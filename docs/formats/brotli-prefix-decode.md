# Brotli first-stream prefix decoding

Vort's prefix APIs decode exactly one complete Brotli stream from the start of
a larger byte sequence. `DecodePrefixResult.input_read` includes the validated
end marker and zero padding byte, while `output_written` reports bytes emitted
to caller storage. Bytes beginning at `input[input_read..]` remain outside the
Brotli operation and can be handed to another protocol or decoded as the next
stream.

The public families cover caller-buffer, owned, append, size-preflight and
legacy joined-chunk inputs:

- `decodeStreamPrefixInto*`
- `decodeStreamPrefixAlloc*`
- `decodeStreamPrefixAppend*`
- `decodedStreamPrefixSize*`
- the corresponding `decodeStreamPrefixChunks*` and
  `decodedStreamPrefixChunksSize*` functions

Each family includes `WithOptions`; Limited and ExactSize variants are present
where the strict API already defines those resource contracts. Owned results
use `DecodedPrefix.deinit(allocator)`. Chunk results report a flattened logical
offset across the concatenated spans and retain the existing full
`compressed_scratch` join requirement.

Strict `decodeStream*` entrypoints wrap the same core and require
`input_read == input.len`, preserving `TrailingData`. Limited prefix decoding
preflights the first stream before mutating caller output; an exceeded limit
returns `OutputLimitExceeded`, while insufficient physical output returns
`OutputTooSmall`. Append failures preserve the original list length. ExactSize
keeps physical-capacity checks and maps decoded-size mismatches to
`SizeMismatch`.

The one-shot boundary is derived directly from the bit reader after validating
zero padding. Incremental `allow_trailing_data` has a different transport-level
counter because reservoir lookahead is accepted and returned by
`trailingInput()`; tests prove that `accepted - trailingInput().len` equals the
one-shot prefix boundary without changing incremental accounting.

Contracts cover empty/stored/compressed/metadata and large streams, two-member
handoff, arbitrary invalid suffixes, corruption/truncation, output transactions,
RAW shared dictionaries, Large Window opt-in, every-byte chunks, allocation
failure, native/x86/WASI consumers, and libbrotli streaming `available_in`
parity.

```sh
zig build -j2 test-br-prefix-decode
zig build -j2 test-br-prefix-decode-x86
zig build -j2 test-br-prefix-decode-wasm
zig build -j2 run-br-prefix-decode-diff
zig build -j2 check-br-prefix-decode
```
