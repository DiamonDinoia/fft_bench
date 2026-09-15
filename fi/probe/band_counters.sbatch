#!/bin/bash
# wi2a-band: mid-1-D f64 FP-port/FMA band counters (WI-2a, branch team/5-wi2a).
#
# Decides whether the mid-1-D f64 gap to fftw3 on the rome class (admiral/fftw3 =
# 1.207..1.488 over (1,256..8192), era-campaign evidence) is ENGINE ABSENCE
# (admiral within ~5% of the Zen 2 FMA port-marginal floor -> KILL) or a NAMED
# MECHANISM whose prototype A/B projects >= 1.15 on >= 3 of the 6 cells (FUND).
# The instrument is the differenced per-execute counter pair over the
# admiral/fftw3 cell binaries built login-side by fi/probe/submit_band.sh:
#
#   floor_cyc = mac_flops / (2 FLOPs per MAC) / (W=4 f64 lanes) / (2 FMA pipes)
#
# fp_ret_sse_avx_ops.* counts retired per-LANE FLOPs (MAC counts 2; PPR 55803
# sec 2.1.15.4.1 p.184, amdzen2 floating-point.json) and the Zen 2 FP pipe map is
# FMUL+FMA on pipes 0-1, FADD on pipes 2-3 (SOG 56305 sec 2.11.1 p.36). The
# instruction-weighted icelake 'fma x 2' floor (W=8, fp_arith_inst_retired.*) is
# NEVER imported: the two ISAs' events weight differently. fpu_pipe_assignment
# .total{0..3} is the confirmation occupancy read, and the znver2 TLB classes
# are reused verbatim from fi/perf/rome_item2b.sbatch:65-77 where the partition
# probe accepted them.
#
# Protocol: route recorded once per (backend, cell) OUTSIDE any measured run;
# counters at R and 3R reps per (group, cell, backend), differenced off-line so
# startup and planning cancel; timing as 12 rounds with backend order rotated
# per round, min-of-R inside each process (rounds=5), min-over-rounds outside.
# base + FLOP classes run at every cell; pipes, TLB and fill run only at
# DEEP_CELLS.
#
# Submitted ONLY by fi/probe/submit_band.sh, which passes --constraint on the
# CLI (never in-file) and exports CLASS CELLS BACKENDS EVENTS DEEP_CELLS
# ADM_SHA BT MEM_REPO. No admiral build happens on the node. MEM_REPO is the
# logbook checkout ROOT (fi/anchor/submit_chain.sh and fi/probe/large_route.sbatch
# convention); RUN_DIR carries the admiral/beat-standings prefix, so the REL
# pathspec in the self-commit below stays repo-root-relative even under a git
# whose add and commit --only disagree on cwd-prefix absorption. The wi2a job
# 7041868 root cause was the ARTIFACT name, not the rel math: the logbook
# .gitignore rules (raw/ */raw/ *.data *.asm *.raw *.txt *.log) ignore the old
# *.txt artifact name, so add staged nothing and commit --only died on an empty
# pathspec. The transcript name is raw.csv (wi2c's visible .tsv/.csv convention).
#SBATCH --partition=gen
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --exclusive
#SBATCH --time=00:30:00
set -uo pipefail

for v in CLASS CELLS BACKENDS EVENTS DEEP_CELLS ADM_SHA BT MEM_REPO; do
  [[ -n ${!v:-} ]] \
    || { echo "WI2_FAIL: \$$v unset (submit via fi/probe/submit_band.sh)"; exit 1; }
done
fail() { echo "WI2_FAIL: $*" >&2; exit 1; }
LIB=$SLURM_SUBMIT_DIR/perf_probe_lib.sh
[[ -f $LIB ]] || fail "$LIB missing (submit via fi/probe/submit_band.sh)"
source "$LIB"
for t in perf taskset python3 git md5sum lscpu awk tee; do
  command -v $t >/dev/null || fail "no $t on PATH"
done
[[ -d $BT ]] || fail "no build tree BT=$BT (build login-side via fi/probe/submit_band.sh)"

# Runtime libs for the prebuilt binaries (libstdc++ newer than the node base
# image's, and libfftw3): loaded before any ldd or measured work.
source /etc/profile.d/modules.sh 2>/dev/null || fail "no Lmod on this node"
module purge >/dev/null 2>&1
module load modules/2.5-beta1 gcc/14.3.0 fftw/3.3.11 >/dev/null 2>&1 \
  || fail "module load of the gcc/fftw toolchain"

