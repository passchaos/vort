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

```sh
zig build run -- encode-xerial-snappy-file input.bin output.snappy
zig build run -- decode-xerial-snappy-file output.snappy decoded.bin 536870912
zig build run -- inspect-xerial-snappy-file output.snappy

zig build run -- encode-hadoop-snappy-file input.bin output.snappy
zig build run -- decode-hadoop-snappy-file output.snappy decoded.bin 536870912
zig build run -- inspect-hadoop-snappy-file output.snappy
```

`run-snappy-framing-diff` performs deterministic/self validation and, when an
Xerial `snappy-java` jar is supplied, runs Xerial and Hadoop streams in both
directions through the Java implementation.
