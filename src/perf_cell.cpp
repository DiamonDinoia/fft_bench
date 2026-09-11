// One (backend, shape, thread count) per process, so `perf stat` wraps exactly one cell.
// Run the same cell at two rep counts and subtract: the difference is per-execute work with
// process startup, plan construction and array initialisation cancelled out.
//
//   perf_cell <dim> <n_per_dim> <nthreads> <reps> [rounds]
//
// It also times the loop itself and reports the MINIMUM ns per execute over `rounds`, so a
// wall-clock answer needs no differencing. `rounds` defaults to 1; give it 5 or more when the
// number is the answer rather than the counters.
//
// PERF_CELL_HUGE=1 madvises both buffers MADV_HUGEPAGE, =0 madvises MADV_NOHUGEPAGE, unset
// leaves the system default. The rome cliff between 2^22 and 2^23 is a TLB hypothesis and this
// is its control: if 4 KiB page walks are the stall, the cliff moves when the same transform
// runs on 2 MiB pages. BOTH directions are forced, because a node whose THP is `always` would
// otherwise give the two arms identical pages and a null result that looks like a refutation.
// Either setting reports AnonHugePages from /proc/self/status after the transforms, which is
// what separates "the pages did not change the time" from "the pages did not change".
//
// PERF_CELL_DEBUG=<n> sets admiral's plan trace level, so a run records the route it timed.
// It prints once per EXECUTE, not once per plan, so never set it for a measured run.
// PERF_CELL_WISDOM=<file> imports and exports FFTW wisdom, so FFTW_MEASURE is paid once
// per size instead of once per process. MKL's fftw3 shim ignores it.
//
// `nthreads` is 1 for the serial arm. admiral reads 0 as its auto width; the fftw-API backends
// take the count through their own planner call.
#include <algorithm>
#include <chrono>
#include <complex>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <random>
#include <vector>

#if defined(__linux__)
#include <sys/mman.h>
#include <unistd.h>
#endif

// madvise takes a hugepage-aligned range, so the interior of the buffer is advised and the
// unaligned head and tail keep 4 KiB pages.
static void advise_pages(void* p, std::size_t bytes, bool huge) {
#if defined(__linux__) && defined(MADV_HUGEPAGE)
    constexpr std::uintptr_t kHuge = 2u << 20;
    auto lo = reinterpret_cast<std::uintptr_t>(p);
    const std::uintptr_t hi = (lo + bytes) & ~(kHuge - 1);
    lo = (lo + kHuge - 1) & ~(kHuge - 1);
    const int adv = huge ? MADV_HUGEPAGE : MADV_NOHUGEPAGE;
    if (hi <= lo) {
        std::fprintf(stderr, "perf_cell: buffer spans no aligned 2 MiB page, advice skipped\n");
        return;
    }
    // The vector faulted every page at construction, and neither advice splits or collapses a
    // page that already exists. MADV_DONTNEED drops them so the memset below re-faults the
    // range under the advice just set. Without it MADV_NOHUGEPAGE is a no-op on a THP=always
    // node and both arms run on 2 MiB pages.
    if (madvise(reinterpret_cast<void*>(lo), hi - lo, adv) != 0)
        std::fprintf(stderr, "perf_cell: madvise(%s) failed\n", huge ? "HUGEPAGE" : "NOHUGEPAGE");
    else if (madvise(reinterpret_cast<void*>(lo), hi - lo, MADV_DONTNEED) != 0)
        std::fprintf(stderr, "perf_cell: madvise(DONTNEED) failed\n");
#else
    (void)p; (void)bytes; (void)huge;
    std::fprintf(stderr, "perf_cell: madvise page advice unavailable on this platform\n");
#endif
}

// The advice is asynchronous, so the count that matters is the one the timed run actually had.
static void report_anon_huge(const char* when) {
    // AnonHugePages left /proc/self/status on 5.x kernels; smaps_rollup is where it lives now.
    std::FILE* f = std::fopen("/proc/self/smaps_rollup", "r");
    if (!f) return;
    char line[256];
    while (std::fgets(line, sizeof line, f))
        if (std::strncmp(line, "AnonHugePages:", 14) == 0) { std::fprintf(stderr, "perf_cell: %s %s", when, line); break; }
    std::fclose(f);
}

#ifdef FFT_BENCH_MKL
#include <fftw/fftw3_mkl.h>
#elif FFT_BENCH_FFTW3
#include <fftw3.h>
#elif FFT_BENCH_ADMIRAL
#include <admiral/admiral.hpp>
#endif

// FFTW_MEASURE overwrites the input array while it plans, so the input is filled AFTER the
// plan exists. Filling first hands the fftw-API backends a zeroed array and admiral a random
// one, which is not the same measurement.
static void fill(std::vector<std::complex<double>>& v) {
    std::mt19937 gen(12345);
    std::uniform_real_distribution<double> distr(-1.0, 1.0);
    for (auto& z : v) z = {distr(gen), distr(gen)};
}

