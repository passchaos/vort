# TAR and compressed tarballs

Vort provides an in-memory, library-first TAR reader and deterministic writer.
The reader validates every 512-byte header checksum and supports regular files,
directories, symbolic links, hard links, USTAR prefixes, POSIX PAX `path`,
`linkpath`, and `size` records, GNU long-name/long-link records, old GNU
`typeflag='S'` sparse maps with chained extension headers, and GNU PAX sparse
formats 0.0, 0.1, and 1.0.

Entries borrow their metadata and payload slices from the archive bytes. A path
is represented by `TarPath`, which avoids allocating for USTAR prefix/name
pairs and provides `eql`, `writeInto`, `alloc`, and `isSafeRelative` helpers.
The safety helper rejects absolute paths, `.`/`..` components, Windows drive
prefixes, and backslashes. Vort never writes archive entry paths to the
filesystem automatically.

Sparse entries expose `TarSparseInfo`: format (`gnu_old`, `pax_0_0`,
`pax_0_1`, or `pax_1_0`), logical size, wire extent count,
the borrowed raw map, and the concatenated stored extent bytes. Its iterator
returns logical offset/length plus the corresponding physical-data offset.
Normal extraction allocates or accepts the logical size, zero-fills holes, and
copies each validated extent. Maps must be ordered, non-overlapping, within the
logical size, agree with `GNU.sparse.numblocks`, and consume exactly the stored
payload. PAX 1.0 map padding must be zero and 512-byte aligned. Output limits
apply to logical size rather than the much smaller physical payload.

```zig
const entries = [_]vort.TarEncodeEntry{
    .{ .name = "folder/", .kind = .directory },
    .{ .name = "folder/data.txt", .data = payload },
};
const tar_gz = try vort.encodeCompressedTarAlloc(allocator, &entries, .{
    .compression = .gzip,
});
defer allocator.free(tar_gz);

const owned = try vort.decodeTarAutoAlloc(allocator, tar_gz, 256 * 1024 * 1024);
defer owned.deinit(allocator);
const decoded = try owned.archive.extractByNameAllocLimited(
    allocator,
    "folder/data.txt",
    64 * 1024 * 1024,
);
defer allocator.free(decoded);
```

Sparse writing uses explicit caller-owned extents:

```zig
const extents = [_]vort.TarSparseDataExtent{
    .{ .offset = 0, .data = "HEAD" },
    .{ .offset = 1024 * 1024 - 4, .data = "TAIL" },
};
const entries = [_]vort.TarEncodeEntry{.{
    .name = "sparse.img",
    .sparse = .{
        .logical_size = 1024 * 1024,
        .extents = &extents,
        // Optional: .format = .gnu_old,
    },
}};
```

The writer defaults to deterministic GNU PAX sparse 1.0; `.format = .gnu_old`
emits the legacy GNU header and as many chained 21-entry extension blocks as
required. Both normalize stored ranges to TAR's 512-byte blocks, merge touching
normalized ranges, insert zeroes only inside those physical blocks, and append
the required zero-length terminal extent. This preserves logical bytes while
remaining compatible with GNU tar; the archive still stores only the selected
physical ranges. Old-GNU names are limited to its 100-byte header field.

`TarCompression` supports raw TAR, gzip, Bzip2, Brotli, Unix compress,
LZMA-Alone, XZ, LZ4 frame, lzip, LZF, Zstandard, and LZOP. This includes `.tar.br`,
`.tar.Z`, `.tar.lzma` / `.tlz`, `.tar.xz`, `.tar.lz4`, `.tar.lz`, `.tar.lzf`,
`.tar.lzo`, and `.tzo`. Detection
uses the outer stream magic where the format provides one. Because LZMA-Alone
has no magic, Vort first recognizes a structurally valid raw TAR, then accepts
a valid LZMA header only when its known output size has TAR's 512-byte alignment
and is large enough to contain the two end blocks, or when it uses the standard
unknown-size marker. XZ, LZMA, and lzip use their compressed LZMA writers, while
LZ4, LZF, and LZOP select compressed or stored representation independently
for each block.
`TarOwnedArchive` owns the decompressed TAR bytes so all borrowed entry paths,
link targets, and payloads remain valid until `deinit`; its `compression` field
reports the format actually selected by automatic decode.

Brotli has no reliable stream magic. `detectTarCompression` therefore remains
a fast structural/signature probe and reports `.none` for Brotli. The
recommended `decodeTarAutoAlloc` path tries Brotli only after raw TAR and every
identifiable wrapper have failed, passes `max_tar_size` directly to the Brotli
decoder, and accepts the result only after complete TAR validation. Explicit
callers may pass `.brotli` to `decodeCompressedTarAlloc` without probing. The
writer uses Vort's compressed-or-stored fast Brotli encoder.

The writer emits reproducible USTAR headers with zero timestamps by default.
Names and link targets longer than the classic fields are represented with PAX
extended headers. Sparse entries use `GNU.sparse.major/minor/name/realsize` and
a payload-prefixed map. `encodeTarAppend` and `encodeCompressedTarAppend` are transactional.

CLI validation surfaces:

```sh
zig build run -- create-tar-file archive.tar.gz payload.bin input.bin gzip
zig build run -- create-tar-file archive.tar.br payload.bin input.bin brotli
zig build run -- create-tar-file archive.tar.lzma payload.bin input.bin lzma
zig build run -- create-tar-file archive.tar.lzf payload.bin input.bin lzf
zig build run -- list-tar-file archive.tar.gz 268435456
zig build run -- extract-tar-file archive.tar.gz payload.bin output.bin 268435456
zig build run-tar-diff
```

`run-tar-diff` requires GNU tar 1.34-compatible sparse handling: GNU tar writes
old-GNU (including a multi-extension fixture) plus PAX 0.0/0.1/1.0 archives
that Vort reconstructs, while Python `tarfile` and GNU tar both extract Vort's
deterministic PAX-1.0 and old-GNU writer output
(`gnu_sparse_reader_cases=5`, `sparse_writer_readers=4`). Sparse entries also
round trip through all twelve compressed-tar wrappers. Device/FIFO materialization is
not implemented. Symbolic and hard links are exposed as metadata but are not
followed or materialized by the in-memory extraction helpers.

## Incremental writer

`TarIncrementalWriter` emits raw TAR through caller output without retaining an
archive or member. `beginEntry` serializes a bounded control prefix; regular
files then accept exactly the pledged size, while directories and links accept
no payload. PAX long path/link records, PAX sparse 1.0 maps, old-GNU sparse
extension chains, entry padding and the two final zero blocks all drain under
arbitrary output backpressure.

Incremental sparse input is the complete logical file. The caller supplies only
offset/length layout metadata; the writer discards declared holes and streams
normalized stored ranges directly. By default every discarded byte must be
zero, so an incorrect sparse map fails with `NonZeroSparseHole` rather than
silently losing data. State contains copied normalized extents, the current TAR
control record, and counters—never the file. One-byte and micro schedules are
byte-identical to `encodeTarAlloc` for regular files, long PAX metadata, links,
PAX sparse and old-GNU sparse.

The external differential requires seven schedule-independent incremental
writer entries (`incremental_writer_cases=7`) and exact byte equality with the
one-shot writer before Python and GNU tar interoperability checks run.
