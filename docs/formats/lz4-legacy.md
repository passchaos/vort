# LZ4 legacy frames

Vort supports the original LZ4 frame format identified by little-endian magic
`0x184c2102`. This format is still exposed by `lz4 -l` and is used by some
older Linux and boot-image workflows.

The wire format contains the four-byte magic followed by independent blocks.
Each block has a four-byte little-endian compressed length and a raw LZ4 block
payload. Blocks decode to at most 8 MiB. The legacy format has no content size,
end marker, checksum, dictionary identifier, or uncompressed-block flag; EOF is
the only stream terminator, so concatenation cannot be distinguished from
trailing data.

`parseLz4Legacy` and `parseLz4LegacyLimited` validate every raw block without
allocating. The returned archive provides aggregate block/decoded sizes and a
zero-allocation block iterator. Encoders split input into caller-selected
independent blocks up to 8 MiB. Decoders provide exact caller-owned output and
bounded allocating APIs.

`Lz4LegacyIncrementalDecoder` parses arbitrary input splits, retains at most
one explicitly limited compressed block and one decoded block, and drains it
under caller output backpressure. Because the wire has no end marker, callers
must call `finish()` at EOF; partial length fields and payloads then fail as
`TruncatedFrame`. Total-output, compressed-block, decoded-block and optional
exact-output limits are checked before a block is exposed.

```sh
zig build run -- encode-lz4-legacy-file input.bin output.lz4 8388608
zig build run -- inspect-lz4-legacy-file output.lz4 536870912
zig build run -- decode-lz4-legacy-file output.lz4 restored.bin 536870912
zig build run-lz4-legacy-diff
```

Automatic TAR and CPIO compression detection accepts both modern and legacy
LZ4 frame magic. Writers continue to emit the modern checksummed LZ4 frame by
default because the legacy format cannot verify content integrity.
`TarLz4LegacyIncrementalReader` is the explicit bounded TAR composition path;
`TarLz4IncrementalReader` continues to mean the modern LZ4 frame format.
