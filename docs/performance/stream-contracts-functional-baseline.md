# Incremental resource and dictionary contracts

Date: 2026-10-24. Zig 0.16.0, Linux x86-64. These contracts extend the
[bounded decoding baseline](bounded-streaming-functional-baseline.md).
They establish functional limits and recovery behavior; they do not establish
cross-library throughput, compression-ratio or RSS leadership.
Host CPU: Intel Core i7-10700K. Runtime validation uses portable native
ReleaseFast builds unless another mode is stated.

## Native LZ4 and Zstd

Both `NativeIncrementalFrameDecoder` APIs use the following independent limits:

| Option | Scope |
| --- | --- |
| `max_compressed_buffer_len` | Retained compressed capacity, including the payload needed to validate a checksummed LZ4 block or decode a compressed Zstd block. |
| `max_decoded_buffer_len` | Decoded bytes in one data frame, including previously published bytes. |
| `max_output_len` | Cumulative decoded output in the logical operation, across ordinary and explicitly resumed data-frame members. |
| `max_working_memory` | Decoder-owned live requested heap bytes, including retained capacities and temporary decode allocations. |
| `expected_output_len` | Optional exact cumulative decoded count; `finish()` checks the final count. |

The working budget excludes caller input/output, borrowed dictionaries,
caller-owned skippable capture/event buffers, fixed decoder state, stack tables,
and allocator metadata. Allocator-internal transient remap memory is also
outside requested-byte accounting. This is an allocation contract, not an RSS
measurement. Both default `.block_stream` and explicit `.prevalidated_frame`
use the same allocation budget and cumulative output allowance.
Zstd retains complete-frame structural preflight in the explicit policy, but
compressed-block output uses the resumable literal/sequence state so that a
late entropy error also records any bytes already published. Raw/RLE direct
output remains available. Streamed-block counters count those executed
compressed blocks rather than only blocks entered after caller backpressure.

Initialization allocates nothing. `workingMemoryBytes()` and
`peakWorkingMemoryBytes()` report current and peak live requested allocation.
`reset()` preserves capacity, resets logical counters and errors, and starts
the new peak at still-live retained capacity. `resetWithOptions()` validates
the new options before releasing existing owned buffers and installing a new
budget. A pledge larger than the cumulative output cap is `InvalidBlockPlan`.

With `stop_after_first_frame`, a validated data frame returns `.done` even if
the cumulative pledge spans additional members. `nextStream()` is valid at
that stopped boundary and preserves accepted trailing input, cumulative
input/output, metadata statistics and allocation peak. It returns
`InvalidStreamState` elsewhere. Preserve the unaccepted caller-input suffix
separately from `trailingInput()`. Final `finish()` checks the cumulative pledge;
a short pledge at a stopped boundary can still be completed via `nextStream()`.
Until that explicit continuation, `step()` returns `.done` with zero progress,
including when the caller supplies a following member. Ordinary operation
without the stop option retains automatic concatenated-frame progression.

`WorkingMemoryLimitExceeded` identifies budget rejection; `OutOfMemory`
identifies failure by the backing allocator. Failed `step` calls preserve
actual progress in `snapshot().last_step_progress`, with error input/output
offsets. Parser and allocation failures are sticky: another `step` returns the
same error with zero new progress until reset. Incomplete `finish()` retains
the existing ability to supply more input or output. Frame content-checksum
failure can follow earlier published output.

## zlib dictionary recovery

`ZlibIncrementalDecoder.requiredDictionaryId()` returns the complete required
Adler-32 ID while the decoder waits for a preset dictionary. Partial DICTID
input produces no ID. A missing dictionary reports `NeedDictionary` after
accepting CMF/FLG and DICTID; the compressed payload remains available to resume.

