# EROFS

Vort provides a pure Zig EROFS reader and deterministic writer for the
filesystem format used by Android, embedded Linux, and container images.

`ErofsSourceArchive.init(allocator, source, limits)` opens a borrowed stable
`ByteSource`; `initWithDevices` additionally borrows an ordered Source array.
It initially validates bounded superblock/checksum metadata, device tables and
prefix tables in the primary image, parses inodes on demand, and can own a
bounded decoded metabox. `deinit()` releases
that metadata and leaves source handles and contexts with the caller. All
source bytes, lengths and contexts, including the device array, must remain
stable and valid throughout the archive's lifetime. Reads are bounded to the
image length declared by the superblock. Image/device lengths and physical
read offsets use u64; file sizes and metadata positions use checked host
`usize` accounting.

Source archives support inode/device access, lookup, directory and xattr
reading, `readToSink`, `readRangeToSink`, and `extractByPathToSink`. Flat and
chunk data copy directly through a 64 KiB stack buffer, including zero-filled
holes and explicit/unified external addresses. Full/compact and modern extent
indexes decode one overlapping extent at a time, then release its encoded and
decoded working buffers. Inline/interlaced/whole and partial packed tails,
compressed directories, 48-bit/extended inodes and metabox use the same input
and decoding paths. Allocating convenience methods call the Sink core.

`ErofsSourceLimits` defaults to 64 MiB of live requested working heap, a
64 MiB metabox cap, and separate 8 MiB encoded/decoded extent caps. Metabox is
loaded by default; `load_metabox = false` allows header inspection before an
explicit `loadMetabox()` call. A retained metabox and decoder scratch together
must fit the working budget, even when the independent metabox size cap fits.
`ErofsReadLimits.max_output_len` bounds the requested extraction/range, and
`max_packed_extent_len` additionally bounds decoded packed extents.

The working budget includes retained metabox bytes, encoded/decoded extents,
xattr scanning scratch, temporary packed prefix tables and active directory
block buffers. It excludes stack,
backing allocator bookkeeping/remap transients and caller-owned Source/Sink
storage or returned file/directory/xattr buffers. `ErofsSourceReadResult`
returns `decoded_size` and the archive lifetime's monotonic
`peak_working_bytes`; `peakWorkingBytes()` exposes the same counter. Budget
denial reports `WorkingMemoryLimitExceeded`, while backing/output allocator
failure remains `OutOfMemory`. This accounting is not an RSS limit.

Source/Sink callback errors preserve their public error classes. Extraction
sets final Sink length only after successful data emission; failures can leave
partial caller output. File, directory and xattr convenience results own their
buffers independently of the Source archive.

`initDirectoryIterator(inode, max_directory_size)` returns a caller-owned
`ErofsDirectoryIterator`. It retains one directory block and the current
decoded extent, then returns one `DirectoryEntry` per `next()` call. Names
borrow iterator storage until the next call or `deinit()`; NIDs and file types
are values. The byte cap is checked against the directory's declared size
before reading. Directories can span many blocks without a complete directory
allocation or an array of all entries.

The same block parser serves streamed and allocating directory APIs. A fixed
255-byte key preserves strictly increasing name order across reused blocks,
and reserved dot entries are omitted. Lookup scans to validated EOF even after
finding a candidate, retaining only its NID; corrupt later names, Source errors
and unfinished compressed metadata therefore remain errors. `diagnostics()`
returns decoded directory `bytes_read`, `entries_yielded` and logical
`entry_offset`, including the record at a parser failure. Errors remain sticky.

Source directory block buffers and decoder caches count against the archive's
working budget. Always release the iterator before deinitializing or moving
the archive. Multiple active directory/extraction states share that budget.
CLI listing uses this iterator recursively and accepts
`--working-memory-limit=bytes` and `--max-directory-bytes=bytes`.

```zig
var directory = try archive.initDirectoryIterator(try archive.rootInode(),
    64 * 1024 * 1024);
defer directory.deinit();
while (try directory.next()) |entry| {
    try consumeEntry(entry.nid, entry.name, entry.file_type);
}
```

