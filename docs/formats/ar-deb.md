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

GNU/LLVM thin archives use `!<thin>\n` and retain symbol/string tables inline,
while ordinary member headers refer to external files. Parsed
archives expose `Archive.thin`; every external `Entry` exposes `external = true`,
the declared prefix length and normal `safe_path` classification. Ordinary
`extract*` methods return `ArEntryRequiresResolver` instead of touching the
filesystem. Callers explicitly provide already-resolved source bytes to
`extractThinInto`, `extractThinAlloc[Limited]`, or the by-name variants. The
source must contain at least the declared length; later trailing growth is
ignored, matching GNU `ar p`. Thin BSD `#1/` inline names remain rejected
because the GNU thin wire requires its `//` path table.

`encodeArAlloc`, `encodeArAppend`, and `encodeArInto` write deterministic
archives. Short names use the traditional representation and long/path names
use BSD inline names. Extraction has caller-owned and explicitly bounded
allocation variants. `encodeThinArAlloc`, `encodeThinArAppend`, and
`encodeThinArInto` write deterministic GNU thin archives with one `//` path
table and header-only external members; sizes and metadata remain caller-owned.

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
zig build run -- create-ar-file output.a member.bin input.bin [regular|thin]
zig build run -- list-ar-file output.a
zig build run -- extract-ar-file output.a member.bin decoded.bin 1048576
zig build run -- extract-ar-file thin.a member.o decoded.o 1048576 ./member.o

zig build run -- create-deb-file output.deb package-name 1.0 \
  usr/share/package/payload.bin input.bin xz
zig build run -- list-deb-file output.deb
zig build run -- extract-deb-file output.deb \
  usr/share/package/payload.bin decoded.bin 1048576
```

Thin CLI extraction requires an explicit final `thin_source` path argument;
neither the library nor CLI automatically opens an archive-controlled path.
`safe_path` remains available to callers that deliberately implement a rooted,
symlink-aware resolver.

`run-ar-diff` validates GNU long-name input and Vort BSD long-name output,
reads GNU thin archives with short/long/object members and symbol tables, and
has GNU `ar` read Vort-authored thin archives. It also pins shortened external
sources and unsafe paths (`thin_self=2`, `thin_external_read=2`,
`thin_external_write=3`). `run-deb-diff` validates Vort output with `dpkg-deb`
and reads packages produced by `dpkg-deb --build`.
