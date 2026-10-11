# Dolphin WIA and RVZ images

Vort provides a shared pure-Zig reader and deterministic writer for WIA 1.0
and RVZ 1.0 raw-data layouts. This covers GameCube images and arbitrary raw
disc images. Wii partition entries that remove hashes/encryption are detected
and currently rejected explicitly instead of being decoded incorrectly.

Supported compression methods:

| Container | Methods |
| --- | --- |
| WIA | none, purge, Bzip2, raw LZMA1, raw LZMA2 |
| RVZ | none, Bzip2, raw LZMA1, raw LZMA2, Zstandard |

The reader validates both hashed headers, version compatibility, exact file
size, chunk geometry, compressor properties, the partition-table SHA-1,
compressed metadata extents, ordered logical raw-data coverage, group ranges,
per-group sizes, and caller-configured memory limits. RVZ groups can override
the global codec with uncompressed storage or represent all-zero data without a
payload. RVZ junk packing is decoded, including literal segments and the
521-word lagged-Fibonacci reconstruction used by GameCube/Wii padding.

```zig
var image = try vort.parseWiaAlloc(allocator, image_bytes, .{
    .max_raw_entries = 1 << 20,
    .max_group_entries = 1 << 24,
    .max_chunk_size = 64 * 1024 * 1024,
    .max_metadata_bytes = 256 * 1024 * 1024,
    .max_group_stored_bytes = 128 * 1024 * 1024,
    .max_dictionary_size = 64 * 1024 * 1024,
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

The writer emits one canonical raw-data entry covering the image after the
duplicated 0x80-byte disc header. Metadata tables use the selected global
codec. WIA compresses every non-zero group as required by the format. RVZ
stores a group uncompressed when compression is not smaller and emits the
zero-group sentinel for all-zero chunks. Header/table SHA-1 values and all
offsets are deterministic.

```zig
const rvz = try vort.encodeWiaAlloc(allocator, iso_bytes, .{
    .container = .rvz,
    .compression = .zstd,
    .compression_level = 5,
    .chunk_size = 128 * 1024,
});
defer allocator.free(rvz);
```

CLI and validation surface:

```sh
zig build run -- inspect-wia game.wia
zig build run -- inspect-rvz game.rvz
zig build run -- decode-wia game.wia game.iso 17179869184
zig build run -- decode-rvz-range game.rvz range.bin 1048576 65536
zig build run -- encode-wia game.iso game.wia lzma2 2097152 6
zig build run -- encode-rvz game.iso game.rvz zstd 131072 5
zig build test-wia
zig build run-wia-diff
```

The focused suite includes WIA LZMA2 and RVZ Zstandard fixtures produced by
Dolphin commit `e2ad09306e6d`. The differential exercises all ten writer modes;
when DolphinTool is available, it decodes all ten and generates five reverse
fixtures plus an RVZ junk-packed image. Use
`-- --dolphin-tool /path/to/dolphin-tool` for an explicit oracle.

Current explicit limitations are Wii partition data entries and writer-side RVZ
junk packing. Until Wii hash regeneration and AES re-encryption are implemented,
such images return `UnsupportedWiaFeature`. The writer's unpacked RVZ groups are
fully valid but can be larger than Dolphin output for images dominated by
reconstructable pseudorandom padding. Streaming file I/O and parallel group
compression also remain follow-up work.