Borrowed slice `ErofsArchive` uses the same extraction, range, directory and
xattr core. Its `initExtractor`, `initRangeExtractor`, `initPathExtractor`,
`initDirectoryIterator`, `readToSink` and `readRangeToSink` receive an explicit
allocator first. `ErofsSliceExtractor` and `ErofsSliceDirectoryIterator` own
working buffers while borrowing archive/image/metabox storage. Slice paths
borrow encoded extents, ibodies and shared attributes directly; Source paths
retain bounded read buffers. Allocating output APIs retain their caller-owned
results, and slice methods retain the supplied allocator's policy rather than
introducing a separate implicit working budget.

`initExtractor(inode, limits)`, `initRangeExtractor(inode, start, size, limits)`
and `initPathExtractor(path, limits, max_directory_size)` create a caller-owned
`ErofsExtractor`. `read(output)` returns `ErofsExtractProgress` with
`output_written`, range-relative `position`, and `need_output`/`done` status.
Successful reads initialize only the returned output prefix. Before all range
bytes have been delivered, an empty output slice returns zero progress and
does not read Sources or allocate decode buffers.

The extractor retains one current logical segment and at most one decoded
extent, reusing it across arbitrarily small output slices. That cache counts
against the archive's working budget and is released at the segment boundary,
on failure or on extractor deinitialization. Source/Sink convenience methods
and allocating methods use the same resumable reader. Flat/chunk, legacy full,
compact, modern extent, inline/interlaced and packed child ranges all keep
explicit iterator state rather than restarting metadata scans on each read.

Read errors leave the current caller output unchanged and remain sticky;
`position()` still counts bytes returned by earlier successful reads. After
the last data bytes, a further read completes remaining metadata validation
before reporting `done`. That read may fail even though the requested range
has already been delivered. Sink adapters commit final length only after
`done`. Completed reads return zero bytes on subsequent calls.

Always call extractor `deinit()`, including after `done` or error. The archive,
Source contexts and device array must remain valid at stable addresses until
all extractors have been released. Multiple extractors share the archive's
working budget; the archive cannot be deinitialized while one is active.

```zig
var extractor = try archive.initPathExtractor("data/payload", .{
    .max_output_len = 512 * 1024 * 1024,
}, 64 * 1024 * 1024);
defer extractor.deinit();
var buffer: [4096]u8 = undefined;
while (true) {
    const progress = try extractor.read(&buffer);
    try consume(buffer[0..progress.output_written]);
    if (progress.status == .done) break;
}
```

```zig
const image_file = try std.Io.Dir.cwd().openFile(io, "image.erofs", .{});
defer image_file.close(io);
var input = try vort.FileByteSource.init(io, image_file);
var archive = try vort.ErofsSourceArchive.init(allocator, input.source(), .{
    .max_working_memory = 8 * 1024 * 1024,
});
defer archive.deinit();
const output_file = try std.Io.Dir.cwd().createFile(io, "payload.bin", .{});
defer output_file.close(io);
var output = vort.FileByteSink.init(io, output_file);
const result = try archive.extractByPathToSink("data/payload", output.sink(), .{
    .max_output_len = 512 * 1024 * 1024,
}, 64 * 1024 * 1024);
_ = result;
```

Long xattr prefix tables use the format's address priority: the plain flag
selects the primary image; otherwise a metabox takes priority over a packed
inode, with the primary image as fallback when neither is present. Plain and
loaded-metabox tables borrow their storage. Packed tables read only the
declared records through the shared streaming core, retain at most
`xattr_prefix_count * 260` bytes (32.5 KiB for 128 prefixes), and release the
current decoded extent before scanning xattrs. The last record can end at
packed EOF without trailing alignment bytes. Exact-range metadata validation
rejects malformed later extent records without decoding unrelated packed data.

Both archive types expose `readXattrsAllocWithLimits(allocator, inode,
ErofsXattrReadLimits)`. The options independently bound `max_count`,
`max_total_bytes` and `max_packed_extent_len`; the last defaults to 8 MiB and
bounds a decoded packed extent rather than the entire packed file. Source
encoded/decoded caps and its working heap budget apply in addition. The
existing `readXattrsAllocLimited` selects that default. Table, decoder and
scanner buffers use the working allocator; returned attributes use the
caller's output allocator and remain independently owned.

