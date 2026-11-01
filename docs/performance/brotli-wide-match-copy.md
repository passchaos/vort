# Brotli wide match-copy policy in the tail-lookup payload

## Hypothesis

A call-graph profile of `dickens.full.brotli.11` on the committed decoder
attributes 25.81% of samples to one 16-byte match-copy load and another 3.02%
to its store inside `processTailLookupCompressedPayload`. That payload used
`match_copy.append`, whose compact policy falls back to a runtime `@memcpy`
for copies longer than 32 bytes. `match_copy.appendWideNonZero` instead keeps
the measured 32/48/64-byte tiers in ordered fixed 16-byte moves and only falls
back to `@memcpy` above 64 bytes.

## Experiment

Five tail-lookup payload copy sites now call `match_copy.appendWideNonZero`
instead of `match_copy.append`. Because that entry point assumes a non-zero
length, the existing bounds check also rejects `copy_len == 0`:

```zig
if (lengths.copy_len == 0 or lengths.copy_len > meta_block_end - output_cursor)
    return error.CorruptFrame;
```

Valid streams return earlier when the literal-only final command reaches the
meta-block end, so the new condition only rejects malformed zero-length
matches instead of letting the wide copy speculate over 16 bytes. Non-x86-64
targets keep the compact policy through the existing architecture check.

An unguarded variant was about 0.3–0.7% faster, but it would let a malformed
zero-length match take the speculative 16-byte first move in ReleaseFast. The
guarded form is adopted.

## Result

Two four-sweep screens over the 48 Brotli 64 KiB/1 MiB rows compare the
committed binary (`decode-seqgroup`, SHA-256
`472271e39928954092b288e4e70509d2f7f4bf93ae11a34e59aace4408db0150`) with the
adopted candidate (`decode-brwide5`, SHA-256
`b4f2489f2352b15635eaa7cf0d3994b2caf55f3cf08a1522164146968c639ff6`).

| Run | q6 64 KiB | q6 1 MiB | q11 64 KiB | q11 1 MiB |
| --- | ---: | ---: | ---: | ---: |
| 1 | 0.9944 | 0.9870 | 0.9958 | 0.9941 |
| 2 | 0.9898 | 0.9889 | 0.9965 | 0.9921 |

Lower is faster. A 24-row two-sweep full-file screen gives `0.9911` for q6 and
`0.9994` for q11. The complete ReleaseFast Brotli suite passes 1504/1505 with
one platform skip.

## Conclusion

The wide copy policy is adopted for the tail-lookup payload. It removes the
runtime memcpy fallback for 33–64-byte matches and keeps the fixed move tiers
that the full literal-tree executor already uses.

Raw comparison, records and binaries stay local under
`/tmp/vort-br-lookup-20261101/` (`oneshot-brwide5-comparison.json`,
`oneshot-brwide5-1.json`, `oneshot-brwide5-full-comparison.json`,
`decode-brwide5`, `decode-seqgroup`).
