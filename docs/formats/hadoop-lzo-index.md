# Hadoop LZO indexes

Hadoop commonly stores LZO data as a standard LZOP stream plus a sibling
`.lzo.index` file. The index contains only consecutive 8-byte big-endian file
offsets. Each offset points to an LZOP block's `uncompressed_size` field.

`parseHadoopLzoIndex` is zero-allocation and provides O(1) offset access plus a
binary-search helper. It rejects partial trailing longs and non-increasing
offsets. `validateHadoopLzoIndex` walks the LZOP stream and requires every index
offset to equal a real block boundary, including concatenated streams.

`generateHadoopLzoIndexAlloc` deterministically emits one offset per block and
honors all LZOP checksum/header flags while scanning. Compressed payload
checksums are verified during indexing.

`decodeHadoopLzoBlockRangeAlloc` decodes a caller-selected block range, applies
the optional LZOP delta filter, verifies compressed and uncompressed checksums,
and enforces an aggregate output limit.

```sh
zig build run -- create-hadoop-lzo-index data.lzo data.lzo.index
zig build run -- inspect-hadoop-lzo-index data.lzo data.lzo.index
zig build run -- extract-hadoop-lzo-blocks \
  data.lzo data.lzo.index output.bin FIRST COUNT 536870912
```

`run-hadoop-lzo-index-diff` compares generated offsets with an independent
LZOP scanner and optionally indexes streams produced by the system `lzop`.
