# WIM, ESD, and SWM

Vort provides a dependency-free pure Zig reader and deterministic single-image
writer for Microsoft's Windows Imaging Format family. Standard WIM headers,
solid-version ESD headers, and split SWM
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

Container-level encrypted ESD segments are a separate supported mechanism.
`readEncryptedEsdInfoAlloc` parses the UTF-16LE `<ESD>` block, RSA-wrapped
session key, and ordered absolute byte ranges under explicit XML/key/range
limits. `decryptEncryptedEsdAllocLimited` accepts a caller-supplied 2048- or
4096-bit CryptoAPI RSA PRIVATEKEYBLOB; Vail performs best-effort constant-time
finite-field private exponentiation, RSA-OAEP-SHA1 validation, and AES-256-CBC range
decryption with the CryptoAPI zero-IV semantics. Callers that already possess
the 32-byte session key can use `decryptEncryptedEsdWithAesKeyAllocLimited`.
Vort never bundles Microsoft release keys and never overwrites the source: it
returns a caller-owned decrypted image after checking range alignment, order,
overlap, XML/integrity exclusion, and output limits.

The decrypted image is fully reconstructed rather than merely having its
payload ranges changed. Vort removes the `<ESD>` block, reaches a fixed point
for the UTF-16LE `TOTALBYTES` value, updates XML/integrity resource descriptors,
recomputes every integrity-table SHA-1 chunk through the lookup table, relocates
the integrity table, and truncates the result. This makes the result consumable
by ordinary WIM/ESD tools.

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

The writer accepts borrowed relative UTF-8 paths, ordinary file data, named
streams, reparse data, and opaque EFSRPC raw streams through `WimEncodeEntry`.
It inserts missing parent directories, sorts the complete tree deterministically,
rejects duplicate and ASCII-case-ambiguous sibling and stream names, and writes
real security-prefix/dentry/child-list metadata rather than a flat resource
bundle. Empty streams use WIM's zero SHA-1 convention; identical nonempty data
is stored once with an accumulated lookup reference count across every stream.

Named streams use `WimEncodeNamedStream`. `WimEncodeReparseData` carries the
dentry tag/reserved/fixup fields separately from the reparse stream bytes, which
match the reader contract and exclude the common eight-byte
`REPARSE_DATA_BUFFER` header. `encrypted_raw` accepts the already-packed opaque
stream produced by Windows `ReadEncryptedFileRaw()`; it must be nonempty and is
mutually exclusive with plaintext, named, and reparse streams. Vort sets the
corresponding file attributes rather than accepting contradictory caller bits.
No Vail operation is applicable because this API preserves ciphertext and EFS
metadata rather than decrypting or constructing them.

Serialization follows the DISM-compatible stream rules: one ordinary,
reparse, or EFS raw stream occupies `main_hash`; the presence of a named stream
or both reparse and ordinary data clears `main_hash` and writes extra-stream
records in reparse, ordinary, then named order. Named and reparse streams on
directories are selectable through the same archive APIs as file streams.

Each entry may also borrow a self-relative Windows security descriptor through
`security_descriptor`; the root uses `root_security_descriptor`. The writer
validates descriptor headers, self-relative control, SID bounds, ACL bounds and
ACE geometry, deduplicates identical descriptors in deterministic tree order,
then assigns the dentry security IDs and serializes the aligned image security
table. `ImageMetadata.security.descriptor(id)` returns the original descriptor
as a borrowed view.

Nonzero `hard_link_id` values group two or more regular, non-reparse,
non-encrypted entries into one inode. Every alias must provide identical
attributes, timestamps, security descriptor, default data and named streams;
inconsistent or singleton groups are rejected. Lookup reference counts and XML
`TOTALBYTES` count every alias as required by WIM, while `HARDLINKBYTES` counts
only the duplicate inode bytes. This preserves both extraction progress
semantics and hard-link space reporting.

