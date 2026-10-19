# Brotli serialized dictionary index — x86-64

Date: 2026-10-19

## Scope

The correctness-first serialized contextual dictionary encoder originally
enumerated every dictionary, source length, transform, and word at every
literal position. The retained matcher now prepares a context-independent
four-byte candidate index and computes the context-relative combined address
at lookup time. The complete exhaustive matcher remains the correctness oracle
and the fallback for descriptors above the bounded index candidate limit.

The index stores source coordinates rather than transformed bytes. Borrowed
dictionary storage therefore remains the single source of truth, and every
candidate is rematerialized with the same transform implementation used by
decode replay.

## Reproduction

Host:

- Intel Core i7-10700K at 3.80 GHz, x86-64, 16 logical CPUs;
- Zig 0.16.0;
- ReleaseFast benchmark executable;
- one thread; no CPU pinning or frequency isolation.

Command:

```sh
for run in 1 2 3 4 5; do
  zig build run-br-serialized-dictionary-bench -- --iterations 1000
done
```

The deterministic fixture contains 256 eight-byte words and transform kinds
0...11. Seven of the 12 transform families produce at least four output bytes,
so the index retains 1,792 candidates in 18,436 bytes. Every timed lookup asks
for the uppercase-all transform of the last word; indexed and exhaustive
results, including copy length and combined address, must be identical before
timing begins.

## Results

| Metric | Median |
|---|---:|
| Index preparation | 154,115 ns |
| 1,000 indexed lookups | 12,873,625 ns |
| 1,000 exhaustive lookups | 47,480,389 ns |
| Per-run reported speedup | 3.646x |

The five reported speedups were 3.371x, 3.743x, 3.723x, 3.646x, and 3.634x.
The checksum was 5,662,000 in every run.

This is a focused matcher benchmark, not a whole-file Brotli throughput claim.
Preparation amortizes after only a small number of matches for this fixture,
while very small dictionaries may see less benefit. Reusable and incremental
encoders retain the prepared index across calls/blocks with the identical
borrowed descriptor; one-shot encoding prepares it per call.

## Correctness and bounds

- 64-context indexed/exhaustive differential tests cover local and fallback
  dictionary ordering and context-relative address calculation.
- Descriptor-identical prepare performs no allocation.
- Failed replacement preparation leaves the previous index usable.
- Candidate spaces above 1,048,576 theoretical entries use the exhaustive
  matcher rather than silently dropping legal words or transforms.
- Production one-shot, reusable, chunked, and incremental encoding preserve an
  exact address/mode invariant independently for LSB6, MSB6, UTF8, and Signed.
