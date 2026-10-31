# Brotli prepared prefix lookups

The incremental Brotli decoder resolves every literal, command and distance
symbol through a Huffman table. Before this increment the incremental path used
the canonical scalar scan (`HuffmanTable.decodeValue`), which reads one bit at a
time and linearly checks every entry at the current code width. The non-
incremental one-shot path already had tail lookups, but the public incremental
`IncrementalCopyStreamDecoder` did not.

## Change

Each `PrefixCode` now owns a lazily built 8-bit lookup. On first use it fills
`prepared_lookup` from the active table and sets `prepared`; every later decode
reads one 16-bit packed entry. Codes longer than eight bits fall back to
`decodeValueLongAfterLookup` after the same zero-padded peek, so malformed and
truncated behavior is unchanged. A tree with one symbol still returns that
symbol directly.

The lookup is cleared after every compressed-header parse. This matters for the
non-incremental large-window path, which parses each meta-block header into an
`undefined` stack value; the shared command reader must never observe
uninitialized readiness or a lookup built for the previous tree. The incremental
`installCompressedHeaderBits` path clears the same state again after installing
the header.

The incremental bit reader gained three primitives used by the lookup path:
`peekBitsPadded`, `hasStagedBits` and `advanceBitsStagedAssumeAvailable`. A test
compares their values and cursor state against committed `readBits` calls for a
random byte stream and a short tail.

Memory grows by 512 bytes per prefix tree (about 86 KB for the large-window
header's inline trees). The decoder remains well below its existing 1.5 MB size
contract.

## Correctness

The complete ReleaseFast Brotli suite passes 1504/1505 tests with one
32-bit-specific skip and zero failures. Focused Debug runs pass for the prepared
lookup/reader tests and for the large-window, whole-block and complete-length
transaction tests that previously exposed the undefined-header state. The
prepared lookup test compares canonical and prepared decoding symbol by symbol
over every byte truncation of simple, short, long-code and wide trees, and
checks that replacing a tree clears readiness.

## Measurement

The same minimal harness as the decoder-priority epochs was built twice from the
frozen header-ownership baseline and the final source. Each process times
`resetForTiming` plus direct `step`/`finish`; loading, buffers, warmup, complete
output checks, SHA and guards stay outside the timed interval. Two alternating
sweeps cover all twelve Silesia sources at 64 KiB and 1 MiB, qualities 6 and 11,
for 48 rows and 288 processes. Input and output chunks are 64 KiB/1 MiB and
4 KiB. The ordinary call runs on logical CPU2 of an Intel i7-10700K with Zig
0.16.0 ReleaseFast, GNU target `skylake+pku+sgx`, and an explicit 8 MiB stack
limit. Binaries are `e3a76a00…` (baseline), `d1c8848b…` (final) and `6f90ab22…`
(libbrotli 1.2.0 reference).

Lower is faster. Ratios are geometric means over the twelve sources per row
group; the reference column is a different lifecycle and is not an apples-to-
apples streaming comparison.

| Producer quality / scope | Final / baseline | Final / reference |
| --- | ---: | ---: |
| q6 / 64 KiB | 0.6513 | 4.9070 |
| q6 / 1 MiB | 0.5937 | 5.0780 |
| q11 / 64 KiB | 0.6308 | 3.7692 |
| q11 / 1 MiB | 0.5687 | 4.1561 |

All 48 rows together have a geometric mean of 0.6103. The two sweeps
independently reduce to 0.6092 and 0.6114. The fastest rows are Mozilla 1 MiB
q11/q6 at 0.278/0.282; the only row at or above parity is x-ray 1 MiB q11 at
1.017, with sweeps 1.012 and 1.021. The median row ratio is 0.6785.

These numbers measure the incremental decoder only. A matching reference
streaming lifecycle and one-shot public-API epochs remain separate work. The raw
records, comparison and build logs are kept locally under
`/tmp/vort-br-lookup-20261101/`; the repository keeps only this Markdown record
under the current lean-evidence policy.

## Next work

The remaining incremental cost is dominated by per-step bookkeeping, context
selection and copy dispatch. The one-shot path already uses a different literal
lookup strategy and is not covered by this epoch. Next decoder work should
compare the one-shot and incremental APIs separately, then target the hot
context/copy dependencies rather than adding wider lookup roots.
