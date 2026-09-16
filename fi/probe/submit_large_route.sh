#!/bin/bash
# Submit (or, with --check, only print) the WI-2c large-1-D route-line probe
# wave: one parameterized job (fi/probe/large_route.sbatch) per host class,
# re-deriving the four_step_large admission lines of
# include/admiral/detail/four_step_large.hpp:398-407 per host class. The ONLY
# sbatch lines of this wave live here (fi/probe/submit_probes.sh precedent);
# --constraint goes on the submit line, never into the sbatch.
#
#   fi/probe/submit_large_route.sh [--check]
#
#   ADM_REF=<ref>      yafft revision to probe (default master tip;
#                      resolved to a full sha HERE, exported, and stamped into
#                      every output filename; the manager records the exact
#                      integrated sha in the submit note)
#   YAFFT_SRC=<dir>    yafft checkout the workers git-archive from
#                      (default /mnt/home/mbarbone/repos/yafft)
#   RESULTS_DIR=<d>    where the class TSVs + resume markers land (default
#                      fi/probe/results; must be node-visible)
#   MEM_REPO=<dir>     logbook checkout the jobs self-commit their leg
#                      artifacts into (default /mnt/home/mbarbone/repos/memory;
#                      run dirs admiral/beat-standings/runs/wi2c-<class>-<sha7>)
#   WI2C_CPUS=<n>      --cpus-per-task (default 2: the allocation is exclusive
#                      and the driver pins; a job that finds fewer than its
#                      class CAP cpus in its cpuset fails loudly, and raising
#                      this is the escape hatch)
#
# Cadence: 3 x 2-cpu exclusive jobs run CONCURRENTLY under the 256-cpu QOS
# (6 cpus of 256); the probe wave's queue-3/run-2 lockstep does not apply.
#
# Every prerequisite below is checked in BOTH modes and nothing is submitted
# while one is open (a plan that green-lights missing inputs is how empty
# probes reach the scheduler). The one exception is the bench_large_route
# DRIVER, owned by the WI-2c peer lane: in --check mode its absence at ADM_REF
# is reported as PEER-PENDING (this package cannot land it); in submit mode it
# is a hard BLOCKER.
set -uo pipefail

SELF=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CLASSES=(rome icelake genoa)
# ADM_TARGET_ARCH per class (fi/<class>.sbatch BENCH_ARCH; znver2 is gcc's
# x86-64-v3 uarch name); CAP is the full logical-cpu width, the threaded leg's
# top nthreads.
declare -A ARCH_OF=([rome]=znver2 [icelake]=icelake-server [genoa]=znver4)
declare -A CAP_OF=([rome]=128 [icelake]=64 [genoa]=96)
YAFFT_SRC=${YAFFT_SRC:-/mnt/home/mbarbone/repos/yafft}
ADM_REF=${ADM_REF:-master}
RESULTS_DIR=${RESULTS_DIR:-$SELF/results}
MEM_REPO=${MEM_REPO:-/mnt/home/mbarbone/repos/memory}
WI2C_CPUS=${WI2C_CPUS:-2}
CPM_CACHE=/mnt/home/mbarbone/cpm-cache

MODE=submit
[[ ${1:-} == --check ]] && MODE=--check
[[ ${1:-} == --check || -z ${1:-} ]] || { echo "usage: $0 [--check]" >&2; exit 1; }

# ------------------------------------------------------------ prerequisites
PROBLEMS=()
PENDING=()
note() { PROBLEMS+=("$1"); }
pend() { PENDING+=("$1"); }
for t in sbatch md5sum git python3 awk; do
  command -v $t >/dev/null || note "no $t on PATH (not a slurm login node?)"
done
for f in large_route.sbatch perf_probe_lib.sh reduce_large_route.py; do
  [[ -f $SELF/$f ]] || note "missing $SELF/$f"
done
bash -n "$SELF/large_route.sbatch" 2>/dev/null || note "$SELF/large_route.sbatch fails bash -n"
ADM_SHA=$(git -C "$YAFFT_SRC" rev-parse --verify -q "${ADM_REF}^{commit}" 2>/dev/null) \
  || note "cannot resolve ADM_REF=$ADM_REF in $YAFFT_SRC"
