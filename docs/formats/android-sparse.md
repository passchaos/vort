# Android sparse images

Vort provides a pure-Zig Android sparse image v1 reader and deterministic
writer. Android sparse is a block-oriented sparse container rather than an
entropy codec: it stores literal blocks, repeated 32-bit fill values, and
logical holes compactly.

The reader supports all four version-1 chunk types:

- `RAW` (`0xcac1`) copies its block-aligned payload;
- `FILL` (`0xcac2`) repeats one little-endian 32-bit value;
- `DONT_CARE` (`0xcac3`) reads as zero-filled logical blocks;
- `CRC32` (`0xcac4`) verifies all expanded bytes before that chunk.

It accepts forward-compatible larger file and chunk headers, requires major
version 1, and preserves the minor version in the parsed header. Parsing checks
block geometry, reserved fields, exact payload sizes, chunk and block totals,
checked offsets, the optional whole-image CRC-32, every CRC32 checkpoint, exact
physical consumption, and caller limits. Checksum work is optional and bounded
separately, so a hostile sparse image cannot force an unbounded scan of a huge
logical hole.

```zig
var image = try vort.parseAndroidSparseAlloc(allocator, sparse_bytes, .{
    .max_chunks = 1 << 20,
    .max_block_size = 16 * 1024 * 1024,
    .verify_checksums = true,
    .max_checksum_bytes = 8 * 1024 * 1024 * 1024,
});
defer image.deinit();

const range = try image.readRangeAllocLimited(
    allocator,
    offset,
    length,
    max_output,
);
defer allocator.free(range);
```

The writer classifies each input block deterministically. Zero blocks become
`DONT_CARE`, other repeated 32-bit values become `FILL`, and remaining data
becomes `RAW`; adjacent compatible blocks are merged. Large RAW runs are split
automatically before the format's 32-bit physical-size field would overflow.
CRC32 chunks and the header checksum are independent options.

```zig
const sparse = try vort.encodeAndroidSparseAlloc(allocator, raw_image, .{
    .block_size = 4096,
    .sparse_zero_blocks = true,
    .use_fill_chunks = true,
    .emit_crc32_chunk = true,
    .write_image_checksum = true,
    .max_output_len = limit,
});
defer allocator.free(sparse);
```

The format records only a block count, not an exact byte tail, so the in-memory
writer requires block-aligned input instead of silently padding and changing
the caller's logical length.

CLI and validation surface:

```sh
zig build run -- inspect-android-sparse system.simg
zig build run -- decode-android-sparse system.simg system.img
zig build run -- decode-android-sparse-range system.simg range.bin 1048576 65536
zig build run -- encode-android-sparse system.img system.simg 4096 sparse fill crc checksum
zig build test-android-sparse
zig build run-android-sparse-diff
```

The differential compares four writer configurations byte-for-byte against an
independent Python implementation, checks bounded cross-chunk ranges, malformed
inputs, and deterministic mutations, and validates both directions with AOSP
`simg2img` and `img2simg` when installed. Explicit oracle paths can be supplied
with `-- --simg2img /path/to/simg2img --img2simg /path/to/img2simg`.

Current explicit limitations are streaming file I/O and automatic assembly of
multi-file sparse image sets. The core format implementation is self-contained
and has no runtime dependency on Android libsparse.
