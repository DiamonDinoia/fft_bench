#!/bin/bash
# wi2c-lr: per-class large-1-D route-line probe (WI-2c). Re-derives, on ONE
# exclusive node of one host class, every four_step_large admission constant of
# include/admiral/detail/four_step_large.hpp:398-407 (threaded budget 2 MiB /
# floor 512 KiB-1; serial f64 12 MiB; f32 window 16 MiB-1 .. 32 MiB) plus the
# stream-arm multiple kFourStepStreamL3Mult=2 (:38). The lines under test are
# pinned by test/transforms/test_route_forced.cpp:188-204, :206-212, :333-349;
# a moved line ships as constant + test pins + this receipt in ONE commit.
#
# The measurement driver is yafft-side benchmark/bench_large_route at $ADM_SHA,
# built on the node from a git-archive extract (workers are offline; the CPM
# cache on GPFS is pre-seeded and each dep revision is CONTENT-VERIFIED below
# via git rev-parse inside the cache dirs — the [[ -d ]] gates are a base gate
# only, not proof). Driver contract (FIXED, peer lane):
#
#   bench_large_route --route={auto|dif|four_step} --prec={f32|f64}
#                     [--nthreads=N] [--bytes=LIST | --n=LIST]
#                     [--reps=R] [--ramp-ms=M] [--huge={0,1}] [--out=TSV]
#
# stdout rows: prec n bytes nthreads route_forced route_elected
# stream_arm_elected reps min_ns guard_value. The driver self-checks numerics
# (dif-vs-four_step agreement, huge-flag invariance) and exits nonzero on any
# violation; this job checks every call's exit status, row shape and row count,
# and fails loudly on any drift from the contract. The driver pins its own
# threads, so no taskset wrapper anywhere here.
#
# Legs (each resumable via $RESULTS_DIR/resume/, incremental TSV append per
# measurement call, markers WI2C_SERIAL_DONE / WI2C_THREAD_DONE / WI2C_DONE):
#   serial:   N=2^18..2^25 x {f32,f64} x {dif,four_step} x 3 rotated rounds
#             (+ one auto row set per prec, recording elections). Coverage is
#             deliberately PAST the shipped f32 window top: 256 MiB f32,
#             512 MiB f64 (a stopped-early sweep reads only the window's lower
#             edge).
#   threaded: nthreads in {1,2,4,8,32,CAP} x {f32,f64} x {dif,four_step} x 3
#             rotated rounds; byte grid 128 KiB..32 MiB (f64 N 2^13..2^21, f32
#             2^14..2^22 — the spec named 2^13..2^20 / 2^14..2^21 AND a 32 MiB
#             top; this grid is the UNION, so either reading is covered).
#   tlb:      top-2 serial rungs (N=2^24,2^25) x {f32,f64} x {dif,four_step}
#             x --huge={0,1} timed pairs + probe-guarded counters (znver2 names
#             from fi/perf/rome_item2b.sbatch:70-73 for rome; genoa probes the
#             same spellings; icelake gets the Intel dtlb_load_misses.* names).
#             Every event is probed for a NUMERIC count before use; an accepted
#             event that still returns <not supported> in a measured run fails
#             the job loudly. R and 3R rows are recorded; differencing is
#             off-line (perf_probe_lib.sh rule: nothing reduces on-node).
#
# Each DONE echo is preceded by a self-commit of the leg's artifacts into the
# GPFS logbook checkout ($MEM_REPO/admiral/beat-standings/runs/wi2c-<class>-
# <sha7>/), modeled on fi/anchor/collect.sbatch:96-103 (single job, NO chained
# collect job; commit failures are loud, files on disk are recoverable).
#
# Submitted ONLY by fi/probe/submit_large_route.sh, which puts --constraint on
# the CLI and exports CLASS ADM_SHA ADM_ARCH RESULTS_DIR YAFFT_SRC MEM_REPO.
# Exclusive node with --cpus-per-task=2: the driver pins, and under --exclusive
# this cluster grants the whole-node mask; the CAP guard below verifies that
# reading instead of trusting it.
#SBATCH --partition=gen
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --time=01:30:00   # one on-node build dominates; 3 legs measure in minutes
#SBATCH --job-name=wi2c-lr
set -uo pipefail

