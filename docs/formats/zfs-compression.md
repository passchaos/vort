# ZFS on-disk block compression

Vort implements the compression payloads referenced by ZFS block pointers.
This module deliberately accepts the algorithm and logical decoded size from
the caller: pool labels, uberblocks, metaslabs, DMU objects, checksums, and DVA
I/O remain separate storage-layer responsibilities.

Supported concrete algorithms are:

- uncompressed (`off`) and all-zero (`empty`) blocks;
- LZJB with the 8-token copy map, 10-bit distance, and 3...66-byte matches;
- gzip levels 1 through 9 using ZFS's zlib-wrapped DEFLATE representation;
- ZLE with the on-disk parameter 64;
- ZFS-LZ4 with a four-byte big-endian true payload length followed by raw LZ4;
- ZFS-Zstd with its eight-byte big-endian compressed-size and level/version
  header followed by a magicless Zstandard frame.

Compressed physical sizes are normally rounded to the vdev allocation unit.
All decoders therefore stop after producing the exact caller-provided logical
size and tolerate physical padding. ZFS-LZ4 and ZFS-Zstd additionally honor
their embedded true compressed lengths. Malformed matches, truncated payloads,
invalid metadata levels, size mismatches, and arithmetic overflow are rejected.

```zig
const decoded = try vort.decodeZfsBlockAllocExactSize(
    allocator,
    .lz4,
    physical_block_bytes,
    logical_size,
);
defer allocator.free(decoded);

const encoded = try vort.encodeZfsBlockAlloc(
    allocator,
    .zstd,
    logical_block,
    .{ .zstd_level = 3 },
);
defer allocator.free(encoded);
```

`zstd_level` is signed. Positive levels 1...19 retain their old behavior, while
the representable OpenZFS FAST levels are `-1...-10`, `-20...-100` in tens,
`-500`, and `-1000`. They map to unsigned on-disk enum values 103...123;
`ZstdMetadata.level` continues to report that wire value. Zero, missing fast
steps, other native negative levels and enum values passed as input are
rejected. The level/version header and physical-padding rules are preserved.
Fixed-tag mapping and bidirectional evidence are recorded in
[the Zstd controls baseline](../performance/zstd-encode-controls-functional-baseline.md).

The [explicit magicless core increment](zstd-magicless.md) routes ZFS-Zstd
encoding directly through magicless data framing,
with content-size and checksum disabled as before. Decoding borrows only the
true compressed payload selected by the ZFS header and applies exact/max decoded
size limits, removing the former whole-payload temporary copy used to prepend
four magic bytes. The eight-byte big-endian length/level/version header and
physical padding rules are unchanged. Allocating decode still returns an owned
complete plaintext buffer; this change is not a zero-allocation or RSS claim.
The completed consumer aggregate includes allocation-prohibition checks for
that compressed-copy removal. Final three-target core/consumer checks and
native/x86 reference evidence are recorded with their exact scopes in the
[magicless baseline](../performance/zstd-magicless-functional-baseline.md),
without refreshing earlier benchmark epochs.
Final feature build checks pass 185/185 on stable source. The separate
default-standard parity harness matches 96 old/new wires and does
not turn those cases into a universal ZFS or compression-performance guarantee.

The writer emits only the selected algorithm's compressed representation. If a
compressed result would not be smaller than the logical block it returns
`error.IncompressibleZfsBlock`; it never labels raw bytes as a compressed ZFS
algorithm. The storage layer can then choose `off`, round the payload to its
allocation size, and record the correct block-pointer compression ID.

Standalone LZJB and ZLE encode/decode APIs are also exported for differential
testing and callers that already manage ZFS metadata.

```sh
zig build run -- inspect-zfs-block block.bin zstd
zig build run -- decode-zfs-block block.bin decoded.bin lzjb 131072
zig build run -- encode-zfs-block decoded.bin block.bin lz4
zig build test-zfs-compression
zig build run-zfs-compression-diff
```

The checked-in LZJB fixture is generated directly by OpenZFS's
`zfs_lzjb_compress_buf`. The differential gate compiles the current OpenZFS
LZJB/ZLE functions behind a test-only probe and checks both directions. Zlib,
raw LZ4, and magicless Zstd adapters are additionally checked against Python
zlib, python-lz4, and the system zstd CLI.
