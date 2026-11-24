# Gzip CLI standard streams

## Decoding

`decode-gzip-file` and its `decode-gzip-concat-file` alias accept `-` for
stdin or stdout. Use `./-` for a file literally named `-`.

```sh
vort decode-gzip-file - - < data.gz > data.bin
vort decode-gzip-concat-file combined.gz - 1048576
vort decode-gzip-file - data.bin < data.gz
```

When either endpoint is `-`, the command uses the library's incremental gzip
decoder. It accepts concatenated members, including empty members, and validates
CRC-32 and ISIZE for each one. The optional `max_output` is a single 64-bit
limit on decoded bytes across all members. The decoder retains a 32 KiB
DEFLATE history and uses the incremental per-field gzip header metadata limit
of 1 MiB. It does not buffer the complete compressed input or apply a
whole-file compressed input limit.

Stdout carries only decoded bytes, including bytes produced before the member
footer or stdin EOF. A bad footer, incomplete member, or non-member suffix
fails the command; output already written to stdout cannot be withdrawn.
When reading stdin into a named destination, the command is quiet on success
and replaces the file only after validation reaches EOF. Two named paths retain
the original one-shot decoding and summary by default.

### Optional terminal zero padding

Pass `--allow-zero-padding` to accept an all-zero suffix after a validated
member, as GNU gzip does. The default remains strict. Once the first padding
byte arrives, any nonzero byte, including another member header, is rejected.
A file containing only zeros is not a gzip stream.

The flag uses incremental decoding for both named and pipe endpoints. Set
`GzipIncrementalDecoder.Options.allow_trailing_zero_padding` for the same
behavior in a streaming caller. Padding counts as consumed input, not as part
of the last member, and EOF is confirmed with `finish()`.

For whole-input decoding, set `GzipDecodeOptions.allow_trailing_zero_padding`
(including `ZlibOrGzipDecodeOptions.gzip` for auto-detection). It applies to
single and concatenated gzip decoding, including chunked inputs. Both options
default to `false` and cannot be enabled alongside `allow_trailing_data`.
Auto-detect prefix decoders still stop at the end of the first member without
validating or counting its suffix.

`zig build test-gzip-stdio-cli` checks these contracts on the native CLI and
the WASI decode probe, including progressive output and atomic replacement.

## Encoding

```sh
vort encode-gzip-best-file - - < data.bin > data.gz
vort encode-gzip-best-file - data.gz --rsyncable --max-input-len=1048576 < data.bin
vort encode-gzip-best-file data.bin - fast > data.gz
```

With `-` on either endpoint, the command emits one gzip member incrementally
without a whole-file input cap. `--rsyncable` uses content-defined boundaries
in that member. `--max-input-len` and `--max-output-len` accept 64-bit byte
limits on all streaming routes (either endpoint is `-`, or `--rsyncable`).
The original two-path one-shot route does not accept stream limits.

With either endpoint set to `-`, success summaries are suppressed. Stdout
carries only compressed bytes when selected; if streaming subsequently fails,
already written bytes cannot be withdrawn. A named output is replaced only
after successful completion. Two named paths keep their existing default
one-shot or explicit rsyncable behavior when no new limits are supplied.

`zig build test-gzip-encode-stdio-cli` checks native and WASI encoding,
including independent gzip decoding, rsyncable output, and atomic failure.
