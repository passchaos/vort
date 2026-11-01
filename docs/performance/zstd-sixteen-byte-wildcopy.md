# Zstd sixteen-byte wildcopy

## Reference

libzstd defines `WILDCOPY_VECLEN` as 16 and `WILDCOPY_OVERLENGTH` as 32.
`ZSTD_wildcopy` therefore copies matches in 16-byte moves with at most 32 bytes
of overrun, for every match whose offset is at least 16. It does not select a
32- or 64-byte tier based on distance or match length.

## Experiment

Vort's `appendForwardWildcopy` previously selected 64-byte chunks when the
distance was at least 64 and the destination was fully bounded, then 32-byte
chunks at distance 32, then 16-byte chunks. The function now always uses the
16-byte tier and returns `false` to report that no wider tier was selected.
The adaptive wildcopy test was renamed and updated to assert the bounded
16-byte behavior.

## Result

Two four-sweep screens over the 48 Zstd 64 KiB/1 MiB rows compare the
committed `decode-defgen16b` (SHA-256
`6c4aba004d128aa2c4db38fe80ff7fe2266e8f82d49b8f82305df686effd978d`) with the
candidate `decode-zstdw16b` (SHA-256
`7ed544527a40b50f8f66714293da69dd4b315f41fb68361a3a4e21fa6ecbe45a`).

| Run | L3 64 KiB | L3 1 MiB | L19 64 KiB | L19 1 MiB |
| --- | ---: | ---: | ---: | ---: |
| 1 | 0.9974 | 0.9871 | 0.9986 | 0.9931 |
| 2 | 0.9964 | 0.9870 | 1.0075 | 0.9958 |
| confirm | 0.9965 | 0.9846 | 0.9952 | 0.9929 |

Lower is faster. A 24-row two-sweep full-file screen gives `0.9954` for level 3
and `0.9927` for level 19. The complete Zstd suite passes 1251/1251 tests.

## Conclusion

The 16-byte wildcopy is adopted. It matches libzstd's copy width and removes
the wider AVX2 tiers that measured slower on the decode corpus.

Raw comparison, records and binaries stay local under
`/tmp/vort-br-lookup-20261101/` (`oneshot-zstdw16-comparison.json`,
`oneshot-zstdw16-1.json`, `oneshot-zstdw16b-comparison.json`,
`oneshot-zstdw16-full-comparison.json`, `decode-zstdw16b`, `decode-defgen16b`).
