# fft_bench N-D standings, rome, 2026-09-08, admiral @ 017e132440a2900ae6dbf14f6a7a6e308ac51c46 (reship)

Single thread, complex f64 forward oop, ns/transform, min over interleaved rounds, arm order rotated, one core pinned. Job 7001689.
Reduced with /mnt/home/mbarbone/scratch/team-nddiag/fft_bench/fi/nd/nd_reduce.py; verdicts by /mnt/home/mbarbone/scratch/team-nddiag/tools/nd_gen_standings.py (full precision, printed 4 sig figs).

Era-calibration anchors: 2d_4096 and 2d_8192 (d3 compares this table against the D1 baseline drift-scaled by the geomean absolute admiral-ns ratio at these code-untouched cells).

## binaries (staged, sha256)

```
3a1c27cfd0083765cc8819d227509dc493c38f928b1e6b43462fc6c33eaeb6e9  /mnt/home/mbarbone/team-nddiag-shared/bins-reship/rome/admiral_bench
43926b08f9009e93eccc756aa9e3f679f9fecbc925c698b4170f86eff4451972  /mnt/home/mbarbone/team-nddiag-shared/bins-reship/rome/mkl_bench
6e20a443f865ec2576874c50fc25fc7fc1c87ae5b020dc841b45f1916de8226e  /mnt/home/mbarbone/team-nddiag-shared/bins-reship/rome/fftw3_bench
4e2f0f3388a20d1308ecd063a45299a312ca7a6a164bff09b6b38590418c5d6a  /mnt/home/mbarbone/team-nddiag-shared/bins-reship/rome/ducc_bench
```

## ratios (nd_reduce)

| cell | reship | mkl | fftw | ducc | max/min reship | reship2/reship | adm/mkl | adm/fftw | adm/ducc | adm/best | leader |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 2d_16 | 616.1 | 1547 | 431.3 | 1782 | 1.001 | 0.9997 | 0.398 | 1.428 | 0.346 | 1.428 | fftw |
| 2d_32 | 3355 | 6393 | 1981 | 5782 | 1.003 | 1.0000 | 0.525 | 1.694 | 0.580 | 1.694 | fftw |
| 2d_64 | 1.337e+04 | 2.653e+04 | 1.081e+04 | 2.012e+04 | 1.011 | 0.9999 | 0.504 | 1.238 | 0.665 | 1.238 | fftw |
| 2d_128 | 6.5e+04 | 1.088e+05 | 6.428e+04 | 7.534e+04 | 1.014 | 1.0081 | 0.597 | 1.011 | 0.863 | 1.011 | fftw |
| 2d_256 | 3.007e+05 | 5.355e+05 | 3.208e+05 | 4.068e+05 | 1.084 | 0.9985 | 0.561 | 0.937 | 0.739 | 0.937 | fftw |
| 2d_512 | 1.386e+06 | 2.373e+06 | 1.382e+06 | 1.758e+06 | 1.005 | 1.0011 | 0.584 | 1.003 | 0.789 | 1.003 | fftw |
| 2d_1024 | 8.583e+06 | 1.216e+07 | 9.173e+06 | 7.998e+06 | 1.025 | 1.0031 | 0.706 | 0.936 | 1.073 | 1.073 | ducc |
| 2d_2048 | 4.326e+07 | 8.336e+07 | 4.795e+07 | 6.208e+07 | 1.006 | 0.9990 | 0.519 | 0.902 | 0.697 | 0.902 | fftw |
| 2d_4096 | 1.961e+08 | 8.456e+08 | 2.069e+08 | 2.786e+08 | 1.005 | 0.9995 | 0.232 | 0.948 | 0.704 | 0.948 | fftw |
| 2d_8192 | 8.897e+08 | 3.479e+09 | 8.864e+08 | 1.162e+09 | 1.005 | 0.9945 | 0.256 | 1.004 | 0.766 | 1.004 | fftw |
| 3d_4 | 318.9 | 1761 | 140.1 | 1843 | 1.005 | 0.9995 | 0.181 | 2.276 | 0.173 | 2.276 | fftw |
| 3d_8 | 1717 | 6169 | 1142 | 5339 | 1.004 | 1.0013 | 0.278 | 1.504 | 0.322 | 1.504 | fftw |
| 3d_16 | 1.355e+04 | 3.298e+04 | 1.319e+04 | 3.029e+04 | 1.004 | 1.0000 | 0.411 | 1.027 | 0.447 | 1.027 | fftw |
| 3d_32 | 1.594e+05 | 2.381e+05 | 1.317e+05 | 2.657e+05 | 1.016 | 0.9946 | 0.669 | 1.210 | 0.600 | 1.210 | fftw |
| 3d_64 | 1.36e+06 | 2.745e+06 | 1.365e+06 | 2.123e+06 | 1.004 | 0.9983 | 0.496 | 0.997 | 0.641 | 0.997 | fftw |
| 3d_128 | 2.329e+07 | 4.182e+07 | 1.974e+07 | 3.477e+07 | 1.029 | 0.9972 | 0.557 | 1.179 | 0.670 | 1.179 | fftw |
| 3d_256 | 2.217e+08 | 3.881e+08 | 2.126e+08 | 3.028e+08 | 1.008 | 0.9974 | 0.571 | 1.043 | 0.732 | 1.043 | fftw |
| 3d_512 | 1.931e+09 | 3.394e+09 | 1.969e+09 | 2.488e+09 | 1.021 | 1.0048 | 0.569 | 0.981 | 0.776 | 0.981 | fftw |

reship: worst |cpu/real - 1| over cells = 0.0060
mkl: worst |cpu/real - 1| over cells = 0.0042
fftw: worst |cpu/real - 1| over cells = 0.0056
ducc: worst |cpu/real - 1| over cells = 0.0052

## verdicts

| cell | adm/best | eps | verdict | leader |
|---|---|---|---|---|
| 2d_16 | 1.428 | 0.0002589 | LOSS | fftw |
| 2d_32 | 1.694 | 3.173e-05 | LOSS | fftw |
| 2d_64 | 1.238 | 0.0001281 | LOSS | fftw |
| 2d_128 | 1.011 | 0.008087 | LOSS | fftw |
| 2d_256 | 0.9372 | 0.0015 | WIN | fftw |
| 2d_512 | 1.003 | 0.00109 | LOSS | fftw |
| 2d_1024 | 1.073 | 0.003108 | LOSS | ducc |
| 2d_2048 | 0.9021 | 0.001029 | WIN | fftw |
| 2d_4096 | 0.9479 | 0.000546 | WIN | fftw |
| 2d_8192 | 1.004 | 0.005459 | TIE | fftw |
| 3d_4 | 2.276 | 0.0004763 | LOSS | fftw |
| 3d_8 | 1.504 | 0.001297 | LOSS | fftw |
| 3d_16 | 1.027 | 1.783e-05 | LOSS | fftw |
| 3d_32 | 1.21 | 0.005368 | LOSS | fftw |
| 3d_64 | 0.9967 | 0.001671 | WIN | fftw |
| 3d_128 | 1.179 | 0.002838 | LOSS | fftw |
| 3d_256 | 1.043 | 0.002626 | LOSS | fftw |
| 3d_512 | 0.981 | 0.004844 | WIN | fftw |

**WIN 5 / TIE 1 / LOSS 12**

Raw TSV: /mnt/home/mbarbone/scratch/team-nddiag/standings/raw/rome/measure.tsv
