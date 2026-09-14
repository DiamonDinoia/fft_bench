#!/bin/bash
#SBATCH --partition=gen
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=00:10:00
#SBATCH --constraint=rocky9
#SBATCH --job-name=fftb-collect
# fftb-collect: per-class run collector, chained afterok the anchor-probe job. Workers
# are offline but GPFS (/mnt/home) is shared and git commit is local, so the durable
# copy happens HERE, not login-side:
#   1. class sweep jsons ($SLURM_SUBMIT_DIR/*-$CLASS.json) -> run dir in the logbook
#   2. probe evidence header + results.tsv from the GPFS raw dir -> run dir
#   3. probe per-cell medians reduced into the receipt README.md
#   4. sacct ids/durations for sweep+probe+collect appended to JOBS.tsv
#   5. git commit of the run dir ONLY (never other paths; index-lock failure is loud:
#      the files are already on disk, the commit can be redone login-side)
# Charts and pushes are login-side by the user (fft_bench push pre-authorized).
#
# Submitted only by fi/anchor/submit_chain.sh, which exports CLASS, SLUG, RUN_DIR,
# RAW_DIR, MEM_REPO, SWEEP_JOB, PROBE_JOB.
set -uo pipefail

for v in CLASS SLUG RUN_DIR RAW_DIR MEM_REPO SWEEP_JOB PROBE_JOB; do
  [[ -n ${!v:-} ]] || { echo "COLLECT_FAIL: \$$v unset (submit via fi/anchor/submit_chain.sh)"; exit 1; }
done
fail() { echo "COLLECT_FAIL: $*" >&2; exit 1; }

DEST=$RUN_DIR
PROBE_DEST=$RUN_DIR/probe/$CLASS
mkdir -p "$PROBE_DEST" || fail "mkdir $PROBE_DEST"

# --- 1: class jsons (the whole point of the chain; a missing set is a failure).
# Flat <impl>-<class>.json layout, era-style, so `fi/geomean_table.py <run-dir>` works.
n=0
for j in "$SLURM_SUBMIT_DIR"/*-"$CLASS".json; do
  [[ -f $j ]] || continue
  cp -p "$j" "$DEST/" || fail "cp $j"
  n=$((n+1))
done
(( n >= 12 )) || fail "only $n *-$CLASS.json in $SLURM_SUBMIT_DIR (sweep incomplete?)"
echo "collected $n $CLASS jsons -> $DEST"

# --- 2 + 3: probe artifacts and reduced table
if [[ -f $RAW_DIR/$CLASS/probe/results.tsv ]]; then
  cp "$RAW_DIR/$CLASS/probe/evidence_header.md" "$PROBE_DEST/" 2>/dev/null \
    || fail "cp evidence header"
  cp "$RAW_DIR/$CLASS/probe/results.tsv" "$PROBE_DEST/" || fail "cp results.tsv"
  {
    echo ""
    echo "### $CLASS anchor-probe (median of 12 alternating reps; raw tsv in probe/)"
    echo ""
    echo "| cell | anchor us | sweep us | ratio | anchor range | sweep range |"
    echo "|---|---|---|---|---|---|"
    python3 - "$RAW_DIR/$CLASS/probe/results.tsv" <<'PY'
import statistics, sys
rows = [ln.split('\t') for ln in open(sys.argv[1]).read().splitlines()[1:]]
cells = []
for c, *_ in rows:
    if c not in cells: cells.append(c)
for c in cells:
    a = [float(r[3]) for r in rows if r[0] == c and r[2] == 'anchor']
    s = [float(r[3]) for r in rows if r[0] == c and r[2] == 'sweep']
    ma, ms = statistics.median(a), statistics.median(s)
    print(f'| {c} | {ma:.3f} | {ms:.3f} | {ms/ma:.4f} | '
          f'{min(a):.3f}..{max(a):.3f} | {min(s):.3f}..{max(s):.3f} |')
PY
  } >> "$RUN_DIR/README.md" || fail "append probe table"
  echo "probe table reduced into README.md"
else
  echo "COLLECT_WARN: no probe results.tsv at $RAW_DIR/$CLASS/probe;.jsons-only collect"
fi

# --- 4: sacct rows (read-only accounting; allowed inside a job)
if command -v sacct >/dev/null; then
  rows=$(sacct -j "$SWEEP_JOB,$PROBE_JOB,$SLURM_JOB_ID" \
               --format=JobID,JobName%18,NodeList%16,Elapsed,State,ExitCode -P -n \
               2>/dev/null | grep -v '\.') || rows=""
  if [[ -n $rows ]]; then
    while IFS='|' read -r jid jname node elapsed state exitc; do
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$CLASS" "$jname" "${jid%.*}" "$node" "$elapsed" "$state" "$exitc" >> "$RUN_DIR/JOBS.tsv"
    done <<< "$rows"
    echo "JOBS.tsv: $(wc -l < "$RUN_DIR/JOBS.tsv") rows"
  else
    printf '%s\tsweep\t%s\t?\tPENDING\t?\t?\n' "$CLASS" "$SWEEP_JOB" >> "$RUN_DIR/JOBS.tsv"
    printf '%s\tprobe\t%s\t?\tPENDING\t?\t?\n' "$CLASS" "$PROBE_JOB" >> "$RUN_DIR/JOBS.tsv"
    echo "COLLECT_WARN: sacct returned no rows on this node; ids recorded with PENDING"
  fi
else
  printf '%s\tsweep\t%s\t?\tPENDING\t?\t?\n' "$CLASS" "$SWEEP_JOB" >> "$RUN_DIR/JOBS.tsv"
  printf '%s\tprobe\t%s\t?\tPENDING\t?\t?\n' "$CLASS" "$PROBE_JOB" >> "$RUN_DIR/JOBS.tsv"
  echo "COLLECT_WARN: no sacct on this node; refresh login-side: sacct -j $SWEEP_JOB,$PROBE_JOB,$SLURM_JOB_ID"
fi

# --- 5: local commit of THIS run dir only. Never staged foreign changes, never push.
REL=${RUN_DIR#"$MEM_REPO"/}
[[ $REL != "$RUN_DIR" ]] || fail "RUN_DIR $RUN_DIR not under MEM_REPO $MEM_REPO"
git -C "$MEM_REPO" add -- "$REL" || fail "git add $REL"
git -C "$MEM_REPO" commit --only -m \
    "admiral bench-results: $SLUG $CLASS (sweep $SWEEP_JOB, probe $PROBE_JOB)" -- "$REL" \
  || fail "git commit $REL (index lock?); files are on disk in $RUN_DIR — commit login-side"
echo "COLLECT_DONE $CLASS ($(git -C "$MEM_REPO" rev-parse --short HEAD))"
