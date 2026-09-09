# fft_bench N-D standings, rome, 2026-09-09, admiral @ b9a2bdfe7dcdbf4d2a653c2477810435bfb7d9f0 (reship)

Single thread, complex f64 forward oop, ns/transform, min over interleaved rounds, arm order rotated, one core pinned. Job 7008488.
Reduced with /mnt/home/mbarbone/team-r5-shared/fft_bench-jobs/nd_reduce.py; verdicts by /mnt/home/mbarbone/team-r5-shared/tools/nd_gen_standings.py (full precision, printed 4 sig figs).
Era control (codex rule 12): yesterday = staged staged r5base admiral_bench, binary of admiral 017e132440a2900ae6dbf14f6a7a6e308ac51c46 (master tip at round-5 dispatch, built by the D1 wave 2026-09-08); byte-compile of the master-era source, reads the fix delta as well as era. It is a ratio column only; best/verdicts range over mkl/fftw/ducc.

## binaries (staged, sha256)

```
c54d4c7a96ef8337c3c31853a83eb7c09ea545eee0cbd092dcb0f2eb13fd8439  /mnt/home/mbarbone/team-r5-shared/bins/rome/admiral_bench-r5reship
43926b08f9009e93eccc756aa9e3f679f9fecbc925c698b4170f86eff4451972  /mnt/home/mbarbone/team-r5-shared/bins/rome/mkl_bench-r5reship
6e20a443f865ec2576874c50fc25fc7fc1c87ae5b020dc841b45f1916de8226e  /mnt/home/mbarbone/team-r5-shared/bins/rome/fftw3_bench-r5reship
61d8f134a4c1eb60400dd04dc8213ff2027482dacca6eb15fd8fe0f83c2d8423  /mnt/home/mbarbone/team-r5-shared/bins/rome/ducc_bench-r5reship
3a1c27cfd0083765cc8819d227509dc493c38f928b1e6b43462fc6c33eaeb6e9  /mnt/home/mbarbone/team-r5-shared/bins/rome/admiral_bench-r5base
```

## ratios (nd_reduce)

