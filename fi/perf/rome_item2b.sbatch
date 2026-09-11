#!/bin/bash
#SBATCH --partition=gen
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --cpus-per-task=128
#SBATCH --job-name=adm-item2b
#SBATCH --output=rome_item2b.log
#SBATCH --constraint=rome&rocky9
#SBATCH --time=02:00:00
#
# Item 2, second pass. The first pass (7020146) REFUTED the 2x-traffic prediction: per-execute
# cache-references were 0.98-1.01 and cache-misses 0.67 between the serial and ws arms, and
# admiral executes 0.82-0.89 of fftw3's instructions at every size while losing 1.77x in cycles
# from 2^23 up. admiral stalls; it does not overwork. This job tests WHY, on rome.
#
# The hypothesis, from SPR (2026-09-11-item2-transpose-aliasing.md): `choose_large_split` leaves
# `ld = n2` a power of two, so the in-place transposes walk partner tiles W * ld apart and every
# tile of a row walk lands in the same cache sets and DRAM banks. The IPC cliff sits exactly
# where that stride crosses 32 -> 64 KiB (2^22 -> 2^23), and fftw3's IPC is flat across it.
#
# Two independent readings, because neither alone is conclusive on a host I cannot profile
# interactively:
#
#   1. PAGE ADVICE. 2 MiB pages make virtual and physical agree on the low 21 bits, so a
#      power-of-two stride keeps its alias through the physical index. Aliasing predicts huge
#      pages HURT and TLB pressure predicts they HELP, so the SIGN of this arm discriminates the
#      two. On SPR it hurt by 1.05 / 1.14 / 1.19 at 2^22 / 2^23 / 2^24. fftw3 runs the same arm
#      as the control: it should be far less sensitive, because it is the library that does not
#      step.
#
#   2. TLB AND FILL COUNTERS, so the refutation is by measurement and not only by sign. znver2's
#      valid per-process names are probed; anything on the L3 PMU is uncore on AMD and cannot be
#      attributed to one process, which is how `l3_comb_clstr_state.request_miss` returned
#      `<not supported>` for all 22 rows of the first pass.
#
# Build (on a rocky9 workstation, modules as below):
#   cmake -S .. -B ../build-perf-rome -G Ninja -DCMAKE_BUILD_TYPE=Release -DBENCH_ARCH=znver2
#   cmake --build ../build-perf-rome --target admiral_cell fftw3_cell
set -uo pipefail

module purge
module load modules/2.5-beta1 gcc/14.3.0 fftw/3.3.11 intel-oneapi-mkl/2026.0.0
module list 2>&1

BT=$SLURM_SUBMIT_DIR/../../build-perf-rome
source "$SLURM_SUBMIT_DIR/perf_lib.sh"
export LOGERR=$SLURM_SUBMIT_DIR/rome_item2b.stderr
: > "$LOGERR"
export PERF_CELL_WISDOM=$SLURM_SUBMIT_DIR/rome_item2.wisdom

env_report
echo "TREE,$BT"
echo "ADMIRAL,$(git -C "$SLURM_SUBMIT_DIR/../../extern/admiral" log -1 --oneline 2>&1)"
echo "THP,$(cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null)"

SER=0

# `perf_cell` reports AnonHugePages from /proc/self/smaps_rollup after it re-faults the buffers,
# so the log proves the two arms really got different pages. A job whose 4K and 2M arms report
# the same figure measured nothing, whatever the timings say.
huge() { ( export PERF_CELL_HUGE=$1; shift; "$@" ); }

# Demand fills by source, so DRAM traffic is separated from cache hits. Prefetch is excluded
# here on purpose: the first pass already measured `ls_any_fills_from_sys.*`, which mixes them.
G1=$(probe_events cycles instructions task-clock page-faults)
G2=$(probe_events ls_dmnd_fills_from_sys.mem_io_local ls_dmnd_fills_from_sys.ext_cache_remote \
                  ls_dmnd_fills_from_sys.int_cache ls_dmnd_fills_from_sys.lcl_l2)
