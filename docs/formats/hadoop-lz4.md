# Hadoop LZ4 framing

Vort supports the `BlockCompressorStream` representation used by Hadoop's
`Lz4Codec`. The framing is structurally similar to Hadoop Snappy, but each
inner payload is a raw LZ4 block without an embedded decoded-size prefix.

Every outer block begins with a big-endian total uncompressed length. It then
contains one or more big-endian compressed lengths followed by raw LZ4 blocks.
`parseHadoopLz4` scans every LZ4 token stream to derive the actual decoded chunk
size and requires their checked sum to equal the outer length exactly.

`encodeHadoopLz4Alloc`, append, and into APIs default to 256 KiB outer blocks
and 64 KiB chunks. `decodeHadoopLz4AllocLimited` and caller-owned decode enforce
the aggregate bound before output.

`HadoopLz4IncrementalEncoder` and `HadoopLz4IncrementalDecoder` provide the
matching caller-input/caller-output streaming surface. They reuse the same
outer-block state machine as Hadoop Snappy while injecting Vort's reusable raw
LZ4 block encoder, token-derived decoded-size scanner, and caller-buffer block
decoder. The encoder retains one bounded outer block until its final
uncompressed length can be written; without `flush`, arbitrary fragmentation
is byte-exact with one-shot output. `flush` explicitly closes the current outer
block and repeated empty flushes are idempotent.

Options bound input, pending encoded output, compressed chunk retention,
decoded chunk scratch, aggregate output, and optional exact input/output sizes.
Both directions support zero-output backpressure, retained-capacity reset,
snapshots, and malformed/truncated outer-block diagnostics.

```zig
var encoder = try vort.HadoopLz4IncrementalEncoder.initExactSize(allocator, .{
    .block_size = 256 * 1024,
    .chunk_size = 64 * 1024,
    .max_pending_output_len = 4 * 1024 * 1024,
}, input.len);
defer encoder.deinit();

var decoder = vort.HadoopLz4IncrementalDecoder.initWithOptions(allocator, .{
    .max_output_len = input.len,
    .expected_output_len = input.len,
});
defer decoder.deinit();
```

```sh
zig build run -- encode-hadoop-lz4-file input.bin output.lz4
zig build run -- encode-hadoop-lz4-incremental-file input.bin output.lz4 262144 65536 17 31
zig build run -- inspect-hadoop-lz4-file output.lz4
zig build run -- decode-hadoop-lz4-file output.lz4 decoded.bin 536870912
zig build run -- decode-hadoop-lz4-incremental-file output.lz4 decoded.bin 1048576 17 31
```

`run-hadoop-lz4-diff` validates both directions against Python `lz4.block`
using `store_size=False`, which matches Hadoop's raw inner blocks. It also
requires incremental encoding to match one-shot bytes, decodes that output in
Python, and sends both Vort- and Python-generated streams through the
17-byte-input / 31-byte-output incremental decoder.
