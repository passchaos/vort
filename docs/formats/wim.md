# WIM, ESD, and SWM

Vort provides a dependency-free pure Zig reader for Microsoft's Windows Imaging
Format family. Standard WIM headers, solid-version ESD headers, and split SWM
part headers are recognized. Seekable byte slices using wimlib's pipable WIM
extension are recognized through their `WLPWM` leading and trailing headers.
`WimPipableStreamPathExtractor` also consumes this layout incrementally without
requiring the trailing header or a seekable source.

The parser validates the fixed 208-byte header, version, compression flags,
power-of-two chunk geometry, GUID and part fields, image and boot indexes, and
the bounds of header-owned resources. Pipable parsing requires matching archive
identity in both 208-byte headers, zero preliminary resource descriptors, and
keeps final-header resources out of the trailing header. It exposes lookup
entries with their SHA-1, reference count, part number, flags, stored size,
decoded size, and physical offset. XML data is returned in its original WIM
representation, normally UTF-16LE.

Resource extraction supports:

- uncompressed resources;
- original-format cumulative 32- or 64-bit chunk tables;
- raw chunks selected when stored size equals decoded size;
- XPRESS-Huffman compressed chunks from 4 through 64 KiB;
- WIM LZX compressed chunks from 32 KiB through 2 MiB;
- LZMS compressed chunks from 32 KiB through 1 GiB;
- multi-chunk resources and a partial final chunk;
- pipable 40-byte blob headers, per-chunk size headers, and trailing cumulative
  chunk tables with redundant-offset validation;
- SHA-1 verification for lookup-table resources;
- explicit caller output, lookup-entry, and lookup-table byte limits.

Solid-version resources use their 16-byte alternate chunk-table header rather
than the ordinary cumulative-offset table. Vort resolves the overloaded lookup
entries into resource markers and non-overlapping blob ranges, validates every
per-chunk compressed size, and decodes only the chunks overlapping the selected
blob. This supports multi-chunk solid LZMS ESD extraction without allocating or
decoding the complete solid resource; output and decoded-chunk scratch have
separate caller limits.

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
an empty file without requiring a lookup-table entry. Named NTFS alternate
streams are selected by exact UTF-8/UTF-16 name through
`extractNamedStreamByPathAllocLimited`; their presence no longer prevents
ordinary default-stream extraction. Reparse points expose the stored tag and
raw reparse buffer through `reparseTag`, `reparseDataSha1`, and
`extractReparseDataByPathAllocLimited`. Callers that already retain metadata and
the lookup table can use `extractDentryStreamAllocLimited` with `.default`,
`.named`, `.reparse`, or `.encrypted_raw` without repeating path traversal.
Every selected hash still uses the normal output, solid-chunk, part-number, and
SHA-1 checks.

Files and directories with `FILE_ATTRIBUTE_ENCRYPTED` expose their single
opaque MS-EFSR/EFSRPC raw stream through `encryptedRawDataSha1` and
`extractEncryptedRawByPathAllocLimited`. This is the byte stream produced by
Windows `ReadEncryptedFileRaw()` and consumed by `WriteEncryptedFileRaw()`; it
contains EFS metadata plus ciphertext for all data streams and is deliberately
not returned by ordinary `.default` extraction. Vort requires exactly one
nonempty unnamed raw stream and rejects named, duplicate, missing, zero-hash,
or reparse combinations. Decryption requires the user's EFS certificate/private
key and Windows EFS semantics, not an archive password or a standalone AES
operation, so there is no applicable Vail primitive to compose at this layer.

Incremental pipable extraction borrows the requested path and optional named
stream, retains only the selected image metadata plus one encoded and decoded
compression chunk, and writes selected file bytes into caller buffers. It skips
the leading XML resource, decodes the selected metadata resource, resolves the
path before file blobs arrive, then scans blob headers until the selected SHA-1
appears. Empty files finish immediately after metadata. Stored, XPRESS, LZX,
default, named, reparse, and encrypted-raw streams share the same state machine
and SHA-1 verification. `step` reports exact input/output progress and
`need_input`, `need_output`, or `done`; `finish` distinguishes truncation from a
complete stream that lacks the selected blob. Caller limits bound metadata,
output, directory traversal, path depth, and chunk scratch.

Concatenated pipable SWM parts are accepted only in exact order. The extractor
consumes the prior part's trailing header and the next part's preliminary
header, cross-checks GUID/version/compression/chunk/image geometry, and rejects
missing, reversed, skipped, or repeated transitions. Per-chunk size headers are
authoritative during pipe decoding; the seek-only cumulative table at each
resource tail is consumed without buffering it.

