# Shared bit-reader frontend audit, 2026-11-14

Status: static audit, no production source changed. Tests the hypothesis
from the deflate hotspot review that a cross-codec bit-reader change could
reduce front-end footprint safely. Conclusion: the readers are already
specialized per codec and cannot be merged; no safe shared lever exists.

## Four distinct reader implementations

| Module | Used by | Reservoir style | Public API count |
| --- | --- | --- | ---: |
| `bitstream.BufferedBitReader` | deflate, deflate64, generic grammar | LSB-first u64, forward | 67 (shared module, includes chunked variants) |
| `br.fast_bit_reader.Reader` | brotli wide payloads only | LSB-first u64, staged refill tiers | 12 |
| `zstd.sequence.bit_reader.Reader` | zstd sequence fields | reverse, position-based u72 gather | 16 |
| `zstd.source.reverse_bit_reader.Reader` | zstd Huffman literals | reverse marker-terminated | 12 |

The zstd readers are reverse bitstreams with a highest-set marker bit; they
cannot share refill logic with the forward LSB-first deflate/brotli readers
without adding per-read direction branches. The brotli fast reader is
already a narrowed derivative of the forward design, not a duplicate.

## Forward readers: shared core, intentionally different fill policy

`BufferedBitReader.fill` (deflate) and `br.fast_bit_reader.Reader.fill`
(brotli) both stage a single unaligned u64, but:

- Deflate's semantic loop copies `bit_buffer`/`bit_count`/`byte_index` into
  locals and calls a local `refillBits` that assumes eight safe bytes, with
  the bounded tail handled separately. The standalone
  `BufferedBitReader.advanceBitsStagedAssumeAvailable` symbol costs 0.24% in
  the mr 64K L9 profile — negligible.
- Brotli's reader keeps explicit 8/16/32-bit refill tiers and a
  `lowByteBits` tail mask because its block grammar mixes header parsing and
  payload decoding in one frame, including final partial bytes. It syncs
  back to the grammar reader at block boundaries (`syncTo` at eight call
  sites).

Merging them would either push brotli's tail-mask branches into the deflate
hot loop or force brotli header parsing through the narrower reader, both
regressions with no measured upside. The current split is a deliberate
hot/cold grammar boundary, not accidental duplication.

## Measured frontend weight is already small

Deflate mr 64K L9 instruction profile:

- `linear_entry.aligned` (full semantic loop including inlined refill):
  52.30%
- standalone reader symbol (`advanceBitsStagedAssumeAvailable`): 0.24%
- table setup combined: ~3-4%

Brotli profiles from 2026-11-14 attribute reader symbols under 3% once the
auxiliary fixed-9/10 peek helpers are in place; the dominant costs are
table setup and copy kernels, not refill. The deflate branch-miss audit
shows misses diffuse inside the 3.6 KB semantic state machine, not in a
reader call, so shrinking reader code would not reduce the 3-4% branch-miss
rate.

## What this rules out

- A unified/shared reader across codecs: incompatible bit directions and
  grammar boundaries; would add branches to every read.
- Replacing brotli's fast reader with the shared `BufferedBitReader`: loses
  refill tiers and tail masking needed at block boundaries.
- Replacing deflate's local refill with a brotli-style tiered fill: adds
  width branches to a loop whose reader symbol already costs 0.24%.
- Reader-focused micro-edits as a response to the deflate front-end
  saturation: the reader is not where the front-end bytes or misses live.

## Remaining candidate space

The audit confirms the deflate gap is bound by the size and branch layout
of the inlined semantic loop itself, not its bit frontend. The only
untried structural option remains a smaller non-inlined loop core, which is
a high-risk rewrite requiring its own design/codegen package. Across the
whole decode suite, the low-risk local-edit surface is now exhausted:

- Brotli: seven rejected structural variants, reader/setup diagnostics
  complete.
- Zstd: retention and content caches measured at zero hit; copy-width
  trials rejected.
- Deflate: setup ~3-4%, reader 0.24%, loop front-end saturated with diffuse
  branch misses.

Further throughput work should either commit to the deflate loop-core
rewrite as a scoped project with explicit codegen-size acceptance criteria,
or pause decode micro-optimization until a new measurement identifies a
hotspot the existing profiles do not show.
