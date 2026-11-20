# Deflate multi-hop chain-word screen, 2026-11-20

## Decision

The level-6 hash-chain finder keeps the plain predecessor table. Two
wire-identical multi-hop layouts were measured on the twelve 128 KiB Silesia
prefixes and rejected.

## Profile

A flat `perf` profile of the 128 KiB dickens level-6 encode against zlib
1.2.11 and libdeflate 1.10 attributes 34.32% self (of the 44.64% Vort share)
to `lz77.findBestHashMatchWithLayout`; the `prev[...]` chain load alone is
39.72% of all sampled cycles.

## Screens

- **Two-hop words** (`u32`, two `u16` deltas): byte-identical 50,996-byte
  dickens output, but 20.57 / 20.75 / 20.36 MiB/s across three alternating
  runs versus 22.12 / 22.29 / 21.93 for the predecessor table, about 0.93x.
- **Four-hop words** (`u64`, four `u16` deltas): **0.901x** geometric-mean
  speed with byte-identical sizes on all twelve rows.

| case | predecessor MiB/s | four-hop MiB/s | speed | bytes |
| --- | ---: | ---: | ---: | ---: |
| dickens | 22.07 | 22.33 | 1.012 | 50,996 |
| mozilla | 87.50 | 66.92 | 0.765 | 23,159 |
| mr | 22.68 | 19.17 | 0.845 | 33,563 |
| nci | 100.52 | 82.78 | 0.824 | 11,174 |
| ooffice | 28.92 | 25.28 | 0.874 | 68,263 |
| osdb | 44.07 | 45.30 | 1.028 | 51,770 |
| reymont | 23.89 | 22.70 | 0.950 | 37,453 |
| samba | 36.42 | 35.70 | 0.980 | 49,546 |
| sao | 25.67 | 21.24 | 0.827 | 99,460 |
| webster | 31.77 | 32.15 | 1.012 | 42,288 |
| xml | 126.08 | 110.55 | 0.877 | 10,233 |
| x-ray | 33.00 | 28.53 | 0.865 | 94,246 |

Geometric mean **0.901x**; only dickens, osdb and webster improve. Every
output size is byte-identical, so the loss is purely kernel cost.

## Why it loses

Building a hop word requires reading the previous head's hop word during
insertion: one extra dependent random load for every input position. At the
measured roughly three-node average chain depth, the search-side loads saved
by visiting two or four candidates per load do not repay that insertion load,
and the four-delta group decode adds arithmetic to every position.

## Measurement

- Host Intel i7-10700K, Linux 6.8, Zig 0.16.0 ReleaseFast, `skylake+pku+sgx`,
  single thread.
- `run-deflate-encode-bench`, level 6, one-shot, twelve 128 KiB Silesia
  prefixes, `--iterations 50 --rounds 3`, zlib 1.2.11 and libdeflate 1.10
  references. The old/new binaries ran sequentially per file in one session.

## Raw data

`predecessor.csv` and `four-hop.csv` (schema of `run-deflate-encode-bench`).
