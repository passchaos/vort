# Brotli total encoding memory

The implementation and its validation are recorded in the
[total-memory baseline](../performance/brotli-total-memory-functional-baseline.md).
The existing HQ workspace budget remains independently available.

`PlannedEncodeOptions` and `PlannedStreamChunksOptions` expose optional
`max_total_working_memory` and `memory_profile` fields. They apply to legacy
levels, qualities 0...11, and explicit HQ encoding. The package root exports
`BrotliEncodeMemoryProfile`. A fresh encoder with a null limit and null profile
preserves the original allocation path. A profile without a limit tracks an
unlimited operation and must preserve its complete output bytes. An encoder
that already enabled tracking retains its allocator control while owned
storage remains live, even when a later operation disables the cap and profile.

## Counted storage

The total limit bounds live requested heap bytes used by the encoding operation:
its stable budget control, input and pending-output buffers, retained ordinary
history, dictionary indices, parser workspaces, HQ models and matcher forks,
candidate artifacts, alias snapshots and complete-stream comparisons. The
complete q10 wire remains counted while q11 and eligible legacy candidates are
built. Sharing the allocator between those phases preserves one limit.

The limit also includes pre-existing encoder-owned capacity when a reusable or
incremental encoder first enables tracking. A new cap below that live storage
is rejected before resetting the stream or replacing the caller's options.
Fixed state, stack arrays, borrowed input/dictionary bytes and the caller's
pre-existing output allocation are excluded. Newly requested append replacement
storage is counted until successful publication transfers it to the caller.

Allocator bookkeeping, operating-system page rounding, internal transients of
a backing allocator's successful remap, and process RSS are outside requested
byte accounting. A moving fallback that performs a separate allocation before
freeing the old buffer counts both live allocations. Reserved quota for a
different allocator is checked before its allocation; only allocation success
adds those bytes to the reported heap peak.

## Ownership and failures

One stable heap control backs movable ownership leases. Nested encoders share
that control instead of independently resetting the cap. The generic stream
layer and retained codec owners use the same allocator, with each actual
allocation counted once even when an HQ workspace allocator also tracks it.
Retained matchers continue to refer to valid allocator state after their parent
encoder moves or a call finishes.

A successfully returned allocating result can be freed through the allocator
supplied by the caller. Transfer removes its charge after the operation, without
freeing the result. When reusable storage and returned output use different
allocators, their simultaneous allocations share the same quota. A failed
transfer or duplicate releases temporary storage and preserves its owners.

Quota denial returns `WorkingMemoryLimitExceeded`; a real backing allocation
failure returns `OutOfMemory`; checked size arithmetic reports
`IntegerOverflow`. A quota denial cannot silently skip an encoding candidate or
change the operation into a successful stored fallback. Incremental failures
retain actual accepted input and delivered output progress. Retry, reset and
`nextStream` follow the existing stream contracts.

## Profiles

`EncodeMemoryProfile` reports `available`, `peak_requested_bytes`,
`live_requested_bytes` and the current optional `limit`. The peak is a maximum,
while live bytes describe the latest state. Overlapping encoder lifetimes in
one coordinated operation share the budget; summing individual peaks does not
establish their combined peak. The mutable control and profile are serialized
by the operation rather than being a thread-safe global counter.

An incremental profile must remain alive while the encoder can use it. A
reusable operation detaches a call-scoped profile when the call ends, while its
tracked retained storage keeps stable allocator state. Clearing a profile does
not free retained storage. A later observation begins with the current live
bytes. HQ work counters and the HQ workspace cap continue to describe their
original narrower scope.

## Validation targets

The dedicated `test-br-total-memory` target combines independent requested-heap
tracking with budget, ownership and transaction tests. The CLI uses
`--max-total-memory` and `--memory-profile`, independently of `--hq-memory` and
`--profile`. `test-br-total-memory-cli` and `run-br-total-memory-diff` exercise
the same public library APIs and preserve existing outputs on failure.

Acceptance requires representative old complete wires, profile-only byte
identity, exact/one-byte-below quotas, real OOM retries, warm storage adoption,
different return allocators, output and dictionary aliases, and zero remaining
owned heap after cleanup. Validation durations and requested peaks are
functional evidence, not competitor throughput or RSS claims.
