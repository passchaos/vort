# RAR archive support

Vort provides a dependency-free pure Zig parser and deterministic stored-data
writer for the two RAR container generations most often encountered today:

- the `Rar!\x1a\x07\x00` family used by RAR 1.5 through 4.x;
- the VINT-based `Rar!\x1a\x07\x01\x00` family used by RAR 5 and later.

In addition to stored data, Vort decodes non-solid RAR 1.5 and RAR 2.0/2.6
compressed members. The RAR15 path implements the historical adaptive
literal/short/long/old-distance state machine and ST mode over a 64 KiB
history. The RAR20 path implements dynamic canonical Huffman tables, table
reuse and multiblock transitions, a 1 MiB LZ history, repeated distances, and
the multimedia/audio predictor. RAR 2.9/3.x and RAR5 compressed entries remain
classified as `rar29` or `rar50` and return `UnsupportedRarCompression` before
allocating output.

## Reader

`parseRarArchive` scans up to 1 MiB for an embedded signature, so ordinary RAR
files and SFX-prefixed archives share the same API. It validates:

- RAR4 low-16-bit header CRCs, fixed/large file sizes, block extents, optional
  end blocks, and file CRC-32;
- RAR5 bounded VINTs, full header CRC-32, header/data/extra sizes, block chains,
  file CRC-32, and mandatory end headers;
- checked conversion of 64-bit sizes to the current target's `usize`;
- stored packed/unpacked size equality and zero-sized directory entries;
- absolute, parent-component, and empty-component path risks across both `/`
  and `\` separator conventions.

Borrowed entry metadata includes the normalized name view, method and algorithm
version, sizes, CRC, host OS, attributes, timestamp, directory/encryption/solid
flags, split-before/split-after state, unknown-size state, redirection presence,
and path-safety classification.

Stored regular files use caller-owned or explicitly bounded allocation APIs.
Directories, unsupported compressed data, encrypted entries, encrypted
headers, RAR5 redirections, unknown-size members, incomplete split-volume
members, and compressed solid continuations return specific errors. This
prevents an unsupported or incomplete member from being copied as if it were
stored data.

RAR4 Unicode names use a historical custom encoding. The current borrowed
parser exposes their ANSI fallback name; RAR5 names are the archive's UTF-8
bytes. Adding an allocator-backed RAR4 Unicode-name view remains future work.

## Writer

`encodeRarAlloc`, `encodeRarAppend`, and `encodeRarInto` emit deterministic
multi-entry RAR4 or RAR5 archives with stored regular files and directories.
They write standard header/data CRCs, Unix attributes, optional
generation-native timestamps (DOS date/time for RAR4, Unix seconds for RAR5),
RAR4 end blocks, and RAR5 end headers.

RAR4 output accepts safe ASCII names and converts `/` to the traditional `\`
separator. RAR5 output accepts validated UTF-8 names. Both writers reject NUL,
absolute, empty-component, dot, and parent-component paths. Compression,
encryption, solid writing, recovery records, comments, redirections, and volume
splitting are intentionally not exposed until their full semantics are
implemented.

## CLI

```sh
zig build run -- create-rar-file output.rar payload.bin input.bin rar5
zig build run -- list-rar-file output.rar
zig build run -- extract-rar-file output.rar payload.bin decoded.bin 1048576
```

The writer version is `rar4` or `rar5`; `rar5` is the default.

## Differential validation

`tools/rar/diff.py` performs deterministic/self round trips, validates both
writers with 7-Zip, reads stored RAR4/RAR5 output from an optional rars-based
reference helper, verifies that real compressed reference entries are
classified correctly, checks SFX parsing and both CRC layers, exercises RAR2
and RAR5 split-volume fixtures, and compares RAR15/RAR20 text, multiblock,
keep-table, long-history and audio outputs byte-for-byte with 7-Zip:

```sh
zig build run-rar-diff -- \
  --7zz path/to/7zz \
  --rars path/to/reference-writer \
  --fixtures path/to/unarc-rs/crates/unarc-rs/tests/rar/multi \
  --legacy-fixtures path/to/rars/tests/fixtures/rar15_40
```

The next functionality stages are RAR 2.9 LZ/PPMd and VM filters, followed by
RAR5 LZ/filters. Encrypted payloads, solid state and multi-volume reconstruction
should be added on top of those decoders rather than approximated in the stored
path.
