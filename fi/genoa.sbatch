#!/bin/bash -e
#SBATCH --partition=gen
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --job-name=fft-bench
#SBATCH --output=genoa.log
#SBATCH --constraint=genoa&rocky9
#SBATCH --time=06:00:00

module purge
module load modules/2.5-beta1 gcc/14.3.0 fftw/3.3.11 intel-oneapi-mkl/2026.0.0
module list
lscpu | grep 'Model name'

# Build tree, made on a rocky9 host with the modules loaded above:
#   cmake -S $SLURM_SUBMIT_DIR/.. -B $SLURM_SUBMIT_DIR/../build-genoa -G Ninja \
#         -DCMAKE_BUILD_TYPE=Release -DBENCH_ARCH=znver4
#   cmake --build $SLURM_SUBMIT_DIR/../build-genoa
FFT_BENCH_PATH=$SLURM_SUBMIT_DIR/../build-genoa

export OMP_NUM_THREADS=96
export OMP_PROC_BIND=spread
export OMP_PLACES=threads
taskset -c 0-95 $FFT_BENCH_PATH/mkl_omp_bench --benchmark_out=mkl-omp-genoa.json --benchmark_out_format=json --benchmark_time_unit=us
# fftw3_omp_bench omitted on genoa: FFTW_MEASURE planning at 96 threads burns
# 99% of one core for >2h without completing a case; it does not finish in
# meaningful time (rome/icelake take 13-24 min for the same block)
#taskset -c 0-95 $FFT_BENCH_PATH/fftw3_omp_bench --benchmark_out=fftw3-omp-genoa.json --benchmark_out_format=json --benchmark_time_unit=us
OMP_PROC_BIND= OMP_PLACES= OMP_WAIT_POLICY=passive taskset -c 0-95 $FFT_BENCH_PATH/ducc_omp_bench --benchmark_out=ducc-omp-genoa.json --benchmark_out_format=json --benchmark_time_unit=us
taskset -c 0-95 $FFT_BENCH_PATH/sleef_bench --benchmark_out=sleef-omp-genoa.json --benchmark_out_format=json --benchmark_time_unit=us
taskset -c 0-95 $FFT_BENCH_PATH/admiral_omp_bench --benchmark_out=admiral-omp-genoa.json --benchmark_out_format=json --benchmark_time_unit=us

export OMP_NUM_THREADS=1
taskset -c 0 $FFT_BENCH_PATH/mkl_bench --benchmark_out=mkl-genoa.json --benchmark_out_format=json --benchmark_time_unit=us
taskset -c 0 $FFT_BENCH_PATH/fftw3_bench --benchmark_out=fftw3-genoa.json --benchmark_out_format=json --benchmark_time_unit=us
taskset -c 0 $FFT_BENCH_PATH/pocket_bench --benchmark_out=pocket-genoa.json --benchmark_out_format=json --benchmark_time_unit=us
taskset -c 0 $FFT_BENCH_PATH/kiss_bench --benchmark_out=kiss-genoa.json --benchmark_out_format=json --benchmark_time_unit=us
taskset -c 0 $FFT_BENCH_PATH/ducc_bench --benchmark_out=ducc-genoa.json --benchmark_out_format=json --benchmark_time_unit=us
taskset -c 0 $FFT_BENCH_PATH/sleef_bench --benchmark_out=sleef-genoa.json --benchmark_out_format=json --benchmark_time_unit=us
taskset -c 0 $FFT_BENCH_PATH/admiral_bench --benchmark_out=admiral-genoa.json --benchmark_out_format=json --benchmark_time_unit=us
