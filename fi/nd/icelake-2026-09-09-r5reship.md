# fft_bench N-D standings, icelake, 2026-09-09, admiral @ b9a2bdfe7dcdbf4d2a653c2477810435bfb7d9f0 (reship)

Single thread, complex f64 forward oop, ns/transform, min over interleaved rounds, arm order rotated, one core pinned. Job 7008489.
Reduced with /mnt/home/mbarbone/team-r5-shared/fft_bench-jobs/nd_reduce.py; verdicts by /mnt/home/mbarbone/team-r5-shared/tools/nd_gen_standings.py (full precision, printed 4 sig figs).
Era control (codex rule 12): yesterday = staged staged r5base admiral_bench, binary of admiral 017e132440a2900ae6dbf14f6a7a6e308ac51c46 (master tip at round-5 dispatch, built by the D1 wave 2026-09-08); byte-compile of the master-era source, reads the fix delta as well as era. It is a ratio column only; best/verdicts range over mkl/fftw/ducc.

## binaries (staged, sha256)

```
3a78b6972821fab9ac1ef918e36a3b3f8700a3ebab5eab34d43f8e97498fad8f  /mnt/home/mbarbone/team-r5-shared/bins/icelake/admiral_bench-r5reship
ec29a14149b8823bfb81443bd34be94d6577a3f8e4a79e8bedc44debc2b44d44  /mnt/home/mbarbone/team-r5-shared/bins/icelake/mkl_bench-r5reship
d1dc25e787d3f4b44a20edb3260709a301813b4233826555d979dadc98e9af52  /mnt/home/mbarbone/team-r5-shared/bins/icelake/fftw3_bench-r5reship
c88f94b988c36e9783ac6e1e8c0f08ebd0bea9857039e753c8d2e831b43eb611  /mnt/home/mbarbone/team-r5-shared/bins/icelake/ducc_bench-r5reship
884c1a85ae3bbd37b4fae149fcf7af1c261854d70a45a5851574c9ac8f9b9d16  /mnt/home/mbarbone/team-r5-shared/bins/icelake/admiral_bench-r5base
```

## ratios (nd_reduce)

