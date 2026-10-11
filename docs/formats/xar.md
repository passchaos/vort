# Apple XAR, XIP, and package containers

Vort implements the XAR container used directly as `.xar` and as the outer
container for many `.pkg` and `.xip` files. The library is pure Zig; XML, heap
layout, decompression, and checksums do not depend on libxml, libarchive, or
Apple's `xar` command.

The reader supports:

- version 0/1 headers with bounded compressed and decoded TOC sizes;
- zlib-compressed XML TOCs, nested file trees, directories, and symbolic links;
- stored, zlib (`application/x-gzip`), Bzip2, LZMA-Alone, and XZ payloads;
- TOC plus archived/extracted SHA-1, MD5, SHA-256, and SHA-512 verification;
- bounded entry output and independent LZMA/XZ dictionary limits;
- normalized, traversal-safe paths with duplicate-path rejection.

Unknown payload encodings and checksums are rejected explicitly. Encrypted
entry styles return `error.EncryptedXarEntry`. Hard-link/device semantics,
extended attributes, ACL restoration, signatures, and filesystem extraction
are not synthesized by this layer; their XML remains skippable metadata while
regular payload extraction stays available.

```zig
var archive = try vort.parseXarAlloc(allocator, bytes, .{
    .max_toc_bytes = 256 * 1024 * 1024,
    .max_entry_decoded_bytes = 1024 * 1024 * 1024,
    .max_lzma_dictionary_bytes = 64 * 1024 * 1024,
    .max_xz_dictionary_bytes = 64 * 1024 * 1024,
});
defer archive.deinit();

const payload = try archive.extractByPathAllocLimited(
    allocator,
    "Payload",
    max_output,
);
defer allocator.free(payload);
```

The deterministic writer accepts path-based entries, synthesizes missing parent
directories, and emits files, directories, or symbolic links. It supports
stored/zlib/Bzip2/LZMA/XZ payloads, automatic zlib-or-copy selection, and every
standard XAR checksum algorithm. SHA-1 is the compatibility-oriented default;
stronger algorithms remain caller-selectable.

```sh
zig build run -- inspect-xar package.xar
zig build run -- extract-xar-entry package.xar Payload.out Payload 1073741824
zig build run -- encode-xar-file Payload package.xar Payload zlib sha1
zig build test-xar
zig build run-xar-diff
```

The checked-in fixture was created by Apple's `xar --compression bzip2`. The
differential gate checks all five payload encodings bidirectionally against
libarchive and validates stored/zlib/Bzip2 output with 7-Zip.