`encodeWimAlloc`, `encodeWimAppend`, and `encodeWimInto` produce a standard
single-part, single-image WIM using stored resources, XPRESS, LZX, or LZMS.
Compressed modes default to 32 KiB chunks; explicitly selected LZX
windows from 64 KiB through 2 MiB use the corresponding wimlib extension.
Chunks independently select compressed or raw representation, and the writer
emits the original cumulative chunk table.
The deterministic LZX reference encoder writes standard verbatim blocks with
3...8-byte explicit-offset matches and WIM's fixed-size E8 preprocessing. Its
current matcher retains one candidate per 3-byte hash; longer matches,
secondary lengths, aligned blocks, deeper chains, and ratio tuning remain
optimization work rather than wire-format gaps. LZMS uses the native adaptive
literal encoder and retains raw chunks when they are smaller; LZ and delta
matches remain ratio work. Image metadata and ordinary
file blobs use the selected codec, while the lookup table and UTF-16LE XML
remain uncompressed for Microsoft compatibility. A 10 MiB-chunk integrity
table covers the bytes from offset 208 through the lookup table. Output is
reproducible for the same entries/options: timestamps default to zero, a
content-derived GUID is used unless supplied, and all ordering is stable.
`encodeAppend` and `encodeInto` materialize into temporary owned storage first,
so invalid input, allocation failure, and `OutputTooSmall` leave caller output
unchanged.

`WimEncodeImage` plus `encodeWimImagesAlloc`, `encodeWimImagesAppend`, and
`encodeWimImagesInto` extend the same transactional contract to 1...65,535
ordered images. Each image owns its name, tree, root metadata/security and XML
timestamps. Ordinary stream blobs are deduplicated across all images and their
lookup reference count is accumulated globally; metadata resources remain one
per image and their lookup entries retain image-index order even when two images
have byte-identical metadata and SHA-1. XML emits consecutive `INDEX` values and
per-image counts. `WimEncodeImagesOptions.boot_index` optionally copies the
selected metadata resource into the header boot descriptor. Deterministic GUID
derivation includes every image metadata hash and length-delimited name.

`encodeWimSolidAlloc`/Append/Into and the corresponding `encodeWimImagesSolid*`
APIs produce version `0x0e00` packed WIM/ESD archives. Metadata remains in
ordinary independently addressable LZMS resources, while every deduplicated
nonempty file/ADS/reparse/EFSRPC stream is concatenated once into a deterministic
solid resource. Its alternate header records the true decoded size, chunk size
and LZMS format number; the lookup table writes image-ordered metadata entries,
a zero-hash resource marker, then logical-offset blob entries with accumulated
cross-image reference counts. Images with no nonempty streams omit the marker
rather than inventing a zero-length packed resource. Defaults match wimlib's
LZMS geometry: 128 KiB metadata chunks and 64 MiB solid chunks; both are
caller-selectable power-of-two sizes. Solid output supports boot metadata and
integrity, but is a standard seekable archive rather than SWM or pipable output.

`appendWimImageAlloc`/Append/Into add one borrowed `WimEncodeImage` to an
existing caller-supplied single-part seekable WIM. The operation is
transactional and returns a rewritten owned archive: all old physical bytes and
the GUID/header policy are retained, new resources are appended, and fresh
lookup/XML/integrity/header records become authoritative. New stream hashes are
matched against existing data entries only after bounded extraction and exact
byte comparison; successful reuse increments the old lookup refcount without
writing another blob. Ordinary WIMs append independent resources using their
existing codec and chunk geometry. Solid archives append a new packed resource
and bias its logical blob offsets by the decoded sizes of previous resources,
so WIMGAPI/wimlib's single logical solid run remains valid. Existing image XML
is preserved verbatim apart from inserting the consecutive new `IMAGE` element
and replacing top-level `TOTALBYTES`. Integrity presence is preserved by
default or may be explicitly overridden; `bootable` moves the boot descriptor
to the appended image. Lookup/XML/solid-chunk limits are explicit. Pipable and
split inputs are rejected before mutation.

