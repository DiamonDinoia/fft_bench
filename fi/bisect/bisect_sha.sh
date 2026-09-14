#!/bin/bash
# fi/bisect/bisect_sha.sh — login-side driver for ONE admiral sha of the WI-1c bisect
# (rome (2,1024) f64 vs fftw3, bracket e61ae17..a799b6b; runbook: fi/bisect/README.md).
#
#   SHA=<sha> fi/bisect/bisect_sha.sh            build, then print the probe sbatch line
#   SHA=<sha> fi/bisect/bisect_sha.sh --check    preflight + full plan print; builds nothing
#   SHA=<sha> fi/bisect/bisect_sha.sh --submit   build, then submit the probe (ONE job)
#   fi/bisect/bisect_sha.sh --check              the same, without a sha (plan only)
#
# env:  SHA=<admiral sha, full or abbrev>   (required except for bare --check)
#       CLASS=rome                          (the WI-1c cell is rome; knob kept for parity)
#       JOBS=8                              (build width; bench TUs peak near 3.2 GB each)
#       YAFFT=/mnt/home/mbarbone/repos/yafft
#       ERA=era-2026-09-14-c9ae666          (anchor era the probe measures against)
#
# Queue discipline: one invocation submits at most one job, and only under --submit.
# The manager keeps at most one probe in flight (team cap 3 queued jobs). This script
# never runs sbatch/scancel/sacct/squeue in its default or --check modes.
#
# Builds are per-sha: build-bisect-<class>-<sha7>/ next to fi/submit_all.sh's build-<class>/,
# with the SAME module set, so a bisect binary is toolchain-parity with the sweep binaries.
set -uo pipefail

SELF=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FI=$(dirname "$SELF")
REPO=$(dirname "$FI")
YAFFT=${YAFFT:-/mnt/home/mbarbone/repos/yafft}
JOBS=${JOBS:-8}
CLASS=${CLASS:-rome}
ERA=${ERA:-era-2026-09-14-c9ae666}
ANCHORS=${FFT_BENCH_ANCHORS:-/mnt/home/mbarbone/fft_bench_anchors}
RUN_DIR=${RUN_DIR:-/mnt/home/mbarbone/fft_bench_runs/bisect-wi1c-$CLASS}

GOOD=e61ae17
BAD=a799b6b

declare -A ARCH_OF=([rome]=znver2 [icelake]=icelake-server [genoa]=znver4)

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
fail() { echo "[$(date '+%H:%M:%S')] FAIL: $*" >&2; exit 1; }

MODE=print
case "${1:-}" in
  ""|--print) ;;
  --check)     MODE=check ;;
  --submit)    MODE=submit ;;
  *)           fail "usage: SHA=<sha> $0 [--check|--submit]   (or bare $0 --check for the plan)" ;;
esac
SHA=${SHA:-}

# ------------------------------------------------------------------ the plan
# Printed in every mode so a review of one probe always shows where it sits.
print_plan() {
  cat <<EOF
WI-1c bisect plan (rome (2,1024) f64; bracket ${GOOD:0:7}..${BAD:0:7}, 38 linear commits)
  P0  SHA=$GOOD  positive control: FAST end re-measured under THIS protocol
      (harness fixed at this checkout). Expect probe/anchor ~0.84 at (2,1024).
      If it reads >=0.95 instead, the sweep signal is harness/node-draw: STOP.
  P1  SHA=<git-bisect midpoint>  fi/bisect/next_sha.sh $GOOD $BAD   # today: 36e8170
  Pn  repeat: classify probe/anchor at (2,1024) —
        <=0.90 FAST-class (good end moves up), >=0.95 SLOW/anchor class (bad end moves down),
        0.90..0.95 gray -> resubmit the same probe once before believing it
      next candidate: fi/bisect/next_sha.sh <new-good> <new-bad>
  Close: adjacent pair parent FAST / child SLOW -> the child contains the culprit.
  Discipline: ONE probe job in flight at a time; each --submit is exactly one sbatch.
  Full evidence + candidate table: fi/bisect/README.md
EOF
}

# ------------------------------------------------------------------ preflight
# Same gates as fi/submit_all.sh: rocky9 login host, Lmod, the exact toolchain module
# line, real tool version answers, and a -march probe. These run in every mode so a
# printed plan never green-lights an unbuildable sha.
grep -q 'Rocky Linux release 9' /etc/redhat-release \
  || fail "this host is not Rocky 9; binaries built here may not load on the nodes"