CLI list, xattr and extraction commands use actual file Sources, including
external devices. Input images and devices have no whole-file 512 MiB loading
cap; extraction retains its explicit output cap. Extraction uses an atomic
file Sink, preserves existing output on budget or late decoding failure, and
supports same-path input/output. Its final optional
`--working-memory-limit=bytes` follows the output limit/device arguments.
Creation uses automatic inode version selection for larger input files.
CLI extraction uses the public extractor and accepts
`--output-chunk-size=bytes` (1 byte...1 MiB, 64 KiB default) to select its
caller-owned output buffer. This buffer is outside the archive working budget.

The reader validates the superblock, CRC-32C checksum, block geometry,
incompatible feature bits, compact and extended inode layouts, directory entry
ordering, names, NIDs, and exact allocation limits. Flat plain and flat inline
files, directories, regular files, and symbolic links are supported. Bounded
xattr decoding covers inline entries, shared IDs relative to `xattr_block`,
empty values, standard full-name/user/POSIX-ACL/trusted/lustre/security name
indexes, and incompatible-feature long indexes backed by bounded
plain/metabox/packed prefix tables. Reconstructed names and values are copied
into one owned buffer; count
and aggregate-byte limits are checked before allocation.

Chunk-based regular files support per-inode chunk sizes, 4-byte local block
maps, 8-byte device indexes, merged chunks, partial final chunks, and all-ones
holes. `parseErofsWithDevices` borrows the primary image plus an ordered slice
of external device byte slices; no blob is copied or concatenated. Device-table
slots, unified address ranges, declared block counts, explicit IDs, and every
read boundary are validated. Metadata-only parsing and listing work without
devices, while extraction reports `ErofsMissingDevice` until the required blob
is supplied.

The same device resolver serves flat data, legacy full/compact compression,
modern extent records, packed fragments/directories and metabox loading. Byte
addresses retain the intra-block offset; the complete encoded or raw region,
including the skipped first-block bytes, must fit the selected device. An
unaligned 4 KiB encoded region can therefore require two device blocks.
Sources keep u64 physical offsets without loading a complete blob. Returned
slice regions borrow the selected device bytes.

Physical addresses are resolved after logical range cropping. Unrequested
device extents and holes do not require a supplied device, while remaining
metadata ordering and format validation still completes before `done`.
Metadata/inline payloads use their original primary or metabox address space
and are not remapped as data addresses. A zero unified address denotes an
explicit-ID-only slot; it does not shadow primary block zero. Mapped device
ranges retain checked ordering, overlap and byte-length validation.

`list-erofs-file` and `list-erofs-xattrs` accept ordered device filenames,
matching extraction. Xattr listing also accepts `--working-memory-limit=bytes`.
All three CLI readers share file adapter ownership, prepare stable Source
arrays before opening the archive, and release states before closing devices.

The 48-bit incompatible feature extends superblock block counts/root NIDs, flat
inode starts, chunk indexes, and device slots. Compressed full inodes additionally
support 4/8/16/32-byte extent records: compact records derive logical starts
from cluster bits and optionally carry one 64-bit physical base, while larger
records carry explicit 64-bit physical and logical starts. Raw and all four
EROFS compression formats share the same bounded decode path.

Full/compact compression headers retain both algorithm nibbles as independent
wire IDs. `HEAD1` selects the low nibble and `HEAD2` selects the high nibble;
ID zero means LZ4 in either slot, including when the first algorithm is
MicroLZMA, Deflate or Zstandard. The high nibble is never interpreted as an
inheritance marker. Inline compressed tails and legacy partial-reference heads
use the same selection, with metadata/metabox and external-device addresses
remaining independent of the codec choice. Unknown IDs report
`UnsupportedErofsCompression`.

Archive initialization validates the compression algorithm bitmap and its
records in primary metadata. Records occur in algorithm-ID order after the
complete superblock, start at a four-byte boundary and carry a u16 payload
length. LZ4/MicroLZMA payloads require at least 14 bytes; Deflate/Zstandard
require at least six. Unknown bitmap bits and unsupported codec formats return
`UnsupportedErofsCompression`; invalid lengths or field ranges return
`InvalidErofs`, and truncated payloads return `TruncatedFrame`. Reserved bytes
and extensions are accepted; all extension bytes are scanned through a fixed
256-byte buffer, so Source failures and image bounds remain observable without
record-sized allocation. Header-only `parseErofsSuperblock` remains a header
parser; opening an Archive performs the separate configuration validation.

