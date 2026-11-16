# Zstd wide-block mixed-search removal, 2026-11-17

## Finding

Levels 4-22 ran a recursive mixed duplicate/repeated lookahead on every block
with `match_search_budget >= 96`. On the 128 KiB `dickens` prefix it consumed
**84.8%** of cycles in `searchMixedCandidateLookaheadPlans` ->
`MixedMatchCandidateCache.candidatesAt` -> `findBestDuplicateMatchIn` ->
`singleBestSequencePayloadLen`, taking **25.6 s** per encode while returning
the same **50,325-byte** frame as level 3.

## Change

The per-call mixed worker is removed. The mixed search now runs only for
low-alphabet structured blocks (`preferSerialMixedSearch`), serially, through
the existing decisive-beam/dominance arbitration. Wide-alphabet blocks skip
it and use the checked non-mixed selector. No production path in the level
ladder or block emitter creates threads per call; the explicit parallel
seekable API remains the only thread-spawning boundary.

## Measurements

Level 9, 128 KiB `dickens` prefix, ReleaseFast, one iteration:

| state | bytes | ns | MiB/s |
| --- | ---: | ---: | ---: |
| before | 50,325 | 25,659,419,312 | 0.004872 |
| after | 50,325 | 246,026,727 | 0.508 |

Levels 4-22 after the change measure about 247-250 ms each and still emit
50,325 bytes; level 3 remains 36 ms. The 25.6 s cliff is gone.

Twelve 128 KiB Silesia files at level 9 after the change produce the same
`vort_bytes` as level 3 on every file (`level9-after-silesia.csv` versus
`level3-baseline-silesia.csv`). The locked
`run-zstd-encode-bench-gate` matrix passes unchanged: JSON level 9 640 B,
multiblock 27,363 B, binary 8,607 B, level3_tradeoff 2,037 B
(`gate-after.log`).

A separate reversible screen disabled the structured mixed search too; the
same gate passed with identical sizes, so the mixed candidate showed no size
benefit on the locked corpus. It is retained only for structured blocks as a
bounded ratio candidate.

## Validation

`zig build test-zstd` 1430/1430; `run-zstd-encode-bench-gate`;
`zig build -j2 check-wasm` 64/64 steps; `zig fmt --check`; `git diff --check`.

## Raw files

- `level9-before-dickens.csv` - pre-change level 9 single-file measurement.
- `level9-after-silesia.csv` - post-change level 9, twelve Silesia prefixes.
- `level3-baseline-silesia.csv` - level 3 reference sizes, same prefixes.
- `gate-after.log` - locked encode gate output.
