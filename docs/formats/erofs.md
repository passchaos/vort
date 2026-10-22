# EROFS

Vort provides a pure Zig EROFS reader and deterministic writer for the
filesystem format used by Android, embedded Linux, and container images.

The reader validates the superblock, CRC-32C checksum, block geometry,
incompatible feature bits, compact and extended inode layouts, directory entry
ordering, names, NIDs, and exact allocation limits. Flat plain and flat inline
files, directories, regular files, and symbolic links are supported. Bounded
xattr decoding covers inline entries, shared IDs relative to `xattr_block`,
empty values, standard full-name/user/POSIX-ACL/trusted/lustre/security name
indexes, and incompatible-feature long indexes backed by bounded plain prefix
tables. Reconstructed names and values are copied into one owned buffer; count
and aggregate-byte limits are checked before allocation.

Compressed files support both legacy full indexes and modern compact indexes,
including four-byte and sixteen-entry/two-byte packs, HEAD/NONHEAD lookback,
EOF sentinels, and big pclusters. LZ4, raw Deflate, and Zstandard extents are
decoded, as are exact-size MicroLZMA extents with inverted property bytes,
8 MiB EROFS dictionary bounds, exact compressed-input consumption, and range
termination validation. MicroLZMA is handled as its own wire format rather than
being substituted with LZMA-Alone. Whole-file and partial-tail fragments are
resolved through the hidden packed inode, whether it is flat, compressed, or
interlaced. Compressed inline tail packing is decoded directly from inode
metadata. Packed-inode extraction scans indexes without retaining a whole head
table and materializes only intersecting extents; `ErofsReadLimits` separately
bounds caller output and hidden packed-extent scratch (8 MiB by default).

The writer emits 4 KiB filesystems with compact inodes, CRC-32C-protected
superblocks, dot-omitted sorted directories, nested and empty directories,
symbolic links, flat plain/inline stored data, and legacy full compression
indexes. LZ4, raw Deflate, and Zstandard modes encode every non-empty
regular-file logical cluster into an independently addressable physical cluster.
Compressed payloads are right-aligned with `lz4_0padding`; a `PLAIN` index is
used whenever compression would not reduce the payload. Deflate and Zstandard
images include their required superblock compression-configuration records.
Each entry and the root directory can carry deterministic inline xattrs; inode
planning accounts for their ibodies before flat-inline tails and aligned
compression headers. `xattr_prefixes` optionally writes a plain prefix table
and uses its caller-ordered first match without changing the default wire.
`tail_packing = .fragments` deterministically packs the last logical block of
each non-empty regular file: small files use the whole-fragment header, larger
files retain ordinary compressed/plain prefix clusters, and one hidden packed
inode is encoded through the selected LZ4/Deflate/Zstandard planner. The hidden
inode contributes to the inode count but never to directory entries. Identical
entries and options produce identical images.

Writer entries use safe relative paths. Missing parent directories are created
automatically, while absolute paths, empty components, `.`/`..`, NUL bytes,
duplicate entries, and non-directory parents are rejected. Entry data and
symlink targets remain caller-owned for the duration of `encodeErofsAlloc`.

```zig
const config_xattrs = [_]vort.ErofsXattr{
    .{ .name = "user.owner", .value = "vort" },
};
const root_xattrs = [_]vort.ErofsXattr{
    .{ .name = "user.image", .value = "system" },
};
const image = try vort.encodeErofsAlloc(allocator, &.{
    .{ .path = "etc/config", .data = "enabled=true\n", .xattrs = &config_xattrs },
    .{ .path = "var/empty", .kind = .directory },
    .{ .path = "config-link", .kind = .symlink, .target = "etc/config" },
}, .{
    .compression = .zstandard,
    .root_xattrs = &root_xattrs,
    .xattr_prefixes = &.{"user."},
    .tail_packing = .fragments,
});
defer allocator.free(image);

const archive = try vort.parseErofs(image);
const inode = try archive.lookup(allocator, "etc/config", 1024, 1024 * 1024);
var attributes = try archive.readXattrsAllocLimited(allocator, inode, 32, 64 * 1024);
defer attributes.deinit();
const owner = attributes.find("user.owner").?.value;

const payload = try archive.extractByPathAllocWithLimits(
    allocator,
    "etc/config",
    .{ .max_output_len = 1024, .max_packed_extent_len = 2 * 1024 * 1024 },
    1024 * 1024,
);
defer allocator.free(payload);
```

Chunk-based files, external devices, 48-bit addressing, and metaboxes remain
future work. Prefix tables stored inside packed or metabox inodes remain
unsupported; ordinary `PLAIN_XATTR_PFX` tables are supported in both
directions. The writer does not yet generate compressed inline tails or
deduplicate repeated values into the optional shared-xattr region. Fragment
writing requires a non-stored compression mode because visible files use the
compressed inode layout even when a prefix cluster falls back to `PLAIN`.

```sh
zig build run -- list-erofs-file system.erofs
zig build run -- create-erofs-file output.erofs path/in/image input.bin zstd
zig build run -- extract-erofs-file system.erofs etc/config output.conf 67108864
zig build run -- list-erofs-xattrs system.erofs etc/config
zig build run-erofs-diff
```

CI builds a pinned `erofs-utils` reference and generates plain, compact/full
LZ4, MicroLZMA, Deflate, and Zstandard images when the reference has a recent
XZ Utils. `fsck.erofs` validates and extracts those images before Vort performs
independent listing and byte-for-byte extraction.
The same gate generates Vort stored, LZ4, raw Deflate, and Zstandard images
twice to prove determinism, self-decodes their nested tree, and has `fsck.erofs`
extract their regular files, incompressible `PLAIN` fallbacks, symlink, and empty
directory. Real `user.*` attributes include repeated values that erofs-utils
promotes to shared entries; an additional reference image combines shared
values with a long prefix table. Vort reads those images, while
`fsck.erofs --xattrs` restores long-prefix Vort-authored root, file, and
directory attributes. Additional LZ4/Deflate/Zstandard fragment images cover
whole and partial references plus flat/compressed/interlaced packed inodes;
LZ4/Deflate/Zstandard images cover compressed inline tail packing. Seven Vort
writer modes include all three fragment writers and are independently
extracted by `fsck.erofs`.
