# Source-backed gzip range index

`buildGzipSourceIndex` builds a reusable plaintext index over a stable
random-access `ByteSource`. It decodes all concatenated members once and
validates each gzip header, CRC-32 and ISIZE before returning the index.
It requires at least one complete member. By default, an unrecognized or
truncated suffix is rejected. Empty members are counted and verified but need
no entry.

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

Set `GzipSourceIndexOptions.allow_trailing_zero_padding` to accept an all-zero
suffix after the last verified member, including an empty member. Once the
first padding byte is seen, any nonzero byte (including another gzip member)
returns `TrailingData`. The builder checks padding through the declared source
end using the same input page. The source length includes padding, but padding
is not counted against the output or member limit and does not extend any
entry's compressed extent. Neither range-read mode visits the suffix.

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

## Optional per-member revalidation

`decodeVerifiedRangeInto` starts at the gzip header of each intersecting
member and verifies its complete header, CRC-32, ISIZE and indexed compressed
and decoded extents. It does not use a raw block checkpoint or read unselected
members. The requested intersection is staged during that single decode pass
and copied only after that member passes all checks. On failure, the failing
member's destination remains untouched and progress counts only the earlier
member intersections already verified and published.

```zig
const required = try index.verifiedRangeScratchLen(offset, output.len);
// The caller provides at least `required` bytes of disjoint range_scratch.
const result = index.decodeVerifiedRangeInto(offset, output, workspace, range_scratch);
```

Sizing consults only the index. Scratch is the largest requested intersection,
not the largest member or entire range; its used prefix must be disjoint from
output and other workspace and index buffers. The same storage is reused for
subsequent members. Invalid bounds, a short scratch span or overlapping buffers
fail before source reads or output publication. An empty valid range requires
no workspace or scratch and reads no source bytes.

Use the stable source and index as above. This mode detects read-time
corruption against the current gzip footer and indexed extents; it does not
authenticate the bytes or prove equivalence to an earlier source snapshot.
Neither range path allocates codec heap memory.

## Validation

`test-deflate-wide-decode` and `test-deflate-wide-decode-wasm` cover a zlib
1.2.11-generated member with both aligned and nonaligned history-dependent
restarts, concatenation, empty members and a header with FHCRC. Guarded
short reads verify the chosen block offset, raw footer exclusion, no earlier
member reads, and exact failure progress. Corrupt CRC/ISIZE and insufficient
workspace, history, entries or policy allowances cannot publish an index.
Verified-range tests also cover a one-byte request with a bad trailing CRC,
late-member read faults, exact scratch sizing, and valid replacement members
that fail the original indexed compressed or decoded extent checks. Padding
contracts cover cross-page suffixes, exact member and output limits, late
nonzero bytes and source errors, and range reads bounded by the real footer.
