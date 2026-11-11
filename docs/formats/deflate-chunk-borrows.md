# Deflate chunk joining and decode borrows

Legacy Raw Deflate, zlib and gzip chunk facades coalesce fragmented compressed
input into caller-owned scratch. The shared join is allocation-free and
validates the complete copy schedule before its first write. Inspection,
append, probe, reusable decoder and PNG consumers use the same admission
boundary with their operation-specific borrows.

## Copy schedule and scratch

One nonempty chunk, including a chunk surrounded by empty descriptors, remains
borrowed directly. It needs no compressed scratch capacity and does not touch
scratch. Empty/all-empty lists perform no writes; the downstream decoder
retains its ordinary empty-input error. Unused compressed scratch is not a
borrow conflict merely because its address overlaps another buffer.

For multiple nonempty chunks, checked total length and scratch capacity precede
copying. The helper also checks descriptor-table byte-size multiplication.
An insufficient compressed scratch buffer returns `OutputTooSmall`; an
unrepresentable total/table extent returns `IntegerOverflow` before copying.

Every copy is planned before execution. Identity source/destination slices are
skipped, and a current chunk can move forwards or backwards within its own
destination using memmove semantics. Earlier actual writes must not overwrite
any source still needed by a later copy. Read-only chunks may overlap or
duplicate each other; an all-identity packed layout is a valid no-op.

The helper tracks the envelope from the first through the last actual write.
Leading/trailing identity chunks are excluded. Gaps inside this envelope are
conservatively protected, keeping validation linear and avoiding per-chunk
heap storage or a quadratic overlap scan. Use independent scratch when a
layout has a source inside such a gap.

Actual writes must be disjoint from chunk and policy descriptor tables,
provided dictionaries, caller output, complete append allocations and list
objects, reusable state/retained decoded storage, and PNG row/image borrows.
The unused scratch tail is permitted to overlap these regions. Admission
failure returns `InvalidBlockPlan` before scratch, protected bytes, decoder
state or append capacity changes, and before any decode allocator callback.

## Decode and growable-output boundaries

Caller-buffer decoding requires its actual contiguous input to be disjoint
from the complete provided output slice and dictionary output borrows. A
multi-chunk operation can reuse original chunk storage for output after
coalescing snapshots it, provided the output is independent of the joined
input and dictionary. A single borrowed chunk has no snapshot and retains
the contiguous input/output admission rule.

Input and dictionary may share read-only storage. No-copy single/identity
joins can preserve that relationship. A join which would overwrite dictionary
bytes needed after coalescing is refused, including a zero-length decoder
output: joining is itself a write operation.

Append protects the entire existing allocation, including spare capacity,
and the ArrayList object from join writes. Reading compressed input or a
dictionary from that allocation remains supported. Exact append already
stages decoded output. Other legacy chunk append paths stage only when those
read borrows alias the growable allocation/object, consuming the input before
growth or publication can invalidate it. Ordinary disjoint append retains its
existing direct path.

Staging uses the supplied allocator, respects the existing output limit and
frees the owned decode result on successful publication or output-growth
failure. Real allocation failure stays `OutOfMemory`; no fallback swallows
it. Staging can require a complete temporary decoded buffer on the alias path,
so no unchanged-peak or zero-allocation claim applies to that path. Failed
staging leaves the original list and its bytes available for retry.

## Reusable state, PNG and metadata lifetime

Reset protects the receiver object, new output scratch and retained decoded
storage before joining. A mutable receiver which aliases input, dictionaries,
descriptors or output is refused before error recording can modify those
borrows. Raw reset continues to record ordinary join errors but returns a
borrow refusal without changing prior diagnostics. New output may reuse the
old decoded buffer; joining may not overwrite retained bytes before admission.

PNG scanline reset validates its configuration and all outer row/state borrows
before installing new state, joins once, then initializes the scalar zlib
consumer. Adam7 additionally protects the complete image output and both row
buffers before the inner zlib decode. These outer checks are necessary because
an inner decoder cannot discover every caller-owned buffer.

Gzip header/member extra, filename and comment slices keep their existing
borrowed lifetime: a single source lends its original bytes; a multi-source
join lends compressed scratch. The caller must retain that backing storage
while using returned metadata. No heap snapshot is introduced for inspection.

The allocation-free implementation is
`src/deflate/decode/chunk_join.zig`; growable-output staging ownership lives in
`src/deflate/decode/append_borrows.zig`. Dedicated contracts cover the Raw,
wrapped, zlib concatenated append and metadata/state surfaces under
`src/deflate/decode/tests/`.

## Verification

```sh
zig test src/deflate.zig -ODebug \
  --test-filter 'chunk decode borrow contracts'
zig test src/deflate.zig -OReleaseSafe \
  --test-filter 'chunk decode borrow contracts'
zig test src/deflate.zig -target x86_64-linux-gnu -mcpu=skylake+pku+sgx \
  -OReleaseSafe --test-filter 'chunk decode borrow contracts'
zig test src/deflate.zig -target wasm32-wasi -OReleaseSafe -fsingle-threaded \
  --test-filter 'chunk decode borrow contracts' --test-no-exec \
  --stack 8388608 -femit-bin=/tmp/vort-deflate-chunk-borrows-20261111.wasm
node tools/deflate/clone/wasm_gate.js \
  --output /tmp/vort-deflate-chunk-borrows-20261111-wasi.json \
  /tmp/vort-deflate-chunk-borrows-20261111.wasm
```

Scratch-free direct chunk decoders, contiguous wrapper dictionary-set APIs,
and incremental execution have separate ownership surfaces. They are not
covered by the shared coalescing contract merely because their names contain
`Chunks`.
