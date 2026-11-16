# Zstd optimal candidate budget 7, 2026-11-17

## Finding

The optimal DP used eight useful-chain candidates per position. Dropping to
seven enables the existing four-byte optimal route for 64-128 KiB blocks and
removes one candidate from every other optimal search. The twelve-file
level-9 screen shows a **13.4% geometric-mean throughput gain** with
near-neutral size.

## Change

`default_optimal_candidate_budget` changes from 8 to 7, matching the fastest
policy's measured point. `useFourByteOptimal` then routes 64-128 KiB blocks
through the specialized four-byte optimal parser. No other candidate family
or budget changes.

## Measurements

Twelve 128 KiB Silesia files, level 9, ReleaseFast, one iteration:

| file | cand-8 bytes | cand-7 bytes | delta | cand-8 MiB/s | cand-7 MiB/s | speedup |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| dickens | 50,325 | 50,404 | +79 | 2.085 | 2.443 | 1.172x |
| mozilla | 22,994 | 22,914 | -80 | 5.873 | 6.253 | 1.065x |
| mr | 32,676 | 32,676 | 0 | 2.761 | 3.293 | 1.193x |
| nci | 10,401 | 10,401 | 0 | 1.805 | 1.967 | 1.089x |
| ooffice | 68,512 | 68,549 | +37 | 2.815 | 3.011 | 1.070x |
| osdb | 50,141 | 50,003 | -138 | 2.568 | 2.656 | 1.034x |
| reymont | 37,093 | 37,093 | 0 | 3.617 | 4.513 | 1.248x |
| samba | 47,529 | 47,596 | +67 | 1.958 | 2.093 | 1.069x |
| sao | 97,780 | 97,832 | +52 | 2.931 | 3.084 | 1.052x |
| webster | 41,650 | 41,734 | +84 | 4.098 | 5.040 | 1.230x |
| xml | 9,712 | 9,712 | 0 | 6.765 | 9.562 | 1.413x |
| x-ray | 100,874 | 100,874 | 0 | 3.674 | 3.793 | 1.032x |

Geometric-mean speedup: **1.134x**. Aggregate size change: **+101 bytes**
(net), with mozilla and osdb improving; the largest per-file regression is
webster +84 bytes (+0.20%).

Repeated 3-iteration/7-round medians confirmed the effect: dickens
2.171 -> 2.541 MiB/s (1.17x), xml 6.720 -> 9.14 (1.36x), reymont
3.631 -> 4.57 (1.26x).

The locked `run-zstd-encode-bench-gate` matrix passes with identical sizes
(JSON level 9 640 B, multiblock 27,363 B, binary 8,607 B, level3_tradeoff
2,037 B).

## Validation

`zig build test-zstd` 1430/1430; `run-zstd-encode-bench-gate`;
`zig build -j2 check-wasm` 64/64; `zig fmt --check`; `git diff --check`.

## Raw files

- `level9-cand8-silesia.csv` - eight-candidate baseline.
- `level9-cand7-silesia.csv` - seven-candidate result.
- `gate-cand7.log` - locked encode gate output.
