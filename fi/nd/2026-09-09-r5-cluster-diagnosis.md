# cluster diagnosis — fft_bench round 5 (4 hosts)

Refs: base wave admiral @ 017e132440a2900ae6dbf14f6a7a6e308ac51c46 (2026-09-08; jobs 7002700/7002701/7002702 + ccmlin075 local), reship wave admiral @ b9a2bdfe7dcdbf4d2a653c2477810435bfb7d9f0 (2026-09-09; jobs 7008487/7008488/7008489 + ccmlin075 local = m2-spr-reship). Tip of record: b9a2bdfe7dcdbf4d2a653c2477810435bfb7d9f0 (team-r5-shared/tip.sha, CI 41/41). Per-cell ledgers: 43 base-loss sections + 3 lottery-adjacent; dispositions report/d3-dispositions.md; the four host ledgers follow, concatenated verbatim.

# icelake diagnosis — fft_bench N-D LOSS cells, round-5 baseline (admiral @ 017e132, 2026-09-08)

Host: 2x Xeon Platinum 8362 (Ice Lake SP, v4 AVX-512, W=8 f64; L1d 48K, L2 1.25M/core, L3 48M/socket).
15 LOSS cells, leader mkl everywhere (standings/icelake-base.md).
Mechanisms carry over from the closed campaign's counter/record/asm attribution against
the staged binaries of that era; round-5 dispositions (W1 col staged pass_first @ 1756115,
W2 flat-tiny narrowed @ ce9f589, W3 buffered col staging NO-MERGE, W5 TILEMOVE pending)
are marked per cell with round-5 receipts. The r5base rule-11 nm census
(`/mnt/home/mbarbone/team-r5-shared/evidence/census-icelake-r5base.txt`) confirms the same
instantiation families ship in the measured binary; no re-measurement contradicts a carried
attribution on any cell below unless the section says so. Closed-campaign era numbers are
cited with their copied receipts; where the closed D1 table read differs from r5-base
(e.g. 2d_16 2.73 -> 2.135) the merges inside the window (TINY/ARMFLEX/COLFMA/COLDIF-A1)
narrowed the gap without retiring the mechanism class.

## icelake 2d_16

MECHANISM: Row-batched tiny-codelet data-movement class at N=16: split-re/im plane
transposes through port 5 plus the 2N=32(zmm file) `kernel_batched<16>` spill pass, vs
MKL's interleaved monolithic flat kernels. Closed-era differenced counters: admiral
1760 cyc / 3420 instr vs MKL 649 / 2040 (2.71x cycles == the era wall ratio 2.73; r5-base
wall 2.135 at eps 5.4e-05). 82% of exec samples sat in
`codelet_many_static<16>`+`kernel_batched<16>`+`col_codelet_body<16>`.

ASM: `codelet_many_static<16u,double,true>` = 546 insns, 128 `vshuff64x2`+64 `vunpck{lh}pd`
port-5 ops vs 40 `vmulpd` and zero FMA; `kernel_batched<16>::apply` = 363 insns with 73
`(%rsp)` spill refs (`/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-cms16.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-kb16.txt`).

CLASS: REAL

WONTFIX: W2 ship excludes W=8-f64 tiny (w2-report census +11% instr N4 v4-f64,
`/mnt/home/mbarbone/team-r5-shared/evidence/w2-report.md`). Ceiling: 0.61x-row class arm
(w5-report K=16 probe, `/mnt/home/mbarbone/team-r5-shared/evidence/w5-report.md`) ⇒
2.13→~1.7 LOSS; cost = v4-f64 store-map derivation meeting census bar

SIMD: fp512 996 vs 800 per execute (flop parity at 1.25x) — width is used, the shuffle
subclass (port-5 1000 vs 537) is the multiplier's shape, not a width deficit
(`/mnt/home/mbarbone/team-r5-shared/evidence/ice-counters-reduced.txt`).
BW: not the lever — 4 KiB/array, L1-resident; llcmiss ~0.0002/exec both arms.
CACHE: not the lever — L1 misses 0.026/exec both arms, L2 ~0.
TILING: rows batched `codelet_many_static<16>` (batch gate len<=32), col axis
`col_codelet_body<16>`; MKL runs two flat batch-row kernels instead
(`/mnt/home/mbarbone/team-r5-shared/evidence/ice-route-trace.txt`).
REGS: the lever's second half — 73/363 stack refs in `kernel_batched<16>` (2N=32 == the
zmm file), 70 stack in the gather clone.
MATH: flop parity; gap is data movement, not twiddle volume.
OVERHEAD: instr 1.68x with stores 3.6x (710 vs 199): the split-layout gather/scatter body.
STABILITY: r5-base control eps 5.36e-05 vs gap 1.135 (21k x eps); W1 sweep same-binary
floor geomean 0.0014, cell collateral on/off 0.9991 (arm silent by construction:
`/mnt/home/mbarbone/team-r5-shared/evidence/w1-icelake-reduce.md`). Round-5 disposition:
OPEN — W2's shipped arm excludes W=8 f64 tiny rows (narrowed to f64 W<=4;
`/mnt/home/mbarbone/team-r5-shared/evidence/w2-report.md` sec. 4-5), mechanism carries.

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/ice-counters-reduced.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-record/2d_16.adm.symbols.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-cms16.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-kb16.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/census-icelake-r5base.txt`

## icelake 2d_32

MECHANISM: Register-bound row codelet at N=32 (2N=64 > 32 zmm): the gather's 244 loads
are 208 from the stack — every 8-row block spills and re-fetches the split planes — plus
the axis-0 col codelet at 512 B stride. Closed-era counters: 7200 cyc vs MKL 3590
(2.0x == era wall 1.955; r5-base 1.48 at eps 3.7e-04); stores 3.0x, port-5 1.70x.

ASM: `codelet_many_static<32>` = 1191 insns, 451 shuffles, 208 stack vector memops;
`col_codelet_body<32>` = 595 insns, 7 stack — the row side carries it
(`/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-cms32.txt`).

CLASS: REAL

WONTFIX: kManyXpose 2W⌈N/W⌉=64>32 regs — fused body never compiled (diagnosis-icelake
§2d_32; census receipt `/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-cms32.txt`);
same class ceiling ⇒ 1.48→~1.2 LOSS

SIMD: fp512 1.19x — flop parity; the port-5 shuffle subclass is 1.70x vs MKL.
BW: not the lever — 16 KiB, fully resident (llcmiss 0.0013).
CACHE: not the lever — L1-miss counts trivial both arms (245/execute admiral).
TILING: batched codelet past the 2N register bound on rows + col codelet; MKL batches
radix-16 both directions in one two-kernel pass.
REGS: the lever — 208/1191 stack vector ops in the N=32 gather (spill-driven form).
MATH: flop parity; `radix_butterfly_batched_ct<8,32>` lambdas FMA-clean.
OVERHEAD: instr 1.69x, all data movement; FP+shuffles/ratio (p0+p5)/cyc 1.06 vs 1.49.
STABILITY: r5-base eps 3.685e-04 vs gap 0.48 (1300 x eps); W1/W2 sweeps collateral
flat (0.9958 / 1.0064, `/mnt/home/mbarbone/team-r5-shared/evidence/w1-icelake-reduce.md`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w2-icelake-reduce.md`). Round-5 disposition:
OPEN — no shipped wave admits the N=32 W=8 f64 row kernel.

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/ice-counters-reduced.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-cms32.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-record/2d_32.adm.symbols.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/census-icelake-r5base.txt`

## icelake 2d_64

MECHANISM: First ladder cell past the len<=32 batch gate: rows run the plain per-line
DIF chain (64 dispatches) and the col axis runs strided boundary passes at 512 B stride;
loses in both passes at 2.45x instructions with flop parity (fp512 1.1x). Closed-era
counters: 38.7k vs MKL 21.8k cyc (era wall 1.55 == r5-base 1.553).
Round-5 disposition: W1's staged `pass_first` is gated at `kColdifFirstMinLen=128`
(r5-state) and never reaches this cell — measured collateral on/off 0.9811, CONTROL-OK
(`/mnt/home/mbarbone/team-r5-shared/evidence/w1-icelake-reduce.md`); mechanism unchanged.

ASM: `dif_col_pass_first<double,true,8>` runs FP with strided memory operands (census
0 stack; the cost is multiplicity, not spills): `/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-census-admiral.txt`.

CLASS: REAL

SIMD: fp512 parity (1.1x) both 512b — not the lever.
BW: not the lever — 128 KiB, L2-resident both (llcmiss 0.0045/exec).
CACHE: L1 misses 6491 vs 4227 (1.54x) — the strided first column touch per line; real
but secondary to the instruction multiplicity.
TILING: 64 per-line row executes + col_dif Bt=64 radices 8,8
(`/mnt/home/mbarbone/team-r5-shared/evidence/ice-route-trace.txt`); MKL E2-batches columns.
REGS: not the lever — col-first census 0 stack vector ops.
MATH: flop parity; radix 8,8 both passes.
OVERHEAD: the lever — instr 2.45x at flop parity (DIF-chain multiplicity + per-line dispatch).
STABILITY: r5-base eps 0.0011 vs gap 0.553 (500 x eps); three waves collateral-flat
(0.9811/0.9953/0.9978 on/off).

WONTFIX: col-boundary residual — closed-campaign recheck (job 7001799, 12 interleaved
rounds) read tip/best 1.5528 vs reship 1.552 inside same-binary control eps 0.0011
(`/mnt/home/mbarbone/team-r5-shared/evidence/lottery-ice2/reduce.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/lottery-ice2/recheck/measure.tsv`); the
improvement owed was W1's A2 arm, which shipped and does not reach len-64 axes; residual
bound: the remaining gap needs the deferred batched-column E2 shape (MKL's win shape),
cost = new engine, ceiling ~1.1-1.5x by class (closed summary).

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/ice-counters-reduced.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-record/2d_64.adm.symbols.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-census-admiral.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w1-icelake-reduce.md`

## icelake 2d_128

MECHANISM: Strided col boundary passes at 2 KiB column stride plus the row pass's
pow2-alias tax: alias events 22.4k vs 14.3k (1.57x), L1 misses 1.5x, with 25% of cycles
under memory stalls. The col-first boundary pass drops FMA contraction (zero FMA in
`dif_col_pass_first<16>`) — mul/add split halves FP throughput at flop parity (fp512 1.07x).
Closed-era counters 1.90x == era wall 1.833; r5-base 1.596.

ASM: `dif_col_pass_first<double,true,16ul>` = 1119 insns, 309 scalar `mov` (index math)
vs 289 FP, zero FMA — `/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-difcolfirst16.txt`.

CLASS: REAL

SIMD: 512b both; the boundary pass emits zero FMA — FP-pipe efficiency halved there.
BW: not the lever — 512 KiB L2-resident both (llcmiss 0.03/0.01).
CACHE: lever share — L1 miss 1.5x at L1-resident size = set-conflict eviction class.
TILING: rows len-128 iterative_dif, col_dif Bt=128 radices 16,8; MKL batches both
directions 16-wide — the batched-column shape was absent from the col chain pre-W1.
REGS: not dominant — 89 stack of 1119 (8%) in the hot col clone.
MATH: flop parity; the FMA loss is the boundary pass, not the factoring.
OVERHEAD: instr 1.59x (309 scalar mov/1119 in the strided pass).
STABILITY: r5-base eps 0.00523 vs gap 0.596 (114 x eps); W1 sweep same-binary floor
on this cell 0.0009 (on2/on).

Round-5 disposition: CLOSED BY W1 (merged 1756115, staged col `pass_first`): this was the
wave's owned cls128 cell on this host — sweep on/off 0.9331, 7 interleaved rounds, min-stat
(`/mnt/home/mbarbone/team-r5-shared/evidence/w1-icelake-reduce.md`); reship-era stands at
1.411 (from 1.596; `/mnt/home/mbarbone/team-r5-shared/evidence/reship-icelake.md`).

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/ice-counters-reduced.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-difcolfirst16.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-record/2d_128.adm.symbols.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w1-icelake-reduce.md`

## icelake 2d_256

MECHANISM: Boundary-pass pressure at the L2 crossover (2 MiB arrays vs 1.25 MiB L2/core):
alias 103.6k vs 56.6k (1.83x), loads 2.23x, stalls_mem_any 32% of cycles, and ~45% stack
traffic in the hot `dif_col_pass_last<32>` clone (663 `%rbp`-frame `vmovapd` against 599 FP).
L2 spill-to-L3 is shared with MKL (l2 miss 15.6k vs 17.3k) — what admiral adds is the alias
class and the load/store multiplicity. Closed-era counters 1.68x == era wall 1.523; r5-base
1.699.

ASM: `/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-difcol32.txt` (the 1780-insn
spill-heavy col clone) and `/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-difrowlast32.txt`
(row boundary clone, 560 stack vector ops; `%rbp`-realigned framing — a `%rsp` grep reads a
false zero, the known census hazard).

CLASS: REAL

SIMD: flop parity (1.06x) but zero FMA across both boundary passes — half-efficient FP pipes.
BW: not the lever — both arms L3-resident, DRAM idle (llcmiss 0.15/exec).
CACHE: the lever — L2-capacity crossover + alias 1.83x; l1d.replacement 1.53x.
TILING: col_dif Bt=104, 3 tiles, radices 16,16 on this host (icelake's halved per-core L2
shrinks Bt from SPR's 168): `/mnt/home/mbarbone/team-r5-shared/evidence/ice-route-trace.txt`.
REGS: the lever at asm level — 45% stack traffic in `dif_col_pass_last<32>`.
MATH: flop parity; contraction loss is the strided twiddle form.
OVERHEAD: instr 1.43x; boundary passes own 79% of exec samples
(`/mnt/home/mbarbone/team-r5-shared/evidence/ice-record2/2d_256.adm.symbols.txt`).
STABILITY: r5-base eps 0.004212 vs gap 0.699 (166 x eps); era D1 max/min 1.103 within-arm —
the spread is weather, the 1.68x instruction defect is stable.

Round-5 disposition: CLOSED BY W1 (1756115), owned cls256 cell: sweep on/off 0.9485,
7 rounds (`/mnt/home/mbarbone/team-r5-shared/evidence/w1-icelake-reduce.md`); reship-era
1.33 (`/mnt/home/mbarbone/team-r5-shared/evidence/reship-icelake.md`).

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/ice-counters-reduced.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-difcol32.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-difrowlast32.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w1-icelake-reduce.md`

