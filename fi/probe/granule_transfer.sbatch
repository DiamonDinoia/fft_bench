#!/bin/bash
# fftg-ab: per-class granule-admission transfer probe (WI-0a-ii).
#
# Decides, per host class, whether the AoS-granule leaf admissions beat the
# compile-time-OFF build (ADM_GRANULE_ADMIT, the wi0a seam) beyond in-job noise.
# One job per class: builds yafft ON+OFF at $ADM_SHA ON THE NODE from a
# git-archive extract (workers are offline; the CPM cache is pre-seeded on
# GPFS), compiles benchmark/bench_granule_ab.cpp against each static tree,
# then runs the approved protocol on one pinned physical core:
#
#   12 rounds; arm order rotates ON,OFF / OFF,ON per round; each arm turn is TWO
#   back-to-back driver invocations (rep 1, rep 2) whose same-arm pairs are the
#   in-job control spread floor. 48 invocations x 9 cells = 432 TSV rows. Each
#   invocation itself reports the driver's internal min-of-R per cell.
#
# The decision lives in fi/probe/reduce_transfer.py, not here: admission beats
# OFF per (class, cell) iff OFF_min/ON_min - 1 exceeds 2x the control floor.
# znver2 24x24-f32 carries an adverse prior (16 ymm registers); an OFF verdict
# there is an expected-possible outcome — recorded, not rescued.
#
# Submitted ONLY by fi/probe/submit_probes.sh, which passes
# --constraint=<class>&rocky9 --cpus-per-task=<class width> on the CLI and
# exports CLASS ADM_SHA ADM_ARCH RESULTS_DIR YAFFT_SRC. The class cpu widths
# (128/64/96) are the queue-3/run-2 mechanism: against the 256-cpu QOS any two
# classes run and the third pends, as in the standings wave (fi/SUBMIT.md).
#SBATCH --partition=gen
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --time=01:30:00   # two static yafft builds dominate; 48 driver invocations are minutes
#SBATCH --job-name=fftg-ab
set -uo pipefail

for v in CLASS ADM_SHA ADM_ARCH RESULTS_DIR YAFFT_SRC; do
  [[ -n ${!v:-} ]] \
    || { echo "GRANULE_AB_FAIL: \$$v unset (submit via fi/probe/submit_probes.sh)"; exit 1; }
done
case "$CLASS" in
  rome|icelake|genoa) ;;
  *) echo "GRANULE_AB_FAIL: unknown CLASS=$CLASS (expected rome|icelake|genoa)"; exit 1 ;;
esac

# --- toolchain (tiny_ab.sbatch precedent: modules/2.5-beta1 is what exposes
# gcc 14 + cmake on a worker; never pipe `module`, it is a shell function) ----
source /etc/profile.d/modules.sh
module purge >/dev/null 2>&1
module load modules/2.5-beta1 >/dev/null 2>&1 \
  || { echo "GRANULE_AB_FAIL: no modules/2.5-beta1"; exit 1; }
module load gcc/14.3.0 cmake/3.31.11 ninja/1.13.2 >/dev/null 2>&1 \
  || { echo "GRANULE_AB_FAIL: no gcc/cmake/ninja"; exit 1; }
for t in "g++ -dumpversion" "cmake --version" "ninja --version"; do
  $t >/dev/null 2>&1 || { echo "GRANULE_AB_FAIL: '$t' does not run"; exit 1; }
done
unset NINJA_STATUS
# A worker has no route out: CPM would otherwise try to fetch xsimd/poet.
export CPM_SOURCE_CACHE=/mnt/home/mbarbone/cpm-cache
for d in cpm xsimd poet; do
  [[ -d $CPM_SOURCE_CACHE/$d ]] \
    || { echo "GRANULE_AB_FAIL: $CPM_SOURCE_CACHE/$d missing"; exit 1; }
done

# Rerun protection, checked BEFORE the builds: a same-day, same-sha
# re-submission fails loudly instead of burning a node to redo them. Delete
# the stale stem to force a re-run.
STEM=$RESULTS_DIR/$CLASS-$(date +%F)-${ADM_SHA:0:7}
TSV=$STEM.tsv
[[ ! -e $TSV ]] \
  || { echo "GRANULE_AB_FAIL: $TSV exists; delete the stale stem to force a re-run"; exit 1; }
mkdir -p "$RESULTS_DIR" || { echo "GRANULE_AB_FAIL: mkdir $RESULTS_DIR"; exit 1; }
[[ -f $SLURM_SUBMIT_DIR/canon_rows.py ]] \
  || { echo "GRANULE_AB_FAIL: $SLURM_SUBMIT_DIR/canon_rows.py missing (submit via fi/probe/submit_probes.sh)"; exit 1; }

