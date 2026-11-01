# Brotli ten-bit command tail lookup wiring

## Context

`prepareCommand10AuxiliaryTailLookups`, `readCommandSymbolTailLookupFixed10`
and `readInsertCopyLengthsTailLookup10` already existed but were only reached
by tests. The production large-meta-block path used
`prepareAuxiliaryTailLookups` with a nine-bit command tail, and the one-shot
64 KiB profile attributed 5.8% to `HuffmanTable(704).decodeValueLongAfterLookup`
on `samba.64k.q6`.

## Experiment

`processExternalLiteralLookupCompressedPayload` gained a comptime
`command_tail_10` mode. The caller tries `prepareCommand10AuxiliaryTailLookups`
first; on success it reads command and insert/copy lengths through the fused
ten-bit tail, otherwise it falls back to the unchanged nine-bit preparation.
Distance trees stay on the nine-bit tail.

## Result

Two four-sweep screens over the 48 Brotli 64 KiB/1 MiB rows compare the
committed binary (`decode-seqgroup`, SHA-256
`472271e39928954092b288e4e70509d2f7f4bf93ae11a34e59aace4408db0150`) with the
candidate (`decode-cmd10tail`, SHA-256
`688926f30411acfdfadb876587ae5c3768956da1dfcfde8980056c653fa5e9eb`).

| Run | q6 64 KiB | q6 1 MiB | q11 64 KiB | q11 1 MiB |
| --- | ---: | ---: | ---: | ---: |
| 1 | 0.9925 | 0.9972 | 1.0069 | 1.0135 |
| 2 | 0.9955 | 0.9984 | 1.0117 | 1.0105 |

Lower is faster. Quality 6 improves about 0.2–0.8%, but quality 11 regresses
about 0.7–1.3%. The wider 2 KiB command table and fused lookup path help the
smaller quality-6 trees but cost more than the avoided long-code fallback on
quality-11 blocks.

## Conclusion

The wiring was reverted. The ten-bit command machinery stays test-only; the
nine-bit command tail remains the production path. A future attempt would need
a per-block decision that only widens trees where the measured long-code miss
rate justifies the larger table.

Raw comparison, records and binaries stay local under
`/tmp/vort-br-lookup-20261101/` (`oneshot-cmd10tail-comparison.json`,
`oneshot-cmd10tail-1.json`, `decode-cmd10tail`, `decode-seqgroup`).
