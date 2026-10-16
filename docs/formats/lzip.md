# Lzip (`.lz`) support

Vort provides pure Zig encoding and decoding for version-1 lzip files. Lzip wraps a
marker-terminated raw LZMA1 stream with a six-byte member header and a
20-byte integrity trailer. The implementation supports both single-member
and concatenated files.

The decoder validates:

- the `LZIP` magic, version, and coded 4 KiB through 512 MiB dictionary size;
- the fixed LZMA properties (`lc=3`, `lp=0`, `pb=2`) and mandatory end marker;
- CRC-32 of every member's uncompressed data;
- declared uncompressed size and complete member size;
- the lzip trailer consistency bounds and the prohibition on empty members in
  multimember files;
- absence of unaccounted leading, inter-member, or trailing bytes.

```zig
const info = try vort.inspectLzip(allocator, compressed);
const decoded = try vort.decodeLzipAllocWithOptions(allocator, compressed, .{
    .max_output_len = 256 * 1024 * 1024,
    .max_dictionary_size = 64 * 1024 * 1024,
});
defer allocator.free(decoded);

const encoded = try vort.encodeLzipAlloc(allocator, input, .{
    .dictionary_size = 64 * 1024,
});
defer allocator.free(encoded);
```

Available APIs include `parseLzipHeader`, `inspectLzip`,
`decodeLzipInto`, `decodeLzipAlloc`, `decodeLzipAllocLimited`,
`decodeLzipAllocWithOptions`, validated decoded-size helpers,
`encodeLzipAlloc`, `encodeLzipInto`, transactional `encodeLzipAppend`, and
multi-member encode helpers. Dictionary and output limits are checked before a
member's LZMA decoder is initialized. Writer dictionary requests are rounded up
to the smallest standard lzip dictionary representation.

`LzipIncrementalDecoder` synthesizes the fixed LZMA properties around each
member and reuses the symbol-progressive LZMA core. Decoded bytes flow directly
through caller output while a 20-byte lookahead captures the trailer after the
mandatory EOS marker. CRC-32, uncompressed size, complete member size and
trailer consistency are verified before advancing to the next member. The
state supports concatenated members, independent total/member output,
dictionary, compressed-staging and member-count limits, exact-output pledges,
arbitrary input/output splits and explicit EOF through `finish()`.

`TarLzipIncrementalReader` connects this decoder to the bounded TAR reader, so
`.tar.lz` archives no longer require a fully materialized decompressed TAR.

`LzipIncrementalEncoder` performs the inverse composition without duplicating
the LZMA algorithm. It filters the 13-byte LZMA-Alone header from the existing
symbol-progressive encoder, emits the six-byte lzip header, and appends CRC-32,
data-size and member-size trailer fields after the mandatory EOS marker.
Different requested dictionary sizes use the same canonical rounding and
65,535-byte current match-search ceiling as the one-shot writer. Single and
concatenated members, arbitrary caller splits, output backpressure, limits and
allocation failures are supported. `TarLzipIncrementalWriter` composes this
state directly after the raw TAR writer.

CLI validation surfaces:

```sh
zig build run -- encode-lzip-file input.bin output.lz 65536
zig build run -- inspect-lzip-file input.lz
zig build run -- decode-lzip-file input.lz output.bin 268435456 67108864
zig build run -- size-lzip-file input.lz 268435456 67108864
zig build run-lzip-diff
```

The writer emits fixed `lc=3`, `lp=0`, `pb=2` LZMA1 payloads with the mandatory
end marker and records CRC-32, uncompressed size, and complete member size in
the trailer. The current shared token representation limits match search to
65,535 bytes even when a larger compatible dictionary is declared; this only
affects compression ratio, not wire compatibility or decoder memory limits.
The required differential exercises six Python-generated members, six Vort
members and both concatenated forms through one-byte and micro schedules
(`incremental_cases=14`), in addition to optional system-lzip interoperability.