# -------------------------------------------- source extract (offline-safe)
WORK=${TMPDIR:-/tmp}/granule_transfer.$SLURM_JOB_ID
SRC=$WORK/rundir
mkdir -p "$SRC" || { echo "GRANULE_AB_FAIL: mkdir $SRC"; exit 1; }
git -C "$YAFFT_SRC" archive "$ADM_SHA" | tar -x -C "$SRC" \
  || { echo "GRANULE_AB_FAIL: git archive $ADM_SHA from $YAFFT_SRC"; exit 1; }
DRIVER=$SRC/benchmark/bench_granule_ab.cpp
[[ -f $DRIVER ]] || { echo "GRANULE_AB_FAIL: benchmark/bench_granule_ab.cpp absent at $ADM_SHA"
                      echo "  the driver lands with round-2 integration (team/2-runner);"
                      echo "  point ADM_REF at a sha that carries it"; exit 1; }
grep -q 'option(ADM_GRANULE_ADMIT' "$SRC/CMakeLists.txt" \
  || { echo "GRANULE_AB_FAIL: ADM_GRANULE_ADMIT knob absent at $ADM_SHA (lands from the wi0a seam)"; exit 1; }

# ------------------------------------------------- build the two arms here
# Same commit, same node, same toolchain: ON vs OFF of ADM_GRANULE_ADMIT, at the
# sweep's march per class (fi/<class>.sbatch BENCH_ARCH; znver2 is gcc's
# x86-64-v3 uarch name).
for arm in on off; do
  ADMIT=ON; [[ $arm == off ]] && ADMIT=OFF
  cmake -S "$SRC" -B "$WORK/b-$arm" -G Ninja -DCMAKE_BUILD_TYPE=Release \
        -DADM_TARGET_ARCH="$ADM_ARCH" -DADM_GRANULE_ADMIT="$ADMIT" \
        -DADM_BUILD_TESTS=OFF -DADM_BUILD_BENCHMARKS=OFF \
        > "$WORK/b-$arm.cfg.log" 2>&1 \
    || { tail -20 "$WORK/b-$arm.cfg.log"; echo "GRANULE_AB_FAIL: configure $arm"; exit 1; }
  cmake --build "$WORK/b-$arm" -j"${SLURM_CPUS_PER_TASK:-16}" --target admiral_static \
        > "$WORK/b-$arm.build.log" 2>&1 \
    || { tail -30 "$WORK/b-$arm.build.log"; echo "GRANULE_AB_FAIL: build $arm"; exit 1; }
  # The driver includes src-side "granule_apply.hpp" (wi0a seam); -I"$SRC/src" reaches it.
  # The OFF bench TU carries the knob define as well as the OFF library: the
  # driver's cube engagement assert is `#ifndef ADM_GRANULE_ADMIT_OFF`, and the
  # in-tree bench target receives the define through the library's interface
  # -- this manual link does not. Without it the OFF binary exits 3 on the
  # first cube cell (assert fires: no fast3d seat in an OFF build) the moment
  # the run reaches 4x4x4; measured at znver2 on the wave-2 archive.
  DEFS=-DADM_STATIC_DEFINE
  [[ $arm == off ]] && DEFS="$DEFS -DADM_GRANULE_ADMIT_OFF"
  # shellcheck disable=SC2046
  g++ -O3 -march="$ADM_ARCH" -std=c++20 $DEFS \
      -I"$WORK/b-$arm/src/generated/include" -I"$SRC/include" -I"$SRC/src" \
      $(grep -o '\-isystem [^ ]*' "$WORK/b-$arm/build.ninja" | sort -u | tr '\n' ' ') \
      "$DRIVER" "$WORK/b-$arm/src/libadmiral.a" "$WORK/b-$arm/src/libadmiral_codelets.a" \
      -pthread -o "$WORK/granule_ab_$arm" \
    || { echo "GRANULE_AB_FAIL: driver link $arm"; exit 1; }
done

# Distinct binaries, or the A/B is an A/A (tiny_ab precedent).
ON_MD5=$(md5sum < "$WORK/granule_ab_on"); OFF_MD5=$(md5sum < "$WORK/granule_ab_off")
[[ $ON_MD5 != "$OFF_MD5" ]] \
  || { echo "GRANULE_AB_FAIL: ON and OFF drivers are identical; the knob reached no code"; exit 1; }