Only an algorithm actually used by a compressed extent must be declared;
unused HEAD1/HEAD2 slots and metadata-only inode inspection do not trigger that
check. An undeclared selected algorithm returns `InvalidErofs` before decoder
allocation or compressed payload reads. Source, slice, packed, metabox,
inline-tail and partial-reference paths use the same retained configuration.
Old images without the configuration feature interpret the superblock field
as the legacy LZ4 distance and retain the single-physical-block default.

The declared LZ4 distance and maximum pcluster block count constrain its
decoding; a zero block count selects one block. MicroLZMA uses the declared
4 KiB...8 MiB dictionary, Deflate limits match distances to the declared
8...15-bit window, and Zstandard rejects a frame window above its declared
1 KiB...1 MiB cap. Decoder state and returned output retain their existing
allocator policies. Configuration parsing itself allocates no memory and
therefore works under a zero archive working budget. Caller extent/output
limits continue to apply independently.

Modern extent records support `PARTIAL_REF` (encoded-length bit 27), and
legacy full-index heads support their bit-15 partial-reference flag. LZ4,
MicroLZMA, raw Deflate and Zstandard decode only the needed prefix of a marked
extent; range cropping includes the skipped prefix needed for match history.
Unmarked extents retain complete decoding and validation. Input extent bounds
and encoded-size caps still apply to the complete encoded region; decoded-size
caps apply to the prefix actually decoded. Decoder state and prefix storage use
the supplied working allocator and are released at extent boundaries or error.
Legacy physical lengths follow the format's single-block default or explicit
big-pcluster counts, including shared references with noncontiguous addresses.

A zero encoded-length mask represents a hole and emits zeros without
reading its physical address. With the fragment-pcluster advise flag, the final
record instead carries a packed offset: the complete 32-bit length word is the
low offset, and records of 8 bytes or more provide its high 32 bits in
`pstart_lo`. This record shares the ordinary fragment child reader, including
full/compact/modern packed layouts, range offsets and packed-extent limits.
Self references, non-regular packed inodes and unsupported chunk containers are
rejected. Record ordering and remaining metadata are validated before reporting
`done`, including when the requested range ends before the final fragment.

Partial references allow decoding to stop without reaching compression EOF.
Required header, literal spans, match and source bytes must still be valid.
Decoding can stop before unused compressed suffixes or stream footers; any
validation reached while producing the prefix remains active.

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

`directory_metadata_zone = true` reserves ordinary directory blocks in the
primary metadata zone before regular-file payloads, matching the placement
selected by erofs-utils `--MZ=id`. Inline directory tails stay adjacent to their
inode in its primary or metabox storage. This option works with stored and all
four codecs, ordinary/grouped/physically bounded file compression,
48-bit/extended inodes, file-tail packing and local/external stored chunks. It is
independent of `metabox`; enabling both keeps visible inode/inline metadata in
the MZi inode while directory blocks remain in the primary metadata zone.
`compress_directories` and `directory_metadata_zone` select different directory
layouts and cannot both be enabled. The encoder reserves the directory zone
before reading file Sources, preserves those addresses through grouped file
planning, and emits the directory reservation during its metadata phase.
Directory buffers and the metadata output reservation count toward the working
heap budget; allocation failure releases both. No complete file Source is
loaded to arrange directory placement.

