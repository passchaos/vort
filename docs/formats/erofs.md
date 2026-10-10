# EROFS

Vort provides a pure Zig read-only implementation of the EROFS filesystem
format used by Android, embedded Linux, and container images.

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
Chunk-based files, external devices, 48-bit addressing, packed fragments,
metaboxes, and EROFS writing remain future work.

```sh
zig build run -- list-erofs-file system.erofs
zig build run -- extract-erofs-file system.erofs etc/config output.conf 67108864
zig build run-erofs-diff
```

CI builds a pinned `erofs-utils` reference and generates plain, compact/full
LZ4, Deflate, and Zstandard images. `fsck.erofs` validates and extracts each
image before Vort performs independent listing and byte-for-byte extraction.