fail() { echo "WI2C_FAIL: $*" >&2; exit 1; }

for v in CLASS ADM_SHA ADM_ARCH RESULTS_DIR YAFFT_SRC MEM_REPO; do
  [[ -n ${!v:-} ]] \
    || fail "\$$v unset (submit via fi/probe/submit_large_route.sh)"
done
declare -A CAP_OF=([rome]=128 [icelake]=64 [genoa]=96)
CAP=${CAP_OF[$CLASS]:-}
[[ -n $CAP ]] || fail "unknown CLASS=$CLASS (expected rome|icelake|genoa)"

# --- toolchain (tiny_ab.sbatch precedent: modules/2.5-beta1 exposes gcc 14 +
# cmake on a worker; never pipe `module`, it is a shell function) -------------
source /etc/profile.d/modules.sh
module purge >/dev/null 2>&1
module load modules/2.5-beta1 >/dev/null 2>&1 || fail "no modules/2.5-beta1"
module load gcc/14.3.0 cmake/3.31.11 ninja/1.13.2 >/dev/null 2>&1 \
  || fail "no gcc/cmake/ninja"
for t in "g++ -dumpversion" "cmake --version" "ninja --version"; do
  $t >/dev/null 2>&1 || fail "'$t' does not run"
done
unset NINJA_STATUS

# --- CPM cache: the version-blind -d gates are the BASE gate only; the content
# probes after the source extract are the proof (poet 1f136442 and e10d62c are
# both content-verified in this cache; the probe reads whatever rev the tree at
# $ADM_SHA pins). --------------------------------------------------------------
CPM_CACHE=/mnt/home/mbarbone/cpm-cache
export CPM_SOURCE_CACHE=$CPM_CACHE
for d in cpm xsimd poet snmalloc; do
  [[ -d $CPM_CACHE/$d ]] || fail "$CPM_CACHE/$d missing (workers are offline)"
done

KEY=$CLASS-${ADM_SHA:0:7}
STEM=$RESULTS_DIR/wi2c-$KEY
TSV_SERIAL=$STEM.serial.tsv
TSV_THREAD=$STEM.thread.tsv
TSV_TLB=$STEM.tlb.tsv
CSV_CTR=$STEM.tlb_counters.csv
RESUME=$RESULTS_DIR/resume
RUN_DIR=$MEM_REPO/admiral/beat-standings/runs/wi2c-$KEY
mkdir -p "$RESULTS_DIR" "$RESUME" || fail "mkdir $RESULTS_DIR{,/resume}"
[[ -d $MEM_REPO/.git ]] || fail "MEM_REPO=$MEM_REPO is not a git checkout"
[[ -f $SLURM_SUBMIT_DIR/perf_probe_lib.sh ]] \
  || fail "$SLURM_SUBMIT_DIR/perf_probe_lib.sh missing (submit via fi/probe/submit_large_route.sh)"
# shellcheck source=perf_probe_lib.sh
source "$SLURM_SUBMIT_DIR/perf_probe_lib.sh"
export LOGERR=$STEM.stderr
: > "$LOGERR"

# ------------------------------------- node viability (checked BEFORE work)
# The threaded leg pins nthreads up to CAP: the exclusive allocation must hand
# this shell at least CAP cpus, or the threaded arm oversubscribes silently.
ALLOWED=$(python3 - <<'PY'
cpus = set()
for ln in open('/proc/self/status'):
    if ln.startswith('Cpus_allowed_list'):
        for part in ln.split(':', 1)[1].strip().split(','):
            lo, _, hi = part.partition('-')
            cpus.update(range(int(lo), int(hi or lo) + 1))
print(len(cpus))
PY
)
[[ $ALLOWED =~ ^[0-9]+$ ]] || fail "cannot parse Cpus_allowed_list"
(( ALLOWED >= CAP )) \
  || fail "cpuset allows $ALLOWED cpus < CAP $CAP for $CLASS: --exclusive did not grant the whole-node mask here; resubmit with WI2C_CPUS=$CAP (see submit_large_route.sh)"