Extra-stream validation rejects separator-bearing or duplicate names and
impossible unnamed-stream multiplicity. A regular file may have at most one
unnamed extra data stream; a reparse point may have a reparse stream followed by
ordinary unnamed data. Stream-name conversion allocations and selected-resource
extraction are covered by exhaustive allocation-failure tests.

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

const parts = [_]vort.WimArchive{
    try vort.parseWim(first_part_bytes),
    try vort.parseWim(second_part_bytes),
};
const set = try vort.WimArchiveSet.init(&parts);
const split_file = try set.extractByPathAllocLimited(
    allocator,
    1,
    "/sources/install.esd",
    max_output,
    .{},
);
defer allocator.free(split_file);
```

```sh
zig build run -- list-wim-file install.wim
zig build run -- extract-wim-resource install.wim SHA1 output.bin 1073741824
zig build run -- extract-wim-xml install.wim metadata.xml 67108864
zig build run -- list-wim-image install.wim 1
zig build run -- extract-wim-path install.wim 1 /Windows/System32/example.dll output.bin 1073741824
zig build run -- extract-wim-stream install.wim 1 /file.txt Zone.Identifier zone.bin 1048576
zig build run -- extract-wim-reparse install.wim 1 /link reparse.bin 1048576
zig build run -- extract-wim-encrypted-raw install.wim 1 /secret.dat secret.efsrpc 1073741824
zig build run -- extract-wim-pipable-stream-path pipable.wim 1 /large.bin output.bin 2147483648 4096 32768
zig build run -- list-wim-parts-image 1 install.swm install2.swm
zig build run -- extract-wim-parts-path 1 /large.bin output.bin 2147483648 install.swm install2.swm
zig build run-wim-diff
```

`WimArchiveSet` borrows an explicitly ordered caller-provided archive slice; it
never guesses sibling filenames. Initialization requires every part exactly
once in `1...total_parts` order and cross-checks GUID, version, compression,
chunk geometry, layout, image count, and boot index. Each part owns a local
lookup table; the set merges them under the caller's aggregate entry/byte limits
and requires every entry to name its containing part. Standalone and solid
resources are then routed by part number. Solid resource markers are parsed
from their owning part rather than interpreting the same physical offset in
part 1. Missing,
reordered, duplicate-position, or mismatched sets fail before extraction.
Metadata, default data, ADS, reparse buffers, SHA-1, output, lookup and solid
chunk limits are identical to the single-archive APIs; EFSRPC raw resources use
the same owning-part routing.

EFS certificate/private-key decryption, container-level encrypted ESD segments,
and filesystem application of EFSRPC/reparse/alternate-stream semantics remain
follow-up work. The library exposes and verifies raw content without invoking
Windows filesystem mutation implicitly.

The differential gate creates stored, XPRESS, and LZX multi-chunk WIMs with
pinned wimlib, verifies them with `wimlib-imagex`, compares metadata tree paths,
extracts every file through both Vort and wimlib, and compares SHA-1 and bytes.
The generated trees include empty and non-ASCII filenames, while a two-image
archive checks lookup-table metadata ordering. It also fully extracts a
multi-chunk solid LZMS ESD through both Vort and wimlib, covers two split SWM
part headers and cross-part errors, and keeps checked-in XPRESS/LZX/LZMS plus
pipable XPRESS fixtures. The external matrix rebuilds none/XPRESS/LZX pipable
WIMs, exercises multi-chunk extraction, and byte-compares a two-part pipable
SWM set. The same generated images are fed through bounded incremental cuts for
stored/XPRESS/LZX, empty, reparse, and concatenated split paths. Negative
coverage includes output limits, missing images/paths/hashes,
directory extraction rejection, missing named streams, non-reparse selection,
malformed headers, security lengths, UTF-16 name lengths, child offsets, stream
counts, duplicate/unsafe stream names, alternate chunk headers, and directory
terminators. When wimlib is available, each generated compression mode also
captures a Unix symbolic link, requires Vort to list and extract its raw reparse
buffer, and requires wimlib to restore the same link target. Its split fixture
also requires two-part `WimArchiveSet` listing and byte-exact cross-part path
extraction, plus missing and reversed set rejection. A synthetic wire-valid
encrypted dentry pins opaque EFSRPC export and plaintext-selector rejection;
wimlib independently verifies and labels the same entry as a raw encrypted data
stream.
