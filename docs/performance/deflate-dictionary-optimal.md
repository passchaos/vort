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
  into preset history without paying for the complete history prefix.
- When the combined buffer exceeds the BT position domain, `.best` raw/zlib
  encoding switches to the bounded 32 KiB history-chunk planner. Each chunk's
  effective dictionary suffix, prior input history and payload fit the BT
  domain; the planner runs a fixed and one modeled pass and trims the history
  prefix. The split `.optimal` APIs and adaptive split scoring use the same
  planner. `optimalPlanAllocFrom` remains the small/fallback suffix planner.
- The raw/zlib `.best` fallback arbitration still compares the complete wire
  against the lazy default and filtered candidates, so the optimal preset never
  grows the wire.

## Evidence

All rows are Silesia prefixes with 32 KiB dictionaries, encoded through
`run-dictionary-deflate-report --level best`. The 32 KiB payload rows use a
16 KiB dictionary.

| Input | Dictionary | Before raw | After raw | Delta |
| --- | ---: | ---: | ---: | ---: |
| dickens 32 KiB | 16 KiB | 12,127 | 12,111 | -16 |
| xml 32 KiB | 16 KiB | 2,147 | 2,123 | -24 |
| nci 32 KiB | 16 KiB | 1,955 | 1,890 | -65 |
| dickens 64 KiB | 32 KiB | 24,391 | 23,428 | -963 |
| xml 64 KiB | 32 KiB | 4,204 | 4,071 | -133 |
| nci 64 KiB | 32 KiB | 4,603 | 4,270 | -333 |

The 32 KiB rows take the single-buffer BT suffix path; the 64 KiB rows take the
chunked BT path. The zlib wrappers track the same sizes plus their 10-byte
wrapper overhead: 23,438 / 4,081 / 4,280.

### Full 64 KiB dictionary matrix

One-shot `.best` raw bytes before and after the chunked hook, all twelve
Silesia sources at 64 KiB with 32 KiB dictionaries:

| Source | Before | After | Delta |
| --- | ---: | ---: | ---: |
| dickens | 23,714 | 23,428 | -286 |
| mozilla | 9,333 | 9,136 | -197 |
| mr | 15,468 | 15,104 | -364 |
| nci | 4,480 | 4,270 | -210 |
| ooffice | 35,818 | 35,560 | -258 |
| osdb | 23,868 | 23,757 | -111 |
| reymont | 17,051 | 16,718 | -333 |
| samba | 17,926 | 17,395 | -531 |
| sao | 48,487 | 48,210 | -277 |
| webster | 18,739 | 18,595 | -144 |
| x-ray | 46,220 | 45,202 | -1,018 |
| xml | 4,204 | 4,071 | -133 |

The chunked BT candidate is smaller than the former whole-input generic
optimal plan on every row, not merely a speed trade. Default and fast
dictionary wires are unchanged: dickens 24,503, xml 4,393 and nci 4,784 raw
bytes at the default level.

### zlib 1.2.11 ratio reference

Same fixtures, raw deflate with the same 32 KiB preset dictionary, system
zlib 1.2.11 via Python `compressobj(..., zdict=...)`:

| Vort setting | Reference | Vort total | Reference total | Aggregate |
| --- | --- | ---: | ---: | ---: |
| `.best` chunked BT | zlib level 9 | 261,446 | 270,770 | -3.44% |
| `.default` | zlib level 6 | 271,488 | 273,230 | -0.64% |

`.best` is smaller on all twelve rows (range -1.01% to -6.27%). `.default` is
smaller on eleven; `mr` is 0.36% larger. This is a ratio comparison only: the
reference uses a different algorithm, and encode/decode throughput and memory
were not measured in a matched lifecycle. It does not establish an
industry-best ranking against zlib-ng or zlib-rs.

### Rejected: adaptive split for the same inputs

`encodeRawBestAdaptiveSplitWithDictionaryAlloc` reuses the same BT chunk
planner. On dickens/xml/nci 64 KiB dictionary rows it produced the same wires
as the fixed 32 KiB chunked path (23,428 / 4,071 / 4,270 raw bytes) but took
19.5/37.1/64.9 s of whole-report wall time versus 3.2/1.9/4.3 s for the fixed
path. Adaptive split remains opt-in and is not selected by `.best`.


## Tradeoff and follow-ups

- The 32 KiB BT rows are also faster than the generic planner on the same
  report: xml 1.41 s -> 0.35 s, nci 2.27 s -> 0.40 s, dickens 2.84 s -> 2.33 s
  (the dickens report is dominated by its no-dictionary `.best` rows).
- The former 64 KiB generic path was about 2.9x the old lazy path on dickens.
  The chunked BT path removes that multi-second whole-input parse while
  improving size on all twelve sources. It is not a throughput claim: the
  report includes several encodes and was not run on a dedicated performance
  host.
- This is a functional/quality increment, not a competitor parity claim. No
  current-source competitor matrix was rerun for it.

## Validation

- `zig test src/deflate.zig`: 674/674 tests, including the new
  `raw best optimal dictionary planner references preset history`,
  `raw deflate incremental best encoder uses optimal preset dictionary history`,
  `raw and zlib best large dictionary inputs use the chunked BT plan`, and
  `optimal suffix plan references history prefix without emitting it`
  contracts.
- `zig build check`: passed on rerun. The first run hit a transient Node/WASI
  gate failure that passed when the same gate was rerun directly.
- `run-dictionary-deflate-report` at `default` and `best` levels over the
  Silesia prefix fixtures above, plus the full twelve-source 64 KiB matrix.
