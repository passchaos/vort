# zstd x-ray weak row root cause: four-stream Huffman blocks fall through the X2 gate, 2026-11-16

## Trigger

The full-Silesia sweep
([wire-full-silesia-20261116](wire-full-silesia-20261116/README.md)) found
`x-ray` at Vort/reference **0.550**, the worst of twelve files against libzstd
1.4.8. Telemetry explains why it is a different regime from the documented FSE
sequence wall: x-ray is 99.85% literals (8,461,194 literal bytes vs 13,046
match bytes) with only 1,829 sequences across 65 compressed blocks (~28
sequences/block). Sequence decode cannot be the bottleneck when there are
almost no sequences; the dominant work is Huffman literal decoding.

## Code path

One-shot four-stream Huffman literal decode is in
`src/zstd.zig` `decodeLargeFourStreamHuffmanImpl`. The accelerated two-symbol
(X2) decoder runs only when one of three gates holds:

- main: `regenerated_size >= 12 KiB` and
  `compressed_size * 1000 <= regenerated_size * 660` (encoded <= ~66%);
- wide: 7-bit tree, `regenerated_size >= 64 KiB`, ratio <= 90%;
- sparse: `preferSparseHighSequence` requires per-block
  `sequence_count` in `[1536, 2048)` (`huffman_x2_policy.zig`).

If none fires (or the X2 request returns `unsupported`), the block falls
through to a scalar per-symbol four-stream loop with a small reservoir helper.
The fallback is byte-identical; `unsupported` simply continues, so gate
selection affects speed only, never correctness.

## Empirical findings (temporary inspection probe, since removed)

Walking a level-1 x-stream frame with the public
`inspectNativeFrame*` block API and reading each literal header's
`size_format`:

- `blocks=64 huffman_literal_blocks=65 four_stream=65 single_stream=0` —
  every Huffman literal section is four-stream, so the X2 decoder is
  structurally applicable; stream type is not the blocker.
- `pass_sparse_x2=0` — no block reaches the sparse gate (mean ~28
  sequences/block vs the required 1536-2047).
- Frame encoded ratio is ~79.9%, above the main gate's 66% threshold, so the
  compressibility gate also does not fire on typical blocks.

Net: x-ray's four-stream Huffman blocks satisfy none of the X2 entry
conditions and are decoded by the scalar fallback. That, not FSE sequence
recurrence, is the mechanism behind the 0.550 row.

## Why this is a distinct finding, not the known serial wall

- The prior serial-wall analysis explains sequence-heavy files (nci/xml) where
  the FSE `next_state` recurrence dominates. x-ray has almost no sequences.
- Here the limiter is a **gate coverage** gap for near-incompressible,
  sequence-sparse, four-stream literal sections: the existing X2 thresholds
  were tuned for either highly compressible blocks or a narrow high-sequence
  band, neither of which matches x-ray's shape.

## Candidate lever and why it is not implemented here

Widening an X2 entry condition (for example a ratio-bounded path for
large-regenerated, sequence-sparse four-stream sections) is fail-safe at the
byte level because `unsupported` already falls back to the scalar decoder. But
two things make it an uncommitted hypothesis rather than a change:

1. It is a hot-path heuristic; an over-wide gate can make many blocks attempt
   X2, fail `unsupported`, and pay twice. The repo's adoption rule is a paired
   two-baseline A/B with 3% geometric mean, 95% CI excluding parity and no
   control row below 0.98x. No such A/B has been run.
2. A failed X2 attempt's exact cost and the conditions under which X2 actually
   returns `unsupported` for this input are not yet measured, so the expected
   sign is unknown.

## Scope limits

- Single host, level-1 CLI-generated frame for the stream-type inspection;
  throughput numbers inherit the old libzstd 1.4.8 caveat (the gap is a lower
  bound).
- No production code changed; the probe was temporary and removed. This is a
  root-cause record and an A/B-ready hypothesis, not a performance claim or a
  fix.