`metabox = true` emits the standard MZi layout. Visible inode slots, inline
directories and tails, xattr ibodies, and compression indexes are planned in a
separate block-padded metadata stream; directory entries and the superblock use
bit-63 NIDs. One low-NID hidden inode in the primary metadata owns that stream,
using stored blocks or the selected LZ4/MicroLZMA/raw-Deflate/Zstandard
full-index codec. The encoder finishes every non-metabox node and packed index
before populating the visible metabox metadata, then encodes the metadata inode
last. With larger groups, its actual physical size never changes earlier
addresses. Fixed-size layouts retain their preassigned addresses while using
the same completion order.
The extended 144-byte superblock carries `metabox_nid` and enables 48-bit
addressing for the high-bit root NID. Physical file and large-directory blocks
remain in the primary image unless directory compression is selected.
Metabox output supports local/external stored chunks, regular-file tail
fragments and compressed-inline pclusters. Chunk indexes live with their inode
in metabox storage while local/device bytes remain in the primary/external
payload. Packed data uses a low-NID hidden primary inode. Inline compressed
tails live beside the high-NID file inode and preserve their metabox-relative
address. Shared xattrs and plain long-prefix tables retain their primary
metadata address space. Existing chunk rules still require stored compression
and reject combining chunks with compressed file tails or compressed directories.

erofs-utils 1.9.4-g5fcb2f76 maps metabox compressed-inline tails correctly but
reads the resulting metadata offset from the primary image in both fsck and
dump. Such complete-file checks use an explicitly supplied independent copy
with the small address-space fix documented in
[`metabox-inline-oracle.md`](../../tools/erofs/metabox-inline-oracle.md).
That copy also invalidates its metadata cache when switching address spaces,
so metabox ibodies and shared primary xattrs do not reuse a same-block cache.
The original tools continue to validate ordinary modes and complete file bytes
in metabox chunk/fragment modes; the differential reports corrected combined
and inline-oracle counts separately. The fix uses erofs-utils' own metadata
reader and codec code.

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
all regular files into memory. `encodeErofsAlloc` allocates the complete
caller-owned output image while its working core retains only metadata plans
and the current input/codec window. Compressed Source scratch is at most the
decoded extent size; chunk emission uses a fixed 4 KiB temporary buffer.

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

`ErofsEncoder` is a caller-owned resumable writer. Initialize it in stable
storage with `init(allocator, entries, options, limits)` or
`initExternalChunks(...)`, and retain that address until `deinit()`. Entry
data, Source contexts, options and their borrowed arrays remain valid and
stable for the same lifetime. Planning may read tails/chunks and encode inline
tails before the first output call; the writer owns only tree/metadata plans,
source descriptors and the current input/codec window.

`read(output)` returns `ErofsEncodeProgress`: `output_written`, absolute
`offset`, `target` (`image`/`device`) and `need_output`/`done` status. Apply
nonempty output to the indicated random-access destination. Physical data is
emitted before finalized metadata; image offsets therefore return to zero
near completion. A selected cluster and its padding survive arbitrarily small
output slices without rereading/reencoding that selection. Empty output
produces no progress or additional Source reads. Failed reads leave caller
output unchanged and remain sticky.

`result()` returns null until `done`, then provides image/device lengths and
peak working bytes. The last successful read may carry bytes and `done`
together, so write those bytes before committing final length. External
device length precedes primary image length in convenience adapters; callers
using raw pieces control their own transaction boundaries. Always deinitialize
the writer, including on cancellation or error. Moving/copying a live encoder
would invalidate its allocator/planner pointers.

```zig
var encoder: vort.ErofsEncoder = undefined;
try encoder.init(allocator, entries, .{ .compression = .lz4 }, .{});
defer encoder.deinit();
var buffer: [4096]u8 = undefined;
while (true) {
    const progress = try encoder.read(&buffer);
    if (progress.output_written != 0)
        try image_sink.writeExact(progress.offset, buffer[0..progress.output_written]);
    if (progress.status == .done) break;
}
try image_sink.finish(encoder.result().?.image_size);
```

Sink and allocating convenience writers use this same core. Allocating
methods retain caller-owned image/device output buffers and impose no separate
working limit; direct encoders and Sink methods use `ErofsSinkLimits`.
The original allocating orchestration is retained only as an internal byte
comparison reference. CLI creation uses the public encoder and accepts
`--output-chunk-size=bytes` and `--working-memory-limit=bytes`; existing
positional options remain supported. The chunk option ranges from 1 byte to
1 MiB and controls a caller-owned output buffer outside the working budget.

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

