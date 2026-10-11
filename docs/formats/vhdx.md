# Microsoft VHDX images

Vort reads and writes common VHDX virtual disks in pure Zig. The
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
  payload BAT states, including partially-present differencing blocks;
- explicit parent locator linkage validation and parent/local sector merging;
- sparse whole-image and random-range reads with explicit BAT/block limits.

```zig
const image = try vort.parseVhdx(vhdx_bytes, .{
    .parent = optional_parent_archive,
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

The deterministic writer emits `dynamic`, `fixed`, or `differencing` images
with a zeroed 1 MiB
log area, two independently checksummed headers, two region-table copies, the
five required metadata items, an interleaved BAT, and MiB-aligned payload
blocks. Dynamic output leaves all-zero blocks unallocated; fixed output marks
every payload block fully present. Differencing output writes a VHDX parent
locator, validates the parent's DataWriteGuid, emits partially-present payloads,
and shares 1 MiB sector-bitmap blocks across each chunk. File/data/page-83 GUIDs
are deterministic hashes of the logical input, image mode, and parent identity.

```zig
const encoded = try vort.encodeVhdxAlloc(allocator, raw_disk, .{
    .image_type = .differencing,
    .block_size = 8 * 1024 * 1024,
    .logical_sector_size = 512,
    .physical_sector_size = 4096,
    .parent = optional_parent_archive,
    .parent_path = "parent.vhdx",
});
defer allocator.free(encoded);
```

CLI validation surface:

```sh
zig build run -- inspect-vhdx disk.vhdx parent.vhdx
zig build run -- decode-vhdx disk.vhdx disk.raw 1073741824 parent.vhdx
zig build run -- decode-vhdx-range disk.vhdx range.raw 1048576 65536 parent.vhdx
zig build run -- encode-vhdx disk.raw child.vhdx differencing 8388608 parent.vhdx
zig build test-vhdx
zig build run-vhdx-diff
```

A pinned QEMU 9.2 dynamic image keeps real-world redundant structures and BAT
layout in the regular tests. With external tools, QEMU checks and extracts both
Vort writer modes and generates fixed/dynamic images for Vort; 7-Zip provides
an independent extractor for both Vort modes. Explicit paths use
`-- --qemu-img <path> --seven-zip <path>`.

Vort rejects active logs and unknown required regions or metadata. Parent paths
are diagnostic/discovery metadata only: callers retain explicit ownership and
provide the parent archive directly. The writer accepts an ASCII `parent_path`,
while the CLI records the basename of its explicit parent path. Log replay and
in-place updates remain future functionality.
The current writer is one-shot and prioritizes deterministic compatibility over
layout compactness. QEMU 9.2 does not implement VHDX parent chains, but 7-Zip
independently decodes Vort differencing output including sector overrides.
