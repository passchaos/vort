# LZX encoding and decoding

Vort exposes the shared pure-Zig LZX codec through `vort.lzx` and root aliases.
It supports CAB's stream framing and independent WIM/WOF chunks, with explicit
15...21-bit windows (32 KiB through 2 MiB), verbatim/aligned/uncompressed blocks,
2...257-byte matches, secondary length codes and all three repeat-offset slots.
Adaptive complete Huffman trees use modulo-17 previous-length deltas and pretree
zero/equal-length run symbols. An empty secondary-length tree remains legal.

```zig
const encoded = try vort.encodeLzxAlloc(allocator, input, .{
    .window_bits = 16,
    .format = .cabinet,
});
defer allocator.free(encoded);
const decoded = try vort.decodeLzxAllocLimited(
    allocator, encoded, input.len, output_limit, .{ .window_bits = 16 },
);
defer allocator.free(decoded);
```

`encodeLzxInto` and `encodeLzxAppend` have transactional caller-output semantics.
`decodeLzxInto` writes into caller-owned exact-size output and may leave a
decoded prefix on a malformed stream. The caller supplies the decoded size and
the exact format/window because raw LZX has no self-contained size/window
header. `decodeLzxAllocLimited` rejects a requested size beyond the caller's
output budget before allocation. CAB empty streams encode to an empty slice;
independent WIM chunks must be nonempty and fit their selected window.

`LzxCabinetEncoder.init(window_bits)` returns caller-owned tree/recent-offset
state. `encodeBlockAlloc(allocator, input, start, end)` borrows a complete input
prefix and returns owned bytes. Calls must have contiguous offsets; a block is
at most 32 KiB and only the final frame may be shorter. Continuing after a
partial frame is rejected. `encodeBlockWithSummaryAlloc` additionally returns
the selected block type, matched bytes, repeat-match count and maximum offset;
release this result with `deinit(allocator)`. Failed allocation leaves state
unchanged. Compressed and raw frame transitions retain valid tree/recent state.
The CAB encoder disables the optional Intel E8 stream transform, keeping the
input bytes unchanged while remaining interoperable with CAB decoders.

WIM encoding applies its mandatory whole-chunk E8 transform and keeps bit
packing continuous across the 32 KiB plans inside larger chunks. It compares
the complete output with `lzx.encodeWimReferenceChunkAlloc`, retaining the old
short-match reference if smaller. CAB selects compressed or raw by complete
frame bytes. WIM and WOF containers then choose compressed or raw per chunk.
The same core is used by ordinary, split and pipable WIM resources and WOF
random-range decoding; CAB sets can split compressed CFDATA across parts.

The matcher uses a two-byte latest-position table and a three-byte anchor/latest
table, requesting 512 KiB of hash storage. Item plans are bounded to 32 KiB.
CAB borrows history rather than owning a stream-sized link list. One-shot
WIM encoding additionally owns transformed input and candidate/reference bytes;
its memory therefore scales with the selected chunk. This is a functional
greedy encoder; deeper/optimal parsing, compression levels, persistent hash
reuse, throughput and reference-memory comparisons remain open.

```sh
zig build test-lzx test-cab test-wof test-wim
zig build run-lzx-match-diff -Doptimize=ReleaseFast -- \
  --wimlib-dir /path/to/pinned-wimlib \
  --mspack-dir /path/to/libmspack --report /tmp/lzx-matches.json
zig build run-cab-diff
zig build run-wim-diff -- --wimlib-imagex /path/to/wimlib-imagex
```

The dedicated differential independently decodes matched CAB frames through
libarchive and unmodified libmspack, WIM chunks through unmodified wimlib, and
every compressed WOF chunk through wimlib. It exercises every window, tiny and
partial chunks, aligned offsets, cross-frame raw/compressed transitions,
mandatory E8 handling, a full 2 MiB WIM chunk, determinism, reference-wire size
arbitration and compressed CAB sets with 2 KiB part limits. See the retained
[functional size evidence](../performance/lzx-match-functional-baseline.md).
