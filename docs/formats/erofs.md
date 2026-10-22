# EROFS

Vort provides a pure Zig EROFS reader and deterministic writer for the
filesystem format used by Android, embedded Linux, and container images.

The reader validates the superblock, CRC-32C checksum, block geometry,
incompatible feature bits, compact and extended inode layouts, directory entry
ordering, names, NIDs, and exact allocation limits. Flat plain and flat inline
files, directories, regular files, and symbolic links are supported. Bounded
xattr decoding covers inline entries, shared IDs relative to `xattr_block`,
empty values, standard full-name/user/POSIX-ACL/trusted/lustre/security name
indexes, and incompatible-feature long indexes backed by bounded plain prefix
tables. Reconstructed names and values are copied into one owned buffer; count
and aggregate-byte limits are checked before allocation.

Chunk-based regular files support per-inode chunk sizes, 4-byte local block
maps, 8-byte device indexes, merged chunks, partial final chunks, and all-ones
holes. `parseErofsWithDevices` borrows the primary image plus an ordered slice
of external device byte slices; no blob is copied or concatenated. Device-table
slots, unified address ranges, declared block counts, explicit IDs, and every
read boundary are validated. Metadata-only parsing and listing work without
devices, while extraction reports `ErofsMissingDevice` until the required blob
is supplied.

The 48-bit incompatible feature extends superblock block counts/root NIDs, flat
inode starts, chunk indexes, and device slots. Compressed full inodes additionally
support 4/8/16/32-byte extent records: compact records derive logical starts
from cluster bits and optionally carry one 64-bit physical base, while larger
records carry explicit 64-bit physical and logical starts. Raw and all four
EROFS compression formats share the same bounded decode path.

Metabox images expose an ordinary hidden compressed inode whose decoded file is
a second metadata address space. `loadMetaboxAllocLimited` first validates and
decodes that inode under caller output/scratch limits, then returns an owning
`ErofsLoadedMetaboxArchive`; its embedded borrowed Archive routes bit-63 NIDs,
inline directories, xattr ibodies, non-plain long-prefix tables, shared xattrs,
chunk indexes, and compressed indexes/extents to the decoded metadata while
physical payloads continue to use the primary/external devices. Base metadata
can still be inspected without loading, but high-bit inode access reports
`ErofsMissingMetabox`.

Compressed files support both legacy full indexes and modern compact indexes,
including four-byte and sixteen-entry/two-byte packs, HEAD/NONHEAD lookback,
EOF sentinels, and big pclusters. Explicit CBLKCNT sizes from the first
NONHEAD record govern physical reads, including the final EOF pcluster and
clusters preceding fragment tails. Missing, excessive, out-of-image, and zero
counts for primary-image extents are rejected; fragment/inline tails retain
their standard zero-physical-block markers. LZ4, raw Deflate, and Zstandard extents are
decoded, as are exact-size MicroLZMA extents with inverted property bytes,
8 MiB EROFS dictionary bounds, exact compressed-input consumption, and range
termination validation. MicroLZMA is handled as its own wire format rather than
being substituted with LZMA-Alone. Whole-file and partial-tail fragments are
resolved through the hidden packed inode, whether it is flat, compressed, or
interlaced. Compressed inline tail packing is decoded directly from inode
metadata. Packed-inode extraction scans indexes without retaining a whole head
table and materializes only intersecting extents; `ErofsReadLimits` separately
bounds caller output and hidden packed-extent scratch (8 MiB by default).

The writer emits 4 KiB filesystems with compact or extended inodes, CRC-32C-protected
superblocks, dot-omitted sorted directories, nested and empty directories,
symbolic links, flat plain/inline stored data, and legacy full compression
indexes. LZ4, MicroLZMA, raw Deflate, and Zstandard modes encode every non-empty
regular-file logical cluster into an independently addressable physical cluster.
Compressed payloads are right-aligned with `lz4_0padding`; a `PLAIN` index is
used whenever compression would not reduce the payload. MicroLZMA, Deflate,
and Zstandard images include their required superblock compression-configuration records.
Each entry and the root directory can carry deterministic inline xattrs; inode
planning accounts for their ibodies before flat-inline tails and aligned
compression headers. `xattr_prefixes` optionally writes a plain prefix table
and uses its caller-ordered first match without changing the default wire.
`shared_xattrs = true` counts exact repeated name/value pairs across the tree,
keeps only candidates whose shared entry plus 4-byte references reduce total
wire size, and emits the selected entries in a deterministic primary-image
shared region after primary inode metadata. Each inode retains at most the
standard 255 shared IDs and falls back to inline entries for the remainder. IDs
are relative to `xattr_block`, including when a large long-prefix table moves
the region beyond block zero; metabox inode ibodies also reference this primary
region. Leaving
the option disabled preserves the prior wire.
`tail_packing = .fragments` deterministically packs the last logical block of
each non-empty regular file: small files use the whole-fragment header, larger
files retain ordinary compressed/plain prefix clusters, and one hidden packed
inode is encoded through the selected LZ4/MicroLZMA/Deflate/Zstandard planner.
The hidden inode contributes to the inode count but never to directory entries. Identical
entries and options produce identical images. Alternatively,
`tail_packing = .compressed_inline` encodes the last logical block during
metadata planning, selects compressed bytes only when smaller, otherwise keeps
the raw tail, and writes `INLINE_PCLUSTER` only when header, full indexes, and
payload fit in one metadata block. A non-fitting tail automatically retains its
ordinary physical block.

