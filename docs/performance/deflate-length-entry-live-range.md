# Deflate semantic loop: one length-entry value instead of two

## Hypothesis

After the reservoir-derived bit position removed one accumulator, the retired
instruction profile of `dickens.64k.rawdeflate.9` still spends about 11% of its
instructions on stack slots (`-0x48`, `-0x50`, `-0x58`, `-0x78`). The loop is
register-starved, and every freed live value has measured value: the previous
change removed one live value plus one add per token for about 3%.

The match path kept two values alive from the litlen entry through the
length-extra decode: `length_base` and `length_extra_bits`. The primary table
entry already carries both (`base` in bits 16+ and the extra-bit count in
bits 8..13), so the common path only copied them out. The secondary-table path
replaced them with the compact `length_table` metadata.

## Experiment

The two variables are replaced by one `length_entry: u32` that is simply the
primary entry on the common path, and a repacked
`(base << 16) | (extra_bits << 8)` value on the secondary path:

```zig
var match_bits: u6 = @truncate(entry);
var length_entry: u32 = entry;
if ((entry & exceptional_flag) != 0) { ...secondary/end-of-block... }

var bits = bit_buffer >> @intCast(match_bits);
const length_extra_bits: u6 = @truncate(length_entry >> 8);
const length = @as(usize, @intCast(length_entry >> 16)) +
    @as(usize, @intCast(bits & length_mask));
```

`length_base` no longer exists as a value, so one fewer register stays live
across the distance decode. The secondary path pays two shifts and an `or` to
repack its metadata, but that path handles codes longer than the eleven-bit
primary and is rare.

## Result

A four-sweep 48-row screen compares the committed decoder (`decode-derive`)
with the candidate (`decode-lenentry`). Lower is faster.

| Scope | Level 6 | Level 9 |
| --- | ---: | ---: |
| 64 KiB | 0.9906 | 0.9877 |
| 1 MiB | 0.9919 | 0.9891 |

All four groups improve, with per-row medians of `0.9857`–`0.9932` and only
noise-level outliers above 1.0 (worst `1.0066`, `nci.1m.l6`). The standalone
Deflate suite passes 581/581 and `zig build -j2 check` exits zero.

## Conclusion

The match path now carries the litlen entry itself instead of two unpacked
fields. Together with the derived bit position this is about 4% on the 48-row
screen relative to the previous commit.

Raw comparison files, records and binaries stay local under
`/tmp/vort-decode-priority-20261031/` (`lenentry-comparison.json`,
`lenentry-raw.json`, `decode-lenentry`, `decode-derive`).
