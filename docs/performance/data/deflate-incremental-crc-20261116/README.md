# Deflate incremental CRC-32 short-update slices, 2026-11-16

## Why

The audit still lacked a current zlib-ng streaming matrix. With zlib-ng 2.3.90
built locally as a zlib-compatible static library, the reusable incremental
gzip decode bench shows Vort at 0.29-0.91x of zlib-ng depending on payload and
chunking; the 7-byte input / 31-byte output fragmented rows are the worst.

A profile of the bench attributes 8.5% of cycles to `crc32Slice32Update`. The
32-byte slice loop only covers 32-byte groups; a 31-byte streaming chunk falls
through to the serial byte loop, where every byte depends on the previous CRC.
The same short-update path is used by the gzip/zlib/zip encoders and decoders.

## Change

`src/checksum.zig`, `crc32Slice32Update`: add 8-byte and 4-byte slice loops
between the existing 32-byte loop and the byte tail. The same
`Crc32Slice32.tables` layout is reused, so the update is byte-identical; the
shorter dependency chain and lower loop overhead target the short streaming
updates. Portable code, no target-specific assembly.

## A/B (system zlib 1.2.11 bench, median of three alternating runs)

`base` is the committed `crc32Slice32Update`; `candidate` adds the slices.
`vort-semantic` ns/decode, lower is faster:

| case | chunking | base ns | candidate ns | speedup |
| --- | --- | ---: | ---: | ---: |
| http-4k | full | 5331 | 5391 | 0.989 |
| http-4k | fragmented-7x31 | 21740 | 17358 | **1.252** |
| json-32k | full | 14646 | 14594 | 1.004 |
| json-32k | fragmented-7x31 | 134891 | 102120 | **1.321** |
| text-64k | full | 121499 | 121065 | 1.004 |
| text-64k | fragmented-7x31 | 1081685 | 1080199 | 1.001 |
| binary-64k | full | 4023 | 4151 | 0.969 |
| binary-64k | fragmented-7x31 | 718962 | 705836 | 1.019 |

Raw CSVs: `base-{1,2,3}.csv`, `cand-{1,2,3}.csv`, summary `crc-slice-ab.csv`.
The full-case rows use the PCLMUL path for their bulk and are unchanged; the
binary-full 0.969 row is within the host's run-to-run variance and was not
reproduced as a code-path change.

## zlib-ng reference snapshot

`zlib-ng-matrix.csv` records the same bench linked against the local zlib-ng
2.3.90 compat build, before and after the CRC change. The fragmented rows
improve from 3.25x/3.05x behind zlib-ng to 2.60x/2.26x (http-4k/json-32k);
text-64k fragmented stays about 2.2x behind, and the full rows remain
1.2-3.5x behind depending on payload. The before/after zlib-ng runs were not
interleaved, so use the alternating system-zlib A/B above for the increment
claim and the matrix for the reference distance.

## Validation

- `zig test src/checksum.zig`: 19/19, including the differential CRC oracle.
- Focused `test-deflate-wide-decode`, `test-deflate-wide-encode`,
  `test-deflate-incremental-relaxed`, `test-deflate-clone` and
  `test-zip-codecs`: pass.
- `zig build check-wasm`: recorded with the increment.

## Scope limits

Single host, built-in bench payloads, no CPU pinning. The short-update CRC win
is on fragmented streaming rows; the remaining streaming gap is dominated by
the per-chunk step state machine (`stepInternal`, `stepRaw`, `rawAdmission`),
not the checksum.
