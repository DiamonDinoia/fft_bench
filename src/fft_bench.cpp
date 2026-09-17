#include <complex>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <random>
#include <vector>

#include <benchmark/benchmark.h>

// Only the fftw-API backends call an OpenMP routine. ducc and admiral read the
// thread count themselves, and their targets link no OpenMP runtime.
#if defined(FFT_BENCH_OMP) && (defined(FFT_BENCH_MKL) || defined(FFT_BENCH_FFTW3))
#include <omp.h>
#endif

#ifdef FFT_BENCH_MKL
#include <fftw/fftw3_mkl.h>
#ifdef FFT_BENCH_OMP
#include <mkl.h>
#endif
#elif FFT_BENCH_FFTW3
#include <fftw3.h>
#elif FFT_BENCH_SLEEF
extern "C" {
#include <sleef.h>
#include <sleefdft.h>
}
#elif FFT_BENCH_POCKET
extern "C" {
#include <pocketfft.h>
}
#define FFTW_MEASURE 0
#elif FFT_BENCH_KISS
#include <kiss_fft.h>
#define FFTW_MEASURE 0
#elif FFT_BENCH_DUCC
#include <ducc0/fft/fft.h>
#include <ducc0/fft/fftnd_impl.h>
// ugly hack, but it makes compilation easier
#include <ducc0/infra/mav.cc>
#include <ducc0/infra/threading.cc>
#include <ducc0/infra/string_utils.cc>
#elif FFT_BENCH_ADMIRAL
#include <array>

#include <admiral/admiral.hpp>
#endif

// Every arm allocates through here, because the allocator is a measured variable and not a
// detail. fftw_malloc, mkl_malloc and Sleef_malloc return 64 B; std::vector and malloc return
// 16 mod 64 at every size in this sweep. Splitting the field between the two measures the
// allocator: on SPR, MKL alone runs 1.18x to 1.35x slower on 16 mod 64 than on its own
// fftw_malloc, which is the size of the gap the standings attribute to the libraries.
static void *bench_alloc(std::size_t bytes) {
    void *p = std::aligned_alloc(64, (bytes + 63) & ~std::size_t{63});
    if (p == nullptr) std::abort();
    return p;
}

// std::vector with the same 64 B, so the arms that want a container keep one.
template <typename T>
struct bench_allocator {
    using value_type = T;
    bench_allocator() = default;
    template <typename U>
    bench_allocator(const bench_allocator<U> &) {}
    T *allocate(std::size_t n) { return static_cast<T *>(bench_alloc(n * sizeof(T))); }
    void deallocate(T *p, std::size_t) { std::free(p); }
    template <typename U>
    bool operator==(const bench_allocator<U> &) const { return true; }
    template <typename U>
    bool operator!=(const bench_allocator<U> &) const { return false; }
};

template <typename T>
using bench_vector = std::vector<T, bench_allocator<T>>;

// Every arm reaches here, so this is where the shared allocation is proved rather than assumed:
// an arm that acquires its buffers anywhere else shows up as a nonzero residue and stops the run.
void check_alignment(const void *in, const void *out) {
    const std::size_t ain = reinterpret_cast<std::uintptr_t>(in) % 64;
    const std::size_t aout = reinterpret_cast<std::uintptr_t>(out) % 64;
    static bool reported = false;
    if (!reported) {
        reported = true;
        std::fprintf(stderr, "ALIGN in=%zu mod 64, out=%zu mod 64\n", ain, aout);
    }
    if (ain != 0 || aout != 0) {
        std::fprintf(stderr, "ALIGN: arm not on bench_alloc, timings are not comparable\n");
        std::abort();
    }
}

// Scalar-templated: the same routine fills f64 and f32 complex-interleaved buffers. For T=double
// the distribution type and draw count are unchanged, so f64 callers see the old behavior.
template <typename T>
void initialize_arrays(int N, T *in, T *out) {
    check_alignment(in, out);
    std::random_device rand_dev;
    std::mt19937 generator(rand_dev());
    std::uniform_real_distribution<T> distr(T(-1), T(1));

    for (int i = 0; i < 2 * N; ++i)
        in[i] = distr(generator);

    std::memset(out, 0, 2 * N * sizeof(T));
}

// f32 spine capability. pocket's vendored C-API (extern/pocketfft pocketfft.c) and kissfft
// (pinned KISSFFT_DATATYPE=double in CMakeLists.txt; a second datatype would be build-system
// surgery) are double-only, so neither emits run_fft_f32 cells. sleef ships float init1d/init2d
// but no 3-D init, so its f32 spine stops at dim 2, behind the same guard shape as its f64 cells.
#if !defined(FFT_BENCH_POCKET) && !defined(FFT_BENCH_KISS)
#define FFT_BENCH_F32
#endif

