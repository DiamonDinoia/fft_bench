#!/usr/bin/env python3
"""Reduce the WI-2c large-1-D route-line probe TSVs into per-class crossover
tables and verdicts against the shipped four_step_large admission lines.

Reads:
  <RESULTS_DIR>/wi2c-<class>-<sha7>.serial.tsv   (N=2^18..2^25 x {f32,f64} x {dif,four_step} + auto)
  <RESULTS_DIR>/wi2c-<class>-<sha7>.thread.tsv   (nt x prec x {dif,four_step}, 128 KiB..32 MiB)
  <RESULTS_DIR>/wi2c-<class>-<sha7>.tlb.tsv      (top-2 rungs x huge={0,1}; informational)
  <RESULTS_DIR>/wi2c-<class>-<sha7>.env.md       (L3_BYTES for the stream-arm multiple)

Prints, per class: the RAW per-cell min_ns tables, then the DERIVED serial
f64 lower edge, serial f32 lower edge, serial f32 window UPPER edge, the
threaded crossover per nthreads (budget reading at nt in {1,4,32} called out),
the stream-arm onset against the host's L3, and the auto-election agreement.
Every derived line ends in a verdict column: within-noise-kill or
move-needed, against the SHIPPED constants below (a COPY of
include/admiral/detail/four_step_large.hpp:421-437,449-450 and the :38
comment bracket at master f493eb2; keep in sync — the probe never reads
the headers itself).

Noise rule: per (prec,n,route) the repetitions' min_ns spread ((max-min)/min)
over the rotated rounds; the leg's noise floor is the median spread. A cell is
a TIE when |four_step/dif - 1| <= 2*floor. An edge interval is [bytes of the
last rung on the losing side (tie rungs inside the interval), bytes of the
first rung on the winning side]; shipped-inside-interval => within-noise-kill.
A tie-only leg has floor=0 and decides nothing — flagged, not smoothed over.

Usage: fi/probe/reduce_large_route.py [RESULTS_DIR]   (default ./results next
to this script). Exit 0 with data or nothing; 2 on malformed TSV rows (a row
that parses neither as data nor header is contract drift and is loud).
"""

import glob
import os
import re
import statistics
import sys

# --- shipped constants (COPY of four_step_large.hpp:421-437,449-450 at master ---
# --- f493eb2; keep in sync) ---
MIB = 1 << 20
KIB = 1 << 10
SHIP_SERIAL_F64 = 12 * MIB            # kLargeRouteSerialF64Bytes (probe-ladder prior)
SHIP_SERIAL_F32 = 16 * MIB - 1        # kLargeRouteSerialF32Bytes (probe-ladder prior)
# The serial f32 window cap (kLargeRouteSerialF32MaxBytes) is DELETED at master:
# four_step won at every rung past it on every class through 256 MiB.
SHIP_THREAD_FLOOR_F64 = 370727        # kLargeRouteThreadFloorF64Bytes
SHIP_THREAD_FLOOR_F32 = 185363        # kLargeRouteThreadFloorF32Bytes
SHIP_THREAD_KNEE_F64 = 32             # kLargeRouteThreadKneeF64Nt
SHIP_THREAD_KNEE_F32 = 8              # kLargeRouteThreadKneeF32Nt
SHIP_THREAD_CAP = 1482910             # kLargeRouteThreadCapBytes (shared)
# Pool width P per class (fi/<class>.sbatch node width): the threaded law's
# interpolation anchor. Unknown class -> 0 -> the law's 2*knee span guard.
POOL_OF = {"rome": 128, "icelake": 64, "genoa": 96}
STREAM_MULT = 2.0                     # kFourStepStreamL3Mult (:38)
# :38 comment: the SPR crossover bracket was 1.36x..2.71x of L3, 2 = geo-mid.
STREAM_BRACKET = (1.36, 2.71)
NT_CALLOUT = (1, 4, 32)

COLS = ("prec", "n", "bytes", "nthreads", "route_forced", "route_elected",
        "stream_arm_elected", "reps", "min_ns", "guard")


def ship_thread(prec, nt, pool_width):
    # large_route_threaded_bytes(elem_bytes, nthreads, pool_width) at master:
    # f32 nt=2 pins the cap; an element-keyed floor holds flat to the knee,
    # then a linear rise to the shared cap anchored at the pool width.
    if prec == "f32" and nt == 2:
        return SHIP_THREAD_CAP
    knee = SHIP_THREAD_KNEE_F64 if prec == "f64" else SHIP_THREAD_KNEE_F32
    floor = SHIP_THREAD_FLOOR_F64 if prec == "f64" else SHIP_THREAD_FLOOR_F32
    if nt <= knee:
        return floor
    span = max(pool_width, 2 * knee) - knee
    return min(floor + (SHIP_THREAD_CAP - floor) * (nt - knee) // span,
               SHIP_THREAD_CAP)


