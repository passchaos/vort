# Brotli one-shot decode requested-heap contract

`br.DecodeOptions` (also `vort.BrotliDecodeOptions`) accepts
`max_total_working_memory: ?usize` and `memory_profile: ?*DecodeMemoryProfile`.
The profile type is exported as `br.DecodeMemoryProfile` and
`vort.BrotliDecodeMemoryProfile`. Both fields default to null. Existing default
wire validation, decoded bytes, stream boundaries and output limits are retained.
This is an opt-in functional resource contract; it establishes no throughput,
ratio or reference-implementation performance claim.

## Scope and ownership

The cap limits simultaneously live allocator-requested heap bytes for one whole
owned/full/prefix/exact/chunked decode, append, or allocating-summary call. It
includes owned output capacity, spare capacity, old/new allocations during
moving growth, allocating summary history, and the shared ledger's control
allocation. Full append also charges input and shared-dictionary backing snapshots when
those borrows alias any part of the destination allocation, including spare
capacity. RAW descriptors and the parsed serialized view use automatic storage;
aliased RAW bytes and serialized encoded bytes use the operation allocator.
Legacy full append uses the same protection when aliases are present. The
profile observes that same ledger, with `available`, `peak_requested_bytes`,
`live_requested_bytes`, and `limit` fields. Reset a reused profile when a new
independent peak is desired; observations otherwise preserve the maximum peak.

The cap excludes borrowed input and dictionaries, caller-provided into buffers,
compressed chunk-join scratch and summary history, automatic stack storage,
allocator bookkeeping, process RSS, and backing allocator remap transients.
Public preflight failures, including invalid dictionaries and insufficient
chunk-join scratch, report an available zero-heap observation without creating
metadata. Allocator-based children leave an inherited owner profile intact.

Brotli entropy/Huffman tables and their lookup arrays currently use automatic
storage, so they contribute no requested heap. A future heap workspace must use
the same operation allocator to remain inside this contract.

A successful owned return transfers its exact output allocation to the supplied
caller allocator. The caller frees it with that allocator, or calls the owned
prefix result's `deinit`. The operation profile returns to zero after transfer
and cleanup. If the caller allocator already belongs to an outer shared ledger,
the result stays charged to that outer ledger until the caller frees it.
Nested internal calls forward the format options and inherit the existing
allocator policy. Compatible explicit nested bindings are accepted; conflicting
limit/profile bindings return `InvalidBlockPlan` instead of replacing or silently
ignoring the outer policy. A zero-allocation child leaves the outer profile's
live bytes intact. The surviving owner starts each new error-classification
interval with its `Lease.beginOperation()`; forwarded/default child options do
not reset a parent's or sibling's earlier failure. This is the shared ledger's
existing coordinator contract.

Append adopts the entire caller-owned destination capacity before allocating
control state, history, an alias snapshot or decoded staging. All destination
growth shares that ledger. It releases the final destination capacity back to
the physical caller on success and error. A quota refusal publishes no appended
bytes and preserves the preexisting pointer, capacity and bytes. Existing
format-validation and append rollback behavior remains in the original decoder.
The preexisting capacity may itself exceed the cap: this rejects admission before
an allocator request, while the profile truthfully records that existing peak
and returns its live count to zero.

## Zero-heap operations and failure precedence

Caller-buffer into APIs, fixed/caller-history size/summary APIs, probes and the
eager caller-buffer `StreamDecoder` retain their zero-requested-heap paths.
`max_total_working_memory = 0` and profile-only requests introduce no metadata
allocation there; profiles report an available zero peak and zero live count.
Valid empty owned streams, including preceding metadata and prefix tails, also
retain zero heap. Exact-size owned calls with an expected size of zero allocate
no control state before applying the existing size/error contract.

An allocating summary first tries its fixed automatic history for an opted-in
policy. If that suffices, the operation likewise accepts cap zero and records
zero. Only genuine context-history exhaustion admits the shared control state
and the full advertised-window history fallback. The default summary keeps its
existing eager-history hint and retry strategy.

Scalar dictionary validation, window codes, first meta-block headers, metadata
and empty-stream padding are read before metadata admission. Allocating summaries
retain parser phase/offset diagnostics, and fixed-history format failures precede
heap fallback. A rejecting backing allocator cannot mask these preflight errors.
A cap refusal is `WorkingMemoryLimitExceeded`; genuine backing allocator failure
is `OutOfMemory`. This error remains in `br.Error`; `core.Error` and other codec
error sets are unchanged. Decoded-output limits continue to use
`OutputLimitExceeded`, and full-stream tails remain `TrailingData` after the decode is admitted by its
output and working-memory policies. Prefix APIs
retain the validated first stream's `input_read`, including zero padding.

## Incremental option reuse

`IncrementalCopyStreamDecoder.Options.decode` and
`IncrementalStreamDecoder.Options.decode` accept the same format-options type,
but reject either new non-null field with `UnsupportedBrotliFeature`. The owned
incremental decoder retains its separate `Options.max_working_memory` contract.
Rejection occurs at operation/frame validation, before accepting input,
publishing output or allocating decoder heap; step, finish, reset/reconfiguration
and next-frame paths cannot silently discard a requested policy. Constructors
and the copy decoder's void reset keep their established signatures, so those
paths surface invalid options on the first step or finish. Dictionary errors
retain precedence over the policy rejection.

## Validation

Run the focused public contracts with:

```sh
zig build -j2 test-br-decode-memory -Doptimize=ReleaseFast
zig build -j2 test-br-decode-memory -Dtarget=x86-linux-musl -Doptimize=ReleaseFast
zig build -j2 test-br-decode-memory-wasm -Doptimize=ReleaseFast
zig build -j2 run-br-decode-memory-reference -Doptimize=ReleaseFast
```

The independent backing allocator forces moving growth and compares its real
requested-byte peak with the profile. Exact measured peak `D` succeeds and
`D - 1` refuses, independently of instrumentation. Tests cover default/profile
output and boundary identity, stored/RLE/entropy/multiple meta-blocks, Large
Window, borrowed RAW and parsed serialized dictionaries, true OOM, aliases,
existing capacity, prefix tails, truncation, malformed input, and output
publication. The WASI gate executes the actual 32-bit Zig test artifact and
writes `zig-out/br-decode-memory-wasm.json` with artifact/source identities.
Reference verification records its concrete library versions and native/x86
receipts under `zig-out/br-decode-memory-reference/`.

The broader compression objective remains active. Reusable decoder-owned entropy
workspaces, stack accounting, additional hostile-stream coverage, and matched
lifecycle performance evidence remain separate next steps.
