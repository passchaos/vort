# LZNT1

Vort provides a dependency-free pure Zig implementation of Microsoft's LZNT1
compression format used by NTFS compressed attributes, registry data, and other
Windows system components.

The decoder validates the `0x3` chunk signature, exact payload bounds, dynamic
length/displacement token partition, match lookbehind, 4 KiB decoded chunk
limit, optional zero end marker, and nonzero trailing data. It implements the
Windows buffer rule that pads a partial chunk with zeros before a following
chunk. Decoded-size preflight, caller-owned output, bounded allocation, and
summary APIs share the same validation path.

The deterministic encoder splits input into 4 KiB chunks and uses a bounded
hash-chain greedy matcher. A chunk is stored verbatim whenever its compressed
representation is not smaller. Callers can optionally append the two-byte end
marker; unmarked buffers are the default for compatibility with
`RtlCompressBuffer`-style length-delimited use.

```zig
const encoded = try vort.encodeLznt1Alloc(allocator, input, .{});
defer allocator.free(encoded);

const size = try vort.lznt1DecodedSizeLimited(encoded, max_output);
const decoded = try vort.decodeLznt1AllocLimited(allocator, encoded, max_output);
defer allocator.free(decoded);
std.debug.assert(decoded.len == size);
```

```sh
zig build run -- encode-lznt1-file input.bin output.lznt1 no-marker
zig build run -- inspect-lznt1-file output.lznt1 67108864
zig build run -- decode-lznt1-file output.lznt1 restored.bin 67108864
zig build run-lznt1-diff
```

The differential gate checks the published MS-XCA overlapping-copy example,
deterministic self round trips, output limits, malformed streams, Vort output
decoded by Python `lznt1` 0.2, and reference output decoded by Vort. LZNT1 is a
codec rather than a self-describing archive; filesystem-level NTFS support is a
separate layer.
