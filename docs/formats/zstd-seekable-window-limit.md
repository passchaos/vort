# Zstd seekable range window limit

`NativeSeekableRangeDecodeOptions.max_window_size` is an optional, exact
byte limit (unlimited by default). It applies to the data frames contained in
seek-table entries intersecting the requested decompressed range. Use
`decodeNativeSeekableRangeIntoWithOptions` or `...AllocWithOptions` with a
complete seekable stream, or `...IntoWithIndexAndOptions` and
`...AllocWithIndexAndOptions` with a reusable caller-owned index. For example,
`vort.zstdDecodeNativeSeekableRangeIntoWithIndexAndOptions` accepts
`vort.ZstdNativeSeekableRangeDecodeOptions`.

A finite cap walks the admitted range's wire headers before allocating output
or scratch and before writing caller buffers. `OutputLimitExceeded` means
that a selected data header advertised a larger window. The scan uses only
selected, nonempty entries; zero-length requests do not read any frame
bytes. Standard skippable elements have no window. For a selected entry,
the scan bounds block, skippable and checksum spans without reading their
bodies. A later selected window refusal leaves both output and scratch
untouched, even when earlier entries would fit. Unselected entry bytes are
not read; the table/index must still be valid.

Use `dictionary` or `dictionary_set` (not both) for dictionary-backed frames.
The declared window is checked before resolving any selected frame's
dictionary. The decode still checks each selected entry's full decoded length
and frame/seek-table checksums before copying from it. Other decode failures
retain the existing per-entry publication semantics. Keep the stream, index
and dictionaries stable and disjoint from mutable output and frame scratch.
The scratch requirement is still the largest intersecting decompressed frame;
`nativeSeekableRangeScratchLen` and `...WithIndex` remain sizing-only queries.

Existing options-less calls use the unlimited policy and perform no additional
window scan. This is a resource control for selected frames, not a seek-table
validator or a claim about unselected frame contents.

`check-zstd-source-reverse` runs the seekable window contracts on native,
Linux x86 and actual WASI. An independent fixture check using Zstd contrib
seekable source `01b7154f` with system libzstd 1.4.8 matched the expected
cross-entry range `nela` and wide-frame payload `large`. The reference check
covers the seekable wire and selected range, not Vort's opt-in byte limit.
