# RAR archive support

Vort provides a dependency-free pure Zig parser and deterministic
stored/compressed writer for the two RAR container generations most often
encountered today:

- the `Rar!\x1a\x07\x00` family used by RAR 1.5 through 4.x;
- the VINT-based `Rar!\x1a\x07\x01\x00` family used by RAR 5 and later.

In addition to stored data, Vort decodes non-solid RAR 1.5 and RAR 2.0/2.6,
plus ordinary and solid RAR 2.9/3.x LZ and PPMd Variant H compressed members.
The RAR15 path
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
and path-safety classification. RAR5 encrypted entries additionally expose the
version, flags, KDF count, salt, IV, and optional password-check record.

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
eagerly. `password` enables RAR5 file-data decryption and
`max_rar5_kdf_count` independently bounds its binary-log PBKDF2 work before
derivation or output allocation. The default ceiling is 24.

RAR5 Stored and RAR50 entries support AES-256-CBC file-data encryption with
PBKDF2-HMAC-SHA256, the 8+4-byte password-check record, zero-padded cipher
blocks, and password-dependent CRC-32 verification. The cryptographic
primitives come from `../vail/archive_crypto`; Vort owns only the RAR extra
record, limits, padding, checksum policy, and codec composition. Missing,
wrong, malformed, and over-budget passwords/KDF records have distinct errors.

RAR5 encrypted headers use `parseRarOwnedHeadersAllocWithOptions`. The returned
`RarOwnedHeaderArchive` borrows the original archive data but owns decrypted
entry metadata and names, so those views remain valid until `deinit`. The
ordinary borrowed parser continues to return `EncryptedRarHeaders` rather than
hiding temporary allocation. The owned parser validates the clear type-4
encryption header, derives its key once, then processes each following header
as an independent 16-byte IV plus block-aligned AES-CBC payload. Entry count and
copied-name bytes have independent limits in addition to KDF and output limits.
`Archive.extractSession` exposes explicit sequential decoding and returns owned
entry data from `nextAlloc`. `extractByNameAllocLimited` and
`extractByNameAllocWithOptions` automatically replays preceding RAR29 or RAR50
members when the requested entry is a solid continuation. Direct random-access
`extractAlloc` remains an explicit `UnsupportedRarFeature` for such an entry,
because it has no preceding state.
`parseRarVolumeSetAlloc` accepts an ordered slice of borrowed volume bytes. It
validates RAR5 volume numbers and next-volume flags, groups contiguous
split-before/split-after fragments into logical entries, and rejects missing,
reversed, interrupted, or metadata-changing fragment chains. Its extraction
session concatenates packed fragments before decoding and carries RAR50 solid
state across logical entries and volume boundaries.
`parseRarVolumeSetAllocWithOptions` applies the same owned-header/password
policy independently to every volume. Encrypted member ciphertext is joined
across arbitrary fragment cuts before one CBC decode, matching RAR's reuse of
the same file salt/IV record in every fragment.
Directories, unsupported compressed data, RAR4 encrypted entries, encrypted
RAR5 redirections, unknown-size members, incomplete split-volume members, and
unsupported RAR20 solid
continuations return specific errors. This prevents an unsupported or
incomplete member from being copied as if it were stored data.

RAR4 Unicode names use a historical custom encoding. The current borrowed
parser exposes their ANSI fallback name; RAR5 names are the archive's UTF-8
bytes. Adding an allocator-backed RAR4 Unicode-name view remains future work.

## Writer

