#!/bin/bash
#SBATCH --job-name=fftb-standings
#SBATCH --partition=gen
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --time=02:00:00
# The -j8 admiral build peaks at 20 GB of cc1plus RSS at znver4 (3.2 GB per TU; measured on
# ccmlin075 2026-09-05). Under 16G the genoa job thrashed inside the cgroup for 2 h and gcc
# died in combine.cc, which read as an ICE.
#SBATCH --mem=48G
#SBATCH --output=/mnt/home/mbarbone/repos/fft_bench/fi/step5/%x-%j.out
#SBATCH --export=NONE
#
# Step 5 standings: admiral BEFORE (885c93f) vs AFTER (7e4bd88) vs MKL, single-thread
# 1-D complex f64 forward, N in {256,512,1024,2048,4096}, interleaved rounds, min-reduce.
# Submit with fi/step5/submit_standings.sh (one sbatch per host class). Each job clones
# fft_bench and its submodules from the local checkouts into node scratch, so jobs are
# independent of each other and never touch the working tree.
#
# A compute node sees /mnt/home and /mnt/sw only. /home/mbarbone (the workstation's
# localcache: CPM, ccache, scratch) does not exist there, and --export=NONE keeps the
# submitting shell's pointers into it out of the job. Everything the job writes goes to
# /mnt/home (outputs) or to node /tmp (scratch, wiped by the epilog).
set -uo pipefail

FFT_BENCH_REPO=/mnt/home/mbarbone/repos/fft_bench
YAFFT_REPO=/mnt/home/mbarbone/repos/yafft
# admiral pulls xsimd and poet through CPM. The login shell's cache is node-local
# (/home/mbarbone) and a compute node has neither it nor a network, so the configure reads
# this pre-populated cache on /mnt/home and fails loudly instead of trying to fetch.
export CPM_SOURCE_CACHE=/mnt/home/mbarbone/.cpm-mnt
ADMIRAL_BEFORE=885c93f
ADMIRAL_AFTER=7e4bd88
ROUNDS=${ROUNDS:-7}  # override only for a local dry run; --export=NONE blocks it under sbatch
SHIFTS=(8 9 10 11 12)  # N=2^shift; run_fft<> registers as "1 << shift", not decimal N

# --- host tag from CPU model, for output naming; independent of --constraint spelling ---
model=$(grep -m1 '^model name' /proc/cpuinfo)
case "$model" in
  *7742*) HOST_TAG=rome ;;
  *9474*) HOST_TAG=genoa ;;
  *"Xeon(R) Platinum 83"*|*"Xeon(R) Gold 63"*|*"Xeon(R) Silver 43"*) HOST_TAG=icelake ;;
  *) HOST_TAG=$(hostname -s) ;;
esac
DATE_TAG=$(date +%Y-%m-%d)
OUT_MD="${FFT_BENCH_REPO}/fi/step5/${HOST_TAG}-${DATE_TAG}.md"

# --- node-local scratch (not /dev/shm: tmpfs is charged to the job's --mem) ---
SCRATCH="${SLURM_TMPDIR:-/tmp}/${USER}/fftb-bench-${SLURM_JOB_ID}"
mkdir -p "$SCRATCH"/{before,after}
export CCACHE_DIR="$SCRATCH/ccache" XDG_CACHE_HOME="$SCRATCH/xdg"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# --- toolchain: gcc 14.3.0 is the version compatible with MKL 2026.0.0 under
# modules/2.5-beta1 on this Lmod tree (matches the gcc/fftw/mkl combo fft_bench's
# README documents); load modules INSIDE this script, the env does not persist. ---
set +u  # lmod's setup.sh reads ENABLE_LMOD unset in a bare (--export=NONE) environment
source /etc/profile.d/modules.sh
module purge --force >/dev/null 2>&1 || true
module load modules/2.5-beta1 gcc/14.3.0 fftw/3.3.11 intel-oneapi-mkl/2026.0.0 cmake/3.31.11 ninja/1.13.2
set -u
unset NINJA_STATUS
log "toolchain: $(g++ --version | head -1), $(cmake --version | head -1) ($(command -v cmake)), ninja $(ninja --version) ($(command -v ninja)), MKLROOT=$MKLROOT"

# --- CPU frequency scaling off if this uid can (best effort; report GHz regardless) ---
PINCPU=$(python3 -c 'import os; print(sorted(os.sched_getaffinity(0))[0])' 2>/dev/null || echo 0)
log "pinning to logical CPU $PINCPU (from cgroup-allowed set)"

