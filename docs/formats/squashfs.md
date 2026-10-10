# SquashFS

Vort provides a pure Zig implementation of the SquashFS v4 filesystem format.
It is intended for safely inspecting, extracting, and deterministically creating
Linux, container, firmware, and embedded-system images without mounting them.

The reader supports:

- gzip/zlib, LZMA-Alone, LZO1X, XZ, raw LZ4, and Zstandard compression;
- compressed and uncompressed 8 KiB metadata blocks;
- short and extended regular-file and directory inodes;
- nested directory lookup with sorted-name and path-component validation;
- full, sparse, and fragment-backed file data;
- symbolic-link target extraction;
- caller-selected file and directory allocation limits.

The API borrows the image bytes and returns explicitly owned inode, directory,
and extraction buffers. Device nodes, FIFOs, and sockets are parsed as inode
types but are not materialized by the extraction helper.

The writer accepts a flat safe-path entry list, synthesizes parent directories,
sorts the resulting tree deterministically, packs file tails into fragments,
and emits long regular/directory inodes plus symlinks. Stored, gzip, and Zstd
data/fragment modes are supported. Metadata and the single root ID table are
stored uncompressed to keep references deterministic. Writer support for xattrs,
device/FIFO/socket nodes, export tables, hard links, and LZMA/LZO/XZ/LZ4 output
is deferred.

```sh
zig build run -- list-squashfs-file rootfs.sqfs
zig build run -- create-squashfs-file output.sqfs payload.bin input.bin gzip 131072
zig build run -- extract-squashfs-file rootfs.sqfs etc/config output.conf 67108864
zig build run-squashfs-diff
```

`run-squashfs-diff` generates images with squashfs-tools for all six codecs and
compares multi-block, fragment, sparse, nested-directory, long-directory, and
symlink extraction. It also validates stored/gzip/Zstd writer trees with
`unsquashfs`, including nested and empty directories. A checked-in gzip fixture
keeps the complete parser path covered when the external tools are unavailable.
