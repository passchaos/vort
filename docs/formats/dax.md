# DAX compressed PSP images

Vort reads and writes the legacy DAX compressed-ISO format in pure Zig. DAX
splits the logical image into fixed 8192-byte frames. Version 0 stores every
frame as an independent zlib stream; version 1 adds an ordered table of
non-compressed frame ranges.

The reader validates:

- the 32-byte `DAX\0` header and versions 0/1;
- bounded frame and non-compressed-area counts;
- complete 32-bit absolute-offset and 16-bit stored-size tables;
- ordered, non-overlapping, non-empty version-1 raw ranges;
- metadata/data separation, checked frame extents, and configurable compressed
  frame limits;
- exact zlib wrappers, Adler-32 values, decoded frame sizes, partial final
  frames, whole-image limits, and arbitrary ranges.

```zig
const image = try vort.parseDax(dax_bytes, .{
    .max_frames = 1 << 20,
    .max_nc_areas = 1 << 20,
    .max_compressed_frame_bytes = 65535,
});
const range = try image.readRangeAllocLimited(
    allocator,
    offset,
    length,
    max_output,
);
defer allocator.free(range);
```

The deterministic writer offers `zlib`, `raw`, and `auto` modes. Zlib-only
output uses the simpler version-0 layout. Raw and automatic output use version
1 and coalesce adjacent raw frames into canonical non-compressed areas.
Automatic mode keeps zlib only when its complete wrapped frame is smaller than
the raw 8192-byte block. The final codec block is zero-padded, while the header
retains the caller's exact logical byte count.

```zig
const encoded = try vort.encodeDaxAlloc(allocator, iso_bytes, .{
    .compression = .auto,
    .compression_level = 6,
});
defer allocator.free(encoded);
```

CLI and validation surface:

```sh
zig build run -- inspect-dax game.dax
zig build run -- decode-dax game.dax game.iso 5368709120
zig build run -- decode-dax-range game.dax range.bin 1048576 65536
zig build run -- encode-dax game.iso game.dax auto 6
zig build test-dax
zig build run-dax-diff
```

`run-dax-diff` always checks zlib/raw/automatic writers, partial tails, ranges,
limits, and malformed structures. When `maxcso` is installed, it decodes all
three Vort modes and creates a fresh DAX image for Vort; use
`-- --maxcso /path/to/maxcso` to select an explicit binary.
A pinned maxcso 1.13.0 version-0 image keeps independent decoder coverage in
the unit suite when that executable is unavailable.

DAX uses 32-bit logical sizes and physical offsets and therefore cannot
represent images at or above 4 GiB. The current API is one-shot over borrowed
image bytes. Streaming file I/O, parallel frame compression, and compression
ratio/speed tuning remain follow-up work.
