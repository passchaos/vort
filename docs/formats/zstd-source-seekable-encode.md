# Write a Zstandard seekable archive from a source

`zstdEncodeSourceSeekableTo` reads a known-length `ByteSource` and writes a
complete Zstd contrib seekable archive to a `ByteSink`. It does not assemble the
entire plaintext or output in memory. `FileByteSource` and `FileByteSink` can
wrap existing file handles without taking ownership of them.

```zig
const options: vort.ZstdNativeSeekableOptions = .{ .frame_size = 128 * 1024 };
const needed = try vort.zstdSourceSeekableEncodeRequirements(source.len, options);
// Allocate `needed.frame_input_len` bytes and `needed.frame_count` entries.
const result = try vort.zstdEncodeSourceSeekableTo(allocator, source, sink, .{
    .frame_input = frame_input,
    .entries = entries,
}, options);
```

The requirement query does not perform I/O or allocate. It also reports
`table_bytes`, the exact on-wire size of the terminal skippable frame. A zero
length source emits one empty data frame; a nonempty source gets one frame per
`frame_size` chunk, with no extra frame on an exact multiple. Frame and
seek-table checksum options are independent. `zstdEncodeSourceSeekableToWithDictionary`
uses the supplied dictionary for each frame, or only the first frame when
`dictionary_usage` is `.prefix`, matching the contiguous encoder.

## Memory, I/O and publication

- The used caller buffers hold at most one plaintext frame and one fixed-size
  entry per data frame. The encoder reuses its scratch and match state across
  frames; the seek table is written in fixed-size batches without a second
  table allocation. `frame_options.max_total_working_memory` covers
  encoder-owned requested heap across the operation, not the caller buffers
  or memory allocated inside source and sink callbacks.
- The source length and contents must remain stable. The source, sink, used
  workspace prefixes, borrowed dictionary and mutable encoder profiles must
  not alias. The backing allocator must not return memory overlapping those
  borrows. Keep all backing storage valid until the call returns.
- Source and sink offsets are 64-bit. Reads and writes honor callback limits
  and complete short transfers before moving to the next frame. Sink writes
  are consecutive from offset zero. `finish` sets the final length only after
  all frames and the seek table have been written.
- Invalid frame options, an unrepresentable frame count, and insufficient or
  overlapping workspace fail before I/O. Other errors can leave a partial
  archive and tentative workspace. The error-union API does not report a
  retry position or roll back sink bytes. Use a separate temporary sink and
  publish it after success if atomic replacement is required.

The output can be opened with the [source seek table and range decoder](zstd-source-seekable.md).
The tests compare its complete wire to the contiguous encoder and cover short
callbacks, empty input, exact multiples, dictionary use, wide sizing and I/O
failures during frames, table writing and length commit.

## Independent verification

`zig build check-zstd-source-reverse` executes the writer and reader contracts
on native, x86 and WASI. To produce an archive directly from an existing file:

```sh
zig build run-zstd-source-seekable-encode-probe -- plain.bin new-archive.zst 131072 1
```

The probe requires a new output path. The last argument enables (`1`) or
omits (`0`) seek-table checksums. Build the standalone
[upstream checker](../../tools/zstd/source_seekable_encode_verify.c) as shown
in its header, then run:

```sh
/tmp/vort-seekable-encode-verify new-archive.zst plain.bin 131072 1
```

The checker uses upstream Zstd and its contrib seekable API, with no Vort code
linked. It checks random ranges, full plaintext, frame extents, and the complete
seek table against one independently regenerated from the observed frames.
With libzstd 1.6.0 (`01b7154f`), empty, exact-multiple, short-tail and multi-batch
Vort archives passed this comparison (1, 3, 4 and 258 frames), with both seek
checksum modes exercised.