`deleteWimImageAlloc`/Append/Into remove one image from the same supported
single-part seekable inputs while requiring at least one image to remain. The
selected metadata tree is recursively validated and every nonzero dentry main
or extra-stream hash is counted, so ordinary files, hard-link aliases, ADS,
reparse data and opaque EFSRPC streams decrement lookup references according to
their actual wire use. The metadata entry is removed; data entries whose
reference count reaches zero disappear from the rebuilt lookup while physical
bytes remain available for later compaction. Solid resource markers are kept
even when deletion makes a resource unreferenced, preserving the logical offset
bias of later packed resources. Remaining XML image elements are preserved and
higher indexes are shifted down. Deleting the boot image clears the descriptor;
a later boot index shifts down. Integrity presence is inherited or explicitly
overridden, and metadata/directory/path/lookup/XML limits bound hostile inputs.

`replaceWimImageAlloc`/Append/Into transactionally substitute one borrowed
`WimEncodeImage` at an existing index, including the only image in an archive.
The update reuses byte-verified existing blobs, decrements every stream
reference from the removed metadata tree, appends only newly required ordinary
or packed-solid data, and rebuilds metadata lookup order so all other image
indexes remain unchanged. The target XML element is replaced in place; all
other elements remain byte-equivalent and the new name may equal the old name
but not another nonempty image name. `bootable = null` preserves the target's
existing boot identity, `true` selects it, and `false` clears boot metadata only
when the target was bootable. Integrity is inherited unless overridden. As with
append/delete, prior physical resource and authority records remain until a
later compaction pass, and pipable, split, resource-only, metadata-only and
write-in-progress inputs are rejected.

`splitWimAlloc` converts any supported standalone, non-solid standard WIM into
caller-owned SWM parts. `encodeWimSplitAlloc` and
`encodeWimImagesSplitAlloc` compose this with the one- or multi-image writers.
`WimEncodedSplitArchive.deinit()` releases the part array and every part buffer.
The selected `max_part_size` is a soft blob-payload target, matching
`wimlib_split()`: header, lookup, XML, and integrity overhead are excluded, all
metadata remains in part 1, and an indivisible resource may make a part larger
than the target instead of being wire-spanned. Each part receives its own local
lookup and recomputed integrity table plus a copy of the XML. Multi-part sets
set the SPANNED header flag, share the deterministic GUID and image geometry,
and clear boot metadata/index as required by SWM. A one-part result remains a
normal WIM and retains the source boot descriptor.

`toPipableWimAlloc`/Append/Into convert a supported standard WIM to wimlib's
seekable and sequential `WLPWM` layout. Direct one- and multi-image composition
is available through `encodeWimPipable*` and `encodeWimImagesPipable*`. The
writer emits the zero-resource leading header, leading XML blob, image-ordered
metadata blobs, data blobs, pipable lookup and final XML blobs, optional raw
integrity table, and complete trailing header with no gaps. Every blob has the
40-byte hash/size/flags prefix; compressed resources move their cumulative
table to the tail, add a 4-byte size before every chunk, and retain table offsets
that exclude those size fields. Stored and raw-fallback chunks use the same
ordering contract.

`WimPipableEncodeOptions.integrity` defaults to false. This is the true
nonseekable-friendly form: after the final XML blob, the incremental reader sees
the trailing header directly. Explicit integrity is supported for seekable and
wimlib verification, but the raw table between final XML and trailing header is
not consumed by `WimPipableStreamPathExtractor`. Pipable WIM remains a wimlib
extension and intentionally uses non-Microsoft magic.

`encodeWimPipableSplitAlloc` and `encodeWimImagesPipableSplitAlloc` compose
the standard SWM planner with per-part pipable conversion. Metadata remains in
part 1, each part retains its local lookup and XML copies, and all leading and
trailing headers preserve the shared part geometry with boot index zero. Parts
are individually seekable WIMs; concatenating their bytes in part-number order
creates the exact stream consumed by `WimPipableStreamPathExtractor`, including
cross-part target blobs. The returned `WimEncodedSplitArchive` owns every part
as with the standard split API.

The current writer remains whole-archive and caller-buffer based. Physical
compaction, wire-spanned individual resources, automatic
host-filesystem security capture, short names, and tagged metadata remain
follow-up slices. Filesystem capture/application and construction of EFSRPC or
reparse payloads from OS objects stay outside the wire serializer.

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

