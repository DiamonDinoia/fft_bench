# fft_bench N-D standings, icelake, 2026-09-07, admiral @ b68e64cb0f2aeea497a16eb9fa9cf46109f1e1a4 (reship)

Single thread, complex f64 forward oop, ns/transform, min over interleaved rounds, arm order rotated, one core pinned. Job 7000054.
Reduced with /mnt/home/mbarbone/scratch/team-nddiag/fft_bench/fi/nd/nd_reduce.py; verdicts by /mnt/home/mbarbone/scratch/team-nddiag/tools/nd_gen_standings.py (full precision, printed 4 sig figs).

Era-calibration anchors: 2d_4096 and 2d_8192 (d3 compares this table against the D1 baseline drift-scaled by the geomean absolute admiral-ns ratio at these code-untouched cells).

## binaries (staged, sha256)

```
ca83f8e61e2e59bb8028226b3577cc9a1f81d9cd360716a4c1e7eff1f2a722cf  /mnt/home/mbarbone/team-nddiag-shared/bins-reship/icelake/admiral_bench
ec29a14149b8823bfb81443bd34be94d6577a3f8e4a79e8bedc44debc2b44d44  /mnt/home/mbarbone/team-nddiag-shared/bins-reship/icelake/mkl_bench
d1dc25e787d3f4b44a20edb3260709a301813b4233826555d979dadc98e9af52  /mnt/home/mbarbone/team-nddiag-shared/bins-reship/icelake/fftw3_bench
9d9434f3722675e2d4ea8a8f90c3f87f7e83765ee25098d0d5e0b49391700998  /mnt/home/mbarbone/team-nddiag-shared/bins-reship/icelake/ducc_bench
```

## ratios (nd_reduce)

| cell | reship | mkl | fftw | ducc | max/min reship | reship2/reship | adm/mkl | adm/fftw | adm/ducc | adm/best | leader |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 2d_16 | 405.1 | 186.5 | 277.7 | 1426 | 1.021 | 1.0001 | 2.172 | 1.459 | 0.284 | 2.172 | mkl |
| 2d_32 | 1615 | 1059 | 1596 | 4295 | 1.003 | 0.9999 | 1.525 | 1.012 | 0.376 | 1.525 | mkl |
| 2d_64 | 9676 | 6258 | 8875 | 1.789e+04 | 1.013 | 1.0021 | 1.546 | 1.090 | 0.541 | 1.546 | mkl |
| 2d_128 | 4.514e+04 | 2.825e+04 | 4.97e+04 | 7.814e+04 | 1.133 | 1.0001 | 1.598 | 0.908 | 0.578 | 1.598 | mkl |
| 2d_256 | 2.758e+05 | 1.811e+05 | 3.093e+05 | 4.043e+05 | 1.085 | 1.0467 | 1.523 | 0.892 | 0.682 | 1.523 | mkl |
| 2d_512 | 1.267e+06 | 1.002e+06 | 1.569e+06 | 1.923e+06 | 1.145 | 0.9985 | 1.264 | 0.808 | 0.659 | 1.264 | mkl |
| 2d_1024 | 5.587e+06 | 4.782e+06 | 6.768e+06 | 7.806e+06 | 1.014 | 1.0030 | 1.168 | 0.825 | 0.716 | 1.168 | mkl |
| 2d_2048 | 4.098e+07 | 3.833e+07 | 4.539e+07 | 5.582e+07 | 1.078 | 0.9991 | 1.069 | 0.903 | 0.734 | 1.069 | mkl |
| 2d_4096 | 1.757e+08 | 1.941e+08 | 2.107e+08 | 2.778e+08 | 1.003 | 1.0001 | 0.905 | 0.834 | 0.633 | 0.905 | mkl |
| 2d_8192 | 7.378e+08 | 7.268e+08 | 9.094e+08 | 1.16e+09 | 1.088 | 0.9987 | 1.015 | 0.811 | 0.636 | 1.015 | mkl |
| 3d_4 | 264.7 | 82.29 | 117.3 | 1368 | 1.000 | 0.9997 | 3.216 | 2.256 | 0.194 | 3.216 | mkl |
| 3d_8 | 1371 | 498.3 | 755.8 | 3820 | 1.007 | 0.9999 | 2.752 | 1.814 | 0.359 | 2.752 | mkl |
| 3d_16 | 1.094e+04 | 5688 | 1.038e+04 | 2.686e+04 | 1.031 | 1.0027 | 1.923 | 1.054 | 0.407 | 1.923 | mkl |
| 3d_32 | 8.278e+04 | 6.401e+04 | 1.016e+05 | 2.239e+05 | 1.025 | 1.0071 | 1.293 | 0.815 | 0.370 | 1.293 | mkl |
| 3d_64 | 1.047e+06 | 1.089e+06 | 1.34e+06 | 2.069e+06 | 1.057 | 0.9171 | 0.962 | 0.781 | 0.506 | 0.962 | mkl |
| 3d_128 | 1.362e+07 | 1.058e+07 | 1.572e+07 | 2.001e+07 | 1.011 | 0.9945 | 1.287 | 0.866 | 0.681 | 1.287 | mkl |
| 3d_256 | 1.993e+08 | 1.834e+08 | 2.096e+08 | 2.565e+08 | 1.014 | 0.9866 | 1.087 | 0.951 | 0.777 | 1.087 | mkl |
| 3d_512 | 1.903e+09 | 2.364e+09 | 2.038e+09 | 2.407e+09 | 1.010 | 0.9990 | 0.805 | 0.934 | 0.790 | 0.934 | fftw |

reship: worst |cpu/real - 1| over cells = 0.0039
mkl: worst |cpu/real - 1| over cells = 0.0034
fftw: worst |cpu/real - 1| over cells = 0.0039
ducc: worst |cpu/real - 1| over cells = 0.0033

## verdicts

| cell | adm/best | eps | verdict | leader |
|---|---|---|---|---|
| 2d_16 | 2.172 | 7.082e-05 | LOSS | mkl |
| 2d_32 | 1.525 | 0.0001149 | LOSS | mkl |
| 2d_64 | 1.546 | 0.002061 | LOSS | mkl |
| 2d_128 | 1.598 | 8.099e-05 | LOSS | mkl |
| 2d_256 | 1.523 | 0.04672 | LOSS | mkl |
| 2d_512 | 1.264 | 0.001527 | LOSS | mkl |
| 2d_1024 | 1.168 | 0.002997 | LOSS | mkl |
| 2d_2048 | 1.069 | 0.0009298 | LOSS | mkl |
| 2d_4096 | 0.9053 | 7.343e-05 | WIN | mkl |
| 2d_8192 | 1.015 | 0.001334 | LOSS | mkl |
| 3d_4 | 3.216 | 0.0003039 | LOSS | mkl |
| 3d_8 | 2.752 | 7.049e-05 | LOSS | mkl |
| 3d_16 | 1.923 | 0.002707 | LOSS | mkl |
| 3d_32 | 1.293 | 0.00706 | LOSS | mkl |
| 3d_64 | 0.962 | 0.08291 | TIE | mkl |
| 3d_128 | 1.287 | 0.005539 | LOSS | mkl |
| 3d_256 | 1.087 | 0.01338 | LOSS | mkl |
| 3d_512 | 0.9335 | 0.001046 | WIN | fftw |

**WIN 2 / TIE 1 / LOSS 15**

Raw TSV: /mnt/home/mbarbone/scratch/team-nddiag/standings/raw/icelake/measure.tsv
