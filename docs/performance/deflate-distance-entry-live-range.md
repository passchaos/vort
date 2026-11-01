# Deflate semantic loop: one distance-entry value instead of three

## Hypothesis

The two previous live-range reductions in this loop measured about 3% and 1%
on the 48-row screen: removing one value that stayed live across the token
removes both its register and the spill traffic it causes. The distance decode
still carried three unpacked values from the distance entry through the match
copy and the next-entry preload: `distance_base`, `distance_extra_bits` and
`distance_code_bits`.

The primary distance table entry already encodes all three: base in bits 16+,
extra-bit count in bits 8..13, and codeword width in the low byte. Only the
secondary-table path (codes longer than the primary lookup) needed the compact
`distance_table` metadata and the secondary entry's own width.

## Experiment

`distance_entry` becomes a mutable `u32` that is the primary entry on the
common path, and a repacked `(base << 16) | (extra_bits << 8) | code_bits`
value on the secondary path:

```zig
var distance_entry: u32 = decoder.distance[bits & distance_lookup_mask];
if ((distance_entry & literal_flag) == 0) {
    if ((distance_entry & secondary_flag) == 0) return error.InvalidHuffmanCode;
    ...secondary lookup...
    distance_entry = (metadata.base << 16) | (metadata.extra_bits << 8) | code_bits;
}
const distance_code_bits: u6 = @truncate(distance_entry);
...
const distance_extra_bits: u6 = @truncate(distance_entry >> 8);
const distance = @as(usize, @intCast(distance_entry >> 16)) + (bits & distance_mask);
```

`distance_base` no longer exists as a live value, and the two remaining fields
are re-derived from the entry where they are used.

## Result

A four-sweep 48-row screen compares the committed decoder (`decode-lenentry`)
with the candidate (`decode-distentry`). Lower is faster.

| Scope | Level 6 | Level 9 |
| --- | ---: | ---: |
| 64 KiB | 0.9580 | 0.9578 |
| 1 MiB | 0.9570 | 0.9544 |

All 48 rows improve: medians `0.9516`–`0.9552`, best `0.9372`
(`mozilla.64k.l9`), worst `0.9846` (`nci.64k.l6`). The standalone Deflate
suite passes 581/581 and `zig build -j2 check` exits zero.

## Conclusion

This is the largest single live-range win so far (about 4.5%). Together with
the derived bit position and the length-entry change, the semantic loop now
carries three fewer long-lived values than at the start of the session, worth
about 8% on the 48-row screen.

Raw comparison files, records and binaries stay local under
`/tmp/vort-decode-priority-20261031/` (`distentry-comparison.json`,
`distentry-raw.json`, `decode-distentry`, `decode-lenentry`).
