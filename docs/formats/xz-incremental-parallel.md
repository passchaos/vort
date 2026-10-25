# Persistent parallel incremental XZ encoding

Date: 2026-10-26. The persistent owner/queue implementation has completed native,
actual x86, reference, real Wasm fallback and final family/build validation. Exact
counts, observed worker/ownership evidence and corrected initial failures are
recorded in the [functional baseline](../performance/xz-incremental-parallel-functional-baseline.md).
No throughput or RSS result is assigned.

`XzIncrementalEncoder.Options.parallel: ?XzParallelOptions = null` preserves the
existing serial encoder by default. An explicit request uses the same worker,
in-flight and requested-heap options as [one-shot parallel encoding](xz-parallel.md),
but keeps a stable heap owner and worker queue across `step()` calls. Public
`XzIncrementalParallelSnapshot` exposes the persistent operation's observations.

```zig
var profile: vort.XzParallelProfile = .{};
var encoder = try vort.XzIncrementalEncoder.initWithOptions(allocator, .{
    .block_size = 1024 * 1024,
    .include_block_sizes = true,
    .parallel = .{
        .io = io,
        .worker_count = 2,
        .max_inflight_blocks = 4,
        .max_inflight_bytes = 4 * 1024 * 1024,
        .max_working_memory = 256 * 1024 * 1024,
        .profile = &profile,
    },
});
defer encoder.deinit();
```

`include_block_sizes` remains independent and false by default. Stored/compressed
payloads, filters, checks, presets and matcher/parser settings use the same block
writer as serial encoding; the worker mode does not lower search or level
settings. No incremental CLI thread flag is added in this library/ZIP increment.

## Ownership and pipeline

Owner, Queue and allocator slots remain at stable heap addresses. Workers retain
queue/job storage, never a pointer to the movable public Encoder value or caller
profile destinations. The encoder can transfer its unique ownership to a new
value between calls without invalidating active worker addresses.

The complete 12-byte Stream Header must reach caller output before worker startup
or input acceptance. A first zero-output step retains that header and reports
zero input accepted; it does not launch workers. `parallel = null` keeps the old
serial startup/backpressure and retry behavior.

Each reported accepted input prefix is copied into operation-owned job storage.
The caller can reuse those accepted bytes before the next step. In-flight block
credit begins with the first byte of a partial block. In-flight bytes include
partial, queued, active, completed and partly delivered blocks, and remain
charged until the final byte of that Block reaches caller output. Internal
pending bytes and Index publication do not release the credit.

An undrained oldest block can coexist with input acceptance into later jobs,
until block/byte credits fill. Blocks encode independently and publish/deliver
in input order. The API keeps the existing `need_input`, `need_output` and `done`
progress contract; worker completion can be waited for inside a step rather than
introducing a new poll status.

The input-reuse promise applies to the reported accepted prefix. This increment
adds no same-call input/output overlap guarantee. One-shot/direct-block alias
support and its earlier validation epochs remain separate.

Caller I/O must support safe OS-worker mutex/condition coordination. Its context,
backing allocator and borrowed filter descriptors must remain valid until the
workers join. Public profile storage remains valid through encoder deinit.
Only public operations publish caller profiles, so callers may read them between
steps; worker threads update private counters/work only. There is no setter to
replace active profile storage. Calls on one encoder remain externally serialized.
Unsupported/single-worker effective configurations use synchronous fallback with
the same ownership, credit and heap accounting; spawn failure does not select
an implicit fallback.

## Limits and errors

A byte cap smaller than `block_size` is allowed for an unknown-length stream:
a smaller explicit flush/final block can fit. If a partial block exhausts the
cap and no submitted job can release credit, offering more input returns
recoverable `WorkingMemoryLimitExceeded`. It preserves the partial block for
explicit flush/finish; it does not invent a smaller block boundary. If submitted
jobs exist, caller output can drain them and restore credit.

Input and pledged-size checks occur before accepting each offered prefix.
`max_block_count` admission includes a partial accepted block. Header, complete
Block and Index/Footer are each checked as a complete logical publication unit
against `max_pending_output_len`, rather than only counting the currently
undrained suffix. These admission limits can be adjusted through the encoder's
existing options before retry; codec/worker configuration changes use next-stream
options.

