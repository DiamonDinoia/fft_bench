#!/bin/bash
# Build the WI-2a band-counter cell binaries login-side, then submit the one
# parameterized job (fi/probe/band_counters.sbatch). The ONLY sbatch line of
# the WI-2a package lives here (fi/perf/submit.sh precedent); the one scoped
# queue check afterwards is the manager's.
#
#   fi/probe/submit_band.sh            build (login-side), smoke, submit
#   fi/probe/submit_band.sh --check    print the plan and every blocker, build nothing
#
# What it submits: the rome mid-1-D f64 band probe. CLASS=rome, all six cells
# (1,256..8192) timed 12 rounds with rotated backend order; base+FLOP counter
# classes at every cell; deep groups (pipes, TLB, fills) at (1,1024) and
# (1,8192); backends admiral,fftw3. SLEEF stays descoped from live counters:
# it loses to fftw3 at all six cells in the campaign jsons, so it is cited
# statically in the receipt only.
#
# Binaries are PREBUILT here, on this host, into a per-sha GPFS build tree
# (fi/perf/submit.sh:82-114 pattern): workers are offline and never build
# admiral. extern/admiral is pinned to ADM_SHA (resolved from ADM_REF at
# submission), the superproject index is untouched, and the submodule is
# restored to the recorded pointer once the build is done, so `git status`
# stays clean for the team.
#
#   ADM_REF=<ref>     admiral revision to pin for the build
#                     (default: the recorded extern/admiral submodule pointer)
#   ADM_SRC=<dir>     admiral checkout used for ref resolution/build
#                     (default: <repo>/extern/admiral; initialized as needed)
#   REPO=<dir>        fft_bench checkout (default: this script's repo)
#   MEM_REPO=<dir>    logbook checkout ROOT the job self-commits into
#                     (run dir lands under admiral/beat-standings/runs/;
#                     a ROOT-relative REL pathspec needs the prefix — see the
#                     7041868 note in band_counters.sbatch)
#   RESULTS_DIR=<d>   where the slurm %j logs land (default fi/probe/results)
#   JOBS=<n>          build width (default: full host width)
set -uo pipefail

SELF=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FI=$(dirname "$SELF")
REPO=${REPO:-$(cd "$FI/.." && pwd)}

# ------------------------------------------------------------- WI-2a wiring
CLASS=${CLASS:-rome}
declare -A ARCH_OF=([rome]=znver2 [icelake]=icelake-server [genoa]=znver4)
CELLS=${CELLS:-'(1,256) (1,512) (1,1024) (1,2048) (1,4096) (1,8192)'}
DEEP_CELLS=${DEEP_CELLS:-'(1,1024) (1,8192)'}
BACKENDS=${BACKENDS:-'admiral,fftw3'}
EVENTS=${EVENTS:-'base,flops,pipes,tlb,fill'}
ADM_SRC=${ADM_SRC:-$REPO/extern/admiral}
MEM_REPO=${MEM_REPO:-/mnt/home/mbarbone/repos/memory}
RESULTS_DIR=${RESULTS_DIR:-$SELF/results}
CPM_CACHE=/mnt/home/mbarbone/cpm-cache
JOBS=${JOBS:-$(nproc)}

MODE=submit
for a in "$@"; do
  case "$a" in
    --check) MODE=--check ;;
    submit)  ;;
    *) echo "usage: $0 [--check] [submit]" >&2; exit 1 ;;
  esac
done

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
note() { PROBLEMS+=("$1"); }

# ------------------------------------------------------------ prerequisites
# Checked in BOTH modes; every problem is listed and nothing is submitted while
# one is open (submit_probes.sh discipline).
PROBLEMS=()
for t in git md5sum sbatch cmake ninja; do
  command -v $t >/dev/null || note "no $t on PATH (not a slurm login node?)"
done
for f in band_counters.sbatch perf_probe_lib.sh; do
  [[ -f $SELF/$f ]] || note "missing $SELF/$f"
