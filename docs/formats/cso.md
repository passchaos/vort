# CISO/CSO and ZISO/ZSO images

Vort reads and writes PSP/PS2-style CISO v1, experimental CISO v2, and ZISO
images in pure Zig. CISO blocks use raw DEFLATE, ZISO blocks use raw LZ4, and
CISO v2 can choose either codec independently for every block.

The reader validates the fixed 24-byte header, bounded power-of-two block size,
index count, shifted 31-bit physical offsets, monotonic block extents, raw block
sizes, and compressed-block limits. CISO v1 version 0 and unreliable
`header_size` fields are accepted for compatibility with early writers. CISO
v2 and ZISO require the specified header size and reserved bytes. Arbitrary
bounded ranges can cross raw, DEFLATE, and LZ4 blocks without materializing the
whole image.

```zig
const image = try vort.parseCso(cso_bytes, .{
    .max_blocks = 1 << 24,
    .max_block_size = 256 * 1024,
    .max_compressed_block_bytes = 512 * 1024,
});
const range = try image.readRangeAllocLimited(
    allocator,
    offset,
    length,
    max_output,
);
defer allocator.free(range);
```

The deterministic writer supports raw, forced-format, and automatic selection.
When a compressed payload would not remain smaller after index alignment, it
falls back to a raw full block. Partial final input is zero-padded only for the
codec block; `uncompressed_size` retains the caller's exact logical length.
CISO v2 automatic mode compares raw DEFLATE and LZ4 and records its per-block
codec flag. `index_shift` is selected conservatively unless explicitly set.

```zig
const encoded = try vort.encodeCsoAlloc(allocator, iso_bytes, .{
    .format = .cso2,
    .compression = .auto,
    .block_size = 2048,
    .compression_level = 6,
});
defer allocator.free(encoded);
```

CLI validation surface:

```sh
zig build run -- inspect-cso game.cso
zig build run -- decode-cso game.cso game.iso 1073741824
zig build run -- decode-cso-range game.zso range.bin 1048576 65536
zig build run -- encode-cso game.iso game.cso cso1 auto 2048 6
zig build run -- encode-cso game.iso game.zso zso auto 2048
zig build test-cso
zig build run-cso-diff
```

`run-cso-diff` always exercises all three layouts, raw fallback, partial ranges,
shifted indexes, and malformed inputs. When `maxcso` is installed it checks both
directions for CISO v1/v2 and ZISO; use `-- --maxcso /path/to/maxcso` to select
an explicit binary. 7-Zip is probed as an additional decoder, but current 7-Zip
releases commonly do not expose a CSO/ZSO handler, so the summary reports an
independent decode only when one actually succeeds.

The current writer is one-shot and stores one index entry per block. Streaming
file I/O, parallel block encoding, DAX, block deduplication, and compression
ratio/speed tuning remain follow-up work. The wire format cannot address more
than 31 shifted offset bits and Vort rejects options whose required alignment
would exceed the block size.
