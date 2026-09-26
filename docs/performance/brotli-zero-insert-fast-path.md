# Brotli zero-insert fast path

This note records the 2026-09-27 optimization of Brotli compressed payloads.
Measurements use Zig 0.16.0 ReleaseFast on an Intel Core i9-13900K. Input
names below are anonymized; machine-local paths and complete pair data are
kept only in the ignored performance log.

## Implementation

libbrotli's `ProcessCommandsInternal` jumps directly from a decoded command to
distance processing when its insert length is zero. Vort previously initialized
the two-byte literal-context history before entering an empty loop, even though
no literal could consume those values.

The compact-tail, external-lookup, and wide-external-lookup executors now guard
their complete literal-loop setup with `insert_len != 0`. This leaves command,
distance, copy, malformed-stream, and partial-progress behavior unchanged. In
the principal compact-tail specialization, the generated code shrinks from
`0xd0a` to `0xc9b` bytes.

## Fixed-CPU results

Each row alternates independently built baseline and candidate executables on
one fixed CPU. Log and JSON measurements use seven pairs. PDF-A uses seven
pairs; the initially borderline PDF-B q5/q9 controls were extended to fifteen.

| Quality | Input | Wins | Median | Geometric mean |
| ---: | --- | ---: | ---: | ---: |
| 1 | Log | 7/7 | 1.003335x | 1.003692x |
| 5 | Log | 7/7 | 1.014405x | 1.015397x |
| 9 | Log | 7/7 | 1.012826x | 1.014258x |
| 1 | JSON | 7/7 | 1.001382x | 1.008830x |
| 5 | JSON | 7/7 | 1.008295x | 1.007731x |
| 9 | JSON | 5/7 | 1.006064x | 1.004796x |
| 1 | PDF-A | 5/7 | 1.000814x | 1.001047x |
| 5 | PDF-A | 3/7 | 0.999929x | 1.000121x |
| 9 | PDF-A | 3/7 | 0.999966x | 1.000370x |
| 1 | PDF-B | 4/7 | 1.000462x | 1.000209x |
| 5 | PDF-B | 7/15 | 1.000000x | 0.999943x |
| 9 | PDF-B | 7/15 | 1.000000x | 1.000327x |

The equal-weight geometric mean of the twelve row means is `1.004712x`.
The two medians below one differ by less than 0.01%; the target text workloads
improve consistently without a measurable PDF regression.

## Validation

- 53 focused compressed-stream tests in ReleaseSafe;
- fast-reader and UTF-8 context-history tests in ReleaseFast;
- 7,056 generated one-shot streams and 7,056 progressive schedules against
  libbrotli;
- 16 tracked real-corpus one-shot/progressive cases;
- the 13-row libbrotli reference benchmark gate;
- the normal compile-check graph.

The broader Brotli leadership target remains open; this change removes work
from zero-insert commands but does not eliminate the remaining literal-context
lookup dependency or general match-copy cost.
