#!/bin/bash -e
#SBATCH --partition=gen
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --job-name=fft-bench
#SBATCH --output=icelake.log
#SBATCH --constraint=icelake&rocky9
#SBATCH --time=06:00:00

module purge
module load modules/2.5-beta1 gcc/14.3.0 fftw/3.3.11 intel-oneapi-mkl/2026.0.0
module list
lscpu | grep 'Model name'

# Build tree, made on a rocky9 host with the modules loaded above:
#   cmake -S $SLURM_SUBMIT_DIR/.. -B $SLURM_SUBMIT_DIR/../build-icelake -G Ninja \
#         -DCMAKE_BUILD_TYPE=Release -DBENCH_ARCH=icelake-server
#   cmake --build $SLURM_SUBMIT_DIR/../build-icelake
FFT_BENCH_PATH=$SLURM_SUBMIT_DIR/../build-icelake

export OMP_NUM_THREADS=64
export OMP_PROC_BIND=spread
export OMP_PLACES=threads
taskset -c 0-63 $FFT_BENCH_PATH/mkl_omp_bench --benchmark_out=mkl-omp-icelake.json --benchmark_out_format=json --benchmark_time_unit=us
taskset -c 0-63 $FFT_BENCH_PATH/fftw3_omp_bench --benchmark_out=fftw3-omp-icelake.json --benchmark_out_format=json --benchmark_time_unit=us
OMP_PROC_BIND= OMP_PLACES= OMP_WAIT_POLICY=passive taskset -c 0-63 $FFT_BENCH_PATH/ducc_omp_bench --benchmark_out=ducc-omp-icelake.json --benchmark_out_format=json --benchmark_time_unit=us
taskset -c 0-63 $FFT_BENCH_PATH/sleef_bench --benchmark_out=sleef-omp-icelake.json --benchmark_out_format=json --benchmark_time_unit=us
taskset -c 0-63 $FFT_BENCH_PATH/admiral_omp_bench --benchmark_out=admiral-omp-icelake.json --benchmark_out_format=json --benchmark_time_unit=us

export OMP_NUM_THREADS=1
taskset -c 0 $FFT_BENCH_PATH/mkl_bench --benchmark_out=mkl-icelake.json --benchmark_out_format=json --benchmark_time_unit=us
taskset -c 0 $FFT_BENCH_PATH/fftw3_bench --benchmark_out=fftw3-icelake.json --benchmark_out_format=json --benchmark_time_unit=us
taskset -c 0 $FFT_BENCH_PATH/pocket_bench --benchmark_out=pocket-icelake.json --benchmark_out_format=json --benchmark_time_unit=us
taskset -c 0 $FFT_BENCH_PATH/kiss_bench --benchmark_out=kiss-icelake.json --benchmark_out_format=json --benchmark_time_unit=us
taskset -c 0 $FFT_BENCH_PATH/ducc_bench --benchmark_out=ducc-icelake.json --benchmark_out_format=json --benchmark_time_unit=us
taskset -c 0 $FFT_BENCH_PATH/sleef_bench --benchmark_out=sleef-icelake.json --benchmark_out_format=json --benchmark_time_unit=us
taskset -c 0 $FFT_BENCH_PATH/admiral_bench --benchmark_out=admiral-icelake.json --benchmark_out_format=json --benchmark_time_unit=us