`encodeRarAlloc`, `encodeRarAppend`, and `encodeRarInto` emit deterministic
multi-entry RAR4 or RAR5 archives with regular files and directories. RAR4
regular files can select `.compression = .rar29`; the writer emits real RAR29
LZ blocks with complete canonical main/distance/low-distance/length tables,
RAR table-length RLE, hash-indexed matches, and new/repeat/last-distance tokens.
Blocks default to 64 KiB, and the declared dictionary can be 64 KiB, 128 KiB,
256 KiB, 512 KiB, 1 MiB, 2 MiB, or 4 MiB. RAR5 regular files can select
`.compression = .rar50`; its portable baseline uses the corresponding RAR50
wire format. Directories remain stored in both generations.
RAR4 callers can instead select `.compression = .rar29_ppmd` for a native
Variant H range-coded stream. `ppmd_order` defaults to 8 and
`ppmd_memory_size` defaults to 25 MiB; memory is explicit, MiB-aligned, and
encoded in the standard RAR29 PPMd block header. Literal escape bytes, empty
members, block termination, model reset, and solid model continuation are
supported. The current writer intentionally omits PPMd-to-LZ match escape
selection; this affects ratio, not wire compatibility or decoded content.
`encodeRar29PpmdAlloc` and reusable `Rar29PpmdEncoder` expose the same raw
member codec beneath the archive writer.
`.solid = true` on RAR29 retains the 4 MiB-or-smaller LZ window and match state
across consecutive compressed members, sets the RAR4 main/file solid flags,
and supports sequential extraction plus by-name replay. Stored members and
directories terminate both RAR29 LZ and PPMd compression chains.
RAR29 LZ output can apply E8, E8E9, Delta, Itanium, RGB, or Audio filters.
The writer emits canonical RAR VM program bytecode, declares/reuses programs
across blocks, and bounds filter blocks to the VM-compatible 120–128 KiB
range. RGB and Audio parameters are explicit. Filtered RAR29 solid and PPMd
writing remain rejected until their combined cross-member semantics are
exposed by the public API.
RAR50 output can additionally select a whole-member Delta, E8, E8E9, or ARM
filter. The writer applies the forward transform independently to each legal
filter-sized block, writes native filter records, and uses absolute member
offsets for executable transforms.
`.solid = true` on RAR50 keeps LZ history and repeat-distance state across
consecutive compressed members and writes both the archive and per-file
continuation flags. A stored file or directory ends the current compression
chain, so the next compressed member starts non-solid. Filtered solid writing is rejected
until cross-member transformed-history semantics are exposed explicitly.
`RarEncodeEntry.encryption` encrypts either Stored or RAR50 member data after
compression, including solid continuations. Callers provide a UTF-8 password,
unique 16-byte salt and IV, and an optional KDF count; the default writer emits
both the password check and keyed-checksum flags. Salt/IV randomness remains
explicitly caller-owned so the library has no hidden global state and fixtures
remain deterministic.
`RarEncodeOptions.header_encryption` adds the clear archive-encryption header
and encrypts main, every file/directory, and end header independently. It takes
one caller-supplied unique IV per encrypted header (`entries.len + 2` in the
single-archive writer), rejects duplicates, and requires every regular entry to use
file-data encryption with the same password. Header and file salts, IVs, and
KDF counts remain independent. This composes with Stored, RAR50, directories,
and solid RAR50 history without exposing names in the wire.
`encodeRarVolumesAlloc` splits logical RAR5 members at an explicit maximum
payload-per-volume budget and returns an owned `EncodedVolumes` collection. It
writes numbered volume main headers, per-fragment split flags and CRCs, and
next-volume end flags; stored, compressed, and solid compressed members can all
span volumes. It also encrypts complete member data before arbitrary fragment
cuts and can encrypt every per-volume main/fragment/end header; callers provide
the exact flat IV sequence consumed in volume wire order. Header bytes are
intentionally outside the payload budget.
The writers emit standard header/data CRCs, Unix attributes, optional
generation-native timestamps (DOS date/time for RAR4, Unix seconds for RAR5),
RAR4 end blocks, and RAR5 end headers.

