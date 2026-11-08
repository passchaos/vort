# Zstd parallel seekable worker-context reuse

Date: 2026-11-08. This report covers one bounded slice of the
[performance-first architecture](../performance-first-architecture.md):
persistent worker contexts in the parallel native Zstandard seekable encoder.
It is scoped evidence for that operation, not a general Zstd throughput claim.

## Problem

The serial `NativeSeekableStreamEncoder` owns one `NativeFrameEncoder` and
reuses its match tables, block scratch, entropy workspaces and output buffers
for every frame. The parallel entry point created and destroyed a fresh
`NativeFrameEncoder` inside each frame job. Every frame therefore repeated
scratch allocation and table preparation even though the worker lifetime could
outlive many frames.

This is the per-job-allocation pattern the architecture document forbids:
worker scratch belongs to the worker context, not to each unit of work.

## Change

`src/zstd.zig` now allocates one `ParallelNativeSeekableWorker` per requested
worker. Each worker owns one `NativeFrameEncoder` initialized with the shared
locked allocator and claims frames from the existing atomic queue. The encoder
survives across frames, so scratch and match structures are prepared on the
first claimed frame and reused afterwards.

Ownership and failure behavior remain deterministic:

- frame order, seek-table order and wire bytes are unchanged;
- each worker writes only its own result slot and frame buffer;
- a frame failure marks the result and stops that worker from claiming more
  work, because its encoder transaction is already poisoned; the operation
  still reports the first error in frame order;
- worker encoders are deinitialized before the worker array is released;
- spawn-failure and allocation-failure paths release every completed frame and
  every worker context.

## Measurement

Command:

```sh
zig build run-zstd-seekable-parallel-bench -- \
  --iterations 2 --rounds 5 --csv zig-out/seekable-worker-reuse.csv
```

Workload and host:

- ReleaseFast, Zig 0.16.0, x86_64-linux-gnu;
- target CPU `skylake+pku+sgx`, Intel Core i7-10700K, affinity `0-15`;
- 8 MiB generated payload, SHA-256
  `c6e897140bfa4ceae27301a8d021e8b8e1902fc308be3fc0bf8a51605c46fc4c`;
- 32 frames of 256 KiB, `fast_compressed`, frame checksum disabled, seek
  checksums enabled;
- the benchmark alternates parallel and serial one-worker runs and reports
  their ratio, which removes most run-to-run machine drift.

| Workers | Before, MiB/s | Before, speedup | After run 1, MiB/s | After run 1, speedup | After run 2, MiB/s | After run 2, speedup |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 187.34 | 0.9952 | 183.58 | 0.9983 | 184.07 | 1.0023 |
| 2 | 328.74 | 1.7686 | 339.53 | 1.8616 | 333.21 | 1.8331 |
| 4 | 581.02 | 3.1371 | 596.85 | 3.3029 | 604.58 | 3.3597 |
| 8 | 942.87 | 5.1130 | 967.70 | 5.3543 | 962.87 | 5.3685 |

The serial one-worker path is unchanged code. Its absolute throughput moved
between runs because the host was not pinned to a fixed frequency. The
same-run parallel/serial ratio is therefore the meaningful comparison: the
2/4/8-worker ratios improved by roughly 4--7% over the baseline run.

The seek table, encoded size (`2,229,301` bytes) and checksum
(`4,458,924`) are identical in every row, and the benchmark gate compares the
parallel wire byte-for-byte with the serial wire before timing.

## Verification

```sh
zig build test-zstd -Dzstd-test-filter='parallel seekable' --summary all
zig build test-zstd --summary all
zig build test-zstd -Doptimize=ReleaseFast --summary all
zig build run-zstd-seekable-parallel-bench-gate --summary all
```

Results:

- focused parallel seekable tests: 30/30 passed;
- full Debug Zstd suite: 1388/1388 passed;
- full ReleaseFast Zstd suite: 1388/1388 passed;
- benchmark gate: passed, including deterministic wire and provenance checks.

## Limits

This slice does not make workers persistent across public calls, does not
remove per-frame output allocation, and does not change the serial path or the
wire format. The next scheduling increment is the caller-owned persistent
scheduler pilot described in the architecture document; it must reuse this
worker-ownership shape rather than reintroducing per-call or per-frame encoder
construction.
