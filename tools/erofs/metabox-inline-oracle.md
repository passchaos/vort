# Metabox inline interoperability oracle

erofs-utils 1.9.4-g5fcb2f76's `zmap.c` marks compressed inline tails with
`EROFS_MAP_META` and a metadata-relative physical offset. Its `data.c`
`z_erofs_read_one_data` then reads that offset from the primary device even
when the inode is in a metabox. This affects both `fsck` and `dump`: a large
compressed file with a metabox inline tail stops before EOF, although the
ordinary physical extents and inode metadata are valid. The raw-data path has
the same address-space issue when invoked by `fsck` for flat-inline regular
files.

The same version's metadata cache keys only the physical block number. Switching
an xattr iterator from a metabox ibody to a shared entry in primary block zero
can reuse cached metabox block zero and omit the shared attribute. The patch
also invalidates that cache when the metadata source address space changes.

`metabox-inline-oracle.patch` changes only the source address space and cache
identity for these metadata spans. It reads the bytes through erofs-utils' own metabox
metadata reader when `EROFS_MAP_META` and the inode's metabox NID bit are both
set. All mapping, compression, checksum, xattr and extraction code stays in
the external implementation. The patch contains no Vort codec implementation.
Keep the original checkout/tool binaries unchanged and build a separate copy:

```sh
cp -a /path/to/erofs-utils /tmp/erofs-utils-metabox-oracle
cd /tmp/erofs-utils-metabox-oracle
patch -p1 < /path/to/vort/tools/erofs/metabox-inline-oracle.patch
make -j4
```

Run the full matrix using the original `mkfs`/`fsck` for ordinary cases and
the separate binary explicitly for metabox combination data/xattr checks:

```sh
zig build run-erofs-diff -- \
  --mkfs /path/to/erofs-utils/mkfs/mkfs.erofs \
  --fsck /path/to/erofs-utils/fsck/fsck.erofs \
  --metabox-oracle-fsck /tmp/erofs-utils-metabox-oracle/fsck/fsck.erofs
```

The result separately counts `metabox_combined_oracle` and its compressed-inline
subset `metabox_inline_oracle`, so these checks are never reported as passing
the unmodified upstream binary. Original tools additionally validate all
chunk/fragment combinations and their complete file bytes; those checks are
included in `original_fsck_writer`. The matrix requires
complete extracted file bytes, directories, symlinks and restored xattrs. The
native tests also compare each combination with the retained allocating writer
and decode both image/device outputs through slice and Source APIs.