def mib(b):
    if b is None:
        return "NA"
    if b % MIB == 0:
        return "%d MiB" % (b // MIB)
    if b % KIB == 0:
        return "%d KiB" % (b // KIB)
    return "%.3f MiB" % (b / MIB)


def read_tsv(path):
    """Return (rows, problems). rows carry dicts keyed by COLS."""
    rows, problems = [], []
    for i, ln in enumerate(open(path)):
        ln = ln.rstrip("\n")
        if not ln:
            continue
        f = ln.split("\t")
        if f[0] in ("f32", "f64"):
            if len(f) < 10:
                problems.append("%s:%d: %d fields (<10)" % (path, i + 1, len(f)))
                continue
            try:
                rows.append({
                    "prec": f[0], "n": int(f[1]), "bytes": int(f[2]),
                    "nthreads": int(f[3]), "route_forced": f[4],
                    "route_elected": f[5], "stream_arm_elected": f[6],
                    "reps": int(f[7]), "min_ns": float(f[8]), "guard": f[9],
                })
            except ValueError as e:
                problems.append("%s:%d: %s" % (path, i + 1, e))
        elif f[0] == "prec":      # header (any spelling) — skipped
            continue
        else:
            problems.append("%s:%d: contract drift: %r" % (path, i + 1, ln[:80]))
    return rows, problems


def spreads(rows):
    """{(prec,nt,n,route):(rel_spread,nrows)} over repeated same-arm rows.

    nthreads is part of the key: the threaded leg reuses the same n rungs at
    every nt, and pooling across nt would mix noise regimes.
    """
    by = {}
    for r in rows:
        if r["route_forced"] in ("dif", "four_step"):
            by.setdefault((r["prec"], r["nthreads"], r["n"], r["route_forced"]),
                          []).append(r["min_ns"])
    out = {}
    for k, v in by.items():
        if len(v) >= 2 and min(v) > 0:
            out[k] = (max(v) - min(v)) / min(v), len(v)
    return out


def floor_of(sp):
    return statistics.median([s for s, _ in sp.values()]) if sp else 0.0


def tmin(rows, prec, n, route):
    v = [r["min_ns"] for r in rows
         if r["prec"] == prec and r["n"] == n and r["route_forced"] == route]
    return min(v) if v else None


def decide_cells(rows, prec, band):
    """Sorted [(n,bytes,dif,fs,verdict)] for one precision of a leg."""
    ns = sorted({r["n"] for r in rows if r["prec"] == prec})
    cells = []
    for n in ns:
        d, f = tmin(rows, prec, n, "dif"), tmin(rows, prec, n, "four_step")
        if d is None or f is None:
            continue
        b = next((r["bytes"] for r in rows if r["prec"] == prec and r["n"] == n), None)
        if not b:
            b = n * (16 if prec == "f64" else 8)
        ratio = f / d
        v = "tie" if abs(ratio - 1.0) <= band else ("four_step" if ratio < 1.0 else "dif")
        cells.append((n, b, d, f, v))
    return cells


def lower_edge(cells):
    """[lo,hi] bytes of the dif->four_step transition (ties kept inside)."""
    first_f = next((i for i, c in enumerate(cells) if c[4] == "four_step"), None)
    if first_f is None:
        return cells[-1][1], None            # dif wins to the ladder top
    lo = cells[first_f - 1][1] if first_f > 0 else 0
    return lo, cells[first_f][1]


def upper_edge(cells):
    """[lo,hi] bytes of the last four_step->dif transition, or None."""
    last_f, first_d = None, None
    seen_f = False
    for c in cells:
        if c[4] == "four_step":
            seen_f = True
            last_f = c[1]
            first_d = None
        elif c[4] == "dif" and seen_f and first_d is None:
            first_d = c[1]
    if first_d is None:
        return None
    return last_f, first_d


def verdict(edge, shipped):
    """within-noise-kill if the shipped line is inside the measured interval."""
    lo, hi = edge
    lo = 0 if lo is None else lo
    if hi is None:
        inside = shipped > lo
        sug = None
    else:
        inside = lo <= shipped <= hi
        sug = int((max(lo, 1) * hi) ** 0.5)
    line = "shipped %s vs measured [%s, %s]" % (mib(shipped), mib(lo), mib(hi))
    if inside:
        return "within-noise-kill  [%s]" % line
    if sug:
        return "move-needed  [%s]  suggested ~%s (geo-mid)" % (line, mib(sug))
    return "move-needed  [%s]  (edge above the ladder top)" % line


def env_l3(env_path):
    try:
        for ln in open(env_path):
            if ln.startswith("L3_BYTES,"):
                return int(ln.split(",")[1])
    except (OSError, ValueError, IndexError):
        pass
    return None


def reduce_class(stem, label):
    print("=" * 78)
    print("== %s (%s)" % (label, os.path.basename(stem)))
    print("=" * 78)
    mc = re.match(r"(?:.*/)?wi2c-([a-z0-9]+)-", stem)
    pool_width = POOL_OF.get(mc.group(1), 0) if mc else 0
    paths = {leg: stem + "." + leg + ".tsv" for leg in ("serial", "thread", "tlb")}
    env = stem + ".env.md"
    for leg, p in paths.items():
        if not os.path.exists(p):
            print("  %-6s MISSING (%s)" % (leg, p))
    problems = []
    data = {}
    for leg, p in paths.items():
        if os.path.exists(p):
            rows, prob = read_tsv(p)
            problems.extend(prob)
            data[leg] = rows
    if problems:
        for m in problems:
            print("  MALFORMED: %s" % m)
        return 2

    l3 = env_l3(env) if os.path.exists(env) else None
    print("  L3: %s (from env.md)" % (mib(l3) if l3 else "unknown"))

    # ------------------------------------------------------------ serial
    if "serial" in data:
        rows = data["serial"]
        sp = spreads(rows)
        fl = floor_of(sp)
        band = 2 * fl
        print("\n  SERIAL raw (min over min_ns of reps; dif rows: %d, four_step rows: %d)"
              % (sum(1 for r in rows if r["route_forced"] == "dif"),
                 sum(1 for r in rows if r["route_forced"] == "four_step")))
        print("  noise floor: median same-arm spread %.4f (%d repeated cells)"
              % (fl, len(sp)))
        edges = {}
        for prec in ("f64", "f32"):
            cells = decide_cells(rows, prec, band)
            print("\n  prec=%s" % prec)
            print("  %10s %10s %14s %14s %8s %s" % ("n", "bytes", "dif_min_ns",
                  "four_step_min_ns", "fs/dif", "decide"))
            for n, b, d, f, v in cells:
                print("  %10d %10s %14.3f %14.3f %8.4f %s" % (n, mib(b), d, f, f / d, v))
            edges[prec] = cells
        print("\n  SERIAL derived vs shipped:")
        c64, c32 = edges.get("f64", []), edges.get("f32", [])
        if c64:
            print("    f64 lower edge [%s, %s]  %s"
                  % (mib(lower_edge(c64)[0]), mib(lower_edge(c64)[1]),
                     verdict(lower_edge(c64), SHIP_SERIAL_F64)))
        if c32:
            print("    f32 lower edge [%s, %s]  %s"
                  % (mib(lower_edge(c32)[0]), mib(lower_edge(c32)[1]),
                     verdict(lower_edge(c32), SHIP_SERIAL_F32)))
            up = upper_edge(c32)
            if up is None:
                still = "four_step still wins at the ladder top (%s)" % mib(c32[-1][1])
                print("    f32 window UPPER edge: none below the top — %s" % still)
                print("      (the serial f32 window cap is deleted at master: an"
                      " open window is the law's own reading)")
            else:
                print("    f32 window UPPER edge [%s, %s] — master ships NO cap;"
                      " a closed window here is a note for the next probe-ladder"
                      " re-fit, not a move-needed" % (mib(up[0]), mib(up[1])))
        # stream-arm onset (the kFourStepStreamL3Mult re-derivation)
        for prec in ("f64", "f32"):
            srows = [r for r in rows if r["prec"] == prec
                     and r["route_forced"] == "four_step"]
            truthy = [r for r in srows
                      if r["stream_arm_elected"].lower() in ("1", "true", "yes")]
            if truthy:
                onset = min(r["bytes"] for r in truthy)
                if l3:
                    ratio = onset / l3
                    v = ("within-noise-kill" if STREAM_BRACKET[0] <= ratio <= STREAM_BRACKET[1]
                         else "move-needed")
                    print("    stream arm (%s): onset %s = %.2fx L3; shipped mult 2"
                          " (SPR bracket %.2f..%.2f)  %s"
                          % (prec, mib(onset), ratio, STREAM_BRACKET[0], STREAM_BRACKET[1], v))
                else:
                    print("    stream arm (%s): onset %s; L3 unknown, mult n/a"
                          % (prec, mib(onset)))
            elif srows:
                print("    stream arm (%s): never elected on the serial ladder"
                      " (onset > %s)" % (prec, mib(max(r["bytes"] for r in srows))))
            else:
                print("    stream arm (%s): n/a" % prec)
        # auto elections vs measured argmin
        mism = []
        for prec in ("f64", "f32"):
            for r in rows:
                if r["route_forced"] != "auto" or r["prec"] != prec:
                    continue
                d = tmin(rows, prec, r["n"], "dif")
                f = tmin(rows, prec, r["n"], "four_step")
                if d is None or f is None:
                    continue
                argmin = "four_step" if f < d else "dif"
                el = r["route_elected"]
                if argmin not in el:
                    mism.append((prec, r["n"], el, argmin))
        if mism:
            print("    auto elections WRONG side at: %s"
                  % ", ".join("%s n=%d elects %s (measured %s)" % m for m in mism))
        else:
            print("    auto elections: elected == measured winner at every serial rung")

    # ------------------------------------------------------------ threaded
    if "thread" in data:
        rows = data["thread"]
        nts = sorted({r["nthreads"] for r in rows})
        print("\n  THREADED raw-by-crossover:")
        print("  per-(nt,prec): bytes interval of the dif->four_step crossover;")
        print("  shipped = master's floor/knee/cap law at pool_width=%d"
              " (floor f64 %s f32 %s, knee f64 %d f32 %d, cap %s;"
              " f32 nt=2 pins the cap)"
              % (pool_width, mib(SHIP_THREAD_FLOOR_F64), mib(SHIP_THREAD_FLOOR_F32),
                 SHIP_THREAD_KNEE_F64, SHIP_THREAD_KNEE_F32, mib(SHIP_THREAD_CAP)))
        print("  the tie band is PER-NT (2x that nt's median same-arm spread).")
        for nt in nts:
            sub = [r for r in rows if r["nthreads"] == nt]
            sp = spreads(sub)
            fl = floor_of(sp)
            band = 2 * fl
            for prec in ("f64", "f32"):
                cells = decide_cells(sub, prec, band)
                if not cells:
                    continue
                e = lower_edge(cells)
                lo, hi = e
                lo = 0 if lo is None else lo
                mark = " <== nt in %s" % (list(NT_CALLOUT),) if nt in NT_CALLOUT else ""
                sug = ""
                if hi:
                    gm = int((max(lo, 1) * hi) ** 0.5)
                    sug = "  budget~%s (geo-mid %s x nt)" % (mib(gm * nt), mib(gm))
                print("    nt=%-3d %s edge [%s, %s] shipped %s  %s%s%s  (floor %.4f, %d cells)"
                      % (nt, prec, mib(lo), mib(hi),
                         mib(ship_thread(prec, nt, pool_width)),
                         verdict((lo, hi), ship_thread(prec, nt, pool_width)),
                         sug, mark, fl, len(cells)))
                for n, b, d, f, v in cells:
                    print("        %10s dif=%14.3f four_step=%14.3f fs/dif=%.4f %s"
                          % (mib(b), d, f, f / d, v))

    # ------------------------------------------------------------ TLB arm
    if "tlb" in data:
        rows = data["tlb"]
        print("\n  TLB/huge arm (informational; per-event rows in"
              " *.tlb_counters.csv, requested/accepted in *.tlb.events.txt):")
        # huge is not a contract column; pairing uses the sbatch's append
        # order, which is huge=0 immediately followed by huge=1 for each cell.
        keys = []
        for r in rows:
            k = (r["prec"], r["n"], r["route_forced"])
            if k not in keys:
                keys.append(k)
        for prec, n, route in keys:
            sub = [r for r in rows if (r["prec"], r["n"], r["route_forced"])
                   == (prec, n, route)]
            if len(sub) == 2:
                h0, h1 = sub
                print("    %s n=%d %-9s huge0=%.3f huge1=%.3f ratio=%.4f"
                      % (prec, n, route, h0["min_ns"], h1["min_ns"],
                         h1["min_ns"] / h0["min_ns"]))
            else:
                print("    %s n=%d %-9s %d rows (expected the huge 0/1 pair;"
                      " partial leg?)" % (prec, n, route, len(sub)))
        print("    guard values seen: %s" % ", ".join(sorted({r["guard"] for r in rows})))

    print("")
    return 0


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    results = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "results")
    stems = {}
    for leg in ("serial", "thread", "tlb"):
        for p in glob.glob(os.path.join(results, "wi2c-*." + leg + ".tsv")):
            stems[p[: -len("." + leg + ".tsv")]] = True
    if not stems:
        print("no wi2c-*.tsv under %s (nothing submitted yet, or wrong RESULTS_DIR)"
              % results)
        return 0
    rc = 0
    for stem in sorted(stems):
        m = re.match(r"(.*)/wi2c-([a-z0-9]+)-([0-9a-f]{7})$", stem)
        label = "class %s @ %s" % (m.group(2), m.group(3)) if m else stem
        rc = max(rc, reduce_class(stem, label))
    print("verdict legend: within-noise-kill = shipped line inside the measured"
          " crossover interval => close WI-2c storing these values (receipt"
          " rule a); move-needed => line + test pins + receipt ship in ONE"
          " commit (rule b); cross-class disagreement => host-keyed law via"
          " cpu_cache(), never a worst-case global (rule c).")
    return rc


if __name__ == "__main__":
    sys.exit(main())
