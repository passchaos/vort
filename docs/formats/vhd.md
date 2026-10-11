# Microsoft VHD images

Vort reads and writes the classic Microsoft/Connectix VHD format in pure Zig.
It supports fixed, dynamic, and differencing images; paths are never resolved
implicitly, so a differencing parent is supplied as an already parsed archive.

The reader validates:

- the 512-byte `conectix` footer, version, disk type, geometry, UUID, and one's
  complement checksum;
- the 1024-byte `cxsparse` dynamic header and checksum;
- bounded BAT geometry, sector-aligned block offsets, block extents, and the
  per-block sector bitmap;
- differencing parent UUID and virtual-size identity;
- arbitrary bounded ranges across fixed data, sparse blocks, bitmap holes, and
  parent-backed sectors.

```zig
const parent = try vort.parseVhd(parent_bytes, .{});
const image = try vort.parseVhd(child_bytes, .{
    .parent = &parent,
    .max_table_entries = 1 << 24,
    .max_block_size = 256 * 1024 * 1024,
});

const range = try image.readRangeAllocLimited(
    allocator,
    offset,
    length,
    max_output,
);
defer allocator.free(range);
```

The deterministic writer emits `fixed`, `dynamic`, or `differencing` images.
Fixed output stores the complete sector-padded medium followed by its footer.
Dynamic output omits all-zero blocks and writes footer/header/BAT/bitmap/data
structures accepted by QEMU and 7-Zip. Differencing output compares sectors
with the explicit parent, writes only changed sectors in the bitmap, and
records the parent UUID. UUIDs are deterministic hashes of the input, mode,
and parent identity; timestamps are reproducibly zero.

```zig
const encoded = try vort.encodeVhdAlloc(allocator, raw_disk, .{
    .disk_type = .dynamic,
    .block_size = 2 * 1024 * 1024,
});
defer allocator.free(encoded);
```

CLI validation surface:

```sh
zig build run -- inspect-vhd disk.vhd
zig build run -- decode-vhd disk.vhd disk.raw 1073741824
zig build run -- decode-vhd-range disk.vhd range.raw 1048576 65536
zig build run -- encode-vhd disk.raw disk.vhd dynamic 2097152
zig build test-vhd
zig build run-vhd-diff
```

`encode-vhd ... differencing` requires the parent path after `block_size`;
inspect/decode commands likewise accept an optional parent path. A pinned QEMU
9.2 dynamic image preserves external coverage when no oracle is installed.
When available, the differential has QEMU and 7-Zip decode both Vort fixed and
dynamic output, and has Vort decode fresh QEMU fixed/dynamic output.

Classic VHD has a practical 2040 GiB format limit. Vort currently ignores
parent locator paths in favor of explicit ownership, does not update images in
place, and does not implement VHDX. QEMU's `vpc` driver does not resolve VHD
differencing parents, so differencing behavior is covered by strict structural
and round-trip tests while fixed/dynamic output has two independent external
decoders.
