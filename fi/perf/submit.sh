#!/bin/bash
# Build the cell binaries for both classes on this workstation, check them, then submit every
# outstanding counter job in one go. The compute nodes reuse the trees over GPFS, so each
# binary is built once, here, where the modules and the network are.
#
#   fi/perf/submit.sh                     build, check, submit all four jobs
#   fi/perf/submit.sh --check             build and check only, print the lines, submit nothing
#   fi/perf/submit.sh counters            only icelake_item3 and rome_item2b
#   fi/perf/submit.sh tiny                only the two tiny_ab jobs (no local build needed)
#   fi/perf/submit.sh --check tiny        the same selection, submitting nothing
#
# Every sbatch line lives HERE and nowhere else. They carry long `--constraint` and `-o`
# arguments, and a line that gets wrapped by a terminal splits `-o` from its filename and
# submits nothing while looking like it tried.
#
# The four jobs and what each decides:
#
#   icelake_item3   admiral versus MKL on icelake, 1.227 geomean over 26 losing cells. Restarts
#                   7020147, which was invalid: it exported PERF_CELL_DEBUG for the whole run,
#                   so every timed admiral transform paid two fprintf calls to GPFS while MKL
#                   paid none. The route is now recorded once per cell by `route_of`, outside
#                   any measured region, and perf_lib aborts if the variable is ever set during
#                   one.
#   rome_item2b     why admiral stalls on large 1-D. Pass one (7020146) REFUTED the 2x-traffic
#                   prediction, so this one tests aliasing against TLB by the SIGN of a page
#                   advice arm, and carries znver2-valid fill and walk counters so the answer
#                   is measured either way.
#   tiny_ab (x2)    the flat_tiny N=8 W=8 leaf, on icelake and genoa. The r5 wave read that
#                   shape as a cross-host coin flip, and znver4 halves its 512-bit FP datapaths,
#                   so the shuffle-for-FP trade the lever makes can genuinely invert on genoa.
#                   These two build both arms on the node and need no tree from here.
set -uo pipefail

FI=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$FI/../.." && pwd)
# The counter jobs get their OWN trees. They used to share build-<class> with the standings
# sweep, and submit_queue.sh runs both stages back to back: on 2026-09-11 the sweep relinked
# build-{rome,icelake}/admiral_cell at 07:17:58 and 07:18:13, seconds AFTER jobs 7020425 and
# 7020426 had started reading them. Those two survived, but a job that execs a binary mid-relink
# does not, and a job that silently measures two different binaries is worse than one that dies.
PB=build-perf
JOBS=${JOBS:-8}
declare -A ARCH_OF=([rome]=znver2 [icelake]=icelake-server)

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
fail() { echo "[$(date '+%H:%M:%S')] FAIL: $*" >&2; exit 1; }

MODE=submit
SEL=all
for a in "$@"; do
  case "$a" in
    --check)             MODE=--check ;;
    all|counters|tiny)   SEL=$a ;;
    *) fail "usage: $0 [--check] [all|counters|tiny]" ;;
  esac
done
# The tiny_ab jobs clone yafft and build both arms on the node, so they need no tree from here
# and skipping the local build makes a resubmit instant.
BUILD_CELLS=yes
[[ "$SEL" == tiny ]] && BUILD_CELLS=no

# The jobs run under --constraint=rocky9, so this host must be rocky9 too or the binaries it
# produces may not load there.
grep -q 'Rocky Linux release 9' /etc/redhat-release \
  || fail "this host is not Rocky 9; binaries built here may not load on the nodes"

source /etc/profile.d/modules.sh 2>/dev/null || fail "no Lmod on this host"
module --force purge >/dev/null 2>&1
module load modules/2.5-beta1 >/dev/null 2>&1 || fail "module load modules/2.5-beta1"
# Never pipe `module`: it is a shell function, and a pipe runs it in a subshell that throws
# the environment changes away while still exiting 0.
module load gcc/14.3.0 fftw/3.3.11 intel-oneapi-mkl/2026.0.0 cmake/3.31.11 ninja/1.13.2 \
  >/dev/null 2>&1 || fail "module load toolchain"
unset NINJA_STATUS

# Ask each tool its own version. A name that resolves on PATH is not a tool that works.
[[ "$(g++ --version 2>/dev/null | head -1)" == *"14.3.0"* ]] || fail "g++ is not 14.3.0"
[[ -n "${MKLROOT:-}" && -e "$MKLROOT/lib/libmkl_core.so" ]] || fail "MKL not resolvable"
log "g++ $(g++ -dumpversion), MKLROOT=$MKLROOT"
log "extern/admiral: $(git -C "$REPO/extern/admiral" log -1 --oneline)"