| Failure | State and progress contract |
| --- | --- |
| Input/pledge/block-count admission, or a partial-block byte-credit limit | Recoverable; accepted/delivered progress already committed is retained |
| Complete front unit exceeds `max_pending_output_len` | Recoverable; raising the limit can publish an already completed job without encoding it again |
| Worker codec, spawn or requested-heap failure | Sticky; stop/join all started workers and retain the precise failing step's accepted/delivered byte progress |
| Step after a sticky failure | Returns the same error with zero new progress until reset |

After any failed step, read `failedProgress()` before another step to account for
the accepted input and output bytes already delivered. The parallel snapshot
also reports `last_step_progress`, `last_error` and sticky `failed` state. A
recoverable last error may be present while `failed` is false. Serial-null mode
returns no added failed-progress bridge and keeps its prior contract. Streaming
errors cannot undo bytes delivered by earlier calls.

## Heap, reset and stream changes

The explicit parallel heap cap includes stable control/owner/queue allocations,
actual owned plaintext capacities, job output, codec/filter/sized-payload scratch,
front staging and Index records. Retained free-slot buffers remain charged.
Caller buffers, OS worker stack mappings and backing/OS/Io private overhead are
outside requested heap. The backing allocator is serialized by the shared ledger
during operation allocations; worker-local failure slots distinguish quota denial
from backing refusal. Fixed worker stacks remain 2 MiB reservations, not measured
stack use or RSS.

`done` joins workers and ends logical in-flight work, but retains buffers and
control state; it does not imply zero live requested heap. Infallible `reset()`
joins work, clears sticky/logical state with the same settings and retains
capacities. `deinit()` joins and frees operation storage, publishing final live
heap zero. Index storage grows with the stream's block count and is bounded by
block-count and heap limits; this is not constant whole-stream memory for an
unbounded number of blocks.

At a completed stream boundary, `nextStream`/`nextStreamExactSize` support serial
null to parallel, parallel to a new parallel configuration, and parallel back
to null. Activation seeds the budget with all retained serial capacities before
adopting them. Configuration/metadata reservations commit transactionally; an
insufficient new heap limit leaves the previous done state, storage and settings
intact. Returning to serial disowns retained storage from the parallel ledger
without claiming that the retained physical buffers have been freed.

## Observations and ZIP integration

The public `encoder.snapshot().parallel` fields distinguish these stages:

| Fields | Meaning |
| --- | --- |
| `enabled`, `started`, `serial_fallback`, `workers_started`, `workers_live`, `peak_active_workers` | Configuration/startup and actual worker observations |
| `queued_blocks`, `active_blocks`, `completed_waiting_blocks`, `delivering_block` | Job state while order and caller output are pending |
| `partial_input_bytes`, `owned_input_bytes`, `inflight_blocks`, `inflight_bytes` | Accepted owned input and credit still held |
| `completed_output_bytes`, `delivering_output_bytes` | Completed queued bytes and undelivered front bytes |
| `accepted_blocks`, `encoded_blocks`, `published_blocks`, `delivered_blocks` | Current-stream first-byte admission, completed codec work, ordered Index publication and final Block-byte delivery |
| `retained_input_capacity`, `retained_job_output_capacity`, `retained_front_capacity`, `retained_index_capacity` | Retained allocation bytes, including Index record storage, distinct from logical live bytes |
| `live_requested_bytes`, `peak_requested_bytes`, `control_bytes` | Requested allocation accounting, not RSS |
| `failed`, `last_error`, `last_step_progress` | Sticky state and the most recent step's committed progress |

Existing `XzParallelProfile.published_blocks` still means internal ordered Index
publication; caller delivery is exposed separately by the persistent snapshot.
Profile/snapshot observations can lag worker scheduling until a public touchpoint
and are not throughput or deterministic activity guarantees.

ZIP incremental XZ options inherit the new parallel option. Its codec failure
bridge reports only the most recent parallel failing step, allowing the ZIP
writer to account accepted input CRC/size and emitted encryption/output bytes
once before propagating the error. Null serial mode supplies no new bridge.
Independent contracts cover ZIP failure/progress alongside the core/reference
and platform gates. Native/x86 external matrices each pass 84/84, observe an
encoder activity peak of three, and perform two actual value moves with queued
or active jobs. These are scoped functional observations rather than a promise
of identical scheduling or industry-leading performance.
