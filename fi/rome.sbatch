#!/bin/bash -e
#SBATCH --partition=gen
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --cpus-per-task=128   # every logical CPU of the node (SMT off on rocky9 rome; 256 if SMT ever returns)
#SBATCH --job-name=fft-bench
#SBATCH --output=rome.log
#SBATCH --constraint=rome&rocky9
#SBATCH --time=06:00:00

module purge
module load modules/2.5-beta1 gcc/14.3.0 fftw/3.3.11 intel-oneapi-mkl/2026.0.0
module list
lscpu | grep 'Model name'

# Build tree, made on a rocky9 host with the modules loaded above:
#   cmake -S $SLURM_SUBMIT_DIR/.. -B $SLURM_SUBMIT_DIR/../build-rome -G Ninja \
#         -DCMAKE_BUILD_TYPE=Release -DBENCH_ARCH=znver2
#   cmake --build $SLURM_SUBMIT_DIR/../build-rome
FFT_BENCH_PATH=$SLURM_SUBMIT_DIR/../build-rome

export OMP_NUM_THREADS=128
export OMP_PROC_BIND=spread
export OMP_PLACES=threads
taskset -c 0-127 $FFT_BENCH_PATH/mkl_omp_bench --benchmark_out=mkl-omp-rome.json --benchmark_out_format=json --benchmark_time_unit=us
taskset -c 0-127 $FFT_BENCH_PATH/fftw3_omp_bench --benchmark_out=fftw3-omp-rome.json --benchmark_out_format=json --benchmark_time_unit=us
OMP_PROC_BIND= OMP_PLACES= OMP_WAIT_POLICY=passive taskset -c 0-127 $FFT_BENCH_PATH/ducc_omp_bench --benchmark_out=ducc-omp-rome.json --benchmark_out_format=json --benchmark_time_unit=us
taskset -c 0-127 $FFT_BENCH_PATH/sleef_bench --benchmark_out=sleef-omp-rome.json --benchmark_out_format=json --benchmark_time_unit=us
taskset -c 0-127 $FFT_BENCH_PATH/admiral_omp_bench --benchmark_out=admiral-omp-rome.json --benchmark_out_format=json --benchmark_time_unit=us

export OMP_NUM_THREADS=1
taskset -c 0 $FFT_BENCH_PATH/mkl_bench --benchmark_out=mkl-rome.json --benchmark_out_format=json --benchmark_time_unit=us
taskset -c 0 $FFT_BENCH_PATH/fftw3_bench --benchmark_out=fftw3-rome.json --benchmark_out_format=json --benchmark_time_unit=us
taskset -c 0 $FFT_BENCH_PATH/pocket_bench --benchmark_out=pocket-rome.json --benchmark_out_format=json --benchmark_time_unit=us
taskset -c 0 $FFT_BENCH_PATH/kiss_bench --benchmark_out=kiss-rome.json --benchmark_out_format=json --benchmark_time_unit=us
taskset -c 0 $FFT_BENCH_PATH/ducc_bench --benchmark_out=ducc-rome.json --benchmark_out_format=json --benchmark_time_unit=us
taskset -c 0 $FFT_BENCH_PATH/sleef_bench --benchmark_out=sleef-rome.json --benchmark_out_format=json --benchmark_time_unit=us
taskset -c 0 $FFT_BENCH_PATH/admiral_bench --benchmark_out=admiral-rome.json --benchmark_out_format=json --benchmark_time_unit=us
