#!/bin/bash
#SBATCH --partition=gen
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --cpus-per-task=2
#SBATCH --time=00:30:00
#SBATCH --job-name=fftb-probe
# fftb-probe: is this sweep's binary era-class? Pinned A/B of the ERA ANCHOR binaries
# against THIS submission's freshly built binaries, chained afterok the class sweep job.
#
# Protocol (run_probe5/run_probe6 precedent, ~/bisect-regression): whole node exclusive,
# pinned to one physical core, 12 rounds per cell with arm order alternating ABAB, both
# arms md5-tagged, evidence header + per-call TSV, medians reduced at the end.
#
# Cells:
#   wobble:  1-D 2^18/2^19/2^20 via admiral_bench --benchmark_filter (the documented
#            sweep-wobble band; 2^19 flipped 1.099/1.189 between full-node draws while
#            pinned probes read 1.020/0.995 on the same nodes).
#   granule: 2-D 12x12 and 24x24 via admiral_cell (granule AoS leaf admission is
#            N==12||N==24, f64; the pow2-only sweep never measures them).
#
# Submitted only by fi/anchor/submit_chain.sh, which exports CLASS, ERA, ANCHORS,
# RAW_DIR, SWEEP_JOB and passes --constraint=<class>&rocky9 (this file carries none: the
# class dirs differ per class and a stale one silently books the wrong node pool).
set -uo pipefail

for v in CLASS ERA ANCHORS RAW_DIR SWEEP_JOB; do
  [[ -n ${!v:-} ]] || { echo "PROBE_FAIL: \$$v unset (submit via fi/anchor/submit_chain.sh)"; exit 1; }
done
RUN=$RAW_DIR/$CLASS/probe
mkdir -p "$RUN/json" || { echo "PROBE_FAIL: mkdir $RUN"; exit 1; }

module purge
module load modules/2.5-beta1 gcc/14.3.0 fftw/3.3.11 intel-oneapi-mkl/2026.0.0 \
  || { echo "PROBE_FAIL: toolchain modules did not load"; exit 1; }
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1

A_BENCH=$ANCHORS/$ERA/$CLASS/admiral_bench
A_CELL=$ANCHORS/$ERA/$CLASS/admiral_cell
N_BENCH=$SLURM_SUBMIT_DIR/../build-$CLASS/admiral_bench
N_CELL=$SLURM_SUBMIT_DIR/../build-$CLASS/admiral_cell
for f in "$A_BENCH" "$A_CELL" "$N_BENCH" "$N_CELL"; do
  [[ -x $f ]] || { echo "PROBE_FAIL: missing $f"; exit 1; }
done
# The store is the anchor: if a byte moved, this probe's "era" arm is not the era.
(cd "$ANCHORS/$ERA" && md5sum -c MD5SUMS >/dev/null) \
  || { echo "PROBE_FAIL: $ANCHORS/$ERA/MD5SUMS does not verify"; exit 1; }

# Pin to one physical core of the job's allocation; a second core on ANOTHER physical
# core receives the shell's own work. Never trust the first allowed cpu to be alone.
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
echo "=== fftb-probe $CLASS evidence header ==="
date -Is
hostname
lscpu | grep 'Model name' || true
echo "job: probe $SLURM_JOB_ID afterok sweep $SWEEP_JOB"
echo "era: $ERA ($ANCHORS/$ERA, MD5SUMS verified)"
echo "pin: measure cpu $MEAS (physical core $(lscpu -e=CPU,CORE | tr ',' ' ' | awk -v c="$MEAS" '$1==c {print $2}')), shell cpu $OTHER"
echo "arms: anchor=$A_BENCH $A_CELL"
echo "      sweep =$N_BENCH $N_CELL"
md5sum "$A_BENCH" "$A_CELL" "$N_BENCH" "$N_CELL"
[[ $(md5sum < "$A_BENCH") == $(md5sum < "$N_BENCH") ]] \
  && echo "note: anchor and sweep admiral_bench are md5-identical; probe is a same-binary control"
module list 2>&1
} | tee "$RUN/evidence_header.md"

TSV=$RUN/results.tsv
printf 'cell\trep\tarm\tus\n' > "$TSV"

