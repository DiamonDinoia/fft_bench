#!/usr/bin/env python3
"""Geomean of admiral / competitor per (arch, library), and the per-cell delta against a
baseline directory. The charts show shape; this shows whether a change moved the standings.

  fi/geomean_table.py                     table for the jsons in fi/
  fi/geomean_table.py <baseline-dir>      the same, plus new/old per cell and the geomean of it
"""
import json
import math
import re
import sys
from pathlib import Path

ARCHES = ['rome', 'icelake', 'genoa']
LIBS = ['mkl', 'fftw3', 'ducc', 'sleef', 'pocket', 'kiss']


def cells(path):
    """{(rank, n_per_dim): real_time} for one benchmark json, or {} if absent."""
    try:
        runs = json.loads(Path(path).read_text())['benchmarks']
    except (FileNotFoundError, json.JSONDecodeError, KeyError):
        return {}
    out = {}
    for b in runs:
        if b.get('run_type') == 'aggregate':
            continue
        n, rank = eval(re.findall(r'<(.*?)>', b['name'])[0])
        out[(rank, n)] = b['real_time']
    return out


def geomean(xs):
    return math.exp(sum(map(math.log, xs)) / len(xs)) if xs else float('nan')


def table(d, suffix):
    rows = {}
    for arch in ARCHES:
        adm = cells(f'{d}/admiral{suffix}-{arch}.json')
        rows[arch] = {}
        for lib in LIBS:
            other = cells(f'{d}/{lib}{suffix}-{arch}.json')
            shared = sorted(set(adm) & set(other))
            if shared:
                rows[arch][lib] = (geomean([adm[c] / other[c] for c in shared]), len(shared))
    return rows


def emit(title, rows):
    print(f'\n{title}  (geomean admiral/lib, >1 = admiral slower; n cells in parens)')
    print(f'{"arch":9}' + ''.join(f'{l:>16}' for l in LIBS))
    for arch in ARCHES:
        line = f'{arch:9}'
        for lib in LIBS:
            g, n = rows[arch].get(lib, (float("nan"), 0))
            line += f'{g:>11.3f} ({n:2d})' if n else f'{"-":>16}'
        print(line)


fi = Path(__file__).resolve().parent
for suffix, label in (('', 'ST'), ('-omp', 'MT')):
    emit(f'{label} standings', table(fi, suffix))

# Same-binary floor: admiral2 is THE sweep binary re-run back-to-back in the same job
# (the same-binary control pattern of fi/nd: after2 arm + nd_reduce.py --ctl column).
# Per-cell admiral2/admiral, reduced to geomean + worst cell; kept for the mover verdicts
# below.
floors = {}
print('\nsame-binary floor (admiral2/admiral re-run; expected ~1.0)')
for arch in ARCHES:
    a, b = cells(f'{fi}/admiral-{arch}.json'), cells(f'{fi}/admiral2-{arch}.json')
    shared = sorted(set(a) & set(b))
    if not shared:
        print(f'  {arch:9} - (no admiral2-{arch}.json)')
        continue
    r = {c: b[c] / a[c] for c in shared}
    floors[arch] = r
    worst = max(shared, key=lambda c: abs(r[c] - 1))
    print(f'  {arch:9} geomean {geomean(r.values()):.4f} over {len(shared)} cells; '
          f'worst {worst} {r[worst]:.3f}')

if len(sys.argv) > 1:
    base = sys.argv[1]
    print(f'\nper-cell new/old against {base} (admiral ST, <1 = faster now)')
    for arch in ARCHES:
        new, old = cells(f'{fi}/admiral-{arch}.json'), cells(f'{base}/admiral-{arch}.json')
        shared = sorted(set(new) & set(old))
        if not shared:
            print(f'  {arch}: no overlap')
            continue
        r = [new[c] / old[c] for c in shared]
        worst = max(zip(r, shared))
        best = min(zip(r, shared))
        print(f'  {arch:9} geomean {geomean(r):.3f} over {len(r)} cells; '
              f'best {best[1]} {best[0]:.3f}; worst {worst[1]} {worst[0]:.3f}')
        fl = floors.get(arch, {})
        movers = [c for c in shared if abs(new[c] / old[c] - 1) > 0.05]
        if fl and movers:
            print('    movers (|new/old - 1| > 5%), with the same-binary floor:')
            print('      cell           new/old  floor  verdict')
            for c in sorted(movers, key=lambda c: -abs(new[c] / old[c] - 1)):
                f = fl.get(c)
                if f is None:
                    verdict = 'no floor'
                else:
                    verdict = ('MOVE' if abs(new[c] / old[c] - 1) > abs(f - 1) + 0.02
                               else 'wobble')
                print(f'      {str(c):14} {new[c] / old[c]:.3f}   '
                      f'{f if f is not None else float("nan"):.3f}   {verdict}')
