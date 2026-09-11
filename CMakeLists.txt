cmake_minimum_required(VERSION 3.14)
project(
  fft_bench
  LANGUAGES C CXX
)
set(CMAKE_CXX_STANDARD 20)

set (default_build_type "Release")
if (NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  message (STATUS "No build type specified. Setting build type to Release.")
  set (CMAKE_BUILD_TYPE "Release" CACHE STRING "Valid options: Debug, RelWithDebInfo, Release" FORCE)
endif()

set(BENCHMARK_ENABLE_TESTING off CACHE STRING "" FORCE)

# target microarchitecture for every library built here (native, x86-64-v3,
# znver2, icelake-server, znver4, ...); one build tree per benchmark host
set(BENCH_ARCH native CACHE STRING "Target microarchitecture for all bench targets")

set(
  BENCH_INCLUDES
  ${PROJECT_SOURCE_DIR}/include
)


find_package(PkgConfig REQUIRED)
find_package(MKL REQUIRED)
find_package(OpenMP REQUIRED)
pkg_check_modules(FFTW3 REQUIRED fftw3)

include(ExternalProject)
ExternalProject_Add(libsleef
  SOURCE_DIR ${PROJECT_SOURCE_DIR}/extern/sleef
  CMAKE_ARGS -DCMAKE_INSTALL_PREFIX=${CMAKE_BINARY_DIR}/contrib -DSLEEF_BUILD_DFT=ON -DSLEEF_BUILD_TESTS=OFF -DSLEEF_ENABLE_TESTER4=OFF -DSLEEFDFT_MAXBUTWIDTH=7
)

add_subdirectory(${PROJECT_SOURCE_DIR}/extern/benchmark)

set(KISSFFT_STATIC ON CACHE STRING "" FORCE)
set(KISSFFT_PKGCONFIG ON CACHE STRING "" FORCE)
set(KISSFFT_TOOLS OFF CACHE STRING "" FORCE)
set(KISSFFT_TEST OFF CACHE STRING "" FORCE)
set(KISSFFT_DATATYPE double CACHE STRING "" FORCE)
add_subdirectory(${PROJECT_SOURCE_DIR}/extern/kissfft)
# kissfft compiles in its own target, so the per-bench -march does not reach it
target_compile_options(kissfft PRIVATE -march=${BENCH_ARCH})

add_executable(sleef_bench ${PROJECT_SOURCE_DIR}/src/fft_bench.cpp)
add_dependencies(sleef_bench libsleef)
target_include_directories(sleef_bench PRIVATE ${BENCH_INCLUDES} ${CMAKE_BINARY_DIR}/contrib/include)
target_link_directories(sleef_bench PRIVATE ${CMAKE_BINARY_DIR}/contrib/lib64)
target_link_libraries(sleef_bench benchmark::benchmark sleefdft sleef tlfloat OpenMP::OpenMP_CXX)
target_compile_options(sleef_bench PRIVATE -march=${BENCH_ARCH} -DFFT_BENCH_SLEEF)

add_executable(mkl_bench ${PROJECT_SOURCE_DIR}/src/fft_bench.cpp)
target_include_directories(mkl_bench PRIVATE ${BENCH_INCLUDES} ${MKL_H})
target_link_libraries(mkl_bench mkl_rt benchmark::benchmark)
target_compile_options(mkl_bench PRIVATE -march=${BENCH_ARCH} -DFFT_BENCH_MKL)

add_executable(mkl_omp_bench ${PROJECT_SOURCE_DIR}/src/fft_bench.cpp)
target_include_directories(mkl_omp_bench PRIVATE ${BENCH_INCLUDES} ${FFTW3_INCLUDE_DIRS})
target_link_libraries(mkl_omp_bench mkl_rt OpenMP::OpenMP_CXX benchmark::benchmark)
target_compile_options(mkl_omp_bench PRIVATE -march=${BENCH_ARCH} -DFFT_BENCH_MKL -DFFT_BENCH_OMP)

add_executable(ducc_omp_bench ${PROJECT_SOURCE_DIR}/src/fft_bench.cpp)
target_include_directories(ducc_omp_bench PRIVATE ${BENCH_INCLUDES} ${PROJECT_SOURCE_DIR}/extern/ducc0/src)
target_link_libraries(ducc_omp_bench benchmark::benchmark)
target_compile_options(ducc_omp_bench PRIVATE -O3 -march=${BENCH_ARCH} -ffast-math -DFFT_BENCH_DUCC -DFFT_BENCH_OMP -pthread)

add_executable(fftw3_bench ${PROJECT_SOURCE_DIR}/src/fft_bench.cpp)
target_include_directories(fftw3_bench PRIVATE ${BENCH_INCLUDES} ${FFTW3_INCLUDE_DIRS})
target_link_libraries(fftw3_bench ${FFTW3_LIBRARIES} benchmark::benchmark)
target_compile_options(fftw3_bench PRIVATE -march=${BENCH_ARCH} -DFFT_BENCH_FFTW3)

add_executable(fftw3_omp_bench ${PROJECT_SOURCE_DIR}/src/fft_bench.cpp)
target_include_directories(fftw3_omp_bench PRIVATE ${BENCH_INCLUDES} ${FFTW3_INCLUDE_DIRS})
target_link_libraries(fftw3_omp_bench ${FFTW3_LIBRARIES} ${FFTW3_LIBDIR}/libfftw3_omp.so  OpenMP::OpenMP_CXX benchmark::benchmark)
target_compile_options(fftw3_omp_bench PRIVATE -march=${BENCH_ARCH} -DFFT_BENCH_FFTW3 -DFFT_BENCH_OMP)

add_executable(pocket_bench ${PROJECT_SOURCE_DIR}/src/fft_bench.cpp ${PROJECT_SOURCE_DIR}/extern/pocketfft/pocketfft.c)
target_include_directories(pocket_bench PRIVATE ${BENCH_INCLUDES} ${PROJECT_SOURCE_DIR}/extern/pocketfft)
target_link_libraries(pocket_bench benchmark::benchmark)
target_compile_options(pocket_bench PRIVATE -march=${BENCH_ARCH} -DFFT_BENCH_POCKET)

add_executable(kiss_bench ${PROJECT_SOURCE_DIR}/src/fft_bench.cpp)
target_include_directories(kiss_bench PRIVATE ${BENCH_INCLUDES})
target_link_libraries(kiss_bench benchmark::benchmark kissfft::kissfft)
target_compile_options(kiss_bench PRIVATE -march=${BENCH_ARCH} -DFFT_BENCH_KISS)

add_executable(ducc_bench ${PROJECT_SOURCE_DIR}/src/fft_bench.cpp)
target_include_directories(ducc_bench PRIVATE ${BENCH_INCLUDES} ${PROJECT_SOURCE_DIR}/extern/ducc0/src)
target_link_libraries(ducc_bench benchmark::benchmark)
target_compile_options(ducc_bench PRIVATE -O3 -march=${BENCH_ARCH} -ffast-math -DFFT_BENCH_DUCC -DDUCC0_NO_LOWLEVEL_THREADING)

add_executable(duccnew_omp_bench ${PROJECT_SOURCE_DIR}/src/fft_bench.cpp)
target_include_directories(duccnew_omp_bench PRIVATE ${BENCH_INCLUDES} ${PROJECT_SOURCE_DIR}/extern/ducc0new/src)
target_link_libraries(duccnew_omp_bench benchmark::benchmark)
target_compile_options(duccnew_omp_bench PRIVATE -O3 -march=${BENCH_ARCH} -ffast-math -DFFT_BENCH_DUCC -DFFT_BENCH_OMP -pthread)

add_executable(duccnew_bench ${PROJECT_SOURCE_DIR}/src/fft_bench.cpp)
target_include_directories(duccnew_bench PRIVATE ${BENCH_INCLUDES} ${PROJECT_SOURCE_DIR}/extern/ducc0new/src)
target_link_libraries(duccnew_bench benchmark::benchmark)
target_compile_options(duccnew_bench PRIVATE -O3 -march=${BENCH_ARCH} -ffast-math -DFFT_BENCH_DUCC -DDUCC0_NO_LOWLEVEL_THREADING)

# admiral owns its own -march, so BENCH_ARCH has to reach it through its knob.
# FORCE because admiral's own default would otherwise win on a re-configure.
set(ADM_TARGET_ARCH ${BENCH_ARCH} CACHE STRING "Bench arch, forced into admiral" FORCE)
# admiral defaults this ON for its own CI; a warning here must not stop the bench build
set(ADM_ENABLE_WARNINGS_AS_ERRORS OFF CACHE BOOL "" FORCE)
add_subdirectory(${PROJECT_SOURCE_DIR}/extern/admiral)

add_executable(admiral_bench ${PROJECT_SOURCE_DIR}/src/fft_bench.cpp)
target_include_directories(admiral_bench PRIVATE ${BENCH_INCLUDES})
target_link_libraries(admiral_bench benchmark::benchmark admiral::admiral_static)
target_compile_options(admiral_bench PRIVATE -march=${BENCH_ARCH} -DFFT_BENCH_ADMIRAL)

add_executable(admiral_omp_bench ${PROJECT_SOURCE_DIR}/src/fft_bench.cpp)
target_include_directories(admiral_omp_bench PRIVATE ${BENCH_INCLUDES})
target_link_libraries(admiral_omp_bench benchmark::benchmark admiral::admiral_static)
target_compile_options(admiral_omp_bench PRIVATE -march=${BENCH_ARCH} -DFFT_BENCH_ADMIRAL -DFFT_BENCH_OMP)

# One cell per process for `perf stat`; see src/perf_cell.cpp.
add_executable(admiral_cell ${PROJECT_SOURCE_DIR}/src/perf_cell.cpp)
target_include_directories(admiral_cell PRIVATE ${BENCH_INCLUDES})
target_link_libraries(admiral_cell admiral::admiral_static)
target_compile_options(admiral_cell PRIVATE -march=${BENCH_ARCH} -DFFT_BENCH_ADMIRAL)

add_executable(fftw3_cell ${PROJECT_SOURCE_DIR}/src/perf_cell.cpp)
target_include_directories(fftw3_cell PRIVATE ${BENCH_INCLUDES} ${FFTW3_INCLUDE_DIRS})
target_link_libraries(fftw3_cell ${FFTW3_LIBRARIES} ${FFTW3_LIBDIR}/libfftw3_omp.so OpenMP::OpenMP_CXX)
target_compile_options(fftw3_cell PRIVATE -march=${BENCH_ARCH} -DFFT_BENCH_FFTW3)

add_executable(mkl_cell ${PROJECT_SOURCE_DIR}/src/perf_cell.cpp)
target_include_directories(mkl_cell PRIVATE ${BENCH_INCLUDES} ${MKL_H})
target_link_libraries(mkl_cell mkl_rt OpenMP::OpenMP_CXX)
target_compile_options(mkl_cell PRIVATE -march=${BENCH_ARCH} -DFFT_BENCH_MKL)
