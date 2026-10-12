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

For caller-driven streaming, `Bzip2IncrementalDecoder` retains compressed data
only until one complete block or member terminator can be parsed. Bzip2 block
boundaries are bit-aligned rather than byte-aligned, so the decoder carries the
remaining 0...7 bits into the next block instead of joining a complete stream:

```zig
var decoder = vort.Bzip2IncrementalDecoder.initWithOptions(allocator, .{
    .max_output_len = 256 * 1024 * 1024,
    .max_compressed_block_len = 4 * 1024 * 1024,
    .max_decoded_block_len = 64 * 1024 * 1024,
    .expected_output_len = expected_size,
});
defer decoder.deinit();

var input_offset: usize = 0;
var output_offset: usize = 0;
while (input_offset < compressed.len) {
    const result = try decoder.step(
        compressed[input_offset..],
        output[output_offset..],
    );
    input_offset += result.progress.input_read;
    output_offset += result.progress.output_written;
}
decoder.finish();
while (true) {
    const result = try decoder.step("", output[output_offset..]);
    output_offset += result.progress.output_written;
    if (result.status == .done) break;
}
```

Available APIs:

- `encodeBzip2Alloc`, `encodeBzip2Append`, and `encodeBzip2Into`;
- `decodeBzip2Into` for caller-owned output;
- `decodeBzip2Alloc` and `decodeBzip2AllocLimited` for one stream;
- `bzip2DecodedSize` and `bzip2DecodedSizeLimited` for validated preflight;
- `decodeBzip2ConcatenatedInto`, `decodeBzip2ConcatenatedAlloc`, and its
  limited variant for concatenated streams;
- `bzip2DecodedSizeConcatenated` and its limited variant;
- `Bzip2IncrementalDecoder` for fragmented input, caller-owned output,
  concatenated members, resettable scratch, snapshots, and diagnostics;
- `Bzip2IncrementalEncoder` for block-bounded input, caller-owned output,
  explicit flush, pledged sizes, and concatenated continuation.

The allocator supplies bounded block scratch: a stream uses at most the block
size advertised by its `BZh` level for transformed bytes plus a 32-bit inverse
BWT index per transformed byte. Allocating decode APIs additionally own their
output; limited APIs reject expansion before exceeding the caller's limit.
Encoding uses a doubling cyclic suffix array, so its work memory is bounded by
the selected block size rather than total input size.

The incremental decoder additionally bounds the compressed candidate buffer
and decoded-block scratch independently. It retries incomplete Huffman/BWT
parsing at exponentially growing input thresholds, avoiding a full block
reparse for every one-byte fragment. A block's CRC is verified before any byte
from that block is released. The rotated/XOR combined CRC is necessarily
verified at the member terminator after previously verified blocks may already
have been streamed, matching ordinary streaming decompressor semantics.

`Bzip2IncrementalEncoder` provides the matching bounded encode surface. RLE1
runs are retained across input calls and committed in canonical 259-byte
groups; the BWT block ends only when the next encoded run group would exceed
the selected `BZh1`...`BZh9` block size. The partially filled MSB-first output
byte also survives caller output backpressure. Consequently, omitting `flush`
produces exactly the same bytes as one-shot encoding regardless of input and
output fragmentation.

```zig
var encoder = try vort.Bzip2IncrementalEncoder.initExactSize(allocator, .{
    .block_size_100k = 9,
    .max_input_len = 256 * 1024 * 1024,
    .max_pending_output_len = 4 * 1024 * 1024,
}, input.len);
defer encoder.deinit();

// Repeated step(input, output) calls accept and drain the stream.
// flush() closes the current BWT block without ending the stream.
// finish() emits the combined CRC and terminal marker.
```

The encoder exposes idempotent `flush`, unknown-size and exact-size
construction, `reset`, `nextStream`/`nextStreamExactSize` for concatenated
members, retained-capacity snapshots, and independent input/pending-output
limits. A flush intentionally changes block boundaries; without one, a
one-byte input/7-byte output test over a real two-block long-run corpus is
required to match one-shot wire byte-for-byte.

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

The decoder also accepts obsolete randomized blocks produced by early Bzip2
encoders. It applies the format's fixed 512-entry randomization schedule after
inverse BWT and before first-stage RLE expansion, including transformation of
the RLE count byte. A deterministic 5,000-byte fixture generated by the
official bzip2 0.1 `--repetitive-fast` path crosses multiple schedule entries
and is validated through one-shot, caller-output, size-preflight, and
one-byte-input/seven-byte-output incremental APIs plus Python `bz2`. Vort's
encoder intentionally emits the modern non-randomized representation.
