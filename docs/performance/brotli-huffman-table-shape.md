# Brotli Huffman table shape: libbrotli vs Vort

## Reference

libbrotli's decoder uses `HUFFMAN_TABLE_BITS = 8` and a `HuffmanCode` entry of
`{ bits, value }` (four bytes). `DecodeSymbol` peeks 16 bits, loads the 8-bit
root, and for a long code uses the root value as a direct offset into a
second-level table. `BrotliDecoderHuffmanTreeGroupInit` sizes each tree as
`alphabet_size_limit + 376` entries; for the 704-symbol command alphabet that
is about 4.3 KiB of table per tree. There is no linear code scan on a miss.

Vort's command auxiliary path uses a 9-bit flat tail lookup (1 KiB) and falls
back to `decodeValueLongAfterLookup`, which scans the canonical entries grouped
by bit width. The one-shot 64 KiB profile put 5.8% of `samba.64k.q6` in that
fallback.

## Command tree shape

A temporary diagnostic printed the active length and per-width code counts of
each 64 KiB command tree:

| Source | Quality | len | 9-bit | 10-bit | 11-bit | 12+ bit |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| samba | 6 | 236 | 14 | 17 | 27 | 138 |
| samba | 11 | 228 | 18 | 24 | 11 | 133 |
| dickens | 6 | 175 | 18 | 10 | 9 | 107 |
| dickens | 11 | 179 | 15 | 14 | 9 | 100 |

Most long codes are 12 bits or wider, so a 10-bit flat root only covers a
small part of the fallback. That matches the measured 10-bit-root result:
quality 6 gained 0.2–0.8%, while quality 11 regressed 0.7–1.3% from the 2 KiB
table's cache cost.

## Next structural candidate

A two-level command table with a 9-bit root and direct second-level tables for
11–15-bit codes would remove the linear scan the way libbrotli does, without
widening every root slot. The secondary table can live in the unused slack
between the canonical entries and the 9-bit tail when it fits; otherwise it
needs an explicit per-tree array. The size budget is the open question:
`alphabet_size_limit + 376` is libbrotli's empirical bound for its 4-byte
entries, while Vort's u16 packed entries have different packing.

This candidate should be evaluated separately for quality 6 and quality 11,
and must keep the malformed-code and truncation contracts. It is not a
drop-in 10-bit root.
