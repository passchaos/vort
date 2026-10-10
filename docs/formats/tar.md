# TAR and compressed tarballs

Vort provides an in-memory, library-first TAR reader and deterministic writer.
The reader validates every 512-byte header checksum and supports regular files,
directories, symbolic links, hard links, USTAR prefixes, POSIX PAX `path`,
`linkpath`, and `size` records, and GNU long-name/long-link records.

Entries borrow their metadata and payload slices from the archive bytes. A path
is represented by `TarPath`, which avoids allocating for USTAR prefix/name
pairs and provides `eql`, `writeInto`, `alloc`, and `isSafeRelative` helpers.
The safety helper rejects absolute paths, `.`/`..` components, Windows drive
prefixes, and backslashes. Vort never writes archive entry paths to the
filesystem automatically.

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
extended headers. `encodeTarAppend` and `encodeCompressedTarAppend` are
transactional.

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

Sparse files and device/FIFO extraction are not implemented. Symbolic and hard
links are exposed as metadata but are not followed or materialized by the
in-memory extraction helpers.