| cell | reship | yesterday | mkl | fftw | ducc | max/min reship | reship2/reship | adm/yesterday | adm/mkl | adm/fftw | adm/ducc | adm/best | leader |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2d_16 | 616.5 | 615.8 | 1571 | 430.5 | 1754 | 1.006 | 0.9995 | 1.001 | 0.392 | 1.432 | 0.351 | 1.432 | fftw |
| 2d_32 | 3335 | 3368 | 6400 | 1972 | 5723 | 1.011 | 1.0049 | 0.990 | 0.521 | 1.691 | 0.583 | 1.691 | fftw |
| 2d_64 | 1.34e+04 | 1.343e+04 | 2.654e+04 | 1.072e+04 | 2.012e+04 | 1.004 | 1.0006 | 0.998 | 0.505 | 1.251 | 0.666 | 1.251 | fftw |
| 2d_128 | 6.52e+04 | 6.588e+04 | 1.098e+05 | 6.388e+04 | 7.423e+04 | 1.012 | 1.0024 | 0.990 | 0.594 | 1.021 | 0.878 | 1.021 | fftw |
| 2d_256 | 3.135e+05 | 3.129e+05 | 5.332e+05 | 3.208e+05 | 4.055e+05 | 1.016 | 0.9964 | 1.002 | 0.588 | 0.977 | 0.773 | 0.977 | fftw |
| 2d_512 | 1.347e+06 | 1.345e+06 | 2.37e+06 | 1.381e+06 | 1.755e+06 | 1.005 | 0.9975 | 1.001 | 0.568 | 0.975 | 0.767 | 0.975 | fftw |
| 2d_1024 | 8.843e+06 | 8.915e+06 | 1.23e+07 | 9.307e+06 | 8.251e+06 | 1.015 | 1.0037 | 0.992 | 0.719 | 0.950 | 1.072 | 1.072 | ducc |
| 2d_2048 | 4.009e+07 | 4.352e+07 | 8.327e+07 | 4.835e+07 | 6.239e+07 | 1.009 | 1.0049 | 0.921 | 0.481 | 0.829 | 0.643 | 0.829 | fftw |
| 2d_4096 | 1.774e+08 | 1.968e+08 | 8.332e+08 | 2.008e+08 | 2.808e+08 | 1.010 | 1.0025 | 0.902 | 0.213 | 0.884 | 0.632 | 0.884 | fftw |
| 2d_8192 | 7.91e+08 | 8.893e+08 | 3.433e+09 | 8.857e+08 | 1.166e+09 | 1.011 | 0.9986 | 0.889 | 0.230 | 0.893 | 0.678 | 0.893 | fftw |
| 3d_4 | 313.4 | 317.8 | 1745 | 140 | 1795 | 1.003 | 1.0012 | 0.986 | 0.180 | 2.238 | 0.175 | 2.238 | fftw |
| 3d_8 | 1649 | 1717 | 6106 | 1142 | 5288 | 1.005 | 0.9997 | 0.960 | 0.270 | 1.443 | 0.312 | 1.443 | fftw |
| 3d_16 | 1.354e+04 | 1.359e+04 | 3.312e+04 | 1.326e+04 | 3.015e+04 | 1.004 | 1.0006 | 0.996 | 0.409 | 1.022 | 0.449 | 1.022 | fftw |
| 3d_32 | 1.548e+05 | 1.612e+05 | 2.369e+05 | 1.323e+05 | 2.698e+05 | 1.008 | 1.0039 | 0.960 | 0.653 | 1.170 | 0.574 | 1.170 | fftw |
| 3d_64 | 1.415e+06 | 1.422e+06 | 2.729e+06 | 1.372e+06 | 2.128e+06 | 1.012 | 0.9987 | 0.995 | 0.518 | 1.031 | 0.665 | 1.031 | fftw |
| 3d_128 | 2.361e+07 | 2.332e+07 | 4.119e+07 | 1.971e+07 | 3.5e+07 | 1.015 | 1.0027 | 1.013 | 0.573 | 1.198 | 0.675 | 1.198 | fftw |
| 3d_256 | 2.174e+08 | 2.166e+08 | 3.859e+08 | 2.149e+08 | 3.046e+08 | 1.031 | 0.9990 | 1.004 | 0.563 | 1.012 | 0.714 | 1.012 | fftw |
| 3d_512 | 1.973e+09 | 2.025e+09 | 3.361e+09 | 1.968e+09 | 2.504e+09 | 1.010 | 0.9989 | 0.974 | 0.587 | 1.002 | 0.788 | 1.002 | fftw |

reship: worst |cpu/real - 1| over cells = 0.0066
yesterday: worst |cpu/real - 1| over cells = 0.0065
mkl: worst |cpu/real - 1| over cells = 0.0048
fftw: worst |cpu/real - 1| over cells = 0.0067
ducc: worst |cpu/real - 1| over cells = 0.0066

## verdicts

| cell | adm/best | eps | verdict | leader |
|---|---|---|---|---|
| 2d_16 | 1.432 | 0.0004874 | LOSS | fftw |
| 2d_32 | 1.691 | 0.004903 | LOSS | fftw |
| 2d_64 | 1.251 | 0.0006447 | LOSS | fftw |
| 2d_128 | 1.021 | 0.002392 | LOSS | fftw |
| 2d_256 | 0.9771 | 0.003575 | WIN | fftw |
| 2d_512 | 0.9752 | 0.002532 | WIN | fftw |
| 2d_1024 | 1.072 | 0.003725 | LOSS | ducc |
| 2d_2048 | 0.8291 | 0.004895 | WIN | fftw |
| 2d_4096 | 0.8835 | 0.002514 | WIN | fftw |
| 2d_8192 | 0.893 | 0.001428 | WIN | fftw |
| 3d_4 | 2.238 | 0.001153 | LOSS | fftw |
| 3d_8 | 1.443 | 0.0002646 | LOSS | fftw |
| 3d_16 | 1.022 | 0.0005836 | LOSS | fftw |
| 3d_32 | 1.17 | 0.003866 | LOSS | fftw |
| 3d_64 | 1.031 | 0.001266 | LOSS | fftw |
| 3d_128 | 1.198 | 0.002727 | LOSS | fftw |
| 3d_256 | 1.012 | 0.001042 | LOSS | fftw |
| 3d_512 | 1.002 | 0.001059 | LOSS | fftw |

**WIN 5 / TIE 0 / LOSS 13**

Raw TSV: /mnt/home/mbarbone/team-r5-shared/standings/raw-reship/rome/measure.tsv
