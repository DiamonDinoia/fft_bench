# Shared helpers for the counter jobs. Source it; do not execute it.
#
# Two rules the callers depend on:
#   - Every event is probed before use. `perf stat -e <unknown>` runs NOTHING and exits
#     non-zero, so one bad name in a list silently costs the whole arm.
#   - Nothing is reduced here. Every counter lands in the log as a raw CSV row tagged with
#     its arm and rep count; the differencing happens off-line, where it can be re-derived.

LOGERR=${LOGERR:-/dev/stderr}

# probe_events <event>... -> comma-joined subset this kernel and CPU actually count
# A name the parser accepts is not a counter that counts. `l3_comb_clstr_state.request_miss`
# passed an exit-status-only probe on znver2 and then returned `<not supported>` for all 22
# rows of a four-hour job: AMD's L3 PMU is uncore and cannot be attributed to one process.
# So the probe demands a NUMERIC value from a workload long enough to accumulate one, and
# each event is still probed alone, because `perf stat -e <unknown>` runs nothing at all.
probe_events() {
  local ok=() e out v
  for e in "$@"; do
    out=$(perf stat -e "$e" -x, -- sleep 0.05 2>&1) || continue
    v=$(awk -F, -v ev="$e" '$3 == ev {print $1}' <<<"$out" | head -1)
    [[ $v =~ ^[0-9]+$ ]] || continue
    ok+=("$e")
  done
  (IFS=,; echo "${ok[*]}")
}

# report_events <label> <requested-csv> <accepted-csv>
report_events() {
  echo "EVENTS,$1,requested,$2"
  echo "EVENTS,$1,accepted,$3"
}

# perf_run <tag> <cpus> <bin> <dim> <n> <nthreads> <reps> <events-csv>
# Emits one `CTR,<tag>,<reps>,<event>,<value>` row per counter. Keep <tag> free of commas. Rounds is 1: the counter is
# the answer here, and a second round would double the work the counter is attributed to.
perf_run() {
  local tag=$1 cpus=$2 bin=$3 dim=$4 n=$5 nt=$6 reps=$7 ev=$8
  # A measured run with the trace on charges admiral an fprintf pair per transform and MKL
  # nothing, which is how a whole icelake counter phase read 38 us for a 1-D 1024.
  [[ -n ${PERF_CELL_DEBUG:-} ]] && { echo "PERF_LIB_FAIL: PERF_CELL_DEBUG set during a measured run" >&2; exit 1; }
  local f; f=$(mktemp)
  taskset -c "$cpus" perf stat -x, -o "$f" -e "$ev" -- "$bin" "$dim" "$n" "$nt" "$reps" 1 \
    >/dev/null 2>>"$LOGERR"
  awk -F, -v t="$tag" -v r="$reps" '!/^#/ && NF >= 3 && $1 != "" {
        gsub(/^ +| +$/, "", $3); printf "CTR,%s,%s,%s,%s\n", t, r, $3, $1 }' "$f"
  rm -f "$f"
}

# time_run <tag> <cpus> <bin> <dim> <n> <nthreads> <reps> <rounds>
# Emits `TIME,<tag>,<us per execute>`. The binary already takes the minimum over `rounds`.
time_run() {
  local tag=$1 cpus=$2 bin=$3 dim=$4 n=$5 nt=$6 reps=$7 rounds=$8 us
  # A measured run with the trace on charges admiral an fprintf pair per transform and MKL
  # nothing, which is how a whole icelake counter phase read 38 us for a 1-D 1024.
  [[ -n ${PERF_CELL_DEBUG:-} ]] && { echo "PERF_LIB_FAIL: PERF_CELL_DEBUG set during a measured run" >&2; exit 1; }
  us=$(taskset -c "$cpus" "$bin" "$dim" "$n" "$nt" "$reps" "$rounds" 2>>"$LOGERR")
  echo "TIME,$tag,${us:-NA}"
}

# reps_for <total-elements> -> a rep count that keeps one arm near a tenth of a second
reps_for() {
  # Declare before use. `local a=$1 b=$((a))` creates BOTH names first and only then assigns,
  # so `a` is still unset inside the arithmetic and `set -u` aborts the whole job.
  local n=$1
  local r=$(( 200000000 / (n > 0 ? n : 1) ))
  (( r < 3 )) && r=3
  (( r > 20000 )) && r=20000
  echo "$r"
}

# env_report: everything a fresh reader needs to re-run this on the same node
env_report() {
  echo "HOST,$(hostname)"
  echo "DATE,$(date -Is)"
  echo "CPU,$(lscpu | awk -F: '/Model name/{gsub(/^ +/,"",$2); print $2; exit}')"
  echo "KERNEL,$(uname -r)"
  echo "PERF,$(perf --version 2>&1 | head -1)"
  echo "PARANOID,$(cat /proc/sys/kernel/perf_event_paranoid 2>/dev/null)"
  echo "NUMA,$(lscpu | awk -F: '/NUMA node\(s\)/{gsub(/^ +/,"",$2); print $2; exit}')"
}

# One route-recording run per cell, at 1 rep, OUTSIDE any measured region. admiral prints its
# elected route per execute, so the variable must never be exported for a timed or counted run.
route_of() {
  local tag=$1 cpus=$2 bin=$3 dim=$4 n=$5 nt=$6
  local out
  out=$(PERF_CELL_DEBUG=2 taskset -c "$cpus" "$bin" "$dim" "$n" "$nt" 1 1 2>&1 >/dev/null \
        | grep -m1 '^\[admiral\]' | tr ',' ' ')
  echo "ROUTE,$tag,${out:-none}"
}
