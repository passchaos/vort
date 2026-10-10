# Unix ar and Debian package support

Vort provides dependency-free parsing and deterministic writing for classic
Unix `ar` archives and Debian binary packages.

## Unix ar

`parseArArchive` validates the global signature, every fixed-width member
header, decimal/octal metadata, checked payload extents, and odd-size newline
padding. Iteration skips GNU/BSD symbol-table metadata and exposes ordinary
members with borrowed names and payloads.

Name handling includes:

- traditional `name/` fields;
- GNU `//` string tables plus `/offset` references;
- BSD `#1/length` inline names.

Thin archives are deliberately rejected as `UnsupportedArFeature`: their
members refer to external filesystem paths, so treating them as self-contained
payloads would violate the archive ownership and path-safety model.

`encodeArAlloc`, `encodeArAppend`, and `encodeArInto` write deterministic
archives. Short names use the traditional representation and long/path names
use BSD inline names. Extraction has caller-owned and explicitly bounded
allocation variants.

## Debian binary packages

`parseDebPackage` layers Debian validation on top of `ar`. It requires the
first member to be `debian-binary` with exact contents `2.0\n`, followed by one
control archive and one data archive in the required order. Optional
`_gpgorigin` is recognized.

Control and data tarballs support uncompressed TAR, gzip, Bzip2, LZMA-Alone,
XZ, and Zstandard. Decompression reuses the same bounded TAR APIs as ordinary
tarballs. `Package.decodeControlAlloc`, `decodeDataAlloc`, and
`extractDataByNameAllocLimited` keep package and member limits explicit.

`encodeDebAlloc`, `encodeDebAppend`, and `encodeDebInto` write the version
member plus deterministic control/data tarballs. A `control` or `./control`
regular file is mandatory. Control defaults to gzip and data defaults to XZ,
while callers may select any supported Debian compression explicitly.

## CLI and interoperability

```sh
zig build run -- create-ar-file output.a member.bin input.bin
zig build run -- list-ar-file output.a
zig build run -- extract-ar-file output.a member.bin decoded.bin 1048576

zig build run -- create-deb-file output.deb package-name 1.0 \
  usr/share/package/payload.bin input.bin xz
zig build run -- list-deb-file output.deb
zig build run -- extract-deb-file output.deb \
  usr/share/package/payload.bin decoded.bin 1048576
```

`run-ar-diff` validates GNU long-name input and Vort BSD long-name output
against GNU `ar`. `run-deb-diff` validates Vort output with `dpkg-deb` and reads
packages produced by `dpkg-deb --build`.
