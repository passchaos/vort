# Zstd decode hotspot assessment, 2026-11-14

Status: diagnostic profile only; no production source changed. Completes the
three-codec hotspot picture alongside the Deflate token study and Brotli
profile from the same date.

## Method

`perf record -F 997 -g -e cycles:u` on the slowest current Zstd row, mozilla
1 MiB level 3 (matrix time ratio 1.667x), using the pinned
`vort-decode-compare` probe (SHA
`66bc992521fba3c03c7444fa59f2bcedeed1e5da5ece6f20a4f1f04919447e6b`) and
libzstd 1.6.0. 200 iterations, two warmup and two measured paired batches,
CPU 15 on the i7-10700K.

## Symbol attribution (whole process, self weight)

| Symbol | Self % | Role |
| --- | ---: | --- |
| `tryDecodeAllFseSplitDenseHuffmanSequencesNative` | 27.63 | four-stream Huffman literals + FSE sequence loop |
| libzstd `ZSTD_decompressBlock_internal` | 26.35 | reference kernel |
| compiler-rt memcpy | 7.24 | literal and match copies |
| compiler-rt memset | 7.03 | FSE table build/normalized-count workspaces |
| `sequence.small.compact_no_low.buildAssumeValid` | 3.15 | small no-low FSE table build |
| `decodeAllFseRawSequences` | 3.15 | raw sequence FSE loop |
| `decodePredefinedOffsetFsePredefinedRaw` | 2.45 | predefined offset path |
| `decodeFourStreamHuffmanReservoirNative` | 1.57 | Huffman reservoir |
| `readModeSequence` | 1.05 | block mode dispatch |
| `sequence.normalized_counts.parse` | 1.05 | normalized count parser |
| `sequence.fse_builder.buildMapped` | 0.90 | generic mapped FSE build |
| `tryDecodeMediumSplitHuffmanSequencesNative` | 0.89 | medium split fallback |
| `decodeLinearZstdHuffmanTree` | 0.71 | linear Huffman fallback |

## Structural observations

1. The dominant Vort function is one monolithic noinline kernel covering
   both four-stream literal regeneration and the FSE sequence loop. Its
   hottest instructions are 16-byte wildcopy vector loads/stores, matching
   the adopted 16-byte copy width; widening to 32/64 bytes was already
   measured slower and is not a candidate.
2. memcpy (7.24%) and memset (7.03%) together exceed every non-copy Vort
   function. The memset parent is `parseSequenceModeSpecInto` and the FSE
   table builders (`buildAssumeValid`, `buildMapped`, normalized-count
   parse), i.e. per-block table construction rather than payload decoding.
3. The compact no-low builder already avoids an intermediate table for
   64/128-state alphabets, but still fills local `symbols[128]` and
   `next[53]` arrays on every block. Frames with many blocks pay this
   repeatedly even when the normalized distribution is unchanged.
4. No single symbol inside the sequence loop dominates; the cost is spread
   across FSE state updates, offset resolution and copy dispatch, so a
   micro-tweak cannot move the aggregate the way the literal lookup work
   did in earlier sessions.

## Comparison with the other codecs

- Deflate: 66-70% throughput, hot loop already rejected five local
  prototypes; needs unconditional live-state removal.
- Brotli: 79-86% throughput, smallest 1 MiB gap (1.157x), concentrated
  distance dispatch; a cached-tree prototype was parity-only.
- Zstd: 75-77% throughput, cost split between a large copy kernel and
  per-block FSE table construction. The table-build memset/memcpy share
  (about 14% combined) is the most distinct actionable surface because it
  is setup work, not payload semantics, and is insensitive to copy-width
  decisions already settled.

## Recommended next step

Profile block counts and FSE table reuse across the mozilla/sao slow rows to
quantify how often identical normalized distributions recur. If reuse is
common, a cached/retained FSE table keyed on the normalized-count signature
could remove the repeated memset and spread work without touching the
sequence loop; if reuse is rare, the Zstd gap instead requires copy-kernel
restructuring that competes with the already-rejected wider wildcopy
trials. No A/B was run in this step; perf data remains under
`/tmp/vort-perf-20261114/zstd/`.
