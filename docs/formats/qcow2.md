# QCOW2 v2/v3 disk images

Vort reads common unencrypted QCOW2 v2 and v3 images and writes deterministic
baseline images in pure Zig. The library consumes byte slices and never opens a
path implicitly; callers explicitly provide image bytes and, when needed, raw
backing or external-data bytes.

The reader supports:

- standard L1/L2 translation with 512-byte through 2 MiB clusters;
- normal, unallocated, v3 zero, and compressed clusters;
- extended L2 entries with independent allocation and zero bitmaps for all 32
  subclusters;
- QCOW2 raw-DEFLATE compressed clusters, including their 4 KiB history window,
  and standard Zstandard frames;
- caller-supplied raw backing images, with zero fill beyond the supplied
  backing length;
- caller-supplied external data files, including the fixed guest-to-host
  mapping for guest cluster zero and the raw-external-data feature;
- bounded whole-image extraction and range reads that materialize only the
  compressed clusters touched by the requested range.

```zig
const image = try vort.parseQcow2(qcow2_bytes, .{
    .backing_file = optional_raw_backing,
    .external_data_file = optional_external_data,
    .max_l1_entries = 1 << 22,
    .max_cluster_size = 2 * 1024 * 1024,
    .max_compressed_bytes = 4 * 1024 * 1024,
});

const range = try image.readRangeAllocLimited(
    allocator,
    offset,
    length,
    max_output,
);
defer allocator.free(range);
```

The deterministic writer emits v2 or v3 images with one refcount table/block,
an L1 table, the required L2 tables, and normal or compressed data clusters.
Compression modes are `none`, `zlib`, and `zstd`; Zstandard requires v3 and
sets the compression incompatible-feature bit. `zlib` follows QCOW2 terminology
and stores raw DEFLATE rather than a zlib wrapper. Compression falls back to a
normal cluster whenever the result is not smaller, and all-zero clusters remain
sparse. Input length is rounded up to the mandatory 512-byte virtual-disk
sector boundary and the added tail reads as zeros.

Writers can also emit v2 or v3 raw-backing overlays. `backing_file` supplies
the caller-owned logical parent bytes used to omit identical guest clusters;
`backing_file_name` records the explicit QCOW2 path. The header carries the
standard `raw` backing-format extension so QEMU never probes the parent format.
For v3, a zero child cluster over non-zero parent data uses the explicit zero
flag; v2 allocates a normal zero cluster because an unallocated entry would
inherit the parent. Parent bytes beyond their supplied length read as zero, and
partial final sectors retain the ordinary zero-padding rule.

```zig
const encoded = try vort.encodeQcow2Alloc(allocator, raw_disk, .{
    .version = 3,
    .cluster_bits = 16,
    .compression = .zstd,
    .backing_file = optional_raw_parent,
    .backing_file_name = if (optional_raw_parent != null) "parent.raw" else null,
});
defer allocator.free(encoded);
```

CLI validation surface:

```sh
zig build run -- inspect-qcow2 disk.qcow2
zig build run -- decode-qcow2 disk.qcow2 disk.raw 1073741824
zig build run -- decode-qcow2-range disk.qcow2 range.raw 1048576 65536
zig build run -- encode-qcow2 disk.raw disk.qcow2 zstd 16 3
zig build run -- encode-qcow2 child.raw child.qcow2 zlib 16 3 parent.raw parent.raw
zig build test-qcow2
zig build run-qcow2-diff
```

`decode-qcow2` accepts optional raw backing and external-data paths after the
output limit; use `-` when only the later external-data argument is needed.
`encode-qcow2` accepts an optional logical raw backing path and the exact
backing name to store after version.

Encrypted images are rejected. The reader does not resolve backing paths,
validate refcount ownership, or expose internal snapshots; it reads the active
L1/L2 mapping only. The baseline writer does not yet emit external data files,
extended L2 tables, snapshots, encryption, dirty bitmaps,
or compact multiple compressed payloads into one host cluster. Its single
16-bit refcount block bounds the number of host clusters and returns
`error.OutputLimitExceeded` rather than silently generating an incomplete
image. These are explicit storage-feature and size-efficiency follow-ups, not
claimed support.

The differential gate validates Vort output with QEMU 9.2 `qemu-img` and 7-Zip,
including v2/v3 raw-backing overlays with inherited, modified, and explicit-zero
clusters. It also decodes QEMU-generated v2/v3 zlib/Zstandard, extended-L2,
backing, and external-data images byte-exactly. The generic raw-byte fuzz target
exercises bounded header parsing, mapping, and range decoding.
