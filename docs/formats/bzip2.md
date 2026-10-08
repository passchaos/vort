# Bzip2 stream support

Vort provides dependency-free, pure Zig encoding and decoding for standard
`BZh1` through `BZh9` streams. The decoder implements the complete normal block pipeline:
mapping tables, selector move-to-front decoding, two-level run coding,
canonical Huffman tables, inverse move-to-front, inverse Burrows-Wheeler
transform, and first-stage run expansion.

Every block is checked with CRC-32/BZIP2, and the rotated/XOR combined stream
CRC is verified at end-of-stream. Multi-block streams are supported. The
ordinary APIs consume exactly one stream and report `TrailingData`; explicit
concatenated APIs decode all adjacent Bzip2 streams.

The deterministic encoder performs first-stage RLE, cyclic suffix-array BWT,
move-to-front and RUNA/RUNB generation, and emits canonical Huffman-coded
blocks. Its current baseline uses two identical equal-length Huffman groups;
this is fully interoperable but intentionally favors implementation coverage
over compression ratio until the later optimization phase.

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

const encoded = try vort.encodeBzip2Alloc(allocator, input, .{
    .block_size_100k = 9,
});
defer allocator.free(encoded);
```

Available APIs:

- `encodeBzip2Alloc`, `encodeBzip2Append`, and `encodeBzip2Into`;
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
Encoding uses a doubling cyclic suffix array, so its work memory is bounded by
the selected block size rather than total input size.

CLI validation surfaces:

```sh
zig build run -- decode-bzip2-file input.bz2 output.bin 67108864
zig build run -- encode-bzip2-file input.bin output.bz2 9
zig build run -- decode-bzip2-concat-file members.bz2 output.bin 67108864
zig build run -- size-bzip2-file input.bz2 67108864
zig build run-bzip2-diff
```

ZIP archives can also use method 12 for Bzip2 entries. Allocating ZIP extraction
APIs support it directly; caller-owned extraction uses
`zipExtractEntryIntoWithAllocator` because inverse BWT requires explicit scratch
allocation. The no-allocator `zipExtractEntryInto` continues to handle stored
and Deflate entries and returns `ZipEntryRequiresAllocator` for method 12.

The current decoder deliberately rejects the obsolete randomized-block flag.
