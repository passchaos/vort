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
blocks. It builds positive, length-limited Huffman trees and compares complete
selector, code-length-description and data costs. Fixed equal-length,
global adaptive and uniform-weight candidates remain available as size bounds.
The default balanced strategy trains the standard 2...6 group count; the ratio
strategy also evaluates the other group counts. Canonical codes may use up to
20 bits, supported by the standard decoder.

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
    .strategy = .balanced,
});
defer allocator.free(encoded);
```

`Bzip2EncodeOptions.strategy` and `Bzip2IncrementalEncoder.Options.strategy`
use `Bzip2EncodeStrategy` (also `bzip2.EncodeStrategy`):

| Strategy | Encoding work | Size guarantee on identical block settings |
| --- | --- | --- |
| `fast` | Global adaptive/uniform tables and fixed fallback; no group training | No larger than the previous fixed-code encoder |
| `balanced` (default) | Four trained rounds at the standard symbol-count group thresholds, then selector-aware refinement | No larger than `fast` |
| `ratio` | Retain the balanced result and search the other group counts from 2 through 6 | No larger than `balanced` |

Strategies change Huffman coding while retaining the same RLE1/BWT block
boundaries and CRCs. They produce deterministic standard Bzip2 streams.
One-shot and incremental encoding remain byte-identical for the same strategy
when no explicit flush is requested. The [adaptive Huffman evidence](../performance/bzip2-huffman-adaptive.md)
records complete physical bit costs, bounded scratch, and measured size/speed
tradeoffs. A strategy name does not imply speed or ratio leadership over other
libraries.

For caller-driven streaming, `Bzip2IncrementalDecoder` retains compressed data
only until one complete block or member terminator can be parsed. Bzip2 block
boundaries are bit-aligned rather than byte-aligned, so the decoder carries the
remaining 0...7 bits into the next block instead of joining a complete stream:

It retains transformed BWT bytes and a persistent inverse-link table rather
than complete expanded plaintext. A first numeric traversal validates RLE
counts, output length and block CRC; a second traversal drains repeated spans
into caller output. The CRC-before-output contract is preserved.

```zig
var decoder = vort.Bzip2IncrementalDecoder.initWithOptions(allocator, .{
    .max_output_len = 256 * 1024 * 1024,
    .max_compressed_block_len = 4 * 1024 * 1024,
    .max_decoded_block_len = 64 * 1024 * 1024,
    .max_working_memory = 16 * 1024 * 1024,
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

Forward BWT sorting stops once every cyclic prefix has a unique class. Exact
whole-period blocks of at least16 bytes can instead transform their primitive
base, expand each BWT byte by the repetition count, and restore the original
stable tie rank. A conservative divisor sample bypasses KMP on clear primitive
inputs; KMP and whole-length divisibility remain the exact decision. Both paths
produce the same transformed bytes and original pointer, so this optimization
preserves complete encoded bytes under the same Huffman strategy. Generic
allocation sizes/order are unchanged; periodic blocks need far less sorting
scratch, with explicit failure cleanup. See [periodic BWT evidence](../performance/bzip2-bwt-periodic.md)
and the earlier [unique-class comparison](../performance/bzip2-bwt-unique-classes.md).

The incremental decoder additionally bounds the compressed candidate and
decoded-block length independently; the latter is a safety limit, not a
plaintext scratch allocation. It retries incomplete Huffman/BWT
parsing at exponentially growing input thresholds, avoiding a full block
reparse for every one-byte fragment. A block's CRC is verified before any byte
from that block is released. The rotated/XOR combined CRC is necessarily
verified at the member terminator after previously verified blocks may already
have been streamed, matching ordinary streaming decompressor semantics.

The `BZh` block size limits RLE1/BWT bytes. For `N` transformed bytes, first-stage
run expansion can produce up to `259 * floor(N / 5) + N % 5` bytes, so a 900000-byte
block can represent 46620000 plaintext bytes. The incremental cursor does not
allocate that plaintext length. Its working budget counts actual compressed,
transformed and 32-bit link capacities, including temporary allocation peaks;
caller buffers, fixed state and allocator bookkeeping are excluded.

Snapshots expose current/peak work bytes, link capacity, real failed-call
input/output progress and detection offsets. Fatal errors remain sticky until
reset. `reset()` retains reusable storage and restarts operation counts;
`resetWithOptions()` validates before releasing old storage and installing new
limits. The existing void reconfiguration signature records invalid options
for the following `step`.

`stop_after_first_stream` returns `.done` with zero additional progress until
`nextStream()` explicitly continues, preserving accepted suffixes, cumulative
limits, counters and peak allocation. An exact output pledge may span several
stopped members; `finish()` declares logical EOF and checks it during the final
drain. A short pledge at a stopped boundary can be completed through explicit
continuation.

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
