# Bounded parallel XZ block encoding

Date: 2026-10-26. Bounded persistent-worker encoding is implemented for the XZ
one-shot APIs. Completed functional checks and their separate source epochs are
recorded in the [functional baseline](../performance/xz-parallel-functional-baseline.md);
the complete XZ family/consumer suites, CLI help and final build checks pass.

`XzEncodeOptions.parallel` is optional and defaults to null, preserving the
serial encoder. An explicit `XzParallelOptions` request borrows the caller's
`std.Io` implementation for worker coordination during the call. Default limits
are two workers, four in-flight blocks, 4 MiB of in-flight plaintext and 256 MiB
of operation-owned requested heap.

The caller's `std.Io` must safely support mutex/condition/futex coordination from
multiple OS workers in this call and remain alive until return. The allocator
context, input, filter descriptors and profile destinations must also remain
valid until return; the caller must not mutate them concurrently outside the
operation. An arbitrary `std.Io` implementation is not necessarily suitable for
parallel execution. Defined serial fallbacks do not use coordination I/O and
can use `std.Io.failing`.

```zig
var profile: vort.XzParallelProfile = .{};
const encoded = try vort.encodeXzAlloc(allocator, input, .{
    .block_size = 1024 * 1024,
    .parallel = .{
        .io = io,
        .worker_count = 2,
        .max_inflight_blocks = 4,
        .max_inflight_bytes = 4 * 1024 * 1024,
        .max_working_memory = 256 * 1024 * 1024,
        .profile = &profile,
    },
});
defer allocator.free(encoded);
```

## Admission and scheduling

Worker count accepts 1...64. Zero workers, more than 64 workers, or zero
in-flight block/byte limits return `InvalidBlockPlan`. A zero working-memory
quota is a resource limit, not an invalid parameter. If an actual plaintext
block exceeds `max_inflight_bytes`, the call returns
`WorkingMemoryLimitExceeded` before allocating jobs or publishing output. It
does not shrink block boundaries to fit the quota.

In-flight plaintext is borrowed from the input and charged by its logical byte
length. Queued, active and completed blocks waiting for their original output
order remain charged until ordered publication into internal staging. This
limit is distinct from codec heap use. A persistent bounded worker pool processes
independent blocks through reusable ring slots; it does not start a new thread
for every block. Header, ordered blocks, Index and Footer retain the normal XZ
format.

The parallel target condition is a non-single-threaded build on Linux, Windows
or a `std.Thread.use_pthreads` target. Unsupported targets, empty input and an
effective worker count of one use the same-options serial fallback while still
obeying explicit quotas. This includes one-worker requests, single-block input
and in-flight caps that admit only one job. The fallback does not silently
recover from a failed thread spawn: every started thread is joined on all
completion/error paths and the spawn error propagates.

## Memory and publication

The operation heap ledger covers temporary output staging, block records, filter
copies, ring/worker metadata, thread bookkeeping allocated through the supplied
allocator and active codec scratch. Caller-owned final destination allocations,
native OS thread stacks, OS/Io runtime private overhead and backing-allocator
private bookkeeping are excluded. In particular, an Io runtime allocation that
does not pass through the supplied operation allocator is outside this ledger.
The caller allocator is serialized through the shared budget during worker
operations; it need not independently support concurrent use inside this call.

Each OS worker reserves a fixed 2 MiB stack. This reservation is separate from
the heap quota and is not a measured full-stack high-water or RSS figure.
The complete one-shot output is staged before transactional caller publication,
so bounded workers/in-flight input do not make the operation constant-memory
with respect to total input size. Index records and staged output still grow.

Alloc, Append and Into use the same pipeline. Workers finish and join before
caller output is copied or grown. Into checks the caller buffer's length and
copies directly from the single budget-owned complete staging buffer; it does
not allocate another complete temporary wire outside the quota. Input aliases
into destination storage remain valid until encoding is complete; on failure,
the caller's destination retains its established publication contract. Internal
profile progress may describe work or staging completed before that failed
final publication.

## Profiles and scope

`XzParallelProfile` records `workers_started`, `peak_active_workers`,
`peak_inflight_blocks`, `peak_inflight_bytes`, `completed_blocks`,
`published_blocks`, `peak_requested_bytes`, `live_requested_bytes` and
`serial_fallback`. Counts use `usize`. Published blocks mean blocks appended in
order to internal output/Index staging, not bytes already committed to caller
output. Heap live/peak is requested operation storage, not resident memory.

Matcher/parser work is gathered into worker-local profiles and merged in input
order using existing saturating sums/maxima. Workers do not update the shared
matcher/parser work destination directly; parallel activity counters are
synchronized separately. Completion/activity peaks may vary with scheduling;
they are observations, not deterministic performance promises.

The default encoder preserves standard block headers without declared compressed
and uncompressed block sizes. That layout is valid XZ and preserves serial wire
parity. liblzma 5.8.4's multithreaded decoder processes those streams in serial
direct mode; Index sizes at the end do not replace the required header fields.
Both declared sizes and multiple blocks are necessary for its parallel block
decoding, while thread limits, memory limits, filter work and I/O can still
restrict activity. Parallel encoding therefore does not establish full liblzma
MT feature parity or parallel reference decoding.

The subsequent [Block Header size option](xz-block-sizes.md) is independently
validated. `include_block_sizes = true` can be combined with `parallel`
and uses the same sized block writer as serial one-shot and incremental encoding.
Its temporary complete LZMA2 payload is charged to this operation's shared heap
budget. False remains the default. Declared sizes remove the missing-header
condition. [New reference activity evidence](../performance/xz-block-sizes-functional-baseline.md)
observes nine completed jobs on three distinct decoder workers and a peak of
three active decode calls for a specific native/x86 multiblock case; unsized and
low-threading-memory controls use direct mode. These test-only reference
observations do not alter the earlier parallel baseline's source epoch or
promise three workers for arbitrary streams.

The incremental XZ encoder remains serial and gains no parallel control in this
increment. Parallel incremental publication or further XZ ratio/matcher quality
work needs a fresh behavior/ownership review. No throughput or industry-best
claim follows from enabling workers. Functional worker activity, byte parity,
reference interoperability and real Wasm fallback have been verified within the
baseline's bounded matrices; no throughput or encoder RSS measurement was run.
