# Gzip direct chunk decoding

Vort can decode one gzip member directly from discontiguous caller-owned input
without first copying the complete compressed member into a join buffer.
`decodeGzipChunksInto` writes into caller storage, while
`decodeGzipChunksIntoWithOptions` retains the existing CRC32, ISIZE and trailing
data controls. Existing APIs that accept `compressed_scratch` remain compatible
and keep their established scratch-size errors.

`GzipDecoder` provides matching `initFromChunks*Direct` and
`resetFromChunks*Direct` methods. Initialization synchronously validates and
decodes the complete member into caller-owned decoded scratch; subsequent
`step` calls drain that scratch with the same progress and diagnostics as the
contiguous and legacy chunk initializers. Input chunks need remain immutable
only for the initialization/reset call. Decoded scratch must remain alive while
the decoder drains it.

The direct parser accepts empty chunks and arbitrary byte boundaries. It reads
the fixed header, XLEN/FEXTRA, zero-terminated FNAME/FCOMMENT and FHCRC through a
byte cursor, then feeds the existing stored/fixed/dynamic inflater through the
shared chunked bit reader. Footer location comes from the actual final DEFLATE
bit position rather than `input_len - 8`, so strict trailing-data behavior is
unchanged.

Error priority matches contiguous gzip decoding:

1. incomplete fixed or optional headers return `TruncatedFrame`;
2. invalid magic, method, reserved flags or FHCRC return `BadGzipHeader`;
3. DEFLATE errors, including `OutputTooSmall`, are reported before footer errors;
4. an incomplete footer returns `TruncatedFrame` even when checks are ignored;
5. CRC32, ISIZE and trailing data are checked in that order.

The initial contracts cover stored, fixed and dynamic blocks; every-byte and
empty-interleaved chunks; all optional header fields; footer corruption and
truncation; relaxed controls; a 96 KiB cross-span history case; reusable reset
diagnostics; an independent zlib/gzip fixture; and native, x86 and WASI package
consumers.

```sh
zig build -j2 test-gzip-direct-chunks
zig build -j2 test-gzip-direct-chunks-x86
zig build -j2 test-gzip-direct-chunks-wasm
zig build -j2 check-gzip-direct-chunks
zig build -j2 run-gzip-direct-chunks-diff
```
