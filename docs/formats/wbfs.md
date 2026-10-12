# Wii Backup File System images

Vort provides a pure-Zig reader and deterministic single-disc writer for WBFS
images. WBFS is a sparse Wii-disc container rather than an entropy codec: its
WLBA table maps fixed logical disc blocks to physical blocks and leaves unused
blocks unallocated.

The reader validates the magic, physical size equation, sector shifts, selected
disc slot, disc-info extent, fixed dual-layer logical geometry, and every WLBA
mapping. A zero WLBA entry reads as zero-filled logical data. The logical size
is always `9_399_959_552` bytes, matching 286,864 Wii sectors; use bounded range
reads when a full dual-layer allocation is unnecessary.

```zig
var image = try vort.parseWbfsAlloc(allocator, wbfs_bytes, .{
    .disc_slot = 0,
    .max_hd_sector_size = 64 * 1024,
    .max_wbfs_sector_size = 64 * 1024 * 1024,
    .max_parts = 10,
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

Split `.wbfs`/`.wbf1` data can be supplied without concatenating it first:

```zig
var image = try vort.parseWbfsPartsAlloc(
    allocator,
    &.{ wbfs_part, wbf1_part, wbf2_part },
    .{},
);
defer image.deinit();
```

The writer emits slot 0 with a copied 0x100-byte Wii disc header and a big-endian
WLBA table. Physical block 0 contains metadata; data blocks are assigned
sequentially from 1. By default, 2 MiB blocks containing only zeroes are omitted
and partial tails are zero-padded. The first logical block is always retained so
external readers can access the disc header.

```zig
const wbfs = try vort.encodeWbfsAlloc(allocator, iso_bytes, .{
    .wbfs_sector_shift = 21,
    .sparse_zero_clusters = true,
    .max_output_len = 16 * 1024 * 1024 * 1024,
});
defer allocator.free(wbfs);
```

CLI and validation surface:

```sh
zig build run -- inspect-wbfs game.wbfs
zig build run -- decode-wbfs-range game.wbfs range.bin 1048576 65536
zig build run -- encode-wbfs game.iso game.wbfs 2097152 sparse
zig build test-wbfs
zig build run-wbfs-diff
```

The differential compares sparse and full Vort output byte-for-byte with an
independent Python encoder, exercises cross-block and high logical offsets,
checks malformed headers and maps, and asks DolphinTool to recognize both
writer modes and report their block size.

Current explicit limitations are writer-side multi-disc volumes, automatic
filesystem-aware scrubbing, and automatic discovery of sibling `.wbfN` files.
The library can already read split inputs when the caller supplies their byte
slices. Streaming file I/O and filesystem-based sparse output remain follow-up
work.
