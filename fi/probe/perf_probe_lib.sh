# Shared helpers for the band-counter probe jobs. Source it; do not execute it.
#
# PROVENANCE: copy of the main checkout's UNTRACKED fi/perf/perf_lib.sh
# (probe_events, report_events, perf_run, time_run, reps_for, env_report, route_of
# are verbatim), extended for WI-2a with:
#   - probe_events_run: the same numeric-count probe but under a real workload.
#     The sleep-probe cannot see FP classes (a 0.05 s sleep retires zero FLOPs, so
#     fp_ret_sse_avx_ops.* would be rejected as non-counting), and on the rome
#     partition it silently dropped task-clock and the whole ls_dmnd_fills G2
#     group in fi/perf/rome_item2b.log (EVENTS,G2,accepted,<empty>).
#   - gate_events_counted: fail-loud gate. Every requested event must produce a
#     numeric count BEFORE any measurement; a blocked perf is exit 1, never a
#     silent hole.
#   - env_report extended: ADM sha, per-binary md5, lscpu -C cache sizes, GHz read.
#
# Two rules the callers depend on (inherited):
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
    # Decimal counts are numeric too: task-clock prints msec ("0.59"), and an
    # integer-only test is exactly how task-clock fell out of item2b's G1.
    [[ $v =~ ^[0-9]+([.][0-9]+)?$ ]] || continue
    ok+=("$e")
  done
  (IFS=,; echo "${ok[*]}")
}

# probe_events_run <workload...> -- <event>...
# probe_events with a caller-chosen workload instead of `sleep 0.05`: an idle sleep
# accumulates no FP FLOPs and no demand fills, so the FP and fill classes would be
# rejected by a workload this thin. Used by the WI-2a gate with a real transform run.
probe_events_run() {
  local wl=() e out v
  while [[ $# -gt 0 && $1 != -- ]]; do wl+=("$1"); shift; done
  [[ ${1:-} == -- ]] && shift
  local ok=()
  for e in "$@"; do
    # perf writes the -x, table to stderr; the workload's own stdout is the noise.
    # Redirect order matters: 2>&1 first captures the table, then >/dev/null drops the noise.
    out=$(perf stat -e "$e" -x, -- "${wl[@]}" 2>&1 >/dev/null) || continue
    v=$(awk -F, -v ev="$e" '$3 == ev {print $1}' <<<"$out" | head -1)
    [[ $v =~ ^[0-9]+([.][0-9]+)?$ ]] || continue
    ok+=("$e")
  done
  (IFS=,; echo "${ok[*]}")
}

# gate_events_counted <label> <workload...> -- <event>...
# Every requested event must count under the workload, else the job exits before any
# measurement. Prints one EVENTS,requested/accepted pair per label on success; on
# failure prints the dropped names and exits 1.
gate_events_counted() {
  local label=$1; shift
  local wl=() req=("$@") n_req=0 acc e
  while [[ $# -gt 0 && $1 != -- ]]; do wl+=("$1"); shift; done
  [[ ${1:-} == -- ]] && shift
  req=("$@"); n_req=${#req[@]}
  acc=$(probe_events_run "${wl[@]}" -- "${req[@]}")
  local n_acc=0 IFS_save=$IFS
  IFS=,
  # shellcheck disable=SC2206
  local acc_a=($acc)
  IFS=$IFS_save
  n_acc=${#acc_a[@]}; [[ -z $acc ]] && n_acc=0
  report_events "$label" "$(IFS=,; echo "${req[*]}")" "$acc"
  if (( n_acc != n_req )); then
    local miss=()
    for e in "${req[@]}"; do
      case ",$acc," in *,"$e",*) ;; *) miss+=("$e");; esac
    done
    echo "WI2_FAIL: gate $label dropped ${#miss[@]} of $n_req events: ${miss[*]:-none?}" >&2
    echo "WI2_FAIL: a blocked perf is exit 1, never a silent hole (perf $(perf --version 2>&1 | head -1), kernel $(uname -r))" >&2
    exit 1
  fi
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

# env_report [binary...]: everything a fresh reader needs to re-run this on the same node.
# WI-2a extension: with binaries given, append ADM sha, per-binary md5, lscpu -C cache
# sizes and a GHz read, so the job log carries the exact objects it measured.
env_report() {
  echo "HOST,$(hostname)"
  echo "DATE,$(date -Is)"
  echo "CPU,$(lscpu | awk -F: '/Model name/{gsub(/^ +/,"",$2); print $2; exit}')"
  echo "KERNEL,$(uname -r)"
  echo "PERF,$(perf --version 2>&1 | head -1)"
  echo "PARANOID,$(cat /proc/sys/kernel/perf_event_paranoid 2>/dev/null)"
  echo "NUMA,$(lscpu | awk -F: '/NUMA node\(s\)/{gsub(/^ +/,"",$2); print $2; exit}')"
  echo "ADMSHA,${ADM_SHA:-unset}"
  local b
  for b in "$@"; do
    echo "BINMD5,$(basename "$b"),$(md5sum < "$b" | cut -c1-12)"
  done
  # Explicit column list: the default column order of `lscpu -C` is util-linux-versioned.
  lscpu -C=NAME,ONE-SIZE,ALL-SIZE,WAYS,SETS 2>/dev/null \
    | awk 'NR>1 {printf "CACHE,%s,one=%s,all=%s,ways=%s,sets=%s\n", $1, $2, $3, $4, $5}'
  # A GHz read, not a calibration: current and rated clocks as the node reports them.
  echo "MHZ_LSCPU,$(lscpu | awk -F: '/CPU max MHz|CPU MHz/{gsub(/^ +/,"",$2); printf "%s,", $2}')"
  echo "MHZ_PROC,$(awk -F: '/cpu MHz/{gsub(/^ +/,"",$2); s+=$2; n+=1} END{if (n) printf "%.0f", s/n; else printf "NA"}' /proc/cpuinfo)"
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
