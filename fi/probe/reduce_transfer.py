#!/usr/bin/env python3
"""Reduce the granule transfer probe TSVs to the per-class admission table.

    fi/probe/reduce_transfer.py                 # newest TSV per class under fi/probe/results
    fi/probe/reduce_transfer.py <tsv> [<tsv>..] # explicit files
    fi/probe/reduce_transfer.py --self-test     # synthetic ADMIT/OFF/DEGENERATE + malformed

Row schema (fi/probe/granule_transfer.sbatch + canon_rows.py):
    class  cell  prec  round  rep  arm  ns
12 rounds x 2 arms x 2 same-arm repeats = 24 rows per arm per (class, cell, prec),
912 rows per class TSV at the 19-cell universe (WI-1b less the 9x9/11x11 f32
squares, globally reverted at W4 per the no-conjunct rule). The two same-arm
repeats of each (round, arm) turn are the in-job control floor: their
relative deviations never leave the job, so no cross-node calibration is
involved. A banked 9-cell (pre-WI-1b) TSV fails the coverage check below as
stale-universe; that failure is the guard working. A banked 21-cell (wave-4)
TSV fails instead on the reverted cells as unexpected; the self-test pins both.

Verdict per (class, cell, prec):
    floor = max over (round, arm) pairs of (hi/lo - 1)
    gain  = off_min/on_min - 1            (positive: admission is faster)
    floor == 0            -> DEGENERATE (zero control spread; the 2x rule has no
                             floor to test against — rerun, do not re-judge)
    gain > 2 * floor      -> ADMIT
    otherwise             -> OFF
znver2 (rome) 24x24-f32 carries an adverse prior (16 ymm registers, structurally
worse past the N=24 register cliff); an OFF there is expected-possible and is
annotated, not rescued.

Exit codes: 0 clean reduce, 2 malformed input (counts, schema, ranges).
"""
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from canon_rows import CANON_CELLS  # the one copy of the cell universe

CLASSES = ("rome", "icelake", "genoa")
ROUNDS, REPS = 12, 2
EXPECTED_PER_ARM = ROUNDS * REPS
ADVERSE_PRIOR = ("rome", "24x24", "f32")  # 16 ymm registers; OFF acceptable


class ReduceError(Exception):
    pass


def load(path):
    """-> list of (class, cell, prec, round, rep, arm, ns). Raises ReduceError."""
    rows = []
    try:
        lines = open(path).read().splitlines()
    except OSError as e:
        raise ReduceError(f"{path}: {e}")
    if not lines or lines[0].split("\t") != "class cell prec round rep arm ns".split():
        raise ReduceError(f"{path}: bad or missing header"
                          " (expected 'class\\tcell\\tprec\\tround\\trep\\tarm\\tns')")
    for ln, line in enumerate(lines[1:], 2):
        f = line.split("\t")
        if len(f) != 7:
            raise ReduceError(f"{path}:{ln}: {len(f)} fields, expected 7")
        cls, cell, prec, rnd, rep, arm, ns = f
        if cls not in CLASSES and cls != "test":
            raise ReduceError(f"{path}:{ln}: unknown class {cls!r}")
        if (cell, prec) not in CANON_CELLS:
            raise ReduceError(f"{path}:{ln}: unexpected cell {cell}/{prec}")
        if arm not in ("on", "off"):
            raise ReduceError(f"{path}:{ln}: arm must be on|off, got {arm!r}")
        try:
            rnd, rep, ns = int(rnd), int(rep), float(ns)
        except ValueError:
            raise ReduceError(f"{path}:{ln}: non-numeric round/rep/ns")
        if not (1 <= rnd <= ROUNDS and 1 <= rep <= REPS and ns > 0):
            raise ReduceError(f"{path}:{ln}: round/rep/ns out of range")
        rows.append((cls, cell, prec, rnd, rep, arm, ns))
    return rows


def reduce_rows(rows):
    """-> {(class, cell, prec): verdict dict}. Raises ReduceError on gaps."""
    groups = {}
    for r in rows:
        groups.setdefault((r[0], r[1], r[2]), []).append(r)
    out = {}
    for key, g in sorted(groups.items()):
        cls, cell, prec = key
        per = {}
        for arm in ("on", "off"):
            a = [r for r in g if r[5] == arm]
            if len(a) != EXPECTED_PER_ARM:
                raise ReduceError(f"{cls} {cell} {prec} {arm}: {len(a)} rows,"
                                  f" expected {EXPECTED_PER_ARM} (12 rounds x 2 reps)")
            per[arm] = a
        devs = []
        for arm in ("on", "off"):
            for rnd in range(1, ROUNDS + 1):
                pair = [r[6] for r in per[arm] if r[3] == rnd]
                if len(pair) != REPS:
                    raise ReduceError(f"{cls} {cell} {prec} {arm} round {rnd}:"
                                      f" {len(pair)} reps, expected {REPS}")
                lo, hi = min(pair), max(pair)
                devs.append(hi / lo - 1.0)
        floor = max(devs)
        on_min = min(r[6] for r in per["on"])
        off_min = min(r[6] for r in per["off"])
        gain = off_min / on_min - 1.0
        if floor == 0:
            verdict = "DEGENERATE"
        elif gain > 2 * floor:
            verdict = "ADMIT"
        else:
            verdict = "OFF"
        if key == ADVERSE_PRIOR and verdict == "OFF":
            verdict = "OFF (adverse prior)"  # expected-possible: 16 ymm registers
        out[key] = dict(on_min=on_min, off_min=off_min, gain=gain,
                        floor=floor, verdict=verdict)
    return out


