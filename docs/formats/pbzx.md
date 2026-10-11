# Apple PBZX

Vort reads and writes Apple's PBZX streaming container used for macOS installer
and software-update payloads. The implementation is pure Zig and exposes the
decompressed byte stream; callers can pass the usual CPIO payload to Vort's
existing CPIO APIs.

The 12-byte header is parsed as `pbzx` followed by a big-endian maximum
uncompressed chunk size. This field is not treated as the old, frequently
repeated “flags” interpretation: current Apple writers put their selected block
size there, while installer payloads commonly use 16 MiB. Each chunk carries
big-endian uncompressed and packed sizes followed by either stored bytes or one
complete XZ stream. Normal streams end at EOF; a final all-zero chunk header is
also accepted, but an all-zero header followed by more data is corruption.

Parsing validates chunk counts, maximum chunk size, cumulative decoded size,
packed ranges, XZ magic, integer arithmetic, and optional XZ dictionary limits.
Range decoding skips non-overlapping chunks and only inflates compressed chunks
that intersect the requested range.

```zig
const stream = try vort.parsePbzxWithOptions(bytes, .{
    .max_output_len = 1024 * 1024 * 1024,
    .max_chunk_decoded_bytes = 16 * 1024 * 1024,
    .max_xz_dictionary_bytes = 64 * 1024 * 1024,
});

const decoded = try stream.decodeAllocLimited(allocator, max_output);
defer allocator.free(decoded);

const range = try stream.decodeRangeAllocLimited(
    allocator,
    offset,
    length,
    length,
);
defer allocator.free(range);
```

The deterministic writer supports forced stored chunks, forced XZ chunks, and
automatic compressed-or-stored selection. Chunk size and XZ options are
caller-controlled.

```sh
zig build run -- inspect-pbzx Payload
zig build run -- decode-pbzx Payload payload.cpio 1073741824
zig build run -- decode-pbzx-range Payload range.bin 16777200 4096
zig build run -- encode-pbzx payload.cpio Payload auto 16777216
zig build test-pbzx
zig build run-pbzx-diff
```

The differential gate has an independent PBZX reader decode Vort's stored, XZ,
and automatic output. It also constructs mixed stored/compressed PBZX streams
with the system `xz` implementation and decodes them through Vort.
