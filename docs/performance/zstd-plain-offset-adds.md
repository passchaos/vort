# Zstd sequence loop: plain offset adds on 64-bit targets

## Hypothesis

`perf stat` on `dickens.1m.zstd.3` shows the same IPC for `vort` and libzstd
(3.51 vs 3.57) but 49% more retired instructions (13.54B vs 9.08B for 600
decodes). Aggregating retired instructions by inlined source line put three
`std.math.add` overflow checks from `resolveSequenceOffset` at about 2.3–2.7%
each, plus a stack slot for the stored carry flag.

The offset base is packed into the FSE symbol's low 32 bits
(`sequenceSymbolBase` truncates to `u32`), and `readSequenceField` rejects
fields wider than 32 bits. On a 64-bit target the sum of two u32-bounded
values cannot overflow `usize`, so the checked add is provably redundant.

## Experiment

A small helper keeps the checked form only where it can matter:

```zig
inline fn addOffsetParts(a: usize, b: usize) Error!usize {
    if (comptime @bitSizeOf(usize) >= 64) return a + b;
    return std.math.add(usize, a, b) catch return error.IntegerOverflow;
}
```

`resolveSequenceOffset` uses it for the direct offset (`base + extra`) and for
the `raw_base`/`raw_offset` pair. On 64-bit targets the three checked adds
become plain adds; 32-bit targets keep the previous behavior exactly.

## Result

A four-sweep 48-row screen compares the committed decoder (`decode-distentry`)
with the candidate (`decode-offadd`). Lower is faster.

| Scope | Level 3 | Level 19 |
| --- | ---: | ---: |
| 64 KiB | 0.9722 | 0.9547 |
| 1 MiB | 0.9789 | 0.9698 |

Per-row medians are `0.9439`–`0.9820`; five rows are about 1.6–1.8% slower
(`osdb` and `x-ray`), the rest improve, and the geometric mean is about 0.969.
The Zstd suite passes 1251/1251 and `zig build -j2 check` exits zero.

## Conclusion

The sequence loop was paying for overflow checks whose bounds are proven by the
symbol packing and the field reader. This is the first Zstd decode win since
the sixteen-byte copy changes, and it confirms that the Zstd gap is also
per-sequence instruction work rather than latency.

Raw comparison files, records and binaries stay local under
`/tmp/vort-decode-priority-20261031/` (`offadd-comparison.json`,
`offadd-raw.json`, `decode-offadd`, `decode-distentry`).
