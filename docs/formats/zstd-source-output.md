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
and checksum errors remains block based. Use the verified stream mode below
when the destination must not expose an incomplete frame.

## Resume an interrupted source stream

`decodeSourceStreamIntoWithProgress` takes the same source, destination,
workspace and options plus an optional checkpoint (`null` for a fresh stream).
Its `ZstdSourceStreamOutcome` distinguishes a complete result from failure.
Both report two local output lengths:

- `output_written`: all bytes actually drained into this invocation's
  destination, including a failed frame's published prefix. A short
  destination can contain part of an already decoded block.
- `complete_output_written`: the prefix from complete data frames only. A frame
  whose footer could not be read or whose checksum disagrees is incomplete,
  even if all its plaintext has already been written.

`progress.checkpoint` uses absolute compressed and decoded offsets, wide
cumulative data/skippable counts, and the stream format. It advances only
past complete data frames or range-checked skippable frames. A failure also
reports the data-frame header, including its dictionary ID, when traversal
had admitted that header. A header read or admission failure has no such
metadata.

To retry after a transient read error or a dictionary refusal, retain only
`output[0..progress.complete_output_written]`. Invoke the same API with the
**original full source**, the checkpoint, and
`output[progress.complete_output_written..]` (or a new destination appended
after the retained prefix). It replays the interrupted frame from its start,
replacing the partial bytes; it does not read completed elements again or
retain intra-frame history. Frame count and total decoded limits apply to the
whole logical stream, including earlier checkpoint counts. A checkpoint at
EOF returns zero local output without a source callback.

Use a trusted checkpoint returned for the same stable source. The API checks
the offset, format and cumulative policy bounds; it does not revalidate the
preceding bytes or authenticate the checkpoint. Validation follows the decode
options including `ignore_checksum`. The existing error-union and append
interfaces retain their block-publication semantics.

## Publish only complete, verified frames

`zstdDecodeVerifiedSourceStreamIntoWithProgress` adds a separate
`frame_scratch` argument before the options and checkpoint. The decoder
stages one complete frame in that caller-provided buffer and copies it into
the destination only after the frame's structure, size and any advertised
checksum are valid. No frame is reread for publication. Skippable payloads
are still not read, and the frame and total limits still apply on resume.

```zig
const outcome = vort.zstdDecodeVerifiedSourceStreamIntoWithProgress(
    source, output, workspace, frame_scratch, options, checkpoint,
);
```

Size `frame_scratch` for the largest decoded frame to be published, separate
from the destination, block workspace and dictionary storage. There is no
codec allocation. A known frame size exceeding the available destination or
scratch is rejected before its body is read; an unknown size can instead be
rejected during decode. Either refusal leaves the failing frame's destination
unchanged. Scratch contents on failure are unspecified. An empty frame can
complete without decoded-frame scratch space.

Checksum bypass (`ignore_checksum`) and overlapping buffers are rejected with
`InvalidBlockPlan` before source reads. `output_written` and
`complete_output_written` are always equal in this mode: both count only this
call's verified frames. A failure retains those frames and the checkpoint at
the next element for retry. Earlier elements are not reverified when a
checkpoint is supplied; this is validation of newly read frames, not
cryptographic authentication. Use the block-publication API to stream frames
that do not fit a decoded-frame buffer.

The [regression evidence](../performance/zstd-source-output-alias-20261111/README.md)
includes the frozen successful-but-corrupt counterexample, rejected aliases,
independent retries and native/x86/WASI validation.
