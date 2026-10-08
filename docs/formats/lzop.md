# LZOP and LZO1X support

Vort provides a pure Zig LZO1X decoder and an LZOP container implementation.
The reader accepts LZO1X-1, LZO1X-1(15), and LZO1X-999 blocks, along with raw
blocks used when compression is not beneficial. Concatenated LZOP streams are
decoded in order.

The container validates:

- the nine-byte LZOP magic and version compatibility fields;
- Adler-32 or CRC-32 header checksums, variable filenames, and extra fields;
- block sizes up to the format's 64 MiB ceiling and caller-selected limits;
- compressed and uncompressed block checksums when present;
- exact LZO1X end markers, input consumption, output size, lookbehind offsets,
  and extended run lengths;
- legacy LZOP delta filters 1 through 16.

```zig
const decoded = try vort.decodeLzopAllocWithOptions(allocator, compressed, .{
    .max_output_len = 256 * 1024 * 1024,
    .max_block_size = 16 * 1024 * 1024,
});
defer allocator.free(decoded);

const stored = try vort.encodeLzopStoredAlloc(allocator, input, .{
    .block_size = 256 * 1024,
    .checksum = .crc32,
});
defer allocator.free(stored);
```

Available APIs include standalone `decodeLzo1xInto`, LZOP header parsing and
inspection, caller-owned and bounded allocating decode, decoded-size preflight,
and deterministic stored-block alloc/append/into encoding. The writer accepts
blocks up to 256 KiB so its output is readable by default lzop installations.

CLI validation surfaces:

```sh
zig build run -- encode-lzop-stored-file input.bin output.lzo 262144 crc32
zig build run -- decode-lzop-file input.lzo output.bin 268435456 67108864
zig build run -- size-lzop-file input.lzo 268435456 67108864
zig build run -- inspect-lzop-file input.lzo
zig build run-lzop-diff
```

The current writer deliberately emits uncompressed LZOP blocks. This supplies
portable deterministic output while full LZO1X compression remains a later
ratio/performance phase. The TAR composition layer uses the same writer and
decoder for `.tar.lzo` and `.tzo` archives.
