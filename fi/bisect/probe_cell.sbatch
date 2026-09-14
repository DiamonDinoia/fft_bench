#!/bin/bash
#SBATCH --partition=gen
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --cpus-per-task=2
#SBATCH --time=00:25:00
#SBATCH --job-name=fftb-bisect
# fftb-bisect: is admiral @ SHA anchor-class (SLOW) or FAST-class at the WI-1c cells?
# Pinned A/B of the ERA ANCHOR binary against ONE bisect build, on an exclusive node.
#
# Protocol (fi/anchor/probe.sbatch arm structure; run_probe5/run_probe6 precedent,
# ~/bisect-regression): whole node exclusive, pinned to one physical core, 12 rounds
# per cell with arm order alternating ABAB, both arms md5-tagged, evidence header +
# per-call TSV + sinks, reduction at the end.
#
# Harness: admiral_cell = src/perf_cell.cpp, the same plan path the sweep exercises
# (plan<double>({n,n}, {nthreads=1, effort::measure}), out-of-place) — but with fixed
# rep counts and a min-over-rounds statistic instead of gbench's adaptive loop, so a
# probe neither drifts with gbench's min-time heuristic nor re-plans per rep.
#
# Cells (all f64, matching the sweep's ST f64-only grid):
#   (2,1024)  the regression cell (admiral moved 8322.8 -> 9927.0 us, e61-base -> era)
#   (2,512)   flank 4x smaller (moved 1379.5 -> 1282.8: control, improved)
#   (2,2048)  flank 4x larger  (moved 40171.7 -> 41397.3: control, ~3%)
# Per-cell invocation covers ~7-9 s of measured rounds (rounds=3, reps scaled by the
# era anchor's swept per-execute time), so 72 invocations fit in ~10-13 min; the 25 min
# budget leaves plan/startup slack. Override via env REPS_512/REPS_1024/REPS_2048/ROUNDS
# (e.g. double the regression cell's reps when a sha lands in the gray band).
#
# Submitted only by fi/bisect/bisect_sha.sh --submit (or the printed sbatch line), which
# exports SHA7 SHA CLASS BISECT_TREE ERA ANCHORS RUN_DIR BISECT_DIR and passes
# --constraint=<class>&rocky9 (this file carries none: a stale one books the wrong pool).
set -uo pipefail

for v in SHA7 SHA CLASS BISECT_TREE ERA ANCHORS RUN_DIR BISECT_DIR; do
  [[ -n ${!v:-} ]] || { echo "BISECT_FAIL: \$$v unset (submit via fi/bisect/bisect_sha.sh)"; exit 1; }
done
RUN=$RUN_DIR/$SHA7
mkdir -p "$RUN/raw" || { echo "BISECT_FAIL: mkdir $RUN"; exit 1; }

module purge
module load modules/2.5-beta1 gcc/14.3.0 fftw/3.3.11 intel-oneapi-mkl/2026.0.0 \
  || { echo "BISECT_FAIL: toolchain modules did not load"; exit 1; }
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1

A_CELL=$ANCHORS/$ERA/$CLASS/admiral_cell       # era arm (683a697, SLOW class at (2,1024))
P_CELL=$BISECT_TREE/admiral_cell               # the sha under test
for f in "$A_CELL" "$P_CELL"; do
  [[ -x $f ]] || { echo "BISECT_FAIL: missing $f"; exit 1; }
done
# The store is the anchor: if a byte moved, this probe's "anchor" arm is not the era.
(cd "$ANCHORS/$ERA" && md5sum -c MD5SUMS >/dev/null) \
  || { echo "BISECT_FAIL: $ANCHORS/$ERA/MD5SUMS does not verify"; exit 1; }

# Pinning block copied verbatim from fi/anchor/probe.sbatch (lines 50-70) so the two
# probes keep ONE spelling: pin to one physical core of the job's allocation; a second
# core on ANOTHER physical core receives the shell's own work.
read -r MEAS OTHER <<<"$(python3 - <<'PY'
cpus=set()
for ln in open('/proc/self/status'):
    if ln.startswith('Cpus_allowed_list'):
        for part in ln.split(':',1)[1].strip().split(','):
            lo,_,hi = part.partition('-')
            cpus.update(range(int(lo), int(hi or lo)+1))
import subprocess
core_of={}
for ln in subprocess.check_output(['lscpu','-e=CPU,CORE']).decode().splitlines():
    parts = ln.replace(',', ' ').split()
    try: core_of[int(parts[0])] = int(parts[1])
    except (ValueError, IndexError): continue