# Binary table from BACKENDS: token -> <token>_cell, as built login-side.
read -ra BL <<<"${BACKENDS//,/ }"
NB=${#BL[@]}
declare -A BIN=() SHORT=()
for b in "${BL[@]}"; do
  BIN[$b]=$BT/${b}_cell
  SHORT[$b]=$(case "$b" in admiral) echo adm;; fftw3) echo fftw;; *) echo "$b";; esac)
  [[ -x ${BIN[$b]} ]] || fail "missing binary ${BIN[$b]} (build with fi/probe/submit_band.sh)"
  ldd -r "${BIN[$b]}" 2>&1 | grep -qE 'not found|undefined symbol' \
    && fail "unresolved DSO in ${BIN[$b]} on this node"
done

# The login-side build stamps the tree; md5 it on the node so a stale or mixed
# GPFS tree cannot pass for the declared one.
MANIFEST=$BT/wi2a-manifest.txt
[[ -f $MANIFEST ]] || fail "no build manifest $MANIFEST (build via fi/probe/submit_band.sh)"
for b in "${BL[@]}"; do
  m=$(awk -v b="${b}_cell" '$1 == "md5" && $2 == b {print $3}' "$MANIFEST")
  [[ -n $m && $m == "$(md5sum < "${BIN[$b]}" | cut -d' ' -f1)" ]] \
    || fail "md5 mismatch for ${BIN[$b]} against build manifest"
done

# Rerun protection, checked BEFORE anything is measured: a same-sha
# re-submission fails loudly instead of redoing the wave. Delete the stale run
# dir to force a re-run.
# The .git check pins MEM_REPO to the checkout ROOT, the shape the self-commit
# below requires: REL keeps the admiral/beat-standings prefix only when
# RUN_DIR starts from the root. A subdir MEM_REPO is tonight's 7041868 defect.
[[ -d $MEM_REPO/.git ]] || fail "MEM_REPO=$MEM_REPO is not the logbook checkout root (no .git)"
RUN_DIR=$MEM_REPO/admiral/beat-standings/runs/wi2a-$CLASS-${ADM_SHA:0:7}
[[ ! -e $RUN_DIR ]] \
  || fail "$RUN_DIR exists; delete the stale run dir to force a re-run"
mkdir -p "$RUN_DIR" || fail "mkdir $RUN_DIR"
# From here on the whole output also lands in the committed artifact.
# The transcript is a comma-separated record stream and the name must survive the
# logbook's ignore rules (~/repos/memory/.gitignore: *.txt *.log *.data *.asm *.raw
# are all ignored — the old *.txt artifact staged nothing and job 7041868's commit
# --only found an empty pathspec). wi2c convention: the durable artifact carries a
# visible .csv/.tsv name.
exec > >(tee "$RUN_DIR/raw.csv") 2>&1

# Cell id used in tags: "(1,256)" -> "1x256" (tags must stay comma-free for the
# CSV rows — perf_lib warns about commas in tags).
cell_id() { local dn=${1#(}; dn=${dn%)}; echo "${dn%%,*}x${dn##*,}"; }

# Pin to one of the two allocated cpus for measurement; the shell keeps the
# other (anchor-probe precedent). Sibling left idle if the allocation gives two
# physical cores.
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

env_report "${BIN[@]}"
echo "TREE,$BT"
echo "CLASS,$CLASS"
echo "CELLS,$CELLS"
echo "DEEP_CELLS,$DEEP_CELLS"
echo "BACKENDS,$BACKENDS"
echo "EVENTS,$EVENTS"
echo "ADMIRAL,$ADM_SHA"
echo "NMI_WATCHDOG,$(cat /proc/sys/kernel/nmi_watchdog 2>/dev/null)"
echo "THP,$(cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null)"
echo "PIN,measure cpu $MEAS,shell cpu $OTHER"
module list 2>&1

# ----------------------------------------------------------------- the gate
# Every requested event must count under a REAL transform workload before any
# measurement: a blocked perf is exit 1. A sleep probe would false-reject the FP
# classes (zero FLOPs retired): see perf_probe_lib.sh.
PROBE_BIN=${BIN[${BL[0]}]}
case ",$EVENTS," in *,base,*)  B=1;; *) B=0;; esac
case ",$EVENTS," in *,flops,*) F=1;; *) F=0;; esac
case ",$EVENTS," in *,pipes,*) P=1;; *) P=0;; esac
case ",$EVENTS," in *,tlb,*)   T=1;; *) T=0;; esac
case ",$EVENTS," in *,fill,*)  L=1;; *) L=0;; esac
(( B && F )) || fail "EVENTS must include base,flops (the floor law needs both at every cell)"

