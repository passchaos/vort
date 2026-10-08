# Lzip (`.lz`) support

Vort provides pure Zig decoding for version-1 lzip files. Lzip wraps a
marker-terminated raw LZMA1 stream with a six-byte member header and a
20-byte integrity trailer. The implementation supports both single-member
and concatenated files.

The decoder validates:

- the `LZIP` magic, version, and coded 4 KiB through 512 MiB dictionary size;
- the fixed LZMA properties (`lc=3`, `lp=0`, `pb=2`) and mandatory end marker;
- CRC-32 of every member's uncompressed data;
- declared uncompressed size and complete member size;
- the lzip trailer consistency bounds and the prohibition on empty members in
  multimember files;
- absence of unaccounted leading, inter-member, or trailing bytes.

```zig
const info = try vort.inspectLzip(allocator, compressed);
const decoded = try vort.decodeLzipAllocWithOptions(allocator, compressed, .{
    .max_output_len = 256 * 1024 * 1024,
    .max_dictionary_size = 64 * 1024 * 1024,
});
defer allocator.free(decoded);
```

Available APIs include `parseLzipHeader`, `inspectLzip`,
`decodeLzipInto`, `decodeLzipAlloc`, `decodeLzipAllocLimited`,
`decodeLzipAllocWithOptions`, and validated decoded-size helpers. Dictionary
and output limits are checked before a member's LZMA decoder is initialized.

CLI validation surfaces:

```sh
zig build run -- inspect-lzip-file input.lz
zig build run -- decode-lzip-file input.lz output.bin 268435456 67108864
zig build run -- size-lzip-file input.lz 268435456 67108864
zig build run-lzip-diff
```

Encoding is not yet exposed. Lzip has no uncompressed/stored member mode, so a
standards-compatible writer requires an LZMA1 range encoder rather than a
container-only baseline.
