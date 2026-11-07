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
Python libz 1.2.11 `wbits=47` boundary parity.

```sh
zig build -j2 test-zlib-or-gzip-auto
zig build -j2 test-zlib-or-gzip-auto-x86
zig build -j2 test-zlib-or-gzip-auto-wasm
zig build -j2 run-zlib-or-gzip-auto-diff
zig build -j2 check-zlib-or-gzip-auto
```
