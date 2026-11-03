# Deflate block-boundary checkpoint API, 2026-11-03

Raw, zlib and gzip incremental Deflate decoders now expose
`stepToBlockBoundary`. It advances through wrapper headers/footers and the
deflate payload until the next compressed-block boundary, an input/output wait,
or completion. A new `core.StepResult.block_boundary` flag marks a stop
between blocks even when caller input remains, and `atBlockBoundary()` reports
whether the decoder is positioned at a block header or at completion.

Ordinary `step` never sets the flag. Checkpoint-aware callers can persist
their own state after a boundary result and resume with another call; callers
that only follow `progress` continue normally. The request is one-shot and is
cleared when the step returns, so it cannot affect a later ordinary call.

The result keeps the existing status vocabulary. A boundary stop uses
`need_input` with the flag set because the caller may still hold unconsumed
input; callers must inspect the flag before treating the status as an input
request. This avoids changing the status enum and the many existing streaming
switches.

## Validation

Tests generate raw, zlib and gzip streams with 64-byte encoder blocks, producing
33 deflate blocks for the structured payload. Each `stepToBlockBoundary` call
that reports a boundary also satisfies `atBlockBoundary()`, and the complete
decoded output equals the input. The same streams decoded through ordinary
`step` never report a boundary flag and still round-trip. The three tests pass
in Debug, ReleaseSafe and ReleaseFast; the broader incremental Deflate filter
passes 174/174 tests.

This establishes the decoder-side checkpoint contract. It does not add an
encoder checkpoint, a whole-stream save/restore format, or a
streaming/dictionary performance comparison.
