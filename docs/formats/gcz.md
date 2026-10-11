# Dolphin GCZ disc images

Vort reads and writes Dolphin's GCZ GameCube/Wii disc-image container in pure
Zig. GCZ stores fixed-size blocks as either complete zlib streams or raw bytes,
with 64-bit relative pointers and a per-block Adler-32 over the stored payload.

The reader validates:

- the 32-byte little-endian header and `0xB10BC001` magic;
- exact logical-size/block-count geometry and bounded power-of-two block sizes;
- complete 64-bit pointer and 32-bit hash tables;
- monotonic relative offsets, the high-bit raw marker, compressed-data bounds,
  raw block sizes, and Dolphin's compressed-block safety margin;
- stored-payload Adler-32 values, complete zlib wrappers, full decoded blocks,
  partial logical tails, whole-image limits, and arbitrary ranges.

```zig
const image = try vort.parseGcz(gcz_bytes, .{
    .verify_hashes = true,
    .max_blocks = 1 << 24,
    .max_block_size = 64 * 1024 * 1024,
    .max_compressed_block_bytes = 64 * 1024 * 1024 + 64,
});
const range = try image.readRangeAllocLimited(
    allocator,
    offset,
    length,
    max_output,
);
defer allocator.free(range);
```

The deterministic writer supports raw, forced-zlib, and automatic blocks. It
zero-pads the final codec block while preserving the exact logical size. Auto
mode follows Dolphin's ten-byte minimum-saving policy by default, writes the
raw marker when compression is not worthwhile, and hashes the selected stored
bytes. Block size, zlib level, subtype, and saving threshold are explicit.

```zig
const encoded = try vort.encodeGczAlloc(allocator, iso_bytes, .{
    .compression = .auto,
    .block_size = 128 * 1024,
    .compression_level = 9,
    .sub_type = 0,
});
defer allocator.free(encoded);
```

CLI and validation surface:

```sh
zig build run -- inspect-gcz game.gcz
zig build run -- decode-gcz game.gcz game.iso 17179869184
zig build run -- decode-gcz-range game.gcz range.bin 1048576 65536
zig build run -- encode-gcz game.iso game.gcz auto 131072 9 0
zig build test-gcz
zig build run-gcz-diff
```

The differential always checks all three writer modes against an independent
Python `zlib` implementation, creates a reference GCZ for Vort, and exercises
ranges, hashes, partial tails, and malformed pointers. When `dolphin-tool` is
available it additionally converts every Vort image back to ISO and generates
a fresh GCZ for Vort. Use `-- --dolphin-tool /path/to/dolphin-tool` to select an
explicit oracle.
A pinned image from Dolphin commit `e2ad09306e6d` keeps real-tool decoder
coverage in the unit suite when DolphinTool is unavailable.

GCZ has no filesystem-aware junk-data reconstruction and is less efficient for
Wii images than RVZ. The current API is one-shot over caller-owned bytes;
streaming file I/O, parallel compression, and compression tuning remain
follow-up work.
