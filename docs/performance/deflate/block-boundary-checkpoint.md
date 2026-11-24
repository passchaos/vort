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

## Exact position query

`blockBoundaryPosition()` returns `?DeflateBlockBoundaryPosition`. The fields
`compressed_byte_offset` and `compressed_bit_offset` locate the next header
relative to decoder reset, counting from the least-significant bit (0) of
that byte. `decoded_offset` counts published plaintext. Wrapper header and
footer bytes and previous concatenated members contribute to the absolute
compressed coordinate. Buffered lookahead does not: the byte position can
therefore precede the number of compressed bytes already accepted.

```zig
const step = try decoder.stepToBlockBoundary(input, output);
if (step.block_boundary) {
    const checkpoint = decoder.blockBoundaryPosition().?;
    // Store the byte and bit fields separately, along with decoded_offset.
    indexCheckpoint(checkpoint);
}
```

A raw decoder at completion reports the exact final EOB position, before any
padding. Completed zlib and gzip decoders report the byte after the last
validated footer, excluding any accepted trailing-data probe. Stored-only
positions are byte-aligned even if part of the next header is buffered.
The query returns null inside a block, during wrapper header/footer parsing
and auto detection, between members, or while a recorded decode error remains.
It works after ordinary stepping too and produces no new pause events. Raw
Deflate64 uses the same position representation.

Keep both compressed fields: a full-width byte offset can overflow if multiplied
by eight. A coordinate alone does not contain window history or dictionary state.

## Capture and restart a payload

At the next block header, `captureBlockRestart(history_output)` saves a
`DeflateBlockRestartPoint` from raw Deflate/Deflate64 and from zlib, gzip or
auto-detect decoders. The result borrows the written prefix of `history_output`,
with usable window bytes in oldest-to-newest order. The position remains
absolute even in a later concatenated member; the history is member-local.
A final EOB or a partially decoded block is not a restart point.

Restore a point in a raw decoder of the matching format. For an unaligned
checkpoint supply the original compressed byte containing that bit position;
for an aligned checkpoint supply `null`. Then start issuing input at the
returned absolute byte offset:

```zig
const point = try decoder.captureBlockRestart(saved_history);
const initial_byte: ?u8 = if (point.position.compressed_bit_offset == 0)
    null
else
    try readAt(point.position.compressed_byte_offset);
const next_input = try raw.restartAtBlockBoundary(point, initial_byte, .{
    .max_output_len = absolute_output_limit,
    .allow_trailing_data = true,
});
```

Restoration seeds caller-owned history and restores absolute compressed and
plaintext counters. Output limits and expected lengths use those absolute
coordinates. Restore cannot relax the saved distance cap, and rejects an
incompatible window, insufficient storage, counter overflow or overlapping
borrow **before** resetting the decoder or touching history. Capture likewise
checks its actual output span before copying. Neither operation allocates.

Store the numeric fields and history bytes explicitly if persisting an index;
there is no serialized format for the Zig struct. Use only trusted checkpoints
from the same compressed data. A restart decodes a raw payload suffix, leaving
any wrapper footer unconsumed when configured to allow trailing data. It does
not reconstruct the prefix checksum or validate a zlib/gzip member's footer;
use a full wrapper decode or state clone when that validation is required.

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
position. Libz `inflate(Z_BLOCK)` supplies each non-final EOB bit offset and
decoded byte count, compared with the public `blockBoundaryPosition()` query.
The checkpoint counts exclude wrapper headers and the final block. Separate
checks compare the exact raw final EOB against libz and the completed wrapper
position against its byte-aligned footer end.

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
earlier internal-state oracle linked to pre-fix Vort `f9dc91d7` rejected the
first raw `Z_BLOCK` case with `UnexpectedCompletion` after the checkpoint was
skipped; the fix and the current public-position oracle pass. These are conformance counts, not performance data.

The same oracle checks suffix replay from captured histories against libz
`inflatePrime` and `inflateSetDictionary`. On system libz 1.2.11 it verified
256 restarts (136 non-byte-aligned) across raw, wrapped and auto consumers.
The focused wide tests also cover actual cross-block matches, restarting at
modeled offsets above 4 GiB, circular history order, cross-member isolation,
and transactional refusal of invalid or aliased restart data.

This does not add an encoder checkpoint, a whole-stream save/restore format,
or a streaming/dictionary performance comparison.