#if defined(FFT_BENCH_MKL) && defined(FFT_BENCH_OMP)
// The threaded MKL arm cannot go through the fftw3-compat wrapper: MKL's wrapper
// execute path is pathology-grade when threaded — 1-D f64 8192 x 64T timed at
// 144 ms/call on icelake where native DftiComputeForward with
// DFTI_NUMBER_OF_USER_THREADS reads 17.6 us at 32T (2-D 64^2: 64.5 ms vs 4.7 us;
// measured 2026-09-16, SPR/gcc 14.2, threads 2..32, both OMP runtimes probed).
// Every MT chart carrying mkl-omp plotted that artifact, so this arm drives DFTI
// directly: one descriptor, thread count from OMP_NUM_THREADS via
// omp_get_max_threads (the contract the other MT arms follow).
//
// DFTI_THREAD_LIMIT caps MKL's internal threading, which is the count this arm means.
// DFTI_NUMBER_OF_USER_THREADS declares user threads sharing one descriptor and, on
// AMD, leaves the internal path serial while Intel threads either way; it must not
// stand in for the limit here (fi/probe/mkl_thread_probe.cpp).
template <int N_per_dim, int dim>
static void run_fft(benchmark::State &state) {
    const int N = std::pow(N_per_dim, dim);
    double *in = (double *)bench_alloc(2 * N * sizeof(double));
    double *out = (double *)bench_alloc(2 * N * sizeof(double));
    initialize_arrays(N, in, out);

    MKL_LONG n[dim];
    for (int i = 0; i < dim; ++i)
        n[i] = N_per_dim;

    DFTI_DESCRIPTOR_HANDLE p = nullptr;
    // dim==1 takes the scalar length form: the array form segfaults inside
    // DftiCommitDescriptor's threaded path (MKL 2026.0, probed 2026-09-16).
    if (dim == 1)
        DftiCreateDescriptor(&p, DFTI_DOUBLE, DFTI_COMPLEX, 1, n[0]);
    else
        DftiCreateDescriptor(&p, DFTI_DOUBLE, DFTI_COMPLEX, dim, n);
    DftiSetValue(p, DFTI_THREAD_LIMIT, omp_get_max_threads());
    DftiSetValue(p, DFTI_PLACEMENT, DFTI_NOT_INPLACE);
    if (DftiCommitDescriptor(p) != 0) std::abort();

    for (auto _ : state)
        DftiComputeForward(p, in, out);

    DftiFreeDescriptor(&p);
    std::free(in);
    std::free(out);
}

template <int N_per_dim, int dim>
static void run_fft_f32(benchmark::State &state) {
    const int N = std::pow(N_per_dim, dim);
    float *in = (float *)bench_alloc(2 * N * sizeof(float));
    float *out = (float *)bench_alloc(2 * N * sizeof(float));
    initialize_arrays(N, in, out);

    MKL_LONG n[dim];
    for (int i = 0; i < dim; ++i)
        n[i] = N_per_dim;

    DFTI_DESCRIPTOR_HANDLE p = nullptr;
    if (dim == 1)
        DftiCreateDescriptor(&p, DFTI_SINGLE, DFTI_COMPLEX, 1, n[0]);
    else
        DftiCreateDescriptor(&p, DFTI_SINGLE, DFTI_COMPLEX, dim, n);
    DftiSetValue(p, DFTI_THREAD_LIMIT, omp_get_max_threads());
    DftiSetValue(p, DFTI_PLACEMENT, DFTI_NOT_INPLACE);
    if (DftiCommitDescriptor(p) != 0) std::abort();

    for (auto _ : state)
        DftiComputeForward(p, in, out);

    DftiFreeDescriptor(&p);
    std::free(in);
    std::free(out);
}
#elif defined(FFT_BENCH_MKL) || defined(FFT_BENCH_FFTW3)
template <int N_per_dim, int dim>
static void run_fft(benchmark::State &state) {
    const int N = std::pow(N_per_dim, dim);
    fftw_complex *in = (fftw_complex *)bench_alloc(sizeof(fftw_complex) * N);
    fftw_complex *out = (fftw_complex *)bench_alloc(sizeof(fftw_complex) * N);
    initialize_arrays(N, (double *)in, (double *)out);

    int n[dim];
    for (int i = 0; i < dim; ++i)
        n[i] = N_per_dim;

#ifdef FFT_BENCH_OMP
    int n_threads;
#pragma omp parallel
    n_threads = omp_get_num_threads();
    fftw_plan_with_nthreads(n_threads);
#endif
    fftw_plan p = fftw_plan_dft(dim, n, in, out, FFTW_FORWARD, FFTW_MEASURE);

    for (auto _ : state)
        fftw_execute(p);

    fftw_destroy_plan(p);
    std::free(in);
    std::free(out);
}

