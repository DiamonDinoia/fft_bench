// DFTI_NUMBER_OF_USER_THREADS declares how many user threads share one descriptor.
// DFTI_THREAD_LIMIT caps MKL's internal threading. The two are crossed against an unset
// descriptor over one cell list, so the arm that scales with the thread count names the
// knob that drives the internal path.
//
//   build: icx/g++ -O2 -fopenmp -o mkl_thread_probe mkl_thread_probe.cpp -lmkl_rt
//   run:   OMP_NUM_THREADS=<T> ./mkl_thread_probe [--smoke]

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

#include <mkl.h>
#include <mkl_dfti.h>
#include <omp.h>

namespace {

enum class Knob { unset, user_threads, thread_limit };

const char *knob_name(Knob k) {
    switch (k) {
    case Knob::unset: return "unset";
    case Knob::user_threads: return "USER_THREADS";
    case Knob::thread_limit: return "THREAD_LIMIT";
    }
    return "?";
}

struct Cell {
    int dim, n_per_dim;
};

// One (cell, knob, threads) point: minimum wall time over `reps` calls, microseconds,
// plus the thread limit the committed descriptor reports back.
struct Row {
    double us;
    MKL_LONG limit_readback;
};

auto measure(Cell c, Knob knob, int threads, int reps) -> Row {
    MKL_LONG n[3];
    long long points = 1;
    for (int i = 0; i < c.dim; ++i) {
        n[i] = c.n_per_dim;
        points *= c.n_per_dim;
    }

    auto *in = static_cast<double *>(mkl_malloc(2 * points * sizeof(double), 64));
    auto *out = static_cast<double *>(mkl_malloc(2 * points * sizeof(double), 64));
    for (long long i = 0; i < 2 * points; ++i) in[i] = 1.0 / (1.0 + i);
    std::memset(out, 0, 2 * points * sizeof(double));

    DFTI_DESCRIPTOR_HANDLE p = nullptr;
    // dim 1 must take the scalar length form: the array form segfaults inside
    // DftiCommitDescriptor's threaded path (MKL 2026.0, probed 2026-09-16).
    if (c.dim == 1)
        DftiCreateDescriptor(&p, DFTI_DOUBLE, DFTI_COMPLEX, 1, n[0]);
    else
        DftiCreateDescriptor(&p, DFTI_DOUBLE, DFTI_COMPLEX, c.dim, n);
    if (knob == Knob::user_threads) DftiSetValue(p, DFTI_NUMBER_OF_USER_THREADS, threads);
    if (knob == Knob::thread_limit) DftiSetValue(p, DFTI_THREAD_LIMIT, threads);
    DftiSetValue(p, DFTI_PLACEMENT, DFTI_NOT_INPLACE);
    if (DftiCommitDescriptor(p) != 0) {
        std::fprintf(stderr, "commit failed: dim %d n %d knob %s threads %d\n", c.dim,
                     c.n_per_dim, knob_name(knob), threads);
        std::exit(1);
    }

    MKL_LONG readback = -1;
    DftiGetValue(p, DFTI_THREAD_LIMIT, &readback);

    DftiComputeForward(p, in, out); // warm the plan, first call pays one-time work
    double best = 1e300;
    for (int r = 0; r < reps; ++r) {
        const auto t0 = std::chrono::steady_clock::now();
        DftiComputeForward(p, in, out);
        const auto t1 = std::chrono::steady_clock::now();
        best = std::min(best, std::chrono::duration<double, std::micro>(t1 - t0).count());
    }

    DftiFreeDescriptor(&p);
    mkl_free(in);
    mkl_free(out);
    return {best, readback};
}

} // namespace

int main(int argc, char **argv) {
    const bool smoke = argc > 1 && std::strcmp(argv[1], "--smoke") == 0;

    char version[256];
    mkl_get_version_string(version, sizeof version);
    const char *layer = std::getenv("MKL_THREADING_LAYER");
    std::printf("# mkl        %s\n", version);
    std::printf("# omp_get_max_threads %d   mkl_get_max_threads %d   MKL_THREADING_LAYER %s\n",
                omp_get_max_threads(), mkl_get_max_threads(), layer ? layer : "(unset)");

    // 1-D past the wrapper gate, the 2-D cell the README quotes, and the 3-D cells whose
    // per-call cost separates the machines.
    std::vector<Cell> cells = {{1, 8192},  {1, 1 << 20}, {1, 1 << 24}, {2, 64},
                               {2, 1024},  {3, 16},      {3, 64},      {3, 256}};
    if (smoke) cells = {{1, 8192}, {2, 64}, {3, 16}};

    const int max_threads = omp_get_max_threads();
    std::vector<int> thread_counts;
    for (int t : {1, 2, 16, 64, 128})
        if (t <= max_threads) thread_counts.push_back(t);
    if (thread_counts.empty() || thread_counts.back() != max_threads)
        thread_counts.push_back(max_threads);
    if (smoke) thread_counts = {1, max_threads};

    const int reps = smoke ? 3 : 7;

    std::printf("%5s %8s %14s %8s %9s %12s %9s\n", "dim", "n", "knob", "threads", "limit",
                "us", "vs_1T");
    for (Cell c : cells) {
        // Per-cell serial reference, so the ratio never crosses cells or runs. The
        // reference is serial only while both thread counts read 1, so both are set here.
        mkl_set_num_threads(1);
        omp_set_num_threads(1);
        const double ref = measure(c, Knob::unset, 1, reps).us;
        for (Knob knob : {Knob::unset, Knob::user_threads, Knob::thread_limit}) {
            for (int t : thread_counts) {
                // MKL's own thread count governs the internal path. Both counts move
                // together, matching the contract every MT arm follows.
                mkl_set_num_threads(t);
                omp_set_num_threads(t);
                const Row row = measure(c, knob, t, reps);
                std::printf("%5d %8d %14s %8d %9ld %12.2f %9.2f\n", c.dim, c.n_per_dim,
                            knob_name(knob), t, static_cast<long>(row.limit_readback),
                            row.us, ref / row.us);
                std::fflush(stdout);
            }
        }
    }
    std::printf("# done\n");
    return 0;
}