Plain, metabox and packed-inode long xattr prefix tables are supported.
Partial references, holes and final fragments in 48-bit extent records are
supported by both reading interfaces. The writer supports MZ=id directory-data
placement through `directory_metadata_zone`. Chunk output requires stored
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
are covered. Debug and ReleaseFast each pass 128 EROFS plus 12 independent I/O
tests (4 Source, 8 Sink/allocator), with explicit imports ensuring that file
adapters and allocator tests are actually analyzed by Zig.
erofs-utils 1.9.4-g5fcb2f76 passes all 324 writer modes, including 108 Sink
counterparts, with 261 xattr, 63 metabox, 60 directory, 63 extended-inode and
120 physically bounded writer cases.
The external matrix uses the Debug CLI. The final standard Debug repository
suite (`zig build test`) also passes, alongside check and wasm compilation.

The Source reader runs this complete matrix through file Sources and direct
file Sinks. Six additional CLI checks cover images and devices larger than
512 MiB under a 64 KiB working limit, listing, budget-failure preservation,
same-path extraction and corrupt-final-pcluster cleanup (`source_reader=6`).
The Source reader regressions cover every codec/layout, boundary-crossing
ranges, compact/final-big references, metabox and shared xattrs, deferred
loading, encoded/decoded caps, Source/Sink errors and exhaustive OOM. Four-MiB
stored input/output uses less than 64 KiB requested working heap; legacy and
grouped compressed extraction uses at most 2 MiB while emitting 4 MiB. Packed
files with modern extent records also extract through the Source path.
The Source archive increment's Debug repository suite passes 3438/3438 tests.
Resumable extraction passes the 140-case focused gate and wasm compilation;
the external matrix also passes 18 CLI extractions with 17-byte buffers
(`resumable_reader=18`), alongside the 324 ordinary modes and six file cases.
Final Debug repository validation passes 3447/3447 tests; broad check, wasm,
CLI help and post-rebase focused verification also pass.

Resumable encoding adds another 108 Source-backed writer modes. The complete
432-mode matrix requires identical primary/device bytes and validates output
with erofs-utils 1.9.4-g5fcb2f76 (`encoder_writer=108`, `writer=432`,
`external_writer=432`). Mixed 0/1/7/137/31-byte output slices exercise data,
padding, node completion and metadata rewrites. Debug and ReleaseFast pass
136 EROFS plus 12 independent I/O tests, including internal allocating-reference
comparisons, a 4 MiB Source within 64 KiB working heap, selection reuse without
extra Source reads, sticky failure, startup budgets, cancellation and OOM.
Thirteen actual CLI creation cases also use 17-byte output buffers, covering
stored/default/grouped/bounded codecs and existing atomic replacement checks.
Final Debug repository validation passes 3455/3455 tests. Broad check, wasm,
CLI help and all 148 post-rebase focused cases also pass.

Streamed directories and unified slice reading pass 144 EROFS plus 12 I/O
tests in Debug/ReleaseFast. Stored and compressed 10,000-entry directories
larger than their working limits traverse and look up under 32 KiB/128 KiB
heap budgets, and a slice iterator succeeds with a 16 KiB allocator. Three
real stored/compressed/metabox directory images pass CLI listing, last-entry
lookup and erofs-utils validation (`directory_stream=3`), alongside the 432
ordinary modes, six Source file and 18 output-slice cases.
Final Debug repository validation passes 3463/3463 tests. Broad check, wasm,
CLI help and all 156 post-rebase focused cases also pass.

Packed xattr prefixes pass all 152 EROFS cases in Debug and ReleaseFast, with
the latter also passing 12 independent I/O cases (164 total). Five committed
erofs-utils fixtures cover stored and every compressed codec. Fresh differential
validation adds nine stored/full/compact packed-prefix modes with root, shared,
inline and directory attributes (`packed_prefix_reader=9`) to the existing
432-mode matrix. A 4 MiB stored packed file reads only its prefix records under
a 64 KiB working limit; 128 prefixes also fit a 40 KiB slice allocator.
Truncation, invalid records, late modern-extent metadata errors, independent
Source/output/work limits, metabox priority/failed loading, and exhaustive
allocation failures are covered. Final Debug repository validation passes
3471/3471 tests; broad check (125 steps), wasm compilation and CLI help pass.

