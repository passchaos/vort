# WIM, ESD, and SWM

Vort provides a dependency-free pure Zig reader for Microsoft's Windows Imaging
Format family. Standard WIM headers, solid-version ESD headers, and split SWM
part headers are recognized.

The parser validates the fixed 208-byte header, version, compression flags,
power-of-two chunk geometry, GUID and part fields, image and boot indexes, and
the bounds of header-owned resources. It exposes lookup entries with their
SHA-1, reference count, part number, flags, stored size, decoded size, and
physical offset. XML data is returned in its original WIM representation,
normally UTF-16LE.

Resource extraction supports:

- uncompressed resources;
- original-format cumulative 32- or 64-bit chunk tables;
- raw chunks selected when stored size equals decoded size;
- XPRESS-Huffman compressed chunks from 4 through 64 KiB;
- WIM LZX compressed chunks from 32 KiB through 2 MiB;
- multi-chunk resources and a partial final chunk;
- SHA-1 verification for lookup-table resources;
- explicit caller output, lookup-entry, and lookup-table byte limits.

Image metadata support validates the security-descriptor prefix, root dentry,
aligned variable-length dentries, UTF-16LE long and short names, extra stream
entries, directory-list terminators, security IDs, child offsets, duplicate
names, and unsafe `.`/`..` or separator-bearing names. `ImageMetadata` owns the
decompressed metadata resource while `Dentry`, names, and stream entries are
borrowed views. Directory arrays are caller-owned and independently bounded.

Path lookup accepts an optional leading `/`, performs exact UTF-16 name
matching, and has caller-selected directory-entry and depth limits. Ordinary
file extraction applies WIM's stream ordering rules: the main hash is the first
unnamed stream, a zero main hash is skipped when unnamed extra streams exist,
and a reparse stream precedes ordinary unnamed data. A zero data hash produces
an empty file without requiring a lookup-table entry. Encrypted files, reparse
points, and files with named NTFS alternate data streams are identified but
intentionally rejected by the path extraction API rather than flattened or
silently misinterpreted.

The shared LZX core preserves its CAB mode and adds WIM block headers and WIM's
fixed-12,000,000-byte Intel E8 postprocessing semantics.

```zig
const archive = try vort.parseWim(image_bytes);
var lookup = try archive.readLookupTableAlloc(
    allocator,
    max_entries,
    max_lookup_bytes,
);
defer lookup.deinit();

const payload = try archive.extractBySha1AllocLimited(
    allocator,
    &sha1,
    max_output,
    max_entries,
    max_lookup_bytes,
);
defer allocator.free(payload);

var image = try archive.readImageMetadataAlloc(allocator, 1, .{});
defer image.deinit();
var root = try image.readDirectoryAlloc(
    allocator,
    image.root,
    1_000_000,
);
defer root.deinit();

const file = try archive.extractByPathAllocLimited(
    allocator,
    1,
    "/Windows/System32/example.dll",
    max_output,
    .{},
);
defer allocator.free(file);
```

```sh
zig build run -- list-wim-file install.wim
zig build run -- extract-wim-resource install.wim SHA1 output.bin 1073741824
zig build run -- extract-wim-xml install.wim metadata.xml 67108864
zig build run -- list-wim-image install.wim 1
zig build run -- extract-wim-path install.wim 1 /Windows/System32/example.dll output.bin 1073741824
zig build run-wim-diff
```

Solid LZMS resource payloads, pipable WIM layout, cross-part SWM resource
assembly, alternate solid chunk tables, encrypted file data, reparse data, and
named alternate-stream extraction are not yet decoded. They return explicit
errors rather than being treated as ordinary resources or files.

The differential gate creates stored, XPRESS, and LZX multi-chunk WIMs with
pinned wimlib, verifies them with `wimlib-imagex`, compares metadata tree paths,
extracts every file through both Vort and wimlib, and compares SHA-1 and bytes.
The generated trees include empty and non-ASCII filenames, while a two-image
archive checks lookup-table metadata ordering. It also covers a solid LZMS ESD
header, two split SWM part headers and cross-part errors, checked-in XPRESS/LZX
fixtures, output limits, missing images/paths/hashes, directory extraction
rejection, and malformed headers. Unit tests additionally mutate security
lengths, UTF-16 name lengths, child offsets, stream counts, duplicate names, and
directory terminators.
