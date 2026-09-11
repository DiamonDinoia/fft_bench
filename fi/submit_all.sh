#!/bin/bash
# Build the three per-class bench trees on this workstation, then submit the
# standings job for each class. The compute nodes reuse the trees over GPFS, so
# every binary is built once, here, where the modules and the network are.
#
#   fi/submit_all.sh --check     preflight + build + smoke, print the sbatch lines, submit nothing
#   fi/submit_all.sh             the same, then submit the three jobs
#   fi/submit_all.sh --plots     regenerate the charts from whatever jsons are present
#
#   ADMIRAL_REF=<ref>  which admiral to benchmark (default: master of the yafft checkout)
#   JOBS=<n>           build width (default 8; the bench TUs peak near 3.2 GB each)
set -uo pipefail

REPO=/mnt/home/mbarbone/repos/fft_bench
YAFFT=/mnt/home/mbarbone/repos/yafft
FI="$REPO/fi"
JOBS=${JOBS:-8}
ADMIRAL_REF=${ADMIRAL_REF:-master}

declare -A ARCH_OF=([rome]=znver2 [icelake]=icelake-server [genoa]=znver4)
CLASSES=(rome icelake genoa)

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
fail() { echo "[$(date '+%H:%M:%S')] FAIL: $*" >&2; exit 1; }

MODE=${1:-submit}
case "$MODE" in --check|--plots|submit) ;; *) fail "usage: $0 [--check|--plots]" ;; esac

# ---------------------------------------------------------------- plots only
if [[ "$MODE" == "--plots" ]]; then
  cd "$FI" || fail "no $FI"
  command -v uv >/dev/null || fail "uv not on PATH"
  uv run --quiet --with matplotlib --with pycairo python collect_results.py || fail "collect_results.py"
  log "charts regenerated in $FI"
  exit 0
fi

# ------------------------------------------------------------------ preflight
# The jobs run under --constraint=rocky9, so this host must be rocky9 too or the
# binaries it produces may not load there.
grep -q 'Rocky Linux release 9' /etc/redhat-release \
  || fail "this host is not Rocky 9; binaries built here may not load on the nodes"

source /etc/profile.d/modules.sh 2>/dev/null || fail "no Lmod on this host"
module --force purge >/dev/null 2>&1
module load modules/2.5-beta1 >/dev/null 2>&1 || fail "module load modules/2.5-beta1"
# Never pipe `module`: it is a shell function, and a pipe runs it in a subshell
# that throws the environment changes away while still exiting 0.
module load gcc/14.3.0 fftw/3.3.11 intel-oneapi-mkl/2026.0.0 cmake/3.31.11 ninja/1.13.2 \
  >/dev/null 2>&1 || fail "module load toolchain"
unset NINJA_STATUS

# Ask each tool its own version. A name that resolves on PATH is not a tool that works.
[[ "$(g++ --version 2>/dev/null | head -1)"   == *"14.3.0"* ]] || fail "g++ is not 14.3.0: $(g++ --version | head -1)"
[[ "$(cmake --version 2>/dev/null | head -1)" == *"3.31.11"* ]] || fail "cmake is not 3.31.11"
ninja --version >/dev/null 2>&1 || fail "ninja does not answer --version"
[[ -n "${MKLROOT:-}" && -e "$MKLROOT/lib/libmkl_core.so" ]] || fail "MKL 2026.0.0 not resolvable (MKLROOT=${MKLROOT:-unset})"
log "g++ $(g++ -dumpversion), cmake $(cmake --version | head -1 | awk '{print $3}'), MKLROOT=$MKLROOT"

# Every -march this script asks for must be one this gcc accepts.
probe=$(mktemp -d); trap 'rm -rf "$probe"' EXIT
echo 'int main(){return 0;}' > "$probe/p.c"
for c in "${CLASSES[@]}"; do
  g++ -march="${ARCH_OF[$c]}" -O3 "$probe/p.c" -o "$probe/p.out" 2>/dev/null \
    || fail "gcc 14.3.0 rejects -march=${ARCH_OF[$c]}"
done
log "arch probes ok: ${ARCH_OF[rome]} ${ARCH_OF[icelake]} ${ARCH_OF[genoa]}"

