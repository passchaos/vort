# zstd decode against current libzstd 1.6.0 (full Silesia), 2026-11-16

## Why this package exists

Every prior Vort-vs-zstd number used the system **libzstd 1.4.8 (2020)**, so
the READMEs called those ratios lower bounds on the competitive distance and
made "measure against a current upstream" the top credibility gap. That gap is
now closable offline: a built **libzstd 1.6.0** already exists locally, and its
SHA-256 matches the identity pinned by
`tools/zstd/incremental_parallel_diff.py` (`LIBRARY_SHA` / `HEADER_SHA`), so
it is the same verified reference the repo's own gate expects.

This package re-runs `run-zstd-reference-bench --libzstd <1.6.0>` on all
twelve Silesia files, 20 iterations, same host and method as the 1.4.8 sweep.

## Result: the gap is larger against current upstream

| reference | min | median | max | Vort faster |
| --- | ---: | ---: | ---: | ---: |
| libzstd 1.4.8 (old) | 0.550 | 0.799 | 0.909 | 0/12 |
| **libzstd 1.6.0 (current)** | **0.326** | **0.760** | 0.795 | 0/12 |

Per-file comparison is in `zstd-1.6.0-comparison.csv`. Vort is behind on 12/12
against 1.6.0, median 0.760 (~24% slower) versus 0.799 against 1.4.8.

The widening is not uniform; two files stand out:

- `x-ray`: 0.550 vs 1.4.8 collapses to **0.326 vs 1.6.0** (a 40.6% relative
  worsening). Modern libzstd improved its near-incompressible Huffman-literal
  path substantially, while Vort's X2 gate analysis already showed its scalar
  fallback is the best it can do for that shape.
- `mr`: 0.773 -> 0.603 (-22%); `sao` 0.909 -> 0.795 (-12.5%).
- Typical sequence-heavy files move 4-7% (e.g. xml 0.790 -> 0.761).

## Interpretation

- The earlier "lower bound" caveat was correct: comparing only to 1.4.8 made
  Vort look closer to parity than it is against a maintained implementation.
- The two weak-row mechanisms documented earlier (FSE serial wall for
  sequence-heavy blocks; Huffman X2 gating for near-incompressible blocks) both
  sit on paths where upstream has kept optimizing, so the deficit compounds on
  those shapes.
- Nothing here changes the conclusion that the remaining work is structural
  (executor/table fusion, SIMD gather, or the native parallel-entropy format),
  not a local reversible edit.

## Scope limits

- Single host (i7-10700K), one round at 20 iterations, no CPU pinning or paired
  interleave: directional evidence, not the section-8 adoption gate. The
  stability package showed sub-0.7% CV, so the medians are repeatable.
- The 1.6.0 library identity is verified by SHA against the repo's pinned
  reference; only the decode one-shot path is measured (no encode, RSS,
  streaming, or cold/warm split).
- This package supersedes the 1.4.8-based lower bound for zstd; the 1.4.8 CSVs
  are retained for provenance and before/after comparison.
- Measurement only; no production code changed.

## Follow-up

These ratios are the level-1 baseline for the wide-executor state localization
in [../zstd-wide-state-localization-20261116](../zstd-wide-state-localization-20261116/README.md),
which improves the twelve-file geometric ratio from 0.6957 to 0.7286.
