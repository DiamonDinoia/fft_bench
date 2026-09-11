// Whole-transform counterpart to kern.cpp: one shape, one process, so `perf stat` at two rep
// counts differences to per-execute instructions and cycles. The leaf costs are already known
// from kern.cpp, so subtracting them from these numbers sizes the dispatch term in instructions
// instead of in sampled percentages.
//
//   whole <dim> <n_per_dim> <reps> [rounds]
#include <admiral/admiral.hpp>

#include <algorithm>
#include <chrono>
#include <complex>
#include <cstdio>
#include <cstdlib>
#include <random>
#include <vector>

using clock_ = std::chrono::steady_clock;

int main(int argc, char** argv) {
    const int dim = argc > 1 ? std::atoi(argv[1]) : 2;
    const std::size_t n1 = argc > 2 ? std::strtoul(argv[2], nullptr, 10) : 16;
    const long reps = argc > 3 ? std::atol(argv[3]) : 20000;
    const int rounds = argc > 4 ? std::atoi(argv[4]) : 5;

    std::vector<std::size_t> shape(static_cast<std::size_t>(dim), n1);
    std::size_t N = 1;
    for (const std::size_t d : shape) N *= d;
    std::vector<std::complex<double>> vin(N), vout(N);
    std::mt19937 g(12345);
    std::uniform_real_distribution<double> u(-1, 1);
    for (auto& z : vin) z = {u(g), u(g)};

    const admiral::plan<double> p(admiral::span<const std::size_t>(shape.data(), shape.size()),
                                  {.nthreads = 1, .eff = admiral::effort::measure});
    double best = 1e300;
    for (int q = 0; q < rounds; ++q) {
        const auto t0 = clock_::now();
        for (long r = 0; r < reps; ++r) p.forward(vin.data(), vout.data());
        best = std::min(best, std::chrono::duration<double, std::nano>(clock_::now() - t0).count()
                                  / double(reps));
    }
    double sink = 0.0;
    for (std::size_t i = 0; i < N; i += (N / 64 + 1)) sink += vout[i].real();
    if (sink == 0.0) { std::fprintf(stderr, "whole: zero sink\n"); return 1; }
    std::fprintf(stderr, "dim=%d n=%zu reps=%ld sink=%g\n", dim, n1, reps, sink);
    std::printf("%.2f\n", best);
    return 0;
}
