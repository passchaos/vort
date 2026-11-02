# Incremental Deflate decode is about 11–14x slower than one-shot

## Measurement

A small harness (`decode-incremental.zig`, local under
`/tmp/vort-decode-priority-20261031/`) drives
`RawDeflateIncrementalFixedLiteralDecoder` with a caller-provided 64 KiB
history, whole input, and 4 KiB output chunks, and verifies the output SHA and
guard bytes. The one-shot harness decodes the same wire into a caller buffer.

| Row | Incremental ns/decode | One-shot ns/decode | Ratio |
| --- | ---: | ---: | ---: |
| `dickens.64k.rawdeflate.9` | 1,281,448 | 91,307 | 14.0x |
| `dickens.1m.rawdeflate.9` | 14,014,103 | 1,254,372 | 11.2x |

Feeding 4 KiB input chunks instead of the whole wire changes nothing
(1,283,091 ns), so the cost is per decoded symbol, not per chunk.

## Cause

The incremental decoder is a resumable state machine with one phase dispatch
per symbol (`block_header`, `stored_lengths`, `dynamic_counts`,
`dynamic_lengths`, `symbols`, `length_extra`, `distance_symbol`,
`distance_extra`, `match_copy`, ...). Each symbol re-enters the switch, reloads
state, and decodes through the compact Huffman tables. The one-shot path
decodes whole blocks through the semantic loop with four-entry literal
speculation, a single reservoir shift per token, and vector copies.

## Direction

The windowed semantic loop (`decodeSemanticDynamicBlockIntoWindow`) is already
resumable: it returns `need_output` and is used by the PNG streaming decoders
with the output buffer as history. A fast streaming path could decode dynamic
blocks into a caller-provided window buffer (window length plus one maximum
match), slide the window when it fills, and copy completed bytes into the
caller's output slice. That keeps bounded memory while reusing the one-shot
loop, and should land within a small factor of one-shot instead of 11–14x.

The integration needs a bridge between the incremental bit state
(`bit_buffer`, `bit_count`, cursor) and `BufferedBitReader`, a new
`fast_dynamic_block` phase, window sliding, and output copying. It is a
multi-step change and must keep the existing symbol path as the fallback for
stored blocks, fixed blocks, small histories, and truncation.

## Status

Measured only; the fast path is not implemented yet. The one-shot corpus
screens are unaffected by this gap.
