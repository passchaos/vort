# Zstd FSE table block-reuse measurement, 2026-11-14

Status: measurement only; no production source changed. Decides whether a
cached/retained FSE table prototype can address the memset/memcpy setup cost
identified in `../decode-hotspot-20261114.md`.

## Method

`tools/decode/fse_reuse_probe.zig` walks every block of a frame through the
public `inspectNativeFrameFirstBlock`, `inspectNativeFrameBlockAt` and
`inspectNativeFrameBlockSequenceModes` APIs, counting block kinds and the
LL/OF/ML sequence table modes. The probe only reads block headers and
sequence mode bytes; it never decodes payloads or changes decoder state.

Inputs are the pinned full-file Silesia frames from the 2026-11-14 decode
matrix. Raw output files in this directory retain the exact probe stdout for
mozilla, sao, nci and xml at levels 3 and 19.

## Observed mode mix

| Fixture | Sequence blocks | Compressed tables per block | Repeat reuse per block |
| --- | ---: | ---: | ---: |
| mozilla L3 | 1366 | 82.9% | 0.0% |
| mozilla L19 | 2100 | 94.1% | 42.1% |
| sao L3 | 306 | 100.0% | 0.0% |
| sao L19 | 119 | 99.2% | 16.0% |
| nci L3 | 256 | 100.0% | 0.0% |
| nci L19 | 256 | 92.2% | 7.8% |
| xml L3 | 47 | 97.9% | 0.0% |
| xml L19 | 65 | 83.1% | 15.4% |

The repeat percentage uses the literal-length table as the per-block proxy;
offset and match-length counts are nearly identical in every output.

## Interpretation

1. Level-3 frames never emit repeat-mode sequence tables on these fixtures
   (0% across all four corpora). Every sequence block carries a fresh
   compressed FSE description, so there is no existing wire-level reuse to
   exploit at that level.
2. Level-19 reuse is real but uneven: mozilla reaches 42.1% while nci only
   7.8%. The decoder already honors repeat mode through
   `resolveSymbolTable`, which copies the previous `SequenceTables` entry
   without rebuilding, so that share already avoids the memset/memcpy cost.
3. A new content-addressed cache keyed on normalized-count signatures would
   only help blocks whose wire mode is `compressed` but whose distribution
   matches an earlier block. The mode counts alone cannot prove such
   content duplication; that requires hashing the normalized arrays, which
   is additional per-block work on the very path being optimized.
4. Because 83-100% of sequence blocks still build compressed tables and the
   dominant level-3 workload has zero repeat traffic, a retention cache
   cannot remove the observed setup cost for the slowest matrix row
   (mozilla 1 MiB L3). The safer conclusion is to not start a cache
   prototype without first measuring normalized-array equality directly.

## Next measurement if this path is pursued

Extend the probe to hash each compressed table's normalized-count array and
report exact content-hit rates separately from wire repeat mode. Only a
content-hit rate above the cache lookup cost on the level-3 fixtures would
justify a retained-table design; otherwise the FSE setup memset/memcpy must
be reduced inside the builder itself rather than avoided through caching.
