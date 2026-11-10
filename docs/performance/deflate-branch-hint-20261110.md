# Deflate unlikely branch hints on exceptional/secondary paths

## Context

After the wide-copy increment, a `branch-misses` profile of `nci.64k` L6
put 43% of all mispredicts in `deflate.semantic.linear_entry.aligned`;
the hottest sites were the literal `exceptional_flag` test (secondary
table / EOB path) and the distance `literal_flag` test (secondary
distance path). Both are rare relative to primary-table hits, but the
compiler interleaved their cold blocks with the common path.

## Change

Two `@branchHint(.unlikely)` annotations in
`decodeDynamicBlockIntoLinearMode`: the literal exceptional-flag branch
and the distance primary/secondary branch. No data or control-flow
semantics change.

## Result

48-row five-round paired A/B (Silesia 64 KiB/1 MiB, zlib L6/L9 raw
frames, taskset CPU 15, per-row medians of best-of-five):

| Group | new/old time geomean |
| --- | ---: |
| L6 64 KiB | 0.9827 (-1.73%) |
| L6 1 MiB | 0.9832 (-1.68%) |
| L9 64 KiB | 0.9788 (-2.12%) |
| L9 1 MiB | 0.9820 (-1.80%) |
| all 48 rows | **0.9817 (-1.83%)** |

Bootstrap 95% interval over rows: `[-2.35%, -1.32%]`. Strongest rows:
`nci.64k` L9 -5.67%, `mozilla.1m` L6 -5.19%, `sao.1m` L9 -4.39%;
worst control `reymont.64k` L6 +0.87%, every row above the 0.98x floor.
`zig test src/deflate.zig`: 670/670.

A companion experiment pinning the semantic literal/distance lookup
arrays to local base pointers measured 0.9998 over three rounds and was
rejected: the compiler already keeps the decoder base in a register, so
the extra slices added frame state without changing generated hot code.

Raw rows: [deflate-branchhint-5r.csv](data/deflate-branch-hint-20261110/deflate-branchhint-5r.csv).
