# Scratch-free Deflate wrapper borrows

Scratch-free zlib/gzip entrypoints retain discontiguous input during decoding.
Before an original-span reader writes caller output, it checks the complete
input chunks, descriptor storage and preset dictionary against the full output
slice. A conflict returns `InvalidBlockPlan` before output writes. Descriptor
table byte-size multiplication and input-length addition are checked.

Zlib's existing bounded stack route is preserved. For eligible inputs up to
64 KiB, non-Stored blocks or many fragments can coalesce into a stack buffer.
Only a real multi-span coalescing copy creates a snapshot; one nonempty source
still borrows its original bytes. After a complete snapshot, original chunk
storage/descriptors may be reused for output if no other live dictionary or
state borrow conflicts. The original-span fallback instead admits output before
Stored or bit-reader execution. Gzip's direct reader has no such snapshot.

Direct reset protects receiver storage from original sources, descriptor
tables, dictionaries, output and row bindings before size/format error recording
or state installation. Refused borrows leave state and bytes unchanged.
Independent receivers may use valid snapshot-backed output reuse; a receiver
object cannot itself be overwritten merely because the encoded bytes will
eventually be copied. Ordinary nonalias errors and decoded-buffer reuse retain
their existing contracts.

PNG direct whole-image routes distinguish their actual writers. Stored readers
retain original chunks through footer validation, so filtered/previous rows
and image output require admission. The optimized streaming image route writes
active history and image rows; its supplied filtered/previous scratch is unused
and may share source storage safely. Fully decoded zlib/Adam7 image routes end
the original-input borrow before later row/pixel reconstruction, preserving
original-storage reuse after snapshot.

Adam7 streaming image clears its output before reader construction; admission
therefore precedes that clear. Active history and row buffers remain separate
from original chunks while streamed rows are decoded. Row-callback context has
an opaque extent and is not subject to an invented size check. The callback
must preserve the live compressed chunks, descriptors and history; its row
view lasts until the next decoder step and must be copied for longer retention.

The checks live in `src/deflate/decode/direct_borrows.zig`, outside symbol/match
loops. They require no allocator or input-sized scratch. Input chunks may share
read-only storage, and adjacent disjoint outputs are allowed. Incremental raw
step/generation ownership is a separate stateful contract: inactive second-half
history storage must not be confused with active semantic writers.

Stored PNG whole-image results report the completed decoder's absolute
`input_read`, including the header parsed during initialization and the footer.
Individual row-step progress remains a delta from that step's starting cursor;
summing only those deltas would omit the already consumed zlib header.
