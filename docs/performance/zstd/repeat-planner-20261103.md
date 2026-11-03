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
candidate back into sequence values first. Large candidates are now emitted
against the current frame state in the first place, so preparation no longer
repeats the whole table-planning and emission pass. Small blocks with an
established frame state take the same state-aware path; the initial block keeps
its frozen state-free wire. On the 64 KiB XML prefix this moves encode time
from 2.958/2.996M ns to 2.872/2.933M ns (about 2.5%) with unchanged wire, while
1 MiB runs stay within run-to-run noise. Intra-block matches in multi-block
frames now read both forward and backward comparison bytes directly from the
block instead of dispatching through the three-segment accessor. The fast
repeat-plan skip threshold drops from 4,096 to 2,048 sequences: the repeat
table saves only its FSE header, so removing the DP from the 2,048-4,096 band
costs 6 bytes on XML while cutting low-level encode time substantially. The
hash word loader marks the dictionary segment unlikely, keeping history and
block hashing on the predicted path. History seeding hashes contiguous history
bytes directly instead of dispatching through the segment-aware word loader
for every seeded position. Block hash lookups and match-seed anchors also read
the current block directly; the segment-aware loader remains for boundary
positions that can span slices.

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
| State-aware candidate emission | 187,489 | 60,112,090 | 0.2000 |
| Intra-block match scan | 187,489 | 58,610,198 | 0.1950 |
| Repeat skip above 2,048 sequences | 187,495 | 53,957,173 | 0.1795 |
| Dictionary-unlikely hash hint | 187,495 | 53,535,559 | 0.1781 |
| Direct history seed hashing | 187,495 | 46,758,314 | 0.1555 |
| Direct block hash paths | 187,495 | 45,207,876 | 0.1504 |

The combined change is **6.65 times faster**; the repeat-skip stages add 34
bytes (0.018%) to the baseline, and the later changes leave the wire unchanged.
The complete ReleaseFast Zstd suite passes 1,273/1,273 tests with exit zero.

This remains a single-strategy screen and is not a full Zstd matrix; libzstd
still encodes these inputs substantially faster. The repeat planner remains
the largest encoder symbol below the skip threshold.
[Raw rows](repeat-planner-20261103.csv) retain the stage timings and wire sizes.

## Corpus screen

Current source, 1 MiB prefix, level 1 with explicit fast strategy and
acceleration 1, three iterations per round and three rounds, one run per file:

| File | Vort bytes | libzstd bytes | Size ratio | Vort ns | Vort MiB/s |
| --- | ---: | ---: | ---: | ---: | ---: |
| xml | 187,495 | 172,242 | 1.0886 | 45,207,876 | 66.4 |
| dickens | 446,706 | 430,405 | 1.0379 | 91,479,542 | 32.8 |
| reymont | 375,454 | 338,665 | 1.1086 | 81,463,617 | 36.8 |
| x-ray | 720,706 | 803,674 | 0.8968 | 121,005,790 | 24.8 |

These rows confirm the timing direction outside XML, but they are not a
whole-file or all-twelve-source matrix; x-ray remains the only row smaller
than the reference here.

Follow-ups were measured over five iterations and five rounds and rejected as
noise: a word-at-a-time block-only match extension (147.34-148.07M ns versus
147.85-147.91M ns), a direct block-only hash path (147.38-148.02M ns) and a
four-byte block-only match precheck (142.20-141.82M ns versus
143.55-141.16M ns). All kept identical wire, so none justified the extra code.
A conditional long-match probe in double-fast was slower (97.4M ns versus
89.0M ns) with a 49-byte wire change. A commit cache stored in
`SequenceEncoderState` measured 87.1-87.4M ns versus 85.9M ns; the out-parameter
form above avoids that per-block state copy and is adopted.

Further rejected experiments, all at unchanged wire unless noted: prepared
repcodes for the small-block path (77.62-77.68M ns versus 76.73-77.07M at
1 MiB; 64 KiB neutral), a block-only backward match extension
(79.15-77.86M ns), direct offset symbols in the chooser (77.52-78.16M ns), a
four-bit transition lookup DP (95.8-95.3M ns) and cached symbol codes in the
repeat planner (78.66-77.21M ns). None justified the extra code or state.

A segment-walking match scan with vectorized run comparison measured
59.61/59.57/59.19M ns versus 58.61/57.88/58.26M, and a scalar history fast
path measured 61.50/60.49/60.43M ns; both were reverted. The first history
variant also changed the wire by 178 bytes until the history-to-block crossing
index was corrected, after which the wire matched but the path was slower.

Removing compressed table alternatives was rejected on ratio cost. Skipping
all three measured 51.9/50.9/51.5M ns but grew the wire from 187,495 to
238,000 bytes (+27%). Skipping only the offset table measured
52.7/52.5/52.3M ns at 197,725 bytes (+5.5%), and skipping only the match table
measured 52.3-53.1M ns at 197,922 bytes (+5.6%). The compressed planners stay
in the fast policy.

Seed-density changes also lost on speed despite smaller wires: capping the
dense history seed measured 55.05/54.23/54.42M ns at 187,446 bytes, a
single-byte recent stride measured 58.62/57.61/56.76M ns at 187,238 bytes, and
doubling the sparse older step measured 56.70/58.65/57.30M ns at 187,454 bytes.
The current density is speed-optimal for this input. A second dictionary
branch hint in `byteAt` measured 54.56/53.89/53.77M ns versus
53.54/53.19/52.74M with only the hash-loader hint, so only the latter was kept.
