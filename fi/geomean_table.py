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
