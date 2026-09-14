#!/bin/bash
# Submit (or, with --check, only print) one anchored sweep run: for each host class,
#   sweep  (fi/<class>.sbatch)               -> the standings measurement
#   probe  (fi/anchor/probe.sbatch)          --dependency=afterok:<sweep>
#          era-anchor vs this run's binary, pinned, 12 alternating reps
#   collect(fi/anchor/collect.sbatch)        --dependency=afterok:<probe>
#          jsons + probe table + sacct rows -> logbook run dir, local git commit
#
#   fi/anchor/submit_chain.sh [--check]
#
# The ONLY sbatch line in the anchored flow lives here (see fi/perf/submit.sh for why);
# fi/submit_all.sh and fi/submit_standings.sh both delegate to this after their own
# build/freshness gates. A failed step cancels its branch of the chain
# (DependencyNeverSatisfied), never producing a half-collected run.
#
#   ERA=<era-id>   which anchor era the probe measures against
#                  (default era-2026-09-14-c9ae666, minted by fi/anchor/capture_anchor.sh)
set -uo pipefail

SELF=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FI=$(dirname "$SELF")
REPO=$(dirname "$FI")
CLASSES=(rome icelake genoa)
ERA=${ERA:-era-2026-09-14-c9ae666}
ANCHORS=${FFT_BENCH_ANCHORS:-/mnt/home/mbarbone/fft_bench_anchors}
MEM_REPO=/mnt/home/mbarbone/repos/memory

fail() { echo "FAIL: $*" >&2; exit 1; }
MODE=submit
[[ ${1:-} == --check ]] && MODE=--check
[[ ${1:-} == --check || -z ${1:-} ]] || fail "usage: $0 [--check]"

ADM_SHA=$(git -C "$REPO/extern/admiral" rev-parse --verify -q HEAD 2>/dev/null) \
  || fail "extern/admiral HEAD unresolvable in $REPO"
FB_SHA=$(git -C "$REPO" rev-parse --verify -q HEAD 2>/dev/null || echo unknown)
SLUG=$(date +%F-%H%M)-adm${ADM_SHA:0:7}
RUN_DIR=$MEM_REPO/admiral/beat-standings/runs/$SLUG
RAW_DIR=/mnt/home/mbarbone/fft_bench_runs/$SLUG

# -------------------------------------------------------------- prerequisites
# Checked in BOTH modes: a plan that green-lights missing inputs is how empty sweeps get
# submitted (fi/perf/submit.sh CPM-cache precedent).
command -v sbatch >/dev/null || fail "no sbatch on PATH (not a slurm login node?)"
command -v md5sum >/dev/null || fail "no md5sum on PATH"
for c in "${CLASSES[@]}"; do
  [[ -f $FI/$c.sbatch ]] || fail "missing $FI/$c.sbatch"
  for b in admiral_bench admiral_cell; do
    [[ -x $REPO/build-$c/$b ]] || fail "missing $REPO/build-$c/$b (run fi/submit_all.sh --check first)"
  done
  for b in admiral_bench admiral_cell; do
    [[ -x $ANCHORS/$ERA/$c/$b ]] || fail "missing anchor $ANCHORS/$ERA/$c/$b (capture the era first)"
  done
done
(cd "$ANCHORS/$ERA" && md5sum -c MD5SUMS >/dev/null) \
  || fail "anchor manifest $ANCHORS/$ERA/MD5SUMS does not verify"
[[ -f $SELF/probe.sbatch && -f $SELF/collect.sbatch ]] || fail "anchor job files missing in $SELF"
[[ -d $MEM_REPO/.git ]] || fail "$MEM_REPO is not a git checkout (logbook)"

time_of() { grep -m1 '^#SBATCH --time=' "$1" | cut -d= -f2 | awk '{print $1}'; }

# ------------------------------------------------------------------ the plan
echo "anchored sweep plan (slug $SLUG)"
echo "  repo:    $REPO @ $FB_SHA"
echo "  admiral: $ADM_SHA"
echo "  era:     $ERA ($ANCHORS/$ERA, MD5SUMS green)"
echo "  receipt: $RUN_DIR   (git-commit by each collect job)"
echo "  raw:     $RAW_DIR (probe per-call jsons, not committed; *.txt policy)"
echo ""
declare -A J P
for c in "${CLASSES[@]}"; do
  J[$c]="\$J_${c}"; P[$c]="\$P_${c}"
