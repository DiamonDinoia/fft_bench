#!/usr/bin/env python3
"""Canonicalize one bench_granule_ab invocation's stdout into transfer-probe rows.

fi/probe/granule_transfer.sbatch runs the driver 48 times per class
(12 rounds x 2 arms x 2 same-arm repeats) and feeds each invocation's stdout
through this canonicalizer. fi/probe/reduce_transfer.py imports the same cell
table, so the cell universe exists in exactly one place.

Driver contract (yafft benchmark/bench_granule_ab.cpp): TSV of min-of-R rows
(cell, prec, ns_min) over {12x12,24x24}x{f32,f64} + {16x16,f32}. Spellings are
normalized here (12^2, 12x12, 12² all read 12x12; f32/float/s read f32) so a
driver-side spelling change cannot fork the results TSV.

    canon_rows.py <class> <round> <rep> <arm> <raw-file> <results.tsv>

Exits 1 with GRANULE_AB_FAIL on any drift: unparseable row, duplicate cell,
unknown (cell, prec), a missing expected cell, or a non-positive timing. A
probe that measures the wrong thing must die loudly, never record less.
"""
import re
import sys

# The admission set under test: exactly these five (cell, prec) pairs. A row
# outside this set is driver drift and fails the job, never a silent skip.
CANON_CELLS = frozenset({
    ("12x12", "f32"), ("12x12", "f64"),
    ("16x16", "f32"),
    ("24x24", "f32"), ("24x24", "f64"),
})

_PREC = {"f32": "f32", "float": "f32", "s": "f32", "single": "f32",
         "f64": "f64", "double": "f64", "d": "f64"}


class CanonError(Exception):
    pass


def canon_cell(tok):
    """'12x12', '12X12', '12^2', '12²' -> '12x12'; anything else raises."""
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

    Only lines of exactly three fields with a numeric third field are rows;
    anything else (headers, banners) is ignored. A numeric row whose cell or
    precision does not canonicalize is drift, and so is a canonical pair
    outside CANON_CELLS; both raise.
    """
    out = {}
    for ln, line in enumerate(text.splitlines(), 1):
        f = line.split("\t") if "\t" in line else line.split()
        if len(f) != 3:
            continue
        try:
            ns = float(f[2])
        except ValueError:
            continue  # header line ('cell prec ns_min') or banner
        cell = canon_cell(f[0])
        prec = canon_prec(f[1])
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


if __name__ == "__main__":
    if len(sys.argv) != 7:
        sys.exit("usage: canon_rows.py <class> <round> <rep> <arm> <raw> <tsv>")
    try:
        main(sys.argv)
    except (CanonError, OSError) as e:
        print(f"GRANULE_AB_FAIL: {e}", file=sys.stderr)
        sys.exit(1)
