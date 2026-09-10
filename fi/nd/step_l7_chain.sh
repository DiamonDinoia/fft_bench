#!/bin/bash
# step-l7: build admiral_bench at landed master 15dc10f and establish the new baseline
# (convention from fi/nd/ccmlin075-2026-09-06-after.md: pinned CPU 4, 5 rotated rounds,
# min-reduced, same-binary control arm).
set -u -o pipefail
F=/mnt/home/mbarbone/repos/fft_bench
B=/home/mbarbone/localcache/scratch/fftb-nd/step-l7
S0=/home/mbarbone/localcache/scratch/fftb-nd/step0
mkdir -p "$B"
module load gcc/14.2.0 intel-oneapi-mkl/2024.2.2 fftw/3.3.10
for bin in admiral_bench mkl_bench fftw3_bench ducc_bench; do
  [ -x "$S0/$bin" ] || { echo "MISSING REF $S0/$bin"; exit 1; }
done
cmake -S "$F" -B "$B/build" -G Ninja -DCMAKE_BUILD_TYPE=Release -DBENCH_ARCH=native \
  > "$B/configure.log" 2>&1 || { echo CONFIGURE-FAIL; exit 1; }
cmake --build "$B/build" --target admiral_bench -j10 > "$B/build.log" 2>&1 \
  || { echo BUILD-FAIL; exit 1; }
"$F/fi/nd/nd_measure.sh" "$B/measure.tsv" 4 5 \
  after="$B/build/admiral_bench" \
  before="$S0/admiral_bench" \
  mkl="$S0/mkl_bench" \
  fftw="$S0/fftw3_bench" \
  ducc="$S0/ducc_bench" \
  after2="$B/build/admiral_bench" \
  > "$B/measure.log" 2>&1 || { echo MEASURE-FAIL; exit 1; }
"$F/fi/nd/nd_reduce.py" "$B/measure.tsv" after mkl fftw ducc --ctl after2 > "$B/reduce-vs-refs.txt" 2>&1 \
  || { echo REDUCE1-FAIL; exit 1; }
"$F/fi/nd/nd_reduce.py" "$B/measure.tsv" after before --ctl after2 > "$B/reduce-vs-before.txt" 2>&1 \
  || { echo REDUCE2-FAIL; exit 1; }
sha256sum "$B/build/admiral_bench" "$S0"/{admiral_bench,mkl_bench,fftw3_bench,ducc_bench} > "$B/SHA256SUMS"
echo STEP-L7-DONE
