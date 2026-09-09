# fft_bench N-D standings R5-reship, ccmlin075 (SPR), 2026-09-09, admiral @ b9a2bdfe7dcdbf4d2a653c2477810435bfb7d9f0 (reship)

Host ccmlin075, Intel Xeon w5-3435X. Single thread, complex f64 forward oop, ns/transform, min over 5 interleaved rounds, arm order rotated, pinned to CPU 22. Hand-run on the login node (no Slurm on ccmlin075) with the pipeline copy at /mnt/home/mbarbone/team-r5-shared/fft_bench-spr (fi/nd/run_spr_reship_r5.sh; log /mnt/home/mbarbone/team-r5-shared/logs/m2-spr-reship.log), nice -n19, harness modules modules/2.5-beta1 gcc/14.3.0 fftw/3.3.11 intel-oneapi-mkl/2026.0.0 cmake/3.31.11 ninja/1.13.2, MKL_THREADING_LAYER=SEQUENTIAL.

Arms: reship = fresh build of the pipeline copy's extern/admiral at the campaign tip (rule-9 `git rev-parse HEAD` asserted in the build log); yesterday = staged r5base admiral_bench, binary of admiral 017e132440a2900ae6dbf14f6a7a6e308ac51c46 (master tip at round-5 dispatch, built on this host 2026-09-08 by run_spr_base_r5.sh; sha256 in the provenance block) re-run this session - byte-compile of the master-era source, so the arm reads the fix delta as well as era; mkl/fftw/ducc/duccnew = pipeline competitors (duccnew_bench per fft_bench CMakeLists); reship2 = second interleaved copy of reship (same-binary control).

## binaries (staged, sha256)

```
070307ea1c767eeac85038837ff576ce71b145084de90fce24f1ffb1bac0d0aa  /mnt/home/mbarbone/team-r5-shared/bins/ccmlin075/admiral_bench-r5reship
099d42122cf61f7d1a26105da36234eb8b84983cf8ed7f0451afe791af300f52  /mnt/home/mbarbone/team-r5-shared/bins/ccmlin075/admiral_bench
b08a3c377f7af8b10ec0dacc6c04ddeb7ec211ae45eaee65980e340ff7553751  /mnt/home/mbarbone/team-r5-shared/bins/ccmlin075/mkl_bench-r5reship
dad49106c06b3aa7d164f6466fca8edfd2b5ce94a61b6c5c6ea1662e4de30084  /mnt/home/mbarbone/team-r5-shared/bins/ccmlin075/fftw3_bench-r5reship
6b2ed16a47a877a5cfe9f4c4a02ea66ccd68288577c5f5da7d83dcda59672d45  /mnt/home/mbarbone/team-r5-shared/bins/ccmlin075/ducc_bench-r5reship
aeccfb0d70dacc81d87a6ee9bdb007ab82c70155608318c99e28428d544d5dfe  /mnt/home/mbarbone/team-r5-shared/bins/ccmlin075/duccnew_bench-r5reship
reship GHz=3.838
yesterday GHz=3.672
mkl GHz=3.689
fftw3 GHz=3.856
ducc GHz=3.689
duccnew GHz=3.819
```

## reship vs. reference implementations (mkl, fftw, ducc, duccnew)

