# XZ and LZMA2 support

Vort provides dependency-free XZ decoding for LZMA2 streams with optional
Delta and x86 BCJ preprocessing filters, plus a deterministic baseline writer
that stores payload bytes in uncompressed LZMA2 chunks.

The container implementation validates:

- stream magic, flags, header CRC-32, footer CRC-32, backward size, and footer
  magic;
- block headers, canonical variable-length integers, LZMA2 filter properties,
  ordered filter chains, declared packed/unpacked sizes, and zero padding;
- Index record count, per-block unpadded/uncompressed sizes, and Index CRC-32;
- block checks `none`, CRC-32, CRC-64/XZ, and SHA-256.

Normal multi-block streams and concatenated streams with four-byte-aligned
stream padding are supported. `StreamInfo` reports the check type, block count,
compressed and uncompressed sizes, and largest declared LZMA2 dictionary.
It also reports how many blocks use Delta and x86 filters.

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

The reader currently supports Delta and x86 BCJ filters followed by LZMA2. The
writer emits standards-compatible uncompressed LZMA2 chunks without a
preprocessing filter. ARM, ARM-Thumb, PowerPC, IA-64, and SPARC BCJ filters,
compressed LZMA encoding, and filter-aware writing remain later functionality
and performance work.