RAR4 output accepts safe ASCII names and converts `/` to the traditional `\`
separator. RAR5 output accepts validated UTF-8 names. Both writers reject NUL,
absolute, empty-component, dot, and parent-component paths. RAR29 compression
rejects unsupported filter/codec combinations instead of relabeling them.
RAR50 dictionary sizes must be power-of-two
multiples of 128 KiB. RAR4 encryption, recovery records, comments, and
redirections remain future writer work.

## CLI

```sh
zig build run -- create-rar-file output.rar payload.bin input.bin rar5
zig build run -- create-rar-file output.rar payload.bin input.bin rar4 rar29
zig build run -- create-rar-file output.rar payload.bin input.bin rar4 rar29 e8e9
zig build run -- create-rar-file output.rar payload.bin input.bin rar4 rar29 rgb:1920:0
zig build run -- create-rar-file output.rar payload.bin input.bin rar4 rar29-ppmd
zig build run -- create-rar-file output.rar payload.bin input.bin rar5 rar50
zig build run -- create-rar-file output.rar payload.bin input.bin rar5 rar50 e8e9
zig build run -- create-rar-file output.rar payload.bin input.bin rar5 rar50 none solid
zig build run -- create-rar-file secret.rar payload.bin input.bin rar5 rar50 none non-solid password 000102030405060708090a0b0c0d0e0f 101112131415161718191a1b1c1d1e1f 15
zig build run -- create-rar-file secret-names.rar payload.bin input.bin rar5 rar50 none non-solid password 000102030405060708090a0b0c0d0e0f 101112131415161718191a1b1c1d1e1f 15 password 202122232425262728292a2b2c2d2e2f 404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f 15
zig build run -- create-rar-volumes output payload.bin input.bin 1048576 rar50 none solid
zig build run -- list-rar-file secret-names.rar password
zig build run -- extract-rar-file secret.rar payload.bin decoded.bin 1048576 password
```

The writer version is `rar4` or `rar5`; `rar5` is the default. Compression is
`stored` by default, `rar29` for RAR4 LZ compatibility compression,
`rar29-ppmd` for RAR4 PPMd Variant H, or `rar50` for RAR5 compression. The
optional filter is `delta:N`, `e8`, `e8e9`, `arm`, `itanium`, `rgb:W:R`, or
`audio:N`. RAR29 supports every listed filter except ARM; RAR50 supports Delta,
E8, E8E9, and ARM.
The final optional mode is `solid`; it matters for multi-entry library calls,
while the single-entry CLI command mainly validates header generation.
`create-rar-volumes` writes `output.part1.rar`, `output.part2.rar`, and so on;
its size argument is the packed payload budget per volume.

## Differential validation

`tools/rar/diff.py` performs deterministic/self round trips, validates stored,
multiblock RAR29 LZ, ordinary/solid RAR29 PPMd, and multiblock RAR50 writer
output plus all six RAR29 and four RAR50 writer filters with 7-Zip, reads stored
RAR4/RAR5 output from an optional rars-based
reference helper, verifies file-data and encrypted-header Stored/RAR50 output
bidirectionally with RAR and 7-Zip, verifies that real compressed reference
entries are classified correctly, checks SFX parsing and both CRC layers, exercises RAR2
and RAR5 split-volume fixtures, and compares RAR15/RAR20 text, multiblock,
keep-table, long-history and audio plus ordinary RAR29 LZ and PPMd literal,
escape, match, mixed-member, and solid-member outputs byte-for-byte with
7-Zip. It also covers all six standard RAR VM filters, LZ and PPMd filter
records, 64-channel Delta, program reuse and unusual encoded integers. A
checksum-valid generic-program mutation is compared with its canonical
standard-program output. RAR5 checks cover compression methods 1, 3, and 5,
all four native filters, generated multi-block input, malformed first-block
table reuse, and the legacy out-of-window zero-fill behavior. Solid
coverage includes five archives and nineteen members, including Quick Open
metadata and a seven-member history chain. RAR20 solid continuations retain
their explicit unsupported error:

```sh
zig build run-rar-diff -- \
  --7zz path/to/7zz \
  --rar path/to/rar \
  --rars path/to/reference-writer \
  --fixtures path/to/unarc-rs/crates/unarc-rs/tests/rar/multi \
  --legacy-fixtures path/to/rars/tests/fixtures/rar15_40
```

The CLI validation surface accepts an explicit ordered volume list:

```sh
zig build run -- extract-rar-volumes entry.bin output.bin 1048576 --password=password \
  archive.part1.rar archive.part2.rar archive.part3.rar
```

RAR4 payload encryption remains the next encryption stage. The next RAR4
writer stages also include PPMd-attached VM filters and multi-volume output.
PPMd hybrid match escapes remain a later compression-ratio optimization.
