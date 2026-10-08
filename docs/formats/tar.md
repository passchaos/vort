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

`TarCompression` supports raw TAR, gzip, Bzip2, XZ, Zstandard, and LZOP
(`.tar.lzo`/`.tzo`). Detection is based on the outer stream magic.
`TarOwnedArchive` owns the decompressed TAR
bytes so all borrowed entry paths, link targets, and payloads remain valid
until `deinit`.

The writer emits reproducible USTAR headers with zero timestamps by default.
Names and link targets longer than the classic fields are represented with PAX
extended headers. `encodeTarAppend` and `encodeCompressedTarAppend` are
transactional.

CLI validation surfaces:

```sh
zig build run -- create-tar-file archive.tar.gz payload.bin input.bin gzip
zig build run -- list-tar-file archive.tar.gz 268435456
zig build run -- extract-tar-file archive.tar.gz payload.bin output.bin 268435456
zig build run-tar-diff
```

Sparse files and device/FIFO extraction are not implemented. Symbolic and hard
links are exposed as metadata but are not followed or materialized by the
in-memory extraction helpers.
