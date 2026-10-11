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
```

```sh
zig build run -- list-wim-file install.wim
zig build run -- extract-wim-resource install.wim SHA1 output.bin 1073741824
zig build run -- extract-wim-xml install.wim metadata.xml 67108864
zig build run-wim-diff
```

Solid LZMS resource payloads, pipable WIM layout, cross-part SWM resource
assembly, alternate solid chunk tables, and filesystem metadata directory/path
traversal are not yet decoded. They return explicit errors rather than being
treated as ordinary WIM resources.

The differential gate creates stored, XPRESS, and LZX multi-chunk WIMs with
pinned wimlib, verifies them with `wimlib-imagex`, and compares every file by
SHA-1 and bytes. It also covers a solid LZMS ESD header, two split SWM part
headers, checked-in XPRESS/LZX fixtures, output limits, missing hashes, and
malformed headers.
