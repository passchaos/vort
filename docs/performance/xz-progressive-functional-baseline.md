# Progressive XZ and LZMA2 functional baseline

Date: 2026-10-24. Zig 0.16.0, Linux x86-64, Intel Core i7-10700K.
This records streaming progress, resource accounting, format compatibility and
error behavior. It does not establish cross-library throughput or RSS leadership.

## Decoder contracts

Raw LZMA2 now consumes range symbols through a conservative 64-byte input
guard. A non-final incomplete guard does not mutate range/probability state;
the declared chunk end permits the shorter final tail. Each symbol emits at
most one literal/match of 273 bytes into fixed state before caller-output
backpressure. The decoder validates chunk output size, consumed packed size
and zero range code, and does not read a following chunk's control byte to
complete the current chunk.

XZ defaults to `InputPolicy.progressive_block`. Unfiltered LZMA2 output goes
directly into caller buffers; inverse Delta/BCJ filters use small pushes and
their required retained suffixes. Checks accumulate over final filtered output.
A block checksum may fail after earlier bytes were published. Explicit
`.prevalidated_block` uses the same raw core and filters but retains decoded
output until the whole block check succeeds. It grows storage from actual
produced bytes rather than from configured maximum limits.

Index records and Footer parse progressively, including canonical VLI,
record count/sizes, Index/stream CRCs, Backward Size, flags, magic and stream
padding. The older footer retry granularity option remains source-compatible;
the progressive parser does not require speculative whole-Index retries.

| Limit | Scope |
| --- | --- |
| XZ `max_output_len` | Cumulative logical output across automatic and explicitly resumed streams. |
| XZ `max_compressed_block_len` | Cumulative block-body bytes: LZMA2 payload, padding and selected check. |
| XZ `max_decoded_block_len` | Decoded output in one XZ block. |
| XZ `max_compressed_buffer_len` | Combined retained outer input and nested raw compressed storage. |
| XZ `max_decoded_buffer_len` | Live requested allocations for filter suffix/work buffers and publication staging, including an explicitly withheld decoded block. |
| XZ `max_working_memory` | All decoder-owned live requested heap bytes, including nested raw state, filters, records and temporary storage. |
| Raw `max_compressed_buffer_len` | Symbol input guard; the default is 64 bytes, and stored chunks also support zero. |
| Raw `max_working_memory` | Raw input, dictionary and probability allocations. |

The allocation budgets exclude caller buffers, fixed state, stack staging,
allocator bookkeeping and allocator-internal remap transients. They are not
RSS measurements. The XZ decoded-buffer cap defaults to unlimited while the
default progressive execution window remains structurally small; finite
caller caps apply to both policies. A decoded/filter cap failure is
`OutputLimitExceeded`, outer budget denial is `WorkingMemoryLimitExceeded`,
and backing allocation failure remains `OutOfMemory`.

Initialization allocates nothing. `reset()` retains reusable capacity and
starts a new logical operation; a fresh peak includes still-live capacity.
Successful `resetWithOptions()` releases old owned storage through its old
budget before installing new options. Raw returns configuration errors directly.
XZ preserves its existing void signature and records an invalid configuration
for the following `step`; `Options.validate()` provides an immediate check.

`last_step_progress` records input accepted and output published even when a
call fails, alongside cumulative detection offsets. Parser/allocation failures
are sticky. A stopped XZ stream retains accepted suffix bytes and caller-owned
unconsumed input separately; `nextStream()` clears member state while preserving
cumulative output limits, counters and working peak. An exact output pledge
may span several stopped streams. A short pledge after finishing a stopped
member can still be completed through explicit continuation.

## Shared correctness fixes

One-shot XZ/inspection and known/unknown-size 7z payload allocation now use the
same raw LZMA2 core. Actual dictionary properties constrain copy distances,
and range-code termination validates consistently. The former arena, duplicate
output copy and unrestricted accumulation helper are removed from those paths.