# ------------------------------------------------------------- admiral pin
cd "$REPO" || fail "no $REPO"
# Resolve the ref in the YAFFT checkout, never in the submodule clone: the
# submodule carries its own stale `master` branch, so resolving there silently
# benchmarks whatever that branch last pointed at.
REF_SHA=$(git -C "$YAFFT" rev-parse --verify -q "${ADMIRAL_REF}^{commit}") \
  || fail "cannot resolve ADMIRAL_REF=$ADMIRAL_REF in $YAFFT"
git -C extern/admiral fetch -q "$YAFFT" "$REF_SHA" 2>/dev/null \
  || git -C extern/admiral cat-file -e "${REF_SHA}^{commit}" 2>/dev/null \
  || fail "cannot fetch $REF_SHA from $YAFFT into extern/admiral"
PINNED=$(git ls-tree HEAD --format='%(objectname)' -- extern/admiral)
git -C extern/admiral -c advice.detachedHead=false checkout -q --detach "$REF_SHA" \
  || fail "checkout extern/admiral @ $REF_SHA"
log "extern/admiral: recorded pin $PINNED -> benchmarking $REF_SHA"
log "  $(git -C extern/admiral log -1 --oneline)"
DIRTY=$(git -C "$YAFFT" status --porcelain | wc -l)
[[ "$DIRTY" -gt 0 ]] && log "NOTE: $YAFFT has $DIRTY uncommitted file(s); they are NOT in $REF_SHA"

# ------------------------------------------------------------------ build
for c in "${CLASSES[@]}"; do
  bt="$REPO/build-$c"
  log "configure build-$c (-march=${ARCH_OF[$c]})"
  cmake -S "$REPO" -B "$bt" -G Ninja -DCMAKE_BUILD_TYPE=Release \
        -DBENCH_ARCH="${ARCH_OF[$c]}" > "$bt.configure.log" 2>&1 \
    || { tail -30 "$bt.configure.log"; fail "configure build-$c"; }
  log "build build-$c at -j$JOBS"
  nice -n19 ionice -c3 cmake --build "$bt" -j"$JOBS" > "$bt.build.log" 2>&1 \
    || { tail -40 "$bt.build.log"; fail "build build-$c"; }
done

# --------------------------------------------------------------- smoke tests
# Every binary the sbatch scripts name must exist and resolve every DSO. `ldd -r`
# catches a missing MKL or FFTW without executing code built for another class.
BINS=(mkl_bench fftw3_bench pocket_bench kiss_bench ducc_bench sleef_bench admiral_bench
      mkl_omp_bench fftw3_omp_bench ducc_omp_bench admiral_omp_bench)
for c in "${CLASSES[@]}"; do
  for b in "${BINS[@]}"; do
    p="$REPO/build-$c/$b"
    [[ -x "$p" ]] || fail "missing binary $p"
    ldd -r "$p" 2>&1 | grep -qE 'not found|undefined symbol' && fail "unresolved DSO in $p"
  done
done
log "smoke: $(( ${#CLASSES[@]} * ${#BINS[@]} )) binaries present, every DSO resolves"

# One real cell from the znver2 tree. AVX2 runs on every class this host can be,
# so this proves the harness emits parseable JSON, not just that it links.
J=$("$REPO/build-rome/admiral_bench" --benchmark_filter='run_fft<1 << 8, 1>$' \
      --benchmark_repetitions=1 --benchmark_format=json 2>/dev/null)
echo "$J" | python3 -c 'import json,sys
b = json.load(sys.stdin)["benchmarks"][0]
print("smoke: %s %.1f %s" % (b["name"], b["real_time"], b["time_unit"]))' \
  || fail "admiral_bench produced no parseable JSON"

# ------------------------------------------------------------------- submit
log "ready. Results land in $FI as <impl>-<class>.json (the sbatch cwd)."
echo
for c in "${CLASSES[@]}"; do echo "  sbatch $c.sbatch   # in $FI"; done
echo
if [[ "$MODE" == "--check" ]]; then
  log "--check: nothing submitted."
  exit 0
fi
cd "$FI" || fail "no $FI"
for c in "${CLASSES[@]}"; do
  sbatch "$c.sbatch" || fail "sbatch $c.sbatch"
done
log "submitted. Watch: squeue -u \$USER   Logs: $FI/{rome,icelake,genoa}.log"
log "When all three finish: $0 --plots"
