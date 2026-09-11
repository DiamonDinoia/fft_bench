#!/bin/bash
# Cross-host decision on flat_tiny at N = 8, W = 8, f64.
#
# The r5 wave excluded this shape on a cross-host sign flip read off WHOLE-TRANSFORM A/Bs
# (icelake 3d_8 -3.3% against genoa +3.1%), where the leaf is only 47% of the cell and the
# resolution is about 3%. This job takes the same decision on the LEAF, which resolves about
# ten times finer, on the two host classes the shape exists on. rome is W = 4 for f64 and
# already admits flat_tiny, so it is not in scope.
#
# Submit once per class, overriding the constraint:
#   sbatch --constraint='icelake&rocky9' -J tiny_ab_ice   fi/perf/tiny_ab.sbatch
#   sbatch --constraint='genoa&rocky9'   -J tiny_ab_genoa fi/perf/tiny_ab.sbatch
#
# Both trees are built ON THE NODE at -march=native from the same commit, one with the
# patch and one without, so no cross-compile can misread the target width.
#SBATCH --partition=gen
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --cpus-per-task=32
#SBATCH --time=01:30:00
#SBATCH --output=/mnt/home/mbarbone/repos/fft_bench/fi/perf/tiny_ab_%j.log
#SBATCH --error=/mnt/home/mbarbone/repos/fft_bench/fi/perf/tiny_ab_%j.stderr
set -uo pipefail

PERF=/mnt/home/mbarbone/repos/fft_bench/fi/perf
SRC=/mnt/home/mbarbone/repos/yafft
BASE_SHA=b5aa45c69c705dc845ee23fa5c3c4b999a4b9f81
WORK=${TMPDIR:-/tmp}/tiny_ab.$SLURM_JOB_ID

source /etc/profile.d/modules.sh
# A worker's default module tree carries neither gcc 14 nor cmake; `modules/2.5-beta1` is what
# exposes them, and every other job here loads it first. Job 7020427 skipped it and died in
# under a second with "no gcc module". Never pipe `module`: it is a shell function, and a pipe
# runs it in a subshell that discards the environment changes while still exiting 0.
module purge >/dev/null 2>&1
module load modules/2.5-beta1 >/dev/null 2>&1 \
  || { echo "TINY_AB_FAIL: no modules/2.5-beta1"; exit 1; }
module load gcc/14.3.0 cmake/3.31.11 ninja/1.13.2 >/dev/null 2>&1 \
  || { echo "TINY_AB_FAIL: no gcc/cmake/ninja"; exit 1; }
# A name that resolves on PATH is not a tool that works. Ask each one its own version.
for t in "g++ -dumpversion" "cmake --version" "ninja --version"; do
  $t >/dev/null 2>&1 || { echo "TINY_AB_FAIL: '$t' does not run"; exit 1; }
done
echo "TOOLS,g++ $(g++ -dumpversion),cmake $(cmake --version | head -1),ninja $(ninja --version)"
unset NINJA_STATUS
# The workstation cache lives under /home, which is node-local and does not exist here.
# CPM would otherwise try to fetch xsimd and poet from a worker that has no route out.
export CPM_SOURCE_CACHE=/mnt/home/mbarbone/cpm-cache
for d in cpm xsimd poet; do
  [[ -d $CPM_SOURCE_CACHE/$d ]] || { echo "TINY_AB_FAIL: $CPM_SOURCE_CACHE/$d missing"; exit 1; }
done

echo "HOST,$(hostname),$(lscpu | sed -n 's/^Model name: *//p' | head -1)"
echo "BASE_SHA,$BASE_SHA"

