# Deflate level-7 hash4-chain routing, 2026-11-22

## Decision

Level 7 (`zlib`, `gzip` and raw level 7) now enables the lazy parser's
chainless 3-byte slot plus 4-byte hash chain (`GreedyOptions.hash4_chain`),
using the same middle-4 KiB content classifier as the level-6 default. The
parser and classifier are unchanged; only the level-7 option is added.
Brotli, levels 1--6 and levels 8--9 keep their historical parsers.

Levels 4 and 5 were measured with the same option and rejected: both fail the
0.98x control floor and neither reaches the 3% geometric-mean gate.

## Measurement

- Host Intel i7-10700K, Linux 6.8, Zig 0.16.0 ReleaseFast, `skylake+pku+sgx`,
  single thread; zlib 1.2.11 and libdeflate 1.10 references in every row.
- `run-deflate-encode-bench`, 128 KiB prefixes, old/new binaries alternating
  per file in one session. Level 7: `--iterations 100 --rounds 5`.
  Levels 4/5: `--iterations 50 --rounds 3`.
- The level-6 control runs the same routing in both binaries, so its spread is
  the run-to-run noise band: **0.9919x** geometric mean, per row
  0.9665--1.0321x, byte-identical wires on all twelve rows.

## Level 7 results

| case | speed | bytes |
| --- | ---: | ---: |
| dickens | 1.4719 | 50,590 -> 50,554 (-0.07%) |
| mozilla | 0.9804 | 23,031 (unchanged) |
| mr | 1.0207 | 33,415 (unchanged) |
| nci | 0.9677 | 10,917 (unchanged) |
| ooffice | 1.2891 | 68,041 -> 68,102 (+0.09%) |
| osdb | 1.4672 | 51,255 -> 51,252 (-0.01%) |
| reymont | 1.4416 | 36,692 -> 36,593 (-0.27%) |
| samba | 0.9650 | 49,368 (unchanged) |
| sao | 1.0115 | 99,063 (unchanged) |
| webster | 1.2398 | 42,009 -> 41,991 (-0.04%) |
| xml | 0.9549 | 9,979 (unchanged) |
| x-ray | 1.0026 | 94,135 (unchanged) |

Geometric mean **1.1336x** speed. Total bytes 568,495 -> 568,400 (-0.017%);
zlib 1.2.11 is 568,214 and libdeflate 1.10 is 562,828 on the same prefixes.

The classifier routes `dickens`, `ooffice`, `osdb`, `reymont` and `webster`;
those five rows gain 1.24--1.47x with -0.27...+0.09% size. The other seven rows
emit byte-identical wires, and their 0.955--1.021x ratios sit inside the
level-6 control band above, so they are not attributed as regressions.

## Rejected levels

- Level 4: **0.9845x** geometric mean, -0.445% total size. `osdb` 0.8879x,
  `nci` 0.9673x, `xml` 0.9517x and `mozilla` 0.9750x fall below the control
  floor.
- Level 5: **1.0146x** geometric mean, -0.268% total size. `osdb` 0.9211x,
  `nci` 0.9550x and `xml` 0.9633x fall below the control floor, and the
  aggregate misses the 3% gate.

The shallower level-4/5 chains already lose fewer cycles to 3-byte collisions,
so the extra hash4 table and insertion work is not repaid on their routed
blocks.

## Raw data

`level7-128k-before.csv` / `level7-128k-after.csv`,
`level6-control-before.csv` / `level6-control-after.csv`,
`level4-128k-before.csv` / `level4-128k-after.csv` and
`level5-128k-before.csv` / `level5-128k-after.csv` (schema of
`run-deflate-encode-bench`; each CSV carries the executable SHA and command).
