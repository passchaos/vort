# Brotli caller-history preflight

`br.DecodePreflightOptions` supplies independent caller-owned `history`, a
logical `max_output_len` and optional `expected_output_len` (both wide stream
counts), plus `decode` for the usual format and zero-heap observation options.
The new entry points are:

- `decodedStreamSizeWithPreflight` and `decodedStreamPrefixSizeWithPreflight`
- `decodeStreamIntoWithPreflight` and `decodeStreamPrefixIntoWithPreflight`
- `StreamDecoder.initWithPreflight` and `StreamDecoder.resetWithPreflight`
- `decodedStreamChunksSizeWithPreflight` and `decodedStreamPrefixChunksSizeWithPreflight`
- `decodeStreamChunksIntoWithPreflight` and `decodeStreamPrefixChunksIntoWithPreflight`
- `StreamDecoder.initFromChunksWithPreflight` and `StreamDecoder.resetFromChunksWithPreflight`

Strict entry points require complete input. Prefix entry points return the
first validated stream's byte boundary, including the end marker and padding.
They neither decode nor count the following bytes against the output limit.

The chunked variants take `chunks` and `compressed_scratch` before the other
arguments. As with the existing chunk APIs, they join once into caller storage;
that scratch must fit the sum of all chunk lengths, including any transport
suffix. Empty chunks are allowed. Prefix progress is the byte offset across
those chunks, not a count of whole chunks. The joined scratch and history are
not retained. The active prefix of compressed scratch must not overlap
history, output, telemetry, dictionary storage or a live eager decoder and
its prior decoded bytes. Borrow and short-join refusal make no scratch writes;
a later wire-validation failure may modify compressed scratch and history but
leaves decoded output untouched.

For example, if the protocol supplies a known plaintext length:

```zig
const written = try vort.brDecodeStreamIntoWithPreflight(input, output, .{
    .history = history_scratch,
    .max_output_len = expected_len,
    .expected_output_len = expected_len,
});
```

The `size-br-file` CLI instead uses the allocating summary path, so it can
measure a long-distance stream without making the caller size history scratch.

The allocation-free validation pass reuses the summary parser. A history
slice covering the maximum legal backward distance (`(1 << WBITS) - 16`),
or the maximum reachable decoded bytes when smaller, suffices for all copy
contexts. A smaller history can succeed when discarded bytes are not needed;
when they are needed, the new APIs return `PreflightHistoryTooSmall`. They do
not allocate, grow the slice, or reinterpret it as a format limit. Existing
fixed-history APIs and their error behavior are unchanged.

The decode and eager paths finish preflight before writing to the destination.
`OutputLimitExceeded` applies to the logical cap; a validated output-size
mismatch is `SizeMismatch`; insufficient physical output is `OutputTooSmall`.
A failed preflight does not publish output or replace an eager decoder's prior
stream position. History may be overwritten even if validation later fails;
it is not retained by any entry point. Writable history and output must not
overlap each other, compressed input, dictionary storage, or the profile. An
eager decoder's object must also be separate; its prior decoded bytes cannot
be used as history during reset. The prior output storage can be reused as
the new destination. The normal heap profile excludes caller-owned buffers.

## Direct reads from borrowed chunks

`BrotliDirectChunkPreflightWorkspace` offers `decodedSize`, `decodedPrefixSize`,
`decodeInto`, and `decodePrefixInto` without `compressed_scratch`. It feeds
borrowed chunks to the same progressive decoder used for streaming. The size
operations do one pass; the into operations first validate into a bounded
internal discard buffer, check the physical capacity, then replay the same
immutable chunks directly into caller output. Prefix offsets include the
stream's validated padding but not any lookahead bytes from the next stream.

```zig
const workspace = try allocator.create(vort.BrotliDirectChunkPreflightWorkspace);
defer allocator.destroy(workspace);
const decoded = try workspace.decodePrefixInto(chunks, output, .{
    .preflight = .{ .history = history_scratch, .max_output_len = limit },
});
```

