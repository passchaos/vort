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
`compression_extent_size` selects power-of-two decoded groups from 4 KiB
through 1 MiB. The 4 KiB default preserves the earlier wire. Larger groups
use one compressed HEAD, standard NONHEAD lookback/lookahead distances, and
an explicit CBLKCNT marker when the group spans multiple logical clusters.
Compressed payloads occupy their actual rounded physical size; groups that
cannot reduce bytes fall back to one PLAIN block per logical cluster. LZ4
adds its standard configuration record and algorithm bitmap; Zstandard uses
a 32 KiB window matching the advertised configuration. Large Deflate groups
perform complete-input matching before storage selection, including when a
random prefix would otherwise trigger the ordinary sampled storage shortcut.
Payload plans are allocator-owned and retained until the image is emitted,
so this one-shot writer uses memory proportional to the planned image.
Stored/chunk modes require the default extent size.

`max_pcluster_size` optionally caps physical bytes per cluster. It accepts
4 KiB multiples from 4 KiB through 1 MiB, independently of the maximum decoded
extent size. With this option, intermediate input progress remains 4 KiB
aligned, while a fully encoded final tail may be partial. LZ4 uses bounded
block encoding and retries an aligned prefix; MicroLZMA uses aligned range
checkpoints. Deflate and Zstandard currently use a portable reference path
that checks complete aligned candidates in descending order, so it does not
assume monotonic compressed size. This reference search can perform many
encodings as decoded extent size increases; native capacity encoders remain
later work. A prefix that does not compress within the cap becomes one PLAIN
logical block, after which planning resumes at the next block. LZ4 advertises
the effective bounded physical limit in its standard configuration record.
Stored/chunk modes reject this option. Omitting it retains fixed groups.

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
full-index codec. With larger groups, all non-metabox physical addresses are
assigned first, visible metabox metadata is populated, and the metadata inode
is compressed last; its actual physical size never changes earlier addresses.
The extended 144-byte superblock carries `metabox_nid` and enables 48-bit
addressing for the high-bit root NID. Physical file and large-directory blocks
remain in the primary image unless directory compression is selected. Metabox
output currently rejects chunk mode, regular-file tail fragments, and
compressed-inline pclusters explicitly instead of combining unimplemented
layouts.

Writer entries use safe relative paths. Missing parent directories are created
automatically, while absolute paths, empty components, `.`/`..`, NUL bytes,
duplicate entries, and non-directory parents are rejected. Entry data and
symlink targets remain caller-owned for the duration of encoding.
Regular-file entries may supply `source: ?ByteSource` instead of `data`.
The source borrows a callback/context and stable u64 length; a source entry
must have empty `data`, be a regular file, and use a nonzero maximum read
size. Metadata and inode version planning use declared length, while physical
blocks, decoded compression groups, chunk deduplication, and tail packing read
only the required windows. Short callback reads are completed, zero before
declared EOF reports `TruncatedFrame`, and callback failures/invalid counts
report `SourceReadFailed`. A source length that cannot fit host accounting
reports `IntegerOverflow` before reading.

`ByteSource`, `SliceByteSource`, and `FileByteSource` are reusable public input
adapters. Individual requests default to at most 64 KiB and are configurable
through `max_read_size`; the file adapter borrows both the file and `std.Io`,
uses positional reads, and leaves closing to the caller. Source bytes and
length must remain stable throughout encoding. Source input avoids loading
all regular files into memory, but `encodeErofsAlloc` still retains encoded
payload plans and allocates the complete output image. Compressed source
scratch is at most the decoded extent size; chunk input scratch is bounded by
the selected chunk size.

```zig
const file = try std.Io.Dir.cwd().openFile(io, "payload.bin", .{});
defer file.close(io);
var input = try vort.FileByteSource.init(io, file);
const image = try vort.encodeErofsAlloc(allocator, &.{.{
    .path = "data/payload", .source = input.source(),
}}, .{ .compression = .zstandard, .compression_extent_size = 64 * 1024 });
defer allocator.free(image);
```

`encodeErofsToSink(allocator, entries, options, sink, limits)` emits physical
data directly to a borrowed random-access `ByteSink`, then writes finalized
metadata and sets the image length. It retains metadata, directory/packed-tail
plans, indexes and codec scratch, without allocating the complete image or
caching all encoded extents. `encodeErofsExternalChunksToSinks` accepts
separate image and device sinks. Chunk deduplication keeps stable source
locations, rereads candidates with two 4 KiB comparison buffers, and rereads
unique chunks during emission. This preserves padded deduplication and holes
without retaining unique payloads; its reference search may be quadratic in
the number of unique chunks.

`ErofsSinkLimits.max_working_memory` defaults to 64 MiB and bounds live
requested bytes in library allocations. A denied budget reports
`WorkingMemoryLimitExceeded`; backing allocator failures remain `OutOfMemory`.
`ErofsSinkResult` returns u64 `image_size`/`device_size` and
`peak_working_bytes`. The budget includes metadata, plans, indexes and codec
allocations; those still grow with entry/block counts. It excludes caller
entry/source storage, the sink's own allocations, stack scratch and backing
allocator bookkeeping or remap transients, so it is not an RSS limit.