if [[ "$BUILD_CELLS" == yes ]]; then
for c in rome icelake; do
  bt="$REPO/$PB-$c"
  log "configure and build $PB-$c (-march=${ARCH_OF[$c]})"
  cmake -S "$REPO" -B "$bt" -G Ninja -DCMAKE_BUILD_TYPE=Release \
        -DBENCH_ARCH="${ARCH_OF[$c]}" > "$bt.cfg.log" 2>&1 \
    || { tail -30 "$bt.cfg.log"; fail "configure $PB-$c"; }
  nice -n19 ionice -c3 cmake --build "$bt" -j"$JOBS" \
        --target admiral_cell mkl_cell fftw3_cell > "$bt.build.log" 2>&1 \
    || { tail -40 "$bt.build.log"; fail "build $PB-$c"; }
done

# Every DSO resolves, every binary runs, and all three libraries agree on the same transform.
# perf_cell seeds its input fixed and prints a strided sum of the output, so a disagreement
# here is a correctness failure and not a timing artifact.
for c in rome icelake; do
  sinks=""
  for b in admiral_cell mkl_cell fftw3_cell; do
    p="$REPO/$PB-$c/$b"
    [[ -x "$p" ]] || fail "missing binary $p"
    ldd -r "$p" 2>&1 | grep -qE 'not found|undefined symbol' && fail "unresolved DSO in $p"
    s=$(taskset -c 0 "$p" 2 64 1 50 1 2>&1 >/dev/null | sed -n 's/.*sink=//p')
    [[ -n "$s" ]] || fail "$p produced no sink"
    sinks="$sinks $s"
  done
  # shellcheck disable=SC2086
  set -- $sinks
  [[ "$1" == "$2" && "$2" == "$3" ]] || fail "$PB-$c backends disagree at 64^2: $sinks"
  log "smoke $PB-$c: 3 binaries, every DSO resolves, all three agree (sink=$1)"
done
else
  log "selection '$SEL' needs no cell binaries; skipping the local build and smoke test"
fi

# The two tiny_ab jobs clone yafft on the node and build both arms there, with no network, so
# the CPM cache has to be populated before they start or they fail four minutes in.
if [[ "$SEL" != counters ]]; then
  # Read the path OUT of the job script. An inherited CPM_SOURCE_CACHE points at
  # /home/mbarbone/localcache/cpm, which is node-local and does not exist on a worker, so
  # honouring it here would green-light a cache the job cannot see.
  CACHE=$(sed -n 's/^export CPM_SOURCE_CACHE=//p' "$FI/tiny_ab.sbatch" | head -1)
  [[ -n "$CACHE" ]] || fail "tiny_ab.sbatch sets no CPM_SOURCE_CACHE"
  [[ "$CACHE" == /mnt/* ]] || fail "tiny_ab CPM cache '$CACHE' is not on a shared filesystem"
  for d in cpm xsimd poet; do
    [[ -d "$CACHE/$d" ]] \
      || fail "CPM cache missing $CACHE/$d; the tiny_ab jobs cannot build offline"
  done
  log "CPM cache ok at $CACHE"
  [[ -f "$FI/flat_tiny_w8.patch" ]] || fail "missing $FI/flat_tiny_w8.patch"
fi

# One array, one source of truth, printed and then executed verbatim.
LINES=()
if [[ "$SEL" == all || "$SEL" == counters ]]; then
  LINES+=("sbatch icelake_item3.sbatch")
  LINES+=("sbatch rome_item2b.sbatch")
fi
if [[ "$SEL" == all || "$SEL" == tiny ]]; then
  LINES+=("sbatch --constraint=icelake&rocky9 -J tiny_ab_ice -o tiny_ab_ice.log tiny_ab.sbatch")
  LINES+=("sbatch --constraint=genoa&rocky9 -J tiny_ab_genoa -o tiny_ab_genoa.log tiny_ab.sbatch")
fi
echo
printf '  %s\n' "${LINES[@]}"
echo
if [[ "$MODE" == "--check" ]]; then
  log "--check: nothing submitted."
  exit 0
fi
cd "$FI" || fail "no $FI"
# Collect every failure and report at the end. A job that fails to submit must not silently
# leave the set short while the others run.
rc=0
for l in "${LINES[@]}"; do
  # shellcheck disable=SC2086
  $l || { echo "FAIL: $l" >&2; rc=1; }
done
(( rc == 0 )) || fail "one or more submissions failed; see above"
log "submitted ${#LINES[@]} jobs. Watch: squeue -u \$USER"
log "Logs: $FI/{icelake_item3,rome_item2b,tiny_ab_ice,tiny_ab_genoa}.log"
log "Done markers: ITEM3_DONE, ITEM2B_DONE, TINY_AB_DONE"
log "When they finish: $FI/reduce.py $FI/rome_item2b.log"