The explicit workspace holds the progressive decoder and a 4 KiB discard
buffer; allocate it once and reuse it. Initialization is not required. An
optional `compressed_header_scratch` in `Workspace.Options` can replace the
embedded bounded header buffer, not stage the whole compressed stream. The
mutable workspace, optional header scratch, history, output and profile must
be disjoint from one another and from the chunks, descriptor table and
dictionary storage. A borrow refusal writes none of them. Preflight may overwrite history and header/workspace scratch, but a
validation or capacity error leaves decoded output unchanged. Neither pass uses
an allocator; the heap profile excludes these caller-owned buffers.

Because it validates using the progressive history ring, the direct variant
requires nonempty history for nonempty data and enough history for the actual
farthest backward copy, even when the fixed-summary path could skip replaying
that copy. A short ring is `PreflightHistoryTooSmall`. There is no change to
existing contiguous, join-scratch or eager APIs. This path trades a second
progressive pass for removing whole-input staging; it is not a throughput claim.

## Short reads from a ByteSource

The same workspace can read a `SourceRange` from a stable `ByteSource` using
one caller-owned input page. `decodedSourceSize` and `decodedSourcePrefixSize`
measure a full range or its first stream; `decodeSourceInto` and
`decodeSourcePrefixInto` validate first, then replay into the destination.

```zig
const decoded = try workspace.decodeSourcePrefixInto(
    .{ .source = source, .offset = stream_start },
    output,
    input_page,
    .{ .preflight = .{ .history = history_scratch, .max_output_len = limit } },
);
```

`SourceRange.offset` and optional `length` are 64-bit. `decoded.input_read`
counts compressed bytes **relative to that offset**, including validated
padding. The nonempty input page completes short callback reads and respects
`ByteSource.max_read_size`. Preflight can read ahead within the specified
range; replay reads only the measured prefix. No full compressed buffer or
codec allocation is needed.

The input page must be separate from the workspace, optional header scratch,
history, output, dictionary storage and telemetry. The opaque source context
and backing storage must also be independent and stay unchanged across both
passes. Source bounds, borrow and preflight failures do not publish output.
A read failure during replay can leave a plaintext prefix in the destination;
a failed into call does not return usable output or a resume position.

The focused decode-memory contracts cover a valid 65,537-byte copy followed by
a context-selected literal, exactly sufficient and one-byte-short history,
strict/prefix boundaries, output guard bytes, late-block cap refusal, an exact
size mismatch, truncation, borrow checks, eager retry, and zero requested heap.
An upstream reproduction uses the first 1 MiB of Silesia `xml`, compressed by
libbrotli 1.2.0 (`558fc64`) with `BrotliEncoderCompress(6, 22, GENERIC, ...)`:
134,106 compressed bytes, SHA-256
`8d1c3a19071f3778ad30ab49d135e1cce000e7bca38e9eede6031c3850ee04e3`,
and a farthest copy of 987,136 bytes. Caller-history preflight and decode
both measured 1,048,576 bytes with zero requested heap. `size-br-file`
reported the same size at that limit and returned `OutputLimitExceeded` at
1,048,575 bytes. The focused decode-memory gate passed on native, 32-bit
x86 Linux, and executed WASI.

The [wide upstream differential mode](../fuzzing.md) verifies both that
1 MiB reproduction and the entire 5,345,280-byte XML file. With libbrotli
1.2.0 the full-file wire is 506,129 bytes, SHA-256
`803c10dae9fb558b5c4bef96db9870110154a2f8d644ccf917c2056044786091`, and reaches
4,193,998 bytes back. Both XML wires exhaust the legacy fixed history but
pass caller-history preflight with zero requested codec heap, using contiguous
input, compressed chunks, and a 257-byte source page whose callback returns
at most 97 bytes at a time. The chunked tests also
exercise empty chunks, a suffix across transport boundaries, aliased borrows,
short scratch, and failed eager reset followed by a disjoint retry.
Both incremental schedules decode each entire wire and reject its final-byte
cut, publishing only the correct plaintext prefix. The no-download CI smoke
reaches 229,376 bytes back with system libbrotli 1.0.9; it exercises the wide
copy path even though this particular wire also fits the fixed summary logic.
