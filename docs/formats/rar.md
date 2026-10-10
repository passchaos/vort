# RAR archive support

Vort provides a dependency-free pure Zig parser and deterministic stored-data
writer for the two RAR container generations most often encountered today:

- the `Rar!\x1a\x07\x00` family used by RAR 1.5 through 4.x;
- the VINT-based `Rar!\x1a\x07\x01\x00` family used by RAR 5 and later.

In addition to stored data, Vort decodes non-solid RAR 1.5, RAR 2.0/2.6, and
ordinary RAR 2.9/3.x LZ and PPMd Variant H compressed members. The RAR15 path
implements the historical adaptive
literal/short/long/old-distance state machine and ST mode over a 64 KiB
history. The RAR20 path implements dynamic canonical Huffman tables, table
reuse and multiblock transitions, a 1 MiB LZ history, repeated distances, and
the multimedia/audio predictor. The RAR29 LZ path implements byte-aligned block
tables, table reuse, canonical main/distance/low-distance/length codes,
repeated-distance tokens, low-offset repeats and a 4 MiB history. The RAR29
PPMd path implements the Variant H range coder, model reset/reuse, configurable
escape byte, literal escapes, distance-one repeats, and long match escapes.
RAR29 VM support parses program records and reuse state, recognizes the E8,
E8E9, Itanium, Delta, RGB, and Audio standard programs, and executes other
valid programs in a bounded 256 KiB RAR VM. RAR5 compressed entries remain
classified as `rar50`; non-solid members decode both algorithm table sizes,
multiblock/table-reuse streams, LZ repeat distances, out-of-window zero fill,
and Delta, E8, E8E9, and ARM filters. RAR50 solid sessions retain Huffman,
repeat-distance, last-length, and pre-filter LZ history across members.

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

Regular files use caller-owned or explicitly bounded allocation APIs. PPMd and
RAR VM filters and RAR5 compression require an allocator, so callers use
`extractIntoWithAllocator`,
`extractIntoWithOptions`, `extractAlloc`, or their bounded variants. The
allocator-free `extractInto` API returns `UnsupportedRar29Ppmd` or
`UnsupportedRar29Filter` for those RAR29 members and
`RarEntryRequiresAllocator` for RAR50. `RarDecodeOptions` keeps the output limit
independent from the PPMd model-memory limit and per-invocation VM instruction
budget. These default to 256 MiB and 25 million instructions, respectively. The
independent RAR5 dictionary-size ceiling defaults to `usize`'s maximum; the
declared dictionary bounds match validation but the dictionary is not allocated
eagerly.
`Archive.extractSession` exposes explicit sequential decoding and returns owned
entry data from `nextAlloc`. `extractByNameAllocLimited` and
`extractByNameAllocWithOptions` automatically replay preceding RAR50 members
when the requested entry is a solid continuation. Direct random-access
`extractAlloc` remains an explicit `UnsupportedRarFeature` for such an entry,
because it has no preceding state.
Directories, unsupported compressed data, encrypted entries, encrypted
headers, RAR5 redirections, unknown-size members, incomplete split-volume
members, and unsupported RAR20/RAR29 solid continuations return specific
errors. This prevents an unsupported or incomplete member from being copied as
if it were stored data.

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
keep-table, long-history and audio plus ordinary RAR29 LZ and PPMd literal,
escape, match, mixed-member, and first-solid-member outputs byte-for-byte with
7-Zip. It also covers all six standard RAR VM filters, LZ and PPMd filter
records, 64-channel Delta, program reuse and unusual encoded integers. A
checksum-valid generic-program mutation is compared with its canonical
standard-program output. RAR5 checks cover compression methods 1, 3, and 5,
all four native filters, generated multi-block input, malformed first-block
table reuse, and the legacy out-of-window zero-fill behavior. Solid
coverage includes five archives and nineteen members, including Quick Open
metadata and a seven-member history chain. RAR20/RAR29 solid continuations
retain their explicit unsupported error:

```sh
zig build run-rar-diff -- \
  --7zz path/to/7zz \
  --rars path/to/reference-writer \
  --fixtures path/to/unarc-rs/crates/unarc-rs/tests/rar/multi \
  --legacy-fixtures path/to/rars/tests/fixtures/rar15_40
```

The next functionality stages are RAR5 multi-volume reconstruction and
compressed writing. Encrypted payloads should be added on top of those decoders
rather than approximated in the stored path.
