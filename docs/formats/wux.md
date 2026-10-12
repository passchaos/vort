# Wii U WUX images

Vort provides a pure-Zig reader and deterministic writer for WUX images. WUX
deduplicates fixed-size sectors from a raw Wii U WUD image; it does not apply an
entropy codec.

The reader validates the 32-byte little-endian ABI-padded header, both magic
values, sector-size bounds, reserved fields, flags, index count, aligned data
offset, exact physical size, and contiguous use of all referenced physical
sectors. Range reads map logical sectors through the UINT32 index table and can
cross repeated-sector boundaries without materializing the full image.

```zig
var image = try vort.parseWuxAlloc(allocator, wux_bytes, .{
    .max_sectors = 1 << 24,
    .max_sector_size = 64 * 1024 * 1024,
});
defer image.deinit();

const range = try image.readRangeAllocLimited(
    allocator,
    offset,
    length,
    max_output,
);
defer allocator.free(range);
```

The writer defaults to the original tool's 0x8000-byte sectors. It assigns each
unique sector its first-occurrence index and zero-pads partial tails. SHA-256 is
used only as a lookup accelerator: matching hashes are confirmed byte-for-byte
before reuse, avoiding the original WudCompress tool's hash-only collision
behavior.

```zig
const wux = try vort.encodeWuxAlloc(allocator, wud_bytes, .{
    .sector_size = 0x8000,
    .deduplicate = true,
    .max_output_len = limit,
});
defer allocator.free(wux);
```

CLI and validation surface:

```sh
zig build run -- inspect-wux game.wux
zig build run -- decode-wux game.wux game.wud 25025314816
zig build run -- decode-wux-range game.wux range.bin 1048576 65536
zig build run -- encode-wux game.wud game.wux 32768 deduplicate
zig build test-wux
zig build run-wux-diff
```

The differential checks deduplicated and store-all output byte-for-byte against
an independent Python implementation, then validates both directions with the
original WudCompress program. It also covers cross-sector ranges and malformed
headers, flags, indexes, sizes, and bounds.

Current explicit limitations are streaming file I/O and automatic opening of
multipart raw WUD dumps. The in-memory writer accepts arbitrary logical sizes
for testing and tooling, while `wuxStandardWudSize` exposes the standard
25,025,314,816-byte WUD size.
