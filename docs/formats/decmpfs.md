# Apple decmpfs transparent compression

Vort decodes the payload carried by macOS `com.apple.decmpfs` extended
attributes and, for large files, the companion `com.apple.ResourceFork`
bytes. The implementation is pure Zig and reuses Vort's zlib, raw LZVN, and
LZFSE codecs without depending on Compression.framework.

Supported compression types are:

- type 1: uncompressed inline data;
- type 3: inline zlib, including Apple's low-nibble `0xF` stored marker;
- type 4: 64 KiB zlib chunks in an HFS resource fork;
- type 7: inline raw LZVN, including the `0x06` stored marker;
- type 8: 64 KiB raw LZVN resource chunks and Apple offset tables;
- type 9: inline copied data with the `0xCC` marker;
- type 11: inline complete LZFSE streams;
- type 12: complete LZFSE streams in 64 KiB resource chunks.

Type 5 dataless files require access to Apple's generation store and are
reported as unsupported. Type 10 copied resource forks are also reported as
unsupported until their on-disk layout has independent compatibility evidence;
Vort does not guess or reinterpret either type.

The parser validates the 16-byte little-endian `fpmc` header and declared
logical size. Type-4 resources validate their big-endian resource header,
50-byte map, little-endian descriptor count, contiguous chunk descriptors,
and payload bounds. Compressed type-4 chunks accept observed post-stream padding
and the HFS variant that omits Adler-32, while inline zlib remains strict.
Types 8 and 12 validate the `(chunk_count + 1)` cumulative offset table,
including the byte-zero Apple layout; the legacy 0x100-prefixed layout is
accepted for compatibility. All chunk counts are derived from the logical size
using Apple's fixed 64 KiB chunk size.

Whole-file and range APIs enforce caller-selected allocation limits.
Resource-fork range decoding touches only overlapping chunks and uses one
bounded 64 KiB scratch buffer. Inline ranges require decoding the single inline
stream first, so their limit must cover the complete logical inline value.

```zig
const archive = try vort.parseDecmpfs(decmpfs_xattr, resource_fork_or_null);
const decoded = try archive.decodeAllocLimited(allocator, max_output);
defer allocator.free(decoded);

const range = try archive.decodeRangeAllocLimited(
    allocator,
    offset,
    length,
    max_allocation,
);
defer allocator.free(range);
```

The CLI takes the xattr and resource fork as separate files; pass `-` when the
compression type is inline:

```sh
zig build run -- inspect-decmpfs decmpfs.xattr resource.rsrc
zig build run -- decode-decmpfs decmpfs.xattr resource.rsrc output.bin 1073741824
zig build run -- decode-decmpfs-range decmpfs.xattr resource.rsrc range.bin 65500 4096
zig build test-decmpfs
zig build run-decmpfs-diff
```

The differential gate constructs type-3 and type-4 samples with Python's zlib,
decodes a checked-in 200,000-byte type-8 resource fork produced by `ditto`, and,
when Apple's open-source `lzfse` CLI is available, exercises externally encoded
types 7, 11, and 12. Malformed headers, missing resources, invalid offset tables,
and output limits are checked through the public CLI.

This module handles the compression metadata and resource bytes, not HFS+/APFS
catalog traversal, extended-attribute lookup, resource-fork extents, or setting
the filesystem compressed flag. A filesystem reader can pass the two extracted
byte slices directly to these APIs.
