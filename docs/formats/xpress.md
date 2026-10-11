# XPRESS

Vort provides dependency-free pure Zig support for the plain LZ77 variant of
Microsoft XPRESS. This codec is used by Windows system formats and is the
foundation for later WIM, WOF, and related container support.

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
```

```sh
zig build run -- encode-xpress-plain-file input.bin output.xpress
zig build run -- inspect-xpress-plain-file output.xpress 67108864
zig build run -- decode-xpress-plain-file output.xpress restored.bin 67108864
zig build run-xpress-diff
```

The differential gate covers the official MS-XCA vector, deterministic self
round trips, all extension-length tiers, malformed streams, output limits, and
Vort output decoded by the independent `xpress-lz77` 1.0.1 Rust/Python module.
XPRESS Huffman uses a different wire representation and remains a separate
follow-up rather than being treated as plain XPRESS.
