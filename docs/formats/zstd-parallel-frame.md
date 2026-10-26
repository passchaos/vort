# Explicit parallel jobs in one Zstandard frame

Date: 2026-10-26. V1.B API and bounded job/coordinator implementation have
completed native/x86 codec/root, independent reference, real Wasm fallback and
final build validation. Exact counts and corrected failures are recorded in the
[functional baseline](../performance/zstd-parallel-frame-functional-baseline.md).

The explicit native parallel API compresses one standard or magicless Zstandard
frame from bounded jobs. `zstd.ParallelOptions`/`ParallelProfile` and their root
`ZstdParallelOptions`/`ZstdParallelProfile` aliases describe this mode. Existing
serial native entrypoints keep their policy; the new entrypoints are explicit.

| Entry point | Contract |
| --- | --- |
| `encodeNativeParallelFrameAlloc(a, input, opts, parallel)` | Returns the allocated complete frame |
| `encodeNativeParallelFrameAppend(a, out, input, opts, parallel)` | Transactionally appends one frame; returns newly added bytes |
| `encodeNativeParallelFrameIntoSlice(a, input, opts, output, parallel)` | Publishes into caller storage; returns frame bytes written |
| `encodedNativeParallelFrameBound(input_len, opts, parallel)` | Checked raw-frame upper bound for this mode |

`opts` is `NativeFrameOptions`. Dictionary variants retain the corresponding
names `WithDictionaryAlloc`, `AppendWithDictionary`, `IntoSliceWithDictionary`
and `BoundWithDictionary`: insert the dictionary immediately after `opts`.
Dictionary-set variants use `WithDictionarySet` and insert `set, id` after
`opts`. Into keeps `output` after those dictionary arguments; `parallel` is
always the last argument. Root function aliases expose the same surfaces.

```zig
var profile: vort.zstd.ParallelProfile = .{};
const encoded = try vort.zstd.encodeNativeParallelFrameAlloc(
    allocator,
    input,
    .{ .content_checksum = true },
    .{
        .io = io,
        .worker_count = 2,
        .job_size = 1024 * 1024,
        .max_inflight_jobs = 4,
        .max_inflight_bytes = 4 * 1024 * 1024,
        .max_working_memory = 256 * 1024 * 1024,
        .profile = &profile,
    },
);
defer allocator.free(encoded);
```

## Jobs and admission

`io` is required. Defaults are two workers, 1 MiB requested job size, four
in-flight jobs, 4 MiB in-flight input and 256 MiB operation-requested heap.
Worker count is legal from 1 through 64. Zero workers, job size or job/byte
credits, and more than 64 workers reject with `InvalidBlockPlan`. A zero heap
quota is a limiting quota, not an invalid parameter.

Requested `job_size` rounds upward to a multiple of the effective native block
size with checked arithmetic. Each actual job is the configured span or its
short final tail. If the first actual job exceeds `max_inflight_bytes`, reject
before allocating the queue or starting workers; do not shrink jobs to fit.
Ceiling slot geometry permits a full job and short tail to coexist when their
actual byte sum fits. Submission strictly checks both free slots and logical
in-flight bytes, including completed jobs waiting for ordered re-emission.

The one-shot queue, slots and worker allocator contexts remain at stable heap
addresses. It computes spans as it submits them rather than allocating a
descriptor for every input job. It borrows immutable input and dictionaries
until return. Caller I/O must safely coordinate OS workers; its context, backing
allocator, borrowed data and profile storage remain valid through the call.

Unsupported targets, one requested/effective worker or one usable slot use
synchronous encoding with the same job geometry and wire policy. No OS worker
starts in that path, and started/live/peak-active-worker observations are zero.
`effective_workers` may still be one for the synchronous codec lane.
A spawn failure stops/joins all started workers and propagates the error rather
than silently selecting a new mode.

## One frame and stateful re-emission

The result has one frame header, its selected content size/window/dictionary ID,
one global last Block and one optional content checksum. Magicless removes only
the normal frame magic. Neither job boundaries nor worker count create extra
frames or a seek table.

Each worker starts its job state from the supplied dictionary while seeing the
correct full-input history allowed by the global window. It honors the native
strategy/candidate/search-budget settings; it does not substitute a lower level
or reduce those settings for worker mode. Its job priors are independently
initialized, so this explicit mode is not a promise of the legacy serial
encoder's complete wire or libzstd's MT algorithm/ratio/speed.