def markdown(red):
    lines = ["| class | cell | prec | on_min_ns | off_min_ns | on/off | gain | floor | verdict |",
             "|---|---|---|---|---|---|---|---|---|"]
    for (cls, cell, prec), d in sorted(red.items()):
        lines.append(f"| {cls} | {cell} | {prec} | {d['on_min']:.9g} | {d['off_min']:.9g}"
                     f" | {d['on_min']/d['off_min']:.4f} | {d['gain']*100:.2f}%"
                     f" | {d['floor']*100:.2f}% | {d['verdict']} |")
    lines.append("| spr (ccmlin075) | 9x9..15x15 less 9x9/11x11 f32 (W4 OFF,"
                 " globally reverted) | f32/f64 | — | — | — | — | — |"
                 " see wi1b-admissions.md (STEP-E squares, W4 section) |")
    lines.append("| spr (ccmlin075) | 12x12/24x24, 16x16 | f32/f64 (16x16 f32 only)"
                 " | — | — | — | — | — | see wi0c-granule-ab.md (squares, lane 2.2) |")
    lines.append("| spr (ccmlin075) | 4x4x4/8x8x8 | f32/f64 | — | — | — | — | — |"
                 " see wi1a-cubes.md (cubes, lane 3.1) |")
    return "\n".join(lines)


def default_inputs():
    rd = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results")
    picked = []
    for cls in CLASSES:
        cand = sorted((os.path.join(rd, f) for f in os.listdir(rd)
                       if f.startswith(cls + "-") and f.endswith(".tsv")),
                      key=os.path.getmtime) if os.path.isdir(rd) else []
        if cand:
            picked.append(cand[-1])
    if not picked:
        raise ReduceError(f"no <class>-*.tsv under {rd}; pass TSV paths explicitly")
    print("# inputs:", *picked, sep="\n#   ", file=sys.stderr)
    return picked


HEADER = "class\tcell\tprec\tround\trep\tarm\tns\n"


def synth(path, cls, gen):
    """gen(cell, prec, rnd, rep, arm) -> ns; writes a full-canonical TSV."""
    with open(path, "w") as fh:
        fh.write(HEADER)
        for cell, prec in sorted(CANON_CELLS):
            for rnd in range(1, ROUNDS + 1):
                for arm in ("on", "off"):
                    for rep in (1, 2):
                        fh.write(f"{cls}\t{cell}\t{prec}\t{rnd}\t{rep}\t{arm}"
                                 f"\t{gen(cell, prec, rnd, rep, arm):.9g}\n")