allowed = sorted(cpus)
meas = allowed[0]
other = next((c for c in allowed[1:] if core_of.get(c) != core_of.get(meas)), meas)
print(meas, other)
PY
)"

{
echo "=== fftb-bisect $CLASS $SHA7 evidence header ==="
date -Is
hostname
lscpu | grep 'Model name' || true
echo "job: bisect probe $SLURM_JOB_ID (WI-1c, rome (2,1024) f64, e61ae17..a799b6b)"
echo "era: $ERA ($ANCHORS/$ERA, MD5SUMS verified)"
echo "pin: measure cpu $MEAS (physical core $(lscpu -e=CPU,CORE | tr ',' ' ' | awk -v c="$MEAS" '$1==c {print $2}')), shell cpu $OTHER"
echo "arms: anchor=$A_CELL"
echo "      probe =$P_CELL  (admiral $SHA, build tree $BISECT_TREE)"
md5sum "$A_CELL" "$P_CELL" "$ANCHORS/$ERA/$CLASS/admiral_bench" "$BISECT_TREE/admiral_bench"
[[ $(md5sum < "$A_CELL") == $(md5sum < "$P_CELL") ]] \
  && echo "note: anchor and probe admiral_cell are md5-identical; probe is a same-binary control"
module list 2>&1
} | tee "$RUN/evidence_header.md"

TSV=$RUN/results.tsv
printf 'cell\trep\tarm\tus\n' > "$TSV"

ROUNDS=${ROUNDS:-3}
REPS_512=${REPS_512:-2000}     # ~1.28 ms/execute at the era anchor -> ~7.7 s
REPS_1024=${REPS_1024:-300}    # ~9.9 ms/execute -> ~8.9 s
REPS_2048=${REPS_2048:-60}     # ~41 ms/execute -> ~7.4 s
reps_of() { case $1 in 512) echo "$REPS_512";; 1024) echo "$REPS_1024";; 2048) echo "$REPS_2048";; esac; }

run_cell() {  # $1=n_per_dim $2=arm $3=bin $4=rep   (2-D f64 cell via admiral_cell)
  local n=$1 arm=$2 bin=$3 rep=$4 out err us sink
  out=$RUN/raw/2d_${n}_rep$(printf %02d "$rep")_$arm.out
  err=$out.stderr
  taskset -c "$MEAS" "$bin" 2 "$n" 1 "$(reps_of "$n")" "$ROUNDS" > "$out" 2> "$err" \
    || { echo "BISECT_FAIL: $bin 2 $n exited $?"; exit 1; }
  us=$(cat "$out")
  sink=$(sed -n 's/.*sink=\([0-9.eE+-]*\).*/\1/p' "$err")
  [[ -n $us && -n $sink ]] || { echo "BISECT_FAIL: no timing/sink in $out/$err"; exit 1; }
  [[ $sink != 0 && $sink != 0.0 ]] || { echo "BISECT_FAIL: zero sink in $err (timed nothing)"; exit 1; }
  printf '2d_%d^2\t%d\t%s\t%s\n' "$n" "$rep" "$arm" "$us" >> "$TSV"
  printf '2d_%d^2\t%d\t%s\tsink=%s\n' "$n" "$rep" "$arm" "$sink" >> "$RUN/sinks.txt"
}

echo "# cells: (2,1024) regression, (2,512) and (2,2048) context; reps $REPS_1024 $REPS_512 $REPS_2048, rounds $ROUNDS" \
  | tee -a "$RUN/evidence_header.md"
for rep in $(seq 1 12); do
  if (( rep % 2 == 1 )); then anchor_first=1; else anchor_first=0; fi
  # regression cell first: if the node dies mid-job the deciding cell is already in
  for n in 1024 512 2048; do
    if (( anchor_first )); then
      run_cell "$n" anchor "$A_CELL" "$rep"; run_cell "$n" probe "$P_CELL" "$rep"
    else
      run_cell "$n" probe "$P_CELL" "$rep"; run_cell "$n" anchor "$A_CELL" "$rep"
    fi
  done
  echo "[rep $rep done $(date +%T)]"
done

# Facts-only reduction (per cell: median and min per arm, ratios, ranges). The verdict
# belongs to fi/bisect/README.md's decision rule, applied by the reader.
"$BISECT_DIR/reduce_cell.py" "$TSV" || { echo "BISECT_FAIL: reduce_cell.py rejected $TSV"; exit 1; }

touch "$RUN/BISECT_DONE"
echo "BISECT_DONE $CLASS $SHA7"
