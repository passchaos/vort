# Hosted sparse VMDK images

Vort reads single-file VMware hosted-sparse VMDK extents and writes
deterministic `monolithicSparse` or `streamOptimized` images in pure Zig. The
library operates on caller-owned byte slices and never follows a descriptor
path implicitly.

The reader supports:

- sparse extent header versions 1 through 3 with checked capacity, grain size,
  feature flags, newline detector, descriptor, and compression metadata;
- grain-directory and grain-table translation with bounded entry counts;
- unallocated grains, explicit zero-grain GTE value 1, and normal hosted grains;
- zlib-wrapped DEFLATE grains with embedded 64-bit LBA and exact compressed
  length;
- both standard end-of-stream layouts with GT/GD/footer/EOS markers and the
  direct-directory compressed layout produced by QEMU 9.2;
- caller-supplied logical parent-disk bytes for sparse backing chains, with an
  explicit `MissingVmdkBackingFile` error when the descriptor declares a parent;
- bounded whole-image decode and random-range reads that decompress only grains
  touched by the requested interval.

```zig
const image = try vort.parseVmdk(vmdk_bytes, .{
    .backing_file = optional_logical_parent_bytes,
    .max_descriptor_bytes = 1024 * 1024,
    .max_grain_bytes = 2 * 1024 * 1024,
    .max_gd_entries = 1 << 22,
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

The writer's `none` mode emits a version-2 monolithic sparse extent with a
zero-grain-capable table and full-grain data allocation. `zlib` emits a
version-3 streamOptimized extent: each non-zero grain has an embedded LBA and
independent zlib stream, while zero grains remain absent. Grain tables and the
grain directory are emitted after payloads with metadata markers, followed by
the authoritative footer and end-of-stream marker. This layout is accepted by
both QEMU and 7-Zip. Input is rounded up to a 512-byte virtual sector boundary,
and the added tail reads as zero.

```zig
const encoded = try vort.encodeVmdkAlloc(allocator, raw_disk, .{
    .compression = .zlib,
    .grain_sectors = 128,
});
defer allocator.free(encoded);
```

CLI validation surface:

```sh
zig build run -- inspect-vmdk disk.vmdk
zig build run -- decode-vmdk disk.vmdk disk.raw 1073741824
zig build run -- decode-vmdk-range disk.vmdk range.raw 1048576 65536
zig build run -- encode-vmdk disk.raw disk.vmdk zlib 128
zig build test-vmdk
zig build run-vmdk-diff
```

Descriptor-only multi-file disks, flat/two-gigabyte split extents, legacy
`COWD`, ESXi SEsparse, and snapshot-chain path resolution are not claimed. A
caller can still resolve a supported sparse parent itself and pass its decoded
logical bytes. The writer does not yet emit redundant grain directories,
parent/delta descriptors, or multi-extent images. These are explicit storage
container follow-ups; the zlib grain codec and common single-file sparse paths
are implemented now.

The pinned fixture is QEMU's `iotest-version3.vmdk.bz2`: it represents a 16 GiB
streamOptimized disk with sparse writes at 100 distinct large offsets. Tests
verify every 512-byte range without allocating the virtual disk. The external
differential additionally checks both writer modes through QEMU 9.2 and 7-Zip,
and checks QEMU-produced zero grains, compressed grains, and a parent overlay in
the reverse direction.
