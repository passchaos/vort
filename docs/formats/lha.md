# LHA/LZH archive support

Vort provides dependency-free LHA/LZH archive reading and deterministic
writing. The implementation targets common new-style and legacy methods while keeping
container parsing and the codec core separate.

The reader accepts header levels 0, 1, and 2. It validates level-0/1 additive
header checksums, chained extended-header sizes, level-2 total header sizes,
optional common-header CRC-16 records, 32- and 64-bit size declarations,
payload bounds, and the per-file LHA CRC-16. Filename and path extended headers
are exposed as borrowed `LhaName` components; `writeInto`, `alloc`, and `eql`
normalize DOS backslashes and the level-1/2 `0xff` path separator without
silently materializing filesystem paths.

Supported entry methods are:

- stored `-lh0-`;
- adaptive-Huffman `-lh1-` with a 4 KiB dictionary;
- `-lh5-` with an 8 KiB dictionary;
- `-lh6-` with a 32 KiB dictionary;
- `-lh7-` with a 64 KiB dictionary;
- LArc `-lz5-` with its standard 4 KiB initialized dictionary;
- LArc `-lzs-` with a 2 KiB space-filled dictionary;
- directory `-lhd-` metadata entries.

The shared LH5/6/7 decoder handles MSB-first blocks, temporary/code/position
canonical Huffman trees, zero-run encoded command lengths, literal commands,
3...256-byte overlapping matches, initialized space history, exact declared
output, truncation, incomplete-but-valid trees, invalid distances, and exact
compressed-byte consumption. Allocation APIs check the caller's output limit
before allocating.

The LH1 path implements the complete 314-symbol adaptive Huffman tree,
frequency groups, leader swaps, static offset prefixes, and the mandatory
32 KiB tree reconstruction transition. Its writer follows the same updates
while emitting arbitrary literal bytes. LZ5 supports LArc's eight-command
LSB-first bitmap groups and exact historical prefill; LZS supports its
MSB-first literal/copy commands and absolute ring positions. Both have
deterministic literal writers, while their decoders accept overlapping matches
from initialized or produced history.

The deterministic writer emits level-0 headers with a fixed 1980-01-01 DOS
timestamp, additive header checksum, payload CRC-16, and an archive terminator.
Stored, LH1, LH5, LH6, LH7, LZ5, LZS, and directory entries may coexist in one archive.
New-style compressed output currently uses a complete fixed 510-symbol command
tree and literal commands. This produces fully interoperable streams for all
input bytes; LZ match planning and adaptive new-style Huffman tables remain later ratio
work.

```zig
const entries = [_]vort.LhaEncodeEntry{
    .{ .name = "plain.bin", .data = plain, .method = .stored },
    .{ .name = "compressed.txt", .data = text, .method = .lh5 },
};
const bytes = try vort.encodeLhaAlloc(allocator, &entries);
defer allocator.free(bytes);

const archive = try vort.parseLhaArchive(bytes);
const entry = (try archive.find("compressed.txt")) orelse
    return error.LhaEntryNotFound;
const decoded = try archive.extractAllocLimited(allocator, entry, 64 * 1024 * 1024);
defer allocator.free(decoded);
```

CLI validation surfaces:

```sh
zig build run -- create-lha-file archive.lzh payload.bin input.bin lh5
zig build run -- list-lha-file archive.lzh
zig build run -- extract-lha-file archive.lzh payload.bin output.bin 67108864
zig build run-lha-diff
```

The differential always checks deterministic Vort writing and self-extraction
for all seven data methods. With lhasa and its fixture directory supplied, it
also decodes all seven Vort writer modes through lhasa and checks real
level-0/1/2 archives, LH1/LH5/LH6/LH7/LZ5/LZS streams, common header CRCs, and
nested extended paths in the reverse direction:

```sh
zig build run-lha-diff -- \
  --reference path/to/lhasa/src/lha \
  --fixtures path/to/lhasa/test/archives
```

Header level 3, self-extracting prefixes, encryption, multi-volume metadata,
and older `-lz4-`, PMarc, and LHARK-specific `-lk7-` methods remain explicit
future compatibility increments. Archive names are never joined to a host
filesystem path by the library.
