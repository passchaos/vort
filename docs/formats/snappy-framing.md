# Snappy framed, Xerial and Hadoop streams

Vort supports two ecosystem-specific Snappy stream formats in addition to the
standard Snappy framed stream and raw Snappy blocks.

## Standard framed streams

`SnappyIncrementalFrameDecoder` validates the identifier and each complete raw
chunk before publication. Compressed data additionally passes masked CRC-32C
validation through a cursor scan, then replays tokens into caller output using
the same history ring. No complete decoded-chunk heap is retained. Verified
uncompressed chunks drain directly from their owned encoded payload; identifier
and skippable data use fixed/direct processing, including large metadata with
no payload-sized allocation.

The standard decoded-chunk maximum remains 64 KiB. `max_output_len` and the
exact pledge retain member scope; `max_total_output_len` and
`max_working_memory` persist across `nextStream` and can only tighten. A new
limit below published totals or retained capacity is rejected before changing
state. `reset()` begins a new operation while retaining scratch, and explicit
reconfiguration validates before releasing old storage. Terminal parser and
allocation errors are sticky; a rejected partial `finish()` can still receive
the missing input.

Snapshots report combined member output, actual failed-call progress, detection
offsets and live/peak requested work bytes. The output returned in each `step`
is caller-owned; fixed state, stack scan buffers and capture buffers are outside
the requested-heap budget. Pure numeric cursors and current allocator arguments
allow active decoder values to move while retaining single ownership.

## Xerial Snappy

`parseXerialSnappy` validates the 16-byte `0x82SNAPPY\0` version-1 header and
every big-endian compressed-chunk length. Each chunk must be one complete raw
Snappy block, including its own decoded-size varint.

`encodeXerialSnappyAlloc`, append, and into APIs split input into independently
compressed blocks; the default block size is 32 KiB. Bounded and caller-owned
decoders preflight all raw block sizes before output.

## Hadoop Snappy

Hadoop `BlockCompressorStream` framing has no magic. Every outer block begins
with a big-endian total uncompressed length and contains one or more
big-endian-length-prefixed raw Snappy blocks. Vort validates that nested chunk
output sums exactly to the outer length, preventing a corrupt chunk from
shifting the next block boundary.

`encodeHadoopSnappyAlloc`, append, and into APIs default to 256 KiB outer blocks
and 64 KiB raw Snappy chunks. Bounded and caller-owned decode APIs expose the
same limits as Xerial framing.

## Incremental encoding and decoding

`XerialSnappyIncrementalEncoder` and `HadoopSnappyIncrementalEncoder` provide
the matching caller-input/caller-output write path. Xerial publishes each
completed independent chunk immediately. Hadoop compresses inner chunks into
one bounded pending outer block, then writes its final uncompressed-size prefix
before exposing any bytes from that block. Without `flush`, arbitrary caller
fragmentation produces exactly the same bytes as the corresponding one-shot
encoder. `flush` explicitly closes the current Xerial chunk or Hadoop outer
block; repeated empty flushes are idempotent.

Encoder options bound accepted input and pending output, support an exact input
pledge, and retain plain/encoded/pending scratch across reset. Both formats
handle zero-output backpressure; Xerial empty input still emits its version-1
header, while Hadoop empty input remains an empty stream.

`XerialSnappyIncrementalDecoder` and `HadoopSnappyIncrementalDecoder` share a
caller-output state machine while preserving their different framing rules.
Headers and compressed chunks may cross arbitrary input calls. Complete raw
chunks are validated before output; a shared token cursor then drains literal
and copy spans through arbitrary caller slices. It retains a history ring based
on the largest validated copy distance rather than complete plaintext. Hadoop
tracks validated decoded length separately from published caller output, so a
complete final chunk may still be waiting to drain when `finish()` is called.

```zig
var decoder = vort.XerialSnappyIncrementalDecoder.initWithOptions(allocator, .{
    .max_compressed_chunk_len = 1024 * 1024,
    .max_decoded_chunk_len = 1024 * 1024,
    .max_output_len = expected_size,
    .max_working_memory = 16 * 1024 * 1024,
    .expected_output_len = expected_size,
});
defer decoder.deinit();

// Repeated step(input, output) calls consume framing and drain plaintext.
// finish() accepts only a complete chunk/outer-block boundary.
```

Both decoders expose retained-capacity snapshots, phase diagnostics, and reset
without reallocating established scratch. Compressed raw Snappy chunks remain
input-atomic so their decoded-size varint and copy stream are validated before
any bytes from that chunk reach the caller.

`max_working_memory` bounds live requested compressed/history allocations and
their transient old/new peaks. `max_output_len` remains cumulative across the
whole Xerial/Hadoop operation, including all Hadoop inner chunks. Failed-call
input/output progress and error offsets are exposed; fatal parser or allocation
errors have zero-progress sticky retries until reset. Reset retains capacity,
while valid explicit reconfiguration releases old owned storage through its
original budget.

Raw COPY4 distances are unsigned 32-bit values. They must refer to an already
decoded prefix but have no format-wide 64 KiB limit. The maximum-distance ring
can therefore approach a large Xerial/Hadoop chunk's decoded length; the work
budget remains the caller's allocation limit. Standard Snappy framed data
chunks separately retain their 64 KiB decoded limit and masked CRC-32C
verification before publication. No new dictionary or flush semantics are
imposed on these formats.

```sh
zig build run -- encode-xerial-snappy-file input.bin output.snappy
zig build run -- encode-xerial-snappy-incremental-file input.bin output.snappy 32768 17 31
zig build run -- decode-xerial-snappy-file output.snappy decoded.bin 536870912
zig build run -- decode-xerial-snappy-incremental-file output.snappy decoded.bin 1048576 17 31
zig build run -- inspect-xerial-snappy-file output.snappy

zig build run -- encode-hadoop-snappy-file input.bin output.snappy
zig build run -- encode-hadoop-snappy-incremental-file input.bin output.snappy 262144 65536 17 31
zig build run -- decode-hadoop-snappy-file output.snappy decoded.bin 536870912
zig build run -- decode-hadoop-snappy-incremental-file output.snappy decoded.bin 1048576 17 31
zig build run -- inspect-hadoop-snappy-file output.snappy
```

`run-snappy-framing-diff` requires incremental encoding to match one-shot bytes
and performs deterministic/self validation through both decode paths. When an
Xerial `snappy-java` jar is supplied, it runs Xerial and Hadoop streams in both
directions through the Java implementation, decodes Vort incremental output in
Java, and feeds Java-produced streams through the 17-byte-input / 31-byte-output
incremental decoder.
