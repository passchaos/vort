# Deflate preset-dictionary optimal planning

Date: 2026-11-10.

## Problem

`planTokensWithDictionaryAlloc` mapped the `.optimal` parser to the lazy
dictionary planner:

```zig
.lazy, .optimal => try lz77.lazyGreedyPlanAllocWithDictionary(...)
```

Raw and zlib `.best` calls with a non-empty preset dictionary therefore used a
lazy greedy parse even though their no-dictionary path uses the covered BT
optimal parser and dynamic cost refinement. The highest-quality preset
silently lost its quality behavior whenever a dictionary was attached.

## Change

- `lz77.optimalPlanAllocFrom(allocator, input, start, options)` plans only
  `input[start..]` while indexing `input[0..start]` as match history. The
  reverse DP stops at `start`, and token reconstruction begins there, so prefix
  bytes are addressable but never emitted. `start == 0` reproduces
  `optimalPlanAlloc` exactly; `start > input.len` returns
  `error.InvalidBlockPlan`.
- Deflate's dictionary planner now builds one contiguous
  `dictionary suffix + input` buffer. When the combined length is within the
  covered BT parser's `4_096...65_536` range, it starts the BT solve one maximum
  match before the payload and trims the crossing token, preserving matches
  into preset history without paying for the complete history prefix. Larger
  combined buffers use `optimalPlanAllocFrom`.
- The raw/zlib `.best` fallback arbitration still compares the complete wire
  against the lazy default and filtered candidates, so the optimal preset never
  grows the wire.

## Evidence

All rows are 64 KiB Silesia prefixes with 32 KiB dictionaries, or 32 KiB
prefixes with 16 KiB dictionaries, encoded through
`run-dictionary-deflate-report --level best`.

| Input | Dictionary | Before raw | After raw | Delta |
| --- | ---: | ---: | ---: | ---: |
| dickens 32 KiB | 16 KiB | 12,127 | 12,111 | -16 |
| xml 32 KiB | 16 KiB | 2,147 | 2,123 | -24 |
| nci 32 KiB | 16 KiB | 1,955 | 1,890 | -65 |
| dickens 64 KiB | 32 KiB | 24,391 | 23,714 | -677 |
| xml 64 KiB | 32 KiB | 4,204 | 4,204 | 0 |
| nci 64 KiB | 32 KiB | 4,603 | 4,480 | -123 |

The 32 KiB rows take the BT suffix path; the 64 KiB rows take the generic
suffix-optimal path because the combined buffer exceeds the BT parser's
65,536-byte position domain. `xml` 64 KiB is unchanged because the complete-wire
arbitration retained the lazy fallback.

Default and fast dictionary wires are unchanged: dickens 24,503, xml 4,393 and
nci 4,784 raw bytes at the default level, matching the pre-change report.

## Tradeoff and follow-ups

- The 32 KiB BT rows are also faster than the generic planner on the same
  report: xml 1.41 s -> 0.35 s, nci 2.27 s -> 0.40 s, dickens 2.84 s -> 2.33 s
  (the dickens report is dominated by its no-dictionary `.best` rows).
- The 64 KiB generic path is about 2.9x the old lazy path on dickens. That is
  the cost of honoring the quality preset; default/fast paths are untouched.
  A chunked BT candidate with dictionary + prior-input history is the next
  speed improvement for large dictionary-backed blocks.
- This is a functional/quality increment, not a throughput or memory claim.
  No current-source competitor matrix was rerun for it.

## Validation

- `zig test src/deflate.zig`: 673/673 tests, including the new
  `raw best optimal dictionary planner references preset history`,
  `raw deflate incremental best encoder uses optimal preset dictionary history`,
  and `optimal suffix plan references history prefix without emitting it`
  contracts.
- `zig build check`: passed on rerun. The first run hit a transient Node/WASI
  gate failure that passed when the same gate was rerun directly.
- `run-dictionary-deflate-report` at `default` and `best` levels over the
  Silesia prefix fixtures above.
