# fft_bench N-D standings, rome, 2026-09-07, admiral @ b68e64cb0f2aeea497a16eb9fa9cf46109f1e1a4 (reship)

Single thread, complex f64 forward oop, ns/transform, min over interleaved rounds, arm order rotated, one core pinned. Job 7000055.
Reduced with /mnt/home/mbarbone/scratch/team-nddiag/fft_bench/fi/nd/nd_reduce.py; verdicts by /mnt/home/mbarbone/scratch/team-nddiag/tools/nd_gen_standings.py (full precision, printed 4 sig figs).

Era-calibration anchors: 2d_4096 and 2d_8192 (d3 compares this table against the D1 baseline drift-scaled by the geomean absolute admiral-ns ratio at these code-untouched cells).

## binaries (staged, sha256)

```
e77f755b92e1bfa75ff59a5848fdea0ee4f845a9826e536fc791603f0d949139  /mnt/home/mbarbone/team-nddiag-shared/bins-reship/rome/admiral_bench
43926b08f9009e93eccc756aa9e3f679f9fecbc925c698b4170f86eff4451972  /mnt/home/mbarbone/team-nddiag-shared/bins-reship/rome/mkl_bench
6e20a443f865ec2576874c50fc25fc7fc1c87ae5b020dc841b45f1916de8226e  /mnt/home/mbarbone/team-nddiag-shared/bins-reship/rome/fftw3_bench
0cf11733d301e8616e8b07e2c8e765e2848405c4e8e63daa48206563abeb0b93  /mnt/home/mbarbone/team-nddiag-shared/bins-reship/rome/ducc_bench
```

## ratios (nd_reduce)

| cell | reship | mkl | fftw | ducc | max/min reship | reship2/reship | adm/mkl | adm/fftw | adm/ducc | adm/best | leader |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 2d_16 | 617.5 | 1553 | 429.2 | 1749 | 1.002 | 1.0002 | 0.398 | 1.439 | 0.353 | 1.439 | fftw |
| 2d_32 | 3346 | 6386 | 1971 | 5714 | 1.001 | 0.9999 | 0.524 | 1.697 | 0.586 | 1.697 | fftw |
| 2d_64 | 1.338e+04 | 2.646e+04 | 1.081e+04 | 2.013e+04 | 1.002 | 0.9999 | 0.506 | 1.237 | 0.665 | 1.237 | fftw |
| 2d_128 | 6.515e+04 | 1.088e+05 | 6.344e+04 | 7.445e+04 | 1.016 | 1.0074 | 0.599 | 1.027 | 0.875 | 1.027 | fftw |
| 2d_256 | 3.191e+05 | 5.324e+05 | 3.22e+05 | 4.068e+05 | 1.031 | 1.0078 | 0.599 | 0.991 | 0.784 | 0.991 | fftw |
| 2d_512 | 1.36e+06 | 2.369e+06 | 1.394e+06 | 1.754e+06 | 1.045 | 0.9976 | 0.574 | 0.976 | 0.775 | 0.976 | fftw |
| 2d_1024 | 8.162e+06 | 1.218e+07 | 9.407e+06 | 7.915e+06 | 1.021 | 1.0075 | 0.670 | 0.868 | 1.031 | 1.031 | ducc |
| 2d_2048 | 4.302e+07 | 8.324e+07 | 4.681e+07 | 6.195e+07 | 1.006 | 1.0015 | 0.517 | 0.919 | 0.694 | 0.919 | fftw |
| 2d_4096 | 1.949e+08 | 8.424e+08 | 2.001e+08 | 2.783e+08 | 1.009 | 0.9993 | 0.231 | 0.974 | 0.700 | 0.974 | fftw |
| 2d_8192 | 8.813e+08 | 3.465e+09 | 8.753e+08 | 1.158e+09 | 1.008 | 1.0014 | 0.254 | 1.007 | 0.761 | 1.007 | fftw |
| 3d_4 | 322.6 | 1763 | 139.5 | 1799 | 1.007 | 1.0033 | 0.183 | 2.313 | 0.179 | 2.313 | fftw |
| 3d_8 | 1712 | 6105 | 1142 | 5290 | 1.002 | 1.0003 | 0.280 | 1.500 | 0.324 | 1.500 | fftw |
| 3d_16 | 1.354e+04 | 3.3e+04 | 1.323e+04 | 3.047e+04 | 1.005 | 1.0001 | 0.410 | 1.023 | 0.444 | 1.023 | fftw |
| 3d_32 | 1.588e+05 | 2.369e+05 | 1.318e+05 | 2.686e+05 | 1.007 | 0.9905 | 0.670 | 1.205 | 0.591 | 1.205 | fftw |
| 3d_64 | 1.343e+06 | 2.737e+06 | 1.35e+06 | 2.126e+06 | 1.009 | 1.0030 | 0.491 | 0.995 | 0.632 | 0.995 | fftw |
| 3d_128 | 2.378e+07 | 4.157e+07 | 1.978e+07 | 3.462e+07 | 1.011 | 1.0044 | 0.572 | 1.202 | 0.687 | 1.202 | fftw |
| 3d_256 | 2.163e+08 | 3.867e+08 | 2.132e+08 | 3.002e+08 | 1.031 | 1.0207 | 0.559 | 1.015 | 0.720 | 1.015 | fftw |
| 3d_512 | 1.887e+09 | 3.375e+09 | 1.964e+09 | 2.478e+09 | 1.018 | 0.9980 | 0.559 | 0.961 | 0.762 | 0.961 | fftw |

reship: worst |cpu/real - 1| over cells = 0.0062
mkl: worst |cpu/real - 1| over cells = 0.0048
fftw: worst |cpu/real - 1| over cells = 0.0062
ducc: worst |cpu/real - 1| over cells = 0.0054

## verdicts

| cell | adm/best | eps | verdict | leader |
|---|---|---|---|---|
| 2d_16 | 1.439 | 0.0002329 | LOSS | fftw |
| 2d_32 | 1.697 | 9.586e-05 | LOSS | fftw |
| 2d_64 | 1.237 | 0.0001063 | LOSS | fftw |
| 2d_128 | 1.027 | 0.007362 | LOSS | fftw |
| 2d_256 | 0.991 | 0.007847 | WIN | fftw |
| 2d_512 | 0.9755 | 0.002443 | WIN | fftw |
| 2d_1024 | 1.031 | 0.007479 | LOSS | ducc |
| 2d_2048 | 0.9191 | 0.001488 | WIN | fftw |
| 2d_4096 | 0.9739 | 0.0006749 | WIN | fftw |
| 2d_8192 | 1.007 | 0.001414 | LOSS | fftw |
| 3d_4 | 2.313 | 0.003285 | LOSS | fftw |
| 3d_8 | 1.5 | 0.0002928 | LOSS | fftw |
| 3d_16 | 1.023 | 5.266e-05 | LOSS | fftw |
| 3d_32 | 1.205 | 0.009536 | LOSS | fftw |
| 3d_64 | 0.995 | 0.00297 | WIN | fftw |
| 3d_128 | 1.202 | 0.00442 | LOSS | fftw |
| 3d_256 | 1.015 | 0.02065 | TIE | fftw |
| 3d_512 | 0.961 | 0.002009 | WIN | fftw |

**WIN 6 / TIE 1 / LOSS 11**

Raw TSV: /mnt/home/mbarbone/scratch/team-nddiag/standings/raw/rome/measure.tsv
