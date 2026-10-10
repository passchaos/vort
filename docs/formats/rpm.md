# RPM package support

Vort provides dependency-free, bounded reading for common binary RPM packages.

`parseRpmPackage` validates the 96-byte v3 lead, signature header, 8-byte
alignment padding, main header, every big-endian index record, typed value
extent, NUL-terminated string/string-array data, and the payload boundary. RPM
region trailers with their specified negative offsets are recognized without
weakening ordinary tag bounds checks.

Borrowed header APIs expose typed lookup for strings, string arrays, 32-bit
integers, and binary values. Package helpers expose the common name, version,
release, architecture, operating-system, payload-format, and compressor tags.

The payload must be CPIO. Uncompressed, gzip, Bzip2, LZMA-Alone, XZ, and
Zstandard payloads are decoded through the existing bounded CPIO facade.
`Package.decodePayloadAlloc` returns an owned raw CPIO plus its parsed archive;
`extractByNameAllocLimited` separately bounds the decompressed archive and the
requested member.

```sh
zig build run -- list-rpm-file package.rpm
zig build run -- extract-rpm-file package.rpm \
  ./usr/bin/program program.bin 1048576
zig build run -- extract-rpm-payload package.rpm payload.cpio 536870912
```

`run-rpm-diff` accepts `--fixture` and compares the complete decompressed CPIO
and a payload member with optional 7-Zip. The retained local validation uses a
Fedora RPM with a Zstandard payload.

Signature/header digests and cryptographic trust policy are intentionally not
claimed yet. The signature header is parsed and exposed, but verification will
be a separate API so callers must choose keys and policy explicitly. RPM
writing is also future work.
