#!/bin/bash
# Submit every outstanding job in one go: the four counter jobs and the full standings sweep.
# This is a thin driver. All build, verification and sbatch logic lives in the two scripts it
# calls, so there is one copy of each and this file cannot drift from them.
#
#   fi/submit_queue.sh            build, verify and submit everything
#   fi/submit_queue.sh --check    build and verify only, print every sbatch line, submit nothing
#
# What goes out, and what each answers:
#
#   perf/submit.sh      icelake_item3   admiral vs MKL on icelake (restarts the invalid 7020147)
#                       rome_item2b     why admiral stalls on large 1-D: aliasing or TLB
#                       tiny_ab x2      the flat_tiny N=8 W=8 leaf on icelake and genoa
#   submit_all.sh       the 3-host standings sweep, 18 charts
#
# The standings sweep measures ADMIRAL_REF, which defaults to the yafft checkout's master.
# Item 0 (auto thread election) is committed on `fix/auto-thread-election` and NOT on master,
# so the default below points there. Change it once that branch merges.
set -uo pipefail

FI=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
MODE=${1:-submit}
case "$MODE" in --check|submit) ;; *) echo "usage: $0 [--check]" >&2; exit 1 ;; esac

export ADMIRAL_REF=${ADMIRAL_REF:-fix/auto-thread-election}
echo "=== ADMIRAL_REF=$ADMIRAL_REF"

# Only submit_all.sh resolves the ref, so on 2026-09-11 the counter jobs were built against
# extern/admiral's existing e61ae17 while the sweep benchmarked b5aa45c. Pin the submodule here,
# BEFORE either stage builds, so both measure one tree. submit_all.sh then re-resolves to the
# same sha and its checkout is a no-op.
REPO=$(cd "$FI/.." && pwd)
YAFFT=$(cd "$REPO/extern/admiral" && git rev-parse --show-toplevel >/dev/null 2>&1 \
        && echo "$REPO/extern/admiral") || { echo "no extern/admiral" >&2; exit 1; }
SHA=$(git -C "$HOME/repos/yafft" rev-parse --verify -q "${ADMIRAL_REF}^{commit}") \
  || { echo "cannot resolve ADMIRAL_REF=$ADMIRAL_REF in ~/repos/yafft" >&2; exit 1; }
git -C "$YAFFT" fetch -q "$HOME/repos/yafft" "$SHA" 2>/dev/null || true
git -C "$YAFFT" -c advice.detachedHead=false checkout -q --detach "$SHA" \
  || { echo "cannot check out $SHA in extern/admiral" >&2; exit 1; }
echo "=== extern/admiral pinned to $(git -C "$YAFFT" log -1 --oneline)"

# Collect both verdicts and fail at the end. A half-submitted queue is worse than none, so
# --check is the way to find a broken tree before anything reaches the scheduler.
rc=0
echo "=== counter jobs"
"$FI/perf/submit.sh" "$MODE" || { echo "FAIL: perf/submit.sh" >&2; rc=1; }
echo
echo "=== standings sweep"
"$FI/submit_all.sh" "$MODE"  || { echo "FAIL: submit_all.sh" >&2; rc=1; }

echo
if (( rc != 0 )); then
  echo "one or more stages failed; see above" >&2
  exit 1
fi
if [[ "$MODE" == "--check" ]]; then
  echo "--check: nothing submitted. Re-run without --check to queue everything."
  exit 0
fi
echo "all queued. Watch: squeue -u \$USER"
