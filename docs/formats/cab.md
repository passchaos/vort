# Microsoft CAB support

Vort provides dependency-free deterministic writing, parsing, and bounded
extraction for Microsoft Cabinet archives. The reader supports uncompressed,
MSZIP, LZX, and Quantum folders, including multiple folders, multiple
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
    .compression = .lzx,
    .lzx_window_bits = 18,
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
  postprocessing;
- Quantum 10–21 bit windows, adaptive arithmetic models, literal and all three
  match selectors, 32 KiB arithmetic-state resets, persistent cross-frame
  models/history, and bounded CFDATA trailer scanning.

CAB folders are solid streams, so extracting one file can require decoding the
whole containing folder. `CabExtractOptions` therefore separates
`max_file_size` from `max_folder_size`. Caller-owned extraction and direct
folder decode APIs also retain explicit allocator and limit control. Entry
names remain borrowed bytes; `CabEntry.isSafeRelative` recognizes both slash
styles and rejects absolute, drive-prefixed, empty-component, `.` and `..`
paths. Vort never materializes archive paths automatically.

The writer emits one deterministic solid folder containing entries in caller
order. Stored, MSZIP, and LZX modes are available, with optional non-zero
CFDATA checksums, deterministic DOS dates, automatic UTF-8 attributes, and a
caller-selected set ID. Stored/MSZIP permit configurable 1–32 KiB CFDATA
blocks. MSZIP independently chooses fixed-Huffman or stored Deflate for each
block while retaining the prior 32 KiB folder tail as its dictionary. The
reference LZX writer emits interoperable uncompressed LZX blocks, selectable
15–21 bit windows, mandatory 32 KiB non-final CFDATA records, restored recent
offsets, word alignment, and odd final-block padding. Entropy-coded LZX writing
is a later ratio optimization, not a distinct compatibility surface. Owned,
transactional append, and caller-buffer APIs share the same wire implementation.

CLI validation surfaces:

```sh
zig build run -- create-cab-file archive.cab path\\file.bin input.bin mszip 32768
zig build run -- create-cab-file archive.cab path\\file.bin input.bin lzx 32768 18
zig build run -- list-cab-file archive.cab
zig build run -- extract-cab-file archive.cab path\\file.bin output.bin 67108864 268435456
zig build run-cab-diff
```

The required differential uses byte-exact public fixtures from libmspack. It
covers Microsoft's Stored example, an archive mixing MSZIP/LZX/Quantum
folders, and a 26 KiB outer CAB whose 21-bit aligned LZX stream spans 449
CFDATA blocks and expands to a 14,689,228-byte nested CAB. The latter output's
MD5 is checked against libmspack's independent decoder. The normal Quantum
payload is checked byte-for-byte, while three historical libmspack Quantum
regressions pin bounded rejection of frame overshoot, invalid history, and
inconsistent archive sizes. Split CFDATA blocks and multi-cabinet continuation
remain explicit unsupported errors. Vort-written Stored/MSZIP/LZX cabinets are
decoded byte-exactly by libarchive, including multi-frame LZX output with an
odd final block. Entropy-coded LZX blocks and Quantum writing remain future
work.
