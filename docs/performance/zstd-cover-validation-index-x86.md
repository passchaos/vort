# Zstd COVER held-out validation index on x86-64

This note records the 2026-10-19 adaptive held-out scoring optimization for
pure-Zig COVER-class parameter training. It compares two byte-identical Vort
paths and does not claim a training-speed lead over libzstd.

## Change

The original scorer checks every dictionary offset at each unmatched held-out
position. Vort already had a reusable first-byte position index for its older
validation-guided trainer. COVER optimization now passes a stateful scorer
context through the generic candidate loop and reuses that index's allocation
across candidates.

Building an index is not profitable for short histories. The production scorer
therefore keeps the allocation-free linear path below 256 dictionary bytes and
uses the indexed path at or above that threshold. Tests compare every
`ValidationScore` field with the linear oracle for several minimum match
lengths, prove short histories allocate nothing, recover after an injected
index-allocation failure, and retain identical selected parameters and bytes.

## Reproduction

```sh
zig build run-cover-dictionary-train-bench-gate
```

Both `cover_optimized_linear` and `cover_optimized` share the prepared training
context. The only difference is linear versus adaptive held-out scoring. The
deterministic benchmark uses 20 training samples and four held-out samples of
320 bytes, twelve parameter candidates, 20 iterations, three rounds, and the
best elapsed round.

Environment:

- base commit: `8340088b`;
- Zig `0.16.0` in `ReleaseFast`;
- `x86_64`, Intel Core i7-10700K, 8 cores / 16 threads;
- no CPU affinity or frequency pinning; both modes run in the same process.

## Result

| Corpus | Linear bytes/s | Adaptive bytes/s | Ratio | Linear allocations | Adaptive allocations | Linear allocated bytes | Adaptive allocated bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| text | 5,851,247 | 5,874,704 | 1.0040x | 40 | 40 | 1,678,824 | 1,678,824 |
| JSON | 5,831,280 | 5,807,569 | 0.9959x | 40 | 40 | 1,678,829 | 1,678,829 |
| binary | 2,417,359 | 5,753,263 | 2.3800x | 28 | 29 | 1,677,984 | 1,684,216 |

All output checksums are identical. Text and JSON select short histories and
stay on the linear path. Binary retains a 512-byte history, where the reusable
index more than doubles held-out scoring throughput for only one additional
allocation. The permanent gate requires every control to retain at least 95%
of linear throughput and the binary row to retain at least `2.0x`.