source /etc/profile.d/modules.sh 2>/dev/null || fail "no Lmod on this host"
module --force purge >/dev/null 2>&1
module load modules/2.5-beta1 >/dev/null 2>&1 || fail "module load modules/2.5-beta1"
# Mirrored verbatim from fi/submit_all.sh (module load line), so bisect binaries are
# toolchain-parity with the sweep binaries:
module load gcc/14.3.0 fftw/3.3.11 intel-oneapi-mkl/2026.0.0 cmake/3.31.11 ninja/1.13.2 \
  >/dev/null 2>&1 || fail "module load toolchain"
unset NINJA_STATUS

[[ "$(g++ --version 2>/dev/null | head -1)"   == *"14.3.0"* ]] || fail "g++ is not 14.3.0"
[[ "$(cmake --version 2>/dev/null | head -1)" == *"3.31.11"* ]] || fail "cmake is not 3.31.11"
ninja --version >/dev/null 2>&1 || fail "ninja does not answer --version"
[[ -n "${MKLROOT:-}" && -e "$MKLROOT/lib/libmkl_core.so" ]] || fail "MKL 2026.0.0 not resolvable"
command -v sbatch >/dev/null || fail "no sbatch on PATH (not a slurm login node?)"

[[ -n ${ARCH_OF[$CLASS]:-} ]] || fail "unknown CLASS=$CLASS (want one of: ${!ARCH_OF[*]})"
probe=$(mktemp -d); trap 'rm -rf "$probe"' EXIT
echo 'int main(){return 0;}' > "$probe/p.c"
g++ -march="${ARCH_OF[$CLASS]}" -O3 "$probe/p.c" -o "$probe/p.out" 2>/dev/null \
  || fail "gcc 14.3.0 rejects -march=${ARCH_OF[$CLASS]}"
log "preflight ok: g++ 14.3.0, cmake 3.31.11, -march=${ARCH_OF[$CLASS]} accepted, sbatch present"

# ---------------------------------------------------------------------- plan
print_plan

if [[ -z $SHA ]]; then
  [[ $MODE == check ]] || fail "SHA unset (usage: SHA=<sha> $0 [--check|--submit])"
  echo ""
  echo "--check: no sha given; nothing fetched, checked out, built or submitted."
  exit 0
fi

# --------------------------------------------------------------- resolve sha
FULL=$(git -C "$YAFFT" rev-parse --verify -q "${SHA}^{commit}") \
  || fail "cannot resolve SHA=$SHA in $YAFFT"
SHA7=${FULL:0:7}
LINEAGE=$(git -C "$YAFFT" merge-base --is-ancestor "$GOOD" "$FULL" \
          && git -C "$YAFFT" merge-base --is-ancestor "$FULL" "$BAD" \
          && echo in-range || echo OUT-OF-RANGE)
log "admiral $SHA7 ($FULL)  [$LINEAGE $GOOD..$BAD]"
log "  $(git -C "$YAFFT" log -1 --format=%s "$FULL")"

BT=$REPO/build-bisect-$CLASS-$SHA7
SBATCH_LINE="sbatch --constraint=$CLASS&rocky9 -J fftb-bisect-$SHA7 -o $RUN_DIR/$SHA7/probe.log --export=ALL,SHA7=$SHA7,SHA=$FULL,CLASS=$CLASS,BISECT_TREE=$BT,ERA=$ERA,ANCHORS=$ANCHORS,RUN_DIR=$RUN_DIR,BISECT_DIR=$SELF $SELF/probe_cell.sbatch"

if [[ $MODE == check ]]; then
  echo ""
  echo "--check for SHA=$SHA7 ($LINEAGE):"
  echo "  build tree : $BT (fresh configure; $BT/.admiral_sha pins the tree to this sha)"
  echo "  targets    : admiral_bench admiral_cell (sweep binary + pinned probe binary)"
  echo "  run dir    : $RUN_DIR/$SHA7 (results.tsv, evidence_header.md, sinks.txt, BISECT_DONE)"
  echo "  probe job  : $SBATCH_LINE"
  echo '  discipline : submit ONLY after the previous probe BISECT_DONE marker; never two in flight.'
  echo "  expected   : 12 reps x 3 cells x 2 arms, ~10-13 min on an exclusive $CLASS node"
  echo "--check: nothing fetched, checked out, built or submitted."
  exit 0
fi

