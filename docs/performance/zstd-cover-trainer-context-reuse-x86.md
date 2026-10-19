# Zstd COVER trainer context reuse on x86-64

This note records the 2026-10-19 optimization of pure-Zig COVER-class parameter
training. It is an internal shared-versus-separate comparison, not a claim that
Vort trains faster than libzstd COVER or FastCover.

## Change

The parameter optimizer previously called the one-shot selector independently
for every `(d, k, hash_log)` candidate. Each call rebuilt sample d-mer offsets,
rescanned the complete training corpus, and allocated fresh frequency and
active-window tables.

`cover.Prepared` now owns immutable offsets and base frequencies plus reusable
working-frequency and active-count tables for one `(d, hash_log)` pair. The
optimizer groups candidates by that pair and evaluates every requested `k`
with the prepared state. Candidate serial numbers preserve the original
`d -> k -> hash_log` tie order even though execution is grouped differently.

The retained tests compare every prepared candidate byte-for-byte with the
one-shot selector, compare the complete optimized result with a separate-
training oracle, exercise recovery after a candidate allocation failure, and
walk all allocation-failure paths.

## Reproduction

```sh
zig build run-cover-dictionary-train-bench-gate
```

The executable is always built in `ReleaseFast`. It generates deterministic
text, JSON, and binary corpora containing 24 samples of 320 bytes, uses 20 for
training and four for held-out scoring, evaluates twelve candidates
(`d=6/8`, `k=64/128/256`, `hash_log=12/16`), and records the best of three
rounds with 20 training iterations per round.

Environment:

- commit before the retained change: `03fa902e`;
- Zig `0.16.0`;
- `x86_64`, Intel Core i7-10700K, 8 cores / 16 threads;
- no CPU affinity or frequency pinning; the ratio and allocation gates compare
  both modes inside the same run.

## Result

| Corpus | Separate bytes/s | Shared bytes/s | Speedup | Allocations | Shared allocations | Allocated bytes | Shared allocated bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| text | 4,147,281 | 5,863,410 | 1.4138x | 60 | 40 | 3,351,336 | 1,678,824 |
| JSON | 4,140,216 | 5,770,268 | 1.3937x | 60 | 40 | 3,351,341 | 1,678,829 |
| binary | 2,051,313 | 2,401,549 | 1.1707x | 48 | 28 | 3,350,496 | 1,677,984 |

All corresponding checksum rows are identical. The permanent gate requires at
least `1.10x` shared/separate throughput, fewer allocations, and at most 75% of
the separate allocated-byte total for every corpus. The observed allocation
bytes are approximately halved because three `k` candidates reuse each pair's
frequency state.

The broader dictionary benchmark's unrelated `zstd_validated` absolute
throughput floor can remain sensitive to machine load. The dedicated COVER gate
therefore locks only the deterministic output and within-run structural ratios
shown here.
