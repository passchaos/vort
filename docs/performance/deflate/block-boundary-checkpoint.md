# Deflate block-boundary checkpoint API, 2026-11-03

Raw, zlib, gzip and stored-only incremental Deflate decoders now expose
`stepToBlockBoundary`. It advances through wrapper headers/footers and the
deflate payload until the next compressed-block (or stored-block) boundary, an
input/output wait, or completion. A new `core.StepResult.block_boundary` flag
marks a stop between blocks even when caller input remains, and
`atBlockBoundary()` reports whether the decoder is positioned at a block
header or at completion.

Ordinary `step` never sets the flag. Checkpoint-aware callers can persist
their own state after a boundary result and resume with another call; callers
that only follow `progress` continue normally. The request is one-shot and is
cleared when the step returns, so it cannot affect a later ordinary call.

The result keeps the existing status vocabulary. A boundary stop uses
`need_input` with the flag set because the caller may still hold unconsumed
input; callers must inspect the flag before treating the status as an input
request. A buffered end-of-block can report a checkpoint with zero input and
output progress. Resume with the same unconsumed input; the decoder is already
at the next block header. Compact and semantic decoding report the same
checkpoint positions, including under output backpressure.

## Validation

Tests generate raw, zlib and gzip streams with 64-byte encoder blocks, producing
33 deflate blocks for the structured payload, plus a stored-only stream with
the same block policy. Each `stepToBlockBoundary` call that reports a boundary
also satisfies `atBlockBoundary()`, and the complete decoded output equals the
input. The same streams decoded through ordinary `step` never report a
boundary flag and still round-trip. The four tests pass in Debug, ReleaseSafe
and ReleaseFast; the broader incremental Deflate filter passes 175/175 tests.

The follow-up checks the exact first checkpoint of a two-block libz 1.2.11
`Z_FIXED`/`Z_BLOCK` fixture in raw, zlib, gzip and auto mode. A six-byte output
slice leaves an entirely buffered end-of-block in the raw decoder; its next
checkpoint has zero byte progress. Three-block dynamic fixtures compare every
semantic checkpoint with compact decoding, including compressed offsets,
output offsets, output backpressure, retained history and ordinary-step
continuation. Empty and nonempty stored blocks have exact checkpoint controls.

This establishes the decoder-side checkpoint contract. It does not add an
encoder checkpoint, a whole-stream save/restore format, or a
streaming/dictionary performance comparison.
