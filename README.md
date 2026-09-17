# Benchmarking various FFT implementations
FFTW3 run in FFTW_MEASURE mode. FFTW_PATIENT is death, and I wanted to give it a fair shot with the default. All benchmarks are compiled with per-machine instructions enabled: `-march={znver2,icelake-server,znver4} -O3`.

| MKL      | FFTW   | KISS             | Pocket   | DUCC              | Sleef         | Admiral |
|----------|--------|------------------|----------|-------------------|---------------|---------|
| 2026.0.0 | 3.3.11 | v131-101-ge5e3fac| 81d171a6 | 0.41.1-72-g9919ab6| 3.9.0-41-g7623d6c | b2bf2d3 |

FFTW3, MKL and gcc come from the cluster's Lmod modules (`gcc/14.3.0 fftw/3.3.11 intel-oneapi-mkl/2026.0.0`); the module's FFTW3 carries the
OpenMP threading library, which `fftw3_omp_bench` links. Machines: Intel Xeon Platinum 8362 (icelake), AMD EPYC 7742 (rome), AMD EPYC 9474F (genoa).

## Single threaded results
### 1D
![](fi/1d_c2c_st_icelake.png)
![](fi/1d_c2c_st_rome.png)
![](fi/1d_c2c_st_genoa.png)

### 2D
![](fi/2d_c2c_st_icelake.png)
![](fi/2d_c2c_st_rome.png)
![](fi/2d_c2c_st_genoa.png)

### 3D
![](fi/3d_c2c_st_icelake.png)
![](fi/3d_c2c_st_rome.png)
![](fi/3d_c2c_st_genoa.png)


## Multi threaded results
Benchmarks run on a whole node, using all cores (both sockets): rome 128 threads,
icelake 64, genoa 96 (SMT off):

```
export OMP_NUM_THREADS=<cores per node>
export OMP_PROC_BIND=spread
export OMP_PLACES=threads

taskset -c 0-$((OMP_NUM_THREADS-1)) blah_bench args
```

mkl, fftw3, ducc and sleef take the thread count from `OMP_NUM_THREADS`, so they are
handed the node's full count at every size and decide internally what to do with it.
Admiral takes its count as a plan option and is passed `nthreads=0`, its auto setting:
serial below 32768 elements; past that a fitted wake-cost law picks the pool size —
up to every allowed physical core at the ceiling, equal to the `taskset` count. The
difference from the libraries is that admiral prices the wake cost against the work
per pass and drops to fewer threads, or to serial, on its own where a thread pool
costs more than it saves.

Known issue: **FFTW3 multi-threaded does not terminate on genoa.** `FFTW_MEASURE`
planning at 96 threads burns 99% of a single core for hours (one transform size
clocked past two hours of pure planning) while the same block completes in 13-24 min
on icelake and rome. `fftw3_omp` is therefore omitted from the genoa runs; FFTW3
OpenMP results are unaffected on the other two machines.

Known issue (fixed 2026-09-16): **MKL's FFTW3-compatibility wrapper is broken when
threaded.** Measured through `fftw_plan_with_nthreads` + `fftw_execute`, every mkl cell
past a point-count gate (1-D: 8192; both precisions, all three machines, several sweeps)
paid a per-CALL overhead of ms-to-~100 ms scale: 144 ms/call at 1-D f64 8192 on icelake
where the same transform through MKL's native DFTI reads 17.6 µs at 32 threads; 2-D 64²
f64 mkl-omp: 64.5 ms vs native 4.7 µs. It is a wrapper defect, not MKL's FFT (native
`DftiComputeForward` is healthy at every probed size/thread count), and not an
OpenMP-runtime interaction (reproduces under iomp5 and gomp, under ACTIVE spin and
immediate sleep). Sweeps before 2026-09-16 drew mkl-omp curves from that artifact and
no mkl-omp series predating this fix is usable. The mkl_omp arm now drives DFTI
natively; per MKL 2026.0, a threaded dim-1 descriptor must take the scalar length form
(the array-length form of `DftiCreateDescriptor` at dim 1 segfaults `commit`).

Session caveat (2026-09-01 measurements): the genoa round ran on a uniformly slower
node (every library moved; admiral least of all), which flatters admiral's MT ratios
on genoa this round. The rankings are the stable content.

Note that KISS has openmp enabled, but I didn't do a separate build for it. Given its
performance, I am happy to ignore it. Pocket is single-threaded only. So the
multi-threaded plots carry mkl, fftw3, ducc, sleef and admiral.

### 1D
![](fi/1d_c2c_mt_icelake.png)
![](fi/1d_c2c_mt_rome.png)
![](fi/1d_c2c_mt_genoa.png)

### 2D
Note the AMD measurements are not in error. This really happens consistently. MKL is very
unhappy with more than 16 threads for these particular sizes in 2D.

![](fi/2d_c2c_mt_icelake.png)
![](fi/2d_c2c_mt_rome.png)
![](fi/2d_c2c_mt_genoa.png)

### 3D
![](fi/3d_c2c_mt_icelake.png)
![](fi/3d_c2c_mt_rome.png)
![](fi/3d_c2c_mt_genoa.png)