`compress_directories = true` implements the standard `--zD` layout for LZ4,
MicroLZMA, raw Deflate, and Zstandard images. Directory streams smaller than
the 16-byte full-index header threshold retain the ordinary flat-inline wire. Every larger
directory is appended in path order to the hidden packed inode and its visible
inode carries the standard whole-fragment high-bit header with no local
clusters. Directory buffers are sized before metadata planning but copied into
the packed stream only after final high-bit/ordinary NIDs have populated the
dirents. The option can share one packed inode with regular-file fragments and
also works when visible inode metadata lives in a metabox; stored mode is
rejected explicitly.

`chunk_size` selects deterministic local chunk-based output in stored mode.
Chunks are padded to their declared power-of-two size, deduplicated across all
regular files, and all-zero chunks become holes. `encodeErofsExternalChunksAlloc`
uses the same plan but returns an owning `{ image, device }` pair with 8-byte
device indexes and a standard 128-byte device-table slot; even an all-hole plan
returns a valid zero-length device paired with its metadata image.
`force_48bit` emits the standard feature on stored, compressed, local-chunk,
and external-chunk output even while current in-memory image sizes keep actual
high halves zero; this provides interoperable forward-compatible wire without
claiming to allocate multi-terabyte buffers.

`metabox = true` emits the standard MZi layout. Visible inode slots, inline
directories and tails, xattr ibodies, and compression indexes are planned in a
separate block-padded metadata stream; directory entries and the superblock use
bit-63 NIDs. One low-NID hidden inode in the primary metadata owns that stream,
using stored blocks or the selected LZ4/MicroLZMA/raw-Deflate/Zstandard
full-index codec.
The extended 144-byte superblock carries `metabox_nid` and enables 48-bit
addressing for the high-bit root NID. Physical file and large-directory blocks
remain in the primary image unless directory compression is selected. Metabox
output currently rejects chunk mode, regular-file tail fragments, and
compressed-inline pclusters explicitly instead of combining unimplemented
layouts.

Writer entries use safe relative paths. Missing parent directories are created
automatically, while absolute paths, empty components, `.`/`..`, NUL bytes,
duplicate entries, and non-directory parents are rejected. Entry data and
symlink targets remain caller-owned for the duration of `encodeErofsAlloc`.
Entries additionally accept 32-bit UID/GID, a modification-time delta relative
to `WriterOptions.epoch`, and an optional per-inode nanosecond value.
`root_mode`, `root_uid`, `root_gid`, `root_modification_time`, and
`root_modification_nsec` provide the corresponding root metadata without a
synthetic entry.
`inode_version = .compact` preserves the original 32-byte default and rejects
fields it cannot represent without truncation. `.extended` emits standard
64-byte inodes for every visible and hidden node, with u64 size/absolute mtime,
u32 UID/GID/nlink/nanoseconds, and sixteen zeroed reserved bytes. `.automatic`
keeps compact inodes when size, IDs, time delta, common nanoseconds, and link
count fit, upgrading only individual lossy cases. Extended inodes retain
32-byte NID slot addressing and work with stored/compressed/chunk, packed
directory, shared-xattr, and metabox layouts.

```zig
const config_xattrs = [_]vort.ErofsXattr{
    .{ .name = "user.owner", .value = "vort" },
    .{ .name = "user.shared", .value = "common" },
};
const root_xattrs = [_]vort.ErofsXattr{
    .{ .name = "user.image", .value = "system" },
    .{ .name = "user.shared", .value = "common" },
};
const image = try vort.encodeErofsAlloc(allocator, &.{
    .{ .path = "etc/config", .data = "enabled=true\n", .xattrs = &config_xattrs },
    .{ .path = "var/empty", .kind = .directory },
    .{ .path = "config-link", .kind = .symlink, .target = "etc/config" },
}, .{
    .compression = .zstandard,
    .root_xattrs = &root_xattrs,
    .xattr_prefixes = &.{"user."},
    .shared_xattrs = true,
    .inode_version = .automatic,
    .tail_packing = .fragments,
});
defer allocator.free(image);

const archive = try vort.parseErofs(image);
const inode = try archive.lookup(allocator, "etc/config", 1024, 1024 * 1024);
var attributes = try archive.readXattrsAllocLimited(allocator, inode, 32, 64 * 1024);
defer attributes.deinit();
const owner = attributes.find("user.owner").?.value;

const payload = try archive.extractByPathAllocWithLimits(
    allocator,
    "etc/config",
    .{ .max_output_len = 1024, .max_packed_extent_len = 2 * 1024 * 1024 },
    1024 * 1024,
);
defer allocator.free(payload);

const external = try vort.parseErofsWithDevices(metadata_image, &.{blob_bytes});

var loaded_metabox = try external.loadMetaboxAllocLimited(
    allocator,
    64 * 1024 * 1024,
    vort.erofsDefaultPackedExtentLimit,
);
defer loaded_metabox.deinit();

const mzi_image = try vort.encodeErofsAlloc(
    allocator,
    entries,
    .{ .compression = .zstandard, .metabox = true },
);
defer allocator.free(mzi_image);

var encoded_chunks = try vort.encodeErofsExternalChunksAlloc(
    allocator,
    entries,
    .{ .chunk_size = 4096 },
);
defer encoded_chunks.deinit(allocator);
```

