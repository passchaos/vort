# Deflate hash-chain early node load, 2026-11-19

## Change

`findBestHashMatchWithLayoutAndHashLimits` walked the hash chain by loading
`prev[candidate]` only after the prefix screen and match scan. The next node is
independent of the scan result, so the load now issues before the candidate
comparison and the match scan, letting its latency overlap that work. The
traversal order, `checked` accounting and match selection are unchanged; only
the load position moved. The extra load on the last candidate of a search is
negligible.

## Measurement

- Host Intel i7-10700K, Linux 6.8, Zig 0.16.0 ReleaseFast, `skylake+pku+sgx`,
  single thread.
- `run-deflate-encode-bench`, level 6, raw Deflate, twelve 128 KiB Silesia
  prefixes, `--iterations 3 --rounds 5`, min-of-rounds.
- Reference: zlib 1.2.11 and libdeflate 1.10 (system libraries); the comparison
  only needs the Vort columns.

| case | before MiB/s | after MiB/s | speed ratio | bytes |
| --- | ---: | ---: | ---: | ---: |
| dickens | 16.18 | 17.07 | 1.0550 | 50,649 |
| mozilla | 65.59 | 68.47 | 1.0439 | 23,057 |
| mr | 11.74 | 12.23 | 1.0417 | 33,433 |
| nci | 72.31 | 73.20 | 1.0123 | 11,001 |
| ooffice | 23.13 | 23.64 | 1.0220 | 68,136 |
| osdb | 34.97 | 36.98 | 1.0575 | 51,361 |
| reymont | 14.28 | 16.17 | 1.1324 | 36,834 |
| samba | 28.24 | 29.39 | 1.0407 | 49,453 |
| sao | 19.61 | 20.06 | 1.0229 | 99,220 |
| webster | 25.08 | 25.11 | 1.0012 | 42,045 |
| xml | 99.27 | 101.94 | 1.0269 | 10,035 |
| x-ray | 32.56 | 32.25 | 0.9905 | 94,246 |

Geometric-mean speed ratio **1.0367x**; every output is byte-identical to the
previous source. The weakest row is x-ray at 0.9905x, above the 0.98x control
floor. Spot checks at level 1 (dickens 89.72 -> 90.79 MiB/s, same 54,008
bytes) and level 9 (dickens 1.14 -> 1.14 MiB/s, same 48,229 bytes) show no
level-family regression; zstd level 3 also keeps its frozen 51,971-byte wire.

## Scope limits

One host, one-shot raw Deflate, 128 KiB prefixes, min-of-five interleaved
rounds. The change is shared by the zstd hash parsers, so the full repository
gate (`zig build test check check-wasm`) is the adoption check; golden wires
must stay byte-identical.
