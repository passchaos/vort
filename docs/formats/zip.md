# ZIP32 archive support

Vort provides dependency-free, library-first reading for common single-disk
ZIP32 archives. It parses the end-of-central-directory record and central
directory before exposing entries, so data-descriptor archives use the
authoritative sizes and CRC values instead of trusting incomplete local
headers.

Supported entry methods:

- stored (`method 0`);
- raw Deflate (`method 8`) through the same decoder used by Vort's public raw,
  zlib, and gzip APIs.

The decoder validates local/central method and filename agreement, exact
compressed and uncompressed sizes, complete Deflate consumption, and IEEE
CRC-32. It supports the general-purpose data-descriptor flag with or without a
descriptor signature because extraction boundaries come from the central
directory.

```zig
const archive = try vort.parseZipArchive(zip_bytes);
defer allocator.free(try archive.entriesAlloc(allocator));

const entry = (try archive.find("folder/data.txt")) orelse
    return error.ZipEntryNotFound;
const decoded = try archive.extractAllocLimited(
    allocator,
    entry,
    64 * 1024 * 1024,
);
defer allocator.free(decoded);
```

Convenience functions `zipExtractEntryInto`, `zipExtractEntryAlloc`,
`zipExtractEntryAllocLimited`, `zipExtractByNameAlloc`, and
`zipExtractByNameAllocLimited` parse and extract in one call. Entry names are
returned as borrowed archive bytes. Vort never automatically joins an entry
name to a filesystem path; callers therefore retain explicit control over
Zip-Slip/path-traversal policy.

CLI validation surfaces:

```sh
zig build run -- list-zip-file archive.zip
zig build run -- extract-zip-file archive.zip folder/data.txt output.txt 67108864
zig build run-zip-diff
```

The current slice deliberately rejects encrypted entries, multi-disk archives,
ZIP64 sentinel fields, and compression methods other than stored/Deflate with
specific errors. Those are explicit future compatibility increments rather
than silently accepted partial behavior.
