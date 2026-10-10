# EROFS

Vort provides a pure Zig EROFS reader and deterministic writer for the
filesystem format used by Android, embedded Linux, and container images.

The reader validates the superblock, CRC-32C checksum, block geometry,
incompatible feature bits, compact and extended inode layouts, inline xattr
area sizing, directory entry ordering, names, NIDs, and exact allocation
limits. Flat plain and flat inline files, directories, regular files, and
symbolic links are supported.

Compressed files support both legacy full indexes and modern compact indexes,
including four-byte and sixteen-entry/two-byte packs, HEAD/NONHEAD lookback,
EOF sentinels, and big pclusters. LZ4, raw Deflate, and Zstandard extents are
decoded. MicroLZMA is intentionally reported as unsupported because its wire
format is not LZMA-Alone; Vort does not substitute an incompatible decoder.

The writer emits 4 KiB filesystems with compact inodes, CRC-32C-protected
superblocks, dot-omitted sorted directories, nested and empty directories,
symbolic links, flat plain/inline stored data, and legacy full compression
indexes. In LZ4 mode every non-empty regular-file logical cluster independently
uses a right-aligned `lz4_0padding` compressed physical cluster or a `PLAIN`
fallback when compression would not reduce the payload. Identical entries and
options produce identical images.

Writer entries use safe relative paths. Missing parent directories are created
automatically, while absolute paths, empty components, `.`/`..`, NUL bytes,
duplicate entries, and non-directory parents are rejected. Entry data and
symlink targets remain caller-owned for the duration of `encodeErofsAlloc`.

```zig
const image = try vort.encodeErofsAlloc(allocator, &.{
    .{ .path = "etc/config", .data = "enabled=true\n" },
    .{ .path = "var/empty", .kind = .directory },
    .{ .path = "config-link", .kind = .symlink, .target = "etc/config" },
}, .{ .compression = .lz4 });
defer allocator.free(image);
```

Chunk-based files, external devices, 48-bit addressing, packed fragments,
metaboxes, MicroLZMA, compressed tail packing, xattrs, and Deflate/Zstandard
writing remain future work.

```sh
zig build run -- list-erofs-file system.erofs
zig build run -- create-erofs-file output.erofs path/in/image input.bin lz4
zig build run -- extract-erofs-file system.erofs etc/config output.conf 67108864
zig build run-erofs-diff
```

CI builds a pinned `erofs-utils` reference and generates plain, compact/full
LZ4, Deflate, and Zstandard images. `fsck.erofs` validates and extracts those
images before Vort performs independent listing and byte-for-byte extraction.
The same gate generates Vort stored and LZ4 images twice to prove determinism,
self-decodes their nested tree, and has `fsck.erofs` extract their regular
files, symlink, and empty directory.
