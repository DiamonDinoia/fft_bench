#!/bin/bash
# Submit the three standings jobs against the trees ALREADY built by submit_all.sh --check.
# Nothing is compiled here, so the binaries the nodes run are the ones smoke-tested on the
# workstation.
#
#   fi/submit_standings.sh
#
# Results land in fi/ as <impl>-<class>.json. Reduce with
#   fi/geomean_table.py fi/baseline-2026-09-11-e61ae17
# and redraw with
#   fi/submit_all.sh --plots
set -uo pipefail

FI=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(dirname "$FI")
CLASSES=(rome icelake genoa)
BINS=(mkl_bench fftw3_bench pocket_bench kiss_bench ducc_bench sleef_bench admiral_bench
      mkl_omp_bench fftw3_omp_bench ducc_omp_bench admiral_omp_bench)

fail() { echo "FAIL: $*" >&2; exit 1; }

# A tree older than the harness source would silently benchmark the previous harness.
src=$(stat -c %Y "$REPO/src/fft_bench.cpp")
for c in "${CLASSES[@]}"; do
  [[ -f "$FI/$c.sbatch" ]] || fail "no $FI/$c.sbatch"
  for b in "${BINS[@]}"; do
    p="$REPO/build-$c/$b"
    [[ -x "$p" ]] || fail "missing $p; run fi/submit_all.sh --check first"
    (( $(stat -c %Y "$p") >= src )) || fail "$p is older than src/fft_bench.cpp; rebuild"
  done
done
echo "pin: $(git -C "$REPO/extern/admiral" log -1 --oneline)"
echo "checked $(( ${#CLASSES[@]} * ${#BINS[@]} )) binaries, all newer than the harness source"

# The jsons about to be overwritten are the only copy of the previous sweep.
arch="$FI/prev-$(date +%Y-%m-%d_%H%M)"
mkdir -p "$arch" && cp -p "$FI"/*.json "$arch"/ 2>/dev/null
echo "previous jsons copied to ${arch#"$REPO"/}"

cd "$FI" || fail "no $FI"
for c in "${CLASSES[@]}"; do
  sbatch "$c.sbatch" || fail "sbatch $c.sbatch"
done
echo
echo "watch:  squeue -u \$USER"
echo "logs:   $FI/{rome,icelake,genoa}.log"
echo "reduce: fi/geomean_table.py fi/baseline-2026-09-11-e61ae17"
