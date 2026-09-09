# fft_bench N-D standings, genoa, 2026-09-08, admiral @ 017e132440a2900ae6dbf14f6a7a6e308ac51c46 (after)

Single thread, complex f64 forward oop, ns/transform, min over interleaved rounds, arm order rotated, one core pinned. Job 7002702.
Reduced with /mnt/home/mbarbone/team-r5-shared/fft_bench-jobs/nd_reduce.py; verdicts by /mnt/home/mbarbone/team-r5-shared/tools/nd_gen_standings.py (full precision, printed 4 sig figs).
Era control (codex rule 12): yesterday = staged closed-campaign after-era build, admiral @ c4c3911235e8e20636f9be471efd4d9717852c8a (2026-09-06), hash-verified vs team-nddiag standings/*-after.md records. It is a ratio column only; best/verdicts range over mkl/fftw/ducc.

## binaries (staged, sha256)

```
87d9534eab1cd652e00b1d23cde7cb7e8c0ce0e57b2fa307cd6ca5d3d1221dc0  /mnt/home/mbarbone/team-r5-shared/bins/genoa/admiral_bench-r5base
25a50446fc53482713eb1a69b92290dcf4259a589a1364a9f40dd57bc9fbfadb  /mnt/home/mbarbone/team-r5-shared/bins/genoa/mkl_bench-r5base
3d6f2c768e3b30f48706690628c6f15614054db57a376028f79ce0cd0f3149e6  /mnt/home/mbarbone/team-r5-shared/bins/genoa/fftw3_bench-r5base
7b3031decd63782f348472208e6a71872279a097a586ac8547d2f3edcd4ab061  /mnt/home/mbarbone/team-r5-shared/bins/genoa/ducc_bench-r5base
31625bc21b236271bc210a78fd8438dfbdccf46393015c3d0e45cafbcbfa0869  /mnt/home/mbarbone/team-r5-shared/bins/genoa/admiral_bench
```

## ratios (nd_reduce)

| cell | after | yesterday | mkl | fftw | ducc | max/min after | after2/after | adm/yesterday | adm/mkl | adm/fftw | adm/ducc | adm/best | leader |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2d_16 | 346.9 | 401.1 | 825.3 | 216.9 | 977.2 | 1.086 | 0.9998 | 0.865 | 0.420 | 1.599 | 0.355 | 1.599 | fftw |
| 2d_32 | 1389 | 1700 | 3274 | 1065 | 3351 | 1.035 | 1.0015 | 0.817 | 0.424 | 1.305 | 0.415 | 1.305 | fftw |
| 2d_64 | 8076 | 8096 | 1.568e+04 | 7410 | 1.92e+04 | 1.120 | 0.9997 | 0.998 | 0.515 | 1.090 | 0.421 | 1.090 | fftw |
| 2d_128 | 3.561e+04 | 3.471e+04 | 6.637e+04 | 3.679e+04 | 4.599e+04 | 1.160 | 1.1348 | 1.026 | 0.536 | 0.968 | 0.774 | 0.968 | fftw |
| 2d_256 | 1.633e+05 | 1.665e+05 | 3.319e+05 | 2.036e+05 | 2.507e+05 | 1.189 | 0.9914 | 0.981 | 0.492 | 0.802 | 0.651 | 0.802 | fftw |
| 2d_512 | 9.324e+05 | 7.978e+05 | 1.588e+06 | 8.943e+05 | 1.207e+06 | 1.061 | 0.8566 | 1.169 | 0.587 | 1.043 | 0.772 | 1.043 | fftw |
| 2d_1024 | 3.687e+06 | 4.184e+06 | 7.877e+06 | 4.463e+06 | 5.011e+06 | 1.366 | 0.9717 | 0.881 | 0.468 | 0.826 | 0.736 | 0.826 | fftw |
| 2d_2048 | 2.687e+07 | 2.721e+07 | 4.419e+07 | 2.964e+07 | 2.791e+07 | 1.103 | 0.9870 | 0.988 | 0.608 | 0.907 | 0.963 | 0.963 | ducc |
| 2d_4096 | 1.145e+08 | 1.135e+08 | 2.524e+08 | 1.405e+08 | 1.243e+08 | 1.034 | 0.9981 | 1.008 | 0.454 | 0.815 | 0.921 | 0.921 | ducc |
| 2d_8192 | 5.528e+08 | 5.572e+08 | 1.809e+09 | 5.966e+08 | 5.8e+08 | 1.006 | 1.0026 | 0.992 | 0.306 | 0.927 | 0.953 | 0.953 | ducc |
| 3d_4 | 187.8 | 216.8 | 855.4 | 86.59 | 1035 | 1.032 | 1.0006 | 0.866 | 0.220 | 2.169 | 0.181 | 2.169 | fftw |
| 3d_8 | 798 | 998.5 | 3231 | 569.8 | 2819 | 1.040 | 0.9999 | 0.799 | 0.247 | 1.401 | 0.283 | 1.401 | fftw |
| 3d_16 | 8342 | 9327 | 1.933e+04 | 7972 | 2.282e+04 | 1.043 | 0.9928 | 0.894 | 0.431 | 1.046 | 0.366 | 1.046 | fftw |
| 3d_32 | 6.404e+04 | 7.38e+04 | 1.414e+05 | 8e+04 | 1.661e+05 | 1.015 | 0.9937 | 0.868 | 0.453 | 0.801 | 0.386 | 0.801 | fftw |
| 3d_64 | 7.571e+05 | 7.289e+05 | 1.728e+06 | 9.064e+05 | 1.417e+06 | 1.012 | 0.9083 | 1.039 | 0.438 | 0.835 | 0.534 | 0.835 | fftw |
| 3d_128 | 1.124e+07 | 1.043e+07 | 1.543e+07 | 1.157e+07 | 1.43e+07 | 1.009 | 1.0007 | 1.077 | 0.728 | 0.971 | 0.785 | 0.971 | fftw |
| 3d_256 | 1.3e+08 | 1.264e+08 | 1.716e+08 | 1.347e+08 | 1.416e+08 | 1.097 | 0.9971 | 1.029 | 0.757 | 0.965 | 0.918 | 0.965 | fftw |
| 3d_512 | 1.618e+09 | 1.631e+09 | 1.485e+09 | 1.164e+09 | 1.228e+09 | 1.052 | 0.9998 | 0.992 | 1.090 | 1.390 | 1.318 | 1.390 | fftw |

after: worst |cpu/real - 1| over cells = 0.0047
yesterday: worst |cpu/real - 1| over cells = 0.0045
mkl: worst |cpu/real - 1| over cells = 0.0041
fftw: worst |cpu/real - 1| over cells = 0.0048
ducc: worst |cpu/real - 1| over cells = 0.0046

## verdicts

| cell | adm/best | eps | verdict | leader |
|---|---|---|---|---|
| 2d_16 | 1.599 | 0.0001853 | LOSS | fftw |
| 2d_32 | 1.305 | 0.001508 | LOSS | fftw |
| 2d_64 | 1.09 | 0.0002942 | LOSS | fftw |
| 2d_128 | 0.968 | 0.1348 | TIE | fftw |
| 2d_256 | 0.8022 | 0.008553 | WIN | fftw |
| 2d_512 | 1.043 | 0.1434 | TIE | fftw |
| 2d_1024 | 0.826 | 0.02829 | WIN | fftw |
| 2d_2048 | 0.9628 | 0.01301 | WIN | ducc |
| 2d_4096 | 0.9208 | 0.001916 | WIN | ducc |
| 2d_8192 | 0.9531 | 0.002588 | WIN | ducc |
| 3d_4 | 2.169 | 0.0006365 | LOSS | fftw |
| 3d_8 | 1.401 | 0.0001237 | LOSS | fftw |
| 3d_16 | 1.046 | 0.007163 | LOSS | fftw |
| 3d_32 | 0.8005 | 0.006314 | WIN | fftw |
| 3d_64 | 0.8353 | 0.09168 | WIN | fftw |
| 3d_128 | 0.971 | 0.0006691 | WIN | fftw |
| 3d_256 | 0.9651 | 0.002902 | WIN | fftw |
| 3d_512 | 1.39 | 0.0001605 | LOSS | fftw |

**WIN 9 / TIE 2 / LOSS 7**

Raw TSV: /mnt/home/mbarbone/team-r5-shared/standings/raw/genoa/measure.tsv
