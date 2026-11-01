# Deflate semantic loop: derive the bit position instead of tracking it

## Hypothesis

`perf stat` on `dickens.64k.rawdeflate.9` shows the same IPC for `vort` and
libdeflate (2.57 vs 2.52) but 77% more retired instructions
(5.208B vs 2.937B for 4000 decodes). The loop is instruction-bound, not
latency-bound, so the remaining gap is per-token work.

The generic semantic loop carried a `consumed_bits` counter and executed
`consumed_bits += ...` on every token, because only the non-overlap
instantiation used the existing reservoir-derived position. That extra
accumulator is also one more live value in an already register-starved loop
(the retired-instruction profile shows 6.5% of instructions on one stack slot
alone).

`BufferedBitReader` stages whole bytes and keeps every unread bit in the low
end of the reservoir, so `byte_index * 8 - bit_count` is exactly the logical
consumed position whenever the invariant holds. The non-overlap loop already
relied on this invariant.

## Experiment

The main semantic loop now derives the position through
`semanticConsumedBits(byte_index, bit_count)` at every exit and drops the
`consumed_bits` variable and all nine per-token updates. The helper no longer
takes a comptime mode flag.

This is safe for this loop because it is entered at the same block-aligned
reader state as the non-overlap instantiation, and `refillSemanticBits` only
stages whole bytes into the low end of the reservoir. The standalone Deflate
suite, including truncated and resynchronized streams, passes 581/581.

## Result

A four-sweep 48-row screen compares the committed decoder
(`decode-matchbits2`) with the candidate (`decode-derive`). Lower is faster.

| Scope | Level 6 | Level 9 |
| --- | ---: | ---: |
| 64 KiB | 0.9713 | 0.9681 |
| 1 MiB | 0.9744 | 0.9741 |

Per-row medians range from `0.9466` (`sao.64k.l9`) to `1.0174`
(`webster.64k.l9`); 46 of 48 rows improve and the median gains are 3.4–3.6%.
`zig build -j2 check` exits zero.

## Conclusion

The loop no longer pays an accumulator dependency and one live register per
token. The other semantic loops (sink mode and the compact RLE-258 loop) still
track the counter and can take the same derivation separately.

Raw comparison files, records and binaries stay local under
`/tmp/vort-decode-priority-20261031/` (`derive-comparison.json`,
`derive-raw.json`, `decode-derive`, `decode-matchbits2`).