# The knob must have taken in BOTH directions (wi0a gate-f census: ON carries
# granule_apply_rows_oop, OFF carries none). Inverted counts mean A/B garbage.
NM_ON=$(nm --defined-only "$WORK/b-on/src/libadmiral.a" 2>/dev/null | grep -c granule_apply_rows_oop || true)
NM_OFF=$(nm --defined-only "$WORK/b-off/src/libadmiral.a" 2>/dev/null | grep -c granule_apply_rows_oop || true)
if (( NM_ON == 0 || NM_OFF != 0 )); then
  echo "GRANULE_AB_FAIL: granule symbol census wrong (on=$NM_ON off=$NM_OFF); the knob did not take"
  exit 1
fi

# Pin to one physical core of the allocation, its sibling left idle; a second
# core on ANOTHER physical core receives the shell's own work (anchor probe).
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

mkdir -p "$WORK/raw" || { echo "GRANULE_AB_FAIL: mkdir $WORK/raw"; exit 1; }

{
echo "=== fftg-ab granule transfer probe, class $CLASS ==="
date -Is
hostname
lscpu | grep 'Model name' || true
echo "job:      $SLURM_JOB_ID (${SLURM_CPUS_PER_TASK:-?} cpus, exclusive)"
echo "yafft:    $YAFFT_SRC @ $ADM_SHA"
echo "driver:   benchmark/bench_granule_ab.cpp md5 $(md5sum "$DRIVER" | cut -c1-12)"
echo "arch:     ADM_TARGET_ARCH=$ADM_ARCH (matches fi/$CLASS.sbatch BENCH_ARCH)"
echo "arms:     ADM_GRANULE_ADMIT ON vs OFF, built on this node, Release"
echo "md5:      on $(echo "$ON_MD5" | cut -c1-12)  off $(echo "$OFF_MD5" | cut -c1-12)  (distinct)"
echo "census:   granule_apply_rows_oop symbols on=$NM_ON off=$NM_OFF"
echo "pin:      measure cpu $MEAS (physical core $(lscpu -e=CPU,CORE | tr ',' ' ' | awk -v c="$MEAS" '$1==c {print $2}')), shell cpu $OTHER"
echo "protocol: 12 rounds, arm order rotated per round, 2 same-arm repeats per turn (control floor)"
echo "cpm:      $CPM_SOURCE_CACHE"
module list 2>&1
} | tee "$STEM.env.md"

printf 'class\tcell\tprec\tround\trep\tarm\tns\n' > "$TSV"

run_one() {  # $1=arm $2=round $3=rep
  local arm=$1 round=$2 rep=$3 raw st
  raw=$WORK/raw/r$(printf %02d "$round")_${arm}${rep}.txt
  taskset -c "$MEAS" "$WORK/granule_ab_$arm" > "$raw" 2>&1 \
    || { st=$?
         cp "$raw" "$STEM.failed.txt"
         echo "GRANULE_AB_FAIL: driver $arm exited $st (round $round rep $rep); raw copied to $STEM.failed.txt"
         exit 1; }
  python3 "$SLURM_SUBMIT_DIR/canon_rows.py" "$CLASS" "$round" "$rep" "$arm" "$raw" "$TSV" \
    || { cp "$raw" "$STEM.failed.txt"
         echo "GRANULE_AB_FAIL: canonicalizer rejected $raw (copied to $STEM.failed.txt)"; exit 1; }
  { echo "--- round $round $arm rep $rep ---"; cat "$raw"; } >> "$STEM.raw.txt"
}

for round in $(seq 1 12); do
  if (( round % 2 == 1 )); then order="on off"; else order="off on"; fi
  for arm in $order; do
    run_one "$arm" "$round" 1
    run_one "$arm" "$round" 2
  done
  echo "[round $round/12 done $(date +%T)]"
done

# Eyeball summary for the slurm log; fi/probe/reduce_transfer.py is the
# authoritative reducer (per-cell min per arm, control-floor spread, verdict).
python3 - "$TSV" <<'PY'
import sys
rows = [ln.split('\t') for ln in open(sys.argv[1]).read().splitlines()[1:]]
cells = sorted({(r[1], r[2]) for r in rows})
for cell, prec in cells:
    on = [float(r[6]) for r in rows if r[1] == cell and r[2] == prec and r[5] == 'on']
    off = [float(r[6]) for r in rows if r[1] == cell and r[2] == prec and r[5] == 'off']
    print(f'GRANULE_CELL,{cell},{prec},on_min_ns={min(on):.9g},off_min_ns={min(off):.9g},'
          f'ratio={min(on)/min(off):.4f},n_on={len(on)},n_off={len(off)}')
PY

rm -rf "$WORK"
echo "GRANULE_AB_DONE $STEM.tsv"