done
for c in "${CLASSES[@]}"; do
  echo "  $c:"
  printf '    sweep    sbatch %s.sbatch   # constraint %s&rocky9, time %s, log %s/%s.log\n' \
    "$c" "$c" "$(time_of "$FI/$c.sbatch")" "$FI" "$c"
  printf '    probe    sbatch --dependency=afterok:%s -J fftb-probe-%s --constraint=%s&rocky9 %s/probe.sbatch   # exclusive, time %s, log %s/%s/probe.log\n' \
    "${J[$c]}" "$c" "$c" "$SELF" "$(time_of "$SELF/probe.sbatch")" "$RAW_DIR" "$c"
  printf '    collect  sbatch --dependency=afterok:%s -J fftb-collect-%s %s/collect.sbatch   # 1 cpu, time %s, log %s/%s/collect.log\n' \
    "${P[$c]}" "$c" "$SELF" "$(time_of "$SELF/collect.sbatch")" "$RAW_DIR" "$c"
done
echo ""
echo "  exports probe:   CLASS ERA=$ERA ANCHORS RAW_DIR SWEEP_JOB"
echo "  exports collect: CLASS SLUG RUN_DIR RAW_DIR MEM_REPO SWEEP_JOB PROBE_JOB"
if [[ $MODE == --check ]]; then
  echo ""
  echo "--check: nothing submitted, nothing seeded."
  exit 0
fi

# ---------------------------------------------------------------------- seed
for c in "${CLASSES[@]}"; do mkdir -p "$RAW_DIR/$c" || fail "mkdir $RAW_DIR/$c"; done
mkdir -p "$RUN_DIR" || fail "mkdir $RUN_DIR"
printf 'class\tjob\tid\tnode\telapsed\tstate\texit\n' > "$RUN_DIR/JOBS.tsv"
cat > "$RUN_DIR/README.md" <<EOF
# Standings run $SLUG

- fft_bench @ $FB_SHA ($REPO)
- admiral @ $ADM_SHA
- era anchor: $ERA ($ANCHORS/$ERA, MD5SUMS verified at submission)
- submitted $(date -Is) from $(hostname) by $(whoami)
- per class: sweep (fi/<class>.sbatch) -> afterok anchor-probe (fi/anchor/probe.sbatch,
  pinned 12-rep ABAB vs the era anchor, wobble 1d 2^18..20 + granule 2d 12^2/24^2)
  -> afterok collect (this receipt, JOBS.tsv, per-class jsons and probe tables below)
- sweep sbatches also carry the admiral2 same-binary control arm; the floor prints in
  \`fi/geomean_table.py\`.

Job ids/durations land in JOBS.tsv (sacct, appended by each collect job). Reduce:

    fi/geomean_table.py fi/baseline-2026-09-11-e61ae17      # standings + per-cell deltas
    fi/geomean_table.py                                     # floor column from admiral2

Charts + pushes are login-side: fi/submit_all.sh --plots, then commit/push fft_bench;
push this logbook repo.
EOF
echo "seeded $RUN_DIR"

# -------------------------------------------------------------------- submit
cd "$FI" || fail "no $FI"
for c in "${CLASSES[@]}"; do
  out=$(sbatch "$c.sbatch") || fail "sbatch $c.sbatch: $out"
  J[$c]=${out##* }
  [[ ${J[$c]} =~ ^[0-9]+$ ]] || fail "unparsable sbatch output for $c: $out"
  out=$(sbatch --dependency="afterok:${J[$c]}" -J "fftb-probe-$c" \
            --constraint="$c&rocky9" -o "$RAW_DIR/$c/probe.log" \
            --export="ALL,CLASS=$c,ERA=$ERA,ANCHORS=$ANCHORS,RAW_DIR=$RAW_DIR,SWEEP_JOB=${J[$c]}" \
            "$SELF/probe.sbatch") || fail "sbatch probe $c: $out"
  P[$c]=${out##* }
  [[ ${P[$c]} =~ ^[0-9]+$ ]] || fail "unparsable sbatch output for probe $c: $out"
  out=$(sbatch --dependency="afterok:${P[$c]}" -J "fftb-collect-$c" \
            -o "$RAW_DIR/$c/collect.log" \
            --export="ALL,CLASS=$c,SLUG=$SLUG,RUN_DIR=$RUN_DIR,RAW_DIR=$RAW_DIR,MEM_REPO=$MEM_REPO,SWEEP_JOB=${J[$c]},PROBE_JOB=${P[$c]}" \
            "$SELF/collect.sbatch") || fail "sbatch collect $c: $out"
  C=${out##* }
  [[ $C =~ ^[0-9]+$ ]] || fail "unparsable sbatch output for collect $c: $out"
  printf '  %-8s sweep %-10s probe %-10s collect %s\n' "$c" "${J[$c]}" "${P[$c]}" "$C"
done
echo ""
echo "watch:    squeue -u \$USER"
echo "logs:     $FI/{rome,icelake,genoa}.log and $RAW_DIR/<class>/{probe,collect}.log"
echo "markers:  PROBE_DONE / COLLECT_DONE <class> (DependencyNeverSatisfied = a parent failed)"
echo "receipt:  $RUN_DIR"
echo "cadence:  the 256-cpu QOS cap runs two sweep jobs at once; the third pends and its"
echo "          probe/collect chain fires whenever it lands. Nothing needs babysitting."
