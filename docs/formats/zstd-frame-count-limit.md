# Zstd decode frame-count limit

`max_frames` limits the combined number of data and skippable frames in one
logical Zstandard stream. Empty data and skippable frames each consume a slot,
even with zero decoded bytes. In magicless format only data frames are
recognized. The default is unlimited; a zero limit admits no frame. This is
independent of decoded-byte, window and working-memory limits.

- `ZstdFrameDecodeOptions` applies to one-shot size, allocate, into and append
  operations, including prefix wrappers and reusable decoders. The existing
  size preflight rejects excess before publishing output. With chunk input,
  the header-only admission scan also runs before modifying the caller's
  compressed scratch.
- `ZstdIncrementalFrameDecoder.Options` applies in both `.block_stream` and
  `.prevalidated_frame` modes. Prior output and completed frame counts remain
  committed. A rejected skippable frame does not emit an observer event or
  write to fixed capture. `nextStream` and automatic continuation preserve
  the quota; `reset` and `resetWithOptions` start a new logical stream.
- `ZstdSourceStreamDecodeOptions` applies to stream inspection, allocate,
  into and append. Source into/append retain their already committed output
  on failure. Set the traversal limit with
  `ZstdSourceStreamCursor.initWithFrameLimit(source, format, max_frames)`
  when walking elements manually. Rejection leaves the cursor at the refused
  frame with no pending data; decoding, inspecting or skipping an already
  admitted frame does not charge it again.

A complete, valid header beyond the quota returns `OutputLimitExceeded`
before dictionary lookup, block processing or skippable payload processing.
Incomplete or invalid headers retain their wire errors. Prevalidated
incremental calls may already have buffered later bytes as lookahead for an
admitted frame; admission never treats those bytes as an accepted body of
an excess frame. A header-only refusal can therefore precede a body
truncation error. The limit does not change wire format, legacy options-less
APIs or indexed seekable range reads.

`zig build check-zstd-source-reverse` runs native, 32-bit x86 and executed
WASI contracts. The mixed fixture (raw data, empty data, empty skippable)
decodes to `abc` with libzstd 1.4.8 and 1.6.0; the caller quota is a Vort
policy, not a claim that those references expose an equivalent option.
