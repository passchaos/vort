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

```sh
zig build run -- encode-hadoop-lz4-file input.bin output.lz4
zig build run -- inspect-hadoop-lz4-file output.lz4
zig build run -- decode-hadoop-lz4-file output.lz4 decoded.bin 536870912
```

`run-hadoop-lz4-diff` validates both directions against Python `lz4.block`
using `store_size=False`, which matches Hadoop's raw inner blocks.