mkdir -p "$WORK" || { echo "TINY_AB_FAIL: mkdir $WORK"; exit 1; }
for arm in base ft; do
  git -C "$SRC" worktree list >/dev/null 2>&1
  git clone --quiet --no-checkout --shared "$SRC" "$WORK/$arm" \
    || { echo "TINY_AB_FAIL: clone $arm"; exit 1; }
  git -C "$WORK/$arm" checkout --quiet "$BASE_SHA" \
    || { echo "TINY_AB_FAIL: checkout $arm"; exit 1; }
  if [[ $arm == ft ]]; then
    git -C "$WORK/$arm" apply "$PERF/flat_tiny_w8.patch" \
      || { echo "TINY_AB_FAIL: patch did not apply"; exit 1; }
  fi
  cmake -S "$WORK/$arm" -B "$WORK/$arm/b" -G Ninja -DCMAKE_BUILD_TYPE=Release \
        -DADM_TARGET_ARCH=native -DADM_BUILD_TESTS=OFF -DADM_BUILD_BENCHMARKS=OFF \
        > "$WORK/$arm.cfg.log" 2>&1 || { tail -20 "$WORK/$arm.cfg.log"; echo "TINY_AB_FAIL: configure $arm"; exit 1; }
  cmake --build "$WORK/$arm/b" -j16 --target admiral_static \
        > "$WORK/$arm.build.log" 2>&1 || { tail -30 "$WORK/$arm.build.log"; echo "TINY_AB_FAIL: build $arm"; exit 1; }
  for drv in kern whole; do
    g++ -O3 -march=native -std=c++20 -DADM_STATIC_DEFINE \
        -I"$WORK/$arm/b/src/generated/include" -I"$WORK/$arm/include" \
        $(grep -o '\-isystem [^ ]*' "$WORK/$arm/b/build.ninja" | sort -u | tr '\n' ' ') \
        "$PERF/$drv.cpp" "$WORK/$arm/b/src/libadmiral.a" "$WORK/$arm/b/src/libadmiral_codelets.a" \
        -pthread -o "$WORK/${arm}_$drv" \
        || { echo "TINY_AB_FAIL: link $arm $drv"; exit 1; }
  done
  echo "BUILT,$arm,$(md5sum "$WORK/${arm}_kern" | cut -c1-12)"
done

# Distinct objects, or the A/B is an A/A.
if [[ $(md5sum < "$WORK/base_kern") == $(md5sum < "$WORK/ft_kern") ]]; then
  echo "TINY_AB_FAIL: the two kern binaries are identical; the patch reached no code"
  exit 1
fi

# The static mix is the mechanism claim and needs no run.
for arm in base ft; do
  a=$(nm --defined-only "$WORK/$arm/b/src/libadmiral_codelets.a" 2>/dev/null | \
      while read _ _ m; do [[ $(echo "$m" | c++filt) == *"codelet_many_static<8u, double, true>"* ]] && echo "$m"; done | head -1)
  objdump -d --disassemble="$a" "$WORK/$arm/b/src/CMakeFiles/admiral_codelets.dir/codelet_8.cpp.o" 2>/dev/null | \
    awk -v arm="$arm" '/\t/ {op=$0; sub(/.*\t/,"",op); split(op,f," "); m=f[1]; t++
      if (m ~ /^v(perm|shuf|unpck|pblend|blend|insert|extract|align|movdup|broadcast)/) s++
      if (m ~ /^v(fmadd|fmsub|fnmadd|fnmsub|mulp|addp|subp)/) p++}
      END {printf "MIX,%s,total=%d,shuffle=%d,fp=%d\n", arm, t, s, p}'
done

CORE=$(lscpu -e=CPU,CORE | awk 'NR>1 && $2==4 {print $1; exit}')
[[ -z $CORE ]] && CORE=4
echo "PINNED_CORE,$CORE"

# Leaf, the measurement the r5 wave never took. Arm order rotates per round.
for round in 1 2 3 4 5; do
  order="base ft"; (( round % 2 == 0 )) && order="ft base"
  for arm in $order; do
    for cell in "8 64" "4 16" "16 16"; do
      set -- $cell
      v=$(taskset -c "$CORE" "$WORK/${arm}_kern" "$1" "$2" 200000 rows 2>&1 | \
          sed -n 's/.*rows_ns=\([0-9.]*\).*/\1/p')
      [[ -z $v ]] && { echo "TINY_AB_FAIL: leaf $arm $1 $2 produced nothing"; exit 1; }
      echo "LEAF,$arm,$1,$2,$v"
    done
  done
done

# Whole transform, the cell the r5 wave decided on, plus the neighbours that must not move.
for round in 1 2 3 4 5; do
  order="base ft"; (( round % 2 == 0 )) && order="ft base"
  for arm in $order; do
    for cell in "3 8" "3 4" "2 16" "2 32" "1 512"; do
      set -- $cell
      v=$(taskset -c "$CORE" "$WORK/${arm}_whole" "$1" "$2" 40000 5 2>/dev/null)
      [[ -z $v ]] && { echo "TINY_AB_FAIL: whole $arm $1 $2 produced nothing"; exit 1; }
      echo "WHOLE,$arm,$1,$2,$v"
    done
  done
done

rm -rf "$WORK"
echo "TINY_AB_DONE"