# The TLB group is what makes the refutation measured rather than inferred. If page walks are
# flat across the 2^22 -> 2^23 step while cycles double, TLB is out on counters too.
G3=$(probe_events ls_l1_d_tlb_miss.all ls_l1_d_tlb_miss.tlb_reload_4k_l2_miss \
                  ls_l1_d_tlb_miss.tlb_reload_2m_l2_miss dTLB-load-misses)
G4=$(probe_events ls_tablewalker.dc_type0 ls_tablewalker.dc_type1 \
                  bp_l1_tlb_miss_l2_tlb_miss.if4k dTLB-loads)
report_events G1 "cycles,instructions,task-clock,page-faults" "$G1"
report_events G2 "ls_dmnd_fills_from_sys.*" "$G2"
report_events G3 "ls_l1_d_tlb_miss.*,dTLB-load-misses" "$G3"
report_events G4 "ls_tablewalker.*,bp_l1_tlb_miss_l2_tlb_miss.*,dTLB-loads" "$G4"

for e in 21 22 23 24 25; do
  N=$((1 << e))
  s=$SECONDS
  taskset -c "$SER" "$BT/fftw3_cell" 1 "$N" 1 1 1 >/dev/null 2>>"$LOGERR"
  echo "WISDOM,$N,$((SECONDS - s))s"
done

# ---------------------------------------------------------------- counters
# R and 3R, differenced off-line, so startup, planning and first-touch cancel.
for e in 21 22 23 24 25; do
  N=$((1 << e))
  R=$(reps_for "$N")
  echo "SIZE,$N,reps,$R,$((3 * R))"
  route_of "adm:$N" "$SER" "$BT/admiral_cell" 1 "$N" 1
  for G in "$G1" "$G2" "$G3" "$G4"; do
    [[ -z "$G" ]] && continue
    for r in "$R" $((3 * R)); do
      huge 0 perf_run "adm_4k:$N"  "$SER" "$BT/admiral_cell" 1 "$N" 1 "$r" "$G"
      huge 1 perf_run "adm_2m:$N"  "$SER" "$BT/admiral_cell" 1 "$N" 1 "$r" "$G"
      huge 0 perf_run "fftw_4k:$N" "$SER" "$BT/fftw3_cell"   1 "$N" 1 "$r" "$G"
      huge 1 perf_run "fftw_2m:$N" "$SER" "$BT/fftw3_cell"   1 "$N" 1 "$r" "$G"
    done
  done
done

# ------------------------------------------------------------------ timing
# Four arms, order rotated every round, minimum over rounds inside each process and over rounds
# outside it. The page-advice ratio is the measurement; the 4k pair against the first pass's
# numbers is the check that this job reproduces it.
for round in 1 2 3 4; do
  for e in 21 22 23 24 25; do
    N=$((1 << e))
    R=$(reps_for "$N")
    arms=(adm_4k adm_2m fftw_4k fftw_2m)
    for i in 0 1 2 3; do
      case "${arms[$(( (i + round) % 4 ))]}" in
        adm_4k)  huge 0 time_run "adm_4k:$N:r$round"  "$SER" "$BT/admiral_cell" 1 "$N" 1 "$R" 5 ;;
        adm_2m)  huge 1 time_run "adm_2m:$N:r$round"  "$SER" "$BT/admiral_cell" 1 "$N" 1 "$R" 5 ;;
        fftw_4k) huge 0 time_run "fftw_4k:$N:r$round" "$SER" "$BT/fftw3_cell"   1 "$N" 1 "$R" 5 ;;
        fftw_2m) huge 1 time_run "fftw_2m:$N:r$round" "$SER" "$BT/fftw3_cell"   1 "$N" 1 "$R" 5 ;;
      esac
    done
  done
done

echo "ITEM2B_DONE"