# perf is a required deliverable (TLB arm), so probe it BEFORE the build: a
# broken perf costs the job minutes of leg work if found late.
command -v perf >/dev/null || fail "no perf on this node (the TLB arm is required)"
PERF_PROBE=$(probe_events cycles instructions)
[[ -n $PERF_PROBE ]] \
  || fail "perf counts nothing on $CLASS (paranoid=$(cat /proc/sys/kernel/perf_event_paranoid 2>/dev/null))"

# -------------------------------------------- source extract (offline-safe)
WORK=${TMPDIR:-/tmp}/wi2c_large_route.$SLURM_JOB_ID
SRC=$WORK/rundir
mkdir -p "$SRC" || fail "mkdir $SRC"
git -C "$YAFFT_SRC" archive "$ADM_SHA" | tar -x -C "$SRC" \
  || fail "git archive $ADM_SHA from $YAFFT_SRC"
DRIVER=$SRC/benchmark/bench_large_route.cpp
[[ -f $DRIVER ]] \
  || fail "benchmark/bench_large_route.cpp absent at $ADM_SHA
  the driver lands from the WI-2c peer lane; point ADM_REF at a tree that carries it"

# CPM download script version-pinned by the extracted tree.
CPMV=$(awk '/set\(CPM_DOWNLOAD_VERSION/{gsub(/\)/, "", $2); print $2; exit}' \
         "$SRC/cmake/CPM.cmake")
[[ -f $CPM_CACHE/cpm/CPM_$CPMV.cmake ]] \
  || fail "$CPM_CACHE/cpm/CPM_$CPMV.cmake missing (tree pins CPM $CPMV)"

