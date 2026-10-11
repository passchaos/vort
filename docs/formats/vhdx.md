# Microsoft VHDX images

Vort reads and writes common standalone VHDX virtual disks in pure Zig. The
implementation keeps both redundant headers and region tables, validates their
CRC-32C checksums, and selects the newest valid header by sequence number.

The reader supports:

- the `vhdxfile` identifier and UTF-16LE creator field;
- redundant 4 KiB headers and 64 KiB region tables with fallback after one
  corrupt copy;
- BAT and metadata regions identified by their Microsoft GUIDs;
- required file-parameters, virtual-size, page-83, logical-sector, and
  physical-sector metadata;
- 512- or 4096-byte logical sectors and 1...256 MiB payload blocks;
- not-present, undefined, zero, unmapped, legacy-unmapped, and fully-present
  payload BAT states;
- sparse whole-image and random-range reads with explicit BAT/block limits.

```zig
const image = try vort.parseVhdx(vhdx_bytes, .{
    .max_bat_entries = 1 << 26,
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

The deterministic writer emits `dynamic` or `fixed` images with a zeroed 1 MiB
log area, two independently checksummed headers, two region-table copies, the
five required metadata items, an interleaved BAT, and MiB-aligned payload
blocks. Dynamic output leaves all-zero blocks unallocated; fixed output marks
every payload block fully present. File/data/page-83 GUIDs are deterministic
hashes of the logical input and image mode.

```zig
const encoded = try vort.encodeVhdxAlloc(allocator, raw_disk, .{
    .image_type = .dynamic,
    .block_size = 8 * 1024 * 1024,
    .logical_sector_size = 512,
    .physical_sector_size = 4096,
});
defer allocator.free(encoded);
```

CLI validation surface:

```sh
zig build run -- inspect-vhdx disk.vhdx
zig build run -- decode-vhdx disk.vhdx disk.raw 1073741824
zig build run -- decode-vhdx-range disk.vhdx range.raw 1048576 65536
zig build run -- encode-vhdx disk.raw disk.vhdx dynamic 8388608
zig build test-vhdx
zig build run-vhdx-diff
```

A pinned QEMU 9.2 dynamic image keeps real-world redundant structures and BAT
layout in the regular tests. With external tools, QEMU checks and extracts both
Vort writer modes and generates fixed/dynamic images for Vort; 7-Zip provides
an independent extractor for both Vort modes. Explicit paths use
`-- --qemu-img <path> --seven-zip <path>`.

Vort rejects active logs, parent/differencing metadata, partially-present
payload blocks, and unknown required regions or metadata. Log replay,
differencing images, in-place updates, and sector-bitmap blocks remain future
functionality. The current writer is one-shot and prioritizes deterministic
compatibility over layout compactness.
