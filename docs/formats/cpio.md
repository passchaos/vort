# CPIO archive support

Vort provides a dependency-free pure Zig CPIO reader and deterministic writer.
It covers the header families still encountered in Unix backups, package
payloads, firmware images, and Linux initramfs files:

- SVR4 `newc` (`070701`);
- SVR4 CRC (`070702`), with unsigned byte-sum validation;
- POSIX old ASCII/ODC (`070707`);
- old binary in both little- and big-endian byte order.

The parser handles each format's actual alignment rules: `newc` and CRC names
and data are aligned to four bytes, old binary names and data are aligned to
two bytes, and ODC has no padding. Binary 32-bit values use the historical
high-word-first pair of archive-endian 16-bit words.

## Library API

`parseCpioArchive` returns borrowed entry metadata including file kind, mode,
inode, ownership, link count, timestamp, device numbers, stored size, checksum,
header/data offsets, and path-safety classification. Regular-file data and
symbolic-link targets can be extracted into caller-owned buffers or through
bounded allocation APIs.

`encodeCpioAlloc`, `encodeCpioAppend`, and `encodeCpioInto` write any of the
five exposed variants (`newc`, `crc`, `odc`, `binary_little`, or
`binary_big`). Writers support regular files, directories, symbolic links,
block/character devices, FIFOs, and sockets. Output is deterministic and by
default padded to a conventional 512-byte record boundary; callers may select
a different record size or disable final record padding.

The parser requires:

- valid fixed-width hexadecimal, octal, or binary fields;
- a nonempty NUL-terminated pathname with no embedded NUL;
- checked header, name, data, and alignment extents;
- zero alignment and post-trailer padding;
- a zero-sized `TRAILER!!!` record;
- zero data sizes for directories and special files;
- CRC byte-sum equality when extracting CRC-format data.

GNU cpio writes a zero CRC for symbolic-link target bytes. Vort accepts this
historical convention and verifies nonzero symlink checksums. Unsafe archived
paths remain visible as metadata with `safe_path = false`; the deterministic
writer rejects absolute, empty-component, dot, parent, NUL-containing, and
reserved trailer names. The library and example CLI never choose an output
filesystem path from archive metadata.

Hard-link inode/link-count metadata is preserved. For newc/CRC archives that
store data only on the final member of an inode group, bounded extraction
resolves earlier zero-sized members to that payload; genuinely empty hard-link
groups remain empty. Device creation and ownership restoration are
intentionally outside the library's byte-extraction API.

## Compressed CPIO

The same public facade supports automatic bounded composition with all existing
Vort stream codecs:

- gzip, Bzip2, Brotli, Unix `compress`, and LZMA-Alone;
- XZ, LZ4 frame, lzip, LZF `ZV`, Zstandard, and LZOP.

`encodeCompressedCpioAlloc` builds the selected CPIO header format before
compression. `decodeAutoCpioAlloc` detects or bounded-probes the wrapper,
returns the owned decompressed bytes, and parses them with the ordinary CPIO
reader. This keeps container semantics in the CPIO modules and compression in
the existing public codec implementations.

## CLI

```sh
zig build run -- create-cpio-file output.cpio payload.bin input.bin newc none
zig build run -- create-cpio-file output.cpio.xz payload.bin input.bin newc xz
zig build run -- list-cpio-file output.cpio.xz
zig build run -- extract-cpio-file output.cpio.xz payload.bin decoded.bin 1048576
```

The header argument is `newc`, `crc`, `odc`, `bin`, or `bin-be`. The optional
compression argument is `none`, `gzip`, `bzip2`, `brotli`, `compress-z`,
`lzma`, `xz`, `lz4`, `lzip`, `lzf`, `zstd`, or `lzop`.

## Differential validation

`tools/cpio/diff.py` verifies all five Vort writers with GNU cpio, reads all
four formats GNU cpio can create on the host, checks directory and symlink
metadata, exercises all twelve wrapper choices, and rejects corrupt CRC data,
truncated headers, and nonzero bytes after the trailer:

```sh
python3 tools/cpio/diff.py --cli path/to/vort --cpio /usr/bin/cpio
zig build run-cpio-diff -- --cpio /usr/bin/cpio
```

Future functionality can add hard-link writer controls, concatenated CPIO
members, HP-UX device-number variants, and afio's extended ODC header without
changing the current entry or compression APIs.
