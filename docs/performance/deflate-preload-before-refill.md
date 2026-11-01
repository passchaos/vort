# Deflate semantic loop: preload the next entry before the refill

## Hypothesis

The scoped retired-instruction profile of the generic semantic loop is
latency-bound: refill code is 17.6% of instructions (the `byte_index` update
alone 9.75%), the literal chain 24.1%, the match path 22%, and the copy store
7.6%. The loop shifted the reservoir, refilled, and only then preloaded the
next literal entry, so the table load waited for the refill's eight-byte load
and shift to complete.

The refill only ORs new bytes into bits above the valid reservoir, so the low
lookup bits are unchanged by it. The next entry can therefore be preloaded
*before* the refill whenever at least the eleven lookup bits remain staged,
which lets the table load issue in parallel with the refill.

## Experiment

```zig
bit_buffer >>= @intCast(total_bits);
bit_count -= total_bits;
if (bit_count >= Decoder.literal_lookup_bits) {
    entry = decoder.literal[@intCast(bit_buffer & Decoder.literal_lookup_mask)];
    refillSemanticBits(input, &byte_index, &bit_buffer, &bit_count);
} else {
    refillSemanticBits(input, &byte_index, &bit_buffer, &bit_count);
    entry = decoder.literal[@intCast(bit_buffer & Decoder.literal_lookup_mask)];
}
```

The guard falls back to refill-first only for tokens that consume more than
`56 - 11 = 45` bits (wide distances), which are rare. The same pattern is
applied to the secondary-literal continuation, the RLE-1 and RLE-258
specializations, and the literal chain already preloaded `entry4` before its
refill.

## Result

Four-sweep 48-row screens, lower is faster.

Match path only, against the committed decoder:

| Run | L6 64 KiB | L6 1 MiB | L9 64 KiB | L9 1 MiB |
| --- | ---: | ---: | ---: | ---: |
| 1 | 0.9632 | 0.9745 | 0.9613 | 0.9776 |
| 2 | 0.9615 | 0.9760 | 0.9621 | 0.9780 |

47 of 48 rows improve; the best is `nci.64k.l6` at `0.9046` (long matches let
the preload overlap a larger refill) and the worst is `mozilla.1m.l6` at
`1.0083`.

All remaining refill sites on top of the match path:

| Run | L6 64 KiB | L6 1 MiB | L9 64 KiB | L9 1 MiB |
| --- | ---: | ---: | ---: | ---: |
| 1 | 0.9917 | 0.9842 | 0.9951 | 0.9821 |
| 2 | 0.9930 | 0.9823 | 0.9948 | 0.9830 |

The secondary-literal site trades about 3–4% on `xml.64k` for about 1.5% at
1 MiB and a positive group mean. The standalone Deflate suite passes 581/581
and `zig build -j2 check` exits zero.

## Conclusion

This is the largest single Deflate win since the live-range work: combined,
about 4–5% on the 48-row screen. It confirms that the loop is dependency-bound
and that shortening the refill-to-preload chain matters more than removing
independent instructions.

Raw comparison files, records and binaries stay local under
`/tmp/vort-decode-priority-20261031/` (`preload-comparison.json`,
`preload2-comparison.json`, `preloadall-comparison.json`,
`preloadall2-comparison.json`, `decode-preload`, `decode-preloadall`).
