# fft_bench N-D standings, icelake, 2026-09-08, admiral @ 017e132440a2900ae6dbf14f6a7a6e308ac51c46 (after)

Single thread, complex f64 forward oop, ns/transform, min over interleaved rounds, arm order rotated, one core pinned. Job 7002700.
Reduced with /mnt/home/mbarbone/team-r5-shared/fft_bench-jobs/nd_reduce.py; verdicts by /mnt/home/mbarbone/team-r5-shared/tools/nd_gen_standings.py (full precision, printed 4 sig figs).
Era control (codex rule 12): yesterday = staged closed-campaign after-era build, admiral @ c4c3911235e8e20636f9be471efd4d9717852c8a (2026-09-06), hash-verified vs team-nddiag standings/*-after.md records. It is a ratio column only; best/verdicts range over mkl/fftw/ducc.

## binaries (staged, sha256)

```
884c1a85ae3bbd37b4fae149fcf7af1c261854d70a45a5851574c9ac8f9b9d16  /mnt/home/mbarbone/team-r5-shared/bins/icelake/admiral_bench-r5base
ec29a14149b8823bfb81443bd34be94d6577a3f8e4a79e8bedc44debc2b44d44  /mnt/home/mbarbone/team-r5-shared/bins/icelake/mkl_bench-r5base
d1dc25e787d3f4b44a20edb3260709a301813b4233826555d979dadc98e9af52  /mnt/home/mbarbone/team-r5-shared/bins/icelake/fftw3_bench-r5base
3f22c1779f334247f0a898cd3947a163b4867484cb1c031b4b352db4da40726d  /mnt/home/mbarbone/team-r5-shared/bins/icelake/ducc_bench-r5base
c97355be7fcb2eab57c14152a39d21936e6e725970ec5b48ec4a63c4d4c9cf87  /mnt/home/mbarbone/team-r5-shared/bins/icelake/admiral_bench
```

## ratios (nd_reduce)

| cell | after | yesterday | mkl | fftw | ducc | max/min after | after2/after | adm/yesterday | adm/mkl | adm/fftw | adm/ducc | adm/best | leader |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2d_16 | 405 | 510.5 | 189.7 | 281.8 | 1425 | 1.001 | 1.0001 | 0.793 | 2.135 | 1.437 | 0.284 | 2.135 | mkl |
| 2d_32 | 1618 | 2067 | 1093 | 1458 | 4299 | 1.004 | 0.9996 | 0.783 | 1.480 | 1.110 | 0.376 | 1.480 | mkl |
| 2d_64 | 9696 | 9655 | 6244 | 9070 | 1.786e+04 | 1.007 | 0.9989 | 1.004 | 1.553 | 1.069 | 0.543 | 1.553 | mkl |
| 2d_128 | 4.552e+04 | 4.214e+04 | 2.853e+04 | 4.982e+04 | 7.809e+04 | 1.148 | 0.9948 | 1.080 | 1.596 | 0.914 | 0.583 | 1.596 | mkl |
| 2d_256 | 2.898e+05 | 2.343e+05 | 1.706e+05 | 3.037e+05 | 3.983e+05 | 1.012 | 1.0042 | 1.237 | 1.699 | 0.954 | 0.728 | 1.699 | mkl |
| 2d_512 | 1.26e+06 | 1.427e+06 | 9.997e+05 | 1.535e+06 | 1.906e+06 | 1.140 | 0.9955 | 0.883 | 1.260 | 0.821 | 0.661 | 1.260 | mkl |
| 2d_1024 | 4.894e+06 | 6.929e+06 | 4.763e+06 | 6.495e+06 | 7.769e+06 | 1.010 | 0.9976 | 0.706 | 1.027 | 0.753 | 0.630 | 1.027 | mkl |
| 2d_2048 | 4.406e+07 | 4.072e+07 | 3.77e+07 | 4.557e+07 | 5.485e+07 | 1.008 | 0.9215 | 1.082 | 1.169 | 0.967 | 0.803 | 1.169 | mkl |
| 2d_4096 | 1.756e+08 | 1.741e+08 | 1.886e+08 | 2.084e+08 | 2.761e+08 | 1.005 | 0.9978 | 1.009 | 0.931 | 0.843 | 0.636 | 0.931 | mkl |
| 2d_8192 | 7.327e+08 | 7.306e+08 | 7.246e+08 | 9.035e+08 | 1.145e+09 | 1.013 | 0.9988 | 1.003 | 1.011 | 0.811 | 0.640 | 1.011 | mkl |
| 3d_4 | 258.2 | 325 | 79.55 | 119.3 | 1368 | 1.001 | 0.9996 | 0.794 | 3.246 | 2.165 | 0.189 | 3.246 | mkl |
| 3d_8 | 1370 | 1362 | 487.6 | 733.8 | 3819 | 1.001 | 1.0005 | 1.006 | 2.810 | 1.867 | 0.359 | 2.810 | mkl |
| 3d_16 | 1.099e+04 | 1.078e+04 | 5669 | 1.028e+04 | 2.685e+04 | 1.031 | 0.9937 | 1.019 | 1.938 | 1.069 | 0.409 | 1.938 | mkl |
| 3d_32 | 8.244e+04 | 9.518e+04 | 6.443e+04 | 1.029e+05 | 2.236e+05 | 1.030 | 0.9970 | 0.866 | 1.280 | 0.802 | 0.369 | 1.280 | mkl |
| 3d_64 | 9.566e+05 | 1.11e+06 | 1.087e+06 | 1.321e+06 | 2.059e+06 | 1.194 | 1.0017 | 0.862 | 0.880 | 0.724 | 0.465 | 0.880 | mkl |
| 3d_128 | 1.357e+07 | 1.356e+07 | 1.052e+07 | 1.582e+07 | 1.981e+07 | 1.042 | 0.9926 | 1.001 | 1.290 | 0.858 | 0.685 | 1.290 | mkl |
| 3d_256 | 1.972e+08 | 2.002e+08 | 1.812e+08 | 2.074e+08 | 2.574e+08 | 1.013 | 0.9949 | 0.985 | 1.088 | 0.951 | 0.766 | 1.088 | mkl |
| 3d_512 | 1.855e+09 | 1.848e+09 | 2.299e+09 | 2.056e+09 | 2.385e+09 | 1.023 | 1.0140 | 1.004 | 0.807 | 0.902 | 0.778 | 0.902 | fftw |

after: worst |cpu/real - 1| over cells = 0.0039
yesterday: worst |cpu/real - 1| over cells = 0.0038
mkl: worst |cpu/real - 1| over cells = 0.0037
fftw: worst |cpu/real - 1| over cells = 0.0038
ducc: worst |cpu/real - 1| over cells = 0.0034

## verdicts

| cell | adm/best | eps | verdict | leader |
|---|---|---|---|---|
| 2d_16 | 2.135 | 5.356e-05 | LOSS | mkl |
| 2d_32 | 1.48 | 0.0003685 | LOSS | mkl |
| 2d_64 | 1.553 | 0.001097 | LOSS | mkl |
| 2d_128 | 1.596 | 0.00523 | LOSS | mkl |
| 2d_256 | 1.699 | 0.004212 | LOSS | mkl |
| 2d_512 | 1.26 | 0.004468 | LOSS | mkl |
| 2d_1024 | 1.027 | 0.002439 | LOSS | mkl |
| 2d_2048 | 1.169 | 0.07849 | LOSS | mkl |
| 2d_4096 | 0.9311 | 0.002228 | WIN | mkl |
| 2d_8192 | 1.011 | 0.001175 | LOSS | mkl |
| 3d_4 | 3.246 | 0.0003678 | LOSS | mkl |
| 3d_8 | 2.81 | 0.0004694 | LOSS | mkl |
| 3d_16 | 1.938 | 0.006318 | LOSS | mkl |
| 3d_32 | 1.28 | 0.003015 | LOSS | mkl |
| 3d_64 | 0.8801 | 0.001735 | WIN | mkl |
| 3d_128 | 1.29 | 0.007396 | LOSS | mkl |
| 3d_256 | 1.088 | 0.005103 | LOSS | mkl |
| 3d_512 | 0.9023 | 0.01401 | WIN | fftw |

**WIN 3 / TIE 0 / LOSS 15**

Raw TSV: /mnt/home/mbarbone/team-r5-shared/standings/raw/icelake/measure.tsv