const ads = [_]vort.WimEncodeNamedStream{.{
    .name = "Zone.Identifier",
    .data = zone_identifier,
}};
const security_descriptor = windows_self_relative_descriptor;
const input = [_]vort.WimEncodeEntry{
    .{
        .path = "Windows/System32/example.dll",
        .data = dll_bytes,
        .named_streams = &ads,
        .security_descriptor = security_descriptor,
        .hard_link_id = 42,
    },
    .{
        .path = "Windows/System32/example-alias.dll",
        .data = dll_bytes,
        .named_streams = &ads,
        .security_descriptor = security_descriptor,
        .hard_link_id = 42,
    },
    .{
        .path = "link",
        .reparse = .{ .tag = reparse_tag, .data = reparse_payload },
    },
    .{ .path = "secret.dat", .encrypted_raw = efsrpc_raw_bytes },
    .{ .path = "empty.txt" },
};
const encoded_wim = try vort.encodeWimAlloc(allocator, &input, .{
    .compression = .lzx,
    .image_name = "Deterministic image",
    .root_security_descriptor = security_descriptor,
});
defer allocator.free(encoded_wim);

const images = [_]vort.WimEncodeImage{
    .{ .name = "workstation", .entries = workstation_entries },
    .{ .name = "server", .entries = server_entries },
};
const multi_wim = try vort.encodeWimImagesAlloc(allocator, &images, .{
    .compression = .xpress,
    .boot_index = 1,
});
defer allocator.free(multi_wim);

const solid_esd = try vort.encodeWimImagesSolidAlloc(allocator, &images, .{
    .boot_index = 1,
});
defer allocator.free(solid_esd);

const appended = try vort.appendWimImageAlloc(
    allocator,
    existing_wim,
    .{ .name = "new-image", .entries = new_entries },
    .{ .bootable = true },
);
defer allocator.free(appended);

const deleted = try vort.deleteWimImageAlloc(
    allocator,
    appended,
    1,
    .{},
);
defer allocator.free(deleted);

const replaced = try vort.replaceWimImageAlloc(
    allocator,
    existing_wim,
    2,
    .{ .name = "replacement", .entries = replacement_entries },
    .{ .bootable = null },
);
defer allocator.free(replaced);

var swm = try vort.encodeWimImagesSplitAlloc(
    allocator,
    &images,
    .{ .compression = .xpress },
    .{ .max_part_size = 4 * 1024 * 1024 * 1024 },
);
defer swm.deinit();

const pipable_wim = try vort.encodeWimImagesPipableAlloc(
    allocator,
    &images,
    .{ .compression = .xpress, .boot_index = 1 },
    .{},
);
defer allocator.free(pipable_wim);
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
zig build run -- inspect-wim-encrypted-esd encrypted.esd
zig build run -- decrypt-wim-encrypted-esd encrypted.esd release-private.blob decrypted.esd 8589934592
zig build run -- decrypt-wim-encrypted-esd-key encrypted.esd AES256_KEY_HEX decrypted.esd 8589934592
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