# Content-verified dep gate: the revision the extracted tree pins must be the
# HEAD of some cache dir for that package (cache dirs retain .git).
dep_tag() { # $1=pkg -> GIT_TAG pinned by the extracted tree
  awk -v pkg="$1" '$0 ~ "NAME "pkg {f=1} f && /GIT_TAG/ {print $2; exit}' \
      "$SRC/cmake/Dependencies.cmake"
}
dep_cached() { # $1=pkg $2=tag
  local pkg=$1 tag=$2 d h
  [[ -n $tag ]] || return 1
  for d in "$CPM_CACHE/$pkg"/*/; do
    [[ -d $d/.git ]] || continue
    h=$(git -C "$d" rev-parse -q HEAD 2>/dev/null) || continue
    [[ $h == "$tag" ]] && return 0
  done
  return 1
}
TAGS=()
for pkg in xsimd poet snmalloc; do
  tag=$(dep_tag "$pkg")
  dep_cached "$pkg" "$tag" \
    || fail "CPM cache has no $pkg at $tag (pinned by $ADM_SHA); seed the cache on a host with network first"
  TAGS+=("$pkg=$tag")
done

# ------------------------------------------------------------- build here
B=$WORK/build
cmake -S "$SRC" -B "$B" -G Ninja -DCMAKE_BUILD_TYPE=Release \
      -DADM_TARGET_ARCH="$ADM_ARCH" -DADM_BUILD_TESTS=OFF -DADM_BUILD_BENCHMARKS=OFF \
      > "$WORK/b.cfg.log" 2>&1 \
  || { tail -20 "$WORK/b.cfg.log"; fail "configure"; }
cmake --build "$B" -j"$ALLOWED" --target admiral_static > "$WORK/b.build.log" 2>&1 \
  || { tail -30 "$WORK/b.build.log"; fail "build"; }
# shellcheck disable=SC2046
g++ -O3 -march="$ADM_ARCH" -std=c++20 -DADM_STATIC_DEFINE \
    -I"$B/src/generated/include" -I"$SRC/include" \
    $(grep -o '\-isystem [^ ]*' "$B/build.ninja" | sort -u | tr '\n' ' ') \
    "$DRIVER" "$B/src/libadmiral.a" "$B/src/libadmiral_codelets.a" \
    -pthread -o "$WORK/bench_large_route" \
  || fail "driver link"
BIN=$WORK/bench_large_route
BIN_MD5=$(md5sum < "$BIN")

# ------------------------------------------------------------- helpers
HEADER=$'prec\tn\tbytes\tnthreads\troute_forced\troute_elected\tstream_arm_elected\treps\tmin_ns\tguard'
SER_REPS=9;  SER_RAMP=200    # serial ladder measures in ~minutes with these
THR_REPS=101; THR_RAMP=100
TLB_REPS=15; TLB_RAMP=400
CTR_REPS=5                    # counters also run at 3x; differenced off-line

# measure <tsv> <driver args...> — one measurement call: runs the driver,
# verifies the contract on every returned row, and appends the data rows to
# <tsv> (the incremental append a crashed leg is resumed past).
measure() {
  local tsv=$1; shift
  local list='' a
  for a in "$@"; do case $a in --n=*) list=${a#--n=} ;; esac; done
  [[ -n $list ]] || fail "measure: no --n= among driver args: $*"
  local expect
  expect=$(awk -F',' '{print NF}' <<<"$list")
  local raw; raw=$(mktemp "$WORK/raw.XXXXXX") || fail "mktemp"
  if ! "$BIN" "$@" > "$raw"; then
    cp "$raw" "$STEM.failed.txt"
    fail "driver exited nonzero: $BIN $* (raw copied to $STEM.failed.txt)"
  fi
  local n bad
  n=$(awk -F'\t' '($1=="f32" || $1=="f64") {c++} END{print c+0}' "$raw")
  bad=$(awk -F'\t' '($1=="f32" || $1=="f64") && NF<10 {c++} END{print c+0}' "$raw")
  (( bad == 0 )) \
    || { cp "$raw" "$STEM.failed.txt"; fail "contract drift: $bad rows with <10 fields in $raw (copied to $STEM.failed.txt)"; }
  (( n == expect )) \
    || { cp "$raw" "$STEM.failed.txt"; fail "driver emitted $n data rows, expected $expect for --n=$list (raw copied to $STEM.failed.txt)"; }
  awk -F'\t' '($1=="f32" || $1=="f64") {print}' "$raw" >> "$tsv"
  { echo "--- $BIN $* ---"; cat "$raw"; } >> "$STEM.raw.txt"
  rm -f "$raw"
  echo "  [$(date +%T)] $* -> $n rows"
}

fresh_tsv() { # $1=path: start a leg's TSV; a markerless leftover is a crash partial
  local tsv=$1
  if [[ -e $tsv ]]; then
    mv "$tsv" "$tsv.abandoned-$(date +%s)" \
      || fail "mv partial $tsv aside"
    echo "resume: $tsv had no done marker; moved aside as a crash partial"
  fi
  printf '%s\n' "$HEADER" > "$tsv" || fail "write header $tsv"
}

leg_commit() { # $1=leg tag; rest=files to publish into the logbook run dir
  local leg=$1; shift
  local f
  mkdir -p "$RUN_DIR" || fail "mkdir $RUN_DIR"
  for f in "$@"; do
    [[ -f $f ]] || fail "leg_commit $leg: $f missing"
    cp -p "$f" "$RUN_DIR/" || fail "cp $f"
  done
  local rel=${RUN_DIR#"$MEM_REPO"/}
  [[ $rel != "$RUN_DIR" ]] || fail "RUN_DIR $RUN_DIR not under MEM_REPO $MEM_REPO"
  # collect.sbatch:96-103 pattern, plus a lock-retry: up to three class jobs can
  # share this checkout (2-cpu jobs run concurrently under the QOS).
  local try
  for try in 1 2 3 4 5 6; do
    git -C "$MEM_REPO" add -- "$rel" 2>/dev/null \
      && { git -C "$MEM_REPO" diff --cached --quiet -- "$rel" \
           && { echo "leg_commit $leg: no changes (identical re-commit)"; return 0; }
           git -C "$MEM_REPO" commit --only --no-verify -q -m \
             "admiral beat-standings: wi2c large1d $CLASS $KEY ($leg leg, job $SLURM_JOB_ID)" \
             -- "$rel" 2>/dev/null \
           && { echo "leg_commit $leg: committed $rel ($(git -C "$MEM_REPO" rev-parse --short HEAD))"; return 0; }
           true; }
    echo "leg_commit $leg: git index busy (try $try/6); retrying in 20 s"
    sleep 20
  done
  fail "git commit $rel (index lock?); files are on disk in $RUN_DIR — commit login-side"
}

ghz_read() { # measured socket frequency, not lscpu's base clock; ~2% bar
  command -v perf >/dev/null || { echo unknown; return 0; }
  local t0 t1 cyc
  t0=$(date +%s%N)
  cyc=$(perf stat -x, -e cycles -- bash -c 'e=$((SECONDS+2)); while (( SECONDS < e )); do :; done' \
          2>/dev/null | awk -F, '$3=="cycles"{print $1}' | head -1)
  t1=$(date +%s%N)
  [[ $cyc =~ ^[0-9]+$ && $t1 -gt $t0 ]] || { echo unknown; return 0; }
  python3 -c "print(f'{$cyc / ($t1 - $t0):.3f}')"
}

# cache geometry for the evidence header AND the reducer (L3 is the unit of the
# stream-arm multiple being re-derived).
cache_bytes() {
  python3 - <<'PY' 2>/dev/null || true
import subprocess, re
unit = {'K': 1 << 10, 'M': 1 << 20, 'G': 1 << 30}
want = {'L1d': 'L1D_BYTES', 'L2': 'L2_BYTES', 'L3': 'L3_BYTES'}
out = subprocess.check_output(['lscpu', '-C=NAME,ALL-SIZE']).decode()
for ln in out.splitlines():
    name, _, sz = ln.partition(',')
    if name in want:
        m = re.match(r'(\d+)\s*([KMG])', sz.strip())
        if m:
            print('%s,%d' % (want[name], int(m.group(1)) * unit[m.group(2)]))
PY
}

# ------------------------------------------------------- contract smoke gate
# The first driver call proves the CLI, the row shape and the numeric
# self-check end to end before anything is recorded.
SMOKE=$WORK/smoke.txt
"$BIN" --route=dif --prec=f32 --nthreads=1 --n=65536 --reps=3 --ramp-ms=50 \
  > "$SMOKE" || { cat "$SMOKE"; fail "smoke call failed"; }
smk=$(awk -F'\t' '($1=="f32" || $1=="f64") && NF>=10 {c++} END{print c+0}' "$SMOKE")
(( smk == 1 )) || { cat "$SMOKE"; fail "smoke call returned $smk well-formed rows, expected 1"; }

# ------------------------------------------------------- evidence header
{
  echo "=== wi2c large-1-D route-line probe (WI-2c), class $CLASS ==="
  env_report
  echo "JOB,$SLURM_JOB_ID (${SLURM_CPUS_PER_TASK:-?} cpus requested, $ALLOWED allowed, exclusive)"
  echo "CLASS,$CLASS"
  echo "CAP,$CAP"
  echo "ARCH,$ADM_ARCH (matches fi/$CLASS.sbatch BENCH_ARCH)"
  echo "ADM,$YAFFT_SRC @ $ADM_SHA"
  echo "DRIVER,benchmark/bench_large_route.cpp md5 $(md5sum "$DRIVER" | cut -c1-12)"
  echo "BINARY,md5 $BIN_MD5"
  echo "DEPS,${TAGS[*]} (content-verified in $CPM_CACHE: cache-dir HEAD == pinned tag)"
  echo "CPM,$CPMV"
  echo "GHZ,$(ghz_read) (measured: cycles over a 2 s spin window)"
  echo "THP,$(cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null)"
  echo "SMOKE,ok ($smk row, 10-field contract)"
  echo "PINNING,driver self-pins; no taskset anywhere in this job"
  cache_bytes
  echo "--- lscpu -C ---"
  lscpu -C
  module list 2>&1
} | tee "$STEM.env.md"

# =================================================================== legs
SERIAL_NS=262144,524288,1048576,2097152,4194304,8388608,16777216,33554432
THR_NS_F64=8192,16384,32768,65536,131072,262144,524288,1048576,2097152
THR_NS_F32=16384,32768,65536,131072,262144,524288,1048576,2097152,4194304
TLB_NS=16777216,33554432

# ------------------------------------------------------------ serial leg
# N=2^18..2^25 x {f32,f64} x {dif,four_step}, 3 rounds with rotated arm start;
# one auto pass per prec records the route the library elects at every rung.
serial_leg() {
  local mk=$RESUME/$KEY.serial.done
  [[ -f $mk ]] && { echo "RESUME: serial leg complete ($mk); skipped"; return 0; }
  fresh_tsv "$TSV_SERIAL"
  local round prec route routes
  for round in 1 2 3; do
    if (( round % 2 == 1 )); then routes="dif four_step"; else routes="four_step dif"; fi
    for prec in f32 f64; do
      for route in $routes; do
        measure "$TSV_SERIAL" --route="$route" --prec="$prec" --nthreads=1 \
                --n="$SERIAL_NS" --reps="$SER_REPS" --ramp-ms="$SER_RAMP"
      done
    done
    echo "[serial round $round/3 done $(date +%T)]"
  done
  for prec in f32 f64; do
    measure "$TSV_SERIAL" --route=auto --prec="$prec" --nthreads=1 \
            --n="$SERIAL_NS" --reps="$SER_REPS" --ramp-ms="$SER_RAMP"
  done
  leg_commit serial "$TSV_SERIAL" "$STEM.env.md"
  touch "$mk" || fail "touch $mk"
  echo "WI2C_SERIAL_DONE $TSV_SERIAL"
}

# ----------------------------------------------------------- threaded leg
# nthreads in {1,2,4,8,32,CAP} x {f32,f64} x {dif,four_step} over the byte grid
# 128 KiB..32 MiB, 3 rounds with rotated arm start. The threaded law under test
# is bytes > max(kLargeRouteThreadedFloorBytes, kLargeRouteThreadedByteBudget/nt)-1,
# so per-nt crossovers re-derive budget and floor directly.
thread_leg() {
  local mk=$RESUME/$KEY.thread.done
  [[ -f $mk ]] && { echo "RESUME: threaded leg complete ($mk); skipped"; return 0; }
  fresh_tsv "$TSV_THREAD"
  local nts='' nt round prec route routes ns
  for nt in 1 2 4 8 32 "$CAP"; do
    case " $nts " in *" $nt "*) ;; *) nts="$nts $nt" ;; esac
  done
  for round in 1 2 3; do
    if (( round % 2 == 1 )); then routes="dif four_step"; else routes="four_step dif"; fi
    for nt in $nts; do
      for prec in f32 f64; do
        ns=$THR_NS_F32; [[ $prec == f64 ]] && ns=$THR_NS_F64
        for route in $routes; do
          measure "$TSV_THREAD" --route="$route" --prec="$prec" --nthreads="$nt" \
                  --n="$ns" --reps="$THR_REPS" --ramp-ms="$THR_RAMP"
        done
      done
    done
    echo "[thread round $round/3 done $(date +%T)]"
  done
  leg_commit thread "$TSV_THREAD"
  touch "$mk" || fail "touch $mk"
  echo "WI2C_THREAD_DONE $TSV_THREAD"
}

# ------------------------------------------------------------- TLB/page arm
# Timed --huge 0|1 pairs plus probe-guarded counter groups at the top-2 serial
# rungs. Event names are per-class CANDIDATES, each probed for a numeric count
# before use (probe_events); an accepted event that still reports
# <not supported> in a measured run fails the job. znver2 spellings are
# fi/perf/rome_item2b.sbatch:70-73 verbatim; genoa probes the same AMD names;
# icelake probes its own. Nothing is assumed, everything is probed.
tlb_leg() {
  local mk=$RESUME/$KEY.tlb.done
  [[ -f $mk ]] && { echo "RESUME: TLB arm complete ($mk); skipped"; return 0; }
  fresh_tsv "$TSV_TLB"
  printf 'tag,reps,event,value\n' > "$CSV_CTR" || fail "write $CSV_CTR"
  local prec n route huge
  for prec in f32 f64; do
    for n in ${TLB_NS//,/ }; do
      for route in dif four_step; do
        for huge in 0 1; do
          measure "$TSV_TLB" --route="$route" --prec="$prec" --nthreads=1 \
                  --n="$n" --reps="$TLB_REPS" --ramp-ms="$TLB_RAMP" --huge="$huge"
        done
      done
    done
  done

  local base_req="cycles instructions task-clock page-faults dTLB-loads dTLB-load-misses"
  local cls_req
  case "$CLASS" in
    rome|genoa)
      cls_req="ls_l1_d_tlb_miss.all ls_l1_d_tlb_miss.tlb_reload_4k_l2_miss ls_l1_d_tlb_miss.tlb_reload_2m_l2_miss ls_tablewalker.dc_type0 ls_tablewalker.dc_type1 bp_l1_tlb_miss_l2_tlb_miss.if4k" ;;
    icelake)
      cls_req="dtlb_load_misses.walk_completed dtlb_load_misses.walk_pending dtlb_load_misses.stlb_hit dtlb_load_misses.miss_causes_a_walk dtlb_store_misses.walk_completed dtlb_store_misses.stlb_hit" ;;
    *) fail "no TLB event candidates for CLASS=$CLASS" ;;
  esac
  local gbase gcls
  gbase=$(probe_events $base_req)
  gcls=$(probe_events $cls_req)
  {
    report_events base "$(tr ' ' ',' <<<"$base_req")" "$gbase"
    report_events "$CLASS" "$(tr ' ' ',' <<<"$cls_req")" "$gcls"
  } | tee "$STEM.tlb.events.txt"
  [[ -n $gbase ]] || fail "base counter group accepted nothing on $CLASS"
  [[ -n $gcls ]] || fail "no class-specific TLB event accepted on $CLASS (requested: $cls_req)"

  local tag g r f
  for prec in f32 f64; do
    for n in ${TLB_NS//,/ }; do
      for route in dif four_step; do
        for huge in 0 1; do
          tag=$CLASS:$prec:$n:$route:h$huge
          for g in "$gbase" "$gcls"; do
            for r in "$CTR_REPS" $((3 * CTR_REPS)); do
              f=$(mktemp "$WORK/perf.XXXXXX") || fail "mktemp"
              perf stat -x, -o "$f" -e "$g" -- \
                "$BIN" --route="$route" --prec="$prec" --nthreads=1 --n="$n" \
                --reps="$r" --ramp-ms=200 --huge="$huge" >/dev/null 2>>"$LOGERR" \
                || fail "perf stat failed at $tag reps=$r (see $LOGERR)"
              if grep -q -e '<not supported>' -e '<not counted>' "$f"; then
                cp "$f" "$STEM.failed.perf.txt"
                fail "counter <not supported>/<not counted> at $tag reps=$r group=[$g] (raw at $STEM.failed.perf.txt)"
              fi
              awk -F, -v t="$tag" -v rr="$r" \
                '!/^#/ && NF>=3 && $1!="" { gsub(/^ +| +$/, "", $3); printf "%s,%s,%s,%s\n", t, rr, $3, $1 }' \
                "$f" >> "$CSV_CTR"
              rm -f "$f"
            done
          done
          echo "  [$(date +%T)] counters $tag done"
        done
      done
    done
  done
  leg_commit tlb "$TSV_TLB" "$CSV_CTR" "$STEM.tlb.events.txt"
  touch "$mk" || fail "touch $mk"
  echo "WI2C_DONE $RUN_DIR"
}

serial_leg
thread_leg
tlb_leg

rm -rf "$WORK"
echo "WI2C_ALL_LEGS_COMPLETE $KEY"
