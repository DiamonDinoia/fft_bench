#!/bin/bash
# fftm-thr: which knob drives MKL's internal DFTI threading on one host class.
#
# The mkl-omp arm reads the serial time of the mkl arm on rome and genoa, and a
# threaded time on icelake, from one binary and one batch shape. Two candidate causes
# are separable here:
#   1. the knob: DFTI_NUMBER_OF_USER_THREADS declares user threads sharing a descriptor,
#      DFTI_THREAD_LIMIT caps the internal thread count.
#   2. the threading layer: mkl_rt picks GNU when libgomp is loaded, Intel otherwise.
# The probe crosses knob x thread count, once per layer, and prints the limit the
# committed descriptor reports back. icelake is the positive control: its rows must show
# the ratio rising with the thread count, or the probe cannot see threading at all.
#
# Submit one class per job, CLI carries the class width and constraint:
#   sbatch --constraint=rome\&rocky9    --cpus-per-task=128 --export=ALL,CLASS=rome \
#          -o results/rome-mkl-thread-%j.log    fi/probe/mkl_thread_probe.sbatch
#   sbatch --constraint=icelake\&rocky9 --cpus-per-task=64  --export=ALL,CLASS=icelake \
#          -o results/icelake-mkl-thread-%j.log fi/probe/mkl_thread_probe.sbatch
#   sbatch --constraint=genoa\&rocky9   --cpus-per-task=96  --export=ALL,CLASS=genoa \
#          -o results/genoa-mkl-thread-%j.log   fi/probe/mkl_thread_probe.sbatch

#SBATCH --partition=gen
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --time=00:30:00
#SBATCH --job-name=fftm-thr

set -uo pipefail

[[ -n ${CLASS:-} ]] || { echo "MKL_THR_FAIL: CLASS unset (see the header for the submit line)"; exit 1; }

source /etc/profile.d/modules.sh >/dev/null 2>&1
module purge >/dev/null 2>&1
module load modules/2.5-beta1 gcc/14.3.0 intel-oneapi-mkl/2026.0.0 >/dev/null 2>&1 \
    || { echo "MKL_THR_FAIL: no gcc/mkl module"; exit 1; }
g++ -dumpversion >/dev/null 2>&1 || { echo "MKL_THR_FAIL: g++ does not run"; exit 1; }

SRC=$SLURM_SUBMIT_DIR/mkl_thread_probe.cpp
[[ -f $SRC ]] || { echo "MKL_THR_FAIL: $SRC missing"; exit 1; }

WORK=${TMPDIR:-/tmp}/mkl_thread_probe.$SLURM_JOB_ID
mkdir -p "$WORK" || { echo "MKL_THR_FAIL: mkdir $WORK"; exit 1; }
BIN=$WORK/mkl_thread_probe

# The sweep links mkl_rt against libgomp; -fopenmp reproduces that pairing.
g++ -O2 -fopenmp -o "$BIN" "$SRC" -lmkl_rt \
    || { echo "MKL_THR_FAIL: build"; exit 1; }

CPUS=${SLURM_CPUS_PER_TASK:?}

echo "=== fftm-thr, class $CLASS ==="
date -Is
hostname
lscpu | grep 'Model name'
echo "job: $SLURM_JOB_ID ($CPUS cpus, exclusive)"
echo "src: $SRC md5 $(md5sum "$SRC" | cut -c1-12)"
echo "env: OMP_NUM_THREADS=$CPUS OMP_PROC_BIND=spread OMP_PLACES=threads (fi/$CLASS.sbatch shape)"
module list 2>&1

export OMP_NUM_THREADS=$CPUS
export OMP_PROC_BIND=spread
export OMP_PLACES=threads

status=0
for layer in GNU INTEL; do
    echo
    echo "--- MKL_THREADING_LAYER=$layer"
    MKL_THREADING_LAYER=$layer taskset -c 0-$((CPUS - 1)) "$BIN" || status=1
done

rm -rf "$WORK"
[[ $status -eq 0 ]] || { echo "MKL_THR_FAIL: a probe run exited non-zero"; exit 1; }
echo "MKL_THR_DONE $CLASS"
