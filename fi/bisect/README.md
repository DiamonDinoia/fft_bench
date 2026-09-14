# fi/bisect — WI-1c runbook: rome (2,1024) f64 regression bisect (e61ae17..a799b6b)

The cell `run_fft<1 << 10, 2>` f64 (2-D 1024x1024 C2C, serial, out-of-place) on rome
moved admiral 8322.8 -> 9927.0 us (+19.3%) between the 2026-09-11 baseline sweep
(admiral e61ae17) and the 2026-09-14 era sweep (admiral 683a697), while fftw3 stayed
flat (9769.0 -> 9652.5, x0.988) and the same cell IMPROVED on icelake (x0.770) and
genoa (x0.935). Three consecutive rome sweeps read the cell at 1.159 / 1.105 / 1.193
vs baseline (a799b6b / 7739611 / 683a697) — a rome-specific admiral-code regression,
not wobble. The bracket is **e61ae17 (FAST) .. a799b6b (SLOW)**, 38 linear commits,
zero merges (`git rev-list --merges` = 0). The era anchor binary (683a697) IS SLOW-class
at this cell, so every probe measures against it and classifies by relative time.

This directory:

| file | role |
|---|---|
| `bisect_sha.sh` | login-side: fetch + checkout one admiral sha, build `build-bisect-<class>-<sha7>/`, print (or `--submit`) the ONE probe job |
| `probe_cell.sbatch` | exclusive-node pinned 12-rep ABAB probe: era anchor vs bisect binary, cells (2,1024)+(2,512)+(2,2048) f64, TSV + BISECT_DONE marker |
| `reduce_cell.py` | facts-only reducer of the probe TSV (BISECT_CELL lines; fails on <12 rows per arm) |
| `next_sha.sh` | git's own midpoint pick over `<bad> ^<good>`; prints BOUNDARY_PAIR when the close is reached |

## Queue discipline (binding)

ONE probe job in flight at any time. Each probe loop iteration is exactly:
`SHA=<sha> fi/bisect/bisect_sha.sh --submit` = 1 build (login-side, nice/ionice,
JOBS-capped) + 1 sbatch = 1 queued job, compatible with the team cap of 3. Submit the
next probe only after the current run dir carries `BISECT_DONE`.

## Ordered submission plan

Probe order: boundary pair first (P0 confirms the FAST end under this protocol; the SLOW
end is the era anchor itself, already measured there at 9927.0 us), then git-bisect
midpoints. Expected total: 2 (boundary-ish) + ceil(log2(38)) = 8 probes worst case.

| step | sha | why |
|---|---|---|
| P0 | `e61ae17` | positive control + FAST-class calibrator; falsification gate (see rule 0) |
| P1 | `36e8170` | initial `git rev-list --bisect a799b6b ^e61ae17` pick (midpoint of 38) |
| Pn | per result | `fi/bisect/next_sha.sh <new-good> <new-bad>` prints the next sha |
| close | — | `next_sha.sh` prints BOUNDARY_PAIR when parent(FAST)/child(SLOW) are adjacent |

Exact commands the manager runs per probe (each bullet = one queued job):

```
SHA=e61ae17 fi/bisect/bisect_sha.sh            # build + print the sbatch line (no submit)
SHA=e61ae17 fi/bisect/bisect_sha.sh --submit   # build (idempotent) + submit probe P0
# ... wait for /mnt/home/mbarbone/fft_bench_runs/bisect-wi1c-rome/e61ae17/BISECT_DONE
fi/bisect/next_sha.sh e61ae17 a799b6b          # -> 36e8170
SHA=36e8170 fi/bisect/bisect_sha.sh --submit   # probe P1
# ... wait for BISECT_DONE, classify, then e.g.
fi/bisect/next_sha.sh <new-good> <new-bad>     # and iterate
```

