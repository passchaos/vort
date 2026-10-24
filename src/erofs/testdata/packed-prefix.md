# Packed xattr prefix fixtures

`packed-prefix-{stored,lz4,lzma,deflate,zstd}.erofs.b64` were generated with
erofs-utils 1.9.4-g5fcb2f76. The source tree contains one regular `file` whose
bytes are `b"packed prefix interoperability payload\n" * 2000`. The root has
`user.vort.root=root-value`; the file has `user.vort.repeat=file-value` and
`user.other.detail=other-value`.

Each image uses:

```sh
mkfs.erofs -T0 --all-root --xattr-prefix=user.vort. \
  --xattr-prefix=user.other. -E fragments output.erofs source
```

Compressed cases additionally pass `-z{lz4,lzma,deflate,zstd} -E all-fragments`.
The stored case keeps the 17-byte prefix table alone in a flat-inline packed
inode, whose final prefix payload has no trailing alignment bytes. Compressed
cases retain the prefixes and file bytes in full/compact compressed packed
layouts, exercising prefix reads inside real LZ4/MicroLZMA/Deflate/Zstandard
extents. All images have two long prefixes and clear the plain-prefix flag.

The unit tests read attributes through both slice and short-read Source APIs
and independently compare the visible file bytes. `tools/erofs/prefix_diff.py`
builds fresh stored and full/compact compressed images with root, directory,
shared and inline attributes, checks actual packed placement, compares Vort
listing/extraction with fsck.erofs, and verifies restored xattrs.