`ByteSink` completes short writes and caps individual callbacks through
`max_write_size` (64 KiB default). Zero/excessive counts, failed writes and
failed final-length changes report `SinkWriteFailed`; address arithmetic
overflow reports `IntegerOverflow`. `FileByteSink` borrows a writable seekable
file/Io, uses positional writes and leaves closing to the caller.
`BufferByteSink` owns a growing buffer, fills gaps with zeros and transfers
ownership through `take()`; that output buffer is outside the working budget.
Caller sinks may contain partial output on failure. Final lengths are set
after successful data/metadata writes; external device length is set before
primary image length, with no atomic transaction across both sinks.

```zig
const output_file = try std.Io.Dir.cwd().createFile(io, "image.erofs", .{});
defer output_file.close(io);
var output = vort.FileByteSink.init(io, output_file);
const result = try vort.encodeErofsToSink(allocator, &.{.{
    .path = "data/payload", .source = input.source(),
}}, .{ .compression = .lz4 }, output.sink(), .{
    .max_working_memory = 8 * 1024 * 1024,
});
_ = result;
```

`create-erofs-file` uses file Source/Sink adapters and atomically replaces its
destination only after encoding succeeds, allowing input and output to name
the same file. Its final optional `working_memory_limit` argument follows
`max_pcluster_size`; successful output reports `peak_working_bytes`.

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
    .compression_extent_size = 64 * 1024,
    .max_pcluster_size = 4096,
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
All 108 Vort writer modes enable cost-aware shared-xattr planning for one
repeated long-prefix attribute across root, file, and directory ibodies. Vort
reconstructs each value, and the 87 non-metabox modes additionally require
`fsck.erofs --xattrs` restoration; the summary reports
`shared_xattr_writer=108`. Three reference and four Vort-authored LZ4/MicroLZMA/Deflate/
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

Thirty-two additional writer modes cover 64 KiB groups across all four
compression algorithms, ordinary/fragments/inline/48-bit/metabox/directory/
extended layouts, and combined directory + extended + metabox output.
A random 8 KiB prefix repeated twice additionally exercises multi-block
physical clusters in both ordinary files and the extraction matrix. All 68
writer modes pass fsck and exact extraction (`grouped_writer=32`,
`external_writer=68`, `directory_writer=12`, `extended_inode_writer=13`).
Focused tests additionally cover 1 MiB decoded extents, metadata larger than
two physical blocks, actual image-size reduction on repetitive data, and OOM.

The public writer facade remains `src/erofs/writer.zig`. Internal tree,
codec, cluster, chunk, fragment, inode, xattr, and metabox components live in
`src/erofs/writer/`; options and wire serialization have dedicated modules,
and writer regressions live in `writer/tests/`. The reader's full/compact
index parser remains a separate `compression_index.zig` module.

Forty bounded writer modes cover 4 KiB physical limits in all codecs and
existing layout combinations, plus 8/12 KiB limits in ordinary layouts.
erofs-utils independently validates and extracts every output, bringing the
matrix to 108 writers (`bounded_writer=40`, `external_writer=108`,
`xattr_writer=87`, `metabox_writer=21`, `directory_writer=20`,
`extended_inode_writer=21`). Unit tests read physical counts directly, cover
non-power-of-two limits, require exact round trips and deterministic output,
and exercise no-fit fallback, EOF/tail metadata, and exhaustive OOM.

The Source and Sink matrices each mirror every one of the 108 memory-backed
writer modes, requiring byte-identical images and external devices as well as
fsck/extraction compatibility (`writer=324`, `source_writer=108`,
`sink_writer=108`, `external_writer=324`). Thirteen additional CLI cases use
actual positional file Source/Sink adapters across
stored, default compressed, grouped, and physically bounded output
(`file_source_writer=13`); budget rejection preserves existing output and
removes temporary files, and same-path input/output retains input until
encoding succeeds. Unit tests additionally cover short reads, callback
errors, premature EOF, empty-source non-reading, declarations overflowing host
accounting, and allocation failures in grouped/metabox/chunk source paths.

Sink tests require byte identity across all codecs, grouped/physical limits,
inline/fragment tails, xattrs, directories, extended/48-bit inodes and metabox,
plus local/external chunk padding, deduplication and holes. Four-MiB stored
and all-unique chunk sources complete within 64 KiB of requested working heap;
LZ4 legacy/grouped sources complete within 1 MiB including encoder tables.
Source/write/final-length/device failures, empty devices and exhaustive OOM
are covered. Debug and ReleaseFast each pass 99 EROFS plus 12 independent I/O
tests (4 Source, 8 Sink/allocator), with explicit imports ensuring that file
adapters and allocator tests are actually analyzed by Zig.
erofs-utils 1.9.4-g5fcb2f76 passes all 324 writer modes, including 108 Sink
counterparts, with 261 xattr, 63 metabox, 60 directory, 63 extended-inode and
120 physically bounded writer cases.
The external matrix uses the Debug CLI. The final standard Debug repository
suite (`zig build test`) also passes, alongside check and wasm compilation.