def self_test():
    tmp = tempfile.mkdtemp(prefix="reduce_transfer_selftest_")
    cases = {
        # clear admission: gain 10.6% vs floor ~1.0% -> ADMIT
        "admit": lambda c, p, r, q, a: 90.0 if a == "on" else (99.5 if q == 1 else 100.5),
        # inside 2x floor: gain 1.5% vs floor ~3.0% -> OFF
        "off": lambda c, p, r, q, a: (98.5 if q == 1 else 101.5) if a == "on" else 100.0,
        # every same-arm pair identical: no floor to test against -> DEGENERATE
        "degenerate": lambda c, p, r, q, a: 90.0 if a == "on" else 100.0,
    }
    want = {"admit": "ADMIT", "off": "OFF", "degenerate": "DEGENERATE"}
    for name, gen in cases.items():
        path = os.path.join(tmp, f"{name}.tsv")
        synth(path, "test", gen)
        got = {k: d["verdict"] for k, d in reduce_rows(load(path)).items()}
        bad = {k: v for k, v in got.items() if v != want[name]}
        if bad:
            print(f"SELFTEST_FAIL: {name}: expected all {want[name]}, got {bad}",
                  file=sys.stderr)
            return 1
        print(f"selftest {name}: {len(got)} cells -> {want[name]} (as required)")
        cli = subprocess.run([sys.executable, os.path.abspath(__file__), path],
                             capture_output=True, text=True)
        if cli.returncode != 0:
            print(f"SELFTEST_FAIL: {name}: CLI exit {cli.returncode}", file=sys.stderr)
            return 1
    # Cardinality pin at the 19-cell WI-1b-less-W4-reverts universe: the happy
    # path must cover exactly 19 cells and keep the W4-surviving 9x9/f64 square
    # (a quietly shrunk or stale-superset CANON_CELLS sails through the cases
    # above; this one counts).
    path = os.path.join(tmp, "universe19.tsv")
    synth(path, "test", cases["admit"])
    got = {k: d["verdict"] for k, d in reduce_rows(load(path)).items()}
    if len(got) != 19 or ("test", "9x9", "f64") not in got:
        print(f"SELFTEST_FAIL: universe-19: {len(got)} cells (want 19 incl."
              " ('test', '9x9', 'f64'))", file=sys.stderr)
        return 1
    print("selftest universe-19: happy path covers exactly the 19-cell"
          " universe incl. the W4-surviving 9x9/f64 square (as required)")

    # Missing-a-kept-cell: a TSV lacking 10x10/f32 rows entirely (a wave-3-shaped
    # probe, or dropped rows) must exit 2 naming the uncovered cell.
    lines = [ln for ln in open(path).read().splitlines()
             if not ln.startswith("test\t10x10\tf32\t")]
    gap = os.path.join(tmp, "missing-kept-cell.tsv")
    open(gap, "w").write("\n".join(lines) + "\n")
    cli = subprocess.run([sys.executable, os.path.abspath(__file__), gap],
                         capture_output=True, text=True)
    if cli.returncode != 2 or "'10x10', 'f32'" not in cli.stderr:
        print(f"SELFTEST_FAIL: missing-kept-cell: exit {cli.returncode} (want 2),"
              f" stderr {cli.stderr!r} (want '10x10', 'f32' named)", file=sys.stderr)
        return 1
    print("selftest missing-kept-cell: exit 2 naming ('test', '10x10', 'f32')"
          " (as required)")

    # Superset-universe control: a wave-4-era (21-cell) TSV still carrying a
    # W4-reverted cell must exit 2 naming it as unexpected, never silently
    # absorb it into the reduce.
    w4 = os.path.join(tmp, "superset21.tsv")
    extra = "".join(f"test\t9x9\tf32\t{r}\t{q}\t{a}\t100.0\n"
                    for r in range(1, ROUNDS + 1)
                    for a in ("on", "off") for q in (1, 2))
    open(w4, "w").write(open(path).read() + extra)
    cli = subprocess.run([sys.executable, os.path.abspath(__file__), w4],
                         capture_output=True, text=True)
    if cli.returncode != 2 or "unexpected cell 9x9/f32" not in cli.stderr:
        print(f"SELFTEST_FAIL: superset-universe: exit {cli.returncode} (want 2),"
              f" stderr {cli.stderr!r} (want 'unexpected cell 9x9/f32' named)",
              file=sys.stderr)
        return 1
    print("selftest superset-universe: 21-cell wave-4 TSV exits 2 naming"
          " 'unexpected cell 9x9/f32' (the W4-reverted cell) (as required)")

    # malformed: a dropped rep must exit 2 with a named gap
    bad = os.path.join(tmp, "malformed.tsv")
    good = os.path.join(tmp, "admit.tsv")
    lines = open(good).read().splitlines()
    open(bad, "w").write("\n".join(lines[:-1]) + "\n")
    cli = subprocess.run([sys.executable, os.path.abspath(__file__), bad],
                         capture_output=True, text=True)
    if cli.returncode != 2 or "rows, expected" not in cli.stderr:
        print(f"SELFTEST_FAIL: malformed input: exit {cli.returncode}"
              f" (want 2), stderr {cli.stderr!r}", file=sys.stderr)
        return 1
    print("selftest malformed: exit 2 with named gap (as required)")
    return 0


def main(argv):
    if argv[1:2] == ["--self-test"]:
        return self_test()
    try:
        paths = argv[1:] or default_inputs()
        red = {}
        for p in paths:
            red.update(reduce_rows(load(p)))
    except ReduceError as e:
        print(f"REDUCE_FAIL: {e}", file=sys.stderr)
        return 2
    covered = {k[0] for k in red}
    missing = [(c, cell, prec) for c in covered for (cell, prec) in CANON_CELLS
               if (c, cell, prec) not in red]
    if missing:
        print(f"REDUCE_FAIL: class with partial coverage; missing {missing}",
              file=sys.stderr)
        return 2
    for c in CLASSES:
        if c not in covered:
            print(f"# note: no rows for class {c} (probe not landed yet?)",
                  file=sys.stderr)
    print(markdown(red))
    print("\nfloor = max same-arm |hi/lo - 1| over the 24 in-job control pairs;"
          " gain = off_min/on_min - 1; ADMIT iff gain > 2x floor.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