The coordinator interprets each completed job with its own original-job decoder
state to recover physical match distances and validate plaintext/Block extents.
It then re-emits against the actual preceding global-frame state, including
recent offsets, Huffman reuse and FSE tables. Raw, RLE and Huffman-only blocks
use the appropriate paths. Blindly copying independently initialized compressed
blocks would break these dependencies; jobs are not concatenated mini-frames.

Re-emission retains the checked raw upper bound: selected output does not exceed
the corresponding raw framing bound. One planned input block may contain several
actual raw/RLE Blocks, so wire-block counts come from real emitted headers,
not a ceiling division of input spans.

## Heap, publication and profiles

The effective whole-operation requested-heap cap is the minimum of
`parallel.max_working_memory` and a supplied
`NativeFrameOptions.max_total_working_memory`. The stable control/queue/worker
metadata, job outputs, codec/history scratch, coordinator decode/re-encode
storage, complete frame staging and publication replacement storage are charged.
Caller-owned buffers, OS stacks and private Io/backing/OS overhead are excluded.
Worker stacks reserve 2 MiB each; that reservation is not measured stack use/RSS.

Completed job Blocks are validated and re-emitted into a complete staged frame;
all jobs join before caller publication. The wrapper does not perform another
complete-frame decode/preflight on every call. Alloc transfers ownership, Append
replaces/grows caller storage transactionally, and Into checks length before
copying. Input aliases into
destination allocation remain valid until workers have finished; short output,
quota, backing allocation and worker failures preserve caller publication.
Caller-returned output is outside operation heap after ownership transfer.
Complete staging still grows with output size; bounded jobs do not mean constant
whole-input memory or a persistent incremental stream.

`ParallelProfile` records availability/fallback, configured/effective workers,
started/live/peak active OS workers, effective job size/count, encoded/published
jobs and Blocks, peak in-flight jobs/bytes, retained/peak job-output capacity and
requested live/peak heap. Logical credits, capacities and requested heap are
different observations. `peak_job_output_capacity` is the observed sum of
visible completed/free-slot output capacities; active outputs temporarily held
by workers are not included in that observation. Requested-heap peak still
accounts for all tracked allocations. Encoded Block counts describe actual
completed job wire.
`published_jobs`/`published_blocks` are ordered internal frame-staging counters
from queue publication, not proof that caller output has been committed. They
can remain nonzero when final Into publication returns `OutputTooSmall`.

Worker work profiles are private. Coordinator merging excludes workers' original
emitted-output counts. The separate caller `EncoderControlProfile.emitted()`
statistics describe actual coordinator output and merge only after successful
destination publication; a failed destination adds no emitted-output counters.
Work observations and `ParallelProfile` diagnostics may still describe completed
internal work on failure. Function success proves caller frame publication.
Public caller profiles synchronize at final/failure touchpoints, with no setter
replacing active destinations. Scheduling peaks are observations, not
deterministic concurrency or throughput guarantees.

Native Debug/ReleaseFast and actual x86 ReleaseFast each pass 122/122 filtered
executions. Each external native/x86 campaign passes 111/111, including 92 complete
target frames and expected encoder/dictionary refusals. They observe target peak
active workers three and independently parse a 1248-sequence Block. Same-geometry
worker-one output, full reference content and exact consumption are checked.
These are functional observations, not a libzstd MT performance/algorithm claim.

This increment provides one-shot native single-frame jobs. Its subsequent
[persistent incremental class](zstd-incremental-parallel.md) is under independent
validation, with owned prefix/plaintext, full-job sealing, one front job and
final-byte delivery credit. [New runtime evidence](../performance/zstd-incremental-parallel-functional-baseline.md)
passes native Debug/ReleaseFast, synchronous and Wasm32 execution, a 171-case
fixed-libzstd differential and the earlier 92 saved one-shot wires.
CLI worker flags are not added. Existing candidate
MT and independent seekable-frame MT remain separate capabilities. Real Wasm
fallback and full native Zstd 1128/1128 validation retain their own scopes in the
baseline. No throughput, ratio or RSS leadership follows from these gates.
