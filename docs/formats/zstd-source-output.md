# Zstandard source decode output ownership

`decodeSourceFrameInto`, `decodeSourceStreamInto` and
`SourceStreamCursor.decodeInto` publish complete decoded blocks into caller
storage. Their entire offered destination must be separate from every slice
in `SourceFrameWorkspace`: history, staging, literal page and sequence page.
Unused destination tails and unused workspace capacity participate in this
check. History and pages remain mutable during later blocks and frames, so
using them as output can corrupt previously published bytes even when the
frame checksum passes.

The frame and stream append forms apply the same check to the list's entire
allocated capacity, including its logical prefix and spare capacity, and to
the list descriptor. Validation precedes payload execution and growth. A
grown allocation is checked before publication. The allocating facades share
the append implementation.

The backing allocator must preserve still-borrowed dictionary and workspace
storage. A post-growth check prevents codec publication into a newly aliased
allocation; it cannot undo initialization or poisoning performed by the
allocator itself before returning that allocation.

Mutable output/workspace storage must also be separate from configured
dictionary content, full standard-dictionary encoding, prepared entropy state
and dictionary-set descriptors. The complete configured catalog is admitted
at operation entry: an early frame must not overwrite a later frame's
dictionary or descriptor. Dictionaries may share immutable backing with one
another. Workspaces must be mutually disjoint, as required by frame executor
initialization.

A destructive alias returns `InvalidBlockPlan`. Entry rejection performs no
source callback, output allocation or payload write. A cursor retains its
pending frame, source offset and cumulative decoded count, and accepts a retry
with independent output/workspaces. The cursor object itself cannot overlap
those mutable slices or configured dictionary storage.

The lower-level frame executor checks every offered `drain` destination
against complete history, staging, page and dictionary storage, as well as the
frame state, history binding and executor object. Rejection leaves the block
lease and drain offset intact. An empty destination performs no copy and
retains the existing no-progress behavior.

The random-access `Source` has an opaque context and read callback. Its context
and backing bytes must remain independent of mutable output/workspaces and
stable for the complete operation. The facade cannot infer those ranges from
the callback. Existing partial-output behavior for source, format, output-size
and checksum errors remains block based; callers requiring atomic whole-frame
publication supply their own independent destination staging.

The [regression evidence](../performance/zstd-source-output-alias-20261111/README.md)
includes the frozen successful-but-corrupt counterexample, rejected aliases,
independent retries and native/x86/WASI validation.