Prefix tables stored inside packed fragment inodes remain unsupported; plain and
metabox prefix tables are supported. Compressed 48-bit `PARTIAL_REF` and
fragment-extent combinations remain explicitly unsupported. The writer does
not yet expose MZ=id directory-data placement. Chunk output requires stored
mode; fragment and compressed-inline output require a non-stored compression
mode because visible files use the compressed inode layout even when a prefix
or inline cluster falls back to `PLAIN`.

```sh
zig build run -- list-erofs-file system.erofs
zig build run -- create-erofs-file output.erofs path/in/image input.bin zstd
zig build run -- extract-erofs-file system.erofs etc/config output.conf 67108864 [device...]
zig build run -- list-erofs-xattrs system.erofs etc/config
zig build run-erofs-diff
```

CI builds a pinned `erofs-utils` reference and generates plain, compact/full
LZ4, MicroLZMA, Deflate, and Zstandard images when the reference has a recent
XZ Utils. `fsck.erofs` validates and extracts those images before Vort performs
independent listing and byte-for-byte extraction.
The same gate generates Vort stored, LZ4, raw Deflate, and Zstandard images
twice to prove determinism, self-decodes their nested tree, and has `fsck.erofs`
extract their regular files, incompressible `PLAIN` fallbacks, symlink, and empty
directory. Real `user.*` attributes include repeated values that erofs-utils
promotes to shared entries; an additional reference image combines shared
values with a long prefix table. Vort reads those images, while
`fsck.erofs --xattrs` restores long-prefix Vort-authored root, file, and
directory attributes. Additional LZ4/Deflate/Zstandard fragment images cover
whole and partial references plus flat/compressed/interlaced packed inodes;
LZ4/Deflate/Zstandard images cover compressed inline tail packing. Seven Vort
writer modes include all three fragment writers and are independently
extracted by `fsck.erofs`; three more writer modes cover compressed inline
tails and raw/fallback decisions.
Three more reference images cover local block maps, forced local indexes, and
an external blob/device table; Vort extracts each byte-exactly and diagnoses a
missing blob explicitly. Vort-authored local and external chunk layouts are
also extracted by `fsck.erofs`, with the external metadata/blob pair kept as
separate outputs.
Five deterministic MZi writers cover stored, LZ4, MicroLZMA, raw Deflate, and
Zstandard hidden metadata streams. Vort loads and byte-exactly extracts every
mode, while `fsck.erofs` validates all images and independently extracts their
physical/compressed extents. erofs-utils 1.9.4 itself writes zero-filled output
for flat-inline regular files whose inode lives in a metabox (its `dump --cat`
path reads the same bytes correctly), so the stored-MZi oracle check excludes
only those affected inline tails.
All 36 Vort writer modes enable cost-aware shared-xattr planning for one
repeated long-prefix attribute across root, file, and directory ibodies. Vort
reconstructs each value, and the 31 non-metabox modes additionally require
`fsck.erofs --xattrs` restoration; the summary reports
`shared_xattr_writer=36`. Three reference and four Vort-authored LZ4/MicroLZMA/Deflate/
Zstandard directory-compression images require byte-exact listing/extraction
through whole-directory fragments (`directory_reader=3`,
`directory_writer=4`). Four forced-extended reference images and five
Vort-authored stored/LZ4/MicroLZMA/Deflate/Zstandard images exercise 64-byte inode
parsing/writing (`extended_inode_reader=4`, `extended_inode_writer=5`).

MicroLZMA writing uses algorithm ID 1, the standard 14-byte configuration
payload (16 bytes including length), a 32 KiB dictionary, complemented
properties, and no end marker. Its clusters share ordinary compressed/plain
selection, zero-padding, tail fragments, compressed inline tails, 48-bit
feature output, extended inodes, directory fragments, and metabox planning.
Seven writer modes pass erofs-utils 1.9.4-g5fcb2f76 checks and byte-exact
extraction (`lzma_writer=7`). The shared MicroLZMA codec also exposes capacity-
limited prefix encoding with consumed/written accounting. Integrating that
surface into larger EROFS physical clusters remains future writer work.