## icelake 2d_512

MECHANISM: Same boundary-pass class as 2d_256 at 8 MiB (L3-resident), bookkeeping-heavy:
instr 1.62x, alias 1.9x, and the dTLB tell — 51 page-walk completions/execute vs MKL's 3.8,
the 8 KiB column stride walking pages. The boundary clone is the same 1780-insn spill form
as 2d_256 (Bt=48, 11 tiles).

ASM: `/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-difcol32.txt` (shared clone);
the cell runs it across 7-11 tiles per axis.

CLASS: REAL

SIMD: 512b; flop +11% (twiddles re-materialized through spills) — small share.
BW: not the lever — L3-resident (llcmiss 0.92/exec).
CACHE: lever — alias 1.9x, replacements 1.6x; stall share 34% admiral vs 38% MKL (admiral
at a lower total).
TILING: col_dif Bt=48, 11 tiles, radices 16,32; tiles stride 8 KiB = the dTLB price.
REGS: boundary-pass spill traffic per the difcol32 census (radix-32 clone).
MATH: flop parity within 11%.
OVERHEAD: instr 1.62x over 7-11 tile invocations per axis.
STABILITY: r5-base eps 0.004468 vs gap 0.26 (58 x eps). Closed campaign found a reship-day
era split at this cell (two unimodal slow clusters 1.43-1.57e6 vs D1-day 1.25e6;
`/mnt/home/mbarbone/team-r5-shared/evidence/lottery-ice2/reduce.txt`) — an era-weather
history, not a code move: PRE and TIP arms drew from one cluster with route identity 28/28.

Round-5 disposition: CLOSED BY W1 (1756115, owned cls512): sweep on/off 0.9796
(`/mnt/home/mbarbone/team-r5-shared/evidence/w1-icelake-reduce.md`). Reship-era reads 1.375
with the leader arm moved −19% era-side (mkl 1.251e6 -> 1.008e6 min;
`/mnt/home/mbarbone/team-r5-shared/evidence/reship-icelake.md`) — the era anchor absorbs
that at judgment time; the measured arm effect stands.

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/ice-counters-reduced.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-record2/2d_512.adm.symbols.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-difcol32.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/lottery-ice2/reduce.txt`

## icelake 2d_1024

MECHANISM: Boundary tiles (col_dif Bt=24, 43 tiles, radices 4,8,32) on top of the cell's
signature instability class: `effort::measure`'s fixed point is under-determined across
planning contexts — closed campaign: 24 fresh processes read a unimodal 7.109..7.272e6 ns
while the D1-day table read 5.487e6 (MKL stable 4.83e6; era wall 1.164). Round-5: the staged
col pass_last for len>=1024 shipped AT the r5-base ref itself (017e132), and the base read
narrowed to 1.027; the reship-era read 1.361
(`/mnt/home/mbarbone/team-r5-shared/evidence/reship-icelake.md`) re-exposes the same
plan-race class (admiral arm moves across days, mechanism intact).

ASM: boundary clones in `/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-difcol32.txt`
(45% stack traffic), radix-4 chain opener in
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-census-admiral.txt` (`dif_col_pass_first<4>`).

CLASS: REAL

WONTFIX: all waves flat here (w1-icelake-reduce collateral 0.9997, w5 0.9976); miss =
6e-4 ≪ plan-race band (24 fresh procs 7.11-7.27e6 vs D1-day 5.49e6 —
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-noise/2d_1024.bimodal.tsv`). Ceiling: 43
boundary tiles/axis + effort::measure fixed point — deferred lanes, no arm ships

SIMD: flop +20% at width parity — small share.
BW: not the lever — 32 MiB L3-resident, DRAM ~0 (l3missmem 60/exec).
CACHE: lever — alias 2.58x (16 KiB pitches), l1d replacements 2.73M vs 1.95M.
TILING: 43 boundary tiles per column pass vs MKL's single batched-column pass; many strided
invocations re-walk the array.
REGS: spill share of the boundary clones applies (difcol32 census).
MATH: flop parity; no factoring anomaly.
OVERHEAD: instr 1.76x; and the plan-race IS the overhead axis's special case — the chosen
fixed point is inherited by every execute in the process.
STABILITY: the cell's story — 24 fresh-plan probes unimodal per process, 1.023 spread
(`/mnt/home/mbarbone/team-r5-shared/evidence/ice-noise/2d_1024.bimodal.tsv`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-noise/2d_1024.bimodal-mkl.tsv`); era reads
bracket 1.027/1.361 across days. Classified REAL: the in-run defect (boundary-pass
multiplicity) is counter-measured on every day; the plan draw decides which LOSS magnitude
the table reads.

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/ice-counters-reduced.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-noise/2d_1024.bimodal.tsv`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-record2/2d_1024.adm.symbols.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-difcol32.txt`

## icelake 2d_2048

MECHANISM: Transposed route (strip gather/scatter): the scalar move lanes are the cell's
class — one complex element per iteration, all-scalar loop between vector row passes. The
2d_8192 attribution is the measured name-case (mover 47.1% of exec samples); the route is
identical here (col_budget_block < 2W at ice's 1.25 MiB L2: r5-state / w5 cell map).
r5-base 1.169 at eps 0.07849 (era draw across base/reship reads 1.169/1.073, mechanism
stable).

ASM: `/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-transposed-lambda.txt` — the
`apply_lines_strided_oop` gather lambda: 268 insns, 87 `mov`+16 `vmovsd`, ZERO zmm.

CLASS: REAL

SIMD: the mover emits zero 512-bit; row passes are clean 512b — a scalar mover between
vector passes.
BW: shared — the strip moves the array both ways; MKL's batched-column route avoids the
transpose entirely.
CACHE: alias ~2x class at the strip pitch (pitch poisoned at 2048-multiple lens per the
route's line-pitch guard).
TILING: transposed route, move lanes group form; W5's TILEMOVE prototype replaces the
mover with a tiled vector form built from the tree's own prims.
REGS: not the lever — scalar loop, no vector-file pressure.
MATH: row passes flop-parity; nothing in the butterfly.
OVERHEAD: the lever — per-element scalar addressing (the 268-insn loop) at ~2x instr share
on this route class.
STABILITY: base eps 0.0785 vs reship eps 0.0023 — wide-draw cell; the LOSS reproduces on
both days (1.169 / 1.073).

Round-5 disposition: closed by W5 at b9a2bdf (`perf: enable the tiled transposed-route
mover by default`; the gw%W==0 && len>=W gate admits this W=8 f64 geometry). The scalar
move lanes of the mechanism above are replaced by `move_run_tiled`'s W-row movement:
sweep on/off 0.9126 (off 4.08521e+07 -> on 3.72806e+07 ns) against the same-binary
on2/on 1.0026 (eps 0.0026), BIT-CHECK PASS f64 out_fnv=9a72d5d0356b02d5
(`/mnt/home/mbarbone/team-r5-shared/evidence/w5-icelake-reduce.md`); the 15-round reroll
re-PASSes the same bit-hash on the staged binaries
(`/mnt/home/mbarbone/team-r5-shared/evidence/w5-icelake-reroll.md`) and the W5 bit-split's
pinned control is bit-exact off==on at 2d_2048/2d_4096/2d_8192
(`/mnt/home/mbarbone/team-r5-shared/evidence/w5-icelake-bitsplit.md`). The W5-reship
table @ b9a2bdf reads this cell WIN 0.9796 adm/best vs mkl (eps 0.0007749; reship
3.711e+07 ns, adm/yesterday 0.908 — `/mnt/home/mbarbone/team-r5-shared/standings/icelake-reship.md`):
the wide-draw LOSS (r5-base 1.169) closed by code, past the stretch bar of 0.855.

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-transposed-lambda.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-counters-reduced.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/reship-icelake.md`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w5-report.md`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w5-icelake-reduce.md`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w5-icelake-reroll.md`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w5-icelake-bitsplit.md`

## icelake 2d_8192

MECHANISM: Transposed route at the 2 GiB crossing: differenced counters closed-era read
CYCLE-LEVEL PARITY (adm/MKL 1.019) at 2.0x instructions — the scalar strip mover doubles
instruction count while MKL stalls at the same wall (IPC 0.59 vs 1.15). The gather/scatter
lambda owned 47.1% of exec samples; W5's SPR-native re-measure (same W=8 route class)
reads the mover at 46.2% of wall OFF and drops it to 0.00% ON, replaced by
`move_run_tiled` 45.3% (`/mnt/home/mbarbone/team-r5-shared/evidence/w5-report.md` B3).
r5-base 1.011, eps 0.0012.

ASM: `/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-transposed-lambda.txt` — 268
insns all-scalar (0 zmm); W5's micro A/B at the exact geometry cut mover instructions
0.257x and cycles 0.467x, and the ON-symbols engagement census is in
`/mnt/home/mbarbone/team-r5-shared/evidence/w5-report.md` B3.

CLASS: REAL

SIMD: the mover is zero-512-bit; both other passes vector-clean — the SIMD line IS the mover.
BW: not separable — both arms drag ~2x the 2 GiB touch; MKL wins without a full transpose.
CACHE: alias 2.04x (264.6M vs 129.5M); stalls_mem 1.10e9 both arms (stall-bound parity).
TILING: transpose_group lanes on a strip; MKL runs coDFTColBatch batched columns; FFTW's
indirect-transpose is BEATEN by admiral's route on this host (era adm/fftw 0.808).
REGS: not the lever — scalar loop.
MATH: row passes flop-parity (fp512 1.2x).
OVERHEAD: the whole gap — instr 2.0x at cycle parity, per-element scalar addressing.
STABILITY: admiral is the noisy arm closed-era (12 rounds max/min 1.088 vs MKL 1.004;
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-noise/2d_8192.rounds.tsv`); r5-base eps
0.0012 vs gap 0.011 (9 x eps); reship-era 1.012 — flat, as expected: W5 not yet landed.

Round-5 disposition: adjudicated by W5 at b9a2bdf. The sweep read on/off 1.0185 against
same-binary on2/on 0.9980 (|eps| 0.0020; geomean same-binary floor 0.0013 over 18 cells)
— over the floor, UNRESOLVED, escalated to the reroll
(`/mnt/home/mbarbone/team-r5-shared/evidence/w5-icelake-reduce.md`). The 15-round
fixed-rep reroll reads on/off 1.0128 min-stat (median 0.9989, eps_cell 0.0062) inside
tol 0.02: LOTTERY (`/mnt/home/mbarbone/team-r5-shared/evidence/w5-icelake-reroll.md`).
The mover is bit-clean: the W5 bit-split's pinned control (effort::estimate, no timing
race) is bit-exact off==on at 2d_2048/2d_4096/2d_8192
(`/mnt/home/mbarbone/team-r5-shared/evidence/w5-icelake-bitsplit.md`), and the ice reroll
staged binaries re-PASS 2d_2048 f64 9a72d5d0356b02d5 — the same hash the pinned control
reads. The W5-reship table @ b9a2bdf keeps the cell LOSS 1.030 adm/best vs mkl (eps
0.0001764; reship 7.528e+08 ns, adm/yesterday 1.016 —
`/mnt/home/mbarbone/team-r5-shared/standings/icelake-reship.md`): the TILEMOVE arm is
neutral on this host class at the 2 GiB geometry — the transposed route there is
DRAM/frequency-bound, not mover-bound (mover share ~60% SPR-measured vs ~47% the ice-era
measurement, `/mnt/home/mbarbone/team-r5-shared/evidence/w5-report.md` B1/B3). The closed
campaign's WONTFIX (0-8% leader-gap ceiling) is superseded by the at-geometry read: the
arm's headroom does not transfer to ice at 8192^2 — a weather-limited band, not a mover
defect. CLASS stays REAL.