| cell | reship | mkl | fftw | ducc | duccnew | max/min reship | reship2/reship | adm/mkl | adm/fftw | adm/ducc | adm/duccnew | adm/best | leader |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2d_16 | 251.6 | 149.8 | 201.4 | 947.7 | 995.2 | 1.036 | 1.0025 | 1.679 | 1.249 | 0.265 | 0.253 | 1.679 | mkl |
| 2d_32 | 1055 | 787.4 | 952.3 | 3102 | 3090 | 1.071 | 1.0227 | 1.340 | 1.108 | 0.340 | 0.341 | 1.340 | mkl |
| 2d_64 | 7246 | 4977 | 7871 | 1.448e+04 | 1.46e+04 | 1.101 | 1.0074 | 1.456 | 0.921 | 0.501 | 0.496 | 1.456 | mkl |
| 2d_128 | 3.475e+04 | 2.345e+04 | 3.784e+04 | 6.203e+04 | 6.29e+04 | 1.083 | 0.9628 | 1.482 | 0.918 | 0.560 | 0.553 | 1.482 | mkl |
| 2d_256 | 1.589e+05 | 1.329e+05 | 2.302e+05 | 3.226e+05 | 3.14e+05 | 1.063 | 0.9960 | 1.196 | 0.690 | 0.493 | 0.506 | 1.196 | mkl |
| 2d_512 | 9.325e+05 | 1.138e+06 | 1.436e+06 | 1.894e+06 | 1.945e+06 | 1.271 | 1.0953 | 0.819 | 0.649 | 0.492 | 0.479 | 0.819 | mkl |
| 2d_1024 | 5.88e+06 | 6.079e+06 | 7.001e+06 | 8.562e+06 | 8.492e+06 | 1.073 | 0.9917 | 0.967 | 0.840 | 0.687 | 0.692 | 0.967 | mkl |
| 2d_2048 | 3.195e+07 | 4.592e+07 | 3.834e+07 | 5.081e+07 | 5.106e+07 | 1.026 | 0.9838 | 0.696 | 0.834 | 0.629 | 0.626 | 0.834 | fftw |
| 2d_4096 | 1.657e+08 | 1.9e+08 | 1.872e+08 | 2.382e+08 | 2.371e+08 | 1.035 | 0.9982 | 0.872 | 0.885 | 0.696 | 0.699 | 0.885 | fftw |
| 2d_8192 | 7.617e+08 | 8.691e+08 | 7.754e+08 | 1.095e+09 | 1.099e+09 | 1.175 | 1.0305 | 0.876 | 0.982 | 0.696 | 0.693 | 0.982 | fftw |
| 3d_4 | 170.8 | 62.68 | 82.38 | 1004 | 987.6 | 1.071 | 0.9705 | 2.725 | 2.073 | 0.170 | 0.173 | 2.725 | mkl |
| 3d_8 | 710.1 | 379.9 | 556.3 | 2668 | 2621 | 1.082 | 0.9922 | 1.869 | 1.276 | 0.266 | 0.271 | 1.869 | mkl |
| 3d_16 | 7295 | 5535 | 8188 | 1.737e+04 | 1.757e+04 | 1.080 | 1.0272 | 1.318 | 0.891 | 0.420 | 0.415 | 1.318 | mkl |
| 3d_32 | 6.862e+04 | 5.597e+04 | 7.654e+04 | 1.642e+05 | 1.714e+05 | 1.093 | 0.9567 | 1.226 | 0.896 | 0.418 | 0.400 | 1.226 | mkl |
| 3d_64 | 8.029e+05 | 7.826e+05 | 1.079e+06 | 1.749e+06 | 1.577e+06 | 1.016 | 1.0038 | 1.026 | 0.744 | 0.459 | 0.509 | 1.026 | mkl |
| 3d_128 | 1.105e+07 | 1.215e+07 | 1.489e+07 | 2.129e+07 | 2.009e+07 | 1.088 | 0.9944 | 0.909 | 0.742 | 0.519 | 0.550 | 0.909 | mkl |
| 3d_256 | 1.347e+08 | 1.417e+08 | 1.764e+08 | 2.426e+08 | 2.405e+08 | 1.018 | 0.9900 | 0.951 | 0.764 | 0.555 | 0.560 | 0.951 | mkl |
| 3d_512 | 1.391e+09 | 1.957e+09 | 1.677e+09 | 2.371e+09 | 2.385e+09 | 1.019 | 1.0092 | 0.710 | 0.829 | 0.586 | 0.583 | 0.829 | fftw |

reship: worst |cpu/real - 1| over cells = 0.0034
mkl: worst |cpu/real - 1| over cells = 0.0030
fftw: worst |cpu/real - 1| over cells = 0.0027
ducc: worst |cpu/real - 1| over cells = 0.0025
duccnew: worst |cpu/real - 1| over cells = 0.0024

## reship vs. yesterday (non-regression column, same session)

