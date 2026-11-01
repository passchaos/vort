# Deflate semantic loop: litlen width is no longer live across the token

## Hypothesis

The annotated profile of the 64 KiB level-9 semantic loop
(`decodeSemanticDynamicBlockIntoBufferedReader`, 93.68% of decode cycles on
`dickens.64k`) put the two most expensive instructions on a stack reload of the
litlen codeword width: `movzbl -0x29(%rbp),%eax` at 5.75% local, right after the
matching store. The variable `entry_bits` was declared before the literal
speculation chain and used again after the match length and distance were
decoded, so the register allocator spilled it across the whole token.

`libdeflate` avoids this shape: its fast loop consumes the litlen entry
immediately (`bitbuf >>= (u8)entry`) and keeps only `bitbuf`, `bitsleft`,
`in_next`, `out_next` and the table mask live, with the match copy overlapping
the next-entry preload (`lib/decompress_template.h`).

## Experiment

`entry_bits` became a scoped constant inside the literal chain, and a new
`match_bits` value is materialized only after the chain, when the match symbol
is known. The secondary-table path keeps its own width. This shortens the live
range without changing the number of reservoir shifts: the token still retires
with a single `bit_buffer >>= total_bits` where `total_bits` includes
`match_bits`.

A first variant consumed `match_bits` immediately and left `total_bits` with
only the length/distance extras. It removed the spill but added a second
variable shift per match token and regressed match-heavy rows (`nci.64k.l9`
`1.0718`, `xml.64k.l6` `1.0459`). The single-shift form is adopted.

## Result

A four-sweep 48-row screen (12 Deflate files at level 6/9 and 64 KiB/1 MiB,
128/16 iterations) compares the committed decoder (`decode-live`) with the
candidate (`decode-matchbits2`). Lower is faster.

| Scope | Level 6 | Level 9 |
| --- | ---: | ---: |
| 64 KiB | 0.9452 | 0.9358 |
| 1 MiB | 0.9385 | 0.9364 |

The per-row medians range from `0.859` (`reymont.1m.l6`) to `1.031`
(`nci.64k.l9`); 44 of 48 rows improve and the text corpora gain 10–14%.
`dickens.64k.l9` drops from 458.1 ms to 411.3 ms for 4000 decodes in a direct
run. The standalone Deflate suite passes 581/581.

A 1,296-process epoch afterwards gives current/reference Deflate
`1.6890/1.5975/1.6084` (level 6) and `1.6725/1.5825/1.6089` (level 9) at
64 KiB/1 MiB/full, against `1.7359/1.6420/1.6368` and
`1.6962/1.6147/1.6233` before. Zstd is `1.47–1.56x` and Brotli `1.12–1.49x` in
the same epoch.

## Conclusion

The semantic loop now keeps the litlen width inside the token that consumes it.
The remaining Deflate gap is not one instruction but the per-symbol instruction
count of the semantic decoder shape compared with `libdeflate`'s flat
litlen/offset tables.

Raw comparison files, records and binaries stay local under
`/tmp/vort-decode-priority-20261031/` (`matchbits2-comparison.json`,
`matchbits2-raw.json`, `decode-matchbits2`, `decode-live`) and the epoch under
`/tmp/vort-br-lookup-20261101/` (`industry-matchbits2-comparison.json`).
