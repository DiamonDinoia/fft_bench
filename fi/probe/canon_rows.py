#!/usr/bin/env python3
"""Canonicalize one bench_granule_ab invocation's stdout into transfer-probe rows.

fi/probe/granule_transfer.sbatch runs the driver 48 times per class
(12 rounds x 2 arms x 2 same-arm repeats) and feeds each invocation's stdout
through this canonicalizer. fi/probe/reduce_transfer.py imports the same cell
table, so the cell universe exists in exactly one place.

Driver contract (yafft benchmark/bench_granule_ab.cpp print_row; kAdmitted at
0350855, 19 rows): one row per (cell, prec), tab-separated key=value fields
behind the literal marker 'ab':

    ab	cell=12x12	prec=f32	mode=plan	arm=lib	tag=run	ns_min=156.45	reps=9	burst=239	sink=-2.659197e+02

with an optional series= field under --series. Only cell/prec/ns_min/mode are
parsed; the remaining keys are envelope (arm, tag, reps, burst, sink, series)
and pass through unchecked. mode must be 'plan' -- leaf rows belong to the
driver's --candidate path, which the arm's runs never invoke. Spellings are
normalized here (12^2, 12x12, 12² all read 12x12; f32/float/s read f32) so a
driver-side spelling change cannot fork the results TSV.

The printed set is the driver's STATIC kAdmitted repertoire -- the 19
(cell, prec) pairs in CANON_CELLS (WI-1b grew it from the wave-3 nine:
the N in {9..15} squares joined {12,16,24}, f64 everywhere except 16x16;
W4 then cut the 9x9/11x11 f32 squares back out -- both read OFF past the
2x floor on the genoa class probe and the pre-registered no-conjunct rule
makes a single-class OFF a global revert of the bit, wi1b-admissions.md
W4 section; cubes unchanged) -- emitted unconditionally on every arch: the
ADM_GRANULE_ADMIT knob and the granule_*_admit_v predicates gate which
route and speed each plan takes, never whether the row prints (at a
sub-dialect ISA such as x86-64-v2 the driver still prints all 19 rows and
the ON/OFF arms coincide). Wave-2's bogus '0/9 cells' verdict was this file's
parser expecting a bare 3-column TSV that no shipped driver ever prints --
the znver2/icelake-server/znver4 failed raws each carried all nine
(wave-3-era) rows -- not a class-dependent admitted set; there is no
per-arch admission variance in the printed repertoire. A 9-cell raw probed
at a pre-WI-1b ref now FAILS here as stale-universe, naming the 10 missing
cells (self-test 'stale-universe'), and a wave-4-era 21-cell raw fails the
other way, naming the reverted cell as unexpected (self-test
'wave4-superset').

    canon_rows.py <class> <round> <rep> <arm> <raw-file> <results.tsv>
    canon_rows.py --self-test    # synthetic fixtures; no cluster needed

Exits 1 with GRANULE_AB_FAIL on any drift: an 'ab' row that does not parse,
duplicate cell, unknown (cell, prec), a missing expected cell, or a
non-positive timing. A probe that measures the wrong thing must die loudly,
never record less.
"""
import os
import re
import subprocess
import sys
import tempfile

# The registration the driver must print in full: the 19 (cell, prec) pairs
# of the driver's static kAdmitted table at 0350855 (WI-1b less the
# W4-reverted 9x9/11x11 f32 squares), arch-independent by construction (see
# module docstring). A row outside this set is driver drift and fails the
# job, never a silent skip; so is a missing member, which is also what fails
# a pre-WI-1b (9-cell) raw as stale-universe.
_CANON_SQUARES_F32 = (10, 12, 13, 14, 15, 16, 24)  # 16 f32-only; 9/11 f32 reverted at W4
_CANON_SQUARES_F64 = (9, 10, 11, 12, 13, 14, 15, 24)      # no 16x16 f64: pinned OFF
CANON_CELLS = frozenset(
    [(f"{n}x{n}", "f32") for n in _CANON_SQUARES_F32]
    + [(f"{n}x{n}", "f64") for n in _CANON_SQUARES_F64]
    + [(c, p) for c in ("4x4x4", "8x8x8") for p in ("f32", "f64")])

# The wave-3 (pre-WI-1b) universe, kept for the stale-universe negative
# control in --self-test; do not use elsewhere.
WAVE3_CELLS = frozenset({
    ("12x12", "f32"), ("12x12", "f64"),
    ("16x16", "f32"),
    ("24x24", "f32"), ("24x24", "f64"),
    ("4x4x4", "f32"), ("4x4x4", "f64"),
    ("8x8x8", "f32"), ("8x8x8", "f64"),
})

_PREC = {"f32": "f32", "float": "f32", "s": "f32", "single": "f32",
         "f64": "f64", "double": "f64", "d": "f64"}


