# Zstd COVER and FastCover trainer comparison on x86-64

This note records the 2026-10-19 held-out comparison between Vort's pure-Zig
COVER-class optimizer and the local zstd CLI's COVER and FastCover trainers.
It exposes both the remaining quality and training-time gaps; it is not an
industry-leading training claim.

## Reproduction

```sh
zig build run-zstd-cover-trainer-compare
```

The driver creates deterministic text, JSON, binary, and project-source
families with 40 samples each. For every family it assigns 32 samples to
training, four to parameter selection, and four to final held-out evaluation.
It trains:

- Vort with 30 `(d, k, hash_log)` candidates, using `d=6/8`,
  `k=32/64/128/256/352`, and `hash_log=12/16/20`;
- zstd `--train-cover` with its own parameter optimization;
- zstd `--train-fastcover` with its own parameter optimization.

All three are bounded to a 512-byte full dictionary. Vort reserves 352 bytes
for history because its trained entropy header occupies the remainder. Training
latency is the best of three complete runs. Held-out sizes are sums across four
payloads compressed by libzstd at levels 1, 3, and 9. The probe validates every
reference frame with Vort, every Vort dictionary frame with both Vort and
libzstd, and one native Vort frame per payload with libzstd.

Environment:

- base commit: `1f5e4932`;
- Zig `0.16.0`, Vort probe in `ReleaseFast`;
- zstd CLI and runtime `1.4.8`;
- `x86_64`, Intel Core i7-10700K, 8 cores / 16 threads;
- no CPU affinity or frequency pinning.

## Held-out compressed sizes

Each cell is `Vort / COVER / FastCover` in bytes.

| Corpus | Level 1 | Level 3 | Level 9 | Selected Vort `k/d/f` |
| --- | ---: | ---: | ---: | ---: |
| text | 337 / 343 / 317 | 298 / 285 / 285 | 265 / 263 / 245 | 32 / 8 / 12 |
| JSON | 198 / 170 / 185 | 212 / 170 / 185 | 189 / 187 / 199 | 64 / 8 / 16 |
| binary | 813 / 800 / 799 | 817 / 787 / 790 | 812 / 806 / 812 | 256 / 6 / 16 |
| source | 1,868 / 1,829 / 1,841 | 1,827 / 1,803 / 1,807 | 1,791 / 1,781 / 1,784 | 32 / 6 / 12 |

Across all twelve rows the totals are `9,427 / 9,224 / 9,249`: Vort is 2.20%
larger than COVER and 1.92% larger than FastCover. Text level 1 beats COVER,
and JSON level 9 beats FastCover, but JSON level 3 remains the largest gap at
24.7% versus COVER and 14.6% versus FastCover. Source and binary rows are
generally within about 0--4%.

The permanent gate limits any row to 26% over COVER and 16% over FastCover,
and both aggregate gaps to 3%. These are regression bounds, not parity claims.

## Dictionary and training sizes

| Corpus | Full dictionary bytes `V/C/F` | History bytes `V/C/F` | Training ms `V/C/F` |
| --- | ---: | ---: | ---: |
| text | 476 / 512 / 512 | 352 / 388 / 376 | 567.06 / 14.25 / 12.26 |
| JSON | 493 / 512 / 512 | 352 / 389 / 370 | 1,299.51 / 16.62 / 12.06 |
| binary | 494 / 512 / 512 | 352 / 362 / 363 | 67.61 / 29.27 / 18.54 |
| source | 509 / 512 / 512 | 352 / 358 / 358 | 259.94 / 43.70 / 20.08 |

Vort's training latency is currently about 2.3--108 times the faster reference,
depending on corpus. The permanent gate only prevents a catastrophic widening
beyond 200 times because process startup and this small corpus make absolute
latency noisy. Closing the gap requires parameter-grid frequency reuse across
hash logs, cheaper entropy finalization during search, and pruning candidates
with held-out lower bounds. Ratio work should prioritize JSON level 3.
