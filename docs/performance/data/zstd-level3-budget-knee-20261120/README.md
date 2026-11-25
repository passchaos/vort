# Zstd level-3 match-search budget knee, 2026-11-20

## Decision

Level 3 moves from a 32-candidate to a **24-candidate** controlled greedy
budget. The twelve-prefix sweep measures **1.0572x** geometric-mean speed for
**+0.51%** size versus 32. The next step to 16 buys 1.1565x for +1.66%, which
is a worse size-per-speed trade than the accepted 64 -> 32 step
(1.1509x for +1.01%), so the knee stays at 24.

Level 3 still stays below libzstd 1.6.0 on size: the budget-24 total is
575,418 bytes versus the 597,138-byte libzstd ladder total (0.9636x), and the
size ladder remains monotone (level 2 total 650,603 > level 3 575,418).

## Measurement

- Host Intel i7-10700K, Linux 6.8, Zig 0.16.0 ReleaseFast, `skylake+pku+sgx`,
  single thread.
- `run-zstd-encode-bench`, level 3, one-shot, twelve 128 KiB Silesia prefixes,
  `--iterations 50 --rounds 3`, interleaved with libzstd 1.6.0.
- Each budget row used the explicit
  `--native-selection fast_compressed --strategy greedy --match-search-budget N`
  controls. The level policy path reproduces the 32-byte row exactly; the
  policy now selects 24.

| case | b32 MiB/s | b24 MiB/s | speed | size (b32 -> b24) | b16 speed | b16 size |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| dickens | 18.38 | 19.84 | 1.080 | 52,716 -> 53,193 (+0.90%) | 1.223 | +2.77% |
| mozilla | 50.42 | 51.74 | 1.026 | 20,143 -> 20,168 (+0.12%) | 1.097 | +0.44% |
| mr | 25.93 | 28.79 | 1.110 | 33,017 -> 33,168 (+0.46%) | 1.266 | +1.91% |
| nci | 54.58 | 57.35 | 1.051 | 11,323 -> 11,488 (+1.46%) | 1.136 | +4.92% |
| ooffice | 21.82 | 22.71 | 1.041 | 68,670 -> 68,792 (+0.18%) | 1.134 | +0.54% |
| osdb | 27.94 | 28.80 | 1.031 | 51,340 -> 51,344 (+0.01%) | 1.102 | +0.57% |
| reymont | 23.71 | 26.08 | 1.100 | 40,136 -> 40,534 (+0.99%) | 1.249 | +2.46% |
| samba | 28.46 | 29.99 | 1.054 | 48,893 -> 48,991 (+0.20%) | 1.153 | +0.69% |
| sao | 18.01 | 18.77 | 1.042 | 99,562 -> 99,611 (+0.05%) | 1.117 | +0.21% |
| webster | 24.63 | 26.62 | 1.081 | 43,573 -> 43,865 (+0.67%) | 1.214 | +2.07% |
| xml | 67.32 | 70.58 | 1.048 | 10,958 -> 11,075 (+1.07%) | 1.106 | +3.26% |
| x-ray | 17.51 | 17.98 | 1.026 | 93,138 -> 93,189 (+0.05%) | 1.100 | +0.17% |

Geometric-mean 32 -> 24: **1.0572x** speed, **+0.51%** size. 32 -> 16:
1.1565x, +1.66%. Totals: 573,469 / 575,418 / 579,809 bytes.

## Screens recorded in this package

- `screen-hash16.csv`: the controlled-search index at 16 hash bits instead of
  15. Output is byte-identical on all twelve prefixes (same 573,469-byte
  total), so hash collisions are not displacing real candidates inside the
  budget; the larger table only adds clear/cache cost and measures **0.9747x**.
  Reverted.
- `screen-exit64.csv`: greedy search stops once a 64-byte match is found.
  Measures **1.0089x** for +0.17% size, below the 3% bar and mixed (dickens
  0.991x, sao 0.996x, webster 0.997x; xml 1.064x/+1.21%, nci 1.030x/+0.76%).
  Reverted.

`policy32-baseline.csv` is the level-policy path at 32 and is byte-identical
to `budget32.csv`. After the policy change, the level-3 policy path was
re-measured at one iteration per prefix and is byte-identical to
`budget24.csv` (same 575,418-byte total).

## Re-frozen guards

- Wide-block level-3 regression ceiling: 7,385 -> **7,515** bytes (the level-1
  row stays 11,524 and confirms the payload is unchanged).
- Level-3 controls wire golden: **1,931** bytes (was 1,927).
- Encode gate exact sizes: level3_tradeoff **2,102** (was 2,111) and
  multiblock level 3 **26,786** (was 26,806); level 1/9/22 rows unchanged.

## Raw data

`budget32.csv`, `budget24.csv`, `budget16.csv`, `policy32-baseline.csv`,
`screen-hash16.csv`, `screen-exit64.csv` (schema of
`run-zstd-encode-bench`).
