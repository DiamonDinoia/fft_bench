# fft_bench N-D standings, icelake, 2026-09-08, admiral @ 017e132440a2900ae6dbf14f6a7a6e308ac51c46 (reship)

Single thread, complex f64 forward oop, ns/transform, min over interleaved rounds, arm order rotated, one core pinned. Job 7001688.
Reduced with /mnt/home/mbarbone/scratch/team-nddiag/fft_bench/fi/nd/nd_reduce.py; verdicts by /mnt/home/mbarbone/scratch/team-nddiag/tools/nd_gen_standings.py (full precision, printed 4 sig figs).

Era-calibration anchors: 2d_4096 and 2d_8192 (d3 compares this table against the D1 baseline drift-scaled by the geomean absolute admiral-ns ratio at these code-untouched cells).

## binaries (staged, sha256)

```
884c1a85ae3bbd37b4fae149fcf7af1c261854d70a45a5851574c9ac8f9b9d16  /mnt/home/mbarbone/team-nddiag-shared/bins-reship/icelake/admiral_bench
ec29a14149b8823bfb81443bd34be94d6577a3f8e4a79e8bedc44debc2b44d44  /mnt/home/mbarbone/team-nddiag-shared/bins-reship/icelake/mkl_bench
d1dc25e787d3f4b44a20edb3260709a301813b4233826555d979dadc98e9af52  /mnt/home/mbarbone/team-nddiag-shared/bins-reship/icelake/fftw3_bench
8fa07d38038980dfe767fa9ffaad8c42dec1b75020bbca17cc7525013c9eefe7  /mnt/home/mbarbone/team-nddiag-shared/bins-reship/icelake/ducc_bench
```

## ratios (nd_reduce)

| cell | reship | mkl | fftw | ducc | max/min reship | reship2/reship | adm/mkl | adm/fftw | adm/ducc | adm/best | leader |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 2d_16 | 405 | 186.3 | 277.3 | 1427 | 1.000 | 0.9999 | 2.174 | 1.461 | 0.284 | 2.174 | mkl |
| 2d_32 | 1618 | 1064 | 1320 | 4294 | 1.001 | 0.9992 | 1.521 | 1.226 | 0.377 | 1.521 | mkl |
| 2d_64 | 9718 | 6262 | 9027 | 1.788e+04 | 1.013 | 1.0043 | 1.552 | 1.077 | 0.544 | 1.552 | mkl |
| 2d_128 | 4.978e+04 | 2.827e+04 | 4.963e+04 | 7.812e+04 | 1.019 | 1.0083 | 1.761 | 1.003 | 0.637 | 1.761 | mkl |
| 2d_256 | 2.407e+05 | 1.79e+05 | 3.035e+05 | 3.968e+05 | 1.217 | 1.2088 | 1.345 | 0.793 | 0.607 | 1.345 | mkl |
| 2d_512 | 1.43e+06 | 9.909e+05 | 1.551e+06 | 1.909e+06 | 1.100 | 0.8793 | 1.443 | 0.922 | 0.749 | 1.443 | mkl |
| 2d_1024 | 4.9e+06 | 4.724e+06 | 6.516e+06 | 7.755e+06 | 1.007 | 0.9971 | 1.037 | 0.752 | 0.632 | 1.037 | mkl |
| 2d_2048 | 4.118e+07 | 3.832e+07 | 4.585e+07 | 5.562e+07 | 1.078 | 0.9942 | 1.075 | 0.898 | 0.740 | 1.075 | mkl |
| 2d_4096 | 1.762e+08 | 1.896e+08 | 2.09e+08 | 2.756e+08 | 1.004 | 0.9954 | 0.929 | 0.843 | 0.639 | 0.929 | mkl |
| 2d_8192 | 7.307e+08 | 7.253e+08 | 9.036e+08 | 1.151e+09 | 1.032 | 1.0050 | 1.008 | 0.809 | 0.635 | 1.008 | mkl |
| 3d_4 | 258.2 | 82.87 | 118.6 | 1368 | 1.001 | 1.0000 | 3.116 | 2.177 | 0.189 | 3.116 | mkl |
| 3d_8 | 1370 | 489.1 | 738.6 | 3819 | 1.016 | 1.0004 | 2.801 | 1.855 | 0.359 | 2.801 | mkl |
| 3d_16 | 1.094e+04 | 5673 | 1.032e+04 | 2.687e+04 | 1.035 | 1.0102 | 1.928 | 1.060 | 0.407 | 1.928 | mkl |
| 3d_32 | 8.256e+04 | 6.49e+04 | 1.033e+05 | 2.231e+05 | 1.022 | 0.9966 | 1.272 | 0.799 | 0.370 | 1.272 | mkl |
| 3d_64 | 9.554e+05 | 1.085e+06 | 1.339e+06 | 2.059e+06 | 1.083 | 1.0871 | 0.880 | 0.713 | 0.464 | 0.880 | mkl |
| 3d_128 | 1.362e+07 | 1.05e+07 | 1.562e+07 | 1.987e+07 | 1.034 | 1.0005 | 1.297 | 0.872 | 0.685 | 1.297 | mkl |
| 3d_256 | 1.967e+08 | 1.828e+08 | 2.001e+08 | 2.582e+08 | 1.018 | 1.0021 | 1.076 | 0.983 | 0.762 | 1.076 | mkl |
| 3d_512 | 1.886e+09 | 2.354e+09 | 2.009e+09 | 2.392e+09 | 1.011 | 1.0033 | 0.801 | 0.938 | 0.788 | 0.938 | fftw |

reship: worst |cpu/real - 1| over cells = 0.0040
mkl: worst |cpu/real - 1| over cells = 0.0035
fftw: worst |cpu/real - 1| over cells = 0.0047
ducc: worst |cpu/real - 1| over cells = 0.0035

## verdicts

| cell | adm/best | eps | verdict | leader |
|---|---|---|---|---|
| 2d_16 | 2.174 | 9.694e-05 | LOSS | mkl |
| 2d_32 | 1.521 | 0.0007998 | LOSS | mkl |
| 2d_64 | 1.552 | 0.00432 | LOSS | mkl |
| 2d_128 | 1.761 | 0.008263 | LOSS | mkl |
| 2d_256 | 1.345 | 0.2088 | LOSS | mkl |
| 2d_512 | 1.443 | 0.1207 | LOSS | mkl |
| 2d_1024 | 1.037 | 0.002859 | LOSS | mkl |
| 2d_2048 | 1.075 | 0.005806 | LOSS | mkl |
| 2d_4096 | 0.9292 | 0.00464 | WIN | mkl |
| 2d_8192 | 1.008 | 0.004958 | LOSS | mkl |
| 3d_4 | 3.116 | 4.238e-05 | LOSS | mkl |
| 3d_8 | 2.801 | 0.0004246 | LOSS | mkl |
| 3d_16 | 1.928 | 0.0102 | LOSS | mkl |
| 3d_32 | 1.272 | 0.003415 | LOSS | mkl |
| 3d_64 | 0.8805 | 0.08712 | WIN | mkl |
| 3d_128 | 1.297 | 0.0004704 | LOSS | mkl |
| 3d_256 | 1.076 | 0.00208 | LOSS | mkl |
| 3d_512 | 0.9385 | 0.003304 | WIN | fftw |

**WIN 3 / TIE 0 / LOSS 15**

Raw TSV: /mnt/home/mbarbone/scratch/team-nddiag/standings/raw/icelake/measure.tsv
