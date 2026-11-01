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

## Prototype result

A two-level command table with a 9-bit root and direct second-level tables for
10–15-bit codes was implemented in the entry slack. The measured command trees
need only 126–188 secondary u16 slots, well inside the 891–1074 slots available
between the canonical entries and the 9-bit tail, so it adds no table bytes.

Two four-sweep screens compare the committed `decode-defgen16b` with the
candidate `decode-br2level`:

| Run | q6 64 KiB | q6 1 MiB | q11 64 KiB | q11 1 MiB |
| --- | ---: | ---: | ---: | ---: |
| 1 | 0.9966 | 1.0041 | 1.0050 | 1.0038 |
| 2 | 0.9998 | 1.0042 | 1.0060 | 1.0010 |

Quality 6 at 64 KiB is neutral or slightly faster, but the 1 MiB and quality-11
rows regress 0.1–0.6%. The marker branch on every command decode and the
runtime-width second-level peek cost more than the removed linear scan on the
measured corpus. The complete ReleaseFast Brotli suite passes 1504/1505.

## Conclusion

The two-level prototype was reverted. The memory budget is viable, but Vort's
existing 9-bit flat tail plus scan is already competitive for these trees; a
future attempt would need a cheaper marker encoding or a branch-free
second-level path to win.
