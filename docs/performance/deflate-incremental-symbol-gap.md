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
| Comptime length/distance metadata tables | 267,100 | 3,810,800 |
| Bulk 8-byte reservoir refill | 227,370 | 3,225,000 |
| Local history/output state in the run loop | 223,370 | 3,153,250 |

The fused loop cuts 4.9% at both sizes; inlining `copyMatchSpan` cuts another
5.9% at 64 KiB and 6.4% at 1 MiB. Replacing the per-match length/distance
metadata arithmetic with comptime `base | extra << 16` tables cuts another
1.2% at both sizes and 1.2% of instructions (52.1M → 51.5M per 1 MiB). The
bulk refill stages up to seven whole bytes with one unaligned 8-byte load
instead of one byte per refill; it cuts 15.0% at 64 KiB and 15.6% at 1 MiB
and 7.7% of instructions (51.5M → 47.6M per 1 MiB). Keeping `history_pos`,
`history_len` and `total_output` in run-loop locals cuts another 1.8% at
64 KiB and 2.2% at 1 MiB, and 4.3% of instructions (47.6M → 45.6M). Against
the untouched start of this session the streaming decoder is now 5.74x faster
at 64 KiB (1,282,030 → 223,370 ns) and 4.38x at 1 MiB
(13,805,130 → 3,153,250 ns). One-shot `decodeRawAuto` on the same rows is
90,860 and 1,249,270 ns, so the remaining gap is 2.46x and 2.53x instead of
14.0x and 11.2x. `memcpy` remains the largest non-step component.

Two correctness lessons came out of this increment. First, the initial version
ORed the full 8-byte load into the reservoir and relied on the lookahead bits
being re-staged identically later; that assumption failed across some block
boundaries (`mozilla.1m.l9` reported `InvalidDeflateBlockType` at 17/5, 64/16,
4096/65536 and 65536/1 chunk shapes), so the reservoir is now masked to the
staged width. Second, lookahead must not be reported as consumed across pauses.
Rewinding it unconditionally deadlocked one-byte chunks (the caller re-supplied
the same byte while the decoder needed the next one), while never rewinding let
gzip/zlib wrappers lose the footer offset. The adopted policy rewinds complete
unconsumed bytes at output pauses, block ends and the final EOB, but never when
input is exhausted, because those bytes belong to the incomplete token. The
rewind is bounded by the current call's staged byte count, so whole bytes
already reported by an earlier call stay resident instead of being dropped.

The trailing probe covers dynamic, fixed and stored streams with 0-24 appended
bytes across seven input/output chunk shapes in strict and
`allow_trailing_data` modes; all pass with exact EOB progress.

## Third increment: deferred step-end history recording

