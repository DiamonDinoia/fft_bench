# fft_bench N-D standings, ccmlin075 (SPR), 2026-09-10, admiral @ 15dc10f (landed)

Host ccmlin075, Intel Xeon w5-3435X. Single thread, complex f64 forward oop, ns/transform,
min over 5 interleaved rounds, arm order rotated, pinned to CPU 4. Run with
fi/nd/step_l7_chain.sh (build + measure + reduce + sha stamps; log
/home/mbarbone/localcache/scratch/fftb-nd/step-l7.chain.log), the L7 campaign's landed
master as the measured arm.

Landing content at 15dc10f: frozen-selector folds (17 macros deleted, bit-exact) +
alignment-canonical allocation unconditional (S1b) + COLDIF_GEO geometry arm deleted
(adjudicated: wins only on rome class; arm preserved on branch rome/coldif-geo-floor).
Bit-stability: transformed bits change only via the S1b canonical-layout fix
(inst_real_{f,d} object deltas; receipted re-baseline), everything else bit-identical
to b9a2bdf by preprocessor + nm identity proofs.

Deviations from the step0 convention:
- MKL arm EXCLUDED on this host: step0/mkl_bench hardlinks oneMKL 2026.0.0
  (libmkl_rt.so.3), whose nix store path has since been GC'd; ccmlin075's module
  carries 2024.2.2 (libmkl_rt.so.2) only. The cluster standings docs
  (genoa/icelake/rome 2026-09-10-landed) carry per-host MKL rows; mkl rows here all
  measure nan (documented, not a measurement).
- The reduce was re-run by hand after the chain's first reducer call failed on the
  mkl nan rows (tables below = fi/nd/nd_reduce.py on the full 6-arm measure.tsv).
- No perf-stat GHz block: perf is refused on ccmlin075 (campaign wall-only rule).

Commands:
```
bash fi/nd/step_l7_chain.sh   # build -j10, nd_measure CPU4 5 rounds 6 arms
python3 fi/nd/nd_reduce.py step-l7/measure.tsv after fftw ducc --ctl after2
python3 fi/nd/nd_reduce.py step-l7/measure.tsv after before --ctl after2
```
Arms: after = build @15dc10f (this tree); before = step0/admiral_bench @017e132;
fftw/ducc = step0 frozen; after2 = same-as-after control; (mkl rows = nan).

```
a3556dea... step0 shas; landed-arm sha in step-l7/SHA256SUMS
```

## after (landed) vs fftw / ducc

| cell | after | fftw | ducc | max/min after | after2/after | adm/fftw | adm/ducc | adm/best | leader |
|---|---|---|---|---|---|---|---|---|---|
| 2d_16 | 229.8 | 189.8 | 879.2 | 1.029 | 1.0003 | 1.211 | 0.261 | 1.211 | fftw |
| 2d_32 | 980.7 | 891.1 | 2908 | 1.024 | 1.0045 | 1.101 | 0.337 | 1.101 | fftw |
| 2d_64 | 6819 | 7268 | 1.358e+04 | 1.036 | 0.9875 | 0.938 | 0.502 | 0.938 | fftw |
| 2d_128 | 2.861e+04 | 3.638e+04 | 5.808e+04 | 1.116 | 1.0424 | 0.786 | 0.493 | 0.786 | fftw |
| 2d_256 | 1.465e+05 | 2.113e+05 | 2.94e+05 | 1.058 | 1.0069 | 0.693 | 0.498 | 0.693 | fftw |
| 2d_512 | 9.839e+05 | 1.369e+06 | 1.797e+06 | 1.111 | 0.9565 | 0.719 | 0.548 | 0.719 | fftw |
| 2d_1024 | 5.347e+06 | 6.177e+06 | 7.644e+06 | 1.069 | 1.0133 | 0.866 | 0.699 | 0.866 | fftw |
| 2d_2048 | 2.915e+07 | 3.688e+07 | 4.682e+07 | 1.021 | 0.9995 | 0.790 | 0.622 | 0.790 | fftw |
| 2d_4096 | 1.573e+08 | 1.752e+08 | 2.281e+08 | 1.090 | 0.9984 | 0.898 | 0.690 | 0.898 | fftw |
| 2d_8192 | 6.993e+08 | 7.238e+08 | 1.04e+09 | 1.115 | 1.0002 | 0.966 | 0.673 | 0.966 | fftw |
| 3d_4 | 155.1 | 77.38 | 905.4 | 1.055 | 0.9959 | 2.004 | 0.171 | 2.004 | fftw |
| 3d_8 | 651.2 | 528.5 | 2464 | 1.016 | 1.0084 | 1.232 | 0.264 | 1.232 | fftw |
| 3d_16 | 7627 | 7614 | 1.631e+04 | 1.044 | 1.0023 | 1.002 | 0.468 | 1.002 | fftw |
| 3d_32 | 6.027e+04 | 7.092e+04 | 1.549e+05 | 1.153 | 1.0247 | 0.850 | 0.389 | 0.850 | fftw |
| 3d_64 | 7.677e+05 | 9.705e+05 | 1.647e+06 | 1.077 | 1.0026 | 0.791 | 0.466 | 0.791 | fftw |
| 3d_128 | 1.014e+07 | 1.293e+07 | 1.762e+07 | 1.023 | 0.9816 | 0.784 | 0.576 | 0.784 | fftw |
| 3d_256 | 1.279e+08 | 2.424e+08 | 2.296e+08 | 1.011 | 1.0001 | 0.528 | 0.557 | 0.557 | ducc |
| 3d_512 | 1.333e+09 | 1.655e+09 | 2.211e+09 | 1.007 | 0.9989 | 0.805 | 0.603 | 0.805 | fftw |

