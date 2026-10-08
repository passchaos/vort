# XZ and LZMA2 support

Vort provides dependency-free XZ decoding for the common single-filter LZMA2
pipeline, plus a deterministic baseline writer that stores payload bytes in
uncompressed LZMA2 chunks.

The container implementation validates:

- stream magic, flags, header CRC-32, footer CRC-32, backward size, and footer
  magic;
- block headers, canonical variable-length integers, LZMA2 filter properties,
  declared packed/unpacked sizes, and zero padding;
- Index record count, per-block unpadded/uncompressed sizes, and Index CRC-32;
- block checks `none`, CRC-32, CRC-64/XZ, and SHA-256.

Normal multi-block streams and concatenated streams with four-byte-aligned
stream padding are supported. `StreamInfo` reports the check type, block count,
compressed and uncompressed sizes, and largest declared LZMA2 dictionary.

```zig
const info = try vort.inspectXz(allocator, compressed);
const decoded = try vort.decodeXzAllocLimited(
    allocator,
    compressed,
    256 * 1024 * 1024,
);
defer allocator.free(decoded);

const encoded = try vort.encodeXzStoredAlloc(allocator, input, .{
    .check = .crc64,
    .block_size = 1024 * 1024,
});
defer allocator.free(encoded);
```

Available decoding forms include caller-owned output, bounded allocation,
validated decoded-size preflight, and explicit concatenated-stream variants.
The writer provides alloc, transactional append, and caller-owned output APIs.

CLI validation surfaces:

```sh
zig build run -- encode-xz-stored-file input.bin output.xz crc64 1048576
zig build run -- decode-xz-file input.xz output.bin 268435456
zig build run -- decode-xz-concat-file streams.xz output.bin 268435456
zig build run -- size-xz-file input.xz 268435456
zig build run -- inspect-xz-file input.xz
zig build run-xz-diff
```

The current reader deliberately rejects filter chains with BCJ or Delta
filters and accepts only a single LZMA2 filter. The writer emits standards-
compatible uncompressed LZMA2 chunks; compressed LZMA encoding and additional
filters remain later functionality and performance work.