Shared circular LZMA history now uses conditional subtraction for indices,
avoiding intermediate overflow at the maximum declared window without needing
to allocate that window. The implementation is isolated in a small history
module. Tests compare wrap/overlap behavior with linear output, and execute
maximum-window sparse storage on native and real x86 32-bit builds. Dictionary
growth and cumulative input reject integer overflow before new I/O.

Legal Delta distance 256 uses wrapping eight-bit indexing in both one-shot
and incremental filters. XZ applies inverse filter stages in reverse header
order, preserving the existing decode-order API used by 7z.

## Validation evidence

The complete ReleaseFast XZ/LZMA2 suite passes 76 tests. A separate 76-test
consumer suite exercises 7z LZMA2/BCJ2 and Delta/BCJ chains, Apple PBZX and
Dolphin WIA/RVZ. The final Debug and post-rebase ReleaseFast progressive
aggregates each pass 29 tests, including compatibility, resources, movement
and raw symbol transitions.
Shared history tests pass 3/3 natively and 3/3 on real x86 Linux; LZMA-Alone
and MicroLZMA public decoder smoke tests also pass.
The final `zig build check` succeeds in all 127 steps, including wasm32-wasi.
The CLI `--help` smoke also succeeds.
The existing CLI differential passes in Debug: five bidirectional cases, both
writer modes, multi-block streams, all six older BCJ filters plus Delta, and
modern ARM64/RISC-V cases through 7-Zip 26.02. Library tests and the independent
progressive probe use ReleaseFast; this functional CLI check uses Debug.

The independent differential passes 431 cases over 133 corpora: 268 raw and
163 XZ schedules/cases, all 75 legal lc/lp/pb combinations, eight BCJ filters,
Delta and three compound chains, every LZMA2 reset mode, stored/compressed mixed
chunks, four check types, multi-block/concatenated streams and malformed input.
It performs 150 legal XZ one-shot comparisons, six exact memory checks, 45
allocation-failure injections and 18 expected rejection cases. References are
Python/liblzma and XZ Utils 5.2.5 plus 7-Zip 26.02 for newer filter IDs.

| Successful campaign maximum | Compressed live / capacity | Decoded scratch | Requested working peak |
| --- | ---: | ---: | ---: |
| Raw LZMA2 | 64 / 64 | 273 fixed bytes | 77888 bytes |
| Default progressive XZ | 64 / 80 | 2351 bytes | 78561 bytes |

These values describe this corpus and its schedules. Dictionary size and
record count remain caller-limited; the table is not a general constant-memory
or cross-library memory comparison. The 70800-byte explicit prevalidated case
retains 131072 bytes of decoded capacity and peaks at 209116 requested working
bytes, growing from actual output rather than an unlimited ceiling.

The 70800-byte text case publishes raw output at input offset 106 while its
compressed chunk ends at 144; XZ publishes at offset 130 before chunk end 168.
The 2 MiB case publishes raw output at offset 76 before chunk end 371, and XZ
at 100 before chunk end 395. Default checksum failure records 12 input bytes
and 27 published output bytes in the failing call; explicit prevalidation
reports zero published bytes for that failure.

Exact commands, reference/compiler versions, corpus/probe/output hashes and
43 current source hashes are retained in
[the differential JSON](data/xz-progressive-x86-20261024.json).

## Reproduction

```sh
zig test src/lzma/history.zig
zig test src/lzma/history.zig -target x86-linux
zig build test-xz test-xz-progressive -Doptimize=ReleaseFast
zig build test-xz-consumers -Doptimize=ReleaseFast
zig build run-xz-progressive-diff -Doptimize=ReleaseFast -- \
  --seven-zip /path/to/7zz --report /tmp/xz-progressive.json
zig build run-xz-diff -- --modern-seven-zip /path/to/7zz
zig build check --summary all
```

Independent samples come from system Python/liblzma and modern 7-Zip, including
ARM64 and RISC-V filters unsupported by the older Python binding. The campaign
records reference/compiler versions, exact commands and source/probe/corpus
hashes. Larger real-file performance comparisons, optimal compression parsing
and remaining cross-codec resource/API parity continue after this functional
increment.
