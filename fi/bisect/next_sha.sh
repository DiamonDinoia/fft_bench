#!/bin/bash
# fi/bisect/next_sha.sh — pure-readonly bisect arithmetic for the WI-1c range.
# Prints the next admiral sha to probe: git's own midpoint pick over <bad> ^<good>.
#
#   fi/bisect/next_sha.sh [<good> <bad>]      next midpoint (default: the WI-1c bracket)
#   fi/bisect/next_sha.sh --list [<good> <bad>]
#                                             numbered remaining candidates, oldest first
#
# Mutates nothing, submits nothing. Adjacent inputs (no commit strictly between) are the
# boundary-pair close: fi/bisect/README.md's decision rule applies from there.
set -uo pipefail

YAFFT=${YAFFT:-/mnt/home/mbarbone/repos/yafft}
MODE=next
[[ ${1:-} == --list ]] && { MODE=list; shift; }
GOOD=${1:-e61ae17}
BAD=${2:-a799b6b}

fail() { echo "FAIL: $*" >&2; exit 1; }
G=$(git -C "$YAFFT" rev-parse --verify -q "${GOOD}^{commit}") || fail "cannot resolve good=$GOOD"
B=$(git -C "$YAFFT" rev-parse --verify -q "${BAD}^{commit}")  || fail "cannot resolve bad=$BAD"
git -C "$YAFFT" merge-base --is-ancestor "$G" "$B" \
  || fail "good (${G:0:7}) is not an ancestor of bad (${B:0:7}); refuse to orient the range"

N=$(git -C "$YAFFT" rev-list --count "$B" ^"$G")

if [[ $MODE == list ]]; then
  echo "# $N candidate(s) in ${G:0:7}..${B:0:7} (oldest first; 'old' is the FAST side):"
  git -C "$YAFFT" rev-list --reverse --format='%h %s' "$B" ^"$G" | grep -v '^commit' | cat -n
  exit 0
fi

if [[ $N == 0 ]]; then
  fail "empty range ${G:0:7}..${B:0:7} (good == bad?); nothing to bisect"
fi
if [[ $N == 1 ]]; then
  # rev-list BAD ^GOOD includes the bad tip itself, so N==1 means nothing sits between
  # the two classified probes: the boundary pair has closed.
  echo "BOUNDARY_PAIR: ${G:0:7} (FAST-class) and ${B:0:7} (SLOW-class) are adjacent —"
  echo "no unprobed commit between them; ${B:0:7} contains the culprit. Close per fi/bisect/README.md."
  git -C "$YAFFT" log -1 --format='  culprit tip: %h %ad %s' --date=iso-strict "$B"
  exit 0
fi

MID=$(git -C "$YAFFT" rev-list --bisect "$B" ^"$G")
echo "remaining=$N  next midpoint:"
git -C "$YAFFT" log -1 --format='  SHA=%h  %ad  %s' --date=short "$MID"
echo "then: SHA=$MID fi/bisect/bisect_sha.sh            # build + print the sbatch line"
echo "      SHA=$MID fi/bisect/bisect_sha.sh --submit   # queue the one probe job"
