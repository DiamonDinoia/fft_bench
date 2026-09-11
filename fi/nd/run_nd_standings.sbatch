#!/bin/bash
#SBATCH --job-name=fftb-nd
#SBATCH --partition=gen
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --time=04:00:00
# -j8 admiral build peaks at 20 GB cc1plus RSS at znver4 (fi/step5/run_standings.sbatch);
# the 8192^2 cells hold 2 GiB of buffers plus admiral's scratch on top. TWO sequential
# admiral builds (yest + reship) share this envelope: the second checkout reuses the same
# configured tree and warm ccache, so the second build is minutes, not the hour.
#SBATCH --mem=48G
#SBATCH --output=/mnt/home/mbarbone/repos/fft_bench/fi/nd/%x-%j.out
#SBATCH --export=NONE
#
# N-D standings control wave (fftfix campaign P0.5+). ONE job measures TWO admiral refs:
#   yest    = ADMIRAL_REF_A (default: landed master 15dc10f, 2026-09-10)
#   reship  = ADMIRAL_REF_B (exported at submit time; the pin-flip reship candidate)
#   reship2 = reship re-run, the same-binary control (eps basis for check.py w1)
#   mkl / fftw / ducc as before. Single thread, complex f64 forward oop, 2-D sides 16..8192
# and 3-D sides 4..512 via fi/nd/nd_measure.sh, interleaved rounds with rotating arm order,
# min-reduced by fi/nd/nd_reduce.py.
#
# Submit slowest-leg-first (QOSMaxCpuPerUserLimit pends a third concurrent standing ~13
# min; genoa's 3d_512 leg is the slowest), exactly:
#   ADMIRAL_REF_B=<sha> bash fi/nd/submit_nd_standings.sh genoa rome icelake
# The wrapper re-exports ADMIRAL_REF_{A,B} / ADM_TAG / ROUNDS across --export=NONE.
#
# Hard invariants, all asserted below before any build minute is burned:
#  - the fork's recorded extern/admiral gitlink == ADMIRAL_REF_A or ADMIRAL_REF_B;
#  - both refs resolve in the clone --shared of the local extern/admiral checkout
#    (objects must be reachable there; the P0.2 landing fetches the reship ref in);
#  - CPM_SOURCE_CACHE (~/.cpm-mnt, pre-seeded, nodes have no network) must already carry
#    BOTH refs' dep sets; the per-ref cmake configure below is the check (CPM resolves at
#    configure time and dies in seconds on a cache miss, not after a queue wait);
#  - ADM_TAG never 'landed' (the *-landed.md docs are the frozen era anchors), default
#    p0base -> fi/nd/<host>-<date>-p0base.md.
#
# A compute node sees /mnt/home and /mnt/sw only; --export=NONE keeps the submitting
# shell's /home/mbarbone pointers out. GPFS stdout loss is why everything below is teed
# node-local first ($SCRATCH/job.log), copied back to fi/nd/ at the end, and sealed with a
# <out>.done marker file (the slurm %x-%j.out is only a tail, never the record).
set -uo pipefail

FFT_BENCH_REPO=/mnt/home/mbarbone/repos/fft_bench
export CPM_SOURCE_CACHE=/mnt/home/mbarbone/.cpm-mnt   # pre-populated: no network on a node
ADMIRAL_REF_A=${ADMIRAL_REF_A:-15dc10ff9abcb57a5b7c1b514ec44c4d5c6142b8}
ADMIRAL_REF_B=${ADMIRAL_REF_B:-__UNSET_at_submit__}
ADM_TAG=${ADM_TAG:-p0base}   # standings doc suffix; table arms are yest/reship/reship2
ROUNDS=${ROUNDS:-5}          # override only for a local dry run

fail() { echo "[$(date '+%H:%M:%S')] FAIL: $*" >&2; exit 1; }
[[ "$ADM_TAG" == "landed" ]] && fail "ADM_TAG=landed would overwrite the *-landed.md anchors"
[[ "$ADMIRAL_REF_B" == "__UNSET_at_submit__" ]] && fail "ADMIRAL_REF_B not exported at submit time"

