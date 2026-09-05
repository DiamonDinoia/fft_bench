#!/bin/bash
# Usage: measure.sh <out.tsv> <pin_cpu> <rounds> <bin_before> <bin_after> <bin_mkl> <shifts...>
# shift = log2(N); run_fft<> is registered as "1 << shift", not the decimal N.
set -uo pipefail
OUT="$1"; PIN="$2"; ROUNDS="$3"; BIN_BEFORE="$4"; BIN_AFTER="$5"; BIN_MKL="$6"; shift 6
SHIFTS=("$@")

: > "$OUT"
echo -e "arm\tN\tround\tns_per_op" >> "$OUT"

run_one() {
  local bin="$1" regex="$2"
  taskset -c "$PIN" "$bin" --benchmark_filter="$regex" --benchmark_repetitions=1 \
    --benchmark_format=json --benchmark_report_aggregates_only=false 2>/dev/null \
    | python3 -c "
import json,sys
d=json.load(sys.stdin)
b=d['benchmarks'][0]
t=b['real_time']
u=b.get('time_unit','ns')
scale={'ns':1.0,'us':1e3,'ms':1e6,'s':1e9}[u]
print(t*scale)
"
}

for round in $(seq 1 "$ROUNDS"); do
  for shift in "${SHIFTS[@]}"; do
    N=$((1 << shift))
    regex="run_fft<1 << ${shift}, 1>\$"
    t=$(run_one "$BIN_BEFORE" "$regex"); echo -e "before\t$N\t$round\t$t" >> "$OUT"
    t=$(run_one "$BIN_AFTER" "$regex");  echo -e "after\t$N\t$round\t$t" >> "$OUT"
    t=$(run_one "$BIN_MKL" "$regex");    echo -e "mkl\t$N\t$round\t$t" >> "$OUT"
    t=$(run_one "$BIN_AFTER" "$regex");  echo -e "after2\t$N\t$round\t$t" >> "$OUT"
  done
done
