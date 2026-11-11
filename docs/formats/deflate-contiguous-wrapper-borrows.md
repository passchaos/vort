# Contiguous zlib/gzip decode borrows

Caller-buffer zlib and gzip decoding protects the complete encoded input,
including headers, trailers, trailing borrowed input and later concatenated
members, from the full provided output slice. Preset dictionary bytes must
also remain disjoint from output. Conflicts return `InvalidBlockPlan` before
decoding writes, independently of checksum-ignore options.

The common prefix decoders enforce admission for plain/options/auto-prefix and
strict convenience facades. Specialized Stored and concatenated facades enforce
the same rule before bypassing their prefix paths. Empty encoded input keeps
its ordinary `TruncatedFrame` result; ordinary nonalias header, checksum,
truncation and capacity errors keep their existing validation behavior.

Input and dictionaries may overlap each other because they are read borrows.
Adjacent nonoverlapping output remains supported. The full output slice is
protected, including capacity beyond bytes a particular stream might emit.
Automatic zlib/gzip detection retains its existing format-specific behavior:
when the detected format is gzip, the optional dictionary argument is ignored,
does not become a read borrow and may share output storage.

For a dictionary set, the complete descriptor table and every supplied entry's
bytes are protected before the first concatenated member writes. Checking only
the dictionary selected for the current member is insufficient: early output
could corrupt a later descriptor or another dictionary. Descriptor byte-size
multiplication is checked; an unrepresentable table extent reports
`IntegerOverflow` before reading its first entry. Dictionary resolution order
and ordinary `NeedDictionary`/DICTID behavior remain unchanged.

Allocating exact-size set decoding still uses its supplied allocator and normal
allocation failure semantics. Its newly owned output is admitted before any
payload writes. The API does not infer aliasing by assuming a conforming
allocator can return storage overlapping a caller's existing live allocation.

Scalar Raw Deflate/zlib/gzip reset additionally admits its mutable receiver
before decoding or error recording. Receiver storage must be disjoint from
input, dictionary and decoded-output storage. PNG scalar initialization protects
its outer object from row buffers before installing bindings. Refusal leaves
receiver bytes and diagnostics unchanged; new output may otherwise reuse its
existing decoded buffer. Empty input with an independent receiver retains
`TruncatedFrame`, including unused input-free output/dictionary sharing.

These fixed-output paths do not allocate snapshots for in-place decoding.
The shared checks live in `src/deflate/decoder/output_alias.zig`; independent
contracts live under `src/deflate/decode/tests/`. Chunk coalescing and growable
append have their additional [scratch/staging contracts](deflate-chunk-borrows.md).