LOTTERY: W5-arm effect at this cell is weather-band — 15-round reroll on/off 1.0128 <=
tol 0.02 (eps_cell 0.0062), evidence logged
(`/mnt/home/mbarbone/team-r5-shared/evidence/w5-icelake-reroll.md`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w5-icelake-bitsplit.md`); CLASS stays REAL
(the base loss is counter-attributed, not a draw) and the improvement gate re-baselines
via reship2.

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-transposed-lambda.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-counters-reduced.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-noise/2d_8192.rounds.tsv`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w5-report.md`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w5-icelake-reduce.md`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w5-icelake-reroll.md`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w5-icelake-bitsplit.md`

## icelake 3d_4

MECHANISM: xmm-class tiny machinery on every axis (no zmm in the hot symbols): per-line
`codelet_apply<4>` + `dif_col_tail_fused<4>` col chains (len 4 < 8 never admits the col
codelet) + N-D dispatch layers. Closed-era counters: 1130 vs MKL 321 cyc (era wall 3.91;
r5-base 3.246) at 3.2x instructions with BALANCED ports and high IPC — pure instruction
count through sub-vector code. MKL's N=4 kernel is 512-bit (fp512 144 vs 52).

ASM: `/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-census-admiral.txt` tiny-N block:
`codelet_apply<4u,double,true>` = 48 insns 128-bit class, 0 zmm; `col_dif_execute_ws` = 405
insns of dispatch bookkeeping for a 64-point transform.

CLASS: REAL

WONTFIX: W2 reroll draw 1.0102
(`/mnt/home/mbarbone/team-r5-shared/evidence/w2-reroll-icelake.md`) + census-bar fail.
Ceiling: zeroing the ms4 share leaves ~3.0 of 3.31 LOSS; cost = dispatch-layer redesign

SIMD: the lever — 512b ops 52 vs MKL's 144; the cell's work is xmm-class.
BW: not the lever — 1 KiB, nothing misses (llcmiss 0.0003).
CACHE: not the lever — 0 L1 replacements past warmup.
TILING: batched dispatch admitted at pass A (len<=32 gate); the col chains run len-4 fused
radix-4 passes per line.
REGS: not the lever — no vector-file pressure at xmm widths (<=4 stack refs).
MATH: trivial flops; the len-4 twiddle-table setup rivals the transform cost.
OVERHEAD: THE mechanism — 3.2x instructions at equal port mix (per-line dispatch + scalar
boundary machinery); record put execute_nd+nd_apply_axis at 15%.
STABILITY: r5-base eps 3.7e-04 vs gap 2.246 (6k x eps). Round-5: W2's prototype reroll on
this host read the arm effect as a draw (on/off 1.0102, |delta| <= tol 0.02;
`/mnt/home/mbarbone/team-r5-shared/evidence/w2-reroll-icelake.md`) and the SHIPPED arm
excludes W=8 f64 outright (`/mnt/home/mbarbone/team-r5-shared/evidence/w2-report.md`
census sec. 4: v4 f64 W8 N4 278/48/0 -> 309/32/0 = +11% instr class, stripped by the
wave adjudication) — the mechanism stands untouched at master.

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/ice-counters-reduced.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-record/3d_4.adm.symbols.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-census-admiral.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w2-reroll-icelake.md`

## icelake 3d_8

MECHANISM: Row-batched N=8 codelet regime with the two col axes dominant:
`col_codelet_body<8>` held 41% of exec samples vs rows` `kernel_batched<8>` 28% (clean,
0 stack) + gather 19%; stores 2.8x, port-5 1.85x vs MKL at flop parity. Closed-era
2.79x == era wall 2.785; r5-base 2.81.

ASM: `/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-cms8.txt` (`codelet_many_static<8>`
= 382 insns, 98 shuffles) and col body census in
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-census-admiral.txt`
(`col_codelet_body<8>` = 237 insns, 16 FP, 34 stack).

CLASS: REAL

WONTFIX: priced arm exists — W2 prototype 0.9671 reroll-confirmed
(`/mnt/home/mbarbone/team-r5-shared/evidence/w2-reroll-icelake.md`), blocked by genoa
+3.1% (geometry-inexpressible); ceiling 2.81→2.72 LOSS even unblocked

SIMD: flop parity (fp512 1.17x), all 512b; shuffle subclass 1.85x carries the SIMD line.
BW: not the lever — 8 KiB fully resident.
CACHE: not the lever — L1 miss 0.06/exec.
TILING: pass A batched, both col axes col_codelet_body<8>; MKL's compute_tiny_3d driver
runs flat radix-8 kernels through.
REGS: clean — kernel_batched<8> 0 stack; not the lever.
MATH: flop parity; gather twiddle juggling, not extra FP.
OVERHEAD: instr 1.36x with stores 2.8x — split-layout gather/scatter body again.
STABILITY: r5-base eps 4.7e-04 vs gap 1.81 (3.9k x eps). Round-5: the W2 PROTOTYPE moved
this cell −3.3% reroll-confirmed (on/off 0.9671, sweep-consistent;
`/mnt/home/mbarbone/team-r5-shared/evidence/w2-reroll-icelake.md`) but the same shape
regressed +3.1% on genoa and the shipped arm was narrowed to f64 W<=4
(`/mnt/home/mbarbone/team-r5-shared/evidence/w2-report.md` + r5-state adjudication) — the
mechanism is intact at master by construction; disposition OPEN with a priced arm in hand.

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/ice-counters-reduced.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-cms8.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-record/3d_8.adm.symbols.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w2-reroll-icelake.md`

## icelake 3d_16

MECHANISM: Tiny-cell band at the L1d edge (64 KiB vs 48 KiB L1d): batched row codelet
N=16 spills (2N=32) + axis-1 col codelet + axis-0 col_dif opened by a radix-2 boundary
pass. Closed-era counters: 2.33x cyc ratio == era wall 2.247 (r5-base 1.938); stores 3.3x,
port-5 1.75x, l1d.replacement 1.68x.

ASM: `/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-kb16.txt` (73 stack refs of 363)
and `dif_col_pass_first<double,true,2ul>` in
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-census-admiral.txt` (scalar-heavy
stride-256 B chain opener).

CLASS: REAL

WONTFIX: sweeps flat 0.9979/1.0020/1.0003 (w1/w2/w3 reduces;
`/mnt/home/mbarbone/team-r5-shared/evidence/w1-icelake-reduce.md`); class ceiling ⇒
1.94→~1.56 LOSS

SIMD: flop +31% (spilled twiddle re-materialization) — a share, not the whole.
BW: not the lever — 128 KiB, L1d/L2-resident (llcmiss 0.0008).
CACHE: contributory — l1d.replacement 1.68x at the L1d boundary; the gather's second visit
pays evictions.
TILING: rows batched N=16; axis1 col codelet Bt=16; axis0 col_dif Bt=256 radices 2,8
(`/mnt/home/mbarbone/team-r5-shared/evidence/ice-route-trace.txt`).
REGS: lever on the row axis — `kernel_batched<16>` at the 2N=zmm-file edge.
MATH: flop +31% from spill re-materialization, not a worse factoring.
OVERHEAD: instr 1.68x total.
STABILITY: r5-base eps 0.0063 vs gap 0.938 (150 x eps); all three round-5 sweeps read this
cell collateral-flat (on/off 0.9979 / 1.0020 / 1.0003 in the w1/w2/w3 reduces).

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/ice-counters-reduced.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-kb16.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-record/3d_16.adm.symbols.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w1-icelake-reduce.md`

## icelake 3d_32

MECHANISM: The 2N-bound gather on pass A (`codelet_many_static<32>`, 31.5% of samples) plus
col_dif chains on both col axes; the axis-0 chain strides 16 KiB between column elements.
Closed-era tell: address-alias 54.4k vs 19.4k (2.8x — the highest alias ratio class in the
era table); stores 2.4x, port-5 1.58x. Era counters 1.81x == era wall 1.487; r5-base 1.28.

ASM: `/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-cms32.txt` (451 shuffles, 208
stack vector ops of 1191 insns — the register-bound 32-point gather, same symbol class as
2d_32); col boundary forms in
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-census-admiral.txt`.

CLASS: REAL

WONTFIX: sweeps flat 0.9916/1.0017/0.9940; 0.61x-row over pass-A 31.5% share
(`/mnt/home/mbarbone/team-r5-shared/evidence/ice-record/3d_32.adm.symbols.txt`) ⇒
1.28→~1.12 LOSS

SIMD: flop +23%, shuffle subclass 1.58x — both share the SIMD line.
BW: not the lever — 1 MiB, L2-path (llcmiss 0.019).
CACHE: alias 2.8x at the 16 KiB axis-0 pitch; l1 replacements 1.4x.
TILING: pass A batched past the 2N bound; axis1 col codelet; axis0 col_dif Bt=848, 2 tiles,
radices 4,8 (`/mnt/home/mbarbone/team-r5-shared/evidence/ice-route-trace.txt`).
REGS: the pass-A lever — the register-bound gather census quoted.
MATH: flop +23% (spill re-materialization).
OVERHEAD: instr 1.73x over three axes of data movement.
STABILITY: r5-base eps 0.0030 vs gap 0.28 (93 x eps); sweeps collateral-flat
(0.9916/1.0017/0.9940).

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/ice-counters-reduced.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-cms32.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-record/3d_32.adm.symbols.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/census-icelake-r5base.txt`

## icelake 3d_128

MECHANISM: 3-D DRAM-resident band: axis-0 col_dif whose column elements sit 256 KiB apart —
every successive element of a column line is 64 pages along; dTLB walk completions 44x/107x
MKL's (1232+761 per execute vs 27.7/7.1), alias 1.73x, l1d replacements 1.71x, loads 1.66x.
Closed-era counters 1.30x == era wall 1.275; r5-base 1.29.

ASM: `/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-difcolfirst16.txt` (16-radix
strided first pass, index-scalar heavy, zero FMA) + boundary last-pass row in
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-census-admiral.txt`.

CLASS: REAL

SIMD: flop parity (fp512 1.07x) — not the lever.
BW: shared DRAM reality at 64 MiB total (llcmiss within 5% both) — the gap is NOT bytes.
CACHE: the lever — replacements 1.71x + alias 1.73x + walk completions 44x: the column pass
misses pages and sets simultaneously.
TILING: axis0 col_dif Bt=208, 79 tiles (last 160), radices 16,8
(`/mnt/home/mbarbone/team-r5-shared/evidence/ice-route-trace.txt`): 79 tile sweeps re-walk
the 32 MiB array while MKL copies slabs once.
REGS: boundary-clone spill class applies to the <16> family here too.
MATH: flop parity; nothing in the twiddles.
OVERHEAD: instr parity (1.03x) — the gap is pure memory-system pressure.
STABILITY: r5-base eps 0.0074 vs gap 0.29 (39 x eps); same-binary floor at the W1 sweep
on2/on 1.0036.

Round-5 disposition: CLOSED BY W1 (1756115, owned cls128 in 3-D): sweep on/off 0.9596, 7
rounds (`/mnt/home/mbarbone/team-r5-shared/evidence/w1-icelake-reduce.md`); reship-era 1.245
(`/mnt/home/mbarbone/team-r5-shared/evidence/reship-icelake.md`).

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/ice-counters-reduced.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-difcolfirst16.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-record2/3d_128.adm.symbols.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w1-icelake-reduce.md`

## icelake 3d_256

MECHANISM: Largest 3-D cell: axis-0 column elements 1 MiB apart — the boundary passes run
at worst-case alias/pagewalk shape with loads 1.78x and replacements 1.51x at INSTRUCTION
PARITY (504M vs 510M): the gap is memory-system, not issue count; MKL misses MORE to DRAM
(12.1M vs 9.9M llcmiss) yet wins — admiral is L2/L1-side bound.
Era counters 1.10x == era wall 1.115; r5-base 1.088.

ASM: `/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-difcol32.txt` +
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-difrowlast32.txt` (radix-32 boundary
clones; 45% stack traffic in the col clone).

CLASS: REAL

SIMD: width parity, no 512b deficit.
BW: shared — MKL misses to DRAM more; admiral's deficit is above DRAM, in L1/L2.
CACHE: the lever — replacements 1.51x, alias 1.64x at 1 MiB element stride.
TILING: axis0 col_dif Bt=128 over 512 tiles re-walking 128 MiB
(`/mnt/home/mbarbone/team-r5-shared/evidence/ice-route-trace.txt`); MKL copies outer axes
to a contiguous slab once and runs batched columns.
REGS: spill share of the col boundary clone applies.
MATH: flop parity; no factoring anomaly.
OVERHEAD: instr parity — memory pressure is the gap.
STABILITY: r5-base eps 0.0051 vs gap 0.088 (17 x eps).

Round-5 disposition + LOTTERY: W1 owned-cls256 sweep read LOSS-direction 1.0118 on this
col class; the escalated 15-round reroll read on/off 0.9925 with same-binary eps 0.0038
within tol 0.02 (`/mnt/home/mbarbone/team-r5-shared/evidence/w1-reroll-icelake.md`) — i.e.
the arm's effect at this cell is an era draw, and the sweep read was the weather sampling it.
LOTTERY attaches to the W1-effect question, not to the carried mechanism (which stays REAL
and open for a later data-path wave); reship-era reads 1.098 vs base 1.088.

LOTTERY: evidence-bound era-draw class for the W1 sweep reading at this cell — 15-round
interleaved reroll min-stat 0.9925 ties the floor; routes and fp volume conserved per the
reroll receipt. CLASS stays REAL (the base loss is counter-attributed, not a draw).

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/ice-counters-reduced.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-asm-difcol32.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ice-record2/3d_256.adm.symbols.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w1-reroll-icelake.md`

## icelake summary

Round-5 disposition map: W1 (1756115) closed the owned col classes — 2d_128 (0.9331),
2d_256 (0.9485), 2d_512 (0.9796), 3d_128 (0.9596) — and read lottery-grade at 3d_256.
W2's tiny arm does not ship at W=8 f64 (wave adjudication), so the tiny family
(2d_16, 2d_32, 3d_4, 3d_8, 3d_16, 3d_32 rows) carries over open, with the priced v4-f64
prototype in hand (−3.3% at 3d_8, +11% instr class risk noted in the W2 census for N=4).
2d_64 keeps its closed-campaign WONTFIX (recheck-bounded residual, A2 arm shipped but
gated at len>=128). 2d_1024 keeps its plan-race + boundary-tile attribution (narrowed by
the staged pass_last shipped at the base ref; era-sensitive magnitude). 2d_2048 is closed
by W5 at b9a2bdf (sweep 0.9126 vs same-binary 1.0026; reship-era WIN 0.9796) and 2d_8192
is adjudicated at b9a2bdf (CLASS REAL + LOTTERY: reroll 1.0128 <= tol 0.02, arm neutral,
reship-era LOSS 1.030 stands). No open slots remain in this file.

# rome diagnosis — fft_bench N-D LOSS cells, round-5 baseline (admiral @ 017e132, 2026-09-08)

Host: 2x EPYC 7742 (Zen2 fam17h, W=4 f64 AVX2-native). 10 LOSS cells, leader fftw x9,
ducc x1 (2d_1024; standings/rome-base.md).
Contradiction note the audit should read first: the closed campaign's D1 columns (c4c3911)
predate the TINY-ship (e9fa2a3), ARMFLEX (d54ce3b..7bbb199), COLFMA piece_fma and
COLDIF-A1 merges that r5-base carries. Closed counter volume and census histograms below
remain the FMA-free/pin-era ones where marked; the merged window narrowed several fftw-led
small cells (2d_16 1.766 -> 1.432, 2d_64-class flattening) without changing verdicts.
Zen2-only axes: `ls_misal_accesses` (256-bit ops crossing a 32 B L1 face) reads 1e3-1e6
on admiral cells where fftw reads ~0; the col chain's zero-FMA stream was the bit-stability
pin's cost — COLFMA restored piece_fma inside the pin class in-window, so absolute fp_mac
figures from `/mnt/home/mbarbone/team-r5-shared/evidence/rome-counters.md` are
era-archived; the load/misalignment/store multiplicities they sit next to are not.

## rome 2d_16

MECHANISM: W=4 row-batched tiny family at N=16: the fused-gather gate
(`2W*ceil(N/W) <= vregs` = 64 > 16) fails, so `codelet_many_static<16>` keeps the SPLIT
gather (257 shuffles + 100 stack memops in 552 insns) while `kernel_batched<16>` holds
2N=32 ymm planes against a 16-register file (142 `vmovapd` stage traffic of 358 insns).
Closed-era differenced counters: 2541 vs fftw 1459 cyc, instr 1.55x, stores 1.89x at fp
volume 1.22x (`/mnt/home/mbarbone/team-r5-shared/evidence/rome-counters.md`).

ASM: `codelet_many_static<16>` + `kernel_batched<16>` census rows in
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-asm-census.txt`; FFTW's comparator
`n1fv_16_avx2` = 284 insns, 49 shuffles in
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-asm-census-fftw.txt`.

CLASS: REAL

WONTFIX: N=16 row untouched by shipped N≤8 whitelist (w2-report §1,
`/mnt/home/mbarbone/team-r5-shared/evidence/w2-report.md`); K=16-class arm over
~half-row share ⇒ 1.43→~1.15 LOSS; cost = derivation + fr_shape+kFlatRow-budget
relaxations + kManyRollMinBlocks selector
(`/mnt/home/mbarbone/team-r5-shared/evidence/w5-report.md` A0-A3)

SIMD: both arms 256-bit; the split-gather shuffle count (257/block vs fftw 49/codelet) is
the lever's shape — not width.
BW: not the lever: 2x 4 KiB, L1-resident; l1_ldmiss 0.117/xform.
CACHE: not the lever: L1 misses ~0 both arms.
TILING: single tile both arms; route codelet/codelet
(`/mnt/home/mbarbone/team-r5-shared/evidence/rome-routes/rome-route-2d_16.log`).
REGS: lever share — 32 ymm planes against 16 registers → the 142-`vmovapd` stage stream.
MATH: fp composition similar flops; admiral's mul share sat outside FMA form (fma=0 census
row, era-archived by COLFMA).
OVERHEAD: dispatch/table layers 6.2% of record cycles — not the lever.
STABILITY: r5-base eps 5.5e-04 vs gap 0.432 (~800 x eps); W1/W2/W3 sweeps collateral-flat
(on/off 1.0035 / 1.0058 / 1.0070). Round-5 disposition: OPEN — W2's shipped arm covers
N in {4,8} only; the N=16 row kernel is kFlatRow territory (untouched by the N<=8
whitelist; w2-report sec. 1).

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/rome-counters.md`,
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-asm-census.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-asm-census-fftw.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-record/rome-2d_16.report.txt`

