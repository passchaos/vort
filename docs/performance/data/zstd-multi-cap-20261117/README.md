# Zstd multi-duplicate match cap, 2026-11-17

## Finding

The multi-duplicate planner rescans each block suffix for up to 128
global-best duplicate matches. On the 128 KiB `dickens` prefix the unindexed
variant took **194 ms**, scanned **47.8 MB** of literal histograms, and
produced a 75,000-byte candidate that lost to the 50,325-byte beam. After the
mixed-search removal, the indexed variant used by the adaptive split
candidates still consumed about **31%** of level-9 time.

Removing the planner entirely regressed `sao` by about 10%: its early matches
tighten the optimal DP's upper bound even when the multi plan loses.

## Change

`emitMultiDuplicateMatchCompressedBlockWithFirst` takes an explicit
`max_matches`. Production now passes
`multi_duplicate_production_max_matches = 2` for every block, indexed or not.
The first two matches keep the useful DP upper bound while the O(n^2) suffix
rescans stop early. Diagnostic and benchmark entry points still request the
full 128-match budget.

## Measurements

Twelve 128 KiB Silesia files, level 9, ReleaseFast, one iteration. Sizes are
identical before and after on every file; SHA-256 of every complete frame is
also identical (`level9-hashes-*.txt`).

| file | before MiB/s | cap-2 MiB/s | speedup |
| --- | ---: | ---: | ---: |
| dickens | 0.508 | 2.085 | 4.11x |
| mozilla | 5.251 | 5.873 | 1.12x |
| mr | 0.170 | 2.761 | 16.2x |
| nci | 1.425 | 1.805 | 1.27x |
| ooffice | 1.528 | 2.815 | 1.84x |
| osdb | 2.402 | 2.568 | 1.07x |
| reymont | 0.524 | 3.617 | 6.90x |
| samba | 0.461 | 1.958 | 4.25x |
| sao | 2.720 | 2.931 | 1.08x |
| webster | 0.300 | 4.098 | 13.7x |
| xml | 2.071 | 6.765 | 3.27x |
| x-ray | 3.485 | 3.674 | 1.05x |

The geometric-mean throughput gain over the twelve files is about **2.8x**,
with no control row below 1.0x. The locked `run-zstd-encode-bench-gate` matrix
passes unchanged.

Cap sweeps showed 16 and 8 matches were slower than 4, and 4 was slower than 2
on samba/dickens/ooffice/nci. Two matches is the cheapest point that still
recovers the `sao` bound, so it is the production budget.

## Validation

`zig build test-zstd` 1430/1430; `run-zstd-encode-bench-gate`;
`zig build -j2 check-wasm` 64/64; `zig fmt --check`; `git diff --check`.

## Raw files

- `level9-before-silesia.csv` - full 128-match planner.
- `level9-cap2-silesia.csv` - primary-only unindexed cap.
- `level9-cap2-global-silesia.csv` - production cap for every block.
- `level9-hashes-before.txt`, `level9-hashes-cap2-global.txt` - frame SHA-256.
- `gate-cap2.log` - locked encode gate output.