| cell | reship | yesterday | max/min reship | reship2/reship | adm/yesterday | adm/best | leader |
|---|---|---|---|---|---|---|---|
| 2d_16 | 251.6 | 254.9 | 1.036 | 1.0025 | 0.987 | 0.987 | yesterday |
| 2d_32 | 1055 | 1058 | 1.071 | 1.0227 | 0.997 | 0.997 | yesterday |
| 2d_64 | 7246 | 7195 | 1.101 | 1.0074 | 1.007 | 1.007 | yesterday |
| 2d_128 | 3.475e+04 | 3.453e+04 | 1.083 | 0.9628 | 1.007 | 1.007 | yesterday |
| 2d_256 | 1.589e+05 | 1.636e+05 | 1.063 | 0.9960 | 0.971 | 0.971 | yesterday |
| 2d_512 | 9.325e+05 | 9.447e+05 | 1.271 | 1.0953 | 0.987 | 0.987 | yesterday |
| 2d_1024 | 5.88e+06 | 5.94e+06 | 1.073 | 0.9917 | 0.990 | 0.990 | yesterday |
| 2d_2048 | 3.195e+07 | 3.139e+07 | 1.026 | 0.9838 | 1.018 | 1.018 | yesterday |
| 2d_4096 | 1.657e+08 | 1.73e+08 | 1.035 | 0.9982 | 0.958 | 0.958 | yesterday |
| 2d_8192 | 7.617e+08 | 9.619e+08 | 1.175 | 1.0305 | 0.792 | 0.792 | yesterday |
| 3d_4 | 170.8 | 170.2 | 1.071 | 0.9705 | 1.004 | 1.004 | yesterday |
| 3d_8 | 710.1 | 733.5 | 1.082 | 0.9922 | 0.968 | 0.968 | yesterday |
| 3d_16 | 7295 | 8320 | 1.080 | 1.0272 | 0.877 | 0.877 | yesterday |
| 3d_32 | 6.862e+04 | 6.463e+04 | 1.093 | 0.9567 | 1.062 | 1.062 | yesterday |
| 3d_64 | 8.029e+05 | 8.037e+05 | 1.016 | 1.0038 | 0.999 | 0.999 | yesterday |
| 3d_128 | 1.105e+07 | 1.158e+07 | 1.088 | 0.9944 | 0.955 | 0.955 | yesterday |
| 3d_256 | 1.347e+08 | 1.335e+08 | 1.018 | 0.9900 | 1.009 | 1.009 | yesterday |
| 3d_512 | 1.391e+09 | 1.41e+09 | 1.019 | 1.0092 | 0.986 | 0.986 | yesterday |

reship: worst |cpu/real - 1| over cells = 0.0034
yesterday: worst |cpu/real - 1| over cells = 0.0034

## verdicts

Per cell, eps = |1 - reship2/reship| (the same-binary noise floor). WIN if reship/best <= 1 - eps, LOSS if >= 1 + eps, else TIE (best = min over mkl/fftw/ducc/duccnew). Verdicts computed at full precision, printed rounded.

| cell | adm/best | eps | VERDICT | leader |
|---|---|---|---|---|
| 2d_16 | 1.679 | 0.002457 | LOSS | mkl |
| 2d_32 | 1.34 | 0.02267 | LOSS | mkl |
| 2d_64 | 1.456 | 0.007425 | LOSS | mkl |
| 2d_128 | 1.482 | 0.03717 | LOSS | mkl |
| 2d_256 | 1.196 | 0.00395 | LOSS | mkl |
| 2d_512 | 0.8194 | 0.09534 | WIN | mkl |
| 2d_1024 | 0.9673 | 0.008298 | WIN | mkl |
| 2d_2048 | 0.8335 | 0.01617 | WIN | fftw |
| 2d_4096 | 0.8853 | 0.001798 | WIN | fftw |
| 2d_8192 | 0.9824 | 0.03054 | TIE | fftw |
| 3d_4 | 2.725 | 0.02947 | LOSS | mkl |
| 3d_8 | 1.869 | 0.007809 | LOSS | mkl |
| 3d_16 | 1.318 | 0.0272 | LOSS | mkl |
| 3d_32 | 1.226 | 0.04326 | LOSS | mkl |
| 3d_64 | 1.026 | 0.003789 | LOSS | mkl |
| 3d_128 | 0.9093 | 0.005572 | WIN | mkl |
| 3d_256 | 0.951 | 0.009962 | WIN | mkl |
| 3d_512 | 0.8294 | 0.009159 | WIN | fftw |

**WIN 7 / TIE 1 / LOSS 10** (out of 18).

Raw TSV: /mnt/home/mbarbone/team-r5-shared/standings/raw-reship/ccmlin075/measure.tsv
