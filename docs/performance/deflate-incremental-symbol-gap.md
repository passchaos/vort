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

## First increment: canonical fallback tables and wider lookups

The symbol path now precomputes `huffman.HuffmanTable` instances when a dynamic
block header completes and resolves long codes by scanning the per-width entry
group instead of rebuilding canonical codes per miss. Five changes were
measured as paired runs on logical CPU2 (Zig 0.16.0 ReleaseFast,
`skylake+pku+sgx`), 2,000 iterations at 64 KiB and 300 at 1 MiB, with 64 KiB
history, whole input and 4 KiB output chunks:

| Step | `dickens.64k.l9` ns | `dickens.1m.l9` ns |
| --- | ---: | ---: |
| Before | 1,278,500 | 13,870,000 |
| Precomputed per-width fallback table | 373,045 | 5,283,500 |
| Remove ring `% history.len` divisions | 340,950 | 4,835,500 |
| Literal-run inner loop in `.symbols` | 330,450 | 4,686,500 |
| Literal primary lookup 9 → 11 bits | 320,150 | 4,607,700 |
| Distance primary lookup 8 → 10 bits | 305,400 | 4,334,700 |

The final paired runs against the untouched binary give 4.24x at 64 KiB
(1,279,500 → 301,950 ns) and 3.19x at 1 MiB (13,837,400 → 4,334,700 ns).
One-shot `decodeRawAuto` on the same rows is 90,730 and 1,244,900 ns, so the
remaining gap is 3.33x and 3.48x instead of 14.0x and 11.2x.

The `% history.len` terms in `recordByte`, `recordSpan` and `copyMatchSpan`
became single-wrap comparisons because every ring position stays below the
ring length. The literal path keeps its one-store history update; a run is
decoded inside the `.symbols` case so the phase switch is paid once per run.

Rejected or neutral experiments:

- Fusing length extra, distance symbol, distance extra and match copy into the
  `.symbols` case removed the indirect dispatches but measured
  0.4–0.9% (inside noise), so the phase form stays.
- Recording literal runs as one `recordSpan` copy instead of a per-byte ring
  store regressed 1.2% at 64 KiB and 1.5% at 1 MiB; runs are too short.
- A 12-bit literal primary lookup was neutral (0.13%) and is not kept.
- An 11-bit distance primary lookup regressed 3.2% against the 10-bit form,
  most likely from the larger per-block table build and zeroing.
- Replacing `@memcpy` with an inlined byte loop for spans up to 16 bytes
  regressed 25% (1,300 → 1,635 ms per 300 decodes). `compiler_rt.memcpyFast`
  already has a vectorized small-size path, and the extra length branch costs
  more than the call it avoids.

Incremental decoding then executed about 61M instructions per 1 MiB versus
14.4M for one-shot, and `memcpy` was 16% of that profile. The remaining cost is
the resumable phase machine plus the ring history copy, not a single hot
instruction.

## Second increment: fused local-reservoir symbol loop

The `.symbols` phase now calls `decodeSymbolRun`, which decodes literals,
length/distance headers, extra bits and the match copy in one loop with the
reservoir, partial-code state, input cursor and output cursor held in locals.
The phase cases remain only as the resumption owners for input exhaustion,
output-full pauses and partial match copies; `decodeSymbolRun` writes all shared
state back before returning. `copyMatchSpan` is `inline`, so its source
computation and ring recording fold into the loop.

| Step | `dickens.64k.l9` ns | `dickens.1m.l9` ns |
| --- | ---: | ---: |
| After first increment | 301,950 | 4,334,700 |
| Fused local-reservoir run loop | 286,940 | 4,125,970 |
| Inline `copyMatchSpan` | 270,700 | 3,842,200 |

The fused loop cuts 4.9% at both sizes; inlining `copyMatchSpan` cuts another
5.9% at 64 KiB and 6.4% at 1 MiB. Instruction count drops from 61.4M to 52.1M
per 1 MiB. Against the untouched start of this session the streaming decoder is
now 4.74x faster at 64 KiB (1,282,030 → 270,700 ns) and 3.59x at 1 MiB
(13,805,130 → 3,842,200 ns). One-shot `decodeRawAuto` on the same rows is
91,480 and 1,255,070 ns, so the remaining gap is 2.96x and 3.06x instead of
14.0x and 11.2x. `memcpy` is 19.4% of the remaining instructions, and `step`
itself is 79.5%.

A `noinline` `step` regressed 3.4%, `noalias` input/output parameters regressed
12%, and a 16-byte scalar copy loop regressed 25%; all were reverted.

## Status

The fused symbol-path increments are committed. The larger windowed semantic
fast path is still not implemented; it remains the direction below and the
symbol path stays as its fallback. The one-shot corpus screens are unaffected
by this gap.
