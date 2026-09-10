#!/bin/bash
#SBATCH --job-name=fftb-nd
#SBATCH --partition=gen
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --time=04:00:00
# -j8 admiral build peaks at 20 GB cc1plus RSS at znver4 (fi/step5/run_standings.sbatch);
# the 8192^2 cells hold 2 GiB of buffers plus admiral's scratch on top.
#SBATCH --mem=48G
#SBATCH --output=/mnt/home/mbarbone/repos/fft_bench/fi/nd/%x-%j.out
#SBATCH --export=NONE
#
# N-D standings: admiral @ ADMIRAL_REF vs MKL vs FFTW3 vs ducc0, single thread, complex f64
# forward oop, 2-D sides 16..8192 and 3-D sides 4..512 (fi/nd/nd_measure.sh), interleaved
# rounds with rotating arm order, min-reduce (fi/nd/nd_reduce.py). Submit with
# fi/nd/submit_nd_standings.sh. The job clones fft_bench and its submodules --shared from
# the local checkouts into node scratch, so it never touches the working tree.
# A compute node sees /mnt/home and /mnt/sw only; --export=NONE keeps the submitting shell's
# /home/mbarbone pointers out. Outputs go to /mnt/home, scratch to node /tmp.
set -uo pipefail

FFT_BENCH_REPO=/mnt/home/mbarbone/repos/fft_bench
YAFFT_REPO=/mnt/home/mbarbone/repos/yafft
export CPM_SOURCE_CACHE=/mnt/home/mbarbone/.cpm-mnt   # pre-populated: no network on a node
ADMIRAL_REF=15dc10ff9abcb57a5b7c1b514ec44c4d5c6142b8
ADM_TAG=landed   # arm name in the table; landed master 2026-09-10 (L7 folds + align-on, geo deleted)
# 2026-09-06: ref moved a8b4850 -> c4c3911 (nd-campaign consolidated tip: 87d687f Step 4' +
# col dispatch extras fix + poet pinned at the admiral branch 59329e16 + MSVC/gcc-13 CI fixes).
# CPM_SOURCE_CACHE was seeded with poet@59329e16 from the login host (nodes have no network).
ROUNDS=${ROUNDS:-5}  # override only for a local dry run; --export=NONE blocks it under sbatch

model=$(grep -m1 '^model name' /proc/cpuinfo)
case "$model" in
  *7742*) HOST_TAG=rome ;;
  *9474*) HOST_TAG=genoa ;;
  *"Xeon(R) Platinum 83"*|*"Xeon(R) Gold 63"*|*"Xeon(R) Silver 43"*) HOST_TAG=icelake ;;
  *) HOST_TAG=$(hostname -s) ;;
esac
DATE_TAG=$(date +%Y-%m-%d)
OUT_MD="${FFT_BENCH_REPO}/fi/nd/${HOST_TAG}-${DATE_TAG}-${ADM_TAG}.md"

SCRATCH="${SLURM_TMPDIR:-/tmp}/${USER}/fftb-nd-${SLURM_JOB_ID:-local}"
mkdir -p "$SCRATCH"
export CCACHE_DIR="$SCRATCH/ccache" XDG_CACHE_HOME="$SCRATCH/xdg"
log() { echo "[$(date '+%H:%M:%S')] $*"; }

set +u  # lmod's setup.sh reads ENABLE_LMOD unset under --export=NONE
source /etc/profile.d/modules.sh
module purge --force >/dev/null 2>&1 || true
module load modules/2.5-beta1 gcc/14.3.0 fftw/3.3.11 intel-oneapi-mkl/2026.0.0 cmake/3.31.11 ninja/1.13.2
set -u
unset NINJA_STATUS
log "host $(hostname -s) ($model), $(g++ --version | head -1), cmake $(cmake --version | head -1), MKLROOT=$MKLROOT"

PINCPU=$(python3 -c 'import os; print(sorted(os.sched_getaffinity(0))[0])' 2>/dev/null || echo 0)
log "pinning to logical CPU $PINCPU"

