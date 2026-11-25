# Zstd level-3 match-search budget 64 -> 32, 2026-11-20

## Decision

Level 3 now uses a 32-candidate controlled greedy budget. The previous
effective depth was 64; the earlier sweep showed 32 trading +0.06-2.0% size
for +2-34% speed on four prefixes. The full twelve-prefix A/B below confirms
the trade, and the user-directed performance priority makes it the new
level-3 point.

## Measurement

- Host Intel i7-10700K, Linux 6.8, Zig 0.16.0 ReleaseFast, `skylake+pku+sgx`,
  single thread.
- `run-zstd-encode-bench`, level 3, one-shot, twelve 128 KiB Silesia prefixes,
  `--iterations 50 --rounds 3`, interleaved with libzstd 1.6.0.
- The policy path (`--level 3`) reproduces the explicit
  `--native-selection fast_compressed --strategy greedy --match-search-budget 32`
  sizes byte-for-byte.

| case | before MiB/s | after MiB/s | speed ratio | before bytes | after bytes | size delta |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| dickens | 14.76 | 18.52 | 1.2545 | 51,971 | 52,716 | +1.43% |
| mozilla | 45.09 | 50.33 | 1.1162 | 20,112 | 20,143 | +0.15% |
| mr | 18.12 | 24.49 | 1.3514 | 32,663 | 33,017 | +1.08% |
| nci | 48.92 | 55.20 | 1.1283 | 11,033 | 11,323 | +2.63% |
| ooffice | 18.38 | 20.54 | 1.1172 | 68,503 | 68,670 | +0.24% |
| osdb | 26.62 | 27.85 | 1.0464 | 51,095 | 51,340 | +0.48% |
| reymont | 17.67 | 22.26 | 1.2597 | 39,168 | 40,136 | +2.47% |
| samba | 23.51 | 26.93 | 1.1453 | 48,697 | 48,893 | +0.40% |
| sao | 15.63 | 17.04 | 1.0902 | 99,490 | 99,562 | +0.07% |
| webster | 19.36 | 23.11 | 1.1936 | 43,073 | 43,573 | +1.16% |
| xml | 60.22 | 67.44 | 1.1199 | 10,748 | 10,958 | +1.95% |
| x-ray | 15.58 | 16.02 | 1.0287 | 93,086 | 93,138 | +0.06% |

Geometric-mean speed **1.1509x**, geometric-mean size **+1.01%** (worst nci
+2.63%). Level 3 remains smaller than libzstd 1.6.0 (the previous ladder note
measured 0.9580x size), and the ladder stays monotone: L2 59,878 > L3 52,716
on dickens.

## Correctness

The frozen level-3 wire in the controls fixture is re-frozen; levels 1/2 and
explicit budgets are unchanged. The full `test`/`check`/`check-wasm` gate is
the adoption check.