## rome 2d_32

MECHANISM: ROLLED row-batched codelet `codelet_many_body<32>` + `kernel_batched<32>`
(78.3% of record cycles): 2N=64 ymm planes vs 16 registers — 423 `vmovapd` + 164 stack
memops in 979 insns, fp 427 of which 61 FMA. Closed-era counters: 11290 vs 6570 cyc
(1.72x; era wall 1.694, r5-base 1.704 — unchanged class, verdict stable across eras).

ASM: `kernel_batched<32>` census row in
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-asm-census.txt`; record shares
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-record/rome-2d_32.report.txt`.

CLASS: REAL

SIMD: 256-bit both; the rolled body re-gathers per W-block while fftw's direct codelet
covers 32 rows per call.
BW: not the lever: 2x 16 KiB in L2.
CACHE: not the lever: misses ~5% of cycles at Zen2 latency.
TILING: single tile; col axis col_codelet_body<32> 18.86%.
REGS: THE lever with shuffles — 423 stage memops (2N=64 vs 16 regs).
MATH: adm FMA share 0.68x of fftw (pin-era form; COLFMA covers the col chain, this deficit
sits in the row kernel).
OVERHEAD: dispatch ~2.3% — not the lever.
STABILITY: r5-base eps 0.0022 vs gap 0.704 (320 x eps); three waves collateral-flat
(1.0012 / 0.9998 / 0.9993).

WONTFIX: A3 rule-out from the W5 tail lane with bound —
`/mnt/home/mbarbone/team-r5-shared/evidence/w5-report.md`: a driver-forced K=16 flat_row
arm (new rev3 store map, numerically proven) measures 0.61x instr / 0.61x cyc on the ROW
axis at znver2 codegen, but rows are ~60% of the cell → cell ceiling 0.764 →
1.704 * 0.764 = 1.30 vs fftw, still LOSS; the achievable arm cannot flip the cell and the
cost is a new kernel derivation + two gate relaxations (fr_shape whitelist + kFlatRow
budget 20>12) + the kManyRollMinBlocks selector in front. No cluster spend.

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/rome-counters.md`,
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-asm-census.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w5-report.md`,
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-record/rome-2d_32.report.txt`

## rome 2d_64

MECHANISM: Mixed engine cell: pass A per-line `codelet_apply<64>` (36.85%) nesting
`kernel_batched<16>` (31.51%) + col-codelet `col_codelet_body<64>` (19.09%; e2 cap 64
admits it on rome's 4 MiB L3/core where SPR gates at 32). Issue-bound, not cache-bound:
admiral's L1-load misses are LOWER than fftw's (4765 vs 7060) at cycles 1.216x and instr
1.368x (`/mnt/home/mbarbone/team-r5-shared/evidence/rome-counters.md`).

ASM: `codelet_apply<64u>` / `col_codelet_body<64u>` census rows in
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-asm-census.txt`; FFTW plan
(dft-direct-64-x64, n1fv_64 avx+avx2 mix) in
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-routes/rome-fftwplan-2d_64.log`.

CLASS: REAL

WONTFIX: batch-gate admit candidate measured+rejected (loses 2/3 hosts, closed era); all
arms flat (1.0001/1.0018/0.9990; bundle 0.9979); free per-line loop (36.9%,
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-record/rome-2d_64.report.txt`) ⇒ 0.79
only on paper — admission rejected

SIMD: 256-bit both; per-line recursion issues 1.37x instructions for the same flops.
BW: not the lever: 2x 64 KiB fit L2/L3; admiral is the LEANER cache citizen here.
CACHE: not the lever (admiral l1 misses lower).
TILING: col codelet Bt=64 run-capped; rows per-line; fftw batches 64 rows/call.
REGS: kernel_batched<16> stage traffic inside the len-64 codelet (2d_16 census row).
MATH: fp +14%, FMA share −23% (era-archived pin form; the class survives as issue count).
OVERHEAD: per-line dispatch 1.6% + execute 0.7% — present, not the lever.
STABILITY: r5-base eps 0.0012 vs gap 0.237 (197 x eps); sweeps collateral-flat
(1.0001 / 1.0018 / 0.9990); reship-era 1.238 == base magnitude
(`/mnt/home/mbarbone/team-r5-shared/evidence/reship-rome.md`).

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/rome-counters.md`,
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-asm-census.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-record/rome-2d_64.report.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-routes/rome-fftwplan-2d_64.log`

## rome 2d_128

MECHANISM: col axis past the e2 cap at len 128 routes col_dif (chain 4,4,8): closed-era
record had the col family at 45.7% of cycles with the pin-era zero-FMA mul+add col stream
(fp_mac 0.31x of fftw) and ls_misal 1.85e4/xform. r5-base reads 1.023 at eps 0.0037 —
narrowed from the era-archived attribution (COLFMA's piece_fma shipped in-window layered
over the pin class) to a small residual, WITHOUT a verdict change.
Round-5 evidence bounds the residue's source: the W3 misal-cure arm (buffered col staging;
static alignment census-proven to do what it says) read FLAT here (on/off 1.0129, FLAT-OK;
`/mnt/home/mbarbone/team-r5-shared/evidence/w3-rome-reduce.md`), and W1's staged pass_first
read flat as collateral (0.9949) — so neither the first-pass stage nor the misaligned-gather
class owns the remaining 2.3%; it sits in the chain's tile/address multiplicity.

ASM: `dif_col_pass<8>` census row (565 insns, 242 stack refs, 198 scalar mov, era fma=0)
in `/mnt/home/mbarbone/team-r5-shared/evidence/rome-asm-census.txt` — the scalar-index and
stack shares carry over as the residual class.

CLASS: REAL

SIMD: 256-bit; col-chain FMA form restored by COLFMA in-window; the remaining SIMD content
is index scalar-mix, not FP pipes.
BW: modest: 2x 256 KiB in L3; l2_fill pressure shared.
CACHE: L1 miss ratio-era ~1x..1.2x read; not the residual's name.
TILING: chain 4,4,8 Bt=84 (era analytic read; route unchanged at r5 base class);
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-routes/rome-route-2d_128.log`.
REGS: 242 stack refs/565 insns in the col passes — present in the residual.
MATH: era fp_mac 0.31x-of-fftw statement SUPERSEDED by COLFMA shipping; residual math clean.
OVERHEAD: 198 scalar mov in the strided pass — the address-arithmetic multiplicity.
STABILITY: r5-base eps 0.0037 vs gap 0.023 (6.2 x eps); reship-era 1.024
(`/mnt/home/mbarbone/team-r5-shared/evidence/reship-rome.md`); three sweeps bound the cell
inside +/-1.3% arm-control — the residual is small but stable, REAL at 6x eps.

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/rome-counters.md`,
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-asm-census.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-record/rome-2d_128.report.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w3-rome-reduce.md`

## rome 2d_1024

MECHANISM: Route, not kernel — and the route defect is CLOSED at r5-base. Closed campaign
measured the `max(16, 2W)` kAbsGate flip regressing this cell +14.1% (col_budget_block 10 vs
16 → transposed strip, era read 1.185 vs c4c3911's 1.048); master's shipped gate form is
`col_budget_block < 2W` (10.4 >= 8 at W=4 → col_dif route, the ducc-even shape;
`/mnt/home/mbarbone/team-r5-shared/evidence/w5-report.md` B3 cell map names the cell dead
for TILEMOVE because it is NOT transposed). What remains at r5-base is 1.011 at eps 0.0078;
the reship table reads TIE 1.02 at eps 0.070
(`/mnt/home/mbarbone/team-r5-shared/evidence/reship-rome.md`).

ASM: era strip-lambda census (186 insns, 85 scalar-mem, 0 fp — the form the closed gate
flip executed, NOT the current route) in
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-asm-census.txt`.

CLASS: NOISE

