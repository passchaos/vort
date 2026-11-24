# Source-backed Zstandard seekable ranges

Use `zstdOpenSourceSeekTable` to open a Zstd contrib seekable stream from
`ByteSource` rather than a contiguous compressed slice. This supports files and
other stable random-access sources, including compressed offsets above 4 GiB
on 32-bit targets. The source covers exactly one complete seekable container;
its terminal seek table must end at `source.len`.

1. `zstdOpenSourceSeekTable(source)` reads the terminal footer and the table's
   skippable header. It returns the entry count without reading compressed
   frames or index entries.
2. `table.buildIndex(entries)` loads entries into caller-owned storage. It
   validates the table's cumulative compressed length against the table offset.
   No frame bytes are read. `entries` must fit `table.entry_count` elements of
   type `ZstdNativeSeekTableEntry`; a failed build can leave tentative entries
   in that storage, but does not return an index.
3. `zstdSourceSeekableRangeRequirements(index, offset, length, options)` reads
   only the selected data-frame headers and reports the exact minimum sizes of
   the four `ZstdSourceFrameWorkspace` slices and the separate range scratch.
   Callers that already have appropriately sized buffers can skip this step.
4. `zstdDecodeSourceSeekableRangeInto(index, offset, output, workspace,
   range_scratch, options)` writes exactly `output.len` plaintext bytes on
   success. Reuse the same index for subsequent reads; its binary search skips
   zero-output entries and does not reread the table.

For example, given a `ByteSource`, caller-owned `entries` and reusable buffers:

```zig
const table = try vort.zstdOpenSourceSeekTable(source);
const index = try table.buildIndex(entries);
const options: vort.ZstdSourceSeekableDecodeOptions = .{
    .max_window_size = 8 * 1024 * 1024,
    .frame_decoded_max = 32 * 1024 * 1024,
};
_ = try vort.zstdDecodeSourceSeekableRangeInto(
    index, offset, output, workspace, range_scratch, options,
);
```

Only entries intersecting the requested plaintext range are decoded. An empty
range, including one at the end of the stream, needs no workspace and reads no
frames. Out-of-bounds ranges return `RangeOutOfBounds`; zero-output entries
(including skippable or empty frames) and unselected entries are not inspected.
Each selected entry must contain exactly one standard Zstd data frame, and its
actual compressed end and decoded length must match the seek table. Both the
frame checksum and seek-table checksum are verified when present, including if
the requested range ends well before the frame ends. There is no verification
claim for unselected data.

All intermediate storage is caller-owned. Only the largest **selected
intersection** is required in `range_scratch`, not the full decoded frame.
The workspace retains the declared frame history (plus selected dictionary
history), one decoded block and two bounded entropy pages. There is no
full compressed-frame buffer. The library publishes an intersection after
verifying its complete frame; if a later frame fails, earlier verified ranges
remain written, and the failing frame's output stays untouched. Scratch and
workspace contents are unspecified after a failure.

`frame_decoded_max` applies to each full selected frame and is checked against
the index before frame reads; `max_window_size` is checked at each selected
frame's header before dictionary lookup or block reads. Supply a dictionary
catalog for declared IDs and/or a fallback dictionary for ID-less frames (or
IDs absent from the catalog). Keep the source and index storage stable.
The output, range scratch and workspace slices must be disjoint from each
other and from the index, dictionaries and source backing. The opaque source's
context and backing cannot be checked for aliasing by the library.

`zig build check-zstd-source-reverse` covers the range path on native Linux,
32-bit x86 and executed WASI. The checked-in fixture was emitted with libzstd
1.6.0 (`01b7154f`) and the contrib frame log. The same 166-byte wire
(`3bef4c205e71aab5d219e3547a171319aa9a4a8405b7676e61097fd0978c95d5`)
passed 2,662 range comparisons against known plaintext through the upstream
`ZSTD_seekable_initFile` / `ZSTD_seekable_decompress` APIs. Vort's tests also
check read isolation, exact-range sizing, and publication after checksum and
size verification. The contiguous seekable APIs and wire format are unchanged.

The same gate exercises rotation between two full dictionaries trained by
upstream libzstd 1.6.0, with independently verified checksummed data frames.
The [fixture oracle](../../tools/zstd/source_seekable_dictionary_fixture.c)
also verifies refusal when the dictionary is missing or its ID is correct but
its content is wrong. The Vort range crosses adjacent entries with different
IDs, without reading either surrounding frame. Tests verify catalog precedence,
fallback, header-only refusal of a missing dictionary, and retry of only the
unwritten suffix after the preceding frame has already been published.
