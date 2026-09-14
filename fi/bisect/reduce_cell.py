#!/usr/bin/env python3
# fi/bisect/reduce_cell.py — facts-only reducer for fi/bisect/probe_cell.sbatch TSVs.
#
#   fi/bisect/reduce_cell.py <results.tsv>
#
# Prints one BISECT_CELL line per cell:
#   BISECT_CELL,<cell>,anchor_n=<n>,probe_n=<n>,
#   anchor_med_us=<..>,probe_med_us=<..>,ratio_med=<probe/anchor>,
#   anchor_min_us=<..>,probe_min_us=<..>,ratio_min=<..>,
#   anchor_range=<lo>..<hi>,probe_range=<lo>..<hi>
# Exit 1 (nothing classified) if any arm of any cell carries fewer than 12 rows: an
# incomplete probe must fail loudly, never read as a class.
#
# Verdicts live in fi/bisect/README.md's decision rule, not here: a probe/anchor
# ratio_med <=0.90 at (2,1024) is FAST-class, >=0.95 is SLOW/anchor class, between is
# gray (resubmit once). This script only prints the numbers the rule reads.
import statistics
import sys

fail = lambda msg: (print(f"REDUCE_FAIL: {msg}", file=sys.stderr), sys.exit(1))

rows = []
try:
    lines = open(sys.argv[1]).read().splitlines()
except (OSError, IndexError):
    fail(f"cannot read results.tsv: {sys.argv[1:] if len(sys.argv) > 1 else 'no path given'}")
for i, ln in enumerate(lines):
    if i == 0:
        ln == "cell\trep\tarm\tus" or fail(f"unexpected header: {ln!r}")
        continue
    parts = ln.split("\t")
    len(parts) == 4 or fail(f"row {i}: want 4 columns, got {len(parts)}: {ln!r}")
    try:
        rows.append((parts[0], int(parts[1]), parts[2], float(parts[3])))
    except ValueError:
        fail(f"row {i}: unparseable rep/us: {ln!r}")
rows or fail("empty TSV (header only)")

cells = []
for c, *_ in rows:
    if c not in cells:
        cells.append(c)

for c in cells:
    per_arm = {}
    for arm in ("anchor", "probe"):
        vals = [r[3] for r in rows if r[0] == c and r[2] == arm]
        len(vals) >= 12 or fail(f"cell {c} arm {arm}: {len(vals)} rows < 12 (probe incomplete)")
        per_arm[arm] = vals
    a, p = per_arm["anchor"], per_arm["probe"]
    ma, mp = statistics.median(a), statistics.median(p)
    mna, mnp = min(a), min(p)
    print(
        f"BISECT_CELL,{c},anchor_n={len(a)},probe_n={len(p)},"
        f"anchor_med_us={ma:.3f},probe_med_us={mp:.3f},ratio_med={mp / ma:.4f},"
        f"anchor_min_us={mna:.3f},probe_min_us={mnp:.3f},ratio_min={mnp / mna:.4f},"
        f"anchor_range={min(a):.3f}..{max(a):.3f},probe_range={min(p):.3f}..{max(p):.3f}"
    )