SIMD: 256-bit col_dif both-route-equal width class; not the question.
BW: 2x 16 MiB vs 16 MiB CCX L3 — both arms stream; not the discriminator at 1.1%.
CACHE: era strip re-walked L1 at 3.1e6 misses/xform; the restored col_dif route reads each
line once per pass — the closed regression's cache mechanism is retired.
TILING: restored col_dif chain at Bt=16-64 class, no strip.
REGS: clean at uops/instr 0.96 (era read).
MATH: fp parity-era; no math content either route.
OVERHEAD: era front-end ic_stall 78% was the strip shape's; not the current route.
STABILITY: the decisive round-5 evidence — the W2-era identical-pair read (yesterday r5base
binary vs fresh off build) moved 9.4% (yest/off 1.0935) at this cell across wave sessions
(`/mnt/home/mbarbone/team-r5-shared/evidence/w2-rome-reduce.md`), and the closed campaign's
own probe refuted within-process bimodality on rome (15/15 identical route elections;
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-race-2d1024.log`). A 1.1% standing gap
sits inside the documented ~9% era band; reship reads TIE. Bounded recheck verdict: NOISE
with mechanism documented; a REAL call would need a same-session counter separation that
the era data says cannot exist at this margin.

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/rome-race-2d1024.log`,
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-asm-census.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w2-rome-reduce.md`,
`/mnt/home/mbarbone/team-r5-shared/evidence/reship-rome.md`

## rome 3d_4

MECHANISM: Two stacked tiny-cell costs: (a) pass A per-line `codelet_apply<4>` (24.46% of
record; the many body excluded N=2/4 at the era ref), (b) the len-4 col DIF family
(`dif_col_pass_fused<4>` 39.89% + dispatcher 5.36%) since len 4 < 8 never admits the col
codelet. Counters: 1213 vs 457 fftw cyc — 2x instructions at fp 1.47x.
Round-5 disposition: CLOSED-CLASS BY W2 (flat tiny row kernels shipped at ce9f589, default
N in {4,8} f64 W<=4 — rome's f64 IS the admitted class): sweep-reroll WIN-CONFIRMED −3.8%
(on/off 0.9622, 15 interleaved rounds, same-binary eps 0.0013;
`/mnt/home/mbarbone/team-r5-shared/evidence/w2-reroll-rome.md`). The col-family share
(b) is untouched and stays on the books; reship-era 2.19 vs base 2.28
(`/mnt/home/mbarbone/team-r5-shared/evidence/reship-rome.md`).

ASM: `codelet_apply<4>` census (50 insns scalar 4-point) in
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-asm-census.txt`; FFTW plan
(n2fv_4_sse2/n1fv_4_avx2_128 + vrank) in
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-routes/rome-fftwplan-3d_4.log`.

CLASS: REAL

SIMD: the lever — the era pass A ran SCALAR at N=4 while fftw batches ymm rows; W2's flat
tiny removes the row half.
BW: not the lever: 2x 1 KiB, all L1.
CACHE: not the lever: l1_ldmiss 0.01/xform.
TILING: 16 lines/axis, single tile; the len-4 col axes stay DIF (codelet gate is len>=8).
REGS: `codelet_apply<4>` 0 stack refs — pressure never the story at N=4.
MATH: scalar 4-point re/im bookkeeping doubled the counted dfm (fp 1.47x).
OVERHEAD: ~25% of era cycles were axis dispatch plumbing — the residual after W2 carries it.
STABILITY: r5-base eps 8.8e-04 vs gap 1.28 (1.5k x eps); W2 win reroll-pinned (above).

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/rome-counters.md`,
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-asm-census.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w2-reroll-rome.md`,
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-record/rome-3d_4.report.txt`

## rome 3d_8

MECHANISM: The col axes own it: `col_codelet_body<8>` = 64.86% of record cycles vs pass A
`codelet_many_static<8>` 27.93%. Zen2-only tells: l1_ldmiss 9.4x fftw and ls_misal 113.8
vs ~0 — the strided col gather misaligns every other 256-bit access at W=4 and the col
codelet's plane round-trip costs apply at one-iteration-per-call.

ASM: `col_codelet_body<8>` census (360 insns: 78 `vmovapd` + 24 `vmovupd` + 50 shuf + 66 fp)
in `/mnt/home/mbarbone/team-r5-shared/evidence/rome-asm-census.txt`.

CLASS: REAL

SIMD: row kernel vectorized; the col gathers at W=4 are SIMD-fine, ALIGNMENT-poor — the
misal counter is the named Zen2 evidence (fftw reads ~0).
BW: not the lever: 2x 8 KiB in L1/L2.
CACHE: l1_ldmiss 9.4x — the strided col gather defeats the 32 KiB L1's line reuse.
TILING: col codelet Bt=8 (gran W=4), one iteration per call — the prologue/round-trip paid
per 8-column unit.
REGS: col body shows 106 stack refs/360 — per-call prologue class, secondary.
MATH: fp +33%: sign/dir juggling in the strided codelet.
OVERHEAD: execute+axis 3.9% — not the lever.
STABILITY: r5-base eps 2.5e-04 vs gap 0.504 (2k x eps). Round-5 disposition: CLOSED-CLASS
BY W2 (ce9f589): sweep-reroll WIN-CONFIRMED on/off 0.9685 (−3.1%, 15 rounds, eps 0.0002;
`/mnt/home/mbarbone/team-r5-shared/evidence/w2-reroll-rome.md`); reship-era 1.447 vs base
1.504 (`/mnt/home/mbarbone/team-r5-shared/evidence/reship-rome.md`). Col-codelet misal
share is the documented residual on the ticket afterwards.

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/rome-counters.md`,
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-asm-census.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w2-reroll-rome.md`,
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-record/rome-3d_8.report.txt`

## rome 3d_16

MECHANISM: Three-engine mix: pass A split-gather N=16 block (53.1%: cms16+kb16, the 2d_16
class), axis1 col codelet 14.78%, axis0 col_dif {2,8} 30.7%. Era counters 1.219x == era
wall 1.218; r5-base 1.029 at eps 6.2e-05 (margin 470 x eps) — narrowed, mechanism intact.

ASM: census rows as at 2d_16 plus `dif_col_pass_last<8>` in
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-asm-census.txt`.

CLASS: REAL

WONTFIX: 0.61x-row class over 53.1% pass-A share
(`/mnt/home/mbarbone/team-r5-shared/evidence/rome-record/rome-3d_16.report.txt`) ⇒ ~0.84
— flippable ONLY via the unshipped derivation (2d_32 ruling: no cluster spend;
`/mnt/home/mbarbone/team-r5-shared/evidence/w5-report.md` A3); cheapest future flip on
rome

SIMD: split gather at N=16 (W=4 gate fail) — 257 shuffles/block; the SIMD line's name.
BW: 2x 64 KiB in L2; l2_fill pressure present, secondary.
CACHE: l1 misses 8174 vs 8566 — parity; not the lever.
TILING: axis0 col_dif one tile per 256-line run; axis1 col codelet; rows batched codelet.
REGS: kernel_batched<16> stage traffic (2d_16 census) — secondary lever.
MATH: era fp_mac 0.48x of fftw (pin-era); in-window COLFMA narrowed it, not the shuffles.
OVERHEAD: execute+axis 0.72% — not the lever.
STABILITY: r5-base eps 6.16e-05 vs gap 0.029 (470 x eps); three sweeps collateral-flat
(0.9978 / 0.9994 / 1.0053); reship-era 1.027 magnitude-stable.

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/rome-counters.md`,
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-asm-census.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-record/rome-3d_16.report.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w1-rome-reduce.md`

## rome 3d_32

MECHANISM: Register-bound row kernel + col chains: rolled `codelet_many_body<32>` +
`kernel_batched<32>` at 53.39% (the 423-vmovapd stage stream) with axis0 col_dif {4,8}
29.4%. Era recheck pinned the loss against control-arm jitter (11 rounds: min 1.2297 with
per-round same-binary spread 0.0141; the era D1 eps was jitter, the loss real).
r5-base reads 1.202 (era read 1.211 — margin unchanged).

ASM: `kernel_batched<32>` census (423 `vmovapd` of 979) in
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-asm-census.txt`; renoise data
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-noise/rome-noise-3d_32.tsv`.

CLASS: REAL

SIMD: rolled body at N=32 — the 2N=64 register deficit again (2d_32 class).
BW: 2x 512 KiB streams L3 both — equal footing, not the lever.
CACHE: l1 miss parity vs fftw — not the lever.
TILING: axis0 col_dif Bt=340, axis1 col codelet Bt=32 (era analytic); adequate shapes.
REGS: the top register-pressure evidence on the host (the kb32 census above).
MATH: era fp_mac adm 0.44x of fftw (pin-era; COLFMA covers the col chain, not the row
kernel's rolled form).
OVERHEAD: below 1% record share — not the lever.
STABILITY: r5-base eps 0.0056 vs gap 0.202 (36 x eps); era renoise per-round floor 0.0141
(`/mnt/home/mbarbone/team-r5-shared/evidence/rome-noise/rome-noise-3d_32.tsv`).

WONTFIX: closed-campaign ruling carried with round-5 force-evidence: the W3 buffered-staging
arm (the misal-first cure class) regressed this cell +5.34% in sweep AND reroll (+5.3-5.4%,
beyond tol 0.02, sweep-consistent; `/mnt/home/mbarbone/team-r5-shared/evidence/w3-reroll-rome.md`)
while its static alignment census proved the arm executed — the misal share is not the cell's
lever. The remaining gap needs the deferred A2/B1-B2 data-path work (new engine shape; the
COLFMA-era residual after the fixed col math), cost = new kernel class, ceiling unbounded-by-
construction arms tried (all measured flat-to-worse).

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/rome-counters.md`,
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-asm-census.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-noise/rome-noise-3d_32.tsv`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w3-reroll-rome.md`

## rome 3d_128

MECHANISM: The col axes cost more than the rows: era record col_dif family 51.2% vs row
chain 37.6%; counters: cycles 1.131 == era wall shape, instr 1.032x (PARITY — the gap was
never issue count), l1_ldmiss 1.52x, ls_misal 4.13e6 vs fftw ~0, and the era naming split
fp_mac 0.19x of fftw (the pin-era col stream; COLFMA's piece_fma shipped in-window and
narrowed that math statement — r5-base reads 1.152 vs era 1.205).

ASM: col-pass census rows (`dif_col_pass<8>` 565 insns, 242 stack; `pass_last<8>` 696 insns,
335 mem) in `/mnt/home/mbarbone/team-r5-shared/evidence/rome-asm-census.txt`; FFTW plan
(vrank rank2 + dft-buffered-128 + rank0 copies) in
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-routes/rome-fftwplan-3d_128.log`.

CLASS: REAL

SIMD: 256-bit; the era FMA-free col stream was the top SIMD lever — RESTORED in-window by
COLFMA; residual SIMD content is plane-shuffling at W=4.
BW: 2x 32 MiB DRAM streams both; fftw's plan-copies pay the same class.
CACHE: 555 MiB L1 refill per transform vs 64 MiB arrays (~8.7x reuse deficit vs the plane
route) at Bt=128 — the stream-through class.
TILING: fused planes on; both col axes Bt=128 (row-run floor fires, 32 MiB > 16 MiB L3).
REGS: col passes 242 stack/565 — present, subordinate.
MATH: era fp_mac 0.19x; post-COLFMA the counted mac content moved; the banked closed number
is stale by construction (COLDIF-A1/COLFMA window).
OVERHEAD: brmiss 2333 admiral vs 18807 fftw — admiral is the branch-lean side; not the lever.
STABILITY: r5-base eps 0.04996 vs gap 0.152 (3.0 x eps); the W3-era same-binary floor on
this cell read 0.0008 (on2/on; `/mnt/home/mbarbone/team-r5-shared/evidence/w3-rome-reduce.md`).

WONTFIX: carried with round-5 force-evidence: W3's buffered staging read +5.84%/+6.23%
(min/med) in the reroll — REAL-REGRESSION beyond tol, sweep-consistent
(`/mnt/home/mbarbone/team-r5-shared/evidence/w3-reroll-rome.md`; branch NO-MERGE per
r5-state) — the misal-first arm is refuted as the fix direction for the residual, and
W1's staged pass_first did not reach this host's chain shape (sweep collateral
`/mnt/home/mbarbone/team-r5-shared/evidence/w1-rome-reduce.md`). Residual = post-COLFMA
col-chain data path, deferred (same class as 3d_32's ruling).

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/rome-counters.md`,
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-asm-census.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/rome-record/rome-3d_128.report.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w3-reroll-rome.md`

## rome summary

10 cells: 9 REAL, 1 NOISE (2d_1024 — the era regression was a route flip, restored under
the shipped 2W gate; the remaining 1.1% sits inside the documented ~9% era band and reship
reads TIE). CLOSED-CLASS BY W1/W2: none on rome for W1 (ice/genoa-owned), W2 closed the 3d_4/
3d_8 row halves (−3.8/−3.1% reroll-confirmed; the col-family residuals stay on the books).
A3-ruled WONTFIX at 2d_32 (ceiling 1.30 vs fftw at the best measurable arm); deferred-class
WONTFIX at 3d_32/3d_128 (both cure-direction arms refuted in sweep+reroll). The era-archived
caveats: fp_mac/FMA-freeness numbers are the pin era's (COLFMA shipped in-window); absolute
D1-era wall ratios at the fftw-led small cells read high vs r5-base (TINY/ARMFLEX window)
— every verdict was re-confirmed against the r5-base tables' eps.

# genoa diagnosis — fft_bench N-D LOSS cells, round-5 baseline (admiral @ 017e132, 2026-09-08)

Host: AMD EPYC 9474F (Zen4, v4 AVX-512 double-pumped, W=8 f64; L1d 32K, L2 1 MiB, L3 32 MiB/6 cores).
7 LOSS cells, leader fftw x7 (standings/genoa-base.md). Era attribution is counter/record-backed
from the closed campaign (fp_ret_sse_avx_ops counts per-LANE flops; zmm double-pump ratio 1.70
measured); the provenance receipt ties that era's binary to the staged production artifact
(`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-provenance.txt`). Round-5 dispositions marked
per cell; the r5base nm census
(`/mnt/home/mbarbone/team-r5-shared/evidence/census-genoa-r5base.txt`) confirms the era
instantiation families ship in the r5-base binary unchanged in class.
FFTW side note retained: FFTW_MEASURE re-rolls plans per process (3d_256-class spans 1.36x
min/max) — fftw-arm counter ratios live inside a +-0.15 mode band there
(`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-noise2.tsv`)

## genoa 2d_16

MECHANISM: Row-batched tiny family, throughput-bound not instruction-bound: 0.85x fftw's
instructions yet 1.72x its cycles (IPC 2.22 vs 4.50) — zmm double-pump tax on top of the
`flat_leaf`-saturated 2N=32 register file: `kernel_batched<16>` spills whole ZMMs (33 stores
+ 40 reloads/call) and the split gather runs its shuffle stream through the stack. Era wall
1.842; r5-base 1.599 at eps 1.9e-04.

ASM: `codelet_many_static<16u,double,true>` = 193 shuffles + 36 mul + 194 scalar of 535 insns;
`kernel_batched<16>` spill stream per
`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-asm-codelet_many_static_16u__double__true_.asm`
+ the kb16 clone census
(`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-asm-kernel_batched_16u__double__true__xsimd__batch_double__xsimd__avx512vnni.asm`).

CLASS: REAL

WONTFIX: W=8-f64 excluded at W2 ship
(`/mnt/home/mbarbone/team-r5-shared/evidence/w2-report.md`); SPR-measured 0.862 headroom
arm ⇒ 1.59→1.37 LOSS

SIMD: zmm-heavy (62% of many_static<16>) vs fftw's 256-bit codelets; counted flops +35%
(7970 vs 5890 — the split re/im + scale multiplies); double-pump makes the width non-free.
BW: not the lever — 4 KiB L1-resident: 2.54 L1 misses/xform.
CACHE: not binding — loads/misses ~850:1.
TILING: single tile by construction.
REGS: THE lever with shuffles — the 33/40 ZMM spill stream; flat_leaf saturates at 2N=32
with no twiddle headroom (the SPR-measured 0.862 headroom arm confirms the class).
MATH: counted FP +35%; FP ~1/3 of pipe demand at these IPCs — secondary.
OVERHEAD: execute_nd+dispatch 8.3% — plumbing is not the story.
STABILITY: r5-base eps 1.853e-04 vs gap 0.599 (3.2k x eps); most reproducible loss on the host;
W1/W2/W3 sweeps collateral-flat (0.9971 / 1.0015 / 0.9979). Round-5 disposition: OPEN
(W2 excludes W=8 f64 tiny at ship).

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/genoa-counters-reduced.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-asm-codelet_many_static_16u__double__true_.asm`,
`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-hotmerge-all.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/census-genoa-r5base.txt`

## genoa 2d_32

MECHANISM: Same family one size up: split-gather `codelet_many_static<32>` (the
kManyXpose gate needs 2W*ceil(N/W)=64 > 32 registers at W=8 — the fused body is never
compiled at N=32): 513 shuffles + 177 stack memops of 991 insns; +`kernel_batched<32>`
recursion; cycles 1.52x at 0.76x instructions (IPC 2.14 vs 4.31). Era wall 1.609; r5-base
1.305.

ASM: `/mnt/home/mbarbone/team-r5-shared/evidence/genoa-asm-codelet_many_static_32u__double__true_.asm`
(the 513-shuffle split gather is what ships); shares in
`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-hotmerge-all.txt`.

CLASS: REAL

WONTFIX: split gather never compiled at W=8 (kManyXpose 64>32; census
`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-asm-codelet_many_static_32u__double__true_.asm`);
class ceiling ⇒ 1.31→~1.05 LOSS

SIMD: 87% zmm in many_static<32>; flops +25%; the throughput deficit is shuffle+store pipes.
BW: not the lever: 16 KiB; L1 misses 867 vs 212 (4.1x but 9.3% of loads — secondary).
CACHE: L2 misses == L1 misses (every L1 miss walks through) — spill-scratch class.
TILING: one 32-row block + col codelet single tile
(`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-route.txt`).
REGS: the split-gather frame's 177 stack refs + kb32 recursion-through-memory — the
register-file overflow signature.
MATH: +25% counted flops (scale + re/im split); butterfly arithmetic clean.
OVERHEAD: execute_nd 2.4% — not the story.
STABILITY: r5-base eps 0.0015 vs gap 0.305 (200 x eps); sweeps collateral-flat
(0.9988 / 1.0023 / 1.0016). OPEN — no shipped wave admits the N=32 W=8 row kernel.

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/genoa-counters-reduced.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-asm-codelet_many_static_32u__double__true_.asm`,
`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-hotmerge-all.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/census-genoa-r5base.txt`

## genoa 2d_64

MECHANISM: The len<=32 batch gate class at its weakest: pass A runs 64 per-row
`codelet_apply<64>` calls = 41.4% of the cell; cycles 31300 at IPC 1.83 with ex_ret_ops
expansion 1.15 (multi-uop zmm). Era wall 1.078 at eps 6.2e-05 — the tightest stable verdict
of the era table; r5-base 1.09 at eps 2.9e-04.

ASM: `codelet_apply<64u,double,true>` census (375 insns, 82 shuffles, 60 stack):
`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-asm-codelet_apply_64u__double__true_.asm`;
shares `/mnt/home/mbarbone/team-r5-shared/evidence/genoa-perf-2d_64.report.txt`.

CLASS: REAL

SIMD: 98% zmm at double-pump cost; per-row route blocks row batching of the 64-point kernel.
BW: not the lever: 65 KiB; L1 misses 6563 = 1.6/row-pass line — powder.
CACHE: L2 events == L1 misses — handoff scratch/RFO, small.
TILING: rows per-line (gate at len<=32), col col_codelet<64> Bt 64 one tile
(`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-route.txt`).
REGS: moderate 60-stack frame — NOT dominant here (unlike kb16).
MATH: flops 2.04e5 = the 5N log2 N level; nothing numeric.
OVERHEAD: THE lever — 41.4% per-row per-line invocation; same-length batched-vs-per-row
priced at the same order on SPR in the era.
STABILITY: r5-base eps 2.942e-04 vs gap 0.09 (300 x eps); sweeps collateral-flat
(1.0115 / 1.0044 / 1.0003).

WONTFIX: era ruling carried — the batch-gate ADMIT candidate was measured and REJECTED
(targets lose on 2/3 hosts; closed campaign); no further candidate this campaign; bound =
the 41.4% share is dispatch/invocation, and killing the whole per-line loop only bounds the
cell at ~0.586 of today's admiral time (1.09 -> ~0.64 class ceiling IF the batched engine
admitted len 64 at zero cost; it does not admit it cheaply anywhere measured).

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/genoa-counters-reduced.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-asm-codelet_apply_64u__double__true_.asm`,
`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-perf-2d_64.report.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-route.txt`

## genoa 3d_4

MECHANISM: Instruction-count-bound dispatch on a 64-point transform: 2.16x fftw's
instructions, 2.08x uops, cycles 866 vs 349 (era wall 2.481; r5-base 2.169). Per-line
N=4 scalar core (the era many-body exclusion) + per-axis plumbing ~40% of samples:
execute_nd 18.2% + nd_apply_axis 14.1% + dispatch/table builders ~8% vs the kernel at 18.7%.

ASM: `codelet_apply<4u,double,true>` = 48 insns (xmm scalar butterfly + interleaved store):
`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-asm-codelet_apply_4u__double__true_.asm`;
shares `/mnt/home/mbarbone/team-r5-shared/evidence/genoa-perf-3d_4.report.txt`; FFTW plan
(n2fv_4_sse2 + n1fv_4_avx batched 16 rows wide):
`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-fftw-plans.txt`.

CLASS: REAL

WONTFIX: W2 prototype draw 0.9914
(`/mnt/home/mbarbone/team-r5-shared/evidence/w2-reroll-genoa.md`), whitelist excludes;
plumbing >40% ⇒ free-row ceiling ~1.8 of 2.20 LOSS

SIMD: 4%-zmm scalar code vs fftw's ymm-batched rows — admiral pays the scalar line AND the
lost row batching.
BW: not the lever: 1 KiB; 0.09 L1 misses.
CACHE: glue loads (dispatch/state), not data.
TILING: batched wrapper around a scalar core; 2 col_dif fused radix-4 axes (Bt 4/16).
REGS: 0 stack refs in the kernel — pressure irrelevant at N=4.
MATH: counted flops +48% (per-line scale_inplace second pass).
OVERHEAD: THE lever with the N=4 exclusion — >40% plumbing on a 349-cycle competitor.
STABILITY: r5-base eps 6.365e-04 vs gap 1.169 (1.8k x eps; tightest-margin verdicts on the
host, stable across eras). Round-5 disposition: OPEN — the W2 prototype read this host's arm effect as a draw
(on/off 0.9914 within tol; `/mnt/home/mbarbone/team-r5-shared/evidence/w2-reroll-genoa.md`)
and the shipped arm excludes W=8 f64
(`/mnt/home/mbarbone/team-r5-shared/evidence/w2-report.md`); mechanism intact at master.

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/genoa-counters-reduced.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-asm-codelet_apply_4u__double__true_.asm`,
`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-perf-3d_4.report.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w2-reroll-genoa.md`

## genoa 3d_8

MECHANISM: The COLUMN codelet owns it: `col_codelet_body<8>` = 57.4% of samples — the
dir-swap plane round-trip (64 memops of plane-array traffic per W columns against 32 real)
plus a ~24-insn row-base prologue paid at ONE iteration per call (8^3 col loop); cycles
3690 vs 2340 (1.58x) at 0.73x the instructions. Era wall 1.779; r5-base 1.401.

ASM: `/mnt/home/mbarbone/team-r5-shared/evidence/genoa-asm-col_codelet_body_8u__double_.asm`
(2185 B, 68 ld / 38 st, 128 scalar-ops, 38 stack refs in 353 insns); hottest lines
`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-hotmerge-all.txt`.

CLASS: REAL

SIMD: both kernels W=8 zmm; fftw batches 64 rows in ymm — row shapes comparable, the col
body is not; counted flops +40%.
BW: not the lever: 8 KiB; 4.19 L1 misses.
CACHE: the stack round trip replaces data loads (L1 loads 4020 vs 5040) — not capacity.
TILING: axis0 col_codelet Bt 64 / axis1 Bt 8 — one iteration per call is the named pathology
(`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-route.txt`).
REGS: dir-swap runtime pointer selection keeps plane arrays in memory — the 64-memop round
trip; the arm2 conjugated-gather class targets exactly this.
MATH: +40% counted flops (dir-swap conjugation + scale) — second order.
OVERHEAD: execute_nd 7.2%; the per-call prologue is the bulk.
STABILITY: r5-base eps 1.237e-04 vs gap 0.401 (3.2k x eps; margin stable across eras).
Round-5 disposition: OPEN with a decisive refute on record — the W2 prototype arm READ this shape
+3.1% REAL-REGRESSION (reroll 1.0312 beyond tol, sweep-consistent;
`/mnt/home/mbarbone/team-r5-shared/evidence/w2-reroll-genoa.md`; the v4-N8-f64 shape won
−3.3% on icelake and lost here — geometry-inexpressible contrast per r5-state) and the
shipped arm was narrowed OFF W=8 f64; master text unchanged.

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/genoa-counters-reduced.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-asm-col_codelet_body_8u__double_.asm`,
`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-hotmerge-all.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w2-reroll-genoa.md`

## genoa 3d_16

MECHANISM: Mixed family at L2-resident size (64 KiB): row-batch tiny block
(kernel_batched<16> 32.3% + many_static<16> 19.3% + col body 14.8%) + axis-0 col_dif
{dif_col_pass_last<8> 19.6% + first<2> 9.6%}; cycles 1.11x at 0.67x instructions (IPC 2.0
vs 3.36). Era wall 1.162 at 39x era eps; r5-base 1.046 at eps 0.0072 (6.4x eps).

ASM: census rows per 2d_16 (`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-asm-census.txt`
kernel_batched<16> spill stream, many_static<16> shuffles); shares
`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-hotmerge-all.txt`.

CLASS: REAL

SIMD: counted flops +35% vs fftw; zmm everywhere at 2.0 IPC — the shuffle+spill profile.
BW: nothing — 64 KiB, equal misses both arms (8450 vs 8650).
CACHE: L1/L2 loads a wash — not memory.
TILING: axis0 col_dif Bt 256 single tile radices {2,8}; fftw buffered-x256 iter-ci cols
(`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-route.txt` vs
`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-fftw-plans.txt`); compute-limited both.
REGS: kernel_batched<16> spill stream again — flat_leaf saturation.
MATH: +35% counted — bounded contribution.
OVERHEAD: execute_nd 0.68% — the col-share split is where the cycles go.
STABILITY: r5-base gap 0.046 vs eps 0.007163 (6.4 x eps); sweeps collateral-flat
(0.9876 / 1.0047 / 0.9987); reship-era 1.039 == base magnitude.

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/genoa-counters-reduced.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-asm-census.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-hotmerge-all.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/census-genoa-r5base.txt`

## genoa 3d_512

MECHANISM: col_pass memory class at 4 GiB working set: 51 GB through L2 per transform vs
fftw's 42 GB (l2 misses 1.21x) at IPC 0.64 — latency-bound strided columns; Bt=128 is the
2048 B row floor FIRING at genoa geometry (scratch 2 MiB = 2x L2): the floor's premise was
fitted on SPR (2 MiB L2/45 MiB L3); at genoa's 1 MiB L2 the doubled tile's column window no
longer crosses L2 cleanly. fftw's x64-buffered + rank0-copy shape sits in the same L2 with
better overlap. Era wall 1.437; r5-base 1.39 (era-consistent).

ASM: hot lines (strided `vmovupd 0x40(%r12,%rdx,1)` load 7.0%, boundary strided STORE 9.8%)
in `/mnt/home/mbarbone/team-r5-shared/evidence/genoa-annotate-3d_512.txt` +
`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-perf-3d_512.report.txt`.

CLASS: REAL

SIMD: not the lever — double-pumped zmm at IPC 0.64 is idle pipe time; flops +10%.
BW: lever with CACHE — 51 vs 42 GB past L2; the stream is latency-bound (0.114 l2
misses/cycle).
CACHE: L1 misses 1.18x, L2 1.21x; tile footprint per axis ~8 MiB vs 1 MiB L2.
TILING: the lever's address — Bt=128 via the floor + axis0 tiles 2048 at 4 MiB stride; the
floor re-derivation at genoa geometry is the known lead.
REGS: not in the hot lines (folded stack reloads 1.7% at most).
MATH: +10% counted, fma everywhere — clean.
OVERHEAD: plan-machinery ~1-3% — subordinate at 3e8-cycle transforms.
STABILITY: r5-base eps 1.605e-04 vs gap 0.39 (2.4k x eps); fftw-plan lottery width bounded
by the 3d_256-class 1.36 max/min (`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-noise2.tsv`).

Round-5 disposition: CLOSED-CLASS BY W1 (1756115, owned cls512): sweep on/off 0.9700, same
-binary on2/on 1.0018 (`/mnt/home/mbarbone/team-r5-shared/evidence/w1-genoa-reduce.md`);
reship-era 1.282 (improved from 1.39; `/mnt/home/mbarbone/team-r5-shared/evidence/reship-genoa.md`).
The residual is the tile-floor geometry lead above — a separate lane; W3's buffered arm read
PARITY 0.9978 here (`/mnt/home/mbarbone/team-r5-shared/evidence/w3-genoa-reduce.md`).

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/genoa-counters-reduced.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-annotate-3d_512.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/w1-genoa-reduce.md`,
`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-noise2.tsv`

## genoa 2d_256

Not an r5-base LOSS (base TIE-band vs fftw). Section carried for the lottery adjudication
(d3-side): the W1 sweep's owned-cls256 read on/off 1.1022 (UNRESOLVED +WATCH);

LOTTERY: era-draw class for the W1-arm reading at this cell — the 15-round reroll read
on/off 0.9409/0.9336 with same-binary eps 0.0078 (INCONSISTENT-DIRECTION vs the sweep's
+0.1022; `/mnt/home/mbarbone/team-r5-shared/evidence/w1-reroll-genoa.md`), the host's
same-binary intra-job swings document 12-18% at 2d_256-class (r5-state machinery finding),
and the reship-era table reads WIN 0.7538
(`/mnt/home/mbarbone/team-r5-shared/evidence/reship-genoa.md`). No code defect is claimed
for this cell; the sweep's +10% read was the weather half of the draw.

CLASS: NOISE

SIMD: W=8 zmm col class as at cls256 above; width not the question at a +10%-read draw.
BW: 2 MiB arrays L2-crossover class; both arms shared in the sweep/reroll sessions.
CACHE: the sweep's +10% read carried no cache-event separation evidence (wall-only sweep,
perf refused); nothing to claim.
TILING: col_dif cls256 shape per `/mnt/home/mbarbone/team-r5-shared/evidence/genoa-route.txt`;
identical routes across the reroll arms by construction (same source, gate-only arm).
REGS: no register evidence at this cell; none claimed at the lottery scale.
MATH: fp volume conserved per the reroll design (gate-only arm, same kernels).
OVERHEAD: no admissible overhead evidence at the +10% scale; the reroll's eps 0.0078 swallows
the sweep read.
STABILITY: THE cell's content — same-binary intra-job swings 12-18% documented at this class
(r5-state machinery finding), reroll on2/on 0.0078, reship WIN 0.7538: the +10.2% sweep read
is weather, reproducibly refuted.

MECHANISM: none attributable to code — the sweep's +10.2% W1 read at this cell is the
documented genoa same-binary swing class (see LOTTERY); the underlying col-pass engine
content matches the 3d_512 family's cls256 form and carries no standing defect claim here.

ASM: no per-cell asm evidence is claimed for the draw; the engine census rows live in
`/mnt/home/mbarbone/team-r5-shared/evidence/genoa-asm-census.txt`.

## genoa summary

7 base losses, all REAL: tiny family OPEN (2d_16/2d_32/3d_4/3d_8/3d_16 — prototype evidence
banked, shipped arm off W=8 f64 by adjudication); 2d_64 WONTFIX (admit candidate rejected);
3d_512 CLOSED-CLASS BY W1 (0.9700 sweep) with the genoa-geometry tile-floor re-derivation
as the banked residual lead. Watch-cell 2d_256's W1 sweep read is the host lottery floor's
work (LOTTERY, reship WIN 0.7538) — no regression.

## genoa 2d_1024

MECHANISM: not an engine finding — the plan-race band. effort::measure provably races at
this geometry on genoa: the reship-era same-binary spread is 10.7%, the W1/W2 waves both
recorded CONTROL-MOVEs of this class (on2/on 0.9773/0.9710), and 12-18% same-binary draws
are documented for this node-day family. The table's verdict holds TIE through it all.

ASM: no instruction-level attribution belongs to a lottery cell; the census shows the
r5base and reship binaries' kernels class-identical
(`/mnt/home/mbarbone/team-r5-shared/evidence/census-genoa-r5base.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/census-genoa-r5reship.txt`).

CLASS: REAL
LOTTERY: d3's in-session flag (reship/yesterday 1.1408 > floor 1.1067) rerun pairwise,
15-round fixed-rep interleaved on the staged binaries: reship/yesterday min 0.9770,
median 1.0049 (eps 0.0060) — the claimed regression dissolves inside the documented draw
band; receipts in
`/mnt/home/mbarbone/team-r5-shared/evidence/d3-reroll-genoa.md`.

SIMD: neutral (census class identity between eras).
BW: DRAM-class cell; weather enters via the leader's day — measured in-session pair used.
CACHE: route split between tiles/race outcomes; not separately instrumented — the lottery
band is the attribution.
TILING: plans race; see MECHANISM.
REGS: neutral.
MATH: neutral.
OVERHEAD: effort::measure race is the named overhead class at this size on this host.
STABILITY: the cell's trait, documented above with receipts (reroll md carries the
numbers).

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/d3-reroll-genoa.md`

## genoa 3d_64

MECHANISM: verdict holds WIN (0.799) — the d3 in-session flag (1.0672 > 1.0300 floor)
came from a cell whose same-binary draws hit 1.0433/1.0487 across the W1/W2 sweeps while
W5's controls stayed OK: era-band motion, not code delta. No W1/W2/W5 geometry admits
len-64 chains here.

ASM: census class-identity across the binaries (same two census files as the 2d_1024
section above).

CLASS: REAL
LOTTERY: pairwise 15-round fixed-rep rerun on staged binaries: reship/yesterday min
1.0016, median 1.0028 (eps 0.0009) — inside every floor; receipt
`/mnt/home/mbarbone/team-r5-shared/evidence/d3-reroll-genoa.md`.

SIMD: neutral (class identity).
BW: not the lever at this size.
CACHE: L3-class borderline cell; day-to-day placement shifts within it are the noise.
TILING: no shipped change touches this shape.
REGS: neutral.
MATH: neutral.
OVERHEAD: subordinate.
STABILITY: the documented draw band (1.0433/1.0487 prior sweeps) plus the reroll receipt.

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/d3-reroll-genoa.md`

# ccmlin075 diagnosis — fft_bench N-D LOSS cells, round-5 baseline (admiral @ 017e132, 2026-09-08)

Host: Xeon w5-3435X (Sapphire Rapids 1S 16C, v4 AVX-512, W=8 f64; L1d 48K, L2 2 MiB,
L3 45 MiB shared by 32 read-cores; `e2_len_cap=32`). 11 LOSS cells, leader mkl x10, fftw
x1 (2d_8192; standings/ccmlin075-base.md). All mechanism attribution below is THIS
host's round-5 evidence, no era-archived columns: static asm census of the sha-asserted
staged r5base binary (`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-asm-census.txt`),
route trace recomputed at the base ref + debug=2 cross-check
(`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-route-trace-r5base.txt`; geometry
line `W=8 l2=2MiB e2_len_cap=32` printed by the trace itself), perf-record hot shares of
the staged binary (`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-perf-shares.txt`),
and a 9-round same-binary-controlled re-run of the staged binaries
(`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-r5reroll.md` with
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-r5reroll.tsv`). Where a claim leans
on the closed campaign's OTHER-host attributions (icelake, same v4/W=8 class) it says so
explicitly. D1 per-arm max/min spreads (bench re-plans each round) sit at 1.07-1.52 across
the loss cells in `/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-r5base-measure.tsv`;
the reroll separates same-binary eps from that plan-draw width.

## ccmlin075 2d_16

MECHANISM: Row-batched N=16 codelet family on the staged binary: `codelet_many_static<16>`
40.6% + `col_codelet_body<16>` 20.1% + `kernel_batched<16>::apply` 16.6% of exec samples
(+ execute_nd 8.5% + nd_apply_axis 6.6% = 15.1% N-D plumbing;
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-perf-shares.txt`). NOTE vs the closed
icelake attribution: at r5-base the SPR N=16 gather is the FUSED form (kManyXpose admits
2W*ceil(16/8)=32 <= 32 at W=8) — census `codelet_many_static<16>` = 645 insns, 106 shuf,
27 stack, 40 FMA; the register-deficit `kernel_batched<16>` spill stream (73 stack refs of
361 insns) is the live residue, plus the col codelet axis.

ASM: `/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-asm-census.txt` rows
`codelet_many_static<16>` (645/106/27), `kernel_batched<16>::apply` (361 insns, 73 stack),
`col_codelet_body<16>` (381 insns, 115 stack — per-call plane round trip).

CLASS: REAL

SIMD: zmm work: ms16 442 zmm-insns of 645; the col body runs 201 zmm with ZERO FMA (32 fp,
0 fma) — the width is used; the col codelet's math is mul/add-form
(`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-asm-census.txt`).
BW: not the lever — 4 KiB/array, nowhere to miss.
CACHE: not the lever at this size class (L1-resident; no cache event separation claimed).
TILING: rows batched codelet (gate len<=32), col col_codelet Bt=16 single tile
(`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-route-trace-r5base.txt`); MKL runs
flat interleaved batch kernels (era class).
REGS: the lever — `kernel_batched<16>` 73 stack refs (2N=32 == zmm file) + col body's 115.
MATH: fp parity not measured on this host (wall-only permit); FMA-free col body noted above.
OVERHEAD: 15.1% N-D plumbing in the record at gap 0.61 — a named share, subordinate to the
kernel bodies.
STABILITY: base eps 0.0189 vs gap 0.607 (32 x eps); reroll same-binary control |1 − 0.9996|
= 4e-4 with adm/best 1.594 today (base 1.607, reship 1.628 —
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-r5reroll.md`,
`/mnt/home/mbarbone/team-r5-shared/evidence/reship-ccmlin075.md`).

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-perf-shares.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-asm-census.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-route-trace-r5base.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-r5reroll.md`

## ccmlin075 2d_32

MECHANISM: N=32 row codelet PAST the fused-gather gate (2W*ceil = 64 > 32 regs): the split
gather runs `codelet_many_static<32>` 45.8% + `col_codelet_body<32>` 29.1% of samples.
Census: ms32 = 1217 insns, 242 shuffles, 28 stack; col body = 581 insns, 199 stack, 0 FMA —
the register-bound data movement class at both axes.

ASM: `/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-asm-census.txt` rows
`codelet_many_static<32>` (1217/242sh) and `col_codelet_body<32>` (581/199st/0fma).

CLASS: REAL

WONTFIX: register-bound both axes (ms32 45.8% + col 29.1%,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-perf-shares.txt`); rome K=16
row-arm class (`/mnt/home/mbarbone/team-r5-shared/evidence/w5-report.md` A2) ⇒
1.34×(1−0.458×0.39)≈1.10 LOSS

