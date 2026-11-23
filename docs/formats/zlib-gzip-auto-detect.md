# Automatic zlib or gzip wrapper decoding

`ZlibOrGzipIncrementalDecoder` recognizes a valid zlib CMF/FLG pair or gzip
magic from at most two caller bytes, then delegates the complete operation to
the established zlib or gzip incremental decoder. Raw DEFLATE remains an
explicit API because it has no unambiguous wrapper signature.

The detector commits to gzip after `1f 8b`; method, flags, optional fields and
FHCRC are then validated by the gzip child. A non-gzip pair is accepted as zlib
only when CM=8, CINFO is at most 7 and FCHECK is valid. Other pairs return
`InvalidMagic` and are not reinterpreted as raw input.

The facade exposes tiny-input/tiny-output `step`, `stepToBlockBoundary`,
`finish`, `reset`, `cloneInto`, snapshots, diagnostics, member boundaries and
trailing-prefix recovery. Zlib-only `requiredDictionaryId` and
`provideDictionary` preserve resumable FDICT behavior; they return null or
`InvalidStreamState` for gzip. Explicit `allow_concatenated` continues with the
selected wrapper type only, while a different wrapper is trailing data.

The direct zlib/gzip incremental decoders and the auto facade accept
`max_members`, an independent logical-stream cap that includes empty members.
It defaults to unlimited. Once a complete fixed wrapper header has been
validated, an excess member returns `OutputLimitExceeded`, before zlib
DICTID, gzip optional fields or events, or DEFLATE plaintext. The fixed
header may have been consumed. Previously completed counts and output remain
committed. A malformed or partial header keeps its existing error or
input-wait behavior, and an unrecognized allowed tail is not a member.
`reset` starts a new count. The one-shot `ZlibDecodeOptions` and
`GzipDecodeOptions` also offer `max_members` (unlimited by default), counted
per call. With auto detection set the cap on the selected wrapper's options.
Prefix APIs decode only one member and can refuse it with a zero cap. The
cap applies to options-based size queries, probes, and chunk decoders too;
fixed-output concatenation keeps already delivered members, while append
still rolls back its logical length on failure.

`stepWithHeaderEvents` and `stepToBlockBoundaryWithHeaderEvents` forward a
per-call [gzip header observer](gzip-header-events.md) after detecting gzip.
The two-byte detection prefix does not produce or duplicate events. `.complete`
occurs only after validating the complete gzip header (including FHCRC when
present) and before writing plaintext from that member. Zlib ignores the
observer, including on dictionary requests and retries. The observer is not
retained by the decoder or its clones. These methods do not change detected
format, concatenation, trailing-input or progress semantics.

One-shot `decodeZlibOrGzipPrefix*` and owned
`decodeZlibOrGzipPrefixAlloc*` functions follow libz `inflateInit2(47)`:
exactly one wrapper stream is decoded and `input_read` identifies the untouched
suffix. Strict `decodeZlibOrGzip*` functions require the complete input to be
one stream. Limited and ExactSize variants constrain only the detected first
stream. `DecodedZlibOrGzip.deinit` releases owned output.

Contracts cover stored/fixed/dynamic wrappers, split detection, invalid and
committed headers, zlib dictionary retry, same-format concatenation, mixed
wrapper tails, checksum options, cumulative output limits, detecting and
selected-state clones, failed-call progress, native/x86/WASI consumers, and
Python libz 1.2.11 `wbits=47` boundary parity. The observer tests also cover
split detections, same-format members, corrupt FHCRC and failed-call progress,
block-boundary stepping, clone/reset, and silent zlib dictionary retries. An
independent libz 1.2.11 `inflateInit2(47)` / `inflateGetHeader` / `Z_BLOCK`
probe confirms the fixture's complete gzip header at byte 29 before plaintext,
refuses a bad FHCRC, and reports no gzip header for zlib.

```sh
zig build -j2 test-zlib-or-gzip-auto
zig build -j2 test-zlib-or-gzip-auto-x86
zig build -j2 test-zlib-or-gzip-auto-wasm
zig build -j2 run-zlib-or-gzip-auto-diff
zig build -j2 check-zlib-or-gzip-auto
```
