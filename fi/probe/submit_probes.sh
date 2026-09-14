#!/bin/bash
# Submit (or, with --check, only print) the granule transfer probe wave: one
# parameterized job (fi/probe/granule_transfer.sbatch) per host class. The ONLY
# sbatch lines of the probe wave live here (fi/perf/submit.sh precedent).
#
#   fi/probe/submit_probes.sh [--check]
#
#   ADM_REF=<ref>    yafft revision to probe (default team/integration tip;
#                    resolved to a full sha here, exported, and stamped into
#                    every output filename; the manager records the exact
#                    integrated sha in the submit note)
#   YAFFT_SRC=<dir>  yafft checkout the workers git-archive from
#                    (default /mnt/home/mbarbone/repos/yafft)
#   RESULTS_DIR=<d>  where the class TSVs land (default fi/probe/results)
#
# Cadence is queue-3/run-2 BY QOS ARITHMETIC, the choice of the standings wave
# (SUBMIT.md, wi0d): each class job takes an exclusive node at that node's full
# cpu width (128/64/96), so any two fit the 256-cpu QOS and the third pends.
# No afterok chains; the probe wave shares no files with the standings wave.
#
# Every prerequisite below is checked in BOTH modes, all found problems are
# listed, and NOTHING is submitted while one is open: a plan that green-lights
# missing inputs is how empty probes reach the scheduler.
set -uo pipefail

SELF=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FI=$(dirname "$SELF")
CLASSES=(rome icelake genoa)
# ADM_TARGET_ARCH per class, matched to the sweeps' BENCH_ARCH in
# fi/<class>.sbatch (znver2 is gcc's name for the x86-64-v3-class uarch).
declare -A ARCH_OF=([rome]=znver2 [icelake]=icelake-server [genoa]=znver4)
# Full logical-cpu width of each node class (fi/<class>.sbatch); the QOS lever.
declare -A CPUS_OF=([rome]=128 [icelake]=64 [genoa]=96)
YAFFT_SRC=${YAFFT_SRC:-/mnt/home/mbarbone/repos/yafft}
ADM_REF=${ADM_REF:-team/integration}
RESULTS_DIR=${RESULTS_DIR:-$SELF/results}
CPM_CACHE=/mnt/home/mbarbone/cpm-cache

MODE=submit
[[ ${1:-} == --check ]] && MODE=--check
[[ ${1:-} == --check || -z ${1:-} ]] || { echo "usage: $0 [--check]" >&2; exit 1; }

# ------------------------------------------------------------ prerequisites
PROBLEMS=()
note() { PROBLEMS+=("$1"); }
for t in sbatch md5sum git python3; do
  command -v $t >/dev/null || note "no $t on PATH (not a slurm login node?)"
done
for f in granule_transfer.sbatch canon_rows.py reduce_transfer.py; do
  [[ -f $SELF/$f ]] || note "missing $SELF/$f"
done
ADM_SHA=$(git -C "$YAFFT_SRC" rev-parse --verify -q "${ADM_REF}^{commit}" 2>/dev/null) \
  || note "cannot resolve ADM_REF=$ADM_REF in $YAFFT_SRC"
if [[ -n ${ADM_SHA:-} ]]; then
  git -C "$YAFFT_SRC" cat-file -e "$ADM_SHA:benchmark/bench_granule_ab.cpp" 2>/dev/null \
    || note "benchmark/bench_granule_ab.cpp absent at ${ADM_SHA:0:7} ($ADM_REF): the driver lands with round-2 integration (team/2-runner); point ADM_REF at a tree that carries it"
  git -C "$YAFFT_SRC" show "$ADM_SHA:CMakeLists.txt" 2>/dev/null | grep -q 'option(ADM_GRANULE_ADMIT' \
    || note "ADM_GRANULE_ADMIT knob absent in CMakeLists.txt at ${ADM_SHA:0:7} (lands from the wi0a seam)"
fi
# The workers are offline; no cache, no build (fi/perf/submit.sh:116-131).
for d in cpm xsimd poet; do
  [[ -d $CPM_CACHE/$d ]] || note "CPM cache missing $CPM_CACHE/$d: the on-node builds cannot run offline"
done
if [[ ! -d $RESULTS_DIR && ! -w $(dirname "$RESULTS_DIR") ]]; then
  note "cannot create RESULTS_DIR=$RESULTS_DIR"
