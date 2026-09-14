# SUBMIT.md — anchored standings sweep, user runbook

One command builds, one command submits. Each class runs a chain:

    sweep (fi/<class>.sbatch)
      -> afterok anchor-probe (fi/anchor/probe.sbatch): era anchor vs this binary,
         exclusive node, pinned physical core, 12 alternating reps over the wobble
         cells (1-D 2^18/2^19/2^20) and the granule cells (2-D 12x12, 24x24)
      -> afterok collect (fi/anchor/collect.sbatch): class jsons + probe evidence +
         sacct rows land in the logbook run dir and get a local git commit

Prerequisites already satisfied (both on GPFS, both MD5SUMS-verified):

- era jsons: `/mnt/home/mbarbone/repos/memory/admiral/beat-standings/era-2026-09-14-c9ae666/`
- anchor binaries: `/mnt/home/mbarbone/fft_bench_anchors/era-2026-09-14-c9ae666/`

## In submission order

```
# 1. build + preflight (prints the full chain plan, submits NOTHING)
cd /mnt/home/mbarbone/repos/fft_bench
fi/submit_all.sh --check

# 2. submit all three chains (9 jobs) against the current tip
fi/submit_all.sh

# 3. watch
squeue -u $USER
```

`ADMIRAL_REF=<sha>` picks the admiral revision (default master of the yafft checkout);
`ERA=<era-id>` overrides the anchor era (default era-2026-09-14-c9ae666).

## Expected durations (measured on the pre-control-arm draw, jobs 7033751-753)

| leg | rome | icelake | genoa |
|---|---|---|---|
| sweep | 00:50:28 | 00:33:51 | 00:18:55 |
| + admiral2 control | +2-4 min | +2-4 min | +2-4 min |
| probe | ~3-8 min | ~3-8 min | ~3-8 min |
| collect | <1 min | <1 min | <1 min |

Provisional `--time=01:30:00` on the sweep sbatches covers the control-arm addition with
margin; re-derive it from the rehearsal's sacct numbers (JOBS.tsv in the run dir) before
the next run.

## Queue-3 / run-2 cadence

Submit all three chains at once. The QOS cpu cap (256) covers any TWO sweep jobs
(128+64, 128+96, 64+96), never all three: the third pends — 7033753 pended 33:55 on the
2026-09-14 draw — and its probe/collect legs fire automatically whenever it lands.
Nothing needs babysitting; a failed leg cancels only its own branch
(DependencyNeverSatisfied for its children in `squeue` output).

## Granule transfer probe wave (per-class ON/OFF admission A/B, WI-0a-ii)

Decides, per node class, whether the AoS-granule leaf admissions beat the
compile-time-OFF build (`ADM_GRANULE_ADMIT`) beyond the in-job control floor.
One parameterized job per class builds yafft ON+OFF at the pinned sha on the
node itself (offline: `git archive` + the GPFS CPM cache), then runs 12 rounds
of pinned A/B with same-arm repeats as the spread floor.

```
cd /mnt/home/mbarbone/repos/fft_bench
# 1. preflight (prints the full per-class plan, submits NOTHING)
fi/probe/submit_probes.sh --check

# 2. submit the three class jobs
fi/probe/submit_probes.sh

# 3. watch
squeue -u $USER        # third job pends on the 256-cpu QOS, as the sweep does

# 4. after all three land (GRANULE_AB_DONE in $RESULTS_DIR/<class>.slurm.<id>.log)
fi/probe/reduce_transfer.py
```

`ADM_REF=<sha|branch>` picks the yafft revision (default `team/integration` tip,
resolved to a full sha and stamped into every output name). `RESULTS_DIR=<dir>`
overrides the destination (default `fi/probe/results/`); rows land as
`<class>-<date>-<sha7>.{tsv,env.md,raw.txt}`.

Expected durations: builds dominate. Two static yafft builds at full-node `-j`
plus 48 driver invocations — conservative 30-45 min per class job under the
provisional `--time=01:30:00` (tiny_ab carried the same limit for two on-node
builds at only `-j16`).

Ordering vs the standings rehearsal wave: the probes need nothing the rehearsal
produces, but every job shares the 256-cpu QOS and the class node pools. Submit
the probe wave AFTER the rehearsal sweeps drain (a class's probe queues behind
that class's sweeps otherwise and both lengthen); probes and the tiny
anchor collect legs may overlap freely.

Verdict rule (wired into the reducer): per (class, cell) the admission ADMITs
iff `off_min/on_min - 1 > 2x` the in-job same-arm control floor; a zero floor
reports `DEGENERATE`, loudly. znver2 24x24-f32 carries an adverse prior (16 ymm
registers); an `OFF (adverse prior)` there is an expected-possible outcome —
record it, do not rescue it. An existing same-day same-sha TSV stem fails the
job loudly; delete the stale stem to force a re-run.

## When everything is done (login-side)

```
fi/submit_all.sh --plots                                            # charts from fi/*.json
fi/geomean_table.py <run-dir>                                       # standings + per-cell deltas
fi/geomean_table.py fi/baseline-2026-09-11-e61ae17                  # vs the old baseline
```

The run receipt (jsons, probe tables, JOBS.tsv) is at the path printed at submission:
`/mnt/home/mbarbone/repos/memory/admiral/beat-standings/runs/<slug>/`, one commit per
class already made on the worker. Push the logbook repo, commit+push the charts in
fft_bench, and read the probe's PROBE_CELL lines before believing any per-cell mover:
|sweep/anchor| inside 1.00 +/- its own spread at the wobble cells means era-class.
