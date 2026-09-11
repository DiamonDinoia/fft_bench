#!/bin/bash
#SBATCH --partition=gen
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --cpus-per-task=128
#SBATCH --job-name=adm-item2
#SBATCH --output=rome_item2.log
#SBATCH --constraint=rome&rocky9
#SBATCH --time=04:00:00
#
# Item 2 step 1: does admiral's SERIAL large-1-D route really move about twice the
# memory traffic of its own threaded route?
#
# `fsl_ws_engaged` is `pool != nullptr && pool->size() > 1`, so `execute_ws` (2 passes)
# is unreachable at one thread and `execute` (4 passes) runs instead. The two arms below
# are the same plan on the same host at the same size, differing only in that gate, and
# `PERF_CELL_DEBUG=2` makes each arm print which of the two it took. If the counters do
# not separate by about 2x, the pass-count trace is wrong and item 2 re-plans.
#
# The threaded arm occupies two cores. Bytes moved per transform does not depend on that;
# wall clock does, so the timing rows below compare admiral-serial against fftw3 only.
#
# Build (on a rocky9 workstation, modules as below):
#   cmake -S .. -B ../build-perf-rome -G Ninja -DCMAKE_BUILD_TYPE=Release -DBENCH_ARCH=znver2
#   cmake --build ../build-perf-rome --target admiral_cell fftw3_cell mkl_cell
set -uo pipefail

module purge
module load modules/2.5-beta1 gcc/14.3.0 fftw/3.3.11 intel-oneapi-mkl/2026.0.0
module list 2>&1

BT=$SLURM_SUBMIT_DIR/../../build-perf-rome
source "$SLURM_SUBMIT_DIR/perf_lib.sh"
export LOGERR=$SLURM_SUBMIT_DIR/rome_item2.stderr
: > "$LOGERR"
# admiral's route trace is emitted by EXECUTE, not by plan construction, so exporting
# PERF_CELL_DEBUG for the whole job pays two fprintf calls to a GPFS-backed stderr inside
# every timed transform. At 1-D 1024 that read 38 us per execute against a real ~1 us, and
# MKL ignores the variable, so the comparison measured admiral's logging against MKL's
# transform. Record the route once per cell with `route_of` and keep it unset elsewhere.
# FFTW_MEASURE at 2^24 costs minutes. Pay it once per size into a wisdom file on GPFS, then
# every later fftw3 process plans the same transform in milliseconds.
export PERF_CELL_WISDOM=$SLURM_SUBMIT_DIR/rome_item2.wisdom

env_report
echo "TREE,$BT"
echo "ADMIRAL,$(git -C "$SLURM_SUBMIT_DIR/../../extern/admiral" log -1 --oneline 2>&1)"

# Two cores of one CCX for the threaded arm; core 0 alone for every serial arm.
SER=0
WS=0-1

# The node's own event names, for a follow-up job that wants the data-fabric PMU.
echo "--- perf list, memory-side PMUs"
perf list 2>/dev/null | grep -iE 'amd_df|amd_l3|umc|dram' | head -40
echo "--- end perf list"

G1=$(probe_events cycles instructions task-clock page-faults)
G2=$(probe_events ls_any_fills_from_sys.mem_io_local ls_any_fills_from_sys.ext_cache_remote \
                  ls_any_fills_from_sys.int_cache ls_any_fills_from_sys.lcl_l2)
G3=$(probe_events l3_comb_clstr_state.request_miss cache-references cache-misses)
G4=$(probe_events LLC-loads LLC-load-misses LLC-stores LLC-store-misses)
report_events G1 "cycles,instructions,task-clock,page-faults" "$G1"
report_events G2 "ls_any_fills_from_sys.*" "$G2"
report_events G3 "l3_comb_clstr_state.request_miss,cache-references,cache-misses" "$G3"
report_events G4 "LLC-*" "$G4"

# --------------------------------------------------------------- fftw wisdom
for e in 21 22 23 24 25; do
  N=$((1 << e))
  s=$SECONDS
  taskset -c "$SER" "$BT/fftw3_cell" 1 "$N" 1 1 1 >/dev/null 2>>"$LOGERR"
  echo "WISDOM,$N,$((SECONDS - s))s"
done

# ---------------------------------------------------------------- counters
# Every cell runs at reps R and 3R. The difference over 2R is per-execute work with process
# startup, plan construction and first-touch page-in cancelled.
for e in 21 22 23 24 25; do
  N=$((1 << e))
  R=$(reps_for "$N")
  echo "SIZE,$N,reps,$R,$((3 * R))"
  # The pass-count question IS which route each arm took, so both arms are recorded.
  route_of "adm_serial:$N" "$SER" "$BT/admiral_cell" 1 "$N" 1
  route_of "adm_ws:$N"     "$WS"  "$BT/admiral_cell" 1 "$N" 2
  for G in "$G1" "$G2" "$G3" "$G4"; do
    [[ -z "$G" ]] && continue
    for r in "$R" $((3 * R)); do
      perf_run "adm_serial:$N" "$SER" "$BT/admiral_cell" 1 "$N" 1 "$r" "$G"
      perf_run "adm_ws:$N"     "$WS"  "$BT/admiral_cell" 1 "$N" 2 "$r" "$G"
    done
  done
  # fftw3 is the competitor the 1.86x gap is measured against, so it gets the same two rep
  # counts; wisdom has already made its planning free. It skips the port and L3 groups.
  for G in "$G1" "$G2"; do
    [[ -z "$G" ]] && continue
    for r in "$R" $((3 * R)); do
      perf_run "fftw3:$N" "$SER" "$BT/fftw3_cell" 1 "$N" 1 "$r" "$G"
    done
  done
done

# ------------------------------------------------------------------ timing
# Three rounds, arm order rotated each round, minimum over rounds inside each process.
for round in 1 2 3; do
  for e in 21 22 23 24 25; do
    N=$((1 << e))
    R=$(reps_for "$N")
    arms=(adm_serial adm_ws fftw3 mkl)
    for i in 0 1 2 3; do
      case "${arms[$(( (i + round) % 4 ))]}" in
        adm_serial) time_run "adm_serial:$N:r$round" "$SER" "$BT/admiral_cell" 1 "$N" 1 "$R" 5 ;;
        adm_ws)     time_run "adm_ws:$N:r$round"     "$WS"  "$BT/admiral_cell" 1 "$N" 2 "$R" 5 ;;
        fftw3)      time_run "fftw3:$N:r$round"      "$SER" "$BT/fftw3_cell"   1 "$N" 1 "$R" 5 ;;
        mkl)        time_run "mkl:$N:r$round"        "$SER" "$BT/mkl_cell"     1 "$N" 1 "$R" 5 ;;
      esac
    done
  done
done

echo "ITEM2_DONE"