`provideDictionary(bytes)` validates the entire dictionary's Adler-32 before
seeding the raw decoder's history and continuing the already-parsed stream.
A wrong dictionary reports `DictionaryMismatch` and preserves the requested
ID for another attempt. Calling it outside the waiting state reports
`InvalidStreamState`. An explicit matching dictionary can recover a dictionary
set miss. Successful provision clears the recoverable dictionary diagnostic.
Provision copies the needed history suffix during the call and does not retain
the provided slice for future members. Dictionaries configured by the original
initializer remain borrowed configuration for reset and concatenation.
`finish()` while waiting for a complete required ID reports `NeedDictionary`
without sealing input: provide the dictionary, resubmit the unconsumed payload,
then finish normally.

When `step` fails, advance input and output by the snapshot's
`last_step_progress`, then resubmit only the unconsumed input suffix. These
counters include any completed previous member in the same call. Reset starts
a new operation; concatenation retains cumulative output limits.

## Reproduction

The focused LZ4 ReleaseFast suite passes 63 tests, including 16 new limit and
allocation-contract groups. Their matrix covers both input policies, optional
content sizes, checksummed/unchecked blocks, cumulative and zero output caps,
stopped-member pledges, exact working budgets, retained-capacity reset,
validate-before-release reconfiguration, backing OOM and failed-call progress.

Zstd's complete ReleaseFast suite passes 756 tests. Ten new contract groups
cover both policies, unknown content size, output/working boundaries, dictionary
and dictionary-set members, Huffman partial errors, checksum progress, and
every allocation failure in a bounded compressed multi-block fixture. The
failure matrix verifies published prefixes, sticky zero-progress retries,
reset/retry after allocator recovery, and complete allocation cleanup. The
final `finish()` configuration-validation addition passes its focused Debug
group and the final Debug contract aggregate.

| Validation | Result |
| --- | ---: |
| ReleaseFast Zstd/LZ4/zlib-stream suites | 756 + 63 + 29 = 848 passed |
| `test-stream-contracts`: final Debug and post-rebase ReleaseFast | 57 passed in each mode |
| Broader zlib-named Debug regressions | 96 passed |
| Native LZ4/Zstd library probes | 582 passed across four probes |
| Final `zig build check`, including wasm32-wasi | 126 steps succeeded |
| CLI `--help` smoke | Passed |

The native probe dashboard retains the external frame/dictionary checks from
the bounded baseline and passes after the quota and error-progress changes.
Its exact output is saved in
[the native contract JSON](data/native-stream-contracts-x86-20261024.json).

The system Python zlib 1.2.11 differential passes 343 cases from 100 generated
FDICT streams. It checks five dictionaries, levels 0/1/6/9, five strategies and
three caller schedules, plus initializer/set/EOF/reset/concatenation/error
cases. There are 337 in-place dictionary recoveries and 935 wrong-dictionary
rejections, including attempts to supply only the final 32 KiB of a longer
dictionary. Every supplied matching dictionary is copied into temporary memory,
then overwritten and released immediately after provision.

| Failed-call observation | Accepted input bytes | Published output bytes |
| --- | ---: | ---: |
| Later concatenated member needs a dictionary | 81 | 340 |
| Concatenated cumulative output cap | 22 | 1806 |
| Single-stream output cap | 18 | 765 |
| Checksum or trailing-data failure after recovery | 23 | 900 |

These are individual failed-call deltas, not whole-operation counters. Exact
corpus, source, probe and runtime provenance is retained in
[the dictionary recovery JSON](data/zlib-dictionary-resume-x86-20261024.json).

```sh
zig build test-stream-contracts -Doptimize=ReleaseFast
zig build test-zstd test-lz4 test-zlib-stream -Doptimize=ReleaseFast
zig build run-zlib-dictionary-resume-diff -Doptimize=ReleaseFast -- \
  --report /tmp/zlib-dictionary-resume.json
zig build run-native-codec-probes-dashboard -Doptimize=ReleaseFast
zig build check --summary all
```

The dictionary differential generates its compressed members with the system
Python zlib and validates reference round trips before driving the public Zig
decoder. It records compressor/runtime versions and source/probe/corpus hashes.
XZ progressive block decoding, broader real-file allocation/RSS comparisons,
and performance optimization remain subsequent work.