G_BASE="cycles instructions task-clock page-faults"
G_FLOPS="fp_ret_sse_avx_ops.all fp_ret_sse_avx_ops.add_sub_flops fp_ret_sse_avx_ops.mult_flops fp_ret_sse_avx_ops.mac_flops fp_ret_sse_avx_ops.div_flops"
G_PIPES="fpu_pipe_assignment.total fpu_pipe_assignment.total0 fpu_pipe_assignment.total1 fpu_pipe_assignment.total2 fpu_pipe_assignment.total3"
# TLB classes: reused verbatim from fi/perf/rome_item2b.sbatch:65-77 (partition-proven).
G_TLB1="ls_l1_d_tlb_miss.all ls_l1_d_tlb_miss.tlb_reload_4k_l2_miss ls_l1_d_tlb_miss.tlb_reload_2m_l2_miss dTLB-load-misses"
G_TLB2="ls_tablewalker.dc_type0 ls_tablewalker.dc_type1 bp_l1_tlb_miss_l2_tlb_miss.if4k dTLB-loads"
# Fill classes: the item2b spelling ls_dmnd_fills_from_sys.* probed to ZERO
# accepted events on this partition (fi/perf/rome_item2b.log: EVENTS,G2,accepted
# empty). The PPR (55803, sec 2.1.15.4.2 p.186, PMCx043) names the family
# LsRefillsFromSys, spelled ls_refills_from_sys.ls_mabresp_* in the amdzen2
# JSONs. Probe both; the family that counts wins (loud FAILOVER line); if
# neither does the job fails — a silently empty fill column is how the first
# pass lost four hours to `<not supported>`.
G_FILL_V2="ls_refills_from_sys.ls_mabresp_lcl_l2 ls_refills_from_sys.ls_mabresp_lcl_cache ls_refills_from_sys.ls_mabresp_lcl_dram ls_refills_from_sys.ls_mabresp_rmt_cache ls_refills_from_sys.ls_mabresp_rmt_dram"
G_FILL_V1="ls_dmnd_fills_from_sys.mem_io_local ls_dmnd_fills_from_sys.ext_cache_remote ls_dmnd_fills_from_sys.int_cache ls_dmnd_fills_from_sys.lcl_l2"
G_MAB="ls_mab_alloc.loads ls_mab_alloc.stores ls_mab_alloc.dc_prefetcher"

gate_events_counted BASE  "$PROBE_BIN" 1 1024 1 200 1 -- $G_BASE
(( F )) && gate_events_counted FLOPS "$PROBE_BIN" 1 1024 1 200 1 -- $G_FLOPS
(( P )) && gate_events_counted PIPES "$PROBE_BIN" 1 1024 1 200 1 -- $G_PIPES
(( T )) && gate_events_counted TLB   "$PROBE_BIN" 1 1024 1 200 1 -- $G_TLB1 $G_TLB2
FILL_OK=0
if (( L )); then
  ACC2=$(probe_events_run "$PROBE_BIN" 1 1024 1 200 1 -- $G_FILL_V2)
  ACC1=$(probe_events_run "$PROBE_BIN" 1 1024 1 200 1 -- $G_FILL_V1)
  report_events FILL_PPR "$G_FILL_V2" "$ACC2"
  report_events FILL_ITEM2B "$G_FILL_V1" "$ACC1"
  if [[ -n $ACC2 ]]; then
    FILL_OK=1; G_FILL=$ACC2
  elif [[ -n $ACC1 ]]; then
    FILL_OK=1; G_FILL=$ACC1
    echo "FILL_FAILOVER,legacy ls_dmnd_fills spelling in force (PPR spelling rejected by this kernel)"
  else
    fail "no fill-source family counts on this node (tried PPR ls_refills_from_sys.* and item2b ls_dmnd_fills_from_sys.*)"
  fi
  gate_events_counted MAB "$PROBE_BIN" 1 1024 1 200 1 -- $G_MAB
