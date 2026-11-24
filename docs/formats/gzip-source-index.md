# Source-backed gzip range index

`buildGzipSourceIndex` builds a reusable plaintext index over a stable
random-access `ByteSource`. It decodes all concatenated members once and
validates each gzip header, CRC-32 and ISIZE before returning the index.
It requires at least one complete member, and rejects an unrecognized or
truncated suffix. Empty members are counted and verified but need no entry.

```zig
const workspace: vort.GzipSourceIndexWorkspace = .{
    .history = window,       // at least 32 KiB
    .input_page = page,      // nonempty compressed input page
    .discard = discard,      // nonempty plaintext scratch
};
const index = try vort.buildGzipSourceIndex(source, entries, saved_history, workspace, .{
    .checkpoint_spacing = 1024 * 1024,
    .max_output_len = max_plaintext,
    .max_members = max_members,
});
const outcome = index.decodeRangeInto(offset, output, workspace);
```

## Build and storage

A nonempty member has a start entry. With sufficient plaintext progress, the
builder also captures an intra-member [Deflate restart point](../performance/deflate/block-boundary-checkpoint.md)
with an exact bit position and the trailing usable history. The spacing is a
minimum between available checkpoints, not a requirement to split blocks;
zero records every eligible increasing plaintext position. Empty blocks at
the same decoded offset do not add duplicate checkpoints within a member.
The caller supplies `entries` and `saved_history`; insufficient capacity is
`OutputTooSmall`. A failed build returns no index and may modify those buffers
and the workspaces. The decoder does not allocate.

Output and member-count limits are cumulative; empty members consume member
slots. The header metadata limit applies per member. A zero-byte source is
truncated, whereas a valid empty member can produce a zero-entry index.
Input reads are paged, honor `ByteSource.max_read_size`, and use explicit
64-bit source offsets even on 32-bit targets.

## Range reads and integrity

The index borrows the stable source, written entries and saved history. Keep
all three alive and unchanged; an index is not a standalone serialized or
adversarial-input format. The temporary build workspace is not retained.
A range starts at the closest indexed payload checkpoint or member header,
replays only what's needed for the request, and jumps over unselected members.
A restart inside a member stops reading at its raw payload end, not its footer.

`decodeRangeInto` does **not** freshly check every visited member's footer or
rebuild the skipped checksum prefix. Full member validation is a property of
the successful index build on the same immutable source. After bytes change,
build a new index before reading ranges. Range failures report `err` plus
`progress.output_written` and `progress.next_decoded_offset`; an already
written prefix remains in caller output. A zero-length range at a valid offset
needs no workspace and reads no source bytes. Other ranges must fit the
indexed plaintext size.

All mutable slices must be disjoint from each other and from the source. On
range reads they must also be disjoint from the index's entries and saved
history. The opaque source context is the caller's responsibility. The index
itself has no required heap allocation or per-read history allocation.

## Validation

`test-deflate-wide-decode` and `test-deflate-wide-decode-wasm` cover a zlib
1.2.11-generated member with both aligned and nonaligned history-dependent
restarts, concatenation, empty members and a header with FHCRC. Guarded
short reads verify the chosen block offset, raw footer exclusion, no earlier
member reads, and exact failure progress. Corrupt CRC/ISIZE and insufficient
workspace, history, entries or policy allowances cannot publish an index.