SIMD: ms32 = 1066 zmm-insns/1217 with 608 fp and 112 FMA (fma present in the gather body);
the deficit is the 242-shuffle split form — width used, form expensive.
BW: not the lever — 16 KiB/array.
CACHE: not the lever (L1-resident class).
TILING: rows batched codelet; col col_codelet Bt=32 one tile radices 4,8
(`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-route-trace-r5base.txt`).
REGS: share — col body 199 stack refs of 581 (34%); ms32 spill-light at 28 but shuffle-bound.
MATH: butterfly radix_8 batched lambdas stand at 16.8% of samples (4 clones);
FMA present — not a fp-mac deficit.
OVERHEAD: execute_nd + apply_axis = 3.6% — small.
STABILITY: base eps 0.0027 vs gap 0.350 (130 x eps); reroll control 0.0019 with adm/best
1.356 (base 1.350):
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-r5reroll.md`.

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-perf-shares.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-asm-census.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-route-trace-r5base.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-r5reroll.md`

## ccmlin075 2d_64

MECHANISM: First cell past the len<=32 batch gate: rows run 64 per-line
`codelet_apply<64>` dispatches (33.9% of samples) while the col axis runs strided col_dif
`dif_col_pass_first<8>` 25.3% + `dif_col_pass_last<8>` 18.6% at 1 KiB stride. MKL beats
both (today's adm/mkl 1.550). Per-line row invocation + boundary-pass striding — the
same class the closed icelake campaign counter-attributed at 2.45x instructions (wall-only
ratio here).

ASM: `/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-asm-census.txt`:
`codelet_apply<64,d>` = 318 insns, 82 shuf, 63 stack (98% zmm); `dif_col_pass_first<d,t,8>`
= 510 insns, 168 stack vs 92 fp — index/stack heavy col opener.

CLASS: REAL

WONTFIX: W1 gate len≥128 unreachable (e2 cap 32, axes 64 —
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-route-trace-r5base.txt`); deferred
batched-column E2 lane (ice 2d_64 carried bound: ceiling 1.1-1.5x-by-class, cost = new
engine)

SIMD: zmm on both families (apply64 301/318 zmm) — width fine; col-first form pays stack.
BW: not the lever — 128 KiB arrays, L2-resident.
CACHE: L2-resident both arms; the col chain reads strided first elements per column (era
class effect), no cache separation claimed at wall-only resolution.
TILING: rows per-line (gate), col col_dif Bt=64 tiles=1 radices 8,8
(`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-route-trace-r5base.txt`). NOTE e2
cap here is 32: len-64 cols route col_dif, NOT the col codelet (closed-era rome difference).
REGS: col-first 168 stack refs/510 — a real share; rows' 63/318 smaller.
MATH: census fma: first<8> 14 of 92 fp — col butterfly contraction partial;
`dif_tape_step_first` family fma 506/1166 fp.
OVERHEAD: 64 per-line executes visible in the record (`plan_impl::execute` 3.4%);
subordinate to kernel bodies.
STABILITY: base eps 0.0136 vs gap 0.490 (36 x eps); reroll control 1.0249 (one slow draw)
with adm/best 1.550 vs base 1.490 — stable class, both arms re-measured today
(`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-r5reroll.md`).

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-perf-shares.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-asm-census.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-route-trace-r5base.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-r5reroll.md`

## ccmlin075 2d_128

MECHANISM: Strided col_dif boundary at 2 KiB column stride: `dif_col_pass_first<16>`
30.5% + `dif_col_pass_last<8>` 17.3% + rows` `dif_pass_last<16>` 21.5% of samples. The
col-first clone is the heavy station: census 1077 insns with 405 stack refs and 309 scalar
mov against 259 fp, 30 FMA — index/scratch-bound strided boundary form.

ASM: `/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-asm-census.txt`
`dif_col_pass_first<d,t,16>` (6632B, 405 stack, 309 mov, fma 30/259).

CLASS: REAL

WONTFIX: W1 shipped and won ice −6.7% same class (0.9331) but SPR flat twice (reship-era
1.468→1.466 eps 0.083 — `/mnt/home/mbarbone/team-r5-shared/evidence/reship-ccmlin075.md`;
in-session 1.0066); even FULL transfer ⇒ 1.48→1.38 LOSS; residual = col-first 405-stack
form (`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-asm-census.txt`) + E2 lane

SIMD: 512b everywhere (col-first 474 zmm); FMA share 30/259 fp in the boundary pass — the
mul/add-split form charges the FP pipes there.
BW: not the lever — 512 KiB L2-resident.
CACHE: strided first-touches per column at 2 KiB stride (set-conflict class on the
closed-campaign counter hosts); wall-only here — the smoke is the 405-ref stack frame
instead.
TILING: rows iterative_dif len 128; col col_dif Bt=128 tiles=1 radices 16,8
(`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-route-trace-r5base.txt`).
REGS: 405/1077 stack in the col-first clone — a named lever share.
MATH: boundary FMA partial (above); row passes carry dif_pass_last<16> fma 48/438.
OVERHEAD: iterative_dif dispatch ~3.2%; subordinate.
STABILITY: base eps 0.0079 vs gap 0.468 (59 x eps); reroll control 0.0035 at adm/best
1.422 today (base 1.468): `/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-r5reroll.md`.
Round-5 disposition note: W1 merged (1756115) ships the staged `pass_first` for this class
(gate kColdifFirstMinLen=128 admits len 128) and won the SAME cells on icelake (on/off
0.9331); the SPR day reads read flat (base 1.468, reship 1.466 at eps 0.083 —
`/mnt/home/mbarbone/team-r5-shared/evidence/reship-ccmlin075.md`): the shipped arm's win
did not transfer at this geometry/session class, mechanism unretired.

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-perf-shares.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-asm-census.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-r5reroll.md`,
`/mnt/home/mbarbone/team-r5-shared/evidence/reship-ccmlin075.md`

## ccmlin075 2d_256

MECHANISM: Boundary-pass class past the L2 edge (2 MiB arrays): col_dif
`dif_col_pass_last<16>` 27.1% + `dif_col_pass_first<16>` 25.9% + `dif_tape_step_first<8>`
23.4% + row `dif_pass_last<32>` 16.8% = ~93% of samples in boundary stations at 4 KiB
stride. Census: col-last<16> = 1644 insns, 251 shuf, 87 stack, 0 FMA (231 fp); col-last<32>
= 1920 insns, 965 stack — the realigned-frame spill form (a `%rsp` grep reads false zero).

ASM: `/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-asm-census.txt`
`dif_col_pass_last<d,f,16>` (9260B) + `dif_col_pass_last<d,f,32>` (14208B, 965 stack refs).

CLASS: REAL

SIMD: zmm-heavy boundary clones; FMA 0 in both col-last census rows — the split mul/add
form halves FP efficiency in exactly the hot stations.
BW: both arms L3/L2-crossover class at 2 MiB; not a DRAM story.
CACHE: the lever's class — 4 KiB-pitch strided column sweeps re-touch sets per pass;
bt=168 -> 2 tiles (last 88) per the route trace.
TILING: col_dif Bt=168, 2 tiles, radices 16,16
(`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-route-trace-r5base.txt`); rows
iterative_dif.
REGS: 965/1920 stack refs in the radix-32 col-last clone — the lever at asm level.
MATH: FMA-free col boundary math noted; row radix-32 fma 108/954.
OVERHEAD: dispatch+builder ~ 2% — subordinate.
STABILITY: base eps 0.0487 vs gap 0.180 (3.7 x eps); reroll adm/best 1.229 with control
1.0443 (one warm draw; same-binary min-pair) — the gap exceeds every same-binary bound on
the cell (base eps, reroll control): REAL with documented draw width
(`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-r5reroll.md`; D1-day arm spread in
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-r5base-measure.tsv`).

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-perf-shares.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-asm-census.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-route-trace-r5base.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-r5reroll.md`

## ccmlin075 2d_8192

MECHANISM: The route is transposed both endpoints and every vintage (rank-2 oop:
axis0 TRANSPOSED group=256, budget_block=5 < 2W=16; axis passes iterative_dif —
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-route-trace-r5base.txt`), and the
standing question is not the route but the flip: 0.812 WIN (2026-09-06) -> 1.098 LOSS
(r5-base 09-08) -> 1.120 same-day recheck -> 1.10..1.15 (bisect session 09-09, FIVE admiral
binaries across three vintages in [1.110, 1.151] in ONE session) -> reship-era 1.289 at
eps 0.151. The bisect ran the a8b4850..5d91cc2 window endpoints and an era matrix — no
merge owns it: the window START binary measures 1.098 today, master reads 1.068, and BOTH
admiral AND fftw moved between sessions (7.11e8 -> 8.1-8.4e8 ns admiral, 8.80e8 -> 7.30e8
fftw), which no code delta can do. Receipts:
`/mnt/home/mbarbone/team-r5-shared/evidence/spr-2d8192-bisect.md` +
`/mnt/home/mbarbone/team-r5-shared/evidence/spr-2d8192-bisect.tsv`.

ASM: the transposed mover is the all-scalar `apply_lines_strided_oop` lane lambda — 267
insns, ZERO zmm, 37 stack refs in this staged binary
(`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-asm-census.txt`), reproducing the
closed campaign's 268-insn scalar-mover attribution; W5's TILEMOVE prototype replaces the
mover and measures the same route class (staged OFF lambda 46.2% of wall -> 0.00%, tiled
mover 45.3%; `/mnt/home/mbarbone/team-r5-shared/evidence/w5-report.md` B3).

CLASS: NOISE

SIMD: the scalar mover is zero-512-bit (census above); the DIF passes on the strip are
vector-clean; the SIMD content does not decide the session flip (identical binaries flip).
BW: 2x 1 GiB DRAM crossing — the class where page-placement/THP weather lives; the bisect's
GHz fence is falsified as the mechanism (3.975 GHz today vs 3.35 on 09-08, ratios >= 1.11
both days).
CACHE: alias/pitch class documented closed-era; cannot explain BOTH arms moving.
TILING: transposed group 256, 32 groups both vintages — route identical across the window.
REGS: scalar loop; not the question.
MATH: fp volume conserved per the route identity (bisect route dumps identical text).
OVERHEAD: mover ~46-60% of wall on this route class (w5-report B1/B3) — the lever the W5
arm prices; it is NOT the flip source (OFF lambda share reproduces across vintages).
STABILITY: bistable at ~25% across sessions (09-08 after-arm spread max/min 1.64; same-day
control eps 0.0034-0.0746; recheck
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-recheck-2d8192.md` + reship-day
weather pin `/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-weather-2d8192.md`
(reship/fftw 1.2005, same-binary 0.0171)). Verdict of record: the 0.812 belonged to the
09-06 session's weather, not to any source line; the cell's ratios are N-class evidence
only when arms share a session.

W5 note: W5 TILEMOVE names this cell CLAIM-in-principle (transposed route class; flip needs
on/off <= 0.911, stretch per `/mnt/home/mbarbone/team-r5-shared/evidence/w5-report.md` B3
cell map) — a future W5-arm improvement does NOT contradict this NOISE class: the arm cuts
the mover on every day while the 0.812->1.1-1.29 range is weather between days.

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/spr-2d8192-bisect.md`,
`/mnt/home/mbarbone/team-r5-shared/evidence/spr-2d8192-bisect.tsv`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-recheck-2d8192.md`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-weather-2d8192.md`

## ccmlin075 3d_4

MECHANISM: xmm-class tiny cell dominated by N-D plumbing and the len-4 col DIF family:
nd_apply_axis 17.1% + apply_lines_strided 13.1% + execute_nd 11.7% + `dif_col_tail_fused<4>`
16.3% + `col_dif_execute_ws` 15.6% vs the row codelet `codelet_many_static<4>` at 10.6% —
on a 64-point transform where MKL spends 61 ns. Census `codelet_apply<4,d>` = 47 insns:
ZERO zmm, 18 shuf, 16 fp (scalar-form); the batched wrapper dispatches per line-group.

ASM: `/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-asm-census.txt`
`codelet_apply<4,d,true>` (47 insns, 0 zmm/16 ymm — sub-vector class).

CLASS: REAL

WONTFIX: ~42% plumbing share is the floor (free ms4 10.6% ⇒ ~2.4 of 2.73 LOSS;
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-perf-shares.txt`); v4-f64 prototype
failed census bar (+11% instr N4 —
`/mnt/home/mbarbone/team-r5-shared/evidence/w2-report.md` sec. 4)

SIMD: the lever — the cell's hot core never touches zmm; MKL's N=4 works 512-bit class
(closed-era fp512 contrast 144 vs 52).
BW: not the lever — 1 KiB.
CACHE: not the lever (nothing misses; glue-load class only).
TILING: rows batched many-dispatch; both col axes col_dif fused radix-4 (Bt 4/16)
(`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-route-trace-r5base.txt`).
REGS: no file pressure at xmm widths (0 stack in apply<4>).
MATH: trivial; the len-4 chain's twiddle setup rivals the transform.
OVERHEAD: THE mechanism with SIMD — ~42% of samples in axis plumbing + dispatch at gap 1.73.
STABILITY: base eps 0.0058 vs gap 1.729 (298 x eps); reroll control 0.0046 at adm/best
2.515 (base 2.729, reship 2.711):
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-r5reroll.md`. Round-5: W2's shipped
arm excludes W=8 f64 (and the v4-f64 prototype census read +11% instr there —
`/mnt/home/mbarbone/team-r5-shared/evidence/w2-report.md`); mechanism intact at master.

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-perf-shares.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-asm-census.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-route-trace-r5base.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-r5reroll.md`

## ccmlin075 3d_8

MECHANISM: Two-station tiny mix: `codelet_many_static<8>` 43.8% + `col_codelet_body<8>`
38.2% of samples. Census: ms8 = 414 insns/99 shuf/41 stack (212 zmm) — the W=8 gather;
col body<8> = 294 insns, 37 shuf, 41 stack, 16 FMA of 82 fp (191 zmm) — the per-call
prologue + plane round-trip paid once per 8-column unit (the route trace shows Bt=8 -> one
iteration per call on axis1).

ASM: `/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-asm-census.txt` rows
`codelet_many_static<8>` + `col_codelet_body<8>` (1736 B, 41 stack).

CLASS: REAL

SIMD: zmm both stations; col body runs FMA (16/82) unlike its len-16 sibling — math form
fine; the cost is per-call framing.
BW: not the lever — 8 KiB.
CACHE: not the lever (L1-resident class).
TILING: axis1 col_codelet Bt=8 (one iteration/call), axis0 Bt=64
(`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-route-trace-r5base.txt`).
REGS: col body 41 stack refs/294 — prologue class, present.
MATH: gather twiddle work is the movement, not extra FP.
OVERHEAD: plumbing 10.9% (apply_axis 4.6 + strided lambda 4.2 + execute_nd 3.1 + dispatch
2.2) — a named share at gap 0.93.
STABILITY: base eps 0.0210 vs gap 0.928 (44 x eps); reroll control |1-0.9672| = 3.3% (one
fast draw in after2) with adm/best 2.004 (base 1.928):
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-r5reroll.md`. Round-5: prototype arm
geometry-inexpressible at this host class (ice −3.3% vs genoa +3.1%; shipped arm excludes
W=8 f64): OPEN.

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-perf-shares.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-asm-census.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-route-trace-r5base.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-r5reroll.md`

## ccmlin075 3d_16

MECHANISM: Tiny+col mix: `codelet_many_static<16>` 25.9% + col axes
`dif_col_pass_last<8>` 19.7% + `dif_col_pass_first<2>` 18.8% + `col_codelet_body<16>`
16.4% + `kernel_batched<16>` 10.8% (the 73-stack spill stream) = ~92%. The axis-0 chain
opens at radix-2, stride 4 KiB.

ASM: `/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-asm-census.txt`
(kernel_batched<16> 73 stack; col_codelet_body<16> 115 stack; dif_col_pass_first<d,...>
index-heavy forms).

CLASS: REAL

SIMD: zmm everywhere hot; col-last<8> 310 zmm with 0 FMA (80 fp) — the boundary math is
mul/add-form at the axis-0 chain end.
BW: not the lever — 64 KiB, L2-holds.
CACHE: L1d-boundary class (64 KiB vs 48 KiB L1d): the gather's second visit pays evictions
(era counter class at same geometry; wall+asm only on this host).
TILING: rows batched N=16; axis1 col codelet Bt=16; axis0 col_dif Bt=256 radices 2,8
(`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-route-trace-r5base.txt`).
REGS: kb16 73 + col body 16 115 stack refs — the named pressure.
MATH: col-last FMA 0 noted; radix-2 opener trivially light.
OVERHEAD: plumbing ~ 2% here (axis shares dominated by kernels) — subordinate.
STABILITY: base eps 0.0053 vs gap 0.638 (120 x eps); reroll control 1.0151 vs adm/best
1.511 today (base 1.638 — magnitude wobbles 0.13 across days, class stable):
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-r5reroll.md`.

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-perf-shares.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-asm-census.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-route-trace-r5base.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-r5reroll.md`

## ccmlin075 3d_32

MECHANISM: Three-machinery mix: split-gather `codelet_many_static<32>` 23.9% (kManyXpose
fails at N=32, census 242 shuf) + `dif_col_pass_last<8>` 23.2% + `dif_col_pass_first<4>`
20.4% + `col_codelet_body<32>` 19.3% = ~87%; the axis-0 col_dif chain runs Bt=1024 single
tile at 16 KiB stride.

ASM: `/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-asm-census.txt` rows ms32
(1217/242sh), col body<32> (581/199st/0fma), col-first<4> (280 insns, 98 stack/14 shuf).

CLASS: REAL
LOTTERY: d3's in-session flag (reship/yesterday 1.0617 > 1.0433) dissolved by the pairwise 15-round rerun: min 1.0166, median 1.0099, eps 0.0040 — inside every floor; the base/reship day delta was weather against competitors. Receipt `/mnt/home/mbarbone/team-r5-shared/evidence/d3-reroll-ccmlin075.md`.

SIMD: zmm class all stations; col body 409 zmm at fma 0/168 — split form again.
BW: not the lever — 1 MiB arrays, L2-path class.
CACHE: 16 KiB-pitch axis-0 sweeps (4K-alias class on the era counter hosts); the static
proxy is the col bodies' stack/index weight on this host.
TILING: axis1 col_codelet Bt=32; axis0 col_dif Bt=1024 tiles=1 radices 4,8
(`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-route-trace-r5base.txt`).
REGS: col body<32> 199 stack = 34% of the clone — the named share.
MATH: radix-8 batched lambdas 6.9% combined; FMA present in ms32 (112/608 fp).
OVERHEAD: plumbing ≤ 2% — subordinate.
STABILITY: base eps 0.0429 vs gap 0.138 (3.2 x eps); reroll adm/best 1.201 (base 1.138)
with control 0.9946 — loss reproduced today beyond same-binary bounds
(`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-r5reroll.md`).

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-perf-shares.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-asm-census.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-route-trace-r5base.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-r5reroll.md`

## ccmlin075 3d_64

MECHANISM: Mid-3-D class: `dif_col_pass_first<8>` 33.2% + rows per-line
`codelet_apply<64>` 26.9% + `dif_col_pass_last<8>` 24.6% (boundary family = ~58%) with the
per-line 64-point row kernel between them; axis-0 chain runs 7 tiles at 64 KiB stride
(Bt=680 of 4096 runs). Small-margin cell: 4-5% gap, reproduced three days running
(base 1.041, reship 1.041, reroll 1.053).

ASM: `/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-asm-census.txt`
`dif_col_pass_first<d,t,8>` (2766 B, 168 stack, 165 mov vs 92 fp — strided col opener) +
`codelet_apply<64,d>` (318 insns, 63 stack).

CLASS: REAL

WONTFIX: W1 unreachable (len 64); boundary pair ~58%
(`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-perf-shares.txt`) ⇒ W1-class −7% ⇒
~0.99 — needs a len-64-admitting arm that does not exist; reroll control 0.9941 vs gap
1.053 ⇒ REAL small margin, no arm moves it
(`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-r5reroll.md`)

SIMD: zmm both stations; col-first<8> 166 zmm, fma 14/92 — contraction partial in the
strided form.
BW: 8 MiB arrays at L3 edge; both arms similar footing (mkl 7.95e5 vs adm 8.38e5 ns today —
a throughput-class gap, not a miss storm).
CACHE: tiles re-walk the 4 MiB array per axis at 64 KiB pitch (7 x axis-0);
replacement-class effect per the era counter hosts; the asm proxy here is col-first's
168 stack + 165 mov.
TILING: rows per-line codelet; axis1 col_dif Bt=64; axis0 col_dif Bt=680, 7 tiles
(`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-route-trace-r5base.txt`).
REGS: col-first 168/510 + apply<64> 63/318 stack — present shares.
MATH: kernel_batched<8> sits at 4.9% (the 64-point codelet's inner radix); math clean.
OVERHEAD: plan/dispatch ~2.3%; subordinate.
STABILITY: base eps 0.0101 vs gap 0.041 (4.1 x eps) with the reroll control 0.9941 at
adm/best 1.0534 — the gap exceeds the same-binary floor on every measured day:
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-r5reroll.md`. REAL with the smallest
margin on this host: flagged for attention, not NOISE (three independent days all read >
1.04, each > its own same-binary control band).

Evidence: `/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-perf-shares.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-asm-census.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-route-trace-r5base.txt`,
`/mnt/home/mbarbone/team-r5-shared/evidence/ccmlin075-r5reroll.md`

## ccmlin075 summary

11 base losses: 10 REAL + 1 NOISE (2d_8192: weather/bistable per the bisect receipt —
five binaries of three vintages read [1.110,1.151] in one session; both arms moved across
days; no merge owns the 09-06 0.812). All mechanisms are attributed on the staged r5base
binary itself: tiny row-batch family (2d_16/2d_32/3d_8, plus the 3d_4 plumbing+scalar
class), boundary col_dif family (2d_64/2d_128/2d_256/3d_16/3d_32/3d_64), and the
transposed-route scalar mover (2d_8192's lever — real, but not the session-flip source).
W1's cls128/cls256 wins measured on icelake read flat on this host at reship-era
(2d_128 1.468 -> 1.466); W5 TILEMOVE's 2d_8192 claim is the only in-flight lane touching
this host's list.

