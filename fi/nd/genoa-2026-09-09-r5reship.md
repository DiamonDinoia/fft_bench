# fft_bench N-D standings, genoa, 2026-09-09, admiral @ b9a2bdfe7dcdbf4d2a653c2477810435bfb7d9f0 (reship)

Single thread, complex f64 forward oop, ns/transform, min over interleaved rounds, arm order rotated, one core pinned. Job 7008487.
Reduced with /mnt/home/mbarbone/team-r5-shared/fft_bench-jobs/nd_reduce.py; verdicts by /mnt/home/mbarbone/team-r5-shared/tools/nd_gen_standings.py (full precision, printed 4 sig figs).
Era control (codex rule 12): yesterday = staged staged r5base admiral_bench, binary of admiral 017e132440a2900ae6dbf14f6a7a6e308ac51c46 (master tip at round-5 dispatch, built by the D1 wave 2026-09-08); byte-compile of the master-era source, reads the fix delta as well as era. It is a ratio column only; best/verdicts range over mkl/fftw/ducc.

## binaries (staged, sha256)

```
d32b5909998c82fd23d7e4b3e7405e35c92995f94c3d428a5f12c65997f511b8  /mnt/home/mbarbone/team-r5-shared/bins/genoa/admiral_bench-r5reship
25a50446fc53482713eb1a69b92290dcf4259a589a1364a9f40dd57bc9fbfadb  /mnt/home/mbarbone/team-r5-shared/bins/genoa/mkl_bench-r5reship
3d6f2c768e3b30f48706690628c6f15614054db57a376028f79ce0cd0f3149e6  /mnt/home/mbarbone/team-r5-shared/bins/genoa/fftw3_bench-r5reship
eca518261c8f6142c436db70193d266323e1a269bb2451b212b26601e87bfe32  /mnt/home/mbarbone/team-r5-shared/bins/genoa/ducc_bench-r5reship
87d9534eab1cd652e00b1d23cde7cb7e8c0ce0e57b2fa307cd6ca5d3d1221dc0  /mnt/home/mbarbone/team-r5-shared/bins/genoa/admiral_bench-r5base
```

## ratios (nd_reduce)