fi

# ------------------------------------------------------------------ the plan
echo "granule transfer probe wave (WI-0a-ii)"
echo "  yafft:   $YAFFT_SRC @ ${ADM_SHA:-UNRESOLVED} ($ADM_REF)"
echo "  driver:  benchmark/bench_granule_ab.cpp at that sha (canonicalizer fi/probe/canon_rows.py)"
echo "  arms:    ADM_GRANULE_ADMIT ON vs OFF; both built on the node from git archive"
echo "           (offline: CPM cache $CPM_CACHE), Release + ADM_TARGET_ARCH=<class arch>,"
echo "           then benchmark/bench_granule_ab.cpp linked against each static tree;"
echo "           md5-distinct gate + nm granule-census gate before anything is timed"
echo "  measure: exclusive node, one pinned physical core (idle sibling), 12 rounds with"
echo "           rotated arm start, 2 same-arm repeats per turn (the control floor),"
echo "           48 driver invocations x 5 cells = 240 rows"
echo "  results: $RESULTS_DIR/<class>-<date>-${ADM_SHA:0:7}.{tsv,env.md,raw.txt}"
echo "           (rerun protection: an existing stem fails the job loudly)"
echo ""
for c in "${CLASSES[@]}"; do
  printf '  %-8s sbatch --constraint=%s&rocky9 --cpus-per-task=%d -J fftg-ab-%s \\\n' \
    "$c" "$c" "${CPUS_OF[$c]}" "$c"
  printf '           -o %s/%s.slurm.%%j.log --export=ALL,CLASS=%s,ADM_SHA=%s,ADM_ARCH=%s,YAFFT_SRC=%s,RESULTS_DIR=%s \\\n' \
    "$RESULTS_DIR" "$c" "$c" "${ADM_SHA:-?}" "${ARCH_OF[$c]}" "$YAFFT_SRC" "$RESULTS_DIR"
  printf '           %s/granule_transfer.sbatch\n' "$SELF"
done
echo ""
echo "  cadence: queue-3/run-2 by QOS arithmetic: 128+64=192, 128+96=224, 64+96=160 <= 256,"
echo "           all three 288 > 256, so the third pends until a probe frees its node."
echo "           Watch: squeue -u \$USER; markers GRANULE_AB_DONE / GRANULE_AB_FAIL in the"
echo "           slurm logs. Reduce after all three land:"
echo "             fi/probe/reduce_transfer.py"

if (( ${#PROBLEMS[@]} > 0 )); then
  echo ""
  printf 'BLOCKER: %s\n' "${PROBLEMS[@]}" >&2
  exit 1
fi
if [[ $MODE == --check ]]; then
  echo ""
  echo "--check: nothing submitted, nothing seeded."
  exit 0
fi

# -------------------------------------------------------------------- submit
mkdir -p "$RESULTS_DIR" || { echo "FAIL: mkdir $RESULTS_DIR" >&2; exit 1; }
cd "$SELF" || { echo "FAIL: no $SELF" >&2; exit 1; }
rc=0
for c in "${CLASSES[@]}"; do
  out=$(sbatch --constraint="$c&rocky9" --cpus-per-task="${CPUS_OF[$c]}" -J "fftg-ab-$c" \
        -o "$RESULTS_DIR/$c.slurm.%j.log" \
        --export="ALL,CLASS=$c,ADM_SHA=$ADM_SHA,ADM_ARCH=${ARCH_OF[$c]},YAFFT_SRC=$YAFFT_SRC,RESULTS_DIR=$RESULTS_DIR" \
        "$SELF/granule_transfer.sbatch") || { echo "FAIL: sbatch $c: $out" >&2; rc=1; continue; }
  jid=${out##* }
  [[ $jid =~ ^[0-9]+$ ]] || { echo "FAIL: unparsable sbatch output for $c: $out" >&2; rc=1; continue; }
  printf '  %-8s job %s\n' "$c" "$jid"
done
(( rc == 0 )) || { echo "one or more submissions failed; see above" >&2; exit 1; }
echo ""
echo "submitted 3 probe jobs at $ADM_SHA ($ADM_REF)."
echo "watch:  squeue -u \$USER (the third pends under the 256-cpu QOS; nothing to babysit)"
echo "reduce: fi/probe/reduce_transfer.py   # after all three land ($RESULTS_DIR)"
