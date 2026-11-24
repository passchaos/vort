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

`zig build run-deflate-checkpoint-interop` is an independent encoder and
checkpoint oracle, also run by `ci-smoke`. Libz produces raw, zlib and gzip
streams using default and fixed strategies, with `Z_BLOCK`, `Z_PARTIAL_FLUSH`,
`Z_SYNC_FLUSH` or `Z_FULL_FLUSH` between input chunks and an empty final block.
A mixed-tail case applies PARTIAL, SYNC and FULL in sequence after the last
`Z_BLOCK`, without new plaintext, to exercise several EOBs at the same output
position. Libz `inflate(Z_BLOCK)` supplies each non-final EOB position as a bit offset
and decoded byte count. The comparison excludes libz's wrapper-header and
final-block returns; it checks the Vort contract of reporting stops between
DEFLATE blocks, not exact equivalence of the wrapper APIs.

Vort runs compact, semantic and automatic-wrapper routes with a hard output
cap equal to the plaintext length. Schedules include one-byte transport,
periodic zero-capacity calls, and contiguous input. Bit positions account for
retained lookahead; matching only consumed-byte counts would miss defects
when several boundaries share a byte. This hard-cap policy is distinct from
raw `stop_at_output_limit`, which intentionally suspends prefix decoding.

```sh
zig build -Doptimize=ReleaseFast run-deflate-checkpoint-interop
zig build -Doptimize=ReleaseFast -Dzlib-ng-root="$HOME/Work/zlib-ng" \
  run-deflate-checkpoint-interop
```

System libz 1.2.11 and zlib-ng 1.3.2.zlib-ng (`a0467052`, compat build) each
passed 60 wires, 520 runs, and 1,976 exact checkpoints. Each reported 1,144
checkpoints at the hard output cap, 90 completed semantic blocks, and 72
checkpoints where neither the input nor the output byte count advanced. The
same oracle linked to pre-fix Vort `f9dc91d7` rejected the first raw `Z_BLOCK`
case with `UnexpectedCompletion` after the checkpoint was skipped; the fix
and current source pass. These are conformance counts, not performance data.

This establishes the decoder-side checkpoint contract. It does not add an
encoder checkpoint, a whole-stream save/restore format, or a
streaming/dictionary performance comparison.
