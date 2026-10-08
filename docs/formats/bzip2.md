# Bzip2 stream support

Vort provides a dependency-free, pure Zig decoder for standard `BZh1` through
`BZh9` streams. The decoder implements the complete normal block pipeline:
mapping tables, selector move-to-front decoding, two-level run coding,
canonical Huffman tables, inverse move-to-front, inverse Burrows-Wheeler
transform, and first-stage run expansion.

Every block is checked with CRC-32/BZIP2, and the rotated/XOR combined stream
CRC is verified at end-of-stream. Multi-block streams are supported. The
ordinary APIs consume exactly one stream and report `TrailingData`; explicit
concatenated APIs decode all adjacent Bzip2 streams.

```zig
const decoded_len = try vort.bzip2DecodedSizeLimited(
    allocator,
    compressed,
    64 * 1024 * 1024,
);
const output = try allocator.alloc(u8, decoded_len);
defer allocator.free(output);
_ = try vort.decodeBzip2Into(allocator, compressed, output);

const concatenated = try vort.decodeBzip2ConcatenatedAllocLimited(
    allocator,
    compressed_members,
    64 * 1024 * 1024,
);
defer allocator.free(concatenated);
```

Available APIs:

- `decodeBzip2Into` for caller-owned output;
- `decodeBzip2Alloc` and `decodeBzip2AllocLimited` for one stream;
- `bzip2DecodedSize` and `bzip2DecodedSizeLimited` for validated preflight;
- `decodeBzip2ConcatenatedInto`, `decodeBzip2ConcatenatedAlloc`, and its
  limited variant for concatenated streams;
- `bzip2DecodedSizeConcatenated` and its limited variant.

The allocator supplies bounded block scratch: a stream uses at most the block
size advertised by its `BZh` level for transformed bytes plus a 32-bit inverse
BWT index per transformed byte. Allocating decode APIs additionally own their
output; limited APIs reject expansion before exceeding the caller's limit.

CLI validation surfaces:

```sh
zig build run -- decode-bzip2-file input.bz2 output.bin 67108864
zig build run -- decode-bzip2-concat-file members.bz2 output.bin 67108864
zig build run -- size-bzip2-file input.bz2 67108864
zig build run-bzip2-diff
```

The current slice deliberately rejects the obsolete randomized-block flag.
Bzip2 encoding and ZIP method 12 integration remain follow-up functionality.
