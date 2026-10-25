# Deflate64 dynamic-Huffman functional baseline

Date: 2026-10-25. RLE increment: `a7e5320e`; integrated codec revision:
`02b6498a`. Dynamic integration and its functional validation are complete.
Each result below retains its source and measurement scope; the industry-best
functionality/performance objective remains incomplete.

## Public behavior

The increment adds `.dynamic` to `Deflate64IncrementalEncoder.Compression` and
adds `dynamic_block_count` to its diagnostic snapshot, counting emitted dynamic
blocks rather than candidate plans. Explicit `.stored` and
`.fixed` retain their strategies. `.dynamic` requests dynamic-Huffman blocks;
the default `.adaptive` compares stored, fixed and dynamic representations.
Non-final choices use their actual continuous bit costs. Finish compares final
padded byte counts. A candidate must improve the cost strictly: equal costs
prefer stored, then fixed, then dynamic.

One-shot `encodeAlloc`, `encodeInto` and `encodeAppend` retain their existing
options, without a new forced one-shot strategy. Each borrowed 128 KiB input
chunk chooses the smaller fixed/dynamic bit cost, preserving fixed on a tie.
Those selected blocks form one complete compressed candidate, with final
padding applied once. Private checked `u128` sizing compares that candidate
against the original global stored byte bound; only a strict winner narrows
to `usize` and allocates output. Global stored fallback and
`deflate64EncodedBound` remain the admission limit. Adaptive bytes may change.

The implementation reuses the same bounded matcher, 65,536-byte history and match
decisions. It retains no complete input copy or token array. Streaming gathers
the histogram/tree plan and then replays matches to emit a compressed block:
two match traversals. One-shot preflights the complete size, rebuilds each
chunk's tree plan and replays for emission: three traversals for nonempty
compressed input. This keeps state bounded but adds work; fewer retained tokens
do not imply faster encoding.

## Wire and cost invariants

Dynamic coding uses 286 literal/length symbols and all 32 distance symbols.
Length 258 remains symbol 284 with five extra bits valued 31; lengths
259...65,538 use symbol 285 with its 16-bit extension. Distance 65,536 uses
symbol 31 with fourteen extra bits. Length and distance mapping is shared with
the fixed writer, and every block includes one real end-of-block symbol.

The combined literal/distance code-length sequence is bounded by 318 entries.
Code-length RLE and its 19-symbol tree use the actual emitted operation
frequencies and extra bits. Zero/singleton trees are completed in separate
frequency copies; synthetic completion symbols are not charged as payload
tokens. Dynamic header, tree declaration, RLE, payload and extra-bit costs must
match actual emission rather than a histogram-only estimate.

Existing input, pending-output, exact-size, caller-output and failure-progress
contracts are preserved. Into/Append still complete the owned
encoded result before caller-output publication. Preset dictionaries are not
part of this increment.

## Final validation

The evidence directory is
[`data/deflate64-dynamic-20261025/`](data/deflate64-dynamic-20261025/).
Code-length RLE contracts pass 4/4; native Debug, native ReleaseFast and x86
codec contracts each pass 108/108, and focused ZIP contracts pass 44/44.
The final complete ReleaseFast ZIP/codec suite passes 2000/2000, build checks
177/177 and CLI help 7/7. The earlier full Debug oracle run reports 1998 passed
and one skipped out of 1999; its 64 MiB+1 LZMA-distance fixture runs only in
ReleaseFast and is covered by the final complete run. These aggregate suites
have different import/test scopes from the 108-test Deflate64 contracts.
The checks include exact
header/payload costs, padded ties, full length/distance geometry, rejected
incomplete multi-symbol trees, malformed/truncated dynamic data and preserved
nice values 0/1/2, output ownership and failure cleanup.

Final native and x86 public schema-3 campaigns each verify 80 artifacts,
112 member plaintexts and 154 recorded commands through independent exact-bit
parsing, metadata checks and Info-ZIP full-content extraction. Each campaign
checks 35 dynamic blocks and 4,600,430 dynamic encoded bits across repeated
raw/ZIP member records, not 35 distinct corpus inputs. Native/x86 complete
manifests and results agree with each other and with the initial campaigns.
The final source manifests and probe/report identities are bound to `02b6498a`;
earlier probes retain their own identities rather than being relabeled after
the two local-workspace comments changed the source manifest.

An older ZIP test expected fixed BTYPE 1 for the default long-distance fixture;
the new default selects dynamic BTYPE 2, and that assertion was updated. A
Python helper also had a historical code-length order error for symbols
12/3, 13/2 and 14/1; its independent 121-bit golden and negative cases were
corrected. Neither helper/test correction required changing codec semantics.

## Encoded size and requested allocation

The strictly validated old/new resource reports retain identical inputs,
options and encoded bounds. On the 131,072-byte distant fixture, dynamic output
is 65,633 bytes versus 69,098, a reduction of 3,465 bytes (about 5.015%). Codec
peak requested live bytes change from 462,314 to 458,849 by the same 3,465 bytes.
The non-output allocation payload is unchanged at 393,216 bytes; the reduction
comes entirely from the returned output, not a smaller matcher or tree scratch.
The other six one-shot reports retain identical wires and allocation ledgers.
The 4 MiB reused-input stream retains its 6,328-byte wire and 462,909-byte
requested peak.

All new one-shot timing fields are null. This resource comparison excludes
dynamic-tree stack workspace, allocator-internal physical remap transients,
RSS, decoder/collector memory and whole-process peaks. It is a specific encoded-
size and requested-allocation result, not a throughput or cross-library memory
ranking. The final requested-allocation report and source manifest retain their
own identities and agree with the pre-comment report in every resource/wire
field; no earlier report is relabeled as a new measurement.

The preceding
[index-capacity evidence](deflate64-index-capacity-x86.md) remains attached to
its own fixed/stored source and timing epoch. Its seven-input requested peaks
and mixed timing points cannot be refreshed as dynamic-encoder measurements.
No industry-best, all-quality, all-platform or uniform memory/speed claim follows
from adding a compatible dynamic block type.

Next work is explicit dictionary design and its caller-owned history contract.
ZIP method 9 has no preset-dictionary ID field, so dictionary use cannot be
enabled silently without an agreed out-of-band compatibility contract.
Broader Deflate64 comparisons and the existing Brotli/Zstd throughput roadmap
remain separate priorities. Adding dynamic coding does not close those goals.
