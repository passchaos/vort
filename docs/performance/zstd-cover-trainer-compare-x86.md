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
| source | 1,902 / 1,895 / 1,892 | 1,874 / 1,868 / 1,867 | 1,851 / 1,846 / 1,849 | 32 / 6 / 16 |

Across all twelve rows the totals are `9,568 / 9,420 / 9,425`: Vort is 1.57%
larger than COVER and 1.52% larger than FastCover. Text level 1 beats COVER,
and JSON level 9 beats FastCover, but JSON level 3 remains the largest gap at
24.7% versus COVER and 14.6% versus FastCover. Source and binary rows are
generally within about 0--4%.

The permanent gate limits any row to 26% over COVER and 16% over FastCover,
and both aggregate gaps to 3%. These are regression bounds, not parity claims.

## Dictionary and training sizes

| Corpus | Full dictionary bytes `V/C/F` | History bytes `V/C/F` | Training ms `V/C/F` |
| --- | ---: | ---: | ---: |
| text | 476 / 512 / 512 | 352 / 388 / 376 | 571.26 / 13.98 / 12.07 |
| JSON | 493 / 512 / 512 | 352 / 389 / 370 | 1,308.85 / 17.00 / 11.55 |
| binary | 494 / 512 / 512 | 352 / 362 / 363 | 68.03 / 29.38 / 18.02 |
| source | 509 / 512 / 512 | 352 / 359 / 358 | 1,213.25 / 42.74 / 20.96 |

Vort's training latency is currently about 2.3--113 times the faster reference,
depending on corpus. The permanent gate only prevents a catastrophic widening
beyond 200 times because process startup and this small corpus make absolute
latency noisy. Closing the gap requires parameter-grid frequency reuse across
hash logs, cheaper entropy finalization during search, and pruning candidates
with held-out lower bounds. Ratio work should prioritize JSON level 3.

## Codec-aware second-stage selection

The probe also scores all 30 histories with real selector-frame sizes. The
libzstd oracle uses libzstd for scoring; the production pure-Zig API
`zstdTrainCodecOptimizedCoverStandardDictionaryAlloc` uses Vort's encoder.

| Corpus | Generic held-out total | libzstd oracle | Pure-Vort codec score | Generic rank of lib/Vort winners |
| --- | ---: | ---: | ---: | ---: |
| text | 900 | 865 | 877 | 16 / 26 |
| JSON | 599 | 569 | 577 | 3 / 22 |
| binary | 2,442 | 2,426 | 2,423 | 19 / 26 |
| source | 5,627 | 5,630 | 5,622 | 4 / 22 |
| total | 9,568 | 9,490 | 9,499 | — |

The Vort codec scorer improves JSON level 3 from 212 to 195 and the aggregate
by 69 bytes; the source row is also five bytes smaller in this snapshot.
Generic-score ranks also show why a small top-N shortlist is insufficient:
three pure-Vort winners rank 22nd or worse.

This mode is intentionally explicit and slow. The default baseline-repcode
candidate search takes about 0.83--15.8 seconds for these small cases, versus
0.07--1.31 seconds for the match-cost selector. Setting
`candidate_repcodes=true` raises the range to roughly 2.1--51.7 seconds. The
permanent gate requires the key JSON level-3 improvement, limits every held-out
regression to 5%, limits aggregate regression to 2%, and caps the slow-mode
training-time ratio at 100x. It does not make codec-aware selection the default.

## Finalizer stage profile

The same 30-candidate reference loop aggregates profiled finalizer timings.
The exhaustive reference path reports:

| Corpus | Finalizer total | Repcode frame scoring | Share | Sequence collection share |
| --- | ---: | ---: | ---: | ---: |
| text | 15.871 s | 15.858 s | 99.919% | 0.060% |
| JSON | 36.202 s | 36.193 s | 99.974% | 0.019% |
| binary | 1.252 s | 1.224 s | 97.813% | 1.784% |
| source | 19.532 s | 19.503 s | 99.851% | 0.121% |

This evidence changes the optimization target: dictionary-aware greedy/lazy
parsing is not the dominant stage here. Re-encoding every training sample with
baseline and candidate repcodes is. Candidate search now scores with stable
`1/4/8` repcodes and fully retrains only the winner. Stable text, JSON, and
binary rows retain the same selected parameters and held-out bytes while
training improves by roughly 2.5--3.3x. Exhaustive per-candidate repcode search
remains available through `candidate_repcodes=true`.

An exact progressive experiment seeded the exhaustive search with the generic
winner and stopped encoding a candidate once its partial byte total could no
longer beat the current best. It preserved every selected parameter and output
byte, but did not produce a stable end-to-end gain: entropy finalization, which
must still run for every candidate, dominates this workload. Text, binary, and
source slowed slightly while JSON improved only about 2--3%, so the extra state
and generic pre-pass were removed.

The same exact cutoff was re-evaluated after candidate repcode scoring was
disabled. Text was effectively neutral, JSON improved by about 3.1%, while
binary and source regressed by about 2.7% and 1.4%. It was again removed rather
than making a corpus-sensitive generic pre-pass part of the default path.

A second experiment serialized the corpus-only literal Huffman entropy once and
reused it for all 30 histories. Normal and flat-corpus fallback tests were
byte-identical to separate finalization, but complete training did not improve:
text moved from about 24.19 to 24.63 seconds, JSON from 51.70 to 52.45 seconds,
and binary from 2.12 to 2.28 seconds. This refactor was also removed.

Reusing one `NativeFrameEncoder` and its retained scratch across all candidate
frames was byte-identical, but remained neutral: text and JSON improved by only
about 0.4--0.5%, while binary and source were flat or slightly slower. The
baseline-repcode profile shows that selector scoring is dominated by actual
search and arbitration rather than encoder construction, so this extra lifetime
state was removed as well.

## Baseline-repcode search profile

Profiling the production `candidate_repcodes=false` path separates the complete
candidate search from finalization and selector-frame encoding:

| Corpus | Total | Candidate search | Candidate finalizer | Selector encoding | Winner finalizer | Selector/search share |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| text | 8.241 s | 7.700 s | 10.7 ms | 7.665 s | 540 ms | 99.54% |
| JSON | 15.938 s | 14.579 s | 8.7 ms | 14.545 s | 1.359 s | 99.77% |
| binary | 0.890 s | 0.840 s | 23.6 ms | 0.793 s | 49 ms | 94.35% |
| source | 1.450 s | 1.154 s | 25.0 ms | 1.103 s | 296 ms | 95.55% |

Each row covers exactly 360 selector frames (30 candidates × four selector
samples × three levels). Candidate finalization no longer performs repcode
entropy or frame scoring, and history construction plus loop overhead is only
about 24--26 ms per corpus. The new dominant cost is real multi-level selector
encoding, not finalization or encoder allocation. Future speed work must reduce
the number or cost of those 360 encodes without losing the low-ranked winners.