template <int N_per_dim, int dim>
static void run_fft_f32(benchmark::State &state) {
    const int N = std::pow(N_per_dim, dim);
    fftwf_complex *in = (fftwf_complex *)bench_alloc(sizeof(fftwf_complex) * N);
    fftwf_complex *out = (fftwf_complex *)bench_alloc(sizeof(fftwf_complex) * N);
    initialize_arrays(N, (float *)in, (float *)out);

    int n[dim];
    for (int i = 0; i < dim; ++i)
        n[i] = N_per_dim;

#ifdef FFT_BENCH_OMP
    int n_threads;
#pragma omp parallel
    n_threads = omp_get_num_threads();
    fftwf_plan_with_nthreads(n_threads);
#endif
    fftwf_plan p = fftwf_plan_dft(dim, n, in, out, FFTW_FORWARD, FFTW_MEASURE);

    for (auto _ : state)
        fftwf_execute(p);

    fftwf_destroy_plan(p);
    std::free(in);
    std::free(out);
}
#elif defined(FFT_BENCH_SLEEF)
template <int N_per_dim, int dim>
static void run_fft(benchmark::State &state) {
    const int N = std::pow(N_per_dim, dim);
    double *in = (double *)bench_alloc(2 * N * sizeof(double));
    double *out = (double *)bench_alloc(2 * N * sizeof(double));
    initialize_arrays(N, (double *)in, (double *)out);
    SleefDFT_setPlanFilePath("plan.txt", NULL, SLEEF_PLAN_AUTOMATIC);

    struct SleefDFT *p;
    if constexpr (dim == 1)
        p = SleefDFT_double_init1d(N_per_dim, in, out, SLEEF_MODE_FORWARD);
    else if constexpr (dim == 2)
        p = SleefDFT_double_init2d(N_per_dim, N_per_dim, in, out, SLEEF_MODE_FORWARD);

    for (auto _ : state)
        SleefDFT_double_execute(p, NULL, NULL);

    std::free(in);
    std::free(out);
    SleefDFT_dispose(p);
}

template <int N_per_dim, int dim>
static void run_fft_f32(benchmark::State &state) {
    const int N = std::pow(N_per_dim, dim);
    float *in = (float *)bench_alloc(2 * N * sizeof(float));
    float *out = (float *)bench_alloc(2 * N * sizeof(float));
    initialize_arrays(N, in, out);
    SleefDFT_setPlanFilePath("plan.txt", NULL, SLEEF_PLAN_AUTOMATIC);

    struct SleefDFT *p;
    if constexpr (dim == 1)
        p = SleefDFT_float_init1d(N_per_dim, in, out, SLEEF_MODE_FORWARD);
    else if constexpr (dim == 2)
        p = SleefDFT_float_init2d(N_per_dim, N_per_dim, in, out, SLEEF_MODE_FORWARD);

    for (auto _ : state)
        SleefDFT_float_execute(p, NULL, NULL);

    std::free(in);
    std::free(out);
    SleefDFT_dispose(p);
}

