# DEFLATE fixed planning uses emitted Huffman costs

The fixed-Huffman planning model now charges exactly the bits emitted by the
wire writer. The previous length model stayed on the seven-bit literal/length
symbol tier through length 130 and charged 12 bits through length 257. RFC 1951
switches to eight-bit fixed symbols at symbol 280, so every match of length
115 through 257 was underestimated by one bit.

| Match length | Symbol | Fixed symbol bits | Extra bits | Emitted cost |
| --- | ---: | ---: | ---: | ---: |
| 3..10 | 257..264 | 7 | 0 | 7 |
| 11..18 | 265..268 | 7 | 1 | 8 |
| 19..34 | 269..272 | 7 | 2 | 9 |
| 35..66 | 273..276 | 7 | 3 | 10 |
| 67..114 | 277..279 | 7 | 4 | 11 |
| 115..130 | 280 | 8 | 4 | 12 |
| 131..257 | 281..284 | 8 | 5 | 13 |
| 258 | 285 | 8 | 0 | 8 |

`lz77.fixedLengthCost` and its compile-time table use those exact boundaries.
The token-scan, dense one-shot and incremental cached `DynamicCodingPlan`
paths no longer subtract one bit for symbols 280 through 284 after already
accounting for their fixed code and extra bits. The incremental rolling-hash
profitability filter now consumes the same shared exact functions instead of
retaining a fourth private copy of the old model. Its test oracle remains an
independent RFC formula.

This changes public fixed-bit statistics by one bit for each affected match and
can change optimal parsing, adaptive split points or stored/fixed/dynamic block
selection at exact cost boundaries. It does not alter fixed wire coding. The
old model could reserve too few fixed-output bytes, but the fixed writer uses
checked growing writes, so this was a planning/reallocation defect rather than
an out-of-bounds write.

## Exact emission oracle

The new writer-level test first failed on the old implementation with
`expected 43, found 44` at the first affected length. It now checks exact bit
deltas without byte-rounding:

- empty fixed blocks and both final-bit values;
- literal 143 and 144, independently crossing the 8/9-bit boundary;
- every legal match length from 3 through 258;
- the first and last distance of every RFC distance-code range;
- all eight incoming writer bit offsets.

The test passes the private production `writeFixedTokens` function into a
small external helper, so the actual header, Huffman encoders, extra fields and
end marker remain the authoritative cost oracle. Existing independent table
tests continue to verify length/distance symbol identities.

## Validation and observed compatibility

Native Debug and ReleaseFast each pass all 546 `deflate.zig` tests, including
the new emission oracle, independent incremental profitability checks and all
raw/zlib/gzip one-shot and streaming cases. ReleaseFast `lz77.zig` passes
90/90 tests.

The zlib 1.2.11 parameter interoperability campaign passes six cases over raw,
zlib and gzip wrappers, 84 parameter changes, partial flush and sync recovery
in both directions. The Python zlib black-box differential passes 265 commands
and 60 expected failures across valid, malformed, match-heavy and large-file
inputs. The incremental encode gate passes five cases against zlib 1.3 level 6
with a non-binary persistent-over-rebuild geometric ratio of 2.133.

A current-parent/current-candidate screen runs fastest, fast, default, best,
fixed, dynamic, split and adaptive modes on three 64 KiB real inputs for three
alternating cycles. All 72 paired outputs retain their compressed sizes; raw
clocks are noisy and no throughput change is claimed. Zstd's large-block
optimal-four parser also reuses the shared table as a proxy. Four alternating
cycles on three 128 KiB Silesia inputs retain identical Zstd wire sizes and
SHA-256 hashes, so no unrelated Zstd wire change was observed in that screen.
The raw paired outputs, commands and binary identities are retained in the
[evidence directory](data/deflate-fixed-cost-20261029/).

These results establish an exact planning invariant and compatibility, not a
general compression-ratio or industry-performance lead. The next DEFLATE work
should use this corrected foundation for iterative dynamic-cost parsing and
standard-corpus split optimization.