# Source tree per arm: fft_bench HEAD plus every submodule at its recorded sha, all cloned
# --shared from the local checkouts (no network), then extern/admiral moved to the arm's ref.
clone_tree() {
  local admiral_ref="$1" dest="$2"
  git clone -q --shared "${FFT_BENCH_REPO}" "$dest"
  while read -r sha path _; do
    git clone -q --shared "${FFT_BENCH_REPO}/${path}" "${dest}/${path}"
    git -C "${dest}/${path}" -c advice.detachedHead=false checkout -q --detach "${sha#[-+]}"
  done < <(git -C "${FFT_BENCH_REPO}" submodule status)
  git -C "${dest}/extern/admiral" fetch -q "${YAFFT_REPO}" master
  git -C "${dest}/extern/admiral" -c advice.detachedHead=false checkout -q --detach "${admiral_ref}"
  git -C "${dest}/extern/admiral" log -1 --oneline
}

build_arm() {
  local admiral_ref="$1" build_dir="$2"
  local src="${build_dir}-src"
  log "clone tree with extern/admiral @ ${admiral_ref} into ${src}"
  clone_tree "${admiral_ref}" "${src}" >>"$SCRATCH/build.log" 2>&1 || {
    echo "CLONE FAIL: ${admiral_ref} (see $SCRATCH/build.log)" >> "$SCRATCH/verdicts.txt"; return; }
  cmake -S "${src}" -B "${build_dir}" -G Ninja -DFETCHCONTENT_FULLY_DISCONNECTED=ON \
    -DCMAKE_BUILD_TYPE=Release -DBENCH_ARCH=native >>"$SCRATCH/build.log" 2>&1 || {
    echo "CONFIGURE FAIL: ${build_dir}" >> "$SCRATCH/verdicts.txt"
    log "configure failed, build.log tail:"; tail -40 "$SCRATCH/build.log"; return; }
  for tgt in admiral_bench admiral_omp_bench mkl_bench; do
    log "building $tgt in $build_dir"
    nice -n19 ionice -c3 cmake --build "${build_dir}" --target "$tgt" -j8 >>"$SCRATCH/build.log" 2>&1
    rc=$?
    log "$tgt exit=$rc"
    if [[ $rc -ne 0 ]]; then
      echo "BUILD FAIL: $tgt in $build_dir (see $SCRATCH/build.log)" >> "$SCRATCH/verdicts.txt"
      log "build.log tail:"; tail -40 "$SCRATCH/build.log"
    else
      echo "BUILD PASS: $tgt in $build_dir" >> "$SCRATCH/verdicts.txt"
    fi
  done
}

: > "$SCRATCH/verdicts.txt"
build_arm "$ADMIRAL_BEFORE" "$SCRATCH/before"
build_arm "$ADMIRAL_AFTER"  "$SCRATCH/after"

BIN_BEFORE="$SCRATCH/before/admiral_bench"
BIN_AFTER="$SCRATCH/after/admiral_bench"
BIN_AFTER_OMP="$SCRATCH/after/admiral_omp_bench"
BIN_MKL="$SCRATCH/after/mkl_bench"

MEASURE_TSV="$SCRATCH/measure.tsv"
: > "$MEASURE_TSV"
echo -e "arm\tsize\tround\tns_per_op" >> "$MEASURE_TSV"

run_one() {
  local bin="$1" regex="$2"
  taskset -c "$PINCPU" "$bin" --benchmark_filter="$regex" --benchmark_repetitions=1 \
    --benchmark_format=json --benchmark_report_aggregates_only=false 2>/dev/null \
    | python3 -c "
import json,sys
d=json.load(sys.stdin)
b=d['benchmarks'][0]
scale={'ns':1.0,'us':1e3,'ms':1e6,'s':1e9}[b.get('time_unit','ns')]
print(b['real_time']*scale)
"
}

if [[ -x "$BIN_BEFORE" && -x "$BIN_AFTER" && -x "$BIN_MKL" ]]; then
  for round in $(seq 1 "$ROUNDS"); do
    for shift in "${SHIFTS[@]}"; do
      N=$((1 << shift))
      regex="run_fft<1 << ${shift}, 1>\$"
      echo -e "before\t$N\t$round\t$(run_one "$BIN_BEFORE" "$regex")" >> "$MEASURE_TSV"
      echo -e "after\t$N\t$round\t$(run_one "$BIN_AFTER" "$regex")"   >> "$MEASURE_TSV"
      echo -e "mkl\t$N\t$round\t$(run_one "$BIN_MKL" "$regex")"      >> "$MEASURE_TSV"
      echo -e "after2\t$N\t$round\t$(run_one "$BIN_AFTER" "$regex")" >> "$MEASURE_TSV"
    done
  done
