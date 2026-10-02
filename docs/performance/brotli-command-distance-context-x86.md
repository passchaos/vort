# x86-64 Brotli command-root distance-context experiment

Date: 2026-10-02. Baseline: `7eb58dba`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread.

## Experiment

The 32-bit single-command root entry had four unused bits while the command
LUT already stores the RFC distance context. The candidate used two of those
bits to carry the context through the zero-insert command path and replaced
the explicit-distance `distanceContext(copy_len)` classification in the
cached-context middle and full executors.

The exhaustive invariant check covered all 704 command entries. Contexts zero,
one, and two are singleton copy-length ranges 2, 3, and 4; context three starts
at length 5 and is constant through each command's maximum extra-bit value.
The candidate kept the command root at four bytes and `InsertCopyLengths` at
three machine words (24 bytes on this host). All 551 direct ReleaseSafe Brotli
tests passed before measurement.

Two representations were evaluated:

- carrying the two bits in the otherwise unchanged 24-byte
  `InsertCopyLengths` result;
- writing the context to a separate caller-owned `u2` so generic length
  results stayed unchanged.

The second representation expanded the paired full-tier function from
`0x1690` to `0x170e` bytes and regressed roadmap q9/q5 in a seven-pair screen,
so it was rejected immediately. Limiting context writes in the first
representation to the target command path left the target text sections
unchanged and did not remove the control regression.

## Fixed-CPU results

Each process decoded a frozen frame 500 times and retained the best of five
internal rounds. `clustered_q8` uses the benchmark's 10x iteration divisor, so
it decoded 100 times after requesting 1,000 iterations. Baseline/candidate
launch order reversed on alternate pairs; every size and checksum matched.

| Input | Median | Geometric mean | Wins | Range |
| --- | ---: | ---: | ---: | ---: |
| source q9 | 1.0063x | 1.0061x | 15/15 | 1.0012x--1.0093x |
| source q5 | 1.0069x | 1.0082x | 14/15 | 0.9996x--1.0190x |
| roadmap q9 | 1.0001x | 1.0014x | 8/15 | 0.9952x--1.0106x |
| roadmap q5 | 0.9995x | 1.0002x | 7/15 | 0.9932x--1.0102x |
| clustered q8 | 0.9906x | 0.9907x | 0/15 | 0.9820x--0.9999x |

The source wins are real but corpus-specific. The deterministic 1 MiB
clustered control loses about 0.93% geometrically with no winning pair. The
target-only write variant still loses about 0.71% geometrically on that row.
This violates the no-regression requirement, so all production-code changes
were removed. No throughput claim is made from this experiment.

The candidate executable also grew from 6,105,304 to 6,107,392 bytes. Its
paired-literal section grew by 144 bytes, the 10-bit auxiliary section by 63
bytes, and the 9-bit wide section by 117 bytes. Although the selected source
middle-tier instance remained `0x109e` bytes, the full-tier payload grew from
`0x1690` to `0x16eb`. This is consistent with the mixed corpus result and gives
no basis for retaining the extra data flow.

Exact hashes, commands, sizes, and nanosecond samples are recorded in
[brotli-command-distance-context-x86-20261002.json](data/brotli-command-distance-context-x86-20261002.json).

## Decision

Do not propagate distance context through the command result with either an
extra struct field or an output pointer in the current executors. Revisit only
with a representation that demonstrably reduces generated hot-loop code and
passes a long clustered control before running the full reference matrix.
