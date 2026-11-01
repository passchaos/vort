# Brotli header prepared-lookup zeroing

## Hypothesis

Every ordinary `PrefixCode` header parse previously built the tree through a
struct literal, which initialized `prepared_lookup` with `@splat(0)`: 512 bytes
for eight-bit trees and 1 KiB for nine-bit literal/command trees. The one-shot
64 KiB profile attributed 12.2% to `readStreamMetaBlockHeader`, so removing that
zeroing looked like a cheap setup win.

## Experiment

The standard, profiled and Large Window parsers were changed to write only the
live fields (`single_symbol`, `table`, `prepared`) and leave `prepared_lookup`
undefined until first use, mirroring `PackedPrefixCode.expand`.
`singleSymbolPrefixCode` also returned `u16` directly instead of constructing a
whole `PrefixCode`, so the code-length decoder no longer initialized a 512-byte
lookup just to read one symbol.

## Result

A 384-process two-sweep screen over the 48 Brotli 64 KiB/1 MiB rows compares the
current source (`decode-prep`, SHA-256
`5a20965a89766cd309e17a93364985c730b9b76bcf6004b83be5e546dd1c8dc0`) with the
committed source (`decode-final`, SHA-256
`87ae6891096d2d35fbabb2afdb325a48ec650816a6e20400d29721727594c984`).

| Scope | q6 | q11 |
| --- | ---: | ---: |
| 64 KiB | 1.0004 | 0.9971 |
| 1 MiB | 1.0052 | 1.0077 |

Lower is faster. The 64 KiB target is neutral and 1 MiB regresses by 0.5–0.8%.
The worst rows are `osdb.64k.q6 1.052`, `dickens.1m.q6 1.043` and
`xml.1m.q6 1.032`; the best are `xml.64k.q11 0.973` and `reymont.1m.q6 0.981`.

## Conclusion

The change was reverted. LLVM already removes the unused zeroed lookup when
`prepared` stays false, so the per-meta-block header cost is not the LUT clear.
The 64 KiB setup work must target the parse and dispatch code instead.

Raw comparison, records and binaries stay local under
`/tmp/vort-br-lookup-20261101/` (`oneshot-prep-comparison.json`,
`oneshot-prep-raw.json`, `decode-prep`, `decode-final`).
