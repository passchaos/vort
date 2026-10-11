# Apple DMG/UDIF and ADC

Vort reads Apple Universal Disk Image Format (`.dmg`) files and writes
deterministic single-partition images in pure Zig. No `hdiutil`, framework, C
binding, or platform-specific API is used by the library.

The reader supports:

- 512-byte `koly` trailers at the end or front of the image;
- bounded XML property-list parsing of `resource-fork` / `blkx` metadata;
- strict Base64 and `mish` block-map parsing;
- zero-fill types 0 and 2, raw copy type 1, Apple ADC type `0x80000004`, zlib,
  Bzip2, LZFSE, and XZ chunk types;
- data-fork, master, and per-partition CRC-32 verification;
- whole-partition extraction and range decoding that touches only overlapping
  compressed blocks;
- caller-selected XML, partition-count, block-count, decoded-block, and output
  limits.

Optional code-signature offsets are ignored only when out of range because old
DMGs are observed with garbage in that field. Required data, XML, block-map,
and packed-data ranges remain strict. Segmented images and old images whose
block maps exist only in the resource fork are reported as unsupported;
FileVault v2's `encrcdsa` signature returns `error.EncryptedDmg`. Current
unencrypted XML-backed UDIF images are supported.

```zig
var image = try vort.parseDmgAlloc(allocator, dmg_bytes, .{
    .max_xml_bytes = 64 * 1024 * 1024,
    .max_block_decoded_bytes = 256 * 1024 * 1024,
    .max_xz_dictionary_bytes = 256 * 1024 * 1024,
});
defer image.deinit();

const partition = try image.decodePartitionAllocLimited(
    allocator,
    partition_index,
    max_output,
);
defer allocator.free(partition);

const range = try image.decodePartitionRangeAllocLimited(
    allocator,
    partition_index,
    offset,
    length,
    max_range_output,
);
defer allocator.free(range);
```

The writer accepts sector-aligned input and emits one partition split into
caller-selected sector-aligned blocks. It supports copy, ADC, zlib, Bzip2,
LZFSE, and XZ. Zero blocks are represented sparsely, and the default policy
uses copy chunks when compression does not reduce size. The initial ADC writer
uses literal commands only; match finding is future ratio work, while decoding
already supports literal, two-byte match, and three-byte match commands.

```zig
const encoded = try vort.encodeDmgAlloc(allocator, raw_disk, .{
    .compression = .zlib,
    .block_size = 1024 * 1024,
    .name = "Apple_HFS",
});
defer allocator.free(encoded);
```

CLI validation surface:

```sh
zig build run -- inspect-dmg image.dmg
zig build run -- decode-dmg-partition image.dmg partition.raw 4 1073741824
zig build run -- decode-dmg-range image.dmg range.raw 4 1048576 65536
zig build run -- encode-dmg partition.raw image.dmg zlib 1048576 fallback
zig build test-apple-adc
zig build test-dmg
zig build run-dmg-diff
```

The checked-in compatibility fixture was produced by Apple's `hdiutil` and
contains GPT metadata, sparse ranges, and a zlib-compressed HFS partition. Its
decoded partition SHA-256 is pinned against both 7-Zip and dmg2img. The
differential gate also has 7-Zip decode every writer codec and has dmg2img
decode copy, ADC, zlib, and Bzip2 images.
