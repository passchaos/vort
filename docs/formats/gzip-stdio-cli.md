# Gzip CLI standard streams

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
the original one-shot decoding and summary.

`zig build test-gzip-stdio-cli` checks these contracts on the native CLI and
the WASI decode probe, including progressive output and atomic replacement.