Classification of a probe = read `results.tsv` (or the BISECT_CELL lines in the job
log's reduce output / `$RUN_DIR/<sha7>/probe.log`) and apply the decision rule below.

## Decision rule

Rule 0 (falsification gate, applies to P0 only). If the e61ae17 probe reads
`ratio_med >= 0.95` at (2,1024), then under a FIXED harness and pinned protocol there is
no admiral-code regression: the sweep delta is harness-drift (the 2026-09-11 baseline
json predates fft_bench `63d7b17`'s 64 B buffer alignment) and/or node-draw. STOP the
bisect and record the wobble verdict — the analogue of the genoa 2^19 probe6 stay-fixed
outcome. Expectation from the sweep numbers is ratio_med ~0.84 (8322.8/9927.0).

Rule 1 (classify). Per probe, at (2,1024): `ratio_med <= 0.90` → FAST-class (the new
good); `ratio_med >= 0.95` → SLOW-class (the new bad). Between 0.90 and 0.95 → gray:
resubmit the same probe once (optionally `REPS_1024=600` doubles sampling); if still
gray, treat as SLOW for the purpose of narrowing and prefer the FAST-side neighbor on
the next pick. The flanks (2,512),(2,2048) are context for cell-selectivity, not
classification inputs (the true e61-era flanks read ~0.93/0.97 vs the era binary — a
culprit that hits all three cells drags the flanks to ~0.84 too, which is itself
informative about mechanism).

Rule 2 (boundary-pair close). When `next_sha.sh <good> <bad>` prints BOUNDARY_PAIR, the
child (bad end) contains the culprit. Then:

- If the culprit is a deliberate route/model decision (cost-model constant, route
  admission gate, four_step_large-line-style tuning), close as **kill-as-fix**: record
  the culprit + mechanism in this receipt family (memory/admiral/beat-standings/) and
  open the re-derivation as an admiral-side follow-up lane. Do not revert blind.
- If the culprit touches a yafft constants header (`include/admiral/detail/*.hpp`
  constants: `kLargeRoute*`, `kE2Len64MinL3PerCoreBytes`, gate tables), the admiral-side
  fix commit carries a `receipt:` trailer pointing at the bisect receipt. Mandatory.
- If the culprit is codegen-only (piece_* wrap-lane member, scratch/alloc change),
  report it with the per-probe md5 evidence and, for wrap-lane members, an
  `nm --defined-only -S` symbol-size diff of the col/dif instantiation objects against
  the FAST parent — the admiral tree's own verification idiom.

Rule 3 (persistence). The bracket's bad end is a799b6b but the anchor is 683a697; both
are SLOW-class by sweep (1.159 vs 1.193 vs baseline; 7739611 between them 1.105). A
culprit found in e61ae17..a799b6b is therefore still effective at 683a697 — confirmed by
construction, no extra probe. Do NOT "verify the fix" by re-running the sweep alone:
the sweep's full-node draws wobble this cell by a documented 1.1-1.2 band; only a pinned
probe (this sbatch with SHA=<fixed>) settles it.

## Why the harness is fixed and e61ae17 is re-probed

The baseline json (fi/baseline-2026-09-11-e61ae17) was captured BEFORE fft_bench
`63d7b17` ("allocate every arm's buffers at 64 B"), so sweep-vs-baseline crosses both
admiral history and a harness allocator change (documented in
~/env-control-e61/README.md for the genoa 2^19 bisect). Every bisect binary builds from
THIS checkout's harness (src/, include/, CMakeLists.txt identical to the c9ae666 era
builds — empty diff), with only extern/admiral replaced. The e61ae17 probe (P0)
therefore measures the FAST end on the same harness as the anchor. The era anchor
binaries are byte-stable: `md5sum -c $ANCHORS/era-2026-09-14-c9ae666/MD5SUMS` runs at
the top of every probe (rome/admiral_cell a579b3d4..., rome/admiral_bench 46f7f08a...).

## Build parity and notes

- Module set mirrored verbatim from fi/submit_all.sh:
  `module load gcc/14.3.0 fftw/3.3.11 intel-oneapi-mkl/2026.0.0 cmake/3.31.11 ninja/1.13.2`
  (on top of `modules/2.5-beta1`), so bisect binaries are toolchain-parity with the
  sweep binaries. The probe job itself loads the runtime set from fi/anchor/probe.sbatch:
  `module load modules/2.5-beta1 gcc/14.3.0 fftw/3.3.11 intel-oneapi-mkl/2026.0.0`.
- Per-sha build trees keep provenance (`.admiral_sha`, `BISECT_META` with md5s). A
  build dir refuses reuse under a different sha; `rm -rf build-bisect-rome-<sha7>` by
  hand to redo one. After the close, prune the whole `build-bisect-*` set.
- The git-archive mtime gotcha from the genoa 2^19 bisect (stale ninja objects on
  archive-stamped trees) does not apply here: checkout is by `git checkout --detach`
  (changed files get fresh mtimes) and each sha gets a FRESH build dir, so there is no
  incremental state to lie about.
- admiral_cell's argv: `<dim> <n> <nthreads> <reps> [rounds]`; here `2 $n 1 $reps 3`.
  Its plan call is the sweep's own: `plan<double>({n,n}, {nthreads=1, effort::measure})`,
  out-of-place, one process per measurement, min-over-rounds.
- probe_cell.sbatch runs the regression cell FIRST within each rep, so a mid-job node
  death still leaves the deciding measurement in the TSV (and reduce_cell.py's >=12
  rows-per-arm guard fails loudly rather than classify a truncated probe).

## Full candidate range (38 commits, oldest = FAST side)

Position numbers from `fi/bisect/next_sha.sh --list` (git rev-list order). The "role"
column is reading aid only — it does not reorder probes; git's midpoint rule does.

| # | sha | subject | role |
|---|---|---|---|
| 1 | 0c6a57c | fix: elect the route at the width auto resolves to | bench pins nthreads=1; n219 receipt exonerated this shape there |
| 2 | eef1f2a | test: pin that effort::measure reaches the auto-thread route election | test-only |
| 3 | b5aa45c | test: pin the col_codelet length bound against a measured crossover | test-only |
| 4 | e611fb3 | perf: stream the out-of-place four-step transpose past 2x L3 | stream-store threshold vs 16 MiB working set |
| 5 | 45a5622 | fix: fence stream stores with sfence, which gcc's tsan accepts | pair of the above |
| 6 | 7fe0214 | ci: count skipped arms in validate.sh and give ctest a timeout | ci-only |
| 7 | 4597353 | build: one shared engine behind a version script for the tests | build/linkage |
| 8 | c274cc2 | fix: build the shared engine on ELF only | build/linkage |
| 9 | b068c00 | perf: move the serial f64 four_step_large line to 6 MiB | n219 culprit, but len-1024 axes sit far under the line; 7739611 already restored it while the cell stayed SLOW |
| 10 | 7c4a17b | perf: hold the N-D axis run count in the plan | N-D plan path |
| 11 | 6cc3790 | test: benchmark the fixed per-execute cost | test-only |
| 12 | 22ff5dc | perf: race the large route serially past the cost model | large-route election |
| 13 | 5b10e04 | perf: give the engine scratch a stable address through snmalloc | scratch/alloc |
| 14 | ca9b1aa | ci: give every job a timeout and every ctest an explicit one | ci-only |
| 15 | 67951cf | ci: bound each valgrind binary so a deadlock fails instead of hanging | ci-only |
| 16 | 9cd23a3 | test: cover the large route at 2^25 | test-only |
| 17 | 7bb1c89 | perf: gate the snmalloc scratch at glibc's 32 MiB mmap ceiling | scratch/alloc |
| 18 | 09cb3d2 | perf: block the four-step fused sweep into panels | four-step sweep |
| 19 | 36e8170 | fix: scope kSnmallocMinBytes to the branch that uses it | initial midpoint (P1) |
| 20 | fbcb4bd | fix: thread --effort= through the overhead harness | yafft-internal harness |
| 21 | 21fc174 | perf: serve narrow column blocks with a sized batch | col path |
| 22 | 225e5a3 | perf: admit length-3 col axes to the col codelet | len-3 only |
| 23 | 23d3efa | fix: price the E2 col-batch cap per physical core, not per logical cpu | no-op on SMT-off rome |
| 24 | a596885 | docs: record that no sanitizer sits under the alignment barrier | docs-only |
| 25 | 58d35e7 | perf: serve the batched codelet's line remainder with a sized-batch ladder | batched line path |
| 26 | b157584 | perf: dispatch admitted rank-2 in-place plans straight to the two axis bodies | rank-2 dispatch (bench is out-of-place) |
| 27 | 96bdb09 | perf: drop the flat-leaf scratch copy from kernel_batched's unit-stride arm | batched line path |
| 28 | 64c0082 | merge: S1b alignment-stabilization arm (ADM_ALIGN_STAB, default off) | default-off arm |
| 29 | 2bf61b4 | merge: S3 colDif geometry arm (ADM_COLDIF_GEO, default off) + memo + rome probe | default-off arm |
| 30 | da21e6d | merge: make alignment-canonical allocation unconditional (S1b fold-on) | alloc semantics |
| 31 | 01197f0 | feat: piece_fms + wrap recipe (fma-family coverage) | wrap lane |
| 32 | 0182dbf | fix: keep piece_* raw for scalar arities wider than double | wrap lane |
| 33 | 76a80b7 | perf: piece_* wrap — butterfly.hpp | wrap lane (butterfly codegen) |
| 34 | 200539d | perf: piece_* wrap — dif_passes.hpp | wrap lane (DIF passes: the len-1024 engine) |
| 35 | a3f2598 | perf: piece_* wrap — four_step.hpp | wrap lane |
| 36 | c5620f2 | perf: piece_* wrap — vecpass.hpp | wrap lane (vec passes) |
| 37 | aad0bcb | perf: piece_* wrap — real_fft.hpp | wrap lane |
| 38 | a799b6b | fix: keep the stage-twiddle general arm raw | SLOW bracket end |

## Evidence the bracket rests on

- memory/admiral/bench-results/2026-09-13-cluster-standings/README.md — a799b6b sweep,
  "worst (2, 1024) 1.159" vs fi/baseline-2026-09-11-e61ae17, first flag.
- memory/admiral/bench-results/2026-09-14-cluster-standings-granule/README.md — 683a697
  sweep: "(2,1024) vs baseline is now 1.193 (was 1.105 on 7739611, 1.159 on a799b6b)";
  rome-scale geomean flat (1.0036), so not a node-wide drift.
- Direct json read: (2,1024) f64 rome admiral 8322.8 -> 9927.0 us, fftw3 9769.0 ->
  9652.5 us (x0.988), adm/fftw3 0.852 -> 1.028; icelake admiral x0.770, genoa x0.935.
  Sources: memory/admiral/beat-standings/era-2026-09-14-c9ae666/admiral-rome.json etc.
  vs fft_bench/fi/baseline-2026-09-11-e61ae17/.
- yafft 7739611 commit body: "the rome 2-D 1024 cell (~1.2x, unbisected)" — this lane
  closes it.
- Protocol precedent: memory/admiral/2026-09-14-bisect-n219-genoa-b068c00.md
  (boundary-pair close, interleaved anchors, arm-spread controls), ~/bisect-regression/.