#elif defined(FFT_BENCH_POCKET)
template <int N, int dim>
static void run_fft(benchmark::State &state) {
    static_assert(dim == 1, "Multiple dimensions not implemented for pocket");
    double *in = (double *)bench_alloc(2 * sizeof(double) * N);
    double *out = (double *)bench_alloc(2 * sizeof(double) * N);
    initialize_arrays(N, in, out);

    cfft_plan p = make_cfft_plan(N);
    for (auto _ : state)
        cfft_forward(p, in, 1.0);

    destroy_cfft_plan(p);
}
#elif defined(FFT_BENCH_KISS)
template <int N, int dim = 1>
static void run_fft(benchmark::State &state) {
    static_assert(dim == 1, "Multiple dimensions not implemented for KISS");
    kiss_fft_cpx *in = (kiss_fft_cpx *)bench_alloc(sizeof(kiss_fft_cpx) * N);
    kiss_fft_cpx *out = (kiss_fft_cpx *)bench_alloc(sizeof(kiss_fft_cpx) * N);
    initialize_arrays(N, (double *)in, (double *)out);
    kiss_fft_cfg p = kiss_fft_alloc(N, 0, NULL, NULL);

    for (auto _ : state)
        kiss_fft(p, in, out);

    kiss_fft_free(p);
}
#elif defined(FFT_BENCH_DUCC)
template <int N_per_dim, int dim>
static void run_fft(benchmark::State &state) {
    constexpr int N = std::pow(N_per_dim, dim);
    ducc0::fmav_info::shape_t shape, axes;

    for (size_t i = 0; i < dim; ++i) {
        shape.push_back(N_per_dim);
        axes.push_back(i);
    }
    bench_vector<std::complex<double>> vin(N), vout(N);
    initialize_arrays(N, (double *)vin.data(), (double *)vout.data());
    ducc0::cfmav<std::complex<double>> in(vin.data(), shape);
    ducc0::vfmav<std::complex<double>> out(vout.data(), shape);

#ifdef FFT_BENCH_OMP
    size_t n_threads = ducc0::detail_threading::ducc0_default_num_threads();
#else
    size_t n_threads = 1;
#endif

    for (auto _ : state)
        ducc0::c2c(in, out, axes, true, 1., n_threads);
}

template <int N_per_dim, int dim>
static void run_fft_f32(benchmark::State &state) {
    constexpr int N = std::pow(N_per_dim, dim);
    ducc0::fmav_info::shape_t shape, axes;

    for (size_t i = 0; i < dim; ++i) {
        shape.push_back(N_per_dim);
        axes.push_back(i);
    }
    bench_vector<std::complex<float>> vin(N), vout(N);
    initialize_arrays(N, (float *)vin.data(), (float *)vout.data());
    ducc0::cfmav<std::complex<float>> in(vin.data(), shape);
    ducc0::vfmav<std::complex<float>> out(vout.data(), shape);

#ifdef FFT_BENCH_OMP
    size_t n_threads = ducc0::detail_threading::ducc0_default_num_threads();
#else
    size_t n_threads = 1;
#endif

    for (auto _ : state)
        ducc0::c2c(in, out, axes, true, 1.f, n_threads);
}
#elif defined(FFT_BENCH_ADMIRAL)
template <int N_per_dim, int dim>
static void run_fft(benchmark::State &state) {
    constexpr std::size_t N = std::pow(N_per_dim, dim);
    bench_vector<std::complex<double>> vin(N), vout(N);
    initialize_arrays(N, (double *)vin.data(), (double *)vout.data());
    std::array<std::size_t, dim> shape;
    shape.fill(N_per_dim);

#ifdef FFT_BENCH_OMP
    // admiral has a size-aware thread heuristic; the libraries without one get
    // their thread count forced from the environment instead
    constexpr std::size_t n_threads = 0;  // 0 = auto
#else
    constexpr std::size_t n_threads = 1;
#endif
    const admiral::plan<double> p(shape, {.nthreads = n_threads, .eff = admiral::effort::measure});

    for (auto _ : state)
        p.forward(vin.data(), vout.data());
}

template <int N_per_dim, int dim>
static void run_fft_f32(benchmark::State &state) {
    constexpr std::size_t N = std::pow(N_per_dim, dim);
    bench_vector<std::complex<float>> vin(N), vout(N);
    initialize_arrays(N, (float *)vin.data(), (float *)vout.data());
    std::array<std::size_t, dim> shape;
    shape.fill(N_per_dim);

#ifdef FFT_BENCH_OMP
    constexpr std::size_t n_threads = 0;  // 0 = auto
#else
    constexpr std::size_t n_threads = 1;
#endif
    const admiral::plan<float> p(shape, {.nthreads = n_threads, .eff = admiral::effort::measure});

    for (auto _ : state)
        p.forward(vin.data(), vout.data());
}
#endif

BENCHMARK(run_fft<1 << 8, 1>);
BENCHMARK(run_fft<1 << 9, 1>);
BENCHMARK(run_fft<1 << 10, 1>);
BENCHMARK(run_fft<1 << 11, 1>);
BENCHMARK(run_fft<1 << 12, 1>);
BENCHMARK(run_fft<1 << 13, 1>);
BENCHMARK(run_fft<1 << 14, 1>);
BENCHMARK(run_fft<1 << 15, 1>);
BENCHMARK(run_fft<1 << 16, 1>);
BENCHMARK(run_fft<1 << 17, 1>);
BENCHMARK(run_fft<1 << 18, 1>);
BENCHMARK(run_fft<1 << 19, 1>);
BENCHMARK(run_fft<1 << 20, 1>);
BENCHMARK(run_fft<1 << 21, 1>);
BENCHMARK(run_fft<1 << 22, 1>);
BENCHMARK(run_fft<1 << 23, 1>);
BENCHMARK(run_fft<1 << 24, 1>);
BENCHMARK(run_fft<1 << 25, 1>);

