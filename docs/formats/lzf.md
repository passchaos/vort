# LZF block and ZV stream support

Vort provides a dependency-free pure Zig implementation of Marc Lehmann's LZF
byte format and the `ZV` block stream used by the upstream `lzf` utility. The
codec is library-first and does not require liblzf at runtime.

Raw LZF blocks use literal runs of 1...32 bytes and overlapping LZ matches of
3...264 bytes with distances of 1...8192 bytes. The decoder validates every
literal extent, match token, backward distance, input boundary, output bound,
and integer addition. `lzfBlockDecodedSize` performs the same structural pass
without materializing output.

The framed stream supports both defined data block types:

- `ZV 00`, followed by a big-endian 16-bit size and stored bytes;
- `ZV 01`, followed by big-endian compressed and uncompressed 16-bit sizes and
  one raw LZF block.

Streams may contain any number of blocks and may end with the optional zero EOF
marker accepted by the reference utility. Vort requires that marker to be the
last byte. Compressed blocks must decode to their declared size, stored blocks
must be complete, and every input byte must belong to a block or the final EOF
marker. The upstream-reserved type 2 CRC record remains explicitly unsupported;
ordinary LZF streams have no content checksum.

The deterministic writer splits input into configurable 1...65,535-byte blocks,
uses a bounded latest-match hash table, and selects compressed representation
only when the complete type-1 block is smaller than type 0. `LzfEncodeOptions`
also controls the optional EOF marker. Allocating, caller-owned, transactional
append, encoded-bound, decoded-size, bounded decode, and metadata inspection
APIs are exposed for both raw blocks and framed streams.

`LzfIncrementalDecoder` accepts arbitrary compressed input slices and drains
decoded bytes through caller-owned output. Stored payloads copy directly;
compressed records retain at most one explicitly limited 65,535-byte input
block and its validated decoded block. Independent compressed/decoded block,
total-output and expected-output limits apply before output becomes visible.
EOF is valid at a block boundary, while the optional zero marker must still be
the last encoded byte. Snapshots expose retained capacities and exact progress.

```zig
const encoded = try vort.encodeLzfAlloc(allocator, input, .{
    .block_size = 32 * 1024,
    .eof_marker = false,
});
defer allocator.free(encoded);

const info = try vort.inspectLzf(encoded);
const decoded = try vort.decodeLzfAllocLimited(
    allocator,
    encoded,
    64 * 1024 * 1024,
);
defer allocator.free(decoded);
```

TAR composition recognizes and writes `.tar.lzf` through
`TarCompression.lzf`. Automatic detection uses the unambiguous `ZV` signature
after first checking for a structurally valid raw TAR.
`TarLzfIncrementalReader` connects this decoder to the bounded TAR state
machine without retaining the decompressed archive.

CLI validation surfaces:

```sh
zig build run -- encode-lzf-file input.bin output.lzf 65535 no-eof
zig build run -- decode-lzf-file output.lzf decoded.bin 67108864
zig build run -- size-lzf-file output.lzf 67108864
zig build run -- inspect-lzf-file output.lzf
zig build run-lzf-diff
```

The differential always covers empty, tiny, text, random, mixed-block, and
long-distance streams in both Vort directions. When the upstream utility is
available, all cases are decoded in both implementation directions. A liblzf
3.6 checkout can provide it with:

```sh
./configure
make
zig build run-lzf-diff -- --reference path/to/liblzf-3.6/lzf
```

The unused type-2 checksum extension remains future functionality. It is not
needed to decode streams emitted by the upstream liblzf 3.6 utility.