done
[[ -z ${ARCH_OF[$CLASS]:-} ]] && note "unknown CLASS=$CLASS (no ADM_TARGET_ARCH wired)"
# The recorded submodule pointer is the default ADM_REF; it resolves WITHOUT
# the submodule being populated, so --check never has to touch a checkout.
RECORDED=$(git -C "$REPO" ls-tree HEAD extern/admiral 2>/dev/null | awk '$1 == "160000" {print $3}')
[[ -n $RECORDED ]] || note "cannot read the recorded extern/admiral pointer from $REPO HEAD"
ADM_REF=${ADM_REF:-$RECORDED}
ADM_SHA=
if [[ -n ${ADM_REF:-} ]]; then
  if [[ -d $ADM_SRC/.git || -f $ADM_SRC/.git ]]; then
    ADM_SHA=$(git -C "$ADM_SRC" rev-parse --verify -q "${ADM_REF}^{commit}" 2>/dev/null) \
      || note "cannot resolve ADM_REF=$ADM_REF in $ADM_SRC"
  elif [[ ${ADM_REF:-} == "$RECORDED" ]]; then
    ADM_SHA=$RECORDED
  else
    note "ADM_SRC=$ADM_SRC is not populated and ADM_REF=$ADM_REF != recorded pointer; run submit mode to initialize, or point ADM_SRC at a populated clone"
  fi
fi
BT=$REPO/build-wi2a-$CLASS-${ADM_SHA:0:7}
[[ -d $MEM_REPO/.git ]] || note "MEM_REPO=$MEM_REPO is not the logbook checkout root (no .git)"
[[ -d $MEM_REPO/admiral/beat-standings/runs ]] \
  || note "MEM_REPO=$MEM_REPO lacks admiral/beat-standings/runs (run dir lands there)"
[[ -d $RESULTS_DIR || -w $(dirname "$RESULTS_DIR") ]] || note "cannot create RESULTS_DIR=$RESULTS_DIR"
grep -q 'Rocky Linux release 9' /etc/redhat-release \
  || note "this host is not Rocky 9; binaries built here may not load on the nodes (submit.sh:64 guard applies to submit mode)"

# ------------------------------------------------------------------ the plan
SHA7=${ADM_SHA:-UNRESOLVED}; SHA7=${SHA7:0:7}
echo "WI-2a band probe (mid-1-D f64, $CLASS): engine-absence vs named-mechanism"
echo "  repo:    $REPO"
echo "  admiral: $ADM_SRC @ ${ADM_SHA:-UNRESOLVED} (ref ${ADM_REF:-unset}; recorded ${RECORDED:-?})"
echo "  build:   $BT  (Release, BENCH_ARCH=${ARCH_OF[$CLASS]:-?})"
echo "           targets admiral_cell fftw3_cell, built LOGIN-SIDE; manifest $BT/wi2a-manifest.txt;"
echo "           smoke = ldd -r clean + backend sink agreement at 64^2"
echo "  cells:   $CELLS"
echo "           timed at all six (12 rounds, rotated order, min-of-R inside, min outside);"
echo "           base+flops classes at all six; deep groups (pipes,tlb,fill) at: $DEEP_CELLS"
echo "  backends:$BACKENDS (sleef descoped: loses to fftw3 at all six cells in the campaign jsons)"
echo "  events:  $EVENTS"
echo "  floor:   floor_cyc = mac_flops / (2 FLOPs x W=4 lanes) / 2 FMA pipes (znver2 law;"
echo "           the SPR 'fma x 2' instruction-counting law is never imported)"
echo "  results: job self-commits $MEM_REPO/admiral/beat-standings/runs/wi2a-$CLASS-$SHA7/ before the WI2_DONE marker"
echo "  slurm:   $RESULTS_DIR/wi2a-band-$CLASS.slurm.%j.log"
echo ""
printf '  sbatch --constraint=%s&rocky9 -J wi2a-band-%s -o %s/wi2a-band-%s.slurm.%%j.log \\\n' \
  "$CLASS" "$CLASS" "$RESULTS_DIR" "$CLASS"