Partial references, sparse holes and fragment extents pass 167 EROFS cases in
Debug and ReleaseFast, with 12 additional I/O cases passing in ReleaseFast
(179 total). The complete 432-mode matrix retains its existing coverage and
adds 88 legacy/4/8/16/32-byte partial, hole, fragment and noncontiguous-address
cases (`partial_extent_reader=88`). Four actual-file overflow cases preserve
existing output and clean temporary files (`partial_extent_errors=4`).
One-byte range extraction succeeds under a one-byte decoded limit, while four
noncontiguous legacy images spanning 4 MiB fit 128 KiB working heaps and a
4 KiB encoded extent cap. Native tests cover exact errors, late metadata
validation, sticky failures, tiny output schedules and exhaustive OOM.
The final Debug repository suite passes 3486/3486 tests; broad check (125
steps), wasm compilation, CLI help and dedicated default DEFLATE/MicroLZMA
decoder regression checks also pass.

Unified device reading passes 177 EROFS cases in Debug and ReleaseFast, plus
12 independent I/O cases in ReleaseFast (189 total). The original 432-mode
erofs-utils 1.9.4-g5fcb2f76 matrix and 70 additional actual-file device cases
pass (`device_reader=70`). The latter cover unaligned 4/8/16/32-byte records,
all four codecs, legacy heads, compact packed data, flat files, compressed
directories, metabox Sources and CLI device listing/xattrs/extraction.
Native tests additionally cover explicit-ID-only slots, u64 offsets above
4 GiB without allocating a blob, range isolation, short/failing devices,
decoder cache reuse, declared primary-image bounds and exhaustive OOM.
Final Debug repository validation passes 3496/3496 tests. Broad check (125
steps), wasm compilation and CLI help also pass.

Directory metadata-zone writing passes 182 EROFS tests in Debug and
ReleaseFast, plus 12 independent I/O tests in ReleaseFast (194 total).
Allocating/reference/Sink/resumable encoder outputs agree across stored and all
four codecs, ordinary/grouped/physically bounded output, metabox metadata,
shared/long-prefix attributes, local/external chunks and file-tail layouts.
The 432-mode erofs-utils matrix passes alongside ten metadata-zone writer
cases (`metadata_zone_writer=10`). fsck validates directory entries, attributes
and file physical blocks; dump independently checks the complete stored-metabox
regular file because fsck 1.9.4's raw inline-tail path reads primary storage.
Final Debug repository validation passes 3501/3501 tests. Broad check (125
steps), wasm compilation and CLI help also pass.

Metabox chunk/fragment/compressed-inline combinations pass 187 EROFS tests in
Debug and ReleaseFast, plus 12 independent I/O tests in ReleaseFast (199 total).
The writer matrix passes 536 modes across allocating, Source, Sink and
resumable encoder inputs. Original erofs-utils 1.9.4-g5fcb2f76 validates file
data for 488 modes; the separately built metadata-address/cache oracle verifies
all 104 new metabox combinations, including 48 compressed-inline cases and
restored shared xattrs (`original_fsck_writer=488`,
`metabox_combined_oracle=104`, `metabox_inline_oracle=48`). Native regressions
cover tiny outputs, grouped/physically bounded layouts, chunk deduplication,
holes, ranges, planning/streaming Source failures, dual-Sink finish order,
working limits and exhaustive allocation failures. Final Debug repository
validation passes 3506/3506 tests; broad check (125 steps), wasm compilation
and CLI help also pass.

Dual-algorithm reading passes 191 EROFS cases in Debug and ReleaseFast plus
12 independent I/O tests in ReleaseFast (203 total). Twelve independent blocks
from liblz4 1.9.3, zlib 1.2.11, libzstd 1.4.8 and XZ Utils 5.8.4 supply all
16 ordered codec pairs across full/compact, inline and partial-reference
layouts. Original fsck.erofs 1.9.4-g5fcb2f76 validates all 84 layout/device
images (`dual_algorithm_reader=84`), alongside the complete 536-mode writer
matrix. Native tests additionally cover full/compact metabox inline metadata,
ranges, tiny outputs, late Source errors, invalid IDs and exhaustive OOM.
Final Debug repository validation passes 3510/3510 tests. Broad check (125
steps), wasm compilation and CLI help also pass.
