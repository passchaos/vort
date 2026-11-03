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
and every transition lookup is O(1). `largeSequenceTableSymbol` is now inline
so per-sequence plan dispatch specializes in its emit loops.

For blocks above 4,096 sequences, the repeat-table viability DP is skipped:
the repeat table only saves its FSE header, which is negligible beside a large
sequence payload, while the DP dominates low-level encode time. The block falls
back to predefined or compressed tables.

`absoluteOffsetSequenceCode` replaces its 32-entry base scan with the closed
form already used by `offsetCode`. Codes 3..31 cover `[2^c - 3, 2^(c+1) - 4]`,
so the selected code is `floor(log2(offset + 3))`; offsets 1..4 keep the 2-bit
code 2. The wrapper rejects the repeat-offset selectors 0 and 1, and
`offsetCode` still rejects overflow and out-of-range codes with
`error.CorruptFrame`.

Large blocks whose state-dependent re-emission previously took the scalar
planner now use the cached planner. The scalar plan re-validated every value
against its selected symbol, duplicating work the alternative builders already
did; the cached plan consumes their code arrays and precomputed value bits.

The reverse bitstream writer now reserves capacity once per flush and appends
each completed byte with `appendAssumeCapacity`, instead of checking capacity
on every byte. Block-only match scans read both sides directly from the block
instead of dispatching through the three-segment `byteAt` accessor per byte.
The three narrow FSE transition fields for each sequence are validated and
packed into one accumulator update before the reverse writer sees them. The
offset alternative builder also retains each sequence's resolved offset extra
value and final repcodes, so emission no longer replays the state machine over
every sequence. Match seeding inserts each distinct anchor once; acceleration
1 previously wrote the match end twice. Both table DPs handle the final
sequence position separately, removing a per-state last-position branch.
The prepared candidate now carries its proven final repcodes to commit, so the
large-block path no longer decodes the same bitstream a second time. State-dependent
re-emission also consumes the encoder's records directly instead of decoding the
candidate back into sequence values first.

## Measurement

`run-zstd-encode-bench` on the 1 MiB XML prefix, level 1 with explicit fast
strategy and acceleration 1, three iterations per round and three rounds. The
benchmark reports the best round.

| Stage | Wire bytes | Encode ns | Ratio |
| --- | ---: | ---: | ---: |
| Baseline | 187,461 | 300,637,508 | 1.0000 |
| Grouped repeat DP | 187,461 | 197,132,699 | 0.6557 |
| Mapped transitions | 187,461 | 163,920,975 | 0.5452 |
| Inlined symbol dispatch | 187,461 | 153,313,208 | 0.5100 |
| Repeat skip above 4,096 sequences | 187,489 | 114,806,784 | 0.3819 |
| Closed-form offset code | 187,489 | 107,072,102 | 0.3562 |
| Cached re-emission planner | 187,489 | 92,902,760 | 0.3090 |
| Batched bit flush | 187,489 | 91,256,348 | 0.3035 |
| Block-only match scan | 187,489 | 90,946,374 | 0.3025 |
| Packed transition fields | 187,489 | 90,135,365 | 0.2998 |
| Cached offset extras | 187,489 | 87,070,589 | 0.2896 |
| Deduplicated seed anchors | 187,489 | 84,303,965 | 0.2804 |
| Split last-position DP | 187,489 | 84,138,159 | 0.2799 |
| Prepared commit repcodes | 187,489 | 81,752,170 | 0.2729 |
| Records-based preparation | 187,489 | 76,730,873 | 0.2552 |

The combined change is **3.92 times faster**; the repeat-skip stage adds 28
bytes (0.015%) to this row, and the later changes leave the wire unchanged.
The complete ReleaseFast Zstd suite passes 1,273/1,273 tests with exit zero.

This remains a single-input, single-strategy screen and is not a full Zstd
matrix; libzstd still encodes this input substantially faster. The repeat
planner remains the largest encoder symbol below the skip threshold.
[Raw rows](repeat-planner-20261103.csv) retain the stage timings and wire sizes.

Follow-ups were measured over five iterations and five rounds and rejected as
noise: a word-at-a-time block-only match extension (147.34-148.07M ns versus
147.85-147.91M ns), a direct block-only hash path (147.38-148.02M ns) and a
four-byte block-only match precheck (142.20-141.82M ns versus
143.55-141.16M ns). All kept identical wire, so none justified the extra code.
A conditional long-match probe in double-fast was slower (97.4M ns versus
89.0M ns) with a 49-byte wire change. A commit cache stored in
`SequenceEncoderState` measured 87.1-87.4M ns versus 85.9M ns; the out-parameter
form above avoids that per-block state copy and is adopted.
