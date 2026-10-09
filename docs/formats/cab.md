# Microsoft CAB support

Vort provides dependency-free deterministic writing, parsing, and bounded
extraction for single-file Microsoft Cabinet archives. The reader supports
uncompressed and MSZIP/LZX folders, including multiple folders, multiple
CFDATA blocks, files that cross block boundaries, and compression history
retained between blocks.

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

const entries = [_]vort.CabEncodeEntry{
    .{ .name = "folder\\payload.bin", .data = payload },
    .{ .name = "empty.bin", .data = "" },
};
const encoded = try vort.encodeCabAlloc(allocator, &entries, .{
    .compression = .mszip,
});
defer allocator.free(encoded);
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
  block sizes, and cross-block history;
- LZX 15–21 bit windows, verbatim/aligned/uncompressed blocks, delta-coded
  canonical Huffman trees, repeated offsets, 32 KiB frames, and Intel E8
  postprocessing.

CAB folders are solid streams, so extracting one file can require decoding the
whole containing folder. `CabExtractOptions` therefore separates
`max_file_size` from `max_folder_size`. Caller-owned extraction and direct
folder decode APIs also retain explicit allocator and limit control. Entry
names remain borrowed bytes; `CabEntry.isSafeRelative` recognizes both slash
styles and rejects absolute, drive-prefixed, empty-component, `.` and `..`
paths. Vort never materializes archive paths automatically.

The writer emits one deterministic solid folder containing entries in caller
order. Stored and MSZIP modes are available, with a configurable 1–32 KiB
CFDATA block size, optional non-zero CFDATA checksums, deterministic DOS dates,
automatic UTF-8 attributes, and a caller-selected set ID. MSZIP independently
chooses fixed-Huffman or stored Deflate for each block while retaining the
prior 32 KiB folder tail as its dictionary. Owned, transactional append, and
caller-buffer APIs share the same wire implementation.

CLI validation surfaces:

```sh
zig build run -- create-cab-file archive.cab path\\file.bin input.bin mszip 32768
zig build run -- list-cab-file archive.cab
zig build run -- extract-cab-file archive.cab path\\file.bin output.bin 67108864 268435456
zig build run-cab-diff
```

The required differential uses byte-exact public fixtures from libmspack. It
covers Microsoft's Stored example, an archive mixing MSZIP/LZX/Quantum
folders, and a 26 KiB outer CAB whose 21-bit aligned LZX stream spans 449
CFDATA blocks and expands to a 14,689,228-byte nested CAB. The latter output's
MD5 is checked against libmspack's independent decoder. Supported files extract
successfully even when another folder uses Quantum. Quantum, split CFDATA
blocks, and multi-cabinet continuation currently return explicit unsupported
errors instead of being guessed. Vort-written Stored/MSZIP cabinets are decoded
byte-exactly by libarchive; LZX/Quantum writing is future functionality.