// f32 pow2 context spine: the f64 ladder as run_fft_f32 so the consumers can key precision off
// the family name and an f32 cell can never overwrite its f64 twin in a (rank, n)-keyed table.
#ifdef FFT_BENCH_F32
BENCHMARK(run_fft_f32<1 << 8, 1>);
BENCHMARK(run_fft_f32<1 << 9, 1>);
BENCHMARK(run_fft_f32<1 << 10, 1>);
BENCHMARK(run_fft_f32<1 << 11, 1>);
BENCHMARK(run_fft_f32<1 << 12, 1>);
BENCHMARK(run_fft_f32<1 << 13, 1>);
BENCHMARK(run_fft_f32<1 << 14, 1>);
BENCHMARK(run_fft_f32<1 << 15, 1>);
BENCHMARK(run_fft_f32<1 << 16, 1>);
BENCHMARK(run_fft_f32<1 << 17, 1>);
BENCHMARK(run_fft_f32<1 << 18, 1>);
BENCHMARK(run_fft_f32<1 << 19, 1>);
BENCHMARK(run_fft_f32<1 << 20, 1>);
BENCHMARK(run_fft_f32<1 << 21, 1>);
BENCHMARK(run_fft_f32<1 << 22, 1>);
BENCHMARK(run_fft_f32<1 << 23, 1>);
BENCHMARK(run_fft_f32<1 << 24, 1>);
BENCHMARK(run_fft_f32<1 << 25, 1>);
#endif

#if defined(FFT_BENCH_MKL) | defined(FFT_BENCH_FFTW3) | defined(FFT_BENCH_DUCC) | defined(FFT_BENCH_SLEEF) | defined(FFT_BENCH_ADMIRAL)
BENCHMARK(run_fft<1 << 4, 2>);
BENCHMARK(run_fft<1 << 5, 2>);
BENCHMARK(run_fft<1 << 6, 2>);
BENCHMARK(run_fft<1 << 7, 2>);
BENCHMARK(run_fft<1 << 8, 2>);
BENCHMARK(run_fft<1 << 9, 2>);
BENCHMARK(run_fft<1 << 10, 2>);
BENCHMARK(run_fft<1 << 11, 2>);
BENCHMARK(run_fft<1 << 12, 2>);
BENCHMARK(run_fft<1 << 13, 2>);
// granule standings cells, f64
BENCHMARK(run_fft<12, 2>);
BENCHMARK(run_fft<24, 2>);

#ifdef FFT_BENCH_F32
// granule standings cells, f32 (16^2 has no f64 twin by design)
BENCHMARK(run_fft_f32<12, 2>);
BENCHMARK(run_fft_f32<16, 2>);
BENCHMARK(run_fft_f32<24, 2>);
// f32 pow2 2-D context spine
BENCHMARK(run_fft_f32<1 << 6, 2>);
BENCHMARK(run_fft_f32<1 << 7, 2>);
BENCHMARK(run_fft_f32<1 << 8, 2>);
BENCHMARK(run_fft_f32<1 << 9, 2>);
BENCHMARK(run_fft_f32<1 << 10, 2>);
#endif

#if not defined(FFT_BENCH_SLEEF)
BENCHMARK(run_fft<1 << 2, 3>);
BENCHMARK(run_fft<1 << 3, 3>);
BENCHMARK(run_fft<1 << 4, 3>);
BENCHMARK(run_fft<1 << 5, 3>);
BENCHMARK(run_fft<1 << 6, 3>);
BENCHMARK(run_fft<1 << 7, 3>);
BENCHMARK(run_fft<1 << 8, 3>);
BENCHMARK(run_fft<1 << 9, 3>);
// granule cube standings cells, f64
BENCHMARK(run_fft<12, 3>);
BENCHMARK(run_fft<24, 3>);

#ifdef FFT_BENCH_F32
// granule cube standings cells, f32
BENCHMARK(run_fft_f32<12, 3>);
BENCHMARK(run_fft_f32<24, 3>);
// f32 pow2 3-D context spine
BENCHMARK(run_fft_f32<1 << 6, 3>);
BENCHMARK(run_fft_f32<1 << 7, 3>);
BENCHMARK(run_fft_f32<1 << 8, 3>);
#endif
#endif
#endif

BENCHMARK_MAIN();