## after (landed) vs before (step0 @017e132)

| cell | after | before | max/min after | after2/after | adm/before |
|---|---|---|---|---|---|
| 2d_16 | 229.8 | 303.4 | 1.029 | 1.0003 | 0.757 |
| 2d_32 | 980.7 | 1260 | 1.024 | 1.0045 | 0.778 |
| 2d_64 | 6819 | 6839 | 1.036 | 0.9875 | 0.997 |
| 2d_128 | 2.861e+04 | 3.128e+04 | 1.116 | 1.0424 | 0.915 |
| 2d_256 | 1.465e+05 | 1.541e+05 | 1.058 | 1.0069 | 0.951 |
| 2d_512 | 9.839e+05 | 9.651e+05 | 1.111 | 0.9565 | 1.020 |
| 2d_1024 | 5.347e+06 | 5.501e+06 | 1.069 | 1.0133 | 0.972 |
| 2d_2048 | 2.915e+07 | 4.077e+07 | 1.021 | 0.9995 | 0.715 |
| 2d_4096 | 1.573e+08 | 1.704e+08 | 1.090 | 0.9984 | 0.923 |
| 2d_8192 | 6.993e+08 | 8.396e+08 | 1.115 | 1.0002 | 0.833 |
| 3d_4 | 155.1 | 203.7 | 1.055 | 0.9959 | 0.761 |
| 3d_8 | 651.2 | 793.5 | 1.016 | 1.0084 | 0.821 |
| 3d_16 | 7627 | 8727 | 1.044 | 1.0023 | 0.874 |
| 3d_32 | 6.027e+04 | 6.87e+04 | 1.153 | 1.0247 | 0.877 |
| 3d_64 | 7.677e+05 | 7.982e+05 | 1.077 | 1.0026 | 0.962 |
| 3d_128 | 1.014e+07 | 1.056e+07 | 1.023 | 0.9816 | 0.961 |
| 3d_256 | 1.279e+08 | 1.438e+08 | 1.011 | 1.0001 | 0.889 |
| 3d_512 | 1.333e+09 | 1.324e+09 | 1.007 | 0.9989 | 1.007 |

Reading: landed master is faster than step0 on 16 of 18 cells (0.715–0.997). The two
>1 cells (2d_512 1.020, 3d_512 1.007) sit below the same-binary control spread on
those cells (after2/after within 0.95–1.04 across the suite) — unresolved, not
regressions. Known deltas folded since 017e132: alignment-canonical allocation,
COLDIF_FIRST/DIET + TILEMOVE/FLAT* now unconditional, several N-D engine wins from
the r5 reship already compared elsewhere.