else
  log "missing one or more binaries, skipping measurement (see verdicts.txt)"
fi

# supplementary: nthreads=0 auto, one round each
AUTO_TSV="$SCRATCH/auto.tsv"
: > "$AUTO_TSV"
echo -e "size\tns_per_op" >> "$AUTO_TSV"
if [[ -x "$BIN_AFTER_OMP" ]]; then
  for shift in "${SHIFTS[@]}"; do
    N=$((1 << shift))
    regex="run_fft<1 << ${shift}, 1>\$"
    echo -e "$N\t$(run_one "$BIN_AFTER_OMP" "$regex")" >> "$AUTO_TSV"
  done
fi

# GHz check: one perf stat read per arm at N=1024 (best-effort; perf may be unavailable)
GHZ_LOG="$SCRATCH/ghz.txt"
: > "$GHZ_LOG"
for tag_bin in "before:$BIN_BEFORE" "after:$BIN_AFTER" "mkl:$BIN_MKL"; do
  tag="${tag_bin%%:*}"; bin="${tag_bin#*:}"
  [[ -x "$bin" ]] || continue
  perf stat -e cycles,task-clock -- taskset -c "$PINCPU" "$bin" \
    --benchmark_filter="run_fft<1 << 10, 1>\$" --benchmark_min_time=0.2s \
    >/dev/null 2>>"$GHZ_LOG"
  echo "--- $tag ---" >> "$GHZ_LOG"
done

# --- reduce: min over rounds per (arm,size); write the deliverable ---
python3 - "$MEASURE_TSV" "$AUTO_TSV" "$GHZ_LOG" "$SCRATCH/verdicts.txt" "$OUT_MD" "$HOST_TAG" "$DATE_TAG" "$ROUNDS" <<'PYEOF'
import sys, collections
measure_tsv, auto_tsv, ghz_log, verdicts_txt, out_md, host_tag, date_tag, rounds = sys.argv[1:9]

mins = collections.defaultdict(lambda: float("inf"))
with open(measure_tsv) as f:
    next(f)
    for line in f:
        parts = line.rstrip("\n").split("\t")
        if len(parts) != 4:
            continue
        arm, size, rnd, ns = parts
        try:
            ns = float(ns)
        except ValueError:
            continue
        mins[(arm, size)] = min(mins[(arm, size)], ns)

sizes = ["256", "512", "1024", "2048", "4096"]
lines = []
lines.append(f"# fft_bench step 5 standings — {host_tag}, {date_tag}\n")
lines.append("Generated by fi/step5/run_standings.sbatch. Single-thread 1-D complex f64 forward.\n")
lines.append("## Build verdicts\n")
try:
    with open(verdicts_txt) as f:
        for line in f:
            lines.append(f"- {line.strip()}")
except FileNotFoundError:
    lines.append("- verdicts file missing")
lines.append("")
lines.append(f"## Standings (ns/transform, min over {rounds} interleaved rounds)\n")
lines.append("| N | before | after | mkl | after2 (control) | before/mkl | after/mkl |")
lines.append("|---|---|---|---|---|---|---|")
for size in sizes:
    b = mins.get(("before", size))
    a = mins.get(("after", size))
    m = mins.get(("mkl", size))
    a2 = mins.get(("after2", size))
    def fmt(x):
        return f"{x:.1f}" if x not in (None, float("inf")) else "n/a"
    rb = f"{b/m:.3f}" if b and m and m not in (0, float('inf')) else "n/a"
    ra = f"{a/m:.3f}" if a and m and m not in (0, float('inf')) else "n/a"
    lines.append(f"| {size} | {fmt(b)} | {fmt(a)} | {fmt(m)} | {fmt(a2)} | {rb} | {ra} |")

lines.append("")
lines.append("## Supplementary: admiral nthreads=0 (auto), one round\n")
lines.append("| N | ns/transform |")
lines.append("|---|---|")
try:
    with open(auto_tsv) as f:
        next(f)
        for line in f:
            size, ns = line.rstrip("\n").split("\t")
            lines.append(f"| {size} | {ns} |")
except FileNotFoundError:
    pass

lines.append("")
lines.append("## perf stat cycles/task-clock (GHz check), one run per arm at N=1024\n")
lines.append("```")
try:
    with open(ghz_log) as f:
        lines.append(f.read())
except FileNotFoundError:
    lines.append("(perf unavailable)")
lines.append("```")

with open(out_md, "w") as f:
    f.write("\n".join(lines) + "\n")
print(f"wrote {out_md}")
PYEOF

log "done, wrote $OUT_MD"
cat "$SCRATCH/verdicts.txt"
