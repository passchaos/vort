# Zstd sequence loop: one literal bound instead of two

## Hypothesis

The retired-instruction profile of the dense Zstd sequence loop attributes
about 4.7% of the loop's instructions to the two literal-range conditions in
the wildcopy predicate:

```zig
literal_offset <= section.regenerated_size and
section.regenerated_size - literal_offset >= literal_len
```

The same predicate already requires `literal_len <= 16`, so both conditions
together are exactly `literal_offset + literal_len <= regenerated_size`.

## Experiment

The dense loop now computes `literal_end = literal_offset + literal_len` once
and compares it against `section.regenerated_size`. The sum cannot overflow
because both operands are bounded by the literal section size. The other
wildcopy conditions are unchanged.

## Result

A four-sweep 48-row screen compares the committed decoder (`decode-offadd`)
with the candidate (`decode-litend`). Lower is faster.

| Scope | Level 3 | Level 19 |
| --- | ---: | ---: |
| 64 KiB | 0.9959 | 0.9960 |
| 1 MiB | 0.9944 | 0.9957 |

Every group improves slightly; per-row medians are `0.9955`–`0.9981` and the
worst row is `1.0044` (`reymont.1m.l3`). The Zstd suite passes 1251/1251 and
`zig build -j2 check` exits zero.

## Conclusion

One condition and one subtract disappear from every sequence. The gain is
small but uniform, and it removes a branch from the predicate chain that the
next Zstd work (collapsing the remaining history and output-room checks) will
build on.

Raw comparison files, records and binaries stay local under
`/tmp/vort-decode-priority-20261031/` (`litend-comparison.json`,
`litend-raw.json`, `decode-litend`, `decode-offadd`).
