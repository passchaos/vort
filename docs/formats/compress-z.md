# Unix compress (`.Z`) support

Vort provides pure Zig encoding and decoding for the historic Unix
`compress` LZW stream format. Streams use the standard `1f 9d` magic,
LSB-first variable-width codes, 9 through 16 maximum code bits, and optional
block mode with code 256 reserved for dictionary clears.

The implementation preserves the format's unusual packing rule: code-width
changes and block-mode clears advance to the next boundary of eight codes at
the old width. This is required for interoperability with ncompress and Unix
`uncompress` implementations.

```zig
const header = try vort.parseCompressZHeader(compressed);
const decoded = try vort.decodeCompressZAllocLimited(
    allocator,
    compressed,
    64 * 1024 * 1024,
);
defer allocator.free(decoded);

const encoded = try vort.encodeCompressZAlloc(allocator, input, .{
    .max_code_bits = 16,
    .block_mode = true,
});
defer allocator.free(encoded);
```

Available APIs:

- `parseCompressZHeader` returns the maximum code width and block-mode flag;
- `encodeCompressZAlloc`, `encodeCompressZAppend`, and
  `encodeCompressZInto` provide deterministic encoding;
- `decodeCompressZInto`, `decodeCompressZAlloc`, and
  `decodeCompressZAllocLimited` decode one stream;
- `CompressZIncrementalDecoder` performs bit-progressive caller-output decode;
- `compressZDecodedSize` and `compressZDecodedSizeLimited` provide validated
  decoded-size preflight.

The incremental decoder retains a bounded prefix/suffix dictionary and one
current reversed string, not the compressed stream or decoded output. It
supports every 9...16-bit maximum, block-mode clear codes, non-block dictionary
freeze, arbitrary input/output splits and exact output pledges. Width changes
and clears are represented as resumable alignment states, preserving the
eight-code group rule across byte boundaries. Because `.Z` has no terminator,
callers must call `finish()` at physical EOF; fewer than eight unused tail bits
are valid, while an incomplete full byte fails as `TruncatedFrame`.

`TarCompressZIncrementalReader` connects this state machine directly to the
bounded TAR reader without materializing the decompressed archive.

The encoder clears a full dictionary immediately in block mode. This differs
from ncompress's adaptive ratio heuristic but produces standard streams and
keeps output deterministic. Non-block mode freezes a full dictionary instead.

CLI validation surfaces:

```sh
zig build run -- encode-compress-z-file input.bin output.Z 16 block
zig build run -- decode-compress-z-file input.Z output.bin 67108864
zig build run -- size-compress-z-file input.Z 67108864
zig build run-compress-z-diff
```

The `.Z` format has no end marker, declared uncompressed size, or checksum.
Consequently, some tail truncations are indistinguishable from a valid stream.
Use a limited decode API for untrusted input and an outer integrity mechanism
when corruption detection is required.
The required differential exercises seven Vort corpus streams through one-byte
and micro schedules (`incremental_cases=7`) and has system `uncompress` verify
all Vort output. A fixed ncompress 5.0 stream independently covers external
LSB code packing when a system `compress` encoder is unavailable.