SRC="$SCRATCH/src"; BUILD="$SCRATCH/build"
log "clone tree with extern/admiral @ $ADMIRAL_REF"
{
  git clone -q --shared "$FFT_BENCH_REPO" "$SRC"
  while read -r sha path _; do
    git clone -q --shared "$FFT_BENCH_REPO/$path" "$SRC/$path"
    git -C "$SRC/$path" -c advice.detachedHead=false checkout -q --detach "${sha#[-+]}"
  done < <(git -C "$FFT_BENCH_REPO" submodule status)
  git -C "$SRC/extern/admiral" fetch -q "$YAFFT_REPO" nd-campaign
  git -C "$SRC/extern/admiral" -c advice.detachedHead=false checkout -q --detach "$ADMIRAL_REF"
  git -C "$SRC/extern/admiral" log -1 --oneline
} >>"$SCRATCH/build.log" 2>&1 || { log "CLONE FAIL"; tail -20 "$SCRATCH/build.log"; exit 1; }

cmake -S "$SRC" -B "$BUILD" -G Ninja -DFETCHCONTENT_FULLY_DISCONNECTED=ON \
  -DCMAKE_BUILD_TYPE=Release -DBENCH_ARCH=native >>"$SCRATCH/build.log" 2>&1 \
  || { log "CONFIGURE FAIL"; tail -40 "$SCRATCH/build.log"; exit 1; }
: > "$SCRATCH/verdicts.txt"
for tgt in admiral_bench mkl_bench fftw3_bench ducc_bench; do
  log "building $tgt"
  nice -n19 ionice -c3 cmake --build "$BUILD" --target "$tgt" -j8 >>"$SCRATCH/build.log" 2>&1
  rc=$?; log "$tgt exit=$rc"
  if [[ $rc -ne 0 ]]; then echo "BUILD FAIL: $tgt" >> "$SCRATCH/verdicts.txt"; tail -40 "$SCRATCH/build.log"
  else echo "BUILD PASS: $tgt" >> "$SCRATCH/verdicts.txt"; fi
done
grep -q FAIL "$SCRATCH/verdicts.txt" && { cat "$SCRATCH/verdicts.txt"; exit 1; }
sha256sum "$BUILD"/{admiral,mkl,fftw3,ducc}_bench | tee "$SCRATCH/sha256.txt"

TSV="$SCRATCH/measure.tsv"
"$FFT_BENCH_REPO/fi/nd/nd_measure.sh" "$TSV" "$PINCPU" "$ROUNDS" \
  "$ADM_TAG=$BUILD/admiral_bench" mkl="$BUILD/mkl_bench" fftw="$BUILD/fftw3_bench" \
  ducc="$BUILD/ducc_bench" "${ADM_TAG}2=$BUILD/admiral_bench" 2>>"$SCRATCH/measure.log"
log "measure exit=$?"

# GHz per arm: cycles/task-clock at 256^2 (best effort; perf may be absent on the node)
GHZ="$SCRATCH/ghz.txt"; : > "$GHZ"
export MKL_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_DYNAMIC=FALSE
for b in admiral mkl fftw3 ducc; do
  out=$(perf stat -x, -e cycles:u,task-clock -- taskset -c "$PINCPU" "$BUILD/${b}_bench" \
        --benchmark_filter='run_fft<1 << 8, 2>$' --benchmark_min_time=0.5s --benchmark_format=json 2>&1 >/dev/null) \
    && python3 -c "
import sys
d={l.split(',')[2]:float(l.split(',')[0]) for l in sys.argv[1].splitlines() if l.count(',')>=2 and l.split(',')[0].replace('.','').isdigit()}
print('$b GHz=%.3f' % (d['cycles:u']/(d['task-clock']*1e6)))" "$out" >> "$GHZ" || echo "$b GHz=n/a" >> "$GHZ"
done

{
  echo "# fft_bench N-D standings, $HOST_TAG, $DATE_TAG, admiral @ $ADMIRAL_REF ($ADM_TAG)"
  echo
  echo "Host $(hostname -s), $model. Single thread, complex f64 forward oop, ns/transform, min over $ROUNDS interleaved rounds, arm order rotated, pinned to CPU $PINCPU."
  echo "Generated by fi/nd/run_nd_standings.sbatch (job ${SLURM_JOB_ID:-local})."
  echo
  echo '```'; cat "$SCRATCH/sha256.txt"; cat "$GHZ"; echo '```'
  echo
  python3 "$FFT_BENCH_REPO/fi/nd/nd_reduce.py" "$TSV" "$ADM_TAG" mkl fftw ducc --ctl "${ADM_TAG}2"
  echo
  echo "## raw"; echo; echo '```'; cat "$TSV"; echo '```'
} > "$OUT_MD"
log "done, wrote $OUT_MD"