EFS certificate/private-key decryption and filesystem application of
EFSRPC/reparse/alternate-stream semantics remain follow-up work. The library
exposes and verifies raw content without invoking Windows filesystem mutation
implicitly.

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
stream. A separate deterministic encrypted-ESD fixture pins CryptoAPI RSA-OAEP
key unwrapping, direct AES equivalence, range decryption, XML/header/integrity
reconstruction, wrong-key and limit failures. wimlib rejects the encrypted
input and verifies the Vort-decrypted output (`encrypted_esd=5`).
It also generates stored, multichunk XPRESS, LZX, and LZMS images through Vort's public
writer, reopens and extracts every path through Vort, then requires wimlib to
verify and byte-exactly extract all four archives (`writer=4`,
`writer_wimlib=4`).
Separate stored, XPRESS, LZX, and LZMS stream images cover default and Unicode/empty named
streams, directory ADS, single and dual unnamed reparse layouts, file and
directory EFSRPC raw streams, and a relative symbolic-link buffer. Vort extracts
each selector byte-exactly; wimlib verifies every image, labels all three stream
kinds, and restores the Vort-written link (`writer_stream=4`,
`writer_stream_wimlib=4`).
The per-codec inode writer images cover descriptor validation/deduplication,
root and per-entry security IDs, hard-link lookup reference counts and XML
accounting. wimlib reports the exact descriptor bytes and two-link group, then
extracts both aliases to the same inode (`writer_inode=4`,
`writer_inode_wimlib=4`).
The multi-image writer gate generates four-image stored, XPRESS, LZX, and LZMS archives,
including a cross-image shared blob, distinct trees, two byte-identical empty
metadata resources, consecutive XML indexes and boot image 2. Both readers map
all four images correctly; wimlib verifies the archives and byte-compares the
first two extracted trees (`writer_multi=4`, `writer_multi_wimlib=4`).
The solid writer gate packs repeated, high-entropy and cross-image shared blobs
into one four-chunk LZMS resource behind two independently compressed metadata
resources. Vort validates the marker/logical offsets and extracts every path;
wimlib verifies the archive and byte-compares both images
(`writer_solid=1`, `writer_solid_wimlib=1`).
Separate ordinary-XPRESS and solid-LZMS append gates retain the first image,
reuse a shared blob with an incremented reference count, add the second image,
and move the boot index. Vort extracts all old/new paths and wimlib independently
verifies and byte-compares both updated archives (`writer_append=1`,
`writer_append_wimlib=1`, `writer_solid_append=1`,
`writer_solid_append_wimlib=1`). A checked-in wimlib-authored XPRESS archive is
also updated directly, then reverified by wimlib
(`writer_reference_append=1`, `writer_reference_append_wimlib=1`).
Ordinary and two-resource solid deletion gates remove the middle/boot image,
decrement shared stream references, shift the later image and reject the deleted
paths. A wimlib-authored first image is also removed after append. Vort and
wimlib verify and byte-compare every survivor (`writer_delete=1`,
`writer_delete_wimlib=1`, `writer_solid_delete=1`,
`writer_solid_delete_wimlib=1`, `writer_reference_delete=1`,
`writer_reference_delete_wimlib=1`).
Ordinary-XPRESS and solid-LZMS replacement gates keep the first and third image
indexes stable, replace the middle boot image, reuse a shared blob, remove the
old unique blob from lookup and retain solid-resource routing. The same API
replaces the sole image in the checked-in wimlib-authored XPRESS archive. Vort
and wimlib verify and byte-compare every replacement
(`writer_replace=1`, `writer_replace_wimlib=1`,
`writer_solid_replace=1`, `writer_solid_replace_wimlib=1`,
`writer_reference_replace=1`, `writer_reference_replace_wimlib=1`).
The SWM writer matrix then emits multi-image stored, XPRESS, LZX, and LZMS sets with three
indivisible 70,000-byte blobs and a cross-image shared resource. Vort validates
every local lookup and extracts all paths through `WimArchiveSet`; wimlib joins
the parts with `--check`, verifies the result, and byte-compares both images
(`writer_split=4`, `writer_split_wimlib=4`).
Finally, stored, XPRESS, LZX, and LZMS multi-image pipable archives cover large compressed
data, 70,000-byte raw-fallback data, empty files, boot image 2, seekable path
reads, and 7-byte-input/11-byte-output progressive extraction. wimlib verifies
and extracts both images byte-exactly (`writer_pipable=4`,
`writer_pipable_wimlib=4`). Separate seekable stored/XPRESS/LZX/LZMS variants enable
integrity and pass Vort extraction plus wimlib verification
(`writer_pipable_integrity=4`, `writer_pipable_integrity_wimlib=4`).
Stored, XPRESS, LZX, and LZMS pipable SWM sets are also tested independently: Vort performs
seekable `WimArchiveSet` routing and 13-byte-input/17-byte-output extraction
from directly concatenated parts, while wimlib joins with `--check`, verifies,
and extracts the later image (`writer_pipable_split=4`,
`writer_pipable_split_wimlib=4`).