Inside one `step` call the decoder now writes literals and matches only to the
caller's output slice. Match sources are resolved against the combined history
(pre-step ring followed by this step's output prefix), and the ring is updated
once at step end with a single bulk copy of `output[0..output_written]`.

| Step | `dickens.64k.l9` ns | `dickens.1m.l9` ns |
| --- | ---: | ---: |
| Local history/output state | 223,370 | 3,153,250 |
| Deferred step-end history recording | 209,230 | 2,917,280 |

The win is 3.6-7.8% across all eleven Silesia sources at 1 MiB level 9
(Dickens 7.4%, XML 7.8%, reymont 7.1%, x-ray 7.0%, nci 6.2%, mozilla 1.8%),
and 6.3-7.5% on the two Dickens rows. Against the start of this session the
streaming decoder is now 6.13x faster at 64 KiB (1,282,030 → 209,230 ns) and
4.73x at 1 MiB (13,805,130 → 2,917,280 ns). The one-shot gap is 2.29x and
2.35x.

A fresh C harness against classic zlib 1.2.11 raw `inflate` (same 65536/4096
chunks, CPU2, `-O3 -march=skylake`) now puts the decoder ahead on Dickens
(0.94x), nci (0.88x), reymont (0.93x), XML (0.89x) and osdb (0.96x), about
even on ooffice (1.02x), and still behind mozilla (1.51x), sao (1.22x), x-ray
(1.12x), mr (1.11x) and samba (1.10x). Those remaining rows are dominated by
literal/short-match work rather than history copying.

## Fourth increment: adjacent-literal peek

After writing a literal the run loop now peeks the next 11-bit (dynamic) or
9-bit (fixed) lookup entry and, when it is another literal that fits the
staged bits, writes it in the same iteration. This avoids the loop back-edge,
bulk-refill guard, dynamic/fixed branch, staged-literal check and limit
checks for the second literal.

| Step | `dickens.64k.l9` ns | `dickens.1m.l9` ns |
| --- | ---: | ---: |
| Deferred step-end history | 209,230 | 2,917,280 |
| Adjacent-literal peek | 204,330 | 2,903,120 |

The Dickens rows gain 2.0% and 0.7%, but the win is much larger on
literal-heavy sources at 1 MiB level 9: mozilla 16.2%, osdb 12.5%, sao 8.9%,
samba 7.3%, ooffice 4.8%, nci 2.4%, XML 2.2%; mr and x-ray stay inside noise.
Against the start of this session the streaming decoder is now 6.27x faster at
64 KiB (1,282,030 → 204,330 ns) and 4.76x at 1 MiB
(13,805,130 → 2,903,120 ns). The one-shot gap is 2.24x and 2.33x.

Against classic zlib 1.2.11 the decoder is now faster on Dickens (0.93x), nci
(0.86x), ooffice (0.97x), osdb (0.84x), reymont (0.93x) and XML (0.88x), about
even on samba (1.02x), and still behind mozilla (1.27x), sao (1.12x), x-ray
(1.12x) and mr (1.12x).

## Fifth increment: lower bulk-refill threshold

The bulk refill now runs only when the reservoir holds fewer than 32 bits
instead of 56, staging three or four whole bytes at a time and letting the
byte-at-a-time helpers cover long match tokens. This roughly halves the
per-token refill body work.

| Step | `dickens.64k.l9` ns | `dickens.1m.l9` ns |
| --- | ---: | ---: |
| Adjacent-literal peek | 204,330 | 2,903,120 |
| Refill threshold 56 → 32 bits | 196,570 | 2,789,260 |

The win is 0.8-9.0% across the corpus (mozilla 9.0%, samba 5.9%, nci/mr 4.0%,
Dickens 3.9%, x-ray 3.7%, reymont 3.5%, sao 3.2%, XML 2.1%, ooffice 1.3%,
osdb 1.2%), and 3.6% on both Dickens rows. Against the session start the
streaming decoder is now 6.52x faster at 64 KiB (1,282,030 → 196,570 ns) and
4.95x at 1 MiB (13,805,130 → 2,789,260 ns). The one-shot gap is 2.16x and
2.24x.

Against classic zlib 1.2.11 the decoder is now faster on Dickens (0.90x), nci
(0.84x), ooffice (0.96x), osdb (0.83x), reymont (0.89x), samba (0.98x) and
XML (0.86x), and behind only mozilla (1.16x), mr (1.08x), sao (1.07x) and
x-ray (1.07x).

A `noinline` `step` regressed 3.4%, `noalias` input/output parameters regressed
12%, and a 16-byte scalar copy loop regressed 25%; all were reverted. Packing
the length/distance metadata into the lookup entry as a 64-bit semantic table
regressed 7% (1,162 → 1,243 ms per 300 decodes): the wider entry doubles the
table footprint and adds extraction shifts, so the 16-bit lookup plus the
small metadata tables stay. Splitting the run loop into comptime
limited/unlimited instantiations to skip the per-literal limit checks regressed
26% (1,532 → 1,933 ms per 400 decodes, 15.45B → 19.72B instructions), so the
runtime checks stay.

## Sixth increment: caller-owned semantic window

The RFC 1951 dynamic-block path can now reuse the one-shot semantic table and
linear decode loop when the caller supplies two Deflate windows (64 KiB),
attaches a caller-owned semantic-table workspace, and at least 4 KiB of
contiguous compressed input remains after the dynamic header. The first window
is still the ordinary 32 KiB fallback ring; the
second lets the decoder generate one bounded window ahead, deliver it through
arbitrarily small caller output slices, and retain the newest 32 KiB before
continuing. The existing compact symbol machine remains the path for 32 KiB
history, fixed/stored blocks, Deflate64, small streams, incomplete semantic
trees and fragmented input.

`BufferedBitReader` accounting is now delta-based, so the semantic loop can
start with the incremental decoder's preloaded reservoir. Complete staged
bytes are rewound before reporting progress, preserving zlib/gzip footer
ownership. A semantic attempt that reaches the end of the current input slice
is transactional: generated scratch is discarded and the same block continues
through the compact symbol path from the original reservoir.

The semantic tables are also caller-owned instead of embedded unconditionally.
The standard incremental decoder grows from 9,008 to 9,072 bytes (+64), while
the opt-in `SemanticWorkspace` is 19,496 bytes and can be reused across reset
and concatenated wrapper members.

Three alternating CPU2 sweeps (ReleaseFast, Zig 0.16.0, whole input, 4 KiB
caller output) compare 32 KiB symbol-only history with 64 KiB semantic history
in the same binary:

| Row | Symbol ns/decode | Semantic ns/decode | Semantic / symbol |
| --- | ---: | ---: | ---: |
| `dickens.64k.rawdeflate.9` | 211,674 | 136,406 | 0.644 |
| `dickens.1m.rawdeflate.9` | 2,886,063 | 1,893,960 | 0.656 |

The matching current one-shot measurements are 92,857 and 1,272,231
ns/decode, leaving streaming at 1.47x and 1.49x rather than 2.16x and 2.24x.
The build-integrated benchmark now measures `vort-symbol` and
`vort-semantic` in the same process, records semantic-block selection, adds a
64 KiB structured-text case, and requires at least a 5% whole-input win. Its
initial 200-iteration screen measured 0.747 semantic/symbol on that case
(210,602 to 157,423 ns/decode). A 4 KiB minimum contiguous-input policy avoids
the measured table/scratch overhead on the existing 4 KiB and 32 KiB tiny
highly repetitive cases.

Correctness coverage includes a block spanning multiple retained windows,
4 KiB output backpressure, an 8 KiB first-input attempt that transactionally
falls back to one-byte input chunks, exact zlib footer ownership, nonzero
initial reservoir accounting, and the pre-existing raw/zlib/gzip incremental
matrices.

## Seventh increment: lazy compact lookup preparation

Dynamic semantic blocks now skip compact primary lookup construction; actual
compact admission and transactional fallback expand it from the already
validated canonical Huffman entries. Once-per-block preparation is outlined
from `step`, and table helpers/window tests are split into cohesive modules.
Five alternating twelve-source Silesia sweeps at levels 6/9 and 64 KiB/1 MiB
reduce whole-input latency by 3.5–4.5%, while 4 KiB-input group means improve
0.4–1.1%. All 960 processes verify content and guards; new tests cover poisoned
lookups, changing block alphabets and reset/fallback. See
[protocol and all rows](deflate/compact-tables.md).

## Status

The first bounded semantic fast path is implemented for standard dynamic
Deflate blocks with opt-in 64 KiB caller history and table workspace. It closes most of the
streaming/one-shot gap on the measured Dickens rows while preserving the
32 KiB ABI and compact fallback. Broader block-shape admission and direct
caller-output decoding remain follow-up opportunities.
