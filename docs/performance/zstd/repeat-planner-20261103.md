# Grouped repeat and mapped compressed sequence transitions, 2026-11-03

Two Zstd sequence-table planners dominated low-level encode samples.
`planLargeRepeatSequenceCodes` scanned every FSE symbol for every sequence
position while building its viability masks, and
`fillLargeCompressedSequenceTransitions` walked every state of a symbol to find
the first state whose range contains the next state.

The repeat planner now groups FSE states by the sequence code their symbol
represents once per table, then visits only matching states per position. The
compressed-transition planner fills a per-symbol next-state map: each state
range is disjoint and partitions the table, so filling costs O(table length)
and every transition lookup is O(1). Both changes preserve the exact
ascending-state tie rule and the emitted wire.

## Measurement

`run-zstd-encode-bench` on the 1 MiB XML prefix, level 1 with explicit fast
strategy and acceleration 1, three iterations per round and three rounds. The
benchmark reports the best round.

| Stage | Wire bytes | Encode ns | Ratio |
| --- | ---: | ---: | ---: |
| Baseline | 187,461 | 300,637,508 | 1.0000 |
| Grouped repeat DP | 187,461 | 197,132,699 | 0.6557 |
| Mapped transitions | 187,461 | 163,920,975 | 0.5452 |

The combined change is **1.83 times faster** with byte-identical output. The
perf profile's repeat planner share fell from about 38.6% to 16.9%, and the
compressed-transition walk is replaced by the O(1) map. The complete ReleaseFast
Zstd suite passes 1,272/1,272 tests with exit zero.

This remains a single-input, single-strategy screen and is not a full Zstd
matrix; libzstd still encodes this input substantially faster. The repeat
planner remains the largest encoder symbol after the change. [Raw rows](repeat-planner-20261103.csv)
retain the stage timings and wire equality.
