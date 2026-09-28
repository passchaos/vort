# Brotli bounded short match copy

Date: 2026-09-28

## Motivation

The `clustered_q8` reference workload contains 10,533 non-overlapping LZ77
copies of at most 16 bytes, accounting for 73,221 decoded bytes. Vort formerly
sent each one through a dynamically sized `@memcpy`. The local Brotli reference
at `/Users/bytedance/Work/brotli` instead starts eligible backward references
with a fixed 16-byte move, using private ring-buffer slack to make the wider
write safe.

Vort decodes directly into caller-owned memory, so it cannot assume padding
after the output. The new path passes the current meta-block end into the match
copy helper and uses the fixed 16-byte move only when all of these are proven:

- the logical copy is non-empty and at most 16 bytes;
- the distance is at least 16 bytes, so the fixed source and destination do not
  overlap;
- at least 16 bytes remain in the current meta-block.

The last condition confines speculative bytes to output that the same
meta-block must initialize before a successful return. The existing exact copy
and overlap-doubling paths remain the fallback.

## Correctness evidence

The focused match-copy tests cover overlapping replay, exact non-overlapping
fallback, the fixed-width path, and a sentinel after the meta-block boundary:

```sh
zig test src/br/match_copy.zig -OReleaseFast
```

All three tests pass. The broader Brotli checks used the local reference build
reporting API version 1.2.0:

```sh
python3 tools/br/reference_bench_gate.py \
  --csv /tmp/vort-br-wide16.csv \
  --enforce-throughput \
  --executable /tmp/vort-br-reference-new
python3 tools/br/real_corpus_diff_smoke.py
DYLD_LIBRARY_PATH=/tmp/vort-brotli-reference.UjgVSa \
  zig build -Doptimize=ReleaseFast run-br-upstream-multiblock-diff -j1
```

The 13-row reference gate passes. The manifest smoke runs seven tests. The
upstream differential passes 7,056 one-shot cases, 7,056 progressive cases,
99 core cases, 64 high-tree truncation cases, and the operation-schedule and
Large Window matrices.

## Paired result

The baseline is commit `7c89e5df`. Separate ReleaseFast binaries for the
baseline and candidate were run in alternating order for 15 pairs. Each
`clustered_q8` row records 100 timed decodes selected from the benchmark's five
samples. The source is 1 MiB and the Brotli stream is 52,622 bytes. The host
target is aarch64 macOS with Zig 0.16.0 and `target_cpu=apple_m1`; CPU affinity
was unavailable.

| metric | baseline | bounded 16-byte copy |
| --- | ---: | ---: |
| median Vort throughput | 1136.18 MiB/s | 1201.12 MiB/s |
| paired median speedup | 1.0000x | 1.0551x |
| paired geometric-mean speedup | 1.0000x | 1.0568x |
| paired wins | - | 15 / 15 |

The individual paired ratios range from 1.0440x to 1.0747x. This establishes a
repeatable improvement for the measured short-copy-heavy workload, not broad
Brotli decode leadership. The candidate remains below local libbrotli 1.2.0 on
this case, so further literal/command execution work is still required.

The repository-wide `test` and `check` graphs were also attempted in
ReleaseFast, but neither returned a terminal result within a five-minute
observation window on the loaded host. They are therefore not counted as
passing evidence here.