if [[ -n ${ADM_SHA:-} ]]; then
  git -C "$YAFFT_SRC" cat-file -e "$ADM_SHA:benchmark/bench_large_route.cpp" 2>/dev/null \
    || pend "benchmark/bench_large_route.cpp absent at ${ADM_SHA:0:7} ($ADM_REF): the driver lands from the WI-2c peer lane; submission blocks until ADM_REF points at a tree carrying it"
  git -C "$YAFFT_SRC" show "$ADM_SHA:include/admiral/detail/four_step_large.hpp" 2>/dev/null \
    | grep -qE 'kLargeRoute(ThreadedByteBudget|ThreadCapBytes)' \
    || note "kLargeRoute* constants absent in four_step_large.hpp at ${ADM_SHA:0:7} (the WI measures those lines)"
  git -C "$YAFFT_SRC" show "$ADM_SHA:include/admiral/detail/four_step_large.hpp" 2>/dev/null \
    | grep -q 'kFourStepStreamL3Mult' \
    || note "kFourStepStreamL3Mult absent at ${ADM_SHA:0:7} (in WI-2c scope via its comment)"
fi

# The workers are offline; no cache, no build. [[ -d ]] is the base gate; the
# per-dep loop is the content proof: some cache dir's checked-out HEAD must be
# exactly the revision the tree at ADM_REF pins (cache dirs retain .git).
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
for d in cpm xsimd poet snmalloc; do
  [[ -d $CPM_CACHE/$d ]] || note "CPM cache missing $CPM_CACHE/$d: the on-node build cannot run offline"
done
if [[ -n ${ADM_SHA:-} ]]; then
  for pkg in xsimd poet snmalloc; do
    tag=$(git -C "$YAFFT_SRC" show "$ADM_SHA:cmake/Dependencies.cmake" 2>/dev/null \
          | awk -v pkg="$pkg" '$0 ~ "NAME "pkg {f=1} f && /GIT_TAG/ {print $2; exit}')
    dep_cached "$pkg" "$tag" \
      || note "CPM cache has no $pkg at ${tag:-<unpinned>} (pinned by ${ADM_SHA:0:7}); seed the cache on a host with network first"
  done
  CPMV=$(git -C "$YAFFT_SRC" show "$ADM_SHA:cmake/CPM.cmake" 2>/dev/null \
         | awk '/set\(CPM_DOWNLOAD_VERSION/{gsub(/\)/, "", $2); print $2; exit}')
  [[ -f $CPM_CACHE/cpm/CPM_${CPMV:-?}.cmake ]] \
    || note "CPM cache missing cpm/CPM_${CPMV:-?}.cmake (pinned by ${ADM_SHA:0:7})"
fi
[[ -d $MEM_REPO/.git ]] || note "MEM_REPO=$MEM_REPO is not a git checkout"
[[ -d $MEM_REPO/admiral/beat-standings/runs ]] \
  || note "MEM_REPO=$MEM_REPO lacks admiral/beat-standings/runs"