model=$(grep -m1 '^model name' /proc/cpuinfo)
case "$model" in
  *7742*) HOST_TAG=rome ;;
  *9474*) HOST_TAG=genoa ;;
  *"Xeon(R) Platinum 83"*|*"Xeon(R) Gold 63"*|*"Xeon(R) Silver 43"*) HOST_TAG=icelake ;;
  *) HOST_TAG=$(hostname -s) ;;
esac
DATE_TAG=$(date +%Y-%m-%d)
OUT_STEM="${HOST_TAG}-${DATE_TAG}-${ADM_TAG}"
OUT_MD="${FFT_BENCH_REPO}/fi/nd/${OUT_STEM}.md"
[[ -e "$OUT_MD" ]] && fail "$OUT_MD already exists (bump ADM_TAG for a re-run)"

SCRATCH="${SLURM_TMPDIR:-/tmp}/${USER}/fftb-nd-${SLURM_JOB_ID:-local}"
mkdir -p "$SCRATCH"
export CCACHE_DIR="$SCRATCH/ccache" XDG_CACHE_HOME="$SCRATCH/xdg"
log() { echo "[$(date '+%H:%M:%S')] $*"; }

# node-local tee first (GPFS stdout loss rule); everything from here is on disk on the node
exec > >(tee "$SCRATCH/job.log") 2>&1
copyback() {  # cheap, idempotent: the log must survive even a dead leg
  [[ -f "$SCRATCH/job.log" ]] && cp -f "$SCRATCH/job.log" \
    "${FFT_BENCH_REPO}/fi/nd/${OUT_STEM}.log" 2>/dev/null \
    && log "log copied to fi/nd/${OUT_STEM}.log" \
    || log "WARN: could not copy job.log back"
}
trap copyback EXIT

set +u  # lmod's setup.sh reads ENABLE_LMOD unset under --export=NONE
source /etc/profile.d/modules.sh
module purge --force >/dev/null 2>&1 || true
module load modules/2.5-beta1 gcc/14.3.0 fftw/3.3.11 intel-oneapi-mkl/2026.0.0 cmake/3.31.11 ninja/1.13.2
set -u
# mkl era: cluster legs keep intel-oneapi-mkl/2026.0.0 for era continuity with every cluster
# anchor (fftfix round-0 decision; SPR alone runs 2024.2.2 locally).
##############################################################################
# ERA-BREAK FALLBACK — leave commented unless the 2026.0.0 nix store path gets GC'd
# mid-campaign; switching eras must be logged as an era event in the campaign PLAN first.
# Same recipe as fi/nd/step_mkl24_chain.sh (the 2024-era mkl link bakes no rpath; libiomp5
# rides the compilers runtime):
#   module unload intel-oneapi-mkl/2026.0.0
#   module load intel-oneapi-mkl/2024.2.2
#   MKL24_LIB=/mnt/sw/nix/store/8w4h4np7v1ba0gl6darblfm0bsri60ar-intel-oneapi-mkl-2024.2.2/mkl/2024.2/lib
#   IOMP_LIB=/mnt/sw/nix/store/rv5l25lx54ydhp28dfsvqa2ndgq1iyb6-intel-oneapi-compilers-2025.0.4/compiler/2025.0/lib
#   export LD_LIBRARY_PATH="${MKL24_LIB}:${IOMP_LIB}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
##############################################################################
unset NINJA_STATUS
log "host $(hostname -s) ($model), $(g++ --version | head -1), cmake $(cmake --version | head -1), MKLROOT=$MKLROOT"
log "refs: yest=$ADMIRAL_REF_A reship=$ADMIRAL_REF_B tag=$ADM_TAG rounds=$ROUNDS"

PINCPU=$(python3 -c 'import os; print(sorted(os.sched_getaffinity(0))[0])' 2>/dev/null || echo 0)
log "pinning to logical CPU $PINCPU"

# --- ref invariant, before any build minute is burned -------------------------------
GITLINK=$(git -C "$FFT_BENCH_REPO" ls-tree HEAD --format='%(objectname)' -- extern/admiral)
[[ "$GITLINK" == "$ADMIRAL_REF_A" || "$GITLINK" == "$ADMIRAL_REF_B" ]] \
  || fail "fork extern/admiral gitlink $GITLINK matches neither ref A nor B"

