#!/bin/bash
#SBATCH --partition=gen
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --cpus-per-task=64
#SBATCH --job-name=adm-item3
#SBATCH --output=icelake_item3.log
#SBATCH --constraint=icelake&rocky9
#SBATCH --time=06:00:00
#
# Item 3: admiral loses the icelake geomean to MKL, 1.227 over 26 of 36 single-thread cells.
# A broad loss is either more executed work or more stalling on the same work, and those have
# different fixes. This job collects both sides for every cell rather than for a chosen three,
# because choosing three first needs the bucketing this job produces.
#
# Every cell is one process, one library, one shape, one thread, so a counter belongs to that
# cell alone. Each cell runs at reps R and 3R; the difference over 2R removes process startup,
# plan construction and first-touch page-in. Nothing is reduced here: the log carries raw rows.
#
# Build (on a rocky9 workstation, modules as below):
#   cmake -S .. -B ../build-icelake -G Ninja -DCMAKE_BUILD_TYPE=Release -DBENCH_ARCH=icelake-server
#   cmake --build ../build-icelake --target admiral_cell mkl_cell fftw3_cell
set -uo pipefail

module purge
module load modules/2.5-beta1 gcc/14.3.0 fftw/3.3.11 intel-oneapi-mkl/2026.0.0
module list 2>&1

BT=$SLURM_SUBMIT_DIR/../../build-icelake
source "$SLURM_SUBMIT_DIR/perf_lib.sh"
export LOGERR=$SLURM_SUBMIT_DIR/icelake_item3.stderr
: > "$LOGERR"
export PERF_CELL_DEBUG=2

env_report
echo "TREE,$BT"
echo "ADMIRAL,$(git -C "$SLURM_SUBMIT_DIR/../../extern/admiral" log -1 --oneline 2>&1)"

CPU=0

# Port-pressure event names differ between Skylake-SP and Icelake-SP. Probe both spellings and
# keep whatever this node answers; an unprobed name would run nothing and cost the whole group.
G1=$(probe_events cycles instructions task-clock branch-misses)
G2=$(probe_events mem_load_retired.l1_miss mem_load_retired.l2_miss mem_load_retired.l3_miss \
                  l2_rqsts.miss longest_lat_cache.miss)
G3=$(probe_events uops_executed.thread uops_issued.any idq_uops_not_delivered.core \
                  uops_retired.slots)
G4=$(probe_events uops_dispatched.port_0 uops_dispatched.port_1 uops_dispatched.port_2_3 \
                  uops_dispatched.port_4_9 uops_dispatched.port_5 uops_dispatched.port_6 \
                  uops_dispatched.port_7_8 uops_dispatched_port.port_0 \
                  uops_dispatched_port.port_1 uops_dispatched_port.port_5)
G5=$(probe_events cycle_activity.stalls_total cycle_activity.stalls_l1d_miss \
                  cycle_activity.stalls_l2_miss cycle_activity.stalls_l3_miss \
                  cycle_activity.stalls_mem_any)
report_events G1 "cycles,instructions,task-clock,branch-misses" "$G1"
report_events G2 "mem_load_retired.*,l2_rqsts.miss,longest_lat_cache.miss" "$G2"
report_events G3 "uops_executed/issued/retired" "$G3"
report_events G4 "uops_dispatched.port_*" "$G4"
report_events G5 "cycle_activity.stalls_*" "$G5"

echo "--- perf list, memory-side PMUs"
perf list 2>/dev/null | grep -iE 'uncore_imc|cas_count' | head -20
echo "--- end perf list"

# The 36 single-thread cells of the standings harness: src/fft_bench.cpp:179-219.
CELLS=""
for e in $(seq 8 25);  do CELLS="$CELLS 1:$((1 << e))"; done
for e in $(seq 4 13);  do CELLS="$CELLS 2:$((1 << e))"; done
for e in $(seq 2 9);   do CELLS="$CELLS 3:$((1 << e))"; done

# ---------------------------------------------------------------- counters
for cell in $CELLS; do
  D=${cell%%:*}; N1=${cell##*:}
  TOT=1; for ((i = 0; i < D; ++i)); do TOT=$((TOT * N1)); done
  R=$(reps_for "$TOT")
  echo "CELL,$D,$N1,elems,$TOT,reps,$R,$((3 * R))"
  for G in "$G1" "$G2" "$G3" "$G4" "$G5"; do
    [[ -z "$G" ]] && continue
    for r in "$R" $((3 * R)); do
      perf_run "adm:${D}d:$N1" "$CPU" "$BT/admiral_cell" "$D" "$N1" 1 "$r" "$G"
      perf_run "mkl:${D}d:$N1" "$CPU" "$BT/mkl_cell"     "$D" "$N1" 1 "$r" "$G"
    done
  done
done

# ------------------------------------------------------------------ timing
# The ratio per cell is what buckets the 26 losses. Three rounds, arm order swapped each round.
for round in 1 2 3; do
  for cell in $CELLS; do
    D=${cell%%:*}; N1=${cell##*:}
    TOT=1; for ((i = 0; i < D; ++i)); do TOT=$((TOT * N1)); done
    R=$(reps_for "$TOT")
    if (( round % 2 == 1 )); then
      time_run "adm:${D}d:$N1:r$round" "$CPU" "$BT/admiral_cell" "$D" "$N1" 1 "$R" 5
      time_run "mkl:${D}d:$N1:r$round" "$CPU" "$BT/mkl_cell"     "$D" "$N1" 1 "$R" 5
    else
      time_run "mkl:${D}d:$N1:r$round" "$CPU" "$BT/mkl_cell"     "$D" "$N1" 1 "$R" 5
      time_run "adm:${D}d:$N1:r$round" "$CPU" "$BT/admiral_cell" "$D" "$N1" 1 "$R" 5
    fi
  done
done

echo "ITEM3_DONE"
