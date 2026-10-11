# CHD v5 images

Vort reads common MAME CHD v5 images and writes deterministic baseline CHD v5
images in pure Zig. The library is path-independent: callers supply the image
bytes and, for a delta image, an already-opened parent archive explicitly.

The reader supports:

- the fixed 124-byte big-endian v5 header, raw and combined SHA-1 fields, and
  parent identity validation;
- simple uncompressed maps and entropy-coded v5 maps, including canonical
  Huffman type trees, small/large RLE, data offsets, CRC-16, and self/parent
  delta forms;
- raw hunks plus the `zlib` (raw DEFLATE), raw LZMA1, byte-Huffman, and standard
  Zstandard codecs;
- backward self references and unit-addressed parent references, including a
  parent range that crosses a hunk boundary;
- linked metadata records with four-byte tags, flags, cycle detection, and
  explicit entry-count limits;
- bounded whole-image and random-range decoding with per-hunk CRC-16 and final
  raw SHA-1 verification.

```zig
var parent = try vort.parseChdAlloc(allocator, parent_bytes, .{});
defer parent.deinit();

var image = try vort.parseChdAlloc(allocator, child_bytes, .{
    .parent = &parent,
    .verify_checksums = true,
    .max_hunks = 1 << 24,
    .max_expanded_map_bytes = 256 * 1024 * 1024,
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

The writer modes are `none`, `zlib`, `lzma`, `huffman`, `zstd`, and `auto`.
`none` emits the simple u32 map, hunk-aligned raw data, and sparse zero hunks.
The compressed modes emit a v5 compressed map and backward self references for
duplicate hunks. A forced codec is retained whenever its payload fits the CHD
hunk limit; `auto` tests all four codecs per hunk and records the smallest only
when it beats raw storage. All modes use raw fallback for larger incompressible
output. The last hunk is padded with zeros for codec and CRC purposes while the
header and raw SHA-1 retain the caller's exact logical length. The overall
SHA-1 is the CHD-defined SHA-1 of the raw digest when no checksummed metadata
is present.

`compression_level` is used by zlib and Zstandard. Zlib and `auto` accept
levels 0...9; forced Zstandard accepts 0...22. LZMA and Huffman currently use
their deterministic built-in planning policies.

```zig
const encoded = try vort.encodeChdAlloc(allocator, raw_disk, .{
    .compression = .auto,
    .hunk_bytes = 4096,
    .unit_bytes = 512,
    .compression_level = 6,
});
defer allocator.free(encoded);
```

CLI validation surface:

```sh
zig build run -- inspect-chd image.chd parent.chd
zig build run -- decode-chd image.chd image.raw 1073741824 parent.chd
zig build run -- decode-chd-range image.chd range.raw 1048576 65536 parent.chd
zig build run -- encode-chd disk.raw image.chd auto 4096 512 6
zig build test-chd
zig build run-chd-diff
```

Pinned `chdman 0.289` fixtures cover LZMA, Huffman, Zstandard, raw fallback,
self references, checked hard-disk metadata, aligned parent hunks, and
unit-shifted parent ranges that cross hunk boundaries.
The differential always checks those fixtures and Vort's six writer modes.
When `chdman` is installed, it verifies and extracts Vort output, then creates
fresh none/zlib/LZMA/Huffman/Zstandard and parent images for Vort to decode.
Use `-- --chdman /path/to/chdman` to select a non-system binary.

Vort currently rejects CHD v1--v4, FLAC, CD frontends (`cdzl`, `cdlz`, `cdfl`,
`cdzs`), and A/V Huffman rather than silently mis-decoding them. The baseline
writer does not yet emit metadata, parent deltas, or RLE-compressed map type
runs. These are explicit compatibility and ratio follow-ups; they are not
claimed as supported combinations.