SRC="$SCRATCH/src"; BUILD="$SCRATCH/build"
log "clone tree with extern/admiral pinned at the recorded submodule shas"
{
  git clone -q --shared "$FFT_BENCH_REPO" "$SRC"
  while read -r sha path _; do
    git clone -q --shared "$FFT_BENCH_REPO/$path" "$SRC/$path"
    git -C "$SRC/$path" -c advice.detachedHead=false checkout -q --detach "${sha#[-+]}"
  done < <(git -C "$FFT_BENCH_REPO" submodule status)
} >>"$SCRATCH/build.log" 2>&1 || { log "CLONE FAIL"; tail -20 "$SCRATCH/build.log"; exit 1; }
for pair in "yest=$ADMIRAL_REF_A" "reship=$ADMIRAL_REF_B"; do
  arm=${pair%%=*}; ref=${pair#*=}
  git -C "$SRC/extern/admiral" rev-parse --verify -q "${ref}^{commit}" >/dev/null \
    || fail "$arm ref $ref not resolvable in the shared extern/admiral objects"
done

# --- builds -------------------------------------------------------------------------
# Configure happens at ref A AND again at ref B: CPM resolves (or dies fast) per ref.
build_target() {  # $1 = target
  nice -n19 ionice -c3 cmake --build "$BUILD" --target "$1" -j8 >>"$SCRATCH/build.log" 2>&1
  local rc=$?
  log "$1 exit=$rc"
  [[ $rc -eq 0 ]] && echo "BUILD PASS: $1" >>"$SCRATCH/verdicts.txt" \
                  || { echo "BUILD FAIL: $1" >>"$SCRATCH/verdicts.txt"; tail -40 "$SCRATCH/build.log"; }
  return $rc
}

: > "$SCRATCH/verdicts.txt"
git -C "$SRC/extern/admiral" -c advice.detachedHead=false checkout -q --detach "$ADMIRAL_REF_A" \
  || fail "checkout yest $ADMIRAL_REF_A"
log "configure @ yest=$(git -C "$SRC/extern/admiral" log -1 --oneline)"
cmake -S "$SRC" -B "$BUILD" -G Ninja -DFETCHCONTENT_FULLY_DISCONNECTED=ON \
  -DCMAKE_BUILD_TYPE=Release -DBENCH_ARCH=native >>"$SCRATCH/build.log" 2>&1 \
  || fail "CONFIGURE FAIL (yest)"
for tgt in mkl_bench fftw3_bench ducc_bench admiral_bench; do
  build_target "$tgt"
done
grep -q FAIL "$SCRATCH/verdicts.txt" && { cat "$SCRATCH/verdicts.txt"; exit 1; }
YEST_BIN="$BUILD/admiral_bench_yest"
mv "$BUILD/admiral_bench" "$YEST_BIN"

git -C "$SRC/extern/admiral" -c advice.detachedHead=false checkout -q --detach "$ADMIRAL_REF_B" \
  || fail "checkout reship $ADMIRAL_REF_B"
log "reconfigure @ reship=$(git -C "$SRC/extern/admiral" log -1 --oneline)"
cmake -S "$SRC" -B "$BUILD" -G Ninja -DFETCHCONTENT_FULLY_DISCONNECTED=ON \
  -DCMAKE_BUILD_TYPE=Release -DBENCH_ARCH=native >>"$SCRATCH/build.log" 2>&1 \
  || fail "CONFIGURE FAIL (reship — CPM_SOURCE_CACHE missing its dep set?)"
build_target admiral_bench
grep -q FAIL "$SCRATCH/verdicts.txt" && { cat "$SCRATCH/verdicts.txt"; exit 1; }
RESHIP_BIN="$BUILD/admiral_bench_reship"
cp "$BUILD/admiral_bench" "$RESHIP_BIN"
cat "$SCRATCH/verdicts.txt"

ARMS=(yest="$YEST_BIN" reship="$RESHIP_BIN" mkl="$BUILD/mkl_bench" fftw="$BUILD/fftw3_bench" \
      ducc="$BUILD/ducc_bench" reship2="$RESHIP_BIN")

# --- preflight: ldd clean + one parseable JSON cell per binary, before the measure -----
# (mirrors fi/nd/step_mkl24_chain.sh: a dead arm would otherwise write 18 cells of nan)
for pair in "${ARMS[@]}"; do
  arm=${pair%%=*}; bin=${pair#*=}
  [[ "$arm" == "reship2" ]] && continue   # same binary as reship
  if ldd "$bin" 2>&1 | grep -q 'not found'; then
    fail "PREFLIGHT-FAIL $arm $bin: unresolved DSO: $(ldd "$bin" | grep 'not found')"
  fi
  taskset -c "$PINCPU" "$bin" --benchmark_filter='run_fft<1 << 4, 2>$' \
    --benchmark_repetitions=1 --benchmark_format=json \
    --benchmark_report_aggregates_only=false 2>/dev/null | grep -q '"real_time"' \
    || fail "PREFLIGHT-FAIL $arm $bin: no parseable JSON"
done
log "preflight OK"
sha256sum "$YEST_BIN" "$RESHIP_BIN" "$BUILD"/{mkl,fftw3,ducc}_bench | tee "$SCRATCH/sha256.txt"

TSV="$SCRATCH/measure.tsv"
"$FFT_BENCH_REPO/fi/nd/nd_measure.sh" "$TSV" "$PINCPU" "$ROUNDS" "${ARMS[@]}" \
  2>>"$SCRATCH/measure.log" || fail "measure"
log "measure exit=0"

# GHz per arm: cycles/task-clock at 256^2 (best effort; perf may be absent on the node)
GHZ="$SCRATCH/ghz.txt"; : > "$GHZ"
export MKL_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_DYNAMIC=FALSE
for pair in "${ARMS[@]}"; do
  b=${pair%%=*}; bin=${pair#*=}
  [[ "$b" == "reship2" ]] && continue   # same binary as reship: skip the duplicate probe
  out=$(perf stat -x, -e cycles:u,task-clock -- taskset -c "$PINCPU" "$bin" \
        --benchmark_filter='run_fft<1 << 8, 2>$' --benchmark_min_time=0.5s --benchmark_format=json 2>&1 >/dev/null) \
    && python3 -c "
import sys
d={l.split(',')[2]:float(l.split(',')[0]) for l in sys.argv[1].splitlines() if l.count(',')>=2 and l.split(',')[0].replace('.','').isdigit()}
print('$b GHz=%.3f' % (d['cycles:u']/(d['task-clock']*1e6)))" "$out" >> "$GHZ" || echo "$b GHz=n/a" >> "$GHZ"
done

{
  echo "# fft_bench N-D standings, $HOST_TAG, $DATE_TAG, tag=$ADM_TAG"
  echo
  echo "Host $(hostname -s), $model. Single thread, complex f64 forward oop, ns/transform, min over $ROUNDS interleaved rounds, arm order rotated, pinned to CPU $PINCPU."
  echo "Generated by fi/nd/run_nd_standings.sbatch (job ${SLURM_JOB_ID:-local})."
  echo "Arms: yest @ $ADMIRAL_REF_A, reship @ $ADMIRAL_REF_B, reship2 = reship re-run (same-binary control); mkl/fftw/ducc from this same build."
  echo
  echo '```'; cat "$SCRATCH/sha256.txt"; cat "$GHZ"; echo '```'
  echo
  echo "## reship vs mkl / fftw / ducc (ctl reship2)"
  echo
  python3 "$FFT_BENCH_REPO/fi/nd/nd_reduce.py" "$TSV" reship mkl fftw ducc --ctl reship2
  echo
  echo "## reship vs yest (ctl reship2)"
  echo
  python3 "$FFT_BENCH_REPO/fi/nd/nd_reduce.py" "$TSV" reship yest --ctl reship2
  echo
  echo "## raw"; echo; echo '```'; cat "$TSV"; echo '```'
} > "$SCRATCH/$OUT_STEM.md"

# copy-back, then the DONE marker (the marker means the copy landed, GPFS-lag-proof)
cp "$SCRATCH/$OUT_STEM.md" "$OUT_MD" || fail "copy-back $OUT_MD"
cp "$TSV" "${FFT_BENCH_REPO}/fi/nd/${OUT_STEM}.measure.tsv" || fail "copy-back measure.tsv"
touch "${OUT_MD}.done"
log "done, wrote $OUT_MD (+ .measure.tsv, + .done; log copy on exit via trap)"
