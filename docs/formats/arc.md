# ARC/PAK archive support

Vort provides dependency-free ARC and compatible PAK archive reading plus
deterministic ARC writing for methods 1 through 9.

The parser recognizes the `0x1a` member marker, supports bounded SFX-prefix
search, handles the shorter obsolete method-1 header, preserves PAK extended
records after the end marker as a reported trailer, and checks every member's
declared payload range. Names are borrowed fixed-header slices. Extraction is
caller-owned or bounded-allocating and verifies ARC's CRC-16 over the final
uncompressed bytes.

Supported methods are:

- methods 1 and 2, stored;
- method 3, packed RLE90;
- method 4, Squeeze Huffman coding followed by RLE90;
- methods 5–7, old fixed-12-bit hash-table Crunch variants;
- method 8, dynamic 12-bit Crunch followed by RLE90;
- method 9, dynamic 13-bit Squash.

The RLE decoder validates DLE/count state and exact output. Squeeze parses an
explicit signed-node tree, rejects cycles and invalid leaves, recognizes the
special EOF symbol, and streams decoded bytes directly through RLE into caller
storage. Old Crunch reproduces ARC's two historical hash functions, collision
chains, fixed code slots, and alternating 12-bit nibble packing. Dynamic
Crunch/Squash supports 9...12/13-bit code growth, eight-code group alignment,
mid-group CLEAR padding, KwKwK, dictionary limits, and output bounds.

The functionality-first writer emits deterministic DOS timestamps and supports
every method above. Packed and Squeeze writers use complete RLE/Huffman streams;
old and dynamic LZW writers currently emit literal codes while maintaining the
required dictionaries and width transitions. Match discovery remains later
ratio work.

```zig
const entries = [_]vort.ArcEncodeEntry{
    .{ .name = "PLAIN", .data = plain, .method = .stored_2 },
    .{ .name = "PACKED", .data = text, .method = .packed_rle },
    .{ .name = "CRUNCHED", .data = text, .method = .crunched_8 },
};
const bytes = try vort.encodeArcAlloc(allocator, &entries);
defer allocator.free(bytes);

const archive = try vort.parseArcArchive(bytes);
const entry = (try archive.find("CRUNCHED")) orelse return error.ArcEntryNotFound;
const decoded = try archive.extractAllocLimited(allocator, entry, 64 * 1024 * 1024);
defer allocator.free(decoded);
```

CLI validation surfaces:

```sh
zig build run -- create-arc-file archive.arc PAYLOAD input.bin crunched
zig build run -- list-arc-file archive.arc
zig build run -- extract-arc-file archive.arc PAYLOAD output.bin 67108864
zig build run-arc-diff
```

The differential checks all nine Vort writer modes with ARC 5.21 and covers
stored, packed, squeezed, old/dynamic Crunch, Squash, dictionary CLEAR, 13-bit
codes, PAK trailers, corrupt CRC, and encrypted data through external fixtures:

```sh
zig build run-arc-diff -- \
  --arc path/to/arc \
  --arc-fixtures path/to/unarc-rs/crates/unarc-rs/tests/arc \
  --pak-fixtures path/to/unarc-rs/crates/unarc-rs/tests/pak
```

ARC has no reliable encryption flag, so encrypted payloads fail content CRC
without a password API. PAK methods 10 (Crushed) and 11 (Distilled) are parsed
and reported but extraction returns `UnsupportedArcMethod`; they remain the
next compatibility increment.
