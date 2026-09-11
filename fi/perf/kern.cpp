// Direct cost of the two leaf entry points the N-D path uses, at the same (len, count).
// The innermost axis of an N-D transform runs codelet_dispatch_many_oop over contiguous rows;
// every later axis runs col_codelet_dispatch over strided columns. Both do `count` DFTs of
// length `len`. perf attributes 2.5x more of a 16^2 transform to the first than the second,
// and this measures that directly instead of reading it off sampled percentages.
#include <admiral/detail/nd_plan.hpp>
#include <admiral/detail/codelet.hpp>
#include <chrono>
#include <complex>
#include <cstdio>
#include <cstring>
#include <random>
#include <vector>

using namespace admiral::detail;
using clock_ = std::chrono::steady_clock;

template<typename F>
double best_ns(F&& f, long reps, int rounds) {
    double b = 1e300;
    for (int q = 0; q < rounds; ++q) {
        const auto t0 = clock_::now();
        for (long r = 0; r < reps; ++r) f();
        b = std::min(b, std::chrono::duration<double, std::nano>(clock_::now() - t0).count()
                            / double(reps));
    }
    return b;
}

int main(int argc, char** argv) {
    const std::size_t len = argc > 1 ? std::strtoul(argv[1], nullptr, 10) : 16;
    const std::size_t cnt = argc > 2 ? std::strtoul(argv[2], nullptr, 10) : 16;
    const long reps = argc > 3 ? std::atol(argv[3]) : 200000;
    // "rows", "cols" or both. One arm per process lets `perf stat` attribute a counter to it.
    const char* arm = argc > 4 ? argv[4] : "both";
    const std::size_t N = len * cnt;

    std::vector<std::complex<double>> a(N), b(N);
    std::mt19937 g(7);
    std::uniform_real_distribution<double> u(-1, 1);
    for (auto& z : a) z = {u(g), u(g)};

    // Contiguous rows: `cnt` rows of `len`, row stride `len`, element stride 1.
    const double rows = std::strcmp(arm, "cols") == 0 ? 0.0 : best_ns([&] {
        codelet_dispatch_many_oop<double, true>(a.data(), b.data(), cnt, len, len, len, 1.0);
    }, reps, 5);

    // Strided columns: the same array read as `len` rows of `cnt`, so one pass does `cnt`
    // DFTs of length `len` down the columns. Same element count, same DFT count.
    const double cols = std::strcmp(arm, "rows") == 0 ? 0.0 : best_ns([&] {
        col_codelet_dispatch<double>(true, a.data(), cnt, b.data(), cnt, cnt, len, 1.0);
    }, reps, 5);

    double sink = 0;
    for (std::size_t i = 0; i < N; i += 7) sink += b[i].real();
    std::fprintf(stderr, "sink=%g\n", sink);
    std::printf("len=%zu count=%zu  rows_ns=%.1f cols_ns=%.1f  rows/cols=%.2f\n", len, cnt,
                rows, cols, rows / cols);
    return 0;
}
