# EROFS NONHEAD range oracle

`fsck.erofs` whole-file extraction can successfully read an image whose
NONHEAD backward links are malformed. A positional read starting in that
logical cluster exercises the backward chain. The checked-in
`range_oracle.c` calls the original `erofs_iopen` / `erofs_pread` APIs, without
patching the library or replacing its mapping code.

Build erofs-utils normally, then compile the probe against that checkout's
static library and its enabled dependencies. For example, with the local
1.9.4-g5fcb2f76 build used for validation:

```sh
erofs_ref=/path/to/erofs-utils
xz_ref=/path/to/xz/build
cc -O2 -DHAVE_CONFIG_H -I"$erofs_ref/include" -I"$erofs_ref" \
  tools/erofs/range_oracle.c "$erofs_ref/lib/.libs/liberofs.a" \
  -L"$xz_ref" -Wl,-rpath,"$xz_ref" \
  -llzma -lzstd -llz4 -lz -luuid -lssl -lcrypto -lcurl -lxml2 -ljson-c \
  -lpthread -o /tmp/vort-erofs-range-oracle
zig build run-erofs-diff -Doptimize=ReleaseFast -- \
  --mkfs "$erofs_ref/mkfs/mkfs.erofs" \
  --fsck "$erofs_ref/fsck/fsck.erofs" \
  --range-oracle /tmp/vort-erofs-range-oracle
```

The dependency list depends on the checkout's configure options. The probe
accepts `image nid offset length`, writes successful bytes to stdout and
reports the library error value to stderr. Requests are limited to 1 MiB.

The Vort `range_probe.zig` executable uses the public slice and Source archive
APIs with 17-byte output buffers and atomic file replacement. It accepts
`image nid offset length output [slice|source]`.

`nonhead_diff.py` checks original and linked full/compact final-big fixtures,
as well as the original two-byte compact fixture across initial four-byte,
sixteen-item two-byte and trailing four-byte pack boundaries. Broken zero
and excessive lookbacks must fail through the original positional oracle,
both Vort APIs and the whole-file CLI. Vort failures must preserve existing
outputs and remove temporary files. The two-byte corruptions modify the
predecessor of the pack-final item, whose backward distance is derived rather
than stored directly. Superblock CRC-32C is recomputed after each mutation so
these checks reach index validation.

When `--range-oracle` is omitted, the differential reports zero NONHEAD oracle
cases; Zig's index and range regressions still run with `zig build test-erofs`.
