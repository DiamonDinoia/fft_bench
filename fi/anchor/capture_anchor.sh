#!/bin/bash
# Capture one era's anchor binaries into the durable GPFS anchor store.
#
#   fi/anchor/capture_anchor.sh <era-id> [--repo <fft_bench checkout>] [--jobs <j1,j2,j3>]
#   fi/anchor/capture_anchor.sh --self-test
#
# Per class c in rome/icelake/genoa this stores
#   $ANCHORS/<era-id>/$c/admiral_bench   (sweep wobble cells run through this)
#   $ANCHORS/<era-id>/$c/admiral_cell    (granule cells 12^2/24^2 run through this)
# plus a manifest $ANCHORS/<era-id>/MD5SUMS (paths relative to the era root) and a
# README.md with the provenance (repo sha, admiral sha, toolchain, source job ids).
#
# The store graduates the ad-hoc binaries in ~/bisect-regression/bin and
# ~/env-control-e61/bin: an era is minted ONCE and then immutable (refuse-to-overwrite),
# because the probe jobs of every later sweep resolve their anchor arm against it.
#
# --self-test exercises the same capture/verify code path against a scratch set of dummy
# binaries, touching neither the store nor any build tree.
set -uo pipefail

ANCHORS=${FFT_BENCH_ANCHORS:-/mnt/home/mbarbone/fft_bench_anchors}
CLASSES=(rome icelake genoa)
BINS=(admiral_bench admiral_cell)

fail() { echo "FAIL: $*" >&2; exit 1; }

# capture_era <src_root> <dst_era> <label_for_readme>
# Copies $src_root/build-<c>/$bin per class, writes MD5SUMS, verifies it. Common path for
# the real capture and --self-test.
capture_era() {
  local src_root=$1 dst=$2
  local c b src rel
  mkdir -p "$dst" || fail "mkdir $dst"
  : > "$dst/MD5SUMS" || fail "write $dst/MD5SUMS"
  for c in "${CLASSES[@]}"; do
    mkdir -p "$dst/$c" || fail "mkdir $dst/$c"
    for b in "${BINS[@]}"; do
      src="$src_root/build-$c/$b"
      [[ -x $src ]] || { echo "MISSING: $src" >&2; return 1; }
      cp "$src" "$dst/$c/$b" || { echo "COPY FAIL: $src" >&2; return 1; }
      rel="$c/$b"
      (cd "$dst" && md5sum "$rel" >> MD5SUMS) || return 1
    done
  done
  (cd "$dst" && md5sum -c MD5SUMS >/dev/null) \
    || { echo "MANIFEST FAIL: $dst/MD5SUMS does not verify" >&2; return 1; }
  echo "captured $(( ${#CLASSES[@]} * ${#BINS[@]} )) anchor binaries in $dst (MD5SUMS green)"
}

if [[ ${1:-} == --self-test ]]; then
  # Dummy binary set: two classes worth of distinct content under a scratch build root,
  # captured into a scratch anchors root. Verifies manifest creation + verification.
  T=$(mktemp -d /tmp/anchor-selftest.XXXXXX) || fail "mktemp"
  trap 'rm -rf "$T"' EXIT
  for c in "${CLASSES[@]}"; do
    for b in "${BINS[@]}"; do
      mkdir -p "$T/build-$c"
      printf 'dummy %s %s\n' "$c" "$b" > "$T/build-$c/$b"
      chmod +x "$T/build-$c/$b"
    done
  done
  capture_era "$T" "$T/store/test-era" || fail "self-test capture"
  # The manifest must notice a flipped byte; otherwise it decorates the store.
  printf 'tampered\n' > "$T/store/test-era/rome/admiral_bench"
  if (cd "$T/store/test-era" && md5sum -c MD5SUMS >/dev/null 2>&1); then
    fail "self-test: manifest did NOT detect tampering"
  fi
  echo "SELF_TEST_OK: capture + manifest verify + tamper detection all green"
  exit 0
fi

ERA=${1:-}; shift || true
[[ -n $ERA ]] || fail "usage: $0 <era-id> [--repo <path>] [--jobs <j1,j2,j3>] | --self-test"
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
JOBS_STR=""
while (($#)); do
  case $1 in
    --repo) REPO=$2; shift 2 ;;
    --jobs) JOBS_STR=$2; shift 2 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

DST=$ANCHORS/$ERA
[[ -e $DST ]] && fail "$DST already exists; eras are immutable (mint a new era-id)"
command -v md5sum >/dev/null || fail "md5sum not on PATH"
for c in "${CLASSES[@]}"; do
  for b in "${BINS[@]}"; do
    [[ -x $REPO/build-$c/$b ]] || fail "missing $REPO/build-$c/$b"
  done
done

FB_SHA=$(git -C "$REPO" rev-parse --verify -q HEAD 2>/dev/null || echo unknown)
ADM_SHA=$(git -C "$REPO/extern/admiral" rev-parse --verify -q HEAD 2>/dev/null || echo unknown)

capture_era "$REPO" "$DST" || fail "capture into $DST"

cat > "$DST/README.md" <<EOF
# Anchor binaries, $ERA

Captured $(date -Is) on $(hostname) by fi/anchor/capture_anchor.sh.

- fft_bench @ $FB_SHA
- admiral   @ $ADM_SHA (${REPO}/extern/admiral)
- source trees: $REPO/build-{rome,icelake,genoa} (gcc 14.3.0 rocky9, one -march per class)
${JOBS_STR:+- sweep jobs: $JOBS_STR}
- layout: <class>/{admiral_bench, admiral_cell}; verify with \`md5sum -c MD5SUMS\` here.

admiral_bench anchors the sweep wobble cells (1-D 2^18/2^19/2^20), admiral_cell anchors
the granule cells (2-D 12x12, 24x24); see fi/anchor/probe.sbatch.
EOF
echo "anchor era $ERA ready at $DST"
