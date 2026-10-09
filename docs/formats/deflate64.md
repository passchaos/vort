# Deflate64 support

Vort provides a dependency-free Deflate64 decoder for raw streams and ZIP
method 9 entries. Deflate64 retains the stored, fixed-Huffman, and
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
```

ZIP method 9 extraction uses `decodeDeflate64Into` directly and therefore does
not require temporary allocation beyond the caller's ZIP output buffer. CRC-32
and declared uncompressed size are still verified by the ZIP container layer.

The differential suite generates method 9 archives with 7-Zip, including a
large duplicated region intended to exercise references beyond the ordinary
32 KiB Deflate window:

```sh
zig build run-zip-diff
```

Deflate64 encoding is not currently exposed. ZIP writing reports method 9 as
unsupported instead of silently emitting ordinary Deflate under the wrong
method identifier.
