# fft_bench N-D cluster diagnosis — admiral @ c4c3911235e8e20636f9be471efd4d9717852c8a (after), 2026-09-06

**FINAL — FROZEN as committed to the fork (fft_bench main @ 5abf85e,
fi/nd/2026-09-07-cluster-diagnosis.md, byte-identical to this file at freeze
time).** The reship tables live in fi/nd/<host>-2026-09-07-reship.md (their own
fork artifacts), not in this file — this diagnosis's "TBD (SP4)" tail is the
pre-reship disposition and stays frozen as committed. The campaign's terminal
receipt is the logbook capstone (memory/admiral/2026-09-07-fftbench-cluster.md).

Team-nddiag campaign (SP1 standings + SP2 per-host diagnosis). Single thread,
complex f64 forward out-of-place, ns/transform, min over 5 interleaved rounds, arm
order rotated, one core pinned; control arm after2 (same binary). Hosts and jobs:
icelake (2x Xeon Platinum 8362, ICL) job 6993673 worker6120; rome (2x EPYC 7742,
Zen2) job 6993682 worker5345; genoa (2x EPYC 9474F, Zen4) job 6993674 worker7233.
Verdict rule: eps = |1 - after2/after|; WIN if adm/best <= 1-eps, LOSS if >= 1+eps,
else TIE. Raw TSVs + binary sha256 per host are in the host sections and
(reproducible) <SCRATCH>/standings/<host>-after.md.

## icelake — WIN 2 / TIE 2 / LOSS 14 (leader mkl everywhere)

| cell | adm/best | eps | verdict | leader |
|---|---|---|---|---|
| 2d_16 | 2.73 | 2.055e-06 | LOSS | mkl |
| 2d_32 | 1.955 | 0.0001252 | LOSS | mkl |
| 2d_64 | 1.55 | 0.01344 | LOSS | mkl |
| 2d_128 | 1.833 | 0.003987 | LOSS | mkl |
| 2d_256 | 1.523 | 0.005148 | LOSS | mkl |
| 2d_512 | 1.266 | 0.001528 | LOSS | mkl |
| 2d_1024 | 1.164 | 0.004202 | LOSS | mkl |
| 2d_2048 | 1.066 | 0.06911 | TIE | mkl |
| 2d_4096 | 0.9213 | 0.0003207 | WIN | mkl |
| 2d_8192 | 1.008 | 0.002146 | LOSS | mkl |
| 3d_4 | 3.91 | 0.0001844 | LOSS | mkl |
| 3d_8 | 2.785 | 1.958e-05 | LOSS | mkl |
| 3d_16 | 2.247 | 0.005611 | LOSS | mkl |
| 3d_32 | 1.487 | 0.005354 | LOSS | mkl |
| 3d_64 | 0.9494 | 0.07022 | TIE | mkl |
| 3d_128 | 1.275 | 0.002191 | LOSS | mkl |
| 3d_256 | 1.115 | 0.001321 | LOSS | mkl |
| 3d_512 | 0.9453 | 0.0004397 | WIN | fftw |

All 14 LOSS cells CLASS: REAL. Classes: row-batched codelet data-movement
(stores 2.4-3.6x, port-5 1.6-1.9x at flop parity); strided col boundary passes
(4K-alias 1.4-2.8x + ~45% stack traffic in dif_col_pass_last<32>); 3d_4 xmm-class
scalar tail vs mkl's 512-bit N=4 kernel; 2d_1024 effort::measure plan-race
bistability (5.487e6 vs 7.11-7.27e6 ns across planning contexts); 2d_8192
transposed-route scalar mover at cycle parity (marginal, deferred).
Diagnosis entry: `2026-09-06-fftbench-diag-icelake.md` (logbook, memory/admiral/).

## rome — WIN 5 / TIE 0 / LOSS 13 (leader fftw x12, ducc x1)

| cell | adm/best | eps | verdict | leader |
|---|---|---|---|---|
| 2d_16 | 1.766 | 6.672e-05 | LOSS | fftw |
| 2d_32 | 1.694 | 0.0003563 | LOSS | fftw |
| 2d_64 | 1.282 | 0.004019 | LOSS | fftw |
| 2d_128 | 1.055 | 0.006543 | LOSS | fftw |
| 2d_256 | 0.9801 | 0.001787 | WIN | fftw |
| 2d_512 | 0.9925 | 0.000473 | WIN | fftw |
| 2d_1024 | 1.185 | 0.004771 | LOSS | ducc |
| 2d_2048 | 0.9119 | 0.0003699 | WIN | fftw |
| 2d_4096 | 0.9719 | 0.0005985 | WIN | fftw |
| 2d_8192 | 1.013 | 0.0009733 | LOSS | fftw |
| 3d_4 | 2.558 | 0.0009984 | LOSS | fftw |
| 3d_8 | 1.6 | 9.196e-05 | LOSS | fftw |
| 3d_16 | 1.218 | 9.4e-05 | LOSS | fftw |
| 3d_32 | 1.211 | 0.01065 | LOSS | fftw |
| 3d_64 | 1.002 | 0.0009357 | LOSS | fftw |
| 3d_128 | 1.205 | 0.005865 | LOSS | fftw |
| 3d_256 | 1.011 | 0.003322 | LOSS | fftw |
| 3d_512 | 0.9684 | 0.01747 | WIN | fftw |