fi

# ----------------------------------------------- wisdom (fftw3 backends only)
# FFTW_MEASURE plans once per process; a wisdom file pays it once per cell and
# makes the plan identical across the ~30 processes of a cell's arms.
WISDIR=${TMPDIR:-/tmp}/wi2a_wis.$SLURM_JOB_ID
mkdir -p "$WISDIR" || fail "mkdir $WISDIR"
export PERF_CELL_WISDOM=$WISDIR/wisdom.wis
for b in "${BL[@]}"; do
  [[ $b == fftw3 ]] || continue
  for c in $CELLS; do
    dn=${c#(}; dn=${dn%)}; d=${dn%%,*}; n=${dn##*,}
    s=$SECONDS
    taskset -c "$MEAS" "${BIN[$b]}" "$d" "$n" 1 1 1 >/dev/null 2>>"$LOGERR" \
      || fail "wisdom pre-pass failed at $c for $b"
    echo "WISDOM,$(cell_id "$c"),$b,$((SECONDS - s))s"
  done
done

declare -A DEEP=()
for c in $DEEP_CELLS; do DEEP[$c]=1; done

# ------------------------------------------------------------------- counters
for c in $CELLS; do
  cid=$(cell_id "$c")
  dn=${c#(}; dn=${dn%)}; d=${dn%%,*}; n=${dn##*,}
  R=$(reps_for "$n")
  echo "SIZE,$cid,reps,$R,$((3 * R))"
  for b in "${BL[@]}"; do
    route_of "${SHORT[$b]}:$cid" "$MEAS" "${BIN[$b]}" "$d" "$n" 1
  done
  GROUPS=("$G_BASE" "$G_FLOPS")
  if [[ -n ${DEEP[$c]:-} ]]; then
    (( P )) && GROUPS+=("$G_PIPES")
    (( T )) && GROUPS+=("$G_TLB1" "$G_TLB2")
    (( L && FILL_OK )) && GROUPS+=("$G_FILL" "$G_MAB")
  fi
  for G in "${GROUPS[@]}"; do
    [[ -z $G ]] && continue
    for r in "$R" $((3 * R)); do
      for b in "${BL[@]}"; do
        perf_run "${SHORT[$b]}:$cid" "$MEAS" "${BIN[$b]}" "$d" "$n" 1 "$r" "$G"
      done
    done
  done
done

# --------------------------------------------------------------------- timing
# 12 rounds, backend order rotated each round; each process reports its
# internal min-of-R over 5 rounds; the outer minimum over rounds is off-line.
for round in $(seq 1 12); do
  for c in $CELLS; do
    cid=$(cell_id "$c")
    dn=${c#(}; dn=${dn%)}; d=${dn%%,*}; n=${dn##*,}
    R=$(reps_for "$n")
    for k in $(seq 0 $((NB - 1))); do
      b=${BL[$(( (k + round) % NB ))]}
      time_run "${SHORT[$b]}:$cid:r$round" "$MEAS" "${BIN[$b]}" "$d" "$n" 1 "$R" 5
    done
  done
  echo "[round $round/12 done $(date +%T)]"
done
unset PERF_CELL_WISDOM

# ------------------------------------------------- self-commit (collect.sbatch
# model, lines 96-103): the durable copy is committed HERE, before DONE,
# because workers can write GPFS and git commits are local. Never a push.
REL=${RUN_DIR#"$MEM_REPO"/}
[[ $REL != "$RUN_DIR" ]] || fail "RUN_DIR $RUN_DIR not under MEM_REPO $MEM_REPO"
git -C "$MEM_REPO" add -- "$REL" || fail "git add $REL"
git -C "$MEM_REPO" commit --only -m \
    "admiral beat-standings: wi2a $CLASS mid-1-D band counters (job $SLURM_JOB_ID, adm ${ADM_SHA:0:7})" -- "$REL" \
  || fail "git commit $REL (index lock?); files are on disk in $RUN_DIR — commit login-side"
echo "WI2_DONE $RUN_DIR ($(git -C "$MEM_REPO" rev-parse --short HEAD))"
