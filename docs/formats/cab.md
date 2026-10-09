# Microsoft CAB support

Vort provides dependency-free deterministic writing, parsing, and bounded
extraction for Microsoft Cabinet archives. The reader supports uncompressed,
MSZIP, LZX, and Quantum folders, including multiple folders, multiple
CFDATA blocks, files that cross block boundaries, and compression history
retained between blocks. Explicitly ordered `CabinetSet` values additionally
join folders and files split across multiple cabinets without filesystem lookup.

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

const parsed_cabinets = [_]vort.CabArchive{
    try vort.parseCabArchive(part1_bytes),
    try vort.parseCabArchive(part2_bytes),
};
const set = try vort.initCabinetSet(&parsed_cabinets);
const split_file = try set.extractByNameAllocLimited(
    allocator,
    "large.bin",
    256 * 1024 * 1024,
);
defer allocator.free(split_file);

const entries = [_]vort.CabEncodeEntry{
    .{ .name = "folder\\payload.bin", .data = payload },
    .{ .name = "empty.bin", .data = "" },
};
const encoded = try vort.encodeCabAlloc(allocator, &entries, .{
    .compression = .quantum,
    .quantum_window_bits = 18,
    .quantum_level = 3,
});
defer allocator.free(encoded);

var encoded_set = try vort.encodeCabinetSetAlloc(allocator, &entries, .{
    .cabinet = .{ .compression = .mszip, .set_id = 42 },
    .max_cabinet_size = 30_000,
    .name_prefix = "payload-",
});
defer encoded_set.deinit(allocator);
```

The parser validates:

- the `MSCF` signature, reserved fields, exact cabinet size, and version 1.3;
- folder/file table offsets, counts, ordering, and non-overlapping data ranges;
- optional CFHEADER, CFFOLDER, and CFDATA reserve areas;
- previous/next cabinet names, disk labels, set IDs, and cabinet indices;
- NUL-terminated names through the format's 256-byte limit and UTF-8 names
  carrying `_A_NAME_IS_UTF`;
- file ranges against the complete uncompressed folder size;
- CFDATA lengths, the 32 KiB uncompressed block limit, and non-zero Cabinet
  checksums using Microsoft's longitudinal XOR algorithm while excluding
  reserved CFDATA bytes as required by the format;
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

`CabinetSet.init` requires a complete caller-ordered sequence beginning at
cabinet index zero. It validates set IDs, indices, previous/next flags,
continued-file metadata, folder compression settings, fragment placement, and
per-fragment checksums. Split `cbUncomp=0` CFDATA payloads are concatenated only
until the next fragment supplies the logical block size; Quantum trailers are
inserted once per completed logical block. Missing, reordered, or mismatched
cabinets fail explicitly. Standalone files in a linked cabinet remain directly
extractable, while continued entries require a `CabinetSet`.

`encodeCabinetSetAlloc` first produces the same logical solid folder as the
single-cabinet writer, then deterministically partitions compressed CFDATA
payloads under the requested total cabinet-size bound. Every non-final cabinet
ends in a `cbUncomp=0` fragment, each following cabinet closes that logical
block, and file records carry the appropriate forward/backward continuation
marker. Generated fixed-width names are linked through the CAB header; the
returned `EncodedCabinetSet` owns both names and bytes. Stored, MSZIP, LZX, and
Quantum use this common partitioner, so codec history and frame state remain
identical to the single-cabinet stream.

The writer emits one deterministic solid folder containing entries in caller
order. Stored, MSZIP, LZX, and Quantum modes are available, with optional
non-zero CFDATA checksums, deterministic DOS dates, automatic UTF-8 attributes,
and a caller-selected set ID. Stored/MSZIP permit configurable 1–32 KiB CFDATA
blocks. MSZIP independently chooses fixed-Huffman or stored Deflate for each
block while retaining the prior 32 KiB folder tail as its dictionary. The
reference LZX writer emits interoperable uncompressed LZX blocks, selectable
15–21 bit windows, mandatory 32 KiB non-final CFDATA records, restored recent
offsets, word alignment, and odd final-block padding. Entropy-coded LZX writing
is a later ratio optimization, not a distinct compatibility surface.
The reference Quantum writer emits literal-only adaptive arithmetic frames,
persists selector/literal models across 32 KiB CFDATA records, supports 10–21
bit windows and declared levels 1–7, and writes bounded null padding before the
CAB-injected frame sentinel. Quantum match selection is likewise a later ratio
optimization. Owned, transactional append, and caller-buffer APIs share the
same wire implementation.

CLI validation surfaces:

```sh
zig build run -- create-cab-file archive.cab path\\file.bin input.bin mszip 32768
zig build run -- create-cab-file archive.cab path\\file.bin input.bin lzx 32768 18
zig build run -- create-cab-file archive.cab path\\file.bin input.bin quantum 32768 18 3
zig build run -- create-cab-set parts path\\file.bin input.bin 30000 mszip
zig build run -- list-cab-file archive.cab
zig build run -- extract-cab-file archive.cab path\\file.bin output.bin 67108864 268435456
zig build run -- extract-cab-set path\\file.bin output.bin part1.cab part2.cab part3.cab
zig build run-cab-diff
```

The required differential uses byte-exact public fixtures from libmspack. It
covers Microsoft's Stored example, an archive mixing MSZIP/LZX/Quantum
folders, and a 26 KiB outer CAB whose 21-bit aligned LZX stream spans 449
CFDATA blocks and expands to a 14,689,228-byte nested CAB. The latter output's
MD5 is checked against libmspack's independent decoder. The normal Quantum
payload is checked byte-for-byte, while three historical libmspack Quantum
regressions pin bounded rejection of frame overshoot, invalid history, and
inconsistent archive sizes. A five-cabinet libmspack set covers linked header
metadata, three cross-cabinet MSZIP folders, split CFDATA, files continued in
both directions, reserve bytes, and six independently hashed outputs.
Vort-written Stored/MSZIP/LZX cabinets are
decoded byte-exactly by libarchive, including multi-frame LZX output with an
odd final block. Cabextract/libmspack independently decodes Vort's multi-frame
Quantum output and all four Vort-written linked cabinet-set modes. Entropy-coded
LZX blocks and Quantum match encoding remain future ratio work.
