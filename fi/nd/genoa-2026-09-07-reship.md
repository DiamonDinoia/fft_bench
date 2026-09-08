# fft_bench N-D standings, genoa, 2026-09-07, admiral @ b68e64cb0f2aeea497a16eb9fa9cf46109f1e1a4 (reship)

Single thread, complex f64 forward oop, ns/transform, min over interleaved rounds, arm order rotated, one core pinned. Job 7000056.
Reduced with /mnt/home/mbarbone/scratch/team-nddiag/fft_bench/fi/nd/nd_reduce.py; verdicts by /mnt/home/mbarbone/scratch/team-nddiag/tools/nd_gen_standings.py (full precision, printed 4 sig figs).

Era-calibration anchors: 2d_4096 and 2d_8192 (d3 compares this table against the D1 baseline drift-scaled by the geomean absolute admiral-ns ratio at these code-untouched cells).

## binaries (staged, sha256)

```
52de3995070118b46123c5f35c29f619534fadc71a246a819863828d178ce806  /mnt/home/mbarbone/team-nddiag-shared/bins-reship/genoa/admiral_bench
25a50446fc53482713eb1a69b92290dcf4259a589a1364a9f40dd57bc9fbfadb  /mnt/home/mbarbone/team-nddiag-shared/bins-reship/genoa/mkl_bench
3d6f2c768e3b30f48706690628c6f15614054db57a376028f79ce0cd0f3149e6  /mnt/home/mbarbone/team-nddiag-shared/bins-reship/genoa/fftw3_bench
64bda77b9efcd9bc159a9cad5128aafe2ae7c98f7bf4f7e3996a8a30dfc130fb  /mnt/home/mbarbone/team-nddiag-shared/bins-reship/genoa/ducc_bench
```

## ratios (nd_reduce)

| cell | reship | mkl | fftw | ducc | max/min reship | reship2/reship | adm/mkl | adm/fftw | adm/ducc | adm/best | leader |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 2d_16 | 348.1 | 824.3 | 216.9 | 984.4 | 1.171 | 0.9972 | 0.422 | 1.605 | 0.354 | 1.605 | fftw |
| 2d_32 | 1409 | 3270 | 1049 | 3358 | 1.028 | 0.9998 | 0.431 | 1.343 | 0.420 | 1.343 | fftw |
| 2d_64 | 8126 | 1.569e+04 | 7381 | 1.921e+04 | 1.022 | 0.9929 | 0.518 | 1.101 | 0.423 | 1.101 | fftw |
| 2d_128 | 3.526e+04 | 6.599e+04 | 3.681e+04 | 4.605e+04 | 1.194 | 1.0068 | 0.534 | 0.958 | 0.766 | 0.958 | fftw |
| 2d_256 | 1.863e+05 | 3.365e+05 | 2.049e+05 | 2.517e+05 | 1.118 | 0.8850 | 0.554 | 0.909 | 0.740 | 0.909 | fftw |
| 2d_512 | 9.379e+05 | 1.577e+06 | 8.902e+05 | 1.209e+06 | 1.055 | 1.0069 | 0.595 | 1.054 | 0.776 | 1.054 | fftw |
| 2d_1024 | 3.639e+06 | 7.873e+06 | 4.467e+06 | 5.03e+06 | 1.453 | 1.0167 | 0.462 | 0.815 | 0.723 | 0.815 | fftw |
| 2d_2048 | 2.641e+07 | 4.466e+07 | 2.892e+07 | 2.902e+07 | 1.051 | 1.0028 | 0.591 | 0.913 | 0.910 | 0.913 | fftw |
| 2d_4096 | 1.171e+08 | 2.532e+08 | 1.401e+08 | 1.256e+08 | 1.144 | 0.9797 | 0.463 | 0.836 | 0.933 | 0.933 | ducc |
| 2d_8192 | 5.539e+08 | 1.831e+09 | 6.052e+08 | 5.827e+08 | 1.006 | 0.9988 | 0.303 | 0.915 | 0.950 | 0.950 | ducc |
| 3d_4 | 187.9 | 854 | 86.15 | 1039 | 1.030 | 0.9984 | 0.220 | 2.181 | 0.181 | 2.181 | fftw |
| 3d_8 | 800.7 | 3227 | 562.6 | 2821 | 1.021 | 1.0021 | 0.248 | 1.423 | 0.284 | 1.423 | fftw |
| 3d_16 | 8432 | 1.932e+04 | 8027 | 2.288e+04 | 1.016 | 0.9899 | 0.437 | 1.050 | 0.368 | 1.050 | fftw |
| 3d_32 | 6.384e+04 | 1.421e+05 | 7.905e+04 | 1.657e+05 | 1.011 | 0.9999 | 0.449 | 0.808 | 0.385 | 0.808 | fftw |
| 3d_64 | 7.588e+05 | 1.721e+06 | 9.072e+05 | 1.419e+06 | 1.022 | 0.9558 | 0.441 | 0.836 | 0.535 | 0.836 | fftw |
| 3d_128 | 1.139e+07 | 1.545e+07 | 1.139e+07 | 1.432e+07 | 1.062 | 0.9983 | 0.737 | 1.000 | 0.795 | 1.000 | fftw |
| 3d_256 | 1.371e+08 | 1.738e+08 | 1.352e+08 | 1.423e+08 | 1.043 | 0.9680 | 0.789 | 1.014 | 0.963 | 1.014 | fftw |
| 3d_512 | 1.625e+09 | 1.484e+09 | 1.212e+09 | 1.226e+09 | 1.043 | 0.9970 | 1.095 | 1.341 | 1.326 | 1.341 | fftw |

reship: worst |cpu/real - 1| over cells = 0.0056
mkl: worst |cpu/real - 1| over cells = 0.0048
fftw: worst |cpu/real - 1| over cells = 0.0048
ducc: worst |cpu/real - 1| over cells = 0.0055

## verdicts

| cell | adm/best | eps | verdict | leader |
|---|---|---|---|---|
| 2d_16 | 1.605 | 0.002835 | LOSS | fftw |
| 2d_32 | 1.343 | 0.0001689 | LOSS | fftw |
| 2d_64 | 1.101 | 0.007115 | LOSS | fftw |
| 2d_128 | 0.9577 | 0.006849 | WIN | fftw |
| 2d_256 | 0.9093 | 0.115 | TIE | fftw |
| 2d_512 | 1.054 | 0.006912 | LOSS | fftw |
| 2d_1024 | 0.8145 | 0.01668 | WIN | fftw |
| 2d_2048 | 0.9132 | 0.002754 | WIN | fftw |
| 2d_4096 | 0.9327 | 0.02031 | WIN | ducc |
| 2d_8192 | 0.9505 | 0.001239 | WIN | ducc |
| 3d_4 | 2.181 | 0.001615 | LOSS | fftw |
| 3d_8 | 1.423 | 0.002096 | LOSS | fftw |
| 3d_16 | 1.05 | 0.01009 | LOSS | fftw |
| 3d_32 | 0.8076 | 6.734e-05 | WIN | fftw |
| 3d_64 | 0.8364 | 0.04419 | WIN | fftw |
| 3d_128 | 1 | 0.001684 | TIE | fftw |
| 3d_256 | 1.014 | 0.03204 | TIE | fftw |
| 3d_512 | 1.341 | 0.00297 | LOSS | fftw |

**WIN 7 / TIE 3 / LOSS 8**

Raw TSV: /mnt/home/mbarbone/scratch/team-nddiag/standings/raw/genoa/measure.tsv
