# fft_bench N-D standings, icelake, 2026-09-06, admiral @ c4c3911235e8e20636f9be471efd4d9717852c8a (after)

Single thread, complex f64 forward oop, ns/transform, min over interleaved rounds, arm order rotated, one core pinned. Job 6993673.
Reduced with fft_bench/fi/nd/nd_reduce.py; verdicts by /mnt/home/mbarbone/scratch/team-nddiag/tools/nd_gen_standings.py (full precision, printed 4 sig figs).

## binaries (staged, sha256)

```
c97355be7fcb2eab57c14152a39d21936e6e725970ec5b48ec4a63c4d4c9cf87  bins/icelake/admiral_bench
ec29a14149b8823bfb81443bd34be94d6577a3f8e4a79e8bedc44debc2b44d44  bins/icelake/mkl_bench
d1dc25e787d3f4b44a20edb3260709a301813b4233826555d979dadc98e9af52  bins/icelake/fftw3_bench
009a8d5c8de4ab6cd52b7f85218e0ca7f421ec6badbe51b11be92f2125149b73  bins/icelake/ducc_bench
```

## ratios (nd_reduce)

| cell | after | mkl | fftw | ducc | max/min after | after2/after | adm/mkl | adm/fftw | adm/ducc | adm/best | leader |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 2d_16 | 508.6 | 186.3 | 277.4 | 1427 | 1.002 | 1.0000 | 2.730 | 1.834 | 0.357 | 2.730 | mkl |
| 2d_32 | 2080 | 1064 | 1607 | 4296 | 1.013 | 1.0001 | 1.955 | 1.295 | 0.484 | 1.955 | mkl |
| 2d_64 | 9676 | 6244 | 9062 | 1.788e+04 | 1.013 | 1.0134 | 1.550 | 1.068 | 0.541 | 1.550 | mkl |
| 2d_128 | 5.175e+04 | 2.824e+04 | 5.004e+04 | 7.815e+04 | 1.039 | 1.0040 | 1.833 | 1.034 | 0.662 | 1.833 | mkl |
| 2d_256 | 2.691e+05 | 1.767e+05 | 2.999e+05 | 4.026e+05 | 1.103 | 1.0051 | 1.523 | 0.897 | 0.668 | 1.523 | mkl |
| 2d_512 | 1.253e+06 | 9.896e+05 | 1.62e+06 | 1.898e+06 | 1.010 | 0.9985 | 1.266 | 0.773 | 0.660 | 1.266 | mkl |
| 2d_1024 | 5.487e+06 | 4.712e+06 | 6.527e+06 | 7.752e+06 | 1.012 | 1.0042 | 1.164 | 0.841 | 0.708 | 1.164 | mkl |
| 2d_2048 | 4.069e+07 | 3.818e+07 | 4.572e+07 | 5.579e+07 | 1.091 | 1.0691 | 1.066 | 0.890 | 0.729 | 1.066 | mkl |
| 2d_4096 | 1.748e+08 | 1.898e+08 | 2.093e+08 | 2.753e+08 | 1.008 | 0.9997 | 0.921 | 0.835 | 0.635 | 0.921 | mkl |
| 2d_8192 | 7.323e+08 | 7.262e+08 | 9.068e+08 | 1.148e+09 | 1.037 | 0.9979 | 1.008 | 0.808 | 0.638 | 1.008 | mkl |
| 3d_4 | 324 | 82.88 | 120 | 1368 | 1.006 | 1.0002 | 3.910 | 2.701 | 0.237 | 3.910 | mkl |
| 3d_8 | 1362 | 489.2 | 728.6 | 3818 | 1.036 | 1.0000 | 2.785 | 1.870 | 0.357 | 2.785 | mkl |
| 3d_16 | 1.276e+04 | 5680 | 1.028e+04 | 2.683e+04 | 1.015 | 0.9944 | 2.247 | 1.242 | 0.476 | 2.247 | mkl |
| 3d_32 | 9.564e+04 | 6.43e+04 | 1.004e+05 | 2.229e+05 | 1.022 | 1.0054 | 1.487 | 0.953 | 0.429 | 1.487 | mkl |
| 3d_64 | 1.031e+06 | 1.086e+06 | 1.343e+06 | 2.056e+06 | 1.105 | 0.9298 | 0.949 | 0.767 | 0.501 | 0.949 | mkl |
| 3d_128 | 1.344e+07 | 1.054e+07 | 1.597e+07 | 1.985e+07 | 1.005 | 1.0022 | 1.275 | 0.841 | 0.677 | 1.275 | mkl |
| 3d_256 | 2.021e+08 | 1.813e+08 | 1.996e+08 | 2.57e+08 | 1.006 | 1.0013 | 1.115 | 1.013 | 0.787 | 1.115 | mkl |
| 3d_512 | 1.895e+09 | 2.345e+09 | 2.004e+09 | 2.397e+09 | 1.004 | 0.9996 | 0.808 | 0.945 | 0.790 | 0.945 | fftw |

after: worst |cpu/real - 1| over cells = 0.0043
mkl: worst |cpu/real - 1| over cells = 0.0039
fftw: worst |cpu/real - 1| over cells = 0.0037
ducc: worst |cpu/real - 1| over cells = 0.0037

## verdicts

| cell | adm/best | eps | verdict | leader |
|---|---|---|---|---|
| 2d_16 | 2.73 | 2.055e-06 | LOSS | mkl |
| 2d_32 | 1.955 | 0.0001252 | LOSS | mkl |
| 2d_64 | 1.55 | 0.01344 | LOSS | mkl |
| 2d_128 | 1.833 | 0.003987 | LOSS | mkl |
| 2d_256 | 1.523 | 0.005148 | LOSS | mkl |
| 2d_512 | 1.266 | 0.001528 | LOSS | mkl |
| 2d_1024 | 1.164 | 0.004202 | LOSS | mkl |
| 2d_2048 | 1.066 | 0.06911 | TIE | mkl |
| 2d_4096 | 0.9213 | 0.0003207 | WIN | mkl |
| 2d_8192 | 1.008 | 0.002146 | LOSS | mkl |
| 3d_4 | 3.91 | 0.0001844 | LOSS | mkl |
| 3d_8 | 2.785 | 1.958e-05 | LOSS | mkl |
| 3d_16 | 2.247 | 0.005611 | LOSS | mkl |
| 3d_32 | 1.487 | 0.005354 | LOSS | mkl |
| 3d_64 | 0.9494 | 0.07022 | TIE | mkl |
| 3d_128 | 1.275 | 0.002191 | LOSS | mkl |
| 3d_256 | 1.115 | 0.001321 | LOSS | mkl |
| 3d_512 | 0.9453 | 0.0004397 | WIN | fftw |

**WIN 2 / TIE 2 / LOSS 14**

Raw TSV: /mnt/home/mbarbone/scratch/team-nddiag/standings/raw/icelake/measure.tsv
