# Bzip2 and Snappy streaming allocation baseline

Date: 2026-10-24. Zig 0.16.0, Linux x86-64, Intel Core i7-10700K.
This extends the [dictionary/memory contracts](dictionary-memory-contracts-functional-baseline.md).
The evidence concerns decoded storage, requested-allocation limits, progress
and compatibility. No cross-library throughput or RSS leadership is claimed.

## Bzip2 checked plaintext replay

Incremental Bzip2 retains encoded candidates, transformed BWT bytes and a
persistent `u32` inverse-link table. A numeric cursor traverses BWT and RLE once
to count plaintext and verify the block CRC, then resets to replay spans into
caller output. It does not store the complete plaintext. One-shot and the
legacy full-output helper reuse the same inverse/RLE core.

The advertised level-9 size limits transformed bytes to 900000. RLE plaintext
can reach `259 * floor(N / 5) + N % 5`, or 46620000 bytes for that limit.
Transformed storage grows from actual decoded bytes; it is not preallocated
from a caller's output cap. Link storage requires four bytes per transformed
byte. Block CRC failure publishes zero current-block bytes, while combined
stream CRC failure may follow already-validated output.

`max_output_len` and the exact pledge remain cumulative. `max_decoded_block_len`
is a plaintext-count limit rather than a scratch capacity. Work budgets include
all retained capacities and allocator-backed temporary storage. Stop mode ends
one member, leaves suffixes untouched and returns zero-progress `.done` until
explicit `nextStream`; the cumulative pledge is checked after logical EOF.
Short stopped pledges can resume through `continue_with_next_stream`.

The complete ReleaseFast Bzip2 suite passes 50 tests. Thirteen independent
contract groups and the older incremental regressions verify bit-aligned
blocks, legacy randomization, RLE count boundaries, allocation failure,
retained reset, reconfiguration, active movement and exact progress.

The independent system Python/libbz2/bzip2 1.0.8 campaign passes 92 cases over
19 reference streams, including 72 one-shot comparisons, six exact work-budget
checks, 25 allocation failures and 20 expected errors. References include
randomized legacy blocks, non-byte-aligned multi-block data and stopped suffixes.

| Single-block RLE sample | Compressed bytes | Transformed capacity | Link capacity | Requested work peak |
| --- | ---: | ---: | ---: | ---: |
| 8 MiB plaintext | 48 | 164485 | 657940 | 822469 |
| 40 MiB plaintext | 49 | 822415 | 3289660 | 4112120 |

Both pass with a 5 MiB decoder-owned budget and zero decoded capacity. These
are corpus observations; caller verification/output buffers are excluded.
Second-block CRC failure preserves exactly 99981 first-block bytes; combined
CRC failure preserves the complete verified stream. Snapshot deltas match the
actual published prefix, and sticky retries report zero new I/O.

Exact commands, reference/probe hashes and current source hashes are retained
in [the Bzip2 JSON](data/bzip2-replay-x86-20261024.json).

## Snappy block cursors and framing

Native framed, Xerial and Hadoop decoders use the same fully validated raw
token plan and numeric output cursor. The plan records decoded size and maximum
copy distance. Literal and COPY1/COPY2/COPY4 spans replay into caller buffers;
history is sized from the maximum required distance rather than complete
plaintext. No raw-block slice or temporary allocator pointer is retained in
the cursor.

COPY4 offsets are unsigned 32-bit distances into the decoded prefix. They do
not have a universal 64 KiB restriction. Xerial/Hadoop history may approach
the decoded chunk size; finite work budgets remain the caller's allocation
bound. Standard framed data separately limits decoded chunks to 64 KiB.
Native CRC-32C is scanned before replay, preserving check-before-output.
Uncompressed chunks drain the verified owned payload without a second copy;
identifier and skippable payloads use bounded direct processing.

Native `max_output_len` preserves member scope; `max_total_output_len` and work
budgets survive `nextStream` and can only tighten. Xerial/Hadoop output caps
already apply to the whole operation. Hadoop tracks validated chunk sizes
separately from published output, retaining outer-pledge checks and valid
finish while the last complete chunk waits to drain.

All decoders report failed-call accepted input/published output, detection
offsets and requested live/peak work. Parser/allocation errors are sticky.
Rejected incomplete `finish()` calls preserve the established ability to
supply remaining input. Reset retains capacity and starts fresh counters;
valid explicit reconfiguration releases storage through the original budget.

The complete ReleaseFast Snappy and Xerial/Hadoop suites pass 69 and 30 tests.
The current Bzip2/Snappy contract aggregate passes 46 tests in Debug and
ReleaseFast. ZIP method-12/descriptor integration passes 65 tests, and the
existing C Snappy interoperability probe passes 16 bidirectional raw/framed
cases. The raw one-shot output buffer retains its established error semantics;
the probe records partial modification on error rather than inventing atomicity.

The independent libsnappy 1.1.8 / snappy-java 1.1.10.7 campaign passes 255 runs
over 50 streams: Framed 101, Xerial 76 and Hadoop 78. Twelve allocation-failure
cases verify sticky progress, reset/reconfigure and complete cleanup. COPY4
distance 70001 uses that actual history size for Xerial/Hadoop; standard framed
data separately verifies the 65536-byte decoded boundary. Manually constructed
COPY/envelope recipes are documented and independently decoded.

Exact provenance, source/driver/two-probe hashes and outcomes are retained in
[the Snappy cursor JSON](data/snappy-cursors-x86-20261024.json).

The shared framing template is also used by Hadoop LZ4. Its adapter now wraps
the existing LZ4 block cursor with conservative history of at most 64 KiB and
reserves actual capacity before caller output. The allocating and framing rules
remain unchanged. Hadoop LZ4 family ReleaseFast tests pass 61 cases, and its
Debug CLI Python `lz4.block` differential passes bidirectionally. The additional
adapter prevents the new raw-cursor interface from breaking that existing user.
The final build check passes all 134 steps, including wasm32-wasi. Debug CLI
help and Hadoop LZ4 interoperability smoke checks also succeed.

```sh
zig build test-bzip2 test-snappy test-snappy-framing -Doptimize=ReleaseFast
zig build test-bzip2-snappy-contracts
zig build test-bzip2-stream-consumers test-hadoop-lz4 -Doptimize=ReleaseFast
zig build run-bzip2-stream-contract-diff -Doptimize=ReleaseFast -- --report /tmp/bzip2-replay.json
zig build run-snappy-stream-contract-diff -Doptimize=ReleaseSafe -- --report /tmp/snappy-cursors.json
zig build check --summary all
```

Requested allocation bytes exclude fixed state, stack scan buffers, caller
storage, allocator bookkeeping and allocator-internal remap transients.
Real-file ratio/throughput, colder allocation and RSS comparisons remain
necessary before any broad industry-best claim.
