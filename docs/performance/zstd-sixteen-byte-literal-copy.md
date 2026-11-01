# Zstd sixteen-byte literal copy

## Reference

libzstd's `ZSTD_execSequence` copies the first 16 literal bytes with an
unconditional `ZSTD_copy16`, then calls `ZSTD_wildcopy` only when
`litLength > 16`. It does not route exactly-16-byte runs through the bulk loop.
`WILDCOPY_OVERLENGTH` is 32, so the extra bytes are safe temporary output.

## Experiment

Vort's `appendUpTo15Wildcopy16` becomes `appendUpTo16Wildcopy16` and accepts a
16-byte run. The four dense/wide literal wildcopy conditions now use
`literal_len <= 16` instead of `<= 15`, so a 16-byte run takes the single move
instead of `appendBulkWildcopy16`'s whole-chunk loop. The copy test loops over
0..17 to cover the new length.

## Result

Two four-sweep screens over the 48 Zstd 64 KiB/1 MiB rows compare the
committed `decode-defgen16b` (SHA-256
`6c4aba004d128aa2c4db38fe80ff7fe2266e8f82d49b8f82305df686effd978d`) with the
candidate `decode-zstdlit16` (SHA-256
`1681825b5a76666f108afa6f722968b9d0c903c00278f47b73af416016523968`).

| Run | L3 64 KiB | L3 1 MiB | L19 64 KiB | L19 1 MiB |
| --- | ---: | ---: | ---: | ---: |
| 1 | 0.9960 | 0.9830 | 0.9950 | 0.9901 |
| 2 | 0.9990 | 0.9832 | 0.9972 | 0.9927 |

Lower is faster. A 24-row two-sweep full-file screen gives `0.9843` for level 3
and `0.9661` for level 19. The complete Zstd suite passes 1251/1251 tests.

## Conclusion

The 16-byte literal copy is adopted. It matches libzstd's unconditional
first-16-byte literal move and removes the bulk loop for exactly-16-byte
literal runs.

Raw comparison, records and binaries stay local under
`/tmp/vort-br-lookup-20261101/` (`oneshot-zstdlit16-comparison.json`,
`oneshot-zstdlit16-1.json`, `oneshot-zstdlit16-full-comparison.json`,
`decode-zstdlit16`, `decode-defgen16b`).
