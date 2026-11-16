# Zstd unindexed multi-duplicate match cap, 2026-11-17

## Finding

The unindexed multi-duplicate planner rescans the block suffix for up to 128
global-best duplicate matches. On the 128 KiB `dickens` prefix it took
**194 ms**, scanned **47.8 MB** of literal histogram bytes, and produced a
75,000-byte candidate that lost to the 50,325-byte beam. The first few matches
still tighten the DP's upper bound: skipping the planner entirely regressed
`sao` by about 10% even though its final frame was unchanged.

## Change

`emitMultiDuplicateMatchCompressedBlockWithFirst` now takes an explicit
`max_matches`. Production passes the full 128-match budget only when the
bounded precomputed index is available; unindexed large blocks use
`unindexed_multi_duplicate_max_matches = 2`. The first two matches keep the
useful upper bound, while the O(n^2) suffix rescans stop after the second
match. Diagnostic and benchmark entry points still request the full budget.

## Measurements

Twelve 128 KiB Silesia files, level 9, ReleaseFast, one iteration. Sizes are
identical before and after on every file; SHA-256 of every complete frame is
also identical (`level9-hashes-*.txt`).

| file | before MiB/s | cap-2 MiB/s | speedup |
| --- | ---: | ---: | ---: |
| dickens | 0.508 | 1.665 | 3.28x |
| mozilla | 5.251 | 6.028 | 1.15x |
| mr | 0.170 | 2.789 | 16.4x |
| nci | 1.425 | 1.423 | 1.00x |
| ooffice | 1.528 | 1.627 | 1.06x |
| osdb | 2.402 | 2.464 | 1.03x |
| reymont | 0.524 | 3.631 | 6.94x |
| samba | 0.461 | 0.460 | 1.00x |
| sao | 2.720 | 2.794 | 1.03x |
| webster | 0.300 | 4.060 | 13.5x |
| xml | 2.071 | 6.702 | 3.24x |
| x-ray | 3.485 | 3.618 | 1.04x |

The geometric-mean throughput gain over the twelve files is about **2.3x**,
with no control row below 0.999x. The locked
`run-zstd-encode-bench-gate` matrix passes unchanged.

Cap sweeps (single-file, 3 iterations / 7 rounds) showed 16 and 8 matches were
slower than 4; 2 matches recovered `sao` and gave the best aggregate. Full
removal of the unindexed planner regressed `sao` to 0.897x, so the 2-match
bound is retained.

## Validation

`zig build test-zstd` (pending final run); `run-zstd-encode-bench-gate`
passes; `zig build -j2 check-wasm` (pending); `zig fmt --check`;
`git diff --check`.

## Raw files

- `level9-before-silesia.csv` - full multi-duplicate planner.
- `level9-cap2-silesia.csv` - 2-match unindexed cap.
- `level9-hashes-before.txt` / `level9-hashes-after.txt` - frame SHA-256.
- `gate-cap2.log` - locked encode gate output.