12 REAL + 1 NOISE (3d_256: 11-round interleaved recheck reads 0.9945 min / 0.9893
median under a 3.6% per-round same-binary floor — a read on the floor, no action).
Classes: W=4 FMA-free col DIF chain (fp_mac 0.19x of fftw at 3d_128, the
bit-stability pin's mul/add split) + Zen2-only ls_misal_accesses; tiny row-batched
codelet split gather at W=4; 2d_1024 transposed-route REGRESSION through the
SPR-fitted kAbsGate (col block 10 < 16 at rome's 512 KiB L2, +14.1% before->after);
3d_4 kManyBlocked N=4 exclusion + len-4 col-codelet gate. Plan race refuted here
(15/15 identical routes).
Diagnosis entry: `2026-09-06-fftbench-diag-rome.md` (logbook, memory/admiral/).

## genoa — WIN 8 / TIE 2 / LOSS 8 (leader fftw everywhere)

| cell | adm/best | eps | verdict | leader |
|---|---|---|---|---|
| 2d_16 | 1.842 | 0.0002875 | LOSS | fftw |
| 2d_32 | 1.609 | 0.002325 | LOSS | fftw |
| 2d_64 | 1.078 | 6.234e-05 | LOSS | fftw |
| 2d_128 | 0.9608 | 0.006166 | WIN | fftw |
| 2d_256 | 0.9199 | 0.1387 | TIE | fftw |
| 2d_512 | 1.074 | 0.1489 | TIE | fftw |
| 2d_1024 | 0.8154 | 0.02377 | WIN | fftw |
| 2d_2048 | 0.9669 | 0.008547 | WIN | ducc |
| 2d_4096 | 0.9175 | 0.01638 | WIN | ducc |
| 2d_8192 | 0.9527 | 0.00508 | WIN | ducc |
| 3d_4 | 2.481 | 0.0001398 | LOSS | fftw |
| 3d_8 | 1.779 | 7.759e-05 | LOSS | fftw |
| 3d_16 | 1.162 | 0.004107 | LOSS | fftw |
| 3d_32 | 0.9557 | 0.0004815 | WIN | fftw |
| 3d_64 | 0.8361 | 2.475e-05 | WIN | fftw |
| 3d_128 | 0.9257 | 0.01445 | WIN | fftw |
| 3d_256 | 1.025 | 0.004841 | LOSS | fftw |
| 3d_512 | 1.437 | 0.009575 | LOSS | fftw |

All 8 LOSS cells CLASS: REAL. Zen4 executes 512-bit double-pumped (2x256 uops):
admiral retires 0.36-0.85x fftw's instructions while losing on cycles (IPC
0.64-2.22 vs 2.24-4.66) — throughput/latency classes. Classes: six tiny
row-batch/col-codelet cells (SP3a TINY1/2/3 arms confirmed on-target); 3d_512/3d_256
col tile floor (kColDifMinRowBytes, fitted on SPR geometry) misfiring at genoa's
1 MiB L2 / 32 MiB per-CCD L3 (Bt=128, 1.21x fftw's L2 traffic: 51 vs 42 GB at
3d_512); 3d_256 sits at a plan-lottery margin (fftw bimodal 1.36 max/min;
like-for-like ~7% deficit) — the TIE->LOSS flip is the draw, not a tree regression.
Diagnosis entry: `2026-09-06-fftbench-diag-genoa.md` (logbook, memory/admiral/).

## Fix outcomes (rounds 3/4, SP3)

Shipped onto nd-campaign (ff from 79a2000; origin tip `e26f67104613f99a24a45a99600502de147f42cb`):

- **TINY1 `e9fa2a3`** (admit N=2/4 to the row-batched codelet): 3d_4 wins all
  three hosts — walls ice 0.810 / genoa 0.876 / rome 0.885 against max(eps, 0.02)
  floors, counter-backed (ice 3d_4 cycles 0.792, p5 0.677, fp512 52 -> 104; genoa
  0.820; rome 0.858).
- **TINY2 `e26f671`** (col codelet direction on data): 3d_8 wins genoa 0.799 /
  rome 0.939, ice counter win 0.972c; rome 2d_64 0.979 collateral.
- Ship gates: release ctest 352/352, asan ctest 352/352, cxx17 green; nm
  --defined-only -S vs the 79a2000 reference: 962 movers, all inside the
  pre-registered manifest (N=2/4 codelet bodies + dispatchers, col_codelet_body/
  tail catalog resizes, compiler constant renumbering, codelet-TU constellation
  propagation); zero movers in the 1-D engines, dif/col_dif chains, thread pool,
  or plan machinery.
- Manager adjudication (recorded): TINY1's two literal beyond-floor wall
  excursions (ice 2d_128 1.113, genoa 2d_512 1.234) accepted as era/wall-clock
  instability — the mechanism is nm/binary-proved len-2/4-only, counters refute
  (ice 2d_128 cyc 1.029), and the host standings floors corroborate (genoa 2d_512
  same-binary floor 0.149 at D1).

Rejected, with evidence (arms stay unmerged as receipts):

- **TINY3** (interleaved lanes): refuted on its own target cells — ice 2d_16 wall
  1.138 (cycles 1.168, port-5 +25%, fp512 +53%, instructions +26%), genoa 2d_16
  1.241, 3d_8 loss on all three hosts; its 3d_4 wins are subsumed by TINY1. The
  design thesis "trade port-5 for LSU" is refuted as built: it ADDS shuffles.
  W=4 flat as the SP3a gate exclusion predicted (rome 2d_16/2d_32 0.999).
- **ADMIT** (len-4 col-codelet + len-64 pass-A batch): 3d_4 loses ice 1.475 /
  genoa 1.746; 2d_64 loses rome 1.035 / genoa 1.052. (The interim "ice 2d_64
  1.138" figure was shown by arbitration to be a wave artifact — route-identical
  fixed-rep parity 0.9974 — and is refuted, not a datum.)
- **PLANRACE pin** (`1763a3c`, branch kept as evidence): the icelake 2d_1024
  "plan race" decomposes as a host-era environment class, not a race — chain
  lottery <=8% and context-stable, and the 5.49e6-vs-7.12e6 gap splits by
  measurement context (the gbench-harness 5.5e6 era reproduces on two node-days;
  every fixed-rep driver context reads 7.0-7.5e6; MKL holds 4.71-4.84e6
  everywhere; 2d_4096 unaffected at +0.4%). The deterministic pin takes the
  stale model chain [4,8,32], which the race's [8,8,16] beats by 24% in stream
  — measured net loss (2d_1024 -6.5%, 2d_4096 -11%), so REVERTED. Consequence
  for the reship: compare ABSOLUTE admiral times D1 vs reship at 2d_4096 before
  judging 2d_512/1024/2048 (era-calibration rule), and ice 2d_1024 is
  WONTFIX-with-mechanism at D3.
- **COLFMA** (`49fb59e` on team/r3-colfma): col butterfly twiddles through
  piece_fma/piece_fnma with the -ffp-contract=on/-fno-associative-math pin flags
  untouched; gates 352/352 release+asan incl. the bit-identical strides test,
  cxx17, gcc 13.3 leg; movers confined to inst_col_* (inst_dif byte-identical
  control); v3 census dif_col_pass<double,8> fma 0 -> 14, fp -27%. Phase-2:
  rome A/B PASS — supported wins 2d_128 -2.0% / 3d_128 -1.8% / 3d_32 -1.6%
  (counter-backed: fp_mac 1.26-2.72x more fused with fp volume conserved at
  1.0000, ls_misal flat) and 2d_512 -1.4% (7/7 rounds); 2d_256 -6.1% PRUNED to
  INCONCLUSIVE (single-round min latch; the L2-resident rationale retracted —
  the cell is L3-resident on rome; a counter pair rides the genoa job). Ice
  18-cell probe NON-LOSING (per-round reads; min-stat unusable at ice's
  19-22%-spread cells: 3d_256 7/7 under floor, 3d_128 supported). Zen2
  misaligned-access audit: the col middle chain is clean; the residue is
  pass_last scratch loads at addr%64 in {24,56} from glibc's +16 user-base
  class (the aligned-store peel is the correct trade; the cure is buffered
  staging, round-4 SP3-COLDIF scope). genoa probe landed: 2d_256 settles as a
  real ~2% counter win (unclaimed), 3d_128 FLOOR-classified by the 5-process
  route dig (byte-equal traces over all arms; counters clean vs a 6.4%
  same-binary span). **SHIP: merged as a024ba6** with every gate re-verified at
  the rebased HEAD (4 movers confined inst_col_*, 6/6 inst_dif byte-identical,
  352/352, bit-identical strides cases, cxx17).
- **GATE-ROME** (`team/r3-gaterome` 706834e, ship candidate): bare-2W
  restoration of the col/transposed gate — max(16,2W) was fitted before the
  2048 B col floor existed; with the floor the W=4 crossover sits in (5,10] and
  2W=8 inside it. rome 2d_1024 sweep 0.8609 / production wall 0.8324 /
  differenced cycles 0.8679, landing at 8.3648e6 ns — below the before-era
  8.375e6 (COLFMA stacks). W>=8 folds to a no-op (ice/genoa probes:
  byte-identical binaries, zero-diff routes). Fresh-audit ACCEPT (all numbers
  replicated exactly; S5 positive control fails exactly one case on the old
  form as designed; forms coincide iff 2W >= 16 — v2/NEON wording amended).
  Reship effect: rome 2d_1024 LOSS (ducc-led 1.185) returns to col_dif.
- **COLDIF** (`team/r4-coldif` 4619f03, ship candidate): the col last pass's
  big-radix spill set staged through L1 scratch (the row engine's shipped
  mechanism moved verbatim), geometry-gated at chain len >= 1024. ice 2d_1024
  WIN: wall 0.88 on 7/7 rounds + 8/8 fresh plans cycles 0.9195-0.9299 (loads
  0.7489, stores 0.7686, exact x8). genoa 2d_512's twice-reproduced regression
  (cycles 1.0349 at instructions 0.922 / L1 loads 0.874 — less work, more
  cycles) CURED by the gate, with a structural non-execution proof (zero staged
  kernel symbols below the gate; bit-delta control fires exactly at len 1024).
  rome leg: byte-identical control PASS (W=4 never instantiates the arm). Audit
  ACCEPT incl. the exact four-class mover taxonomy; doc slips D1-D6 recorded,
  none verdict-moving; merge-time musts: claw re-runs + clang asan (the earlier
  asan leg ran gcc 13.3 by silent module non-shadowing) + branch push/CI.
- **GATE-GENOA: SHIP NOTHING** (deciding A/B landed) — the 2048 B col floor
  stands as fitted. Measured fired sets exact on-node (genoa 3 / rome 5 / ice
  3) and the fused-plane finding CONFIRMED: engine fused-axis lines
  arm-identical (3d_256/a1 Bt=80 both arms — the residency test reads plane
  bytes; the floor fires on 3d_256's axis0 only). Removing the floor LOSES
  rome/ice's fired cells (recorded 14%/7%/4.5% rome class, +15%-class ice
  3d_512; raw medians read larger, sign unambiguous, off2 at parity) and drifts
  genoa 0-3.6% non-replicating — no geometry key exists (non-monotone in
  L2/L3/W), so no honest re-derivation formula follows. The genoa 3d_512/3d_256
  residual is COLDIF's lane (its gated ship already reads genoa 3d_512 wall
  0.964 with the floor untouched). Methodology byproduct: cross-job spread
  ±2-4% at 2-4 GiB cells while within-job identity holds ±0.4-1% — reship
  verdicts anchor to an unaffected cell first.
- **GATE-GENOA prep** (no jobs yet; merges after COLFMA): the kColDifMinRowBytes
  fired set re-derived engine-faithfully and validated (26/26 on-host anchor):
  SPR 3 / ice 3 / rome 5 / genoa 3 fired axes — key finding: fused-plane middle
  axes read PLANE bytes, so genoa 3d_256/a1 runs Bt=80 unfloored and only
  a0's floor fires (its A/B is a one-axis move vs 3d_512's both). Measurement
  switch ADM_FLOOR_OFF default-off with byte-identical default build; route pin
  is driver-side effort::estimate with production measure preserved in the
  sweep; rome l3_cores got settled on-node before reductions (l3_cores=4
  confirmed, no recompute needed).
- Still queued: merges/cleanups of the shipped candidates (COLDIF merge-time
  musts: gates re-run at the true rebase point, clang asan leg, branch push +
  CI); transposed-route scalar mover (2d_8192, 0-8% — deferred, WONTFIX-grade);
  rome 3d_256 NOISE — excluded from the improvement gate by construction;
  COLDIF deferred leads A2 (pass_first arm) + B1/B2 (misal buffered staging).

Reship standings (pushed-tip tables + sha): TBD (SP4).
