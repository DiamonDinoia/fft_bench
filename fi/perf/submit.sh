#!/bin/bash
# Build the cell binaries for both classes on this workstation, check them, then submit the
# two counter jobs. The compute nodes reuse the trees over GPFS, so every binary is built
# once, here, where the modules and the network are.
#
#   fi/perf/submit.sh            build, check, submit both jobs
#   fi/perf/submit.sh --check    build and check only, print the sbatch lines, submit nothing
set -uo pipefail

FI=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$FI/../.." && pwd)
JOBS=${JOBS:-8}
declare -A ARCH_OF=([rome]=znver2 [icelake]=icelake-server)

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
fail() { echo "[$(date '+%H:%M:%S')] FAIL: $*" >&2; exit 1; }

MODE=${1:-submit}
case "$MODE" in --check|submit) ;; *) fail "usage: $0 [--check]" ;; esac

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

for c in rome icelake; do
  bt="$REPO/build-$c"
  log "configure and build build-$c (-march=${ARCH_OF[$c]})"
  cmake -S "$REPO" -B "$bt" -G Ninja -DCMAKE_BUILD_TYPE=Release \
        -DBENCH_ARCH="${ARCH_OF[$c]}" > "$bt.cellcfg.log" 2>&1 \
    || { tail -30 "$bt.cellcfg.log"; fail "configure build-$c"; }
  nice -n19 ionice -c3 cmake --build "$bt" -j"$JOBS" \
        --target admiral_cell mkl_cell fftw3_cell > "$bt.cell.log" 2>&1 \
    || { tail -40 "$bt.cell.log"; fail "build build-$c"; }
done

# Every DSO resolves, every binary runs, and all three libraries agree on the same transform.
# perf_cell seeds its input fixed and prints a strided sum of the output, so a disagreement
# here is a correctness failure and not a timing artifact.
for c in rome icelake; do
  sinks=""
  for b in admiral_cell mkl_cell fftw3_cell; do
    p="$REPO/build-$c/$b"
    [[ -x "$p" ]] || fail "missing binary $p"
    ldd -r "$p" 2>&1 | grep -qE 'not found|undefined symbol' && fail "unresolved DSO in $p"
    s=$(taskset -c 0 "$p" 2 64 1 50 1 2>&1 >/dev/null | sed -n 's/.*sink=//p')
    [[ -n "$s" ]] || fail "$p produced no sink"
    sinks="$sinks $s"
  done
  # shellcheck disable=SC2086
  set -- $sinks
  [[ "$1" == "$2" && "$2" == "$3" ]] || fail "build-$c backends disagree at 64^2: $sinks"
  log "smoke build-$c: 3 binaries, every DSO resolves, all three agree (sink=$1)"
done

echo
echo "  sbatch rome_item2.sbatch      # in $FI"
echo "  sbatch icelake_item3.sbatch   # in $FI"
echo
if [[ "$MODE" == "--check" ]]; then
  log "--check: nothing submitted."
  exit 0
fi
cd "$FI" || fail "no $FI"
sbatch rome_item2.sbatch    || fail "sbatch rome_item2.sbatch"
sbatch icelake_item3.sbatch || fail "sbatch icelake_item3.sbatch"
log "submitted. Watch: squeue -u \$USER"
log "Logs: $FI/{rome_item2,icelake_item3}.log"
log "When both finish: $FI/reduce.py $FI/rome_item2.log"
