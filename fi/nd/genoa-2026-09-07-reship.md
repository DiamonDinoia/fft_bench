# fft_bench N-D standings, genoa, 2026-09-08, admiral @ 017e132440a2900ae6dbf14f6a7a6e308ac51c46 (reship)

Single thread, complex f64 forward oop, ns/transform, min over interleaved rounds, arm order rotated, one core pinned. Job 7001690.
Reduced with /mnt/home/mbarbone/scratch/team-nddiag/fft_bench/fi/nd/nd_reduce.py; verdicts by /mnt/home/mbarbone/scratch/team-nddiag/tools/nd_gen_standings.py (full precision, printed 4 sig figs).

Era-calibration anchors: 2d_4096 and 2d_8192 (d3 compares this table against the D1 baseline drift-scaled by the geomean absolute admiral-ns ratio at these code-untouched cells).

## binaries (staged, sha256)

```
87d9534eab1cd652e00b1d23cde7cb7e8c0ce0e57b2fa307cd6ca5d3d1221dc0  /mnt/home/mbarbone/team-nddiag-shared/bins-reship/genoa/admiral_bench
25a50446fc53482713eb1a69b92290dcf4259a589a1364a9f40dd57bc9fbfadb  /mnt/home/mbarbone/team-nddiag-shared/bins-reship/genoa/mkl_bench
3d6f2c768e3b30f48706690628c6f15614054db57a376028f79ce0cd0f3149e6  /mnt/home/mbarbone/team-nddiag-shared/bins-reship/genoa/fftw3_bench
d1b654ae649ea0076a968bfb9cf698c614aaa37650f1d070f5a41d0bc74837c3  /mnt/home/mbarbone/team-nddiag-shared/bins-reship/genoa/ducc_bench
```

## ratios (nd_reduce)

| cell | reship | mkl | fftw | ducc | max/min reship | reship2/reship | adm/mkl | adm/fftw | adm/ducc | adm/best | leader |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 2d_16 | 348.3 | 824 | 217.5 | 987 | 1.021 | 0.9977 | 0.423 | 1.601 | 0.353 | 1.601 | fftw |
| 2d_32 | 1392 | 3270 | 1043 | 3378 | 1.029 | 1.0038 | 0.426 | 1.334 | 0.412 | 1.334 | fftw |
| 2d_64 | 8169 | 1.568e+04 | 7334 | 1.958e+04 | 1.031 | 1.0054 | 0.521 | 1.114 | 0.417 | 1.114 | fftw |
| 2d_128 | 3.621e+04 | 6.611e+04 | 3.708e+04 | 4.615e+04 | 1.197 | 1.0006 | 0.548 | 0.976 | 0.785 | 0.976 | fftw |
| 2d_256 | 1.625e+05 | 3.352e+05 | 2.067e+05 | 2.521e+05 | 1.267 | 1.0031 | 0.485 | 0.786 | 0.645 | 0.786 | fftw |
| 2d_512 | 9.463e+05 | 1.582e+06 | 9.04e+05 | 1.211e+06 | 1.032 | 0.8418 | 0.598 | 1.047 | 0.781 | 1.047 | fftw |
| 2d_1024 | 3.598e+06 | 7.954e+06 | 4.439e+06 | 5.137e+06 | 1.401 | 1.0140 | 0.452 | 0.810 | 0.700 | 0.810 | fftw |
| 2d_2048 | 2.737e+07 | 4.48e+07 | 2.969e+07 | 2.89e+07 | 1.039 | 0.9871 | 0.611 | 0.922 | 0.947 | 0.947 | ducc |
| 2d_4096 | 1.149e+08 | 2.54e+08 | 1.408e+08 | 1.246e+08 | 1.250 | 0.9982 | 0.452 | 0.816 | 0.923 | 0.923 | ducc |
| 2d_8192 | 5.583e+08 | 1.83e+09 | 6.109e+08 | 5.818e+08 | 1.022 | 0.9936 | 0.305 | 0.914 | 0.960 | 0.960 | ducc |
| 3d_4 | 188.6 | 854.9 | 86.72 | 1037 | 1.026 | 0.9984 | 0.221 | 2.175 | 0.182 | 2.175 | fftw |
| 3d_8 | 795.4 | 3228 | 560.8 | 2825 | 1.075 | 1.0009 | 0.246 | 1.418 | 0.282 | 1.418 | fftw |
| 3d_16 | 8297 | 1.928e+04 | 8009 | 2.292e+04 | 1.063 | 1.0033 | 0.430 | 1.036 | 0.362 | 1.036 | fftw |
| 3d_32 | 6.378e+04 | 1.412e+05 | 8.025e+04 | 1.663e+05 | 1.057 | 1.0001 | 0.452 | 0.795 | 0.383 | 0.795 | fftw |
| 3d_64 | 7.604e+05 | 1.723e+06 | 9.142e+05 | 1.429e+06 | 1.043 | 1.0008 | 0.441 | 0.832 | 0.532 | 0.832 | fftw |
| 3d_128 | 1.128e+07 | 1.55e+07 | 1.12e+07 | 1.431e+07 | 1.014 | 0.9998 | 0.727 | 1.007 | 0.788 | 1.007 | fftw |
| 3d_256 | 1.258e+08 | 1.754e+08 | 1.334e+08 | 1.428e+08 | 1.138 | 1.0083 | 0.717 | 0.943 | 0.881 | 0.943 | fftw |
| 3d_512 | 1.636e+09 | 1.487e+09 | 1.206e+09 | 1.23e+09 | 1.020 | 0.9946 | 1.100 | 1.357 | 1.330 | 1.357 | fftw |

reship: worst |cpu/real - 1| over cells = 0.0053
mkl: worst |cpu/real - 1| over cells = 0.0048
fftw: worst |cpu/real - 1| over cells = 0.0061
ducc: worst |cpu/real - 1| over cells = 0.0057

## verdicts

| cell | adm/best | eps | verdict | leader |
|---|---|---|---|---|
| 2d_16 | 1.601 | 0.002296 | LOSS | fftw |
| 2d_32 | 1.334 | 0.003831 | LOSS | fftw |
| 2d_64 | 1.114 | 0.005368 | LOSS | fftw |
| 2d_128 | 0.9763 | 0.0005849 | WIN | fftw |
| 2d_256 | 0.7863 | 0.003086 | WIN | fftw |
| 2d_512 | 1.047 | 0.1582 | TIE | fftw |
| 2d_1024 | 0.8105 | 0.01401 | WIN | fftw |
| 2d_2048 | 0.947 | 0.01289 | WIN | ducc |
| 2d_4096 | 0.9228 | 0.001832 | WIN | ducc |
| 2d_8192 | 0.9596 | 0.006394 | WIN | ducc |
| 3d_4 | 2.175 | 0.001609 | LOSS | fftw |
| 3d_8 | 1.418 | 0.0008691 | LOSS | fftw |
| 3d_16 | 1.036 | 0.00329 | LOSS | fftw |
| 3d_32 | 0.7948 | 0.0001019 | WIN | fftw |
| 3d_64 | 0.8318 | 0.000796 | WIN | fftw |
| 3d_128 | 1.007 | 0.000212 | LOSS | fftw |
| 3d_256 | 0.9427 | 0.00829 | WIN | fftw |
| 3d_512 | 1.357 | 0.00541 | LOSS | fftw |

**WIN 9 / TIE 1 / LOSS 8**

Raw TSV: /mnt/home/mbarbone/scratch/team-nddiag/standings/raw/genoa/measure.tsv