class CanonError(Exception):
    pass


def canon_cell(tok):
    """'12x12'/'12^2'/'12²' -> 2-D; '4x4x4' -> 3-D; anything else raises."""
    m = re.fullmatch(r"(\d+)\s*[xX×]\s*(\d+)\s*[xX×]\s*(\d+)", tok.strip())
    if m:
        return f"{int(m.group(1))}x{int(m.group(2))}x{int(m.group(3))}"
    m = re.fullmatch(r"(\d+)\s*[xX×]\s*(\d+)", tok.strip())
    if m:
        return f"{int(m.group(1))}x{int(m.group(2))}"
    m = re.fullmatch(r"(\d+)\s*(?:\^\s*2|²)", tok.strip())
    if m:
        return f"{int(m.group(1))}x{int(m.group(1))}"
    raise CanonError(f"unparseable cell token {tok!r}")


def canon_prec(tok):
    p = _PREC.get(tok.strip().lower())
    if p is None:
        raise CanonError(f"unparseable precision token {tok!r}")
    return p


def parse_invocation(text):
    """Parse one driver stdout dump -> {(cell, prec): ns}. Raises CanonError.

    A driver row begins with the literal marker 'ab' and carries key=value
    fields (bench_granule_ab.cpp print_row; yafft scripts/validate.sh's awk
    consumer splits the same grammar). Any line not starting with 'ab' is
    invocation-environment noise (banners) and ignored; an 'ab' line that
    does not parse, or parses to drift, raises.
    """
    out = {}
    for ln, line in enumerate(text.splitlines(), 1):
        f = line.split("\t") if "\t" in line else line.split()
        if not f or f[0] != "ab":
            continue  # banner/header/noise: not a driver row
        kv = {}
        for tok in f[1:]:
            k, eq, v = tok.partition("=")
            if not eq or not k:
                raise CanonError(f"line {ln}: malformed ab-row field {tok!r}"
                                 " (expected key=value)")
            kv[k] = v
        if kv.get("mode") != "plan":
            raise CanonError(f"line {ln}: ab row mode={kv.get('mode', '<absent>')!r},"
                             " expected 'plan' (leaf rows are the driver's --candidate"
                             " path, out of this arm's contract)")
        absent = [k for k in ("cell", "prec", "ns_min") if k not in kv]
        if absent:
            raise CanonError(f"line {ln}: ab row missing fields {absent}")
        cell = canon_cell(kv["cell"])
        prec = canon_prec(kv["prec"])
        try:
            ns = float(kv["ns_min"])
        except ValueError:
            raise CanonError(f"line {ln}: unparseable ns_min {kv['ns_min']!r}")
        if ns <= 0:
            raise CanonError(f"line {ln}: non-positive timing {ns}")
        if (cell, prec) not in CANON_CELLS:
            raise CanonError(f"line {ln}: unexpected cell {cell}/{prec}"
                             f" (not one of {sorted(CANON_CELLS)})")
        if (cell, prec) in out:
            raise CanonError(f"line {ln}: duplicate cell {cell}/{prec}")
        out[(cell, prec)] = ns
    return out


def main(argv):
    cls, round_, rep, arm, raw, tsv = argv[1:7]
    if arm not in ("on", "off"):
        raise CanonError(f"arm must be on|off, got {arm!r}")
    with open(raw) as fh:
        rows = parse_invocation(fh.read())
    missing = sorted(CANON_CELLS - rows.keys())
    if missing:
        raise CanonError(f"driver printed {len(rows)}/{len(CANON_CELLS)} cells;"
                         f" missing {missing}")
    with open(tsv, "a") as fh:
        for (cell, prec) in sorted(rows):
            fh.write(f"{cls}\t{cell}\t{prec}\t{round_}\t{rep}\t{arm}\t"
                     f"{rows[(cell, prec)]:.9g}\n")


def _synth_raw(cells, ns=100.00):
    """Rows in the driver's real print_row grammar (driver-faithful fixture)."""
    return "".join(
        f"ab\tcell={c}\tprec={p}\tmode=plan\tarm=lib\ttag=run\tns_min={ns:.2f}"
        f"\treps=9\tburst=100\tsink=-1.0e+02\n"
        for c, p in cells)


