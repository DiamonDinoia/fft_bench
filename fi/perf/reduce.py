#!/usr/bin/env python3
"""Reduce a counter job's log to the two tables the items are accepted against.

    fi/perf/reduce.py rome_item2.log
    fi/perf/reduce.py icelake_item3.log

A counter row is `CTR,<tag>,<reps>,<event>,<value>` and a timing row is `TIME,<tag>,<us>`.
Each cell runs at two rep counts; the per-execute value is the difference over the rep
difference, which removes process startup, plan construction and first-touch page-in. A tag
with only one rep count is reported as raw, never as a per-execute number.
"""
import sys
from collections import defaultdict


def load(path):
    ctr = defaultdict(dict)   # (tag, event) -> {reps: value}
    tim = defaultdict(list)   # base tag -> [us]
    for line in open(path):
        f = line.rstrip("\n").split(",")
        if f[0] == "CTR" and len(f) == 5:
            try:
                ctr[(f[1], f[3])][int(f[2])] = float(f[4])
            except ValueError:
                pass
        elif f[0] == "TIME" and len(f) == 3 and f[2] != "NA":
            tim[f[1].rsplit(":r", 1)[0]].append(float(f[2]))
    return ctr, tim


def main(path):
    ctr, tim = load(path)

    per_exec = {}
    for (tag, ev), by_reps in sorted(ctr.items()):
        if len(by_reps) < 2:
            continue
        lo, hi = min(by_reps), max(by_reps)
        per_exec[(tag, ev)] = (by_reps[hi] - by_reps[lo]) / (hi - lo)

    print("# per-execute counters (differenced)")
    print("tag,event,per_execute")
    for (tag, ev), v in sorted(per_exec.items()):
        print(f"{tag},{ev},{v:.6g}")

    print()
    print("# minimum microseconds per execute, over rounds")
    print("tag,us,rounds")
    best = {t: min(v) for t, v in tim.items()}
    for t, v in sorted(best.items()):
        print(f"{t},{v:.4f},{len(tim[t])}")

    # Ratios between arms that share a cell. The cell is whatever follows the first ':'.
    cells = defaultdict(dict)
    for t, v in best.items():
        arm, _, cell = t.partition(":")
        cells[cell][arm] = v
    print()
    print("# per-cell ratios")
    arms = sorted({a for d in cells.values() for a in d})
    print("cell," + ",".join(arms) + ",")
    for cell, d in sorted(cells.items(), key=lambda kv: kv[0]):
        row = [cell] + [f"{d[a]:.4f}" if a in d else "" for a in arms]
        ref = d.get("mkl") or d.get("fftw3") or d.get("adm_ws")
        cmp_ = d.get("adm") or d.get("adm_serial")
        row.append(f"ratio={cmp_ / ref:.3f}" if ref and cmp_ else "")
        print(",".join(row))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
