# Brotli external literal lookup

This note records the 2026-09-25 optimization of large standard Brotli streams
whose literal trees are too dense to store an in-table lookup. The measurements
use Zig 0.16.0 ReleaseFast on an Intel Core i9-13900K, with one codec thread
pinned to CPU 8 and libbrotli 1.1.0 as the reference.

## Motivation and implementation

The existing fast path stores an 8-bit lookup in the unused tail of each
canonical Huffman table. That works well for sparse, highly clustered streams,
but a dense 256-symbol tree has no spare entries. Such a tree fell back to a
bit-at-a-time canonical scan for every literal. A `perf` profile of
`~/Downloads/白话机器学习中的数学.pdf`, compressed by libbrotli at quality 5,
attributed 71.64% of samples to that scalar 256-symbol decoder. Vort reached
only 17.71 MiB/s, or 0.0476x libbrotli throughput.

Large meta-blocks with at most 16 literal trees now build separate packed
10-bit lookup tables. Each slot is one `u16` containing the decoded symbol and
code length. Short codes decode in one indexed load; longer codes retain the
canonical fallback and the same truncation checks. The route is limited to
meta-blocks of at least 64 KiB so small streams do not pay the setup or stack
cost. Existing in-table lookup routing remains unchanged for larger sparse tree
sets.

The generic `PackedLookup` has a direct dense-table, long-code-fallback, cursor,
and truncated-input oracle. A Brotli production test also requires the new
large-meta-block route to execute while round-tripping a two-tree entropy-split
stream.

## Downloads corpus evidence

The baseline and candidate executables were frozen and alternated in each
pair. Every invocation regenerated the Brotli frame through libbrotli and
verified Vort's complete output before entering five best-of timing rounds.

| Input / quality | Pairs won | Median speedup |
| --- | ---: | ---: |
| `白话机器学习中的数学.pdf`, q1 | 5/5 | 9.3776x |
| `白话机器学习中的数学.pdf`, q5 | 7/7 | 7.8520x |
| `白话机器学习中的数学.pdf`, q9 | 5/5 | 8.6144x |
| `Controller.log.2025-09-01-11`, q5 | 7/7 | 1.1103x |
| `trace_1751546764.3447797.json`, q5 | 7/7 | 1.0734x |

A longer same-process q5 comparison on the 6,105,445-byte PDF measured Vort at
154.55 MiB/s and libbrotli at 375.41 MiB/s, a 0.4117x ratio. This is a large
improvement over the 17.71 MiB/s / 0.0476x baseline, but it is not yet a claim
of Brotli decode parity or industry leadership.

An 11-bit lookup was rejected after seven alternating comparisons: it lost all
seven by about 0.07% median while doubling lookup storage. A forced-inline bit
reader experiment was also rejected after losing the stable-frequency pairs by
about 0.8%. Expanding the external lookup from 16 to 32 trees was effectively
neutral while doubling its maximum stack footprint, so the smaller bound was
retained.

## Reproduction

```sh
taskset -c 8 zig build -Doptimize=ReleaseFast run-br-reference-bench -- \
  --input "$HOME/Downloads/白话机器学习中的数学.pdf" \
  --name download_pdf_q5 --quality 5 --iterations 8
```

The built-in reference gate and upstream multi-block differential remain the
broader compatibility checks for this path.

## Deferred canonical-tree access follow-up

The first external-lookup implementation still resolved the large canonical
`PrefixCode(256)` object and checked its single-symbol tag before every lookup,
even when the packed root table contained the answer. The lookup now represents
single-symbol trees directly and exposes separate fast-hit and long-code
fallback operations. The payload loop touches the original canonical tree only
after a root-table miss.

Against the first 10-bit implementation, fixed-CPU interleaved measurements on
the same Downloads corpus produced:

| Input / quality | Pairs won | Median speedup |
| --- | ---: | ---: |
| `白话机器学习中的数学.pdf`, q1 | 5/5 | 1.1385x |
| `白话机器学习中的数学.pdf`, q5 | 9/9 | 1.1181x |
| `白话机器学习中的数学.pdf`, q9 | 5/5 | 1.1161x |
| `Controller.log.2025-09-01-11`, q5 | 6/7 | 1.0075x |
| `trace_1751546764.3447797.json`, q5 | 7/7 | 1.0212x |

The longer PDF q5 comparison now measures 173.49 MiB/s, or 0.4589x of
libbrotli 1.1.0. The remaining profile is dominated by the context-dependent
literal loop and bit-reservoir refill rather than canonical-tree scans.

## Local output cursor

The external-lookup executor now keeps its output position in a local cursor
for the full meta-block and commits it through `defer`, including error exits.
This removes a caller-pointer load and store from every decoded literal without
changing partial-progress behavior.

Eleven alternating q5 runs on `~/Downloads/白话机器学习中的数学.pdf` all
improved, with a 1.0329x median. The `part1_22.pdf`, 63 MiB log, and 31 MiB
trace controls remained neutral to slightly positive by median at 1.0016x,
1.0004x, and 1.0020x. A longer same-process comparison measured 179.10 MiB/s,
or 0.4778x libbrotli 1.1.0. An attempted literal-block-run cache was rejected
because it regressed the trace control.

## Full inline-tree coverage

The original 16-tree cap left most of `~/Downloads/part1_22.pdf` on the scalar
decoder; its quality-5 stream reaches 78 context trees overall and decoded at
only 11.59 MiB/s, or 0.0388x libbrotli. Raising the external lookup capacity to
the decoder's complete 64-tree inline tier covers more of those meta-blocks
without changing the packed-tree fallback.

Seven alternating comparisons improve this second PDF by 2.4731x median with
7/7 wins. The resulting same-process measurement is 41.63 MiB/s, or 0.1203x
libbrotli 1.1.0. The first PDF is neutral at 0.9994x median because all its
blocks were already covered. The 63 MiB log has a positive but noisy 1.0163x
median, while the 31 MiB trace is effectively neutral at 0.9983x. A 128-tree
prototype was rejected because it crossed the 64-entry inline-tree boundary;
the retained bound is tied directly to `inline_literal_tree_count` and guarded
at compile time.