printf '           --export=ALL %s/band_counters.sbatch\n' "$SELF"
echo "  (env exported by this script: CLASS CELLS DEEP_CELLS BACKENDS EVENTS ADM_SHA BT MEM_REPO)"
echo "  (--export=ALL, not inline: CELLS carries commas, which --export=a=b,c=d would misparse)"

if (( ${#PROBLEMS[@]} > 0 )); then
  echo ""
  printf 'BLOCKER: %s\n' "${PROBLEMS[@]}" >&2
  exit 1
fi
if [[ $MODE == --check ]]; then
  echo ""
  echo "--check: nothing built, nothing submitted."
  exit 0
fi

# -------------------------------------------------------------------- build
source /etc/profile.d/modules.sh 2>/dev/null || { echo "FAIL: no Lmod on this host" >&2; exit 1; }
module --force purge >/dev/null 2>&1
# Never pipe `module`: it is a shell function, and a pipe runs it in a subshell
# that throws the environment changes away while still exiting 0.
module load modules/2.5-beta1 >/dev/null 2>&1 || { echo "FAIL: module load modules/2.5-beta1" >&2; exit 1; }
module load gcc/14.3.0 fftw/3.3.11 intel-oneapi-mkl/2026.0.0 cmake/3.31.11 ninja/1.13.2 \
  >/dev/null 2>&1 || { echo "FAIL: module load toolchain" >&2; exit 1; }
unset NINJA_STATUS

# Ask each tool its own version. A name that resolves on PATH is not a tool that works.
[[ "$(g++ --version 2>/dev/null | head -1)" == *"14.3.0"* ]] || { echo "FAIL: g++ is not 14.3.0" >&2; exit 1; }
[[ -n "${MKLROOT:-}" && -e "$MKLROOT/lib/libmkl_core.so" ]] \
  || { echo "FAIL: MKL not resolvable (CMakeLists find_package(MKL REQUIRED) at configure)" >&2; exit 1; }
pkg-config --exists fftw3 || { echo "FAIL: pkg-config fftw3" >&2; exit 1; }
log "g++ $(g++ -dumpversion), cmake $(cmake --version | head -1), MKLROOT=$MKLROOT"

# The cell binaries are admiral_cell + fftw3_cell, but CMake GENERATION walks the
# whole tree: add_subdirectory(extern/{benchmark,kissfft,admiral}) runs at
# configure and extern/pocketfft/pocketfft.c is a named source. Those four
# externs must be populated; sleef/ducc only build with their own targets.
log "initializing submodules needed for configure (adm, benchmark, kissfft, pocketfft)"
SCRATCH=${SCRATCH:-/home/mbarbone/localcache/scratch/team-5-wi2a}
mkdir -p "$SCRATCH" || echo "note: cannot create $SCRATCH, submodule log to /tmp"
SUBLOG=$SCRATCH/wi2a-submodule-init.log; [[ -w $SCRATCH ]] || SUBLOG=/tmp/wi2a-submodule-init.log
git -C "$REPO" submodule update --init extern/admiral extern/benchmark extern/kissfft extern/pocketfft \
  > "$SUBLOG" 2>&1 \
  || { tail -10 "$SUBLOG"; echo "FAIL: submodule update --init" >&2; exit 1; }
for d in cpm xsimd poet; do
  [[ -d $CPM_CACHE/$d ]] || { echo "FAIL: CPM cache missing $CPM_CACHE/$d" >&2; exit 1; }
done

ADM_SHA=$(git -C "$ADM_SRC" rev-parse --verify -q "${ADM_REF}^{commit}" 2>/dev/null) \
  || { echo "FAIL: cannot resolve ADM_REF=$ADM_REF in $ADM_SRC" >&2; exit 1; }
BT=$REPO/build-wi2a-$CLASS-${ADM_SHA:0:7}
log "pinning $ADM_SRC at $ADM_SHA"
git -C "$ADM_SRC" checkout -q "$ADM_SHA" \
  || { echo "FAIL: checkout $ADM_SHA" >&2; exit 1; }

log "configure and build $BT (-march=${ARCH_OF[$CLASS]})"
cmake -S "$REPO" -B "$BT" -G Ninja -DCMAKE_BUILD_TYPE=Release \
      -DBENCH_ARCH="${ARCH_OF[$CLASS]}" > "$BT.cfg.log" 2>&1 \
  || { tail -30 "$BT.cfg.log"; echo "FAIL: configure $BT" >&2; exit 1; }
nice -n19 ionice -c3 cmake --build "$BT" -j"$JOBS" \
      --target admiral_cell fftw3_cell > "$BT.build.log" 2>&1 \
  || { tail -40 "$BT.build.log"; echo "FAIL: build $BT" >&2; exit 1; }

# Restore the recorded pointer so the worktree diff stays clean; the pinned
# state is fully materialized in the build tree and in the manifest below.
git -C "$ADM_SRC" checkout -q "$RECORDED"

# Every DSO resolves, every binary runs, and the two backends agree on the same
# transform. perf_cell seeds its input fixed and prints a strided sum of the
# output, so a disagreement here is a correctness failure, not a timing
# artifact (fi/perf/submit.sh:97-111 precedent).
SINKS=""
for b in admiral fftw3; do
  p="$BT/${b}_cell"
  [[ -x $p ]] || { echo "FAIL: missing binary $p" >&2; exit 1; }
  ldd -r "$p" 2>&1 | grep -qE 'not found|undefined symbol' && { echo "FAIL: unresolved DSO in $p" >&2; exit 1; }
  s=$(taskset -c 0 "$p" 2 64 1 50 1 2>&1 >/dev/null | sed -n 's/.*sink=//p')
  [[ -n $s ]] || { echo "FAIL: $p produced no sink" >&2; exit 1; }
  SINKS="$SINKS $s"
done
# shellcheck disable=SC2086
set -- $SINKS
[[ $1 == "$2" ]] || { echo "FAIL: backends disagree at 64^2: $SINKS" >&2; exit 1; }
log "smoke: both binaries, every DSO resolves, backends agree (sink=$1)"

{
  echo "sha $ADM_SHA"
  echo "built $(date -Is) on $(hostname)"
  echo "bench_arch ${ARCH_OF[$CLASS]}"
  for b in admiral fftw3; do
    echo "md5 ${b}_cell $(md5sum < "$BT/${b}_cell" | cut -d' ' -f1)"
  done
} > "$BT/wi2a-manifest.txt" || { echo "FAIL: write manifest" >&2; exit 1; }
log "manifest: $BT/wi2a-manifest.txt ($(md5sum < "$BT/admiral_cell" | cut -c1-12) / $(md5sum < "$BT/fftw3_cell" | cut -c1-12))"

# ------------------------------------------------------------------ submit
mkdir -p "$RESULTS_DIR" || { echo "FAIL: mkdir $RESULTS_DIR" >&2; exit 1; }
export CLASS CELLS DEEP_CELLS BACKENDS EVENTS ADM_SHA BT MEM_REPO
cd "$SELF" || { echo "FAIL: no $SELF" >&2; exit 1; }
out=$(sbatch --constraint="$CLASS&rocky9" -J "wi2a-band-$CLASS" \
      -o "$RESULTS_DIR/wi2a-band-$CLASS.slurm.%j.log" \
      --export=ALL \
      "$SELF/band_counters.sbatch") \
  || { echo "FAIL: sbatch: $out" >&2; exit 1; }
jid=${out##* }
[[ $jid =~ ^[0-9]+$ ]] || { echo "FAIL: unparsable sbatch output: $out" >&2; exit 1; }
echo ""
log "submitted wi2a-band-$CLASS as job $jid at adm ${ADM_SHA:0:7}"
log "watch:  squeue -u \$USER; markers WI2_DONE / WI2_FAIL in the slurm log"
log "run dir: $MEM_REPO/admiral/beat-standings/runs/wi2a-$CLASS-${ADM_SHA:0:7} (self-committed by the job)"
