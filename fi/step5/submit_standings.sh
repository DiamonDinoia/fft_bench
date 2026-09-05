#!/bin/bash
# Submit the step-5 standings job once per host class. The jobs are independent (each builds
# from its own scratch clone), so they may run at the same time.
set -eu
cd "$(dirname "$0")/../.."
hosts=("$@"); (( ${#hosts[@]} )) || hosts=(rome genoa)   # e.g. submit_standings.sh genoa icelake
for host in "${hosts[@]}"; do
  sbatch --constraint="${host}&rocky9" fi/step5/run_standings.sbatch
done