def self_test():
    """Every fixture runs the full CLI, not parse_invocation alone: wave-2
    shipped because the cube addendum's re-run exercised the reducer's
    --self-test over TSV rows and nothing ever fed canon_rows a driver-shaped
    raw. The pass cases are shaped like real driver stdout; each fail case
    must name its reason via GRANULE_AB_FAIL."""
    tmp = tempfile.mkdtemp(prefix="canon_rows_selftest_")

    def run(text):
        raw = os.path.join(tmp, "raw.txt")
        tsv = os.path.join(tmp, "rows.tsv")
        open(raw, "w").write(text)
        if os.path.exists(tsv):
            os.unlink(tsv)
        cli = subprocess.run([sys.executable, os.path.abspath(__file__),
                              "test", "1", "1", "on", raw, tsv],
                             capture_output=True, text=True)
        return cli, tsv

    full = _synth_raw(sorted(CANON_CELLS))
    for name, text in {
            "happy": full,
            "series-field": full.replace("sink=", "series=1.0,2.0,3.0\tsink=")}.items():
        cli, tsv = run(text)
        got = open(tsv).read().count("\n") if os.path.exists(tsv) else 0
        if cli.returncode != 0 or got != len(CANON_CELLS):
            print(f"SELFTEST_FAIL: {name}: exit {cli.returncode}, {got} tsv rows"
                  f" (want 0 and {len(CANON_CELLS)}); stderr {cli.stderr!r}",
                  file=sys.stderr)
            return 1
        print(f"selftest {name}: exit 0, {got} tsv rows from the driver's grammar"
              " (as required)")

    dropped = sorted(CANON_CELLS)[3]
    cli, _ = run(_synth_raw(sorted(CANON_CELLS - {dropped})))
    if cli.returncode != 1 or str(dropped) not in cli.stderr:
        print(f"SELFTEST_FAIL: drop-one-cell: exit {cli.returncode} (want 1), stderr"
              f" {cli.stderr!r} (want only {dropped} named)", file=sys.stderr)
        return 1
    print(f"selftest drop-one-cell: exit 1 naming only {dropped} (as required)")

    # Stale-universe negative control: a wave-3-era (9-cell) raw is no longer
    # canonicalizable -- it must die naming exactly the cells WI-1b added and
    # W4 kept, so a probe aimed at a pre-WI-1b ref cannot silently record less.
    cli, _ = run(_synth_raw(sorted(WAVE3_CELLS)))
    added = sorted(CANON_CELLS - WAVE3_CELLS)
    unnamed = [c for c in added if str(c) not in cli.stderr]
    if (cli.returncode != 1 or f"{len(WAVE3_CELLS)}/{len(CANON_CELLS)}" not in cli.stderr
            or unnamed):
        print(f"SELFTEST_FAIL: stale-universe: exit {cli.returncode} (want 1),"
              f" stderr {cli.stderr!r} (want '{len(WAVE3_CELLS)}/{len(CANON_CELLS)}'"
              f" and all {len(added)} added cells named; unnamed: {unnamed})",
              file=sys.stderr)
        return 1
    print(f"selftest stale-universe: 9-cell raw exits 1 naming all"
          f" {len(added)} WI-1b-added cells (as required)")

    fail_cases = {
        # The pre-fix fictional contract: a driver grammar change must fail loudly.
        "3-column-tsv": "".join(f"{c}\t{p}\t100.00\n" for c, p in sorted(CANON_CELLS)),
        "duplicate": full + _synth_raw([sorted(CANON_CELLS)[0]]),
        # 16x16 f64 sits inside the N grid but is pinned OFF in the engine:
        # a present-but-unadmitted cell is driver drift, not a canonical row.
        "unexpected-cell": full + _synth_raw([("16x16", "f64")]),
        # Wave-4 superset: a 21-cell raw still carrying a W4-reverted cell is
        # stale the other way and must die naming it as unexpected.
        "wave4-superset": full + _synth_raw([("9x9", "f32")]),
        "non-positive-ns": _synth_raw(sorted(CANON_CELLS), ns=0.00),
        "malformed-field": full.replace("\tmode=plan", "\tmodeplan", 1),
        "leaf-mode-drift": full.replace("mode=plan", "mode=leaf-rows", 1),
        "missing-ns_min": full.replace("\tns_min=100.00", "", 1),
    }
    for name, text in fail_cases.items():
        cli, _ = run(text)
        if cli.returncode != 1 or "GRANULE_AB_FAIL" not in cli.stderr:
            print(f"SELFTEST_FAIL: {name}: exit {cli.returncode} (want 1),"
                  f" stderr {cli.stderr!r}", file=sys.stderr)
            return 1
        print(f"selftest {name}: exit 1 with GRANULE_AB_FAIL (as required)")
    return 0


if __name__ == "__main__":
    if sys.argv[1:2] == ["--self-test"]:
        sys.exit(self_test())
    if len(sys.argv) != 7:
        sys.exit("usage: canon_rows.py <class> <round> <rep> <arm> <raw> <tsv>"
                 " | --self-test")
    try:
        main(sys.argv)
    except (CanonError, OSError) as e:
        print(f"GRANULE_AB_FAIL: {e}", file=sys.stderr)
        sys.exit(1)
