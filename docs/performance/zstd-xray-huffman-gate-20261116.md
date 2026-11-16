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

## Gate-widening hypothesis: tested and falsified (2026-11-16)

Widening an X2 entry condition is fail-safe at the byte level because
`unsupported` already falls back to the scalar decoder, so a temporary local
experiment could test it without any output risk. The main gate's ratio term
was relaxed from `compressed*1000 <= regenerated*660` to `*1000` (allow up to
a 100% ratio), rebuilt, run through `run-zstd-reference-bench`, then reverted
with `git checkout` (no production change retained):

| run | x-ray V/R | xml V/R (compressible control) |
| --- | ---: | ---: |
| current gate | 0.5503 | ~0.789 |
| relaxed gate | 0.5249 (two runs, identical) | 0.7813 |

Interpretation:

- On x-ray the relaxed gate is deterministically **~4.6% slower**, not faster,
  while output stays correct (the bench verifies equality). X2 engages (the
  compressible control improves slightly, proving the path works), but its
  11-bit two-symbol table costs more than the scalar four-stream reservoir path
  for long-coded, near-incompressible symbols.
- Therefore the existing 66% ratio gate is **correctly tuned**, not a coverage
  bug: it keeps exactly this data shape out of a path that loses on it.
- The gate-widening lever for x-ray is closed by measurement, not left open.
  No intermediate threshold helps because X2 itself is slower for this symbol
  distribution, independent of where the entry bar sits.

## Scope limits

- Single host, level-1 CLI-generated frame for the stream-type inspection;
  throughput numbers inherit the old libzstd 1.4.8 caveat (the gap is a lower
  bound).
- No production code changed; the inspection probe and the gate edit were both
  temporary and removed/reverted. This is a root-cause record plus a falsified
  optimization hypothesis, not a fix.

## Postscript: the single-sequence path bypassed the gate (2026-11-16)

The x-ray hot chain resolves further up than the gate: an LBR call graph shows
`decodeLiteralOnlyCompressedBlockIntoBuffer -> decodeSinglePredefinedSequence
-> copyHuffmanLiteralsFromSection -> HuffmanLiteralCursor.readSymbol`. That
executor decoded a single-sequence block's Huffman literal section twice from
the start, once per literal run, through the checked per-symbol loop. Decoding
a four-stream section once with the reservoir directly into the output, then
sliding the tail right for the match, moves x-ray from 0.3364 to **0.7811**
(2.32x in the increment, 2.39x versus the original 1.6.0 baseline; evidence:
[data/zstd-single-sequence-huffman-20261116](../data/zstd-single-sequence-huffman-20261116/README.md)).

The gate analysis above remains correct: widening the X2 entry gate is still
slower for this symbol distribution. The win came from the single-sequence
executor not using the reservoir path at all, not from changing the gate.

