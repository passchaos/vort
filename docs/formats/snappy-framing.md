# Xerial and Hadoop Snappy framing

Vort supports two ecosystem-specific Snappy stream formats in addition to the
standard Snappy framed stream and raw Snappy blocks.

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
Headers and compressed chunks may cross arbitrary input calls, decoded chunks
drain through arbitrary output slices, and zero-length output provides normal
backpressure. Hadoop outer-block progress commits only after a raw Snappy chunk
has decoded successfully, so allocation failure does not commit structural
progress before reset.

```zig
var decoder = vort.XerialSnappyIncrementalDecoder.initWithOptions(allocator, .{
    .max_compressed_chunk_len = 1024 * 1024,
    .max_decoded_chunk_len = 1024 * 1024,
    .max_output_len = expected_size,
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