int main(int argc, char** argv) {
    if (argc != 5 && argc != 6) {
        std::fprintf(stderr, "usage: %s <dim> <n_per_dim> <nthreads> <reps> [rounds]\n", argv[0]);
        return 2;
    }
    const int dim = std::atoi(argv[1]);
    const int n1 = std::atoi(argv[2]);
    const int nthreads = std::atoi(argv[3]);
    const long reps = std::atol(argv[4]);
    const int rounds = argc == 6 ? std::atoi(argv[5]) : 1;
    double best_ns = 1e300;
    using clock = std::chrono::steady_clock;

    std::vector<int> shape(static_cast<std::size_t>(dim), n1);
    std::size_t N = 1;
    for (const int d : shape) N *= static_cast<std::size_t>(d);

    std::vector<std::complex<double>> vin(N), vout(N);
    const char* huge_env = std::getenv("PERF_CELL_HUGE");
    if (huge_env) {
        const bool huge = std::atoi(huge_env) != 0;
        advise_pages(vin.data(), N * sizeof vin[0], huge);
        advise_pages(vout.data(), N * sizeof vout[0], huge);
        // The pages are faulted in under the advice, not before it, or the advice arrives too
        // late to change anything: khugepaged collapsing them later is a different experiment.
        std::memset(vin.data(), 0, N * sizeof vin[0]);
        std::memset(vout.data(), 0, N * sizeof vout[0]);
        std::fprintf(stderr, "perf_cell: page advice %s for %zu bytes each\n",
                     huge ? "HUGEPAGE" : "NOHUGEPAGE", N * sizeof vin[0]);
        report_anon_huge("after touch");
    }

#if defined(FFT_BENCH_MKL) || defined(FFT_BENCH_FFTW3)
    // fftw_plan_dft wants the slowest axis first, which is how `shape` is already laid out.
    if (nthreads > 1) {
        fftw_init_threads();
        fftw_plan_with_nthreads(nthreads);
    }
    // FFTW_MEASURE costs minutes at 2^24, once per process. A wisdom file pays it once per
    // size instead, and a run that reuses wisdom plans the same transform it measured.
    const char* wis = std::getenv("PERF_CELL_WISDOM");
    if (wis) fftw_import_wisdom_from_filename(wis);
    fftw_plan p = fftw_plan_dft(dim, shape.data(), reinterpret_cast<fftw_complex*>(vin.data()),
                                reinterpret_cast<fftw_complex*>(vout.data()), FFTW_FORWARD,
                                FFTW_MEASURE);
    if (wis) fftw_export_wisdom_to_filename(wis);
    fill(vin);
    for (int q = 0; q < rounds; ++q) {
        const auto t0 = clock::now();
        for (long r = 0; r < reps; ++r) fftw_execute(p);
        const double d = std::chrono::duration<double, std::nano>(clock::now() - t0).count();
        best_ns = std::min(best_ns, d / double(reps));
    }
    fftw_destroy_plan(p);
#elif defined(FFT_BENCH_ADMIRAL)
    std::vector<std::size_t> ashape(shape.begin(), shape.end());
    // PERF_CELL_DEBUG traces the elected route, so a counter run can record which path it timed.
    const char* dbg = std::getenv("PERF_CELL_DEBUG");
    const admiral::plan<double> p(
        admiral::span<const std::size_t>(ashape.data(), ashape.size()),
        {.nthreads = static_cast<std::size_t>(nthreads),
         .eff = admiral::effort::measure,
         .debug = dbg ? static_cast<unsigned>(std::atoi(dbg)) : 0u});
    fill(vin);
    for (int q = 0; q < rounds; ++q) {
        const auto t0 = clock::now();
        for (long r = 0; r < reps; ++r) p.forward(vin.data(), vout.data());
        const double d = std::chrono::duration<double, std::nano>(clock::now() - t0).count();
        best_ns = std::min(best_ns, d / double(reps));
    }
#endif

    // Keep the result alive so no pass is dead-code eliminated.
    double sink = 0.0;
    for (std::size_t i = 0; i < N; i += (N / 64 + 1)) sink += vout[i].real();
    std::fprintf(stderr, "dim=%d n1=%d nthreads=%d reps=%ld rounds=%d sink=%g\n", dim, n1,
                 nthreads, reps, rounds, sink);
    // A transform of a random input cannot sum to exactly zero. A zero sink means the input was
    // never filled or the output was never written, and the timing measured nothing. The seed is
    // fixed, so every backend prints the SAME sink at the same shape: a mismatch in a job log is
    // a correctness flag, not noise.
    if (sink == 0.0) {
        std::fprintf(stderr, "perf_cell: sink is exactly zero; the transform ran on no data\n");
        return 1;
    }
    std::printf("%.4f\n", best_ns / 1000.0);  // microseconds per execute, min over rounds
    return 0;
}
