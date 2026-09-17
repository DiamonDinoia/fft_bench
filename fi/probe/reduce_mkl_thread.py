#!/usr/bin/env python3
"""Reduce fftm-thr logs to one verdict per (class, layer, cell, knob).

Each probe row is (dim, n, knob, threads, limit, us, vs_1T). The thread axis collapses to
its best ratio, so a knob that drives MKL's internal path shows a ratio well above 1 at
some thread count and a knob that does not stays at 1. THRESHOLD is the ratio a cell must
reach to count as threaded; 1.5 is far outside the run-to-run spread of a min-of-7 cell
and far below the ratio a real threaded arm reaches.

  fi/probe/reduce_mkl_thread.py results/*-mkl-thread-*.log
  fi/probe/reduce_mkl_thread.py --self-test
"""

import re
import sys
from collections import defaultdict

THRESHOLD = 1.5

ROW = re.compile(r'^\s*(\d+)\s+(\d+)\s+(\S+)\s+(\d+)\s+(-?\d+)\s+([\d.]+)\s+([\d.]+)\s*$')
LAYER = re.compile(r'MKL_THREADING_LAYER=(\w+)')
CLASS = re.compile(r'=== fftm-thr, class (\w+)')


def parse(text: str):
    """(cls, layer, cell, knob, threads, limit, us, ratio) for every probe row in one log."""
    cls, layer = 'unknown', 'unknown'
    for line in text.splitlines():
        if m := CLASS.search(line):
            cls = m.group(1)
        elif m := LAYER.search(line):
            layer = m.group(1)
        elif m := ROW.match(line):
            dim, n, knob, threads, limit, us, ratio = m.groups()
            yield (cls, layer, f'{dim}d-{n}', knob, int(threads), int(limit),
                   float(us), float(ratio))


def report(rows) -> int:
    """Print the best ratio per (class, layer, cell, knob). Return 1 if no row threads at
    all, which means the probe saw nothing and no verdict about a knob is supported."""
    best = defaultdict(lambda: (0.0, 0, 0.0))
    for cls, layer, cell, knob, threads, _limit, us, ratio in rows:
        if ratio > best[(cls, layer, cell, knob)][0]:
            best[(cls, layer, cell, knob)] = (ratio, threads, us)

    if not best:
        print('no probe rows parsed')
        return 1

    threaded = 0
    for cls, layer, cell, knob in sorted(best):
        ratio, threads, us = best[(cls, layer, cell, knob)]
        mark = 'THREADS' if ratio >= THRESHOLD else '.'
        threaded += ratio >= THRESHOLD
        print(f'{cls:8s} {layer:6s} {cell:10s} {knob:13s} best {ratio:7.2f}x '
              f'at {threads:4d}T  {us:11.2f} us  {mark}')
    print(f'# {threaded} of {len(best)} (class, layer, cell, knob) arms reach '
          f'{THRESHOLD}x; threshold {THRESHOLD}')
    if not threaded:
        print('# NO arm threads: the probe cannot see threading here, so no knob verdict holds')
        return 1
    return 0


SELF_TEST_NONE = """=== fftm-thr, class rome ===
--- MKL_THREADING_LAYER=GNU
  dim        n           knob  threads     limit           us     vs_1T
    1     8192          unset        1         1        15.46      1.00
    1     8192          unset      128       128        47.05      0.33
"""

SELF_TEST_SOME = SELF_TEST_NONE + """--- MKL_THREADING_LAYER=INTEL
    1     8192   THREAD_LIMIT      128       128         0.86     17.98
"""


def self_test() -> int:
    """The reducer must stay silent on a table where nothing threads and fire on one where
    a single arm does. A checker that cannot fail proves nothing, so both directions run."""
    quiet = report(list(parse(SELF_TEST_NONE)))
    print('--- self-test: table with no threaded arm ->', 'no verdict (correct)' if quiet
          else 'VERDICT CLAIMED (wrong)')
    loud = report(list(parse(SELF_TEST_SOME)))
    print('--- self-test: table with one 17.98x arm ->', 'verdict (correct)' if not loud
          else 'NO VERDICT (wrong)')
    ok = quiet == 1 and loud == 0
    print('SELF_TEST', 'PASS: the reducer separates a threaded arm from a serial one'
          if ok else 'FAIL')
    return 0 if ok else 1


if __name__ == '__main__':
    if sys.argv[1:2] == ['--self-test']:
        sys.exit(self_test())
    if not sys.argv[1:]:
        sys.exit('usage: reduce_mkl_thread.py <log> [<log> ...] | --self-test')
    rows = [r for path in sys.argv[1:] for r in parse(open(path).read())]
    sys.exit(report(rows))
