# Deflate64 support

Vort provides dependency-free Deflate64 encoding and decoding for raw streams
and ZIP method 9 entries. Deflate64 retains the stored, fixed-Huffman, and
dynamic-Huffman block structure of Deflate while extending the history window
and match lengths.

The decoder implements and validates:

- stored, fixed-Huffman, and dynamic-Huffman blocks;
- all 32 distance symbols and distances through 65,536 bytes;
- length code 285 with its 16-bit extension, producing lengths through 65,538;
- dynamic code-length repeats and mandatory end-of-block symbols;
- exact input consumption in allocating APIs and ZIP extraction;
- caller-provided output capacity and allocating output limits.

```zig
const decoded = try vort.decodeDeflate64AllocLimited(
    allocator,
    compressed,
    256 * 1024 * 1024,
);
defer allocator.free(decoded);

const encoded = try vort.encodeDeflate64Alloc(allocator, input, .{});
defer allocator.free(encoded);
```

ZIP method 9 extraction uses `decodeDeflate64Into` directly and therefore does
not require temporary allocation beyond the caller's ZIP output buffer. CRC-32
and declared uncompressed size are still verified by the ZIP container layer.

The baseline encoder uses a bounded greedy matcher and chooses the smaller of
a fixed-Huffman stream and stored blocks. It emits distance codes 30 and 31 for
matches beyond the ordinary 32 KiB Deflate window. Because Deflate64 assigns a
16-bit extension to length symbol 285, the encoder represents a 258-byte match
with symbol 284 instead of emitting ordinary Deflate's incompatible code 285.
`encodeDeflate64StoredAlloc`, `encodeDeflate64StoredAppend`, and
`encodeDeflate64StoredInto` provide an explicit no-compression path;
`deflate64EncodedBound` covers both modes.

ZIP writing accepts `.method = .deflate64`, records version-needed 2.1 (or 4.5
for ZIP64), and uses the same encoder. The differential suite generates method
9 archives in both directions with 7-Zip, including a large duplicated region
intended to exercise references beyond the ordinary 32 KiB Deflate window:

```sh
zig build run-zip-diff
```

The current encoder emits fixed-Huffman or stored blocks; dynamic-tree planning
and matches longer than 258 bytes remain later compression-ratio work.