| cell | reship | yesterday | mkl | fftw | ducc | max/min reship | reship2/reship | adm/yesterday | adm/mkl | adm/fftw | adm/ducc | adm/best | leader |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2d_16 | 346.9 | 347.6 | 823.8 | 217.6 | 982.8 | 1.077 | 1.0021 | 0.998 | 0.421 | 1.594 | 0.353 | 1.594 | fftw |
| 2d_32 | 1390 | 1386 | 3271 | 1052 | 3362 | 1.074 | 1.0025 | 1.002 | 0.425 | 1.321 | 0.413 | 1.321 | fftw |
| 2d_64 | 8067 | 7971 | 1.571e+04 | 7432 | 1.924e+04 | 1.031 | 1.0050 | 1.012 | 0.514 | 1.085 | 0.419 | 1.085 | fftw |
| 2d_128 | 3.526e+04 | 3.598e+04 | 6.616e+04 | 3.63e+04 | 4.593e+04 | 1.119 | 1.0077 | 0.980 | 0.533 | 0.971 | 0.768 | 0.971 | fftw |
| 2d_256 | 1.567e+05 | 1.616e+05 | 3.33e+05 | 2.072e+05 | 2.512e+05 | 1.241 | 0.9717 | 0.970 | 0.471 | 0.756 | 0.624 | 0.756 | fftw |
| 2d_512 | 7.247e+05 | 8.354e+05 | 1.576e+06 | 8.942e+05 | 1.212e+06 | 1.352 | 1.0023 | 0.868 | 0.460 | 0.811 | 0.598 | 0.811 | fftw |
| 2d_1024 | 4.117e+06 | 3.609e+06 | 7.972e+06 | 4.326e+06 | 5.049e+06 | 1.072 | 0.8933 | 1.141 | 0.516 | 0.952 | 0.816 | 0.952 | fftw |
| 2d_2048 | 2.294e+07 | 2.658e+07 | 4.469e+07 | 2.972e+07 | 2.847e+07 | 1.212 | 1.0095 | 0.863 | 0.513 | 0.772 | 0.806 | 0.806 | ducc |
| 2d_4096 | 9.603e+07 | 1.155e+08 | 2.512e+08 | 1.414e+08 | 1.247e+08 | 1.194 | 0.9888 | 0.832 | 0.382 | 0.679 | 0.770 | 0.770 | ducc |
| 2d_8192 | 4.922e+08 | 5.573e+08 | 1.806e+09 | 6.034e+08 | 5.824e+08 | 1.004 | 1.0031 | 0.883 | 0.272 | 0.816 | 0.845 | 0.845 | ducc |
| 3d_4 | 190.1 | 190.2 | 858.5 | 86.29 | 1042 | 1.013 | 0.9997 | 0.999 | 0.221 | 2.203 | 0.183 | 2.203 | fftw |
| 3d_8 | 796.1 | 823.4 | 3232 | 564.7 | 2868 | 1.012 | 1.0004 | 0.967 | 0.246 | 1.410 | 0.278 | 1.410 | fftw |
| 3d_16 | 8296 | 8440 | 1.925e+04 | 7970 | 2.286e+04 | 1.024 | 1.0051 | 0.983 | 0.431 | 1.041 | 0.363 | 1.041 | fftw |
| 3d_32 | 6.392e+04 | 6.407e+04 | 1.407e+05 | 7.941e+04 | 1.66e+05 | 1.009 | 0.9955 | 0.998 | 0.454 | 0.805 | 0.385 | 0.805 | fftw |
| 3d_64 | 7.27e+05 | 6.812e+05 | 1.723e+06 | 9.094e+05 | 1.416e+06 | 1.013 | 0.9969 | 1.067 | 0.422 | 0.799 | 0.513 | 0.799 | fftw |
| 3d_128 | 9.901e+06 | 1.087e+07 | 1.545e+07 | 1.132e+07 | 1.427e+07 | 1.073 | 0.9984 | 0.911 | 0.641 | 0.875 | 0.694 | 0.875 | fftw |
| 3d_256 | 1.254e+08 | 1.389e+08 | 1.711e+08 | 1.347e+08 | 1.415e+08 | 1.053 | 0.9745 | 0.903 | 0.733 | 0.931 | 0.886 | 0.931 | fftw |
| 3d_512 | 1.564e+09 | 1.657e+09 | 1.485e+09 | 1.201e+09 | 1.224e+09 | 1.026 | 0.9987 | 0.944 | 1.053 | 1.302 | 1.277 | 1.302 | fftw |

reship: worst |cpu/real - 1| over cells = 0.0053
yesterday: worst |cpu/real - 1| over cells = 0.0063
mkl: worst |cpu/real - 1| over cells = 0.0044
fftw: worst |cpu/real - 1| over cells = 0.0049
ducc: worst |cpu/real - 1| over cells = 0.0046

## verdicts

| cell | adm/best | eps | verdict | leader |
|---|---|---|---|---|
| 2d_16 | 1.594 | 0.002055 | LOSS | fftw |
| 2d_32 | 1.321 | 0.002512 | LOSS | fftw |
| 2d_64 | 1.085 | 0.00496 | LOSS | fftw |
| 2d_128 | 0.9714 | 0.007716 | WIN | fftw |
| 2d_256 | 0.7564 | 0.02825 | WIN | fftw |
| 2d_512 | 0.8105 | 0.00229 | WIN | fftw |
| 2d_1024 | 0.9517 | 0.1067 | TIE | fftw |
| 2d_2048 | 0.8058 | 0.00952 | WIN | ducc |
| 2d_4096 | 0.7699 | 0.01116 | WIN | ducc |
| 2d_8192 | 0.8452 | 0.003089 | WIN | ducc |
| 3d_4 | 2.203 | 0.000288 | LOSS | fftw |
| 3d_8 | 1.41 | 0.0004371 | LOSS | fftw |
| 3d_16 | 1.041 | 0.005078 | LOSS | fftw |
| 3d_32 | 0.8049 | 0.004452 | WIN | fftw |
| 3d_64 | 0.7994 | 0.003079 | WIN | fftw |
| 3d_128 | 0.8746 | 0.001608 | WIN | fftw |
| 3d_256 | 0.9311 | 0.02547 | WIN | fftw |
| 3d_512 | 1.302 | 0.001315 | LOSS | fftw |

**WIN 10 / TIE 1 / LOSS 7**

Raw TSV: /mnt/home/mbarbone/team-r5-shared/standings/raw-reship/genoa/measure.tsv