parse_rt() {  # first non-aggregate row of a google-bench json
  python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
for b in d['benchmarks']:
    if 'aggregate_name' not in b:
        print(b['real_time']); break
" "$1"
}

run_bench() { # $1=pow $2=arm $3=bin $4=rep
  local pw=$1 arm=$2 bin=$3 rep=$4 js
  js=$RUN/json/1d_${pw}_rep$(printf %02d "$rep")_$arm.json
  taskset -c "$MEAS" "$bin" --benchmark_filter="run_fft<1 << $pw, 1>\$" \
      --benchmark_repetitions=1 --benchmark_format=json --benchmark_time_unit=us \
      > "$js" 2> "$js.stderr"
  local rt; rt=$(parse_rt "$js")
  [[ -n $rt ]] || { echo "PROBE_FAIL: no real_time in $js"; exit 1; }
  printf '1d_2^%d\t%d\t%s\t%s\n' "$pw" "$rep" "$arm" "$rt" >> "$TSV"
}

run_cell() {  # $1=n_per_dim $2=arm $3=bin $4=rep   (2-D granule cell via admiral_cell)
  local n=$1 arm=$2 bin=$3 rep=$4 out err us sink
  out=$RUN/json/2d_${n}_rep$(printf %02d "$rep")_$arm.out
  err=$out.stderr
  taskset -c "$MEAS" "$bin" 2 "$n" 1 20000 5 > "$out" 2> "$err" \
    || { echo "PROBE_FAIL: $bin 2 $n exited $?"; exit 1; }
  us=$(cat "$out")
  sink=$(sed -n 's/.*sink=\([0-9.eE+-]*\).*/\1/p' "$err")
  [[ -n $us && -n $sink ]] || { echo "PROBE_FAIL: no timing/sink in $out/$err"; exit 1; }
  [[ $sink != 0 && $sink != 0.0 ]] || { echo "PROBE_FAIL: zero sink in $err (timed nothing)"; exit 1; }
  printf '2d_%d^2\t%d\t%s\t%s\n' "$n" "$rep" "$arm" "$us" >> "$TSV"
  printf '2d_%d^2\t%d\t%s\tsink=%s\n' "$n" "$rep" "$arm" "$sink" >> "$RUN/sinks.txt"
}

for rep in $(seq 1 12); do
  if (( rep % 2 == 1 )); then anchor_first=1; else anchor_first=0; fi
  for pw in 18 19 20; do
    if (( anchor_first )); then
      run_bench "$pw" anchor "$A_BENCH" "$rep"; run_bench "$pw" sweep "$N_BENCH" "$rep"
    else
      run_bench "$pw" sweep "$N_BENCH" "$rep"; run_bench "$pw" anchor "$A_BENCH" "$rep"
    fi
  done
  for n in 12 24; do
    if (( anchor_first )); then
      run_cell "$n" anchor "$A_CELL" "$rep"; run_cell "$n" sweep "$N_CELL" "$rep"
    else
      run_cell "$n" sweep "$N_CELL" "$rep"; run_cell "$n" anchor "$A_CELL" "$rep"
    fi
  done
  echo "[rep $rep done $(date +%T)]"
done

# Per cell: median per arm, ratio sweep/anchor, per-arm spread. Printed and copied to the
# run receipt by the collect job; medians because the cells wobble by draw, not trend.
python3 - "$TSV" <<'PY'
import statistics, sys
rows = [ln.split('\t') for ln in open(sys.argv[1]).read().splitlines()[1:]]
cells = []
for c, *_ in rows:
    if c not in cells: cells.append(c)
for c in cells:
    a = [float(r[3]) for r in rows if r[0] == c and r[2] == 'anchor']
    s = [float(r[3]) for r in rows if r[0] == c and r[2] == 'sweep']
    ma, ms = statistics.median(a), statistics.median(s)
    print(f'PROBE_CELL,{c},anchor_med_us={ma:.3f},sweep_med_us={ms:.3f},'
          f'ratio={ms/ma:.4f},anchor_range={min(a):.3f}..{max(a):.3f},'
          f'sweep_range={min(s):.3f}..{max(s):.3f}')
PY

echo PROBE_DONE