| cell | reship | yesterday | mkl | fftw | ducc | max/min reship | reship2/reship | adm/yesterday | adm/mkl | adm/fftw | adm/ducc | adm/best | leader |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2d_16 | 404.9 | 405.2 | 189.7 | 277.3 | 1420 | 1.004 | 1.0001 | 0.999 | 2.134 | 1.460 | 0.285 | 2.134 | mkl |
| 2d_32 | 1621 | 1618 | 1093 | 1605 | 4295 | 1.002 | 1.0001 | 1.002 | 1.483 | 1.010 | 0.377 | 1.483 | mkl |
| 2d_64 | 9653 | 9688 | 6261 | 8916 | 1.789e+04 | 1.010 | 0.9945 | 0.996 | 1.542 | 1.083 | 0.540 | 1.542 | mkl |
| 2d_128 | 4.789e+04 | 5.081e+04 | 2.848e+04 | 5.031e+04 | 7.812e+04 | 1.053 | 1.0401 | 0.942 | 1.681 | 0.952 | 0.613 | 1.681 | mkl |
| 2d_256 | 2.66e+05 | 2.713e+05 | 1.751e+05 | 3.218e+05 | 4.005e+05 | 1.071 | 0.9840 | 0.980 | 1.519 | 0.826 | 0.664 | 1.519 | mkl |
| 2d_512 | 1.379e+06 | 1.449e+06 | 1.01e+06 | 1.559e+06 | 1.914e+06 | 1.118 | 1.0130 | 0.951 | 1.366 | 0.885 | 0.720 | 1.366 | mkl |
| 2d_1024 | 6.458e+06 | 6.519e+06 | 4.796e+06 | 6.699e+06 | 7.789e+06 | 1.056 | 1.0085 | 0.991 | 1.347 | 0.964 | 0.829 | 1.347 | mkl |
| 2d_2048 | 3.711e+07 | 4.086e+07 | 3.789e+07 | 4.558e+07 | 5.487e+07 | 1.100 | 0.9992 | 0.908 | 0.980 | 0.814 | 0.676 | 0.980 | mkl |
| 2d_4096 | 1.74e+08 | 1.765e+08 | 1.911e+08 | 2.096e+08 | 2.775e+08 | 1.010 | 0.9964 | 0.986 | 0.910 | 0.830 | 0.627 | 0.910 | mkl |
| 2d_8192 | 7.528e+08 | 7.41e+08 | 7.306e+08 | 9.061e+08 | 1.156e+09 | 1.017 | 1.0002 | 1.016 | 1.030 | 0.831 | 0.651 | 1.030 | mkl |
| 3d_4 | 263 | 256.5 | 79.49 | 121.8 | 1368 | 1.001 | 1.0001 | 1.025 | 3.309 | 2.159 | 0.192 | 3.309 | mkl |
| 3d_8 | 1372 | 1342 | 487.6 | 728.6 | 3821 | 1.023 | 1.0008 | 1.022 | 2.813 | 1.883 | 0.359 | 2.813 | mkl |
| 3d_16 | 9071 | 9066 | 5694 | 1.018e+04 | 2.708e+04 | 1.014 | 1.0040 | 1.001 | 1.593 | 0.891 | 0.335 | 1.593 | mkl |
| 3d_32 | 8.221e+04 | 8.27e+04 | 6.47e+04 | 1.007e+05 | 2.244e+05 | 1.020 | 1.0048 | 0.994 | 1.270 | 0.816 | 0.366 | 1.270 | mkl |
| 3d_64 | 1.059e+06 | 1.057e+06 | 1.092e+06 | 1.335e+06 | 2.065e+06 | 1.079 | 0.9933 | 1.002 | 0.970 | 0.794 | 0.513 | 0.970 | mkl |
| 3d_128 | 1.315e+07 | 1.373e+07 | 1.06e+07 | 1.554e+07 | 1.991e+07 | 1.094 | 0.9987 | 0.958 | 1.241 | 0.846 | 0.660 | 1.241 | mkl |
| 3d_256 | 2.004e+08 | 1.979e+08 | 1.821e+08 | 2.011e+08 | 2.574e+08 | 1.005 | 0.9997 | 1.012 | 1.100 | 0.996 | 0.779 | 1.100 | mkl |
| 3d_512 | 1.817e+09 | 1.857e+09 | 2.306e+09 | 2.006e+09 | 2.388e+09 | 1.017 | 1.0005 | 0.979 | 0.788 | 0.906 | 0.761 | 0.906 | fftw |

reship: worst |cpu/real - 1| over cells = 0.0041
yesterday: worst |cpu/real - 1| over cells = 0.0038
mkl: worst |cpu/real - 1| over cells = 0.0037
fftw: worst |cpu/real - 1| over cells = 0.0037
ducc: worst |cpu/real - 1| over cells = 0.0035

## verdicts

| cell | adm/best | eps | verdict | leader |
|---|---|---|---|---|
| 2d_16 | 2.134 | 0.0001201 | LOSS | mkl |
| 2d_32 | 1.483 | 5.613e-05 | LOSS | mkl |
| 2d_64 | 1.542 | 0.005456 | LOSS | mkl |
| 2d_128 | 1.681 | 0.04009 | LOSS | mkl |
| 2d_256 | 1.519 | 0.01604 | LOSS | mkl |
| 2d_512 | 1.366 | 0.01299 | LOSS | mkl |
| 2d_1024 | 1.347 | 0.008511 | LOSS | mkl |
| 2d_2048 | 0.9796 | 0.0007749 | WIN | mkl |
| 2d_4096 | 0.9104 | 0.003567 | WIN | mkl |
| 2d_8192 | 1.03 | 0.0001764 | LOSS | mkl |
| 3d_4 | 3.309 | 6.667e-05 | LOSS | mkl |
| 3d_8 | 2.813 | 0.0008258 | LOSS | mkl |
| 3d_16 | 1.593 | 0.004029 | LOSS | mkl |
| 3d_32 | 1.27 | 0.004831 | LOSS | mkl |
| 3d_64 | 0.9699 | 0.006733 | WIN | mkl |
| 3d_128 | 1.241 | 0.001267 | LOSS | mkl |
| 3d_256 | 1.1 | 0.00035 | LOSS | mkl |
| 3d_512 | 0.9062 | 0.0005031 | WIN | fftw |

**WIN 4 / TIE 0 / LOSS 14**

Raw TSV: /mnt/home/mbarbone/team-r5-shared/standings/raw-reship/icelake/measure.tsv
