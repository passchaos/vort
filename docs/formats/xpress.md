# XPRESS

Vort provides dependency-free pure Zig support for the plain LZ77 and
LZ77+Huffman variants of Microsoft XPRESS. These codecs are used by Windows
system formats and form the compression layer for later WIM, WOF, and related
container support.

The decoder implements 32-bit little-endian flag words consumed most-significant
bit first, 13-bit match offsets, overlapping byte copies, and the shared
half-byte plus byte/u16/u32 extended-length ladder. It validates every input
read, output addition, offset, and invalid wide length. Decoded-size
preflight, caller-owned output, bounded allocation, and summaries use the same
parser.

The deterministic encoder uses an 8 KiB bounded hash-chain matcher. It emits a
terminal match flag at input exhaustion and selects the canonical shortest
length representation, including the shared low/high extension nibbles. It
reproduces the published MS-XCA encoding of `abc` repeated 100 times byte for
byte.

XPRESS-Huffman operates on independently sized blocks of at most 64 KiB. Each
block carries a packed 256-byte table of 512 canonical code lengths. Vort builds
an adaptive length-limited table, emits literal and match symbols with up to 16
offset bits, interleaves raw extended-length bytes with little-endian 16-bit
coding units, and writes the compatibility EOF symbol. Decoding requires the
exact output size, matching wimlib and WIM resource metadata semantics.

```zig
const encoded = try vort.encodeXpressPlainAlloc(allocator, input, .{});
defer allocator.free(encoded);

const summary = try vort.xpressSummarizePlainLimited(encoded, max_output);
const decoded = try vort.decodeXpressPlainAllocLimited(
    allocator,
    encoded,
    max_output,
);
defer allocator.free(decoded);
std.debug.assert(decoded.len == summary.decoded_size);

const huffman_encoded = try vort.encodeXpressHuffmanAlloc(allocator, input, .{});
defer allocator.free(huffman_encoded);
const huffman_decoded = try vort.decodeXpressHuffmanAllocExactSize(
    allocator,
    huffman_encoded,
    input.len,
);
defer allocator.free(huffman_decoded);
```

```sh
zig build run -- encode-xpress-plain-file input.bin output.xpress
zig build run -- inspect-xpress-plain-file output.xpress 67108864
zig build run -- decode-xpress-plain-file output.xpress restored.bin 67108864
zig build run -- encode-xpress-huffman-file input.bin output.xpress-huff
zig build run -- inspect-xpress-huffman-file output.xpress-huff 65536
zig build run -- decode-xpress-huffman-file output.xpress-huff restored.bin 65536
zig build run-xpress-diff
```

The differential gate covers all three published MS-XCA vectors, deterministic
self round trips, extension-length tiers, malformed streams, and output limits.
The independent `xpress-lz77` 1.0.1 Rust/Python module decodes both Vort modes;
pinned wimlib independently decodes Vort Huffman output and supplies Huffman
blocks that Vort decodes. Files larger than 64 KiB remain a container concern:
WIM and WOF split them into independently sized XPRESS blocks. Vort's WOF
module now parses and writes the cumulative chunk table and uses this same
XPRESS-Huffman implementation for XPRESS4K, XPRESS8K, and XPRESS16K.