# ----------------------------------------------------------- submodule fetch
# first use only: the bench tree add_subdirectory()s every extern at configure time
NEED_SUBS=(extern/admiral extern/benchmark extern/kissfft extern/sleef \
           extern/pocketfft extern/ducc0 extern/ducc0new)
missing=()
for s in "${NEED_SUBS[@]}"; do [[ -e $REPO/$s/.git ]] || missing+=("$s"); done
if (( ${#missing[@]} )); then
  log "git submodule update --init: ${missing[*]}"
  git -C "$REPO" submodule update --init "${missing[@]}" || fail "submodule init"
fi

# Resolve in the YAFFT checkout, never in the submodule clone (its `master` is stale);
# mirrors fi/submit_all.sh's fetch spellings.
git -C "$REPO/extern/admiral" fetch -q "$YAFFT" "$FULL" 2>/dev/null \
  || git -C "$REPO/extern/admiral" cat-file -e "${FULL}^{commit}" 2>/dev/null \
  || fail "cannot fetch $FULL from $YAFFT into extern/admiral"
git -C "$REPO/extern/admiral" -c advice.detachedHead=false checkout -q --detach "$FULL" \
  || fail "checkout extern/admiral @ $FULL"
log "extern/admiral @ $SHA7"

# --------------------------------------------------------------------- build
if [[ -f $BT/.admiral_sha ]]; then
  have=$(cat "$BT/.admiral_sha")
  [[ $have == "$FULL" ]] \
    || fail "$BT is pinned to ${have:0:7}; rm -rf it yourself before reusing the name"
  log "$BT already built for this sha; skipping rebuild"
else
  mkdir -p "$BT" || fail "mkdir $BT"
  log "configure $BT (-march=${ARCH_OF[$CLASS]})"
  cmake -S "$REPO" -B "$BT" -G Ninja -DCMAKE_BUILD_TYPE=Release \
        -DBENCH_ARCH="${ARCH_OF[$CLASS]}" > "$BT.configure.log" 2>&1 \
    || { tail -30 "$BT.configure.log"; fail "configure $BT"; }
  log "build admiral_bench + admiral_cell at -j$JOBS (nice/ionice)"
  nice -n19 ionice -c3 cmake --build "$BT" -j"$JOBS" --target admiral_bench admiral_cell \
      > "$BT.build.log" 2>&1 \
    || { tail -40 "$BT.build.log"; fail "build $BT"; }
  echo "$FULL" > "$BT/.admiral_sha"
fi

# ------------------------------------------------------------- smoke + stamp
for b in admiral_bench admiral_cell; do
  [[ -x $BT/$b ]] || fail "missing binary $BT/$b"
  ldd -r "$BT/$b" 2>&1 | grep -qE 'not found|undefined symbol' && fail "unresolved DSO in $BT/$b"
done
ONE=$("$BT/admiral_cell" 2 64 1 50 2 2>"$probe/smoke.err")
[[ $ONE =~ ^[0-9]+\.[0-9]+$ ]] || fail "admiral_cell smoke produced no float: '$ONE'"
grep -q 'sink=' "$probe/smoke.err" || fail "admiral_cell smoke: no sink line"
log "smoke: admiral_cell (2,64) -> ${ONE} us"

{
  echo "sha=$FULL"
  echo "class=$CLASS arch=${ARCH_OF[$CLASS]}"
  echo "built=$(date -Is) host=$(hostname)"
  echo "modules: modules/2.5-beta1 gcc/14.3.0 fftw/3.3.11 intel-oneapi-mkl/2026.0.0 cmake/3.31.11 ninja/1.13.2"
  md5sum "$BT/admiral_bench" "$BT/admiral_cell"
} > "$BT/BISECT_META" || fail "write $BT/BISECT_META"

# -------------------------------------------------------------------- submit
echo ""
echo "probe job line:"
echo "  $SBATCH_LINE"
if [[ $MODE == submit ]]; then
  mkdir -p "$RUN_DIR/$SHA7" || fail "mkdir $RUN_DIR/$SHA7"
  out=$($SBATCH_LINE) || fail "sbatch: $out"
  J=${out##* }
  [[ $J =~ ^[0-9]+$ ]] || fail "unparsable sbatch output: $out"
  echo "submitted probe $SHA7 = job $J (the one job of this invocation)"
  echo "wait for $RUN_DIR/$SHA7/BISECT_DONE, then classify with fi/bisect/README.md's rule,"
  echo "pick the next sha with fi/bisect/next_sha.sh, and only then re-run this script."
else
  echo "(default mode: nothing submitted — re-run with --submit to queue this one job)"
fi
