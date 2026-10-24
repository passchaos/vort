# Brotli stored encoding memory controls

`StoredStreamOptions` exposes `max_total_working_memory: ?usize = null` and
`memory_profile: ?*EncodeMemoryProfile = null`, matching the planned encoder's
requested-heap policy. The options reach contiguous and chunked allocating,
append, caller-buffer, reusable and incremental stored encoding.

The budget counts actual encoder-owned requested bytes, including its stable
control, retained allocation capacities, temporary alias snapshots and output
replacement buffers while they are owned by the encoder. Borrowed input and
metadata, caller output already owned outside the authority, allocator
bookkeeping and unobservable OS/remap overhead are excluded. It is not RSS.

## Allocation and ownership

An independent caller-buffer operation with nonoverlapping input and metadata
needs no heap. A zero budget therefore remains valid for that path, and a
requested profile reports an available zero-byte measurement. Actual alias
snapshots require admission before caller output is changed. A reusable encoder
may already own retained scratch; its total budget includes that full capacity
and any required control even when the current output would fit without growth.

Allocating results remain charged until ownership transfers to the original
backing allocator. After a standalone allocating function transfers its output
and cleans up, its profile reports no encoder-owned live allocations. A
reusable receiver may retain its authority even without scratch payload, so its
last call-scoped live measurement can include that control. Returning an allocation to the same
tracked caller keeps its existing charge. A caller-owned append prefix is not
adopted merely because the encoder appends to it; newly requested replacement
storage is charged until publication and handoff.

Reusable scratch operations retain their allocator authority while owned
allocations exist. Adoption uses allocation capacity, not logical wire length.
Borrowed source bytes, metadata and chunk descriptors that overlap storage
about to be overwritten are protected before mutation. Failure leaves the
previous successful scratch, caller output and committed ownership intact.

Profiles supplied to complete-input and reusable calls are detached before the
call returns; the caller may then let their storage expire. Incremental options
retain their caller-owned profile for the configured encoder lifetime. A reset
that reuses those options continues that lifetime. Successful reconfiguration
replaces the old borrowed profile; a rejected change preserves the prior policy.
Profile peaks accumulate until the caller resets the profile. A reusable call's
last live value may include retained scratch or control; its later deinit must not write
to the expired call-scoped profile. Use the encoder's current memory snapshot
and independent allocator accounting to observe subsequent lifetime cleanup.

## Incremental transactions

The incremental stored encoder uses one stable authority for pending/plain
capacities and codec allocations. Retained bytes are adopted once. Window and
metadata validation precede authority creation and input/output progress.
`flush`, metadata, finalization and continued streams use the same policy.

A failed bit-writer call restores the original pending length and mutable last
byte, so retrying after increasing a limit or recovering allocation cannot
duplicate a partial prefix. Previously returned bytes and accepted input retain
their actual progress; pending input is resumed with the existing step API.
Reset and `nextStream` do not discard accounting for retained capacities.

Nested operations inherit the same allocator authority rather than installing
a second limit or reseeding already charged bytes. Only the operation
coordinator begins a new error-classification interval. A quota refusal remains
visible through later successful allocations or reservations in that interval,
keeping `WorkingMemoryLimitExceeded` distinct from a fresh backing
`OutOfMemory`. Independent backing failures are classified in a fresh interval.

This Brotli authority has a single-owner coordination contract. Ownership
references support nested lifetimes; they do not make concurrent mutation of a
shared encoder or authority thread-safe.

## Defaults and validation

Null options retain the existing stored format, default wire and allocation
paths. Standard and explicit Large Window validation is unchanged. Resource
admission does not add compression strategies or relax format limits.

Independent tests compare old wire from an archived revision, actual requested
heap from a separate allocator, exact/B−1/zero budgets, OOM cleanup, overlapping
borrows, retained capacity, profile lifetimes and incremental retry. Native,
32-bit and WebAssembly/reference gates provide separate evidence. Functional
allocation counts and durations do not establish industry-wide memory or
throughput leadership.
