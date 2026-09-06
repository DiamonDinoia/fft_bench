# fft_bench N-D standings, rome, 2026-09-06, admiral @ c4c3911235e8e20636f9be471efd4d9717852c8a (after)

Single thread, complex f64 forward oop, ns/transform, min over interleaved rounds, arm order rotated, one core pinned. Job 6993682.
Reduced with fft_bench/fi/nd/nd_reduce.py; verdicts by /mnt/home/mbarbone/scratch/team-nddiag/tools/nd_gen_standings.py (full precision, printed 4 sig figs).

## binaries (staged, sha256)

```
a5d31b7bde2d6464fc54577ba86395c9e893597fd84d7d61cb8318feadacce2b  bins/rome/admiral_bench
43926b08f9009e93eccc756aa9e3f679f9fecbc925c698b4170f86eff4451972  bins/rome/mkl_bench
6e20a443f865ec2576874c50fc25fc7fc1c87ae5b020dc841b45f1916de8226e  bins/rome/fftw3_bench
7ae03eba43f43dfc380779e3ab86851e1d11ce4d544870b22d7509c7d09f19b7  bins/rome/ducc_bench
```

## ratios (nd_reduce)

| cell | after | mkl | fftw | ducc | max/min after | after2/after | adm/mkl | adm/fftw | adm/ducc | adm/best | leader |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 2d_16 | 757.6 | 1552 | 429 | 1754 | 1.005 | 0.9999 | 0.488 | 1.766 | 0.432 | 1.766 | fftw |
| 2d_32 | 3337 | 6377 | 1970 | 5706 | 1.002 | 1.0004 | 0.523 | 1.694 | 0.585 | 1.694 | fftw |
| 2d_64 | 1.381e+04 | 2.646e+04 | 1.077e+04 | 2.013e+04 | 1.010 | 0.9960 | 0.522 | 1.282 | 0.686 | 1.282 | fftw |
| 2d_128 | 6.667e+04 | 1.086e+05 | 6.317e+04 | 7.498e+04 | 1.008 | 1.0065 | 0.614 | 1.055 | 0.889 | 1.055 | fftw |
| 2d_256 | 3.138e+05 | 5.319e+05 | 3.202e+05 | 4.063e+05 | 1.027 | 1.0018 | 0.590 | 0.980 | 0.772 | 0.980 | fftw |
| 2d_512 | 1.374e+06 | 2.372e+06 | 1.384e+06 | 1.754e+06 | 1.007 | 0.9995 | 0.579 | 0.992 | 0.783 | 0.992 | fftw |
| 2d_1024 | 9.557e+06 | 1.204e+07 | 9.44e+06 | 8.066e+06 | 1.030 | 1.0048 | 0.794 | 1.012 | 1.185 | 1.185 | ducc |
| 2d_2048 | 4.308e+07 | 8.325e+07 | 4.724e+07 | 6.188e+07 | 1.007 | 0.9996 | 0.517 | 0.912 | 0.696 | 0.912 | fftw |
| 2d_4096 | 1.952e+08 | 8.431e+08 | 2.009e+08 | 2.778e+08 | 1.009 | 0.9994 | 0.232 | 0.972 | 0.703 | 0.972 | fftw |
| 2d_8192 | 8.85e+08 | 3.466e+09 | 8.737e+08 | 1.156e+09 | 1.004 | 0.9990 | 0.255 | 1.013 | 0.766 | 1.013 | fftw |
| 3d_4 | 358.4 | 1757 | 140.1 | 1796 | 1.003 | 0.9990 | 0.204 | 2.558 | 0.200 | 2.558 | fftw |
| 3d_8 | 1828 | 6092 | 1142 | 5283 | 1.008 | 0.9999 | 0.300 | 1.600 | 0.346 | 1.600 | fftw |
| 3d_16 | 1.607e+04 | 3.287e+04 | 1.319e+04 | 3.014e+04 | 1.009 | 0.9999 | 0.489 | 1.218 | 0.533 | 1.218 | fftw |
| 3d_32 | 1.589e+05 | 2.366e+05 | 1.312e+05 | 2.693e+05 | 1.018 | 1.0107 | 0.672 | 1.211 | 0.590 | 1.211 | fftw |
| 3d_64 | 1.367e+06 | 2.736e+06 | 1.365e+06 | 2.129e+06 | 1.008 | 0.9991 | 0.500 | 1.002 | 0.642 | 1.002 | fftw |
| 3d_128 | 2.367e+07 | 4.162e+07 | 1.964e+07 | 3.47e+07 | 1.017 | 1.0059 | 0.569 | 1.205 | 0.682 | 1.205 | fftw |
| 3d_256 | 2.152e+08 | 3.875e+08 | 2.128e+08 | 3.008e+08 | 1.021 | 1.0033 | 0.555 | 1.011 | 0.716 | 1.011 | fftw |
| 3d_512 | 1.894e+09 | 3.379e+09 | 1.956e+09 | 2.483e+09 | 1.032 | 1.0175 | 0.561 | 0.968 | 0.763 | 0.968 | fftw |

after: worst |cpu/real - 1| over cells = 0.0075
mkl: worst |cpu/real - 1| over cells = 0.0050
fftw: worst |cpu/real - 1| over cells = 0.0064
ducc: worst |cpu/real - 1| over cells = 0.0065

## verdicts

| cell | adm/best | eps | verdict | leader |
|---|---|---|---|---|
| 2d_16 | 1.766 | 6.672e-05 | LOSS | fftw |
| 2d_32 | 1.694 | 0.0003563 | LOSS | fftw |
| 2d_64 | 1.282 | 0.004019 | LOSS | fftw |
| 2d_128 | 1.055 | 0.006543 | LOSS | fftw |
| 2d_256 | 0.9801 | 0.001787 | WIN | fftw |
| 2d_512 | 0.9925 | 0.000473 | WIN | fftw |
| 2d_1024 | 1.185 | 0.004771 | LOSS | ducc |
| 2d_2048 | 0.9119 | 0.0003699 | WIN | fftw |
| 2d_4096 | 0.9719 | 0.0005985 | WIN | fftw |
| 2d_8192 | 1.013 | 0.0009733 | LOSS | fftw |
| 3d_4 | 2.558 | 0.0009984 | LOSS | fftw |
| 3d_8 | 1.6 | 9.196e-05 | LOSS | fftw |
| 3d_16 | 1.218 | 9.4e-05 | LOSS | fftw |
| 3d_32 | 1.211 | 0.01065 | LOSS | fftw |
| 3d_64 | 1.002 | 0.0009357 | LOSS | fftw |
| 3d_128 | 1.205 | 0.005865 | LOSS | fftw |
| 3d_256 | 1.011 | 0.003322 | LOSS | fftw |
| 3d_512 | 0.9684 | 0.01747 | WIN | fftw |

**WIN 5 / TIE 0 / LOSS 13**

Raw TSV: /mnt/home/mbarbone/scratch/team-nddiag/standings/raw/rome/measure.tsv
