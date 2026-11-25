# Persistent incremental DEFLATE ratio repair, 2026-11-22

## Problem

The `run-deflate-incremental-encode-gate` compared the persistent rolling-hash
encoder with a fresh 32 KiB rebuild on the same 256 KiB inputs and failed on
mainline: `source` emitted 1,899 bytes versus 1,142, and `json-log` 1,764
versus 1,135. The failure reproduces on the parent commit, so it is not caused
by the windowed s16 hash4 change.

A minimal raw-DEFLATE parser over the two `source` wires shows the same
8 dynamic blocks, the same 262,144 decoded bytes and similar token counts
(1,021 versus 1,028 matches), but the persistent parser's average match
distance is **7,385** (maximum 8,000) versus **124.5** (maximum 125) for the
rebuild. The sparse insertion used inside accepted matches skipped the
positions that hold the nearest same-anchor candidate, so the chain returned a
far candidate of equal length and paid the distance-code extra bits.

## Fix

The rolling matcher now keeps the distance of the last emitted match and tests
that candidate before walking the chain. Periodic input reuses the near
distance even though sparse insertion never indexed it. Two details keep the
hint cheap:

- When the hint reaches the maximum match length, `findBest` returns
  immediately. Without this early return the chain still scanned 64 candidates
  at equal length; the uniform-run case executed 2.18B instructions instead of
  102M.
- Sparse tail insertion is retained, so RLE-like runs keep their previous
  speed.

The hint is reset with the encoder. It never changes the emitted token order
beyond preferring the nearer of two equal-length matches, which is a smaller
distance code.

## Results

`bench-deflate-incremental-encode`, 32 iterations, ReleaseFast, 256 KiB inputs:

| case | persistent before | persistent after | rebuild | zlib 1.3 |
| --- | ---: | ---: | ---: | ---: |
| json-log | 1,764 B @ 2,573 MiB/s | **1,122 B @ 2,964 MiB/s** | 1,135 B @ 238 | 1,001 B @ 356 |
| source | 1,899 B @ 2,577 | **1,135 B @ 3,259** | 1,142 B @ 242 | 1,013 B @ 367 |
| repetitive | 271 B @ 4,322 | **271 B @ 4,643** | 377 B @ 2,733 | 272 B @ 386 |
| binary | 262,184 B @ 216 | 262,184 B @ 219 | 262,184 B @ 33 | 262,224 B @ 45 |
| cross-window | 34,565 B @ 532 | 34,565 B @ 532 | 34,565 B @ 41 | 262,224 B @ 45 |

The gate now passes: `nonbinary_geomean_over_rebuild=7.796`, persistent size no
larger than rebuild on every case, and every competitor throughput check
passes.

## Raw data

`before.csv` and `after.csv` are the complete gate matrices (schema of
`bench-deflate-incremental-encode`).
