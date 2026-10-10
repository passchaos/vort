# RPM package support

Vort provides dependency-free, bounded reading and deterministic writing for
common binary RPM packages.

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

`Package.verifyDigests` validates every available legacy MD5, Header SHA1, and
Header SHA256 digest using the exact RPM-defined byte ranges. Its report states
which digests were present; a mismatch is `RpmDigestMismatch`.

`encodeRpmAlloc`, `encodeRpmAppend`, and `encodeRpmInto` write a v3 lead,
canonical immutable-region Main Header, unsigned Signature Header, and a
deterministic CPIO payload. Writers emit MD5, Header SHA1, Header SHA256,
package-size, and uncompressed-payload-size signature tags. Payload compression
can be none, gzip, Bzip2, LZMA-Alone, XZ, or Zstandard.

```sh
zig build run -- create-rpm-file output.rpm package-name 1.0 \
  usr/share/package/payload.bin input.bin xz
zig build run -- list-rpm-file package.rpm
zig build run -- extract-rpm-file package.rpm \
  ./usr/bin/program program.bin 1048576
zig build run -- extract-rpm-payload package.rpm payload.cpio 536870912
```

`run-rpm-diff` validates all six writer compressors with optional 7-Zip. With
`--fixture`, it also compares the complete decompressed CPIO and a payload
member from an external package. The retained local validation uses a Fedora
RPM with a Zstandard payload.

RSA/PGP public-key signature verification and trust policy are intentionally
not claimed yet. The signature header is parsed and exposed, but asymmetric
verification will remain a separate API so callers must choose keys and policy
explicitly. The current writer is therefore explicitly unsigned.
