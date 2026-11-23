# Incremental Zstd skippable observers

`ZstdIncrementalFrameDecoder.Options.skippable_observer` delivers complete
skippable-frame payloads incrementally, even when the fixed `skippable_output`
and `skippable_events` captures are absent or full. It works in ordinary
standard format with both `.block_stream` and `.prevalidated_frame` input
policies. Magicless input does not recognize skippable frames.

```zig
var decoder = vort.ZstdIncrementalFrameDecoder.initWithOptions(allocator, .{
    .skippable_observer = .{ .context = &collector, .on_event = Collector.onFrame },
});
defer decoder.deinit();
```

The callback has signature
`fn (?*anyopaque, vort.ZstdIncrementalFrameDecoder.SkippableObservation) void`.

- `.start` announces the zero-based skippable ordinal, ID, absolute compressed
  offset of the magic and the declared `u32` payload length. It fires after
  admission of the complete eight-byte header. Empty frames only emit this
  event.
- Each `.chunk` gives the same ordinal and ID, a payload-relative `u32` offset,
  and a nonempty read-only span. Chunk boundaries depend on the available
  input. The span is valid only during the callback, including when it refers
  to decoder lookahead from a previous data frame.
- A body is complete once spans cover the declared length. A missing tail
  can leave a start and a partial prefix without a completed fixed capture
  entry. An unsuccessful `finish()` with `TruncatedFrame` does not replay
  already delivered bytes if the missing input is supplied later.

Observation requires no payload-sized allocation and neither needs decoded
output space nor consumes decoded-output quota. Existing fixed capture sizing,
truncation, and completed-frame counters are unchanged. Keep the observer
context and any mutable callback state independent of the decoder, input,
output, fixed capture, and workspaces. Do not reenter or modify those from a
callback; copy any bytes needed after return.

`stop_after_first_frame` still stops at the first **data** frame. Following
skippable frames are not observed until traversal resumes, even if their
bytes were accepted as lookahead. `nextStream` preserves the logical stream's
indices and offsets. `reset` starts them over with the same observer;
`resetWithOptions` can replace it. The separate source cursor continues to
expose skippable ranges without reading their payloads.

The native, Linux x86 and executed wasm32-wasi contracts run via the three
`test-codec-member-boundaries` variants. System Zstd CLI 1.4.8 independently
validated a concatenated fixture with empty, 262,400-byte and short skippable
frames interleaved with data frames, returning only the expected 108 plaintext
bytes.
