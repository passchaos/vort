# Zstd length-only second multi-duplicate match, 2026-11-17

## Finding

The production two-match multi-duplicate bound still priced every candidate
with a full Huffman literal plan. The second match only needs to make the
bound tighter; its payload is never used for emission. A length-only indexed
finder removes the per-candidate literal-plan build for that second match.

## Change

Add `findBestDuplicateMatchIndexedLengthOnly`, which walks the same indexed
candidate rows but ranks by match length/offset only. The production two-match
bound uses it for the second match on blocks above the exact-hash threshold.
The first match keeps exact payload pricing because the single-duplicate
candidate consumes it. Diagnostic/benchmark entry points still request the
full exact plan.

## Measurements

Twelve 128 KiB Silesia files, level 9, ReleaseFast. All twelve sizes are
identical before and after; the locked encode gate also passes unchanged.

Repeated 3-iteration/7-round medians:

| file | base MiB/s | length-only MiB/s | speedup |
| --- | ---: | ---: | ---: |
| dickens | 2.544 | 2.915 | 1.146x |
| samba | 2.096 | 3.280 | 1.565x |
| sao | 3.075 | 3.099 | 1.008x |
| xml | 9.107 | 9.111 | 1.000x |
| x-ray | 3.777 | 3.771 | 0.998x |

The single-run twelve-file matrix shows the same pattern: dickens 1.15x,
samba 1.56x, and the remaining rows neutral within host noise (about 6.4%
geometric mean). No control row falls below 0.998x, and no frame size changes.

## Validation

`zig build test-zstd` 1430/1430; `run-zstd-encode-bench-gate`;
`zig build -j2 check-wasm` 64/64; `zig fmt --check`; `git diff --check`.

## Raw files

- `level9-base-silesia.csv` - exact second-match baseline.
- `level9-lenonly-silesia.csv` - length-only second match.
- `gate-lenonly.log` - locked encode gate output.
