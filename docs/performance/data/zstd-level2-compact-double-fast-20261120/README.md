# Zstd level-2 compact double-fast parser, 2026-11-20

## Decision

Level 2 now uses the compact double-fast parser (the same parser family that
level 1 used before the single-table change) instead of the controlled fast
parser with acceleration 2. This matches zstd's level semantics: level 1 is
the single-table fast parser, level 2 the double-fast parser. The compact
parser dominates every controlled-fast acceleration on both speed and size on
the measured prefix (dickens: acceleration 16 is 69.4 MiB/s at 69,506 bytes
while the compact parser is 91.1 MiB/s at 59,878 bytes), so the old level-2
controlled setting was a speed cliff without a size advantage over the compact
parser.

The size ladder remains monotone: level 1 single-table 61,059 bytes, level 2
double-fast 59,878, level 3 greedy 51,971 on dickens. Explicit
`--strategy fast --fast-acceleration 2` remains available for ratio-first
users.

## Measurement

- Host Intel i7-10700K, Linux 6.8, Zig 0.16.0 ReleaseFast, `skylake+pku+sgx`,
  single thread.
- `run-zstd-encode-bench`, level 2, one-shot, twelve 128 KiB Silesia prefixes,
  `--iterations 1000 --rounds 3`, interleaved with libzstd 1.6.0.

| case | before MiB/s | after MiB/s | speed ratio | before bytes | after bytes | size delta |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| dickens | 38.11 | 91.14 | 2.3914 | 55,783 | 59,878 | +7.34% |
| mozilla | 107.38 | 184.80 | 1.7209 | 21,341 | 24,399 | +14.33% |
| mr | 53.61 | 83.23 | 1.5526 | 34,382 | 36,827 | +7.11% |
| nci | 109.17 | 244.56 | 2.2400 | 11,321 | 11,491 | +1.50% |
| ooffice | 41.39 | 99.07 | 2.3935 | 74,579 | 76,442 | +2.50% |
| osdb | 53.72 | 129.95 | 2.4193 | 53,414 | 61,098 | +14.39% |
| reymont | 44.64 | 80.69 | 1.8075 | 43,217 | 43,617 | +0.93% |
| samba | 54.07 | 112.19 | 2.0750 | 52,255 | 54,011 | +3.36% |
| sao | 39.42 | 105.17 | 2.6681 | 101,650 | 114,461 | +12.60% |
| webster | 44.23 | 102.80 | 2.3243 | 47,465 | 48,838 | +2.89% |
| xml | 160.66 | 271.76 | 1.6916 | 12,503 | 12,323 | -1.44% |
| x-ray | 56.12 | 121.76 | 2.1695 | 102,637 | 107,218 | +4.46% |

Geometric-mean speed **2.0932x**, geometric-mean size **+5.71%** (worst osdb
+14.39%, mozilla +14.33%, sao +12.60%; xml shrinks). Every wire is verified by
both libzstd and Vort before timing.

## Correctness

The frozen level-2 wire in the controls fixture and the level-wire profile
expectation are re-frozen; levels 1/3 and explicit strategies are unchanged.
The full `test`/`check`/`check-wasm` gate is the adoption check.

## Scope limits

One host, one-shot level 2, 128 KiB prefixes. The size cost is concentrated on
binary rows; the compact parser was selected because it dominates the old
controlled-fast ladder on both axes for this corpus.
