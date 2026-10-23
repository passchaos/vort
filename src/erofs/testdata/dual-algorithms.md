# Dual algorithm reference blocks

The 12 `dual-{lz4,lzma,deflate,zstd}-{first,second,inline}.bin.b64` files were
encoded by independent implementations:

- liblz4 1.9.3: `LZ4_compress_default`;
- zlib 1.2.11: raw DEFLATE level 6 through Python `compressobj(wbits=-15)`;
- libzstd 1.4.8: `ZSTD_compress` level 3;
- XZ Utils 5.8.4: `tools/microlzma/xz_probe.c`, 32 KiB dictionary, lc/lp/pb 3/0/2.

`first` is the first 4096 bytes of
`b"primary algorithm history and literals\n" * 128`. `second` uses the first
4096 bytes of `b"secondary algorithm history and literals\n" * 128`.
`inline` is the first 123 bytes of the second payload.

Native tests and `tools/erofs/dual_algorithm_diff.py` independently assemble
EROFS images using all 16 ordered codec pairs. Full/compact indexes contain
HEAD1 then HEAD2, while inline variants store HEAD2's bytes after the indexes.
A legacy PARTIAL_REF HEAD2 fixture extracts a 17-byte second-payload prefix.
Configuration records advertise the exact codec mask and both algorithm
nibbles retain their wire values, including zero for LZ4.

These are codec-reference blocks in synthetic format layouts. The external
gate requires fsck.erofs 1.9.4-g5fcb2f76 to independently parse, decompress and
extract every complete image, alongside Vort's public Source CLI. Native
regressions compare slice/Source/tiny-output/range surfaces and error/OOM cleanup.
Four further external-device images exercise HEAD1/HEAD2 input remapping.
Native tests additionally place both full/compact inline headers in a hidden
flat metabox inode and decode their high-NID metadata without changing codecs.
