# Dolphin WIA and RVZ images

Vort provides a shared pure-Zig reader and deterministic writer for WIA 1.0 and
RVZ 1.0 images. This covers GameCube images, arbitrary raw disc images, and Wii
partition entries whose hash blocks and AES encryption are removed by the
container. Partition writing uses explicit caller-provided encrypted-sector
ranges and AES title keys.

Supported compression methods:

| Container | Methods |
| --- | --- |
| WIA | none, purge, Bzip2, raw LZMA1, raw LZMA2 |
| RVZ | none, Bzip2, raw LZMA1, raw LZMA2, Zstandard |

The reader validates both hashed headers, version compatibility, exact file
size, chunk geometry, compressor properties, the partition-table SHA-1,
compressed metadata extents, ordered logical data coverage, group ranges,
per-group sizes, and caller-configured memory limits. RVZ groups can override
the global codec with uncompressed storage or represent all-zero data without a
payload. RVZ junk packing is decoded, including literal segments and the
521-word lagged-Fibonacci reconstruction used by GameCube/Wii padding.

```zig
var image = try vort.parseWiaAlloc(allocator, image_bytes, .{
    .max_raw_entries = 1 << 20,
    .max_group_entries = 1 << 24,
    .max_partition_entries = 1 << 20,
    .max_partition_entry_size = 4096,
    .max_chunk_size = 64 * 1024 * 1024,
    .max_metadata_bytes = 256 * 1024 * 1024,
    .max_group_stored_bytes = 128 * 1024 * 1024,
    .max_dictionary_size = 64 * 1024 * 1024,
    .max_hash_exceptions_per_list = 52 * 64,
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

For Wii partitions, each decoded chunk begins with one or more hash-exception
lists. The reader regenerates the three-level SHA-1 tree (H0, H1, and H2),
applies those exceptions, and reconstructs each 2 MiB encrypted group with
AES-128-CBC. Both WIA-sized chunks and smaller RVZ chunks are mapped back into
the same Wii group, including exceptions from later subchunks. Range reads use
the same reconstruction path as full-image decoding.

The basic writer emits one canonical raw-data entry covering the image after
the duplicated 0x80-byte disc header. The partition-aware writer automatically
emits raw entries for gaps, decrypts each declared Wii range, derives the
minimal hash-exception lists, and stores decrypted 0x7c00-byte sector payloads.
Ranges use byte offsets and sizes in the encrypted source image and must be
0x8000-byte aligned. An optional second range must directly follow the first
and start on a 2 MiB hash-group boundary relative to it.

Metadata tables use the selected global codec. WIA compresses every non-zero
group as required by the format. RVZ stores a group uncompressed when
compression is not smaller and emits the zero-group sentinel for all-zero
chunks. Header/table SHA-1 values and all offsets are deterministic.

```zig
const rvz = try vort.encodeWiaAlloc(allocator, iso_bytes, .{
    .container = .rvz,
    .compression = .zstd,
    .compression_level = 5,
    .chunk_size = 128 * 1024,
});
defer allocator.free(rvz);
```

```zig
const partitions = [_]vort.WiaEncodePartition{.{
    .key = title_key,
    .data = .{
        .{ .offset = partition_offset, .size = partition_size },
        .{ .offset = 0, .size = 0 },
    },
}};
const partitioned_rvz = try vort.encodeWiaWithPartitionsAlloc(
    allocator,
    encrypted_iso_bytes,
    &partitions,
    .{
        .container = .rvz,
        .compression = .zstd,
        .compression_level = 5,
        .chunk_size = 128 * 1024,
    },
);
defer allocator.free(partitioned_rvz);
```

CLI and validation surface:

```sh
zig build run -- inspect-wia game.wia
zig build run -- inspect-rvz game.rvz
zig build run -- decode-wia game.wia game.iso 17179869184
zig build run -- decode-rvz-range game.rvz range.bin 1048576 65536
zig build run -- encode-wia game.iso game.wia lzma2 2097152 6
zig build run -- encode-rvz game.iso game.rvz zstd 131072 5
zig build run -- encode-rvz-partition game.iso game.rvz zstd 32768 2097152 000102030405060708090a0b0c0d0e0f 131072 5
zig build test-wia
zig build run-wia-diff
```

The focused suite includes WIA LZMA2 and RVZ Zstandard fixtures produced by
Dolphin commit `e2ad09306e6d`, plus independently generated encrypted Wii
partition fixtures. One uses WIA/Bzip2 with a 2 MiB chunk; the other uses
RVZ/none with 128 KiB chunks and places a hash exception in the fourth
subchunk. The differential exercises all ten raw-data writer modes, all ten
partition writer modes, and both partition fixtures. When DolphinTool is
available, it decodes all twenty Vort outputs and generates five reverse
fixtures plus an RVZ junk-packed image. Use
`-- --dolphin-tool /path/to/dolphin-tool` for an explicit oracle.

Current explicit limitations are automatic Wii partition discovery/title-key
derivation and writer-side RVZ junk packing. The writer's unpacked RVZ groups
are fully valid but can be larger than Dolphin output for images dominated by
reconstructable pseudorandom padding. Streaming file I/O and parallel group
compression also remain follow-up work.
