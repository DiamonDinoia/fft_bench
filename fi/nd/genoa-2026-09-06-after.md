# fft_bench N-D standings, genoa, 2026-09-06, admiral @ c4c3911235e8e20636f9be471efd4d9717852c8a (after)

Single thread, complex f64 forward oop, ns/transform, min over interleaved rounds, arm order rotated, one core pinned. Job 6993674.
Reduced with fft_bench/fi/nd/nd_reduce.py; verdicts by /mnt/home/mbarbone/scratch/team-nddiag/tools/nd_gen_standings.py (full precision, printed 4 sig figs).

## binaries (staged, sha256)

```
31625bc21b236271bc210a78fd8438dfbdccf46393015c3d0e45cafbcbfa0869  bins/genoa/admiral_bench
25a50446fc53482713eb1a69b92290dcf4259a589a1364a9f40dd57bc9fbfadb  bins/genoa/mkl_bench
3d6f2c768e3b30f48706690628c6f15614054db57a376028f79ce0cd0f3149e6  bins/genoa/fftw3_bench
ac15d1f32324a71b6aa23ecbf0d6f190de1afa560a663e707124663beeb6d41e  bins/genoa/ducc_bench
```

## ratios (nd_reduce)

| cell | after | mkl | fftw | ducc | max/min after | after2/after | adm/mkl | adm/fftw | adm/ducc | adm/best | leader |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 2d_16 | 401.1 | 824.1 | 217.7 | 980 | 1.096 | 1.0003 | 0.487 | 1.842 | 0.409 | 1.842 | fftw |
| 2d_32 | 1703 | 3271 | 1059 | 3368 | 1.043 | 1.0023 | 0.521 | 1.609 | 0.506 | 1.609 | fftw |
| 2d_64 | 8084 | 1.568e+04 | 7502 | 1.944e+04 | 1.015 | 0.9999 | 0.516 | 1.078 | 0.416 | 1.078 | fftw |
| 2d_128 | 3.57e+04 | 6.626e+04 | 3.715e+04 | 4.593e+04 | 1.144 | 0.9938 | 0.539 | 0.961 | 0.777 | 0.961 | fftw |
| 2d_256 | 1.883e+05 | 3.321e+05 | 2.047e+05 | 2.513e+05 | 1.091 | 0.8613 | 0.567 | 0.920 | 0.749 | 0.920 | fftw |
| 2d_512 | 9.535e+05 | 1.574e+06 | 8.881e+05 | 1.212e+06 | 1.045 | 0.8511 | 0.606 | 1.074 | 0.787 | 1.074 | fftw |
| 2d_1024 | 3.639e+06 | 7.862e+06 | 4.463e+06 | 5.019e+06 | 1.491 | 1.0238 | 0.463 | 0.815 | 0.725 | 0.815 | fftw |
| 2d_2048 | 2.713e+07 | 4.459e+07 | 2.935e+07 | 2.806e+07 | 1.134 | 0.9915 | 0.609 | 0.925 | 0.967 | 0.967 | ducc |
| 2d_4096 | 1.142e+08 | 2.532e+08 | 1.406e+08 | 1.245e+08 | 1.190 | 1.0164 | 0.451 | 0.812 | 0.918 | 0.918 | ducc |
| 2d_8192 | 5.54e+08 | 1.836e+09 | 6.087e+08 | 5.815e+08 | 1.010 | 0.9949 | 0.302 | 0.910 | 0.953 | 0.953 | ducc |
| 3d_4 | 215 | 860.7 | 86.64 | 1043 | 1.001 | 0.9999 | 0.250 | 2.481 | 0.206 | 2.481 | fftw |
| 3d_8 | 998.7 | 3229 | 561.3 | 2836 | 1.075 | 1.0001 | 0.309 | 1.779 | 0.352 | 1.779 | fftw |
| 3d_16 | 9325 | 1.918e+04 | 8023 | 2.291e+04 | 1.080 | 1.0041 | 0.486 | 1.162 | 0.407 | 1.162 | fftw |
| 3d_32 | 7.419e+04 | 1.412e+05 | 7.764e+04 | 1.669e+05 | 1.014 | 1.0005 | 0.526 | 0.956 | 0.445 | 0.956 | fftw |
| 3d_64 | 7.608e+05 | 1.723e+06 | 9.099e+05 | 1.431e+06 | 1.006 | 1.0000 | 0.441 | 0.836 | 0.532 | 0.836 | fftw |
| 3d_128 | 1.078e+07 | 1.539e+07 | 1.165e+07 | 1.424e+07 | 1.060 | 0.9855 | 0.701 | 0.926 | 0.757 | 0.926 | fftw |
| 3d_256 | 1.4e+08 | 1.688e+08 | 1.366e+08 | 1.423e+08 | 1.038 | 0.9952 | 0.829 | 1.025 | 0.984 | 1.025 | fftw |
| 3d_512 | 1.67e+09 | 1.484e+09 | 1.162e+09 | 1.222e+09 | 1.006 | 0.9904 | 1.125 | 1.437 | 1.367 | 1.437 | fftw |

after: worst |cpu/real - 1| over cells = 0.0052
mkl: worst |cpu/real - 1| over cells = 0.0044
fftw: worst |cpu/real - 1| over cells = 0.0047
ducc: worst |cpu/real - 1| over cells = 0.0050

## verdicts

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

**WIN 8 / TIE 2 / LOSS 8**

Raw TSV: /mnt/home/mbarbone/scratch/team-nddiag/standings/raw/genoa/measure.tsv
