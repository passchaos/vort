# Microsoft CAB support

Vort provides dependency-free parsing and bounded extraction for single-file
Microsoft Cabinet archives. The reader supports uncompressed folders and
MSZIP folders, including multiple folders, multiple CFDATA blocks, files that
cross block boundaries, and the 32 KiB Deflate history retained between MSZIP
blocks.

```zig
const cabinet = try vort.parseCabArchive(bytes);
const entry = (try cabinet.find("folder\\payload.bin")) orelse
    return error.CabinetEntryNotFound;
const decoded = try vort.cabExtractAllocWithOptions(
    allocator,
    cabinet,
    entry,
    .{
        .max_file_size = 64 * 1024 * 1024,
        .max_folder_size = 256 * 1024 * 1024,
    },
);
defer allocator.free(decoded);
```

The parser validates:

- the `MSCF` signature, reserved fields, exact cabinet size, and version 1.3;
- folder/file table offsets, counts, ordering, and non-overlapping data ranges;
- optional CFHEADER, CFFOLDER, and CFDATA reserve areas;
- NUL-terminated names through the format's 256-byte limit and UTF-8 names
  carrying `_A_NAME_IS_UTF`;
- file ranges against the complete uncompressed folder size;
- CFDATA lengths, the 32 KiB uncompressed block limit, and non-zero Cabinet
  checksums using Microsoft's longitudinal XOR algorithm;
- MSZIP's mandatory `CK` marker, exact raw-Deflate consumption, exact decoded
  block sizes, and cross-block history.

CAB folders are solid streams, so extracting one file can require decoding the
whole containing folder. `CabExtractOptions` therefore separates
`max_file_size` from `max_folder_size`. Caller-owned extraction and direct
folder decode APIs also retain explicit allocator and limit control. Entry
names remain borrowed bytes; `CabEntry.isSafeRelative` recognizes both slash
styles and rejects absolute, drive-prefixed, empty-component, `.` and `..`
paths. Vort never materializes archive paths automatically.

CLI validation surfaces:

```sh
zig build run -- list-cab-file archive.cab
zig build run -- extract-cab-file archive.cab path\\file.bin output.bin 67108864 268435456
zig build run-cab-diff
```

The required differential uses byte-exact public fixtures from libmspack and
covers both Microsoft's specification example and an archive mixing MSZIP,
LZX, and Quantum folders. Supported MSZIP content extracts successfully even
when other folders use unsupported algorithms. LZX, Quantum, split CFDATA
blocks, and multi-cabinet continuation currently return explicit unsupported
errors instead of being guessed. CAB writing is a future functionality slice.