case $RESULTS_DIR in
  /mnt/home/*|/home/*) ;;
  *) note "RESULTS_DIR=$RESULTS_DIR is not under /mnt/home or /home (not node-visible?)" ;;
esac
if [[ ! -d $RESULTS_DIR && ! -w $(dirname "$RESULTS_DIR") ]]; then
  note "cannot create RESULTS_DIR=$RESULTS_DIR"
fi
[[ $WI2C_CPUS =~ ^[0-9]+$ && $WI2C_CPUS -ge 2 ]] || note "WI2C_CPUS=$WI2C_CPUS not an integer >= 2"

# ------------------------------------------------------------------ the plan
echo "wi2c large-1-D route-line probe wave (WI-2c)"
echo "  yafft:    $YAFFT_SRC @ ${ADM_SHA:-UNRESOLVED} ($ADM_REF)"
echo "  driver:   benchmark/bench_large_route.cpp at that sha"
echo "            bench_large_route --route={auto|dif|four_step} --prec={f32|f64}"
echo "              [--nthreads=N] [--bytes=LIST|--n=LIST] [--reps=R] [--ramp-ms=M]"
echo "              [--huge={0,1}] [--out=TSV]   (contract verbatim; stdout rows appended)"
echo "  under test: four_step_large.hpp:398-407 threaded budget 2 MiB / floor 512 KiB-1,"
echo "              serial f64 12 MiB, f32 window 16 MiB-1..32 MiB, and :38's"
echo "              kFourStepStreamL3Mult=2; test pins test_route_forced.cpp:188-204,"
echo "              :206-212, :333-349"
echo "  build:    on the exclusive node, Release + ADM_TARGET_ARCH=<class arch>, from"
echo "            git archive (CPM cache $CPM_CACHE, dep revisions content-verified)"
echo "  serial:   N=2^18..2^25 x {f32,f64} x {dif,four_step} x 3 rotated rounds (+auto);"
echo "            coverage PAST the f32 window top: 256 MiB f32 / 512 MiB f64"
echo "  threaded: nthreads in {1,2,4,8,32,CAP} x {f32,f64} x {dif,four_step} x 3 rounds,"
echo "            byte grid 128 KiB..32 MiB (union of the spec's two readings)"
echo "  tlb:      N in {2^24,2^25} x {f32,f64} x {dif,four_step} x --huge={0,1} timed"
echo "            pairs + probe-guarded counters (rome item2b names; icelake/genoa"
echo "            probed the same way; <not supported> in a measured run = loud fail)"
echo "  results:  $RESULTS_DIR/wi2c-<class>-${ADM_SHA:0:7}.{serial,thread,tlb}.tsv"
echo "            resume markers $RESULTS_DIR/resume/ (re-submission skips done legs;"
echo "            markerless TSVs are moved aside as crash partials, never resumed)"
echo "  logbook:  per-leg self-commit + DONE marker into"
echo "            $MEM_REPO/admiral/beat-standings/runs/wi2c-<class>-${ADM_SHA:0:7}/"
echo "            (collect.sbatch:96-103 pattern, single job, no chained collect)"
echo ""
for c in "${CLASSES[@]}"; do
  printf '  %-8s sbatch --constraint=%s&rocky9 --cpus-per-task=%d -J wi2c-lr-%s \\\n' \
    "$c" "$c" "$WI2C_CPUS" "$c"
  printf '           -o %s/wi2c-%s.slurm.%%j.log --export=ALL,CLASS=%s,ADM_SHA=%s,ADM_ARCH=%s,YAFFT_SRC=%s,RESULTS_DIR=%s,MEM_REPO=%s \\\n' \
    "$RESULTS_DIR" "$c" "$c" "${ADM_SHA:-?}" "${ARCH_OF[$c]}" "$YAFFT_SRC" "$RESULTS_DIR" "$MEM_REPO"
  printf '           %s/large_route.sbatch    # CAP=%s\n' "$SELF" "${CAP_OF[$c]}"
done
echo ""
echo "  cadence:  3 x $WI2C_CPUS-cpu exclusive jobs run concurrently under the 256-cpu QOS."
echo "            watch: squeue -u \$USER; markers WI2C_SERIAL_DONE / WI2C_THREAD_DONE /"
echo "            WI2C_DONE / WI2C_FAIL in $RESULTS_DIR/wi2c-*.slurm.*.log"
echo "            reduce after all three land: fi/probe/reduce_large_route.py"

if (( ${#PROBLEMS[@]} > 0 )); then
  echo ""
  printf 'BLOCKER: %s\n' "${PROBLEMS[@]}" >&2
  exit 1
fi
if (( ${#PENDING[@]} > 0 )); then
  echo ""
  printf 'PEER-PENDING: %s\n' "${PENDING[@]}"
  if [[ $MODE != --check ]]; then
    echo "submit: peer-pending items are blockers at submission time" >&2
    exit 1
  fi
fi
if [[ $MODE == --check ]]; then
  echo ""
  echo "--check: nothing submitted, nothing built, nothing seeded."
  exit 0
fi

# -------------------------------------------------------------------- submit
mkdir -p "$RESULTS_DIR" || { echo "FAIL: mkdir $RESULTS_DIR" >&2; exit 1; }
cd "$SELF" || { echo "FAIL: no $SELF" >&2; exit 1; }
rc=0
for c in "${CLASSES[@]}"; do
  out=$(sbatch --constraint="$c&rocky9" --cpus-per-task="$WI2C_CPUS" -J "wi2c-lr-$c" \
        -o "$RESULTS_DIR/wi2c-$c.slurm.%j.log" \
        --export="ALL,CLASS=$c,ADM_SHA=$ADM_SHA,ADM_ARCH=${ARCH_OF[$c]},YAFFT_SRC=$YAFFT_SRC,RESULTS_DIR=$RESULTS_DIR,MEM_REPO=$MEM_REPO" \
        "$SELF/large_route.sbatch") || { echo "FAIL: sbatch $c: $out" >&2; rc=1; continue; }
  jid=${out##* }
  [[ $jid =~ ^[0-9]+$ ]] || { echo "FAIL: unparsable sbatch output for $c: $out" >&2; rc=1; continue; }
  printf '  %-8s job %s\n' "$c" "$jid"
done
(( rc == 0 )) || { echo "one or more submissions failed; see above" >&2; exit 1; }
echo ""
echo "submitted 3 probe jobs at $ADM_SHA ($ADM_REF)."
echo "watch:  squeue -u \$USER (all three run concurrently under the QOS)"
echo "reduce: fi/probe/reduce_large_route.py   # after all three land ($RESULTS_DIR)"
