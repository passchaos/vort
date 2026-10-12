# LZOP and LZO1X support

Vort provides a pure Zig LZO1X encoder/decoder and an LZOP container
implementation.
The reader accepts LZO1X-1, LZO1X-1(15), and LZO1X-999 blocks, along with raw
blocks used when compression is not beneficial. Concatenated LZOP streams are
decoded in order.

The container validates:

- the nine-byte LZOP magic and version compatibility fields;
- Adler-32 or CRC-32 header checksums, variable filenames, and extra fields;
- block sizes up to the format's 64 MiB ceiling and caller-selected limits;
- compressed and uncompressed block checksums when present;
- exact LZO1X end markers, input consumption, output size, lookbehind offsets,
  and extended run lengths;
- legacy LZOP delta filters 1 through 16.

```zig
const decoded = try vort.decodeLzopAllocWithOptions(allocator, compressed, .{
    .max_output_len = 256 * 1024 * 1024,
    .max_block_size = 16 * 1024 * 1024,
});
defer allocator.free(decoded);

const compressed = try vort.encodeLzopAlloc(allocator, input, .{
    .block_size = 256 * 1024,
    .checksum = .crc32,
    .compressed_checksum = true,
});
defer allocator.free(compressed);
```

Available APIs include standalone LZO1X alloc/append/into encoding and
caller-owned decoding, LZOP header parsing and inspection, caller-owned and
bounded allocating decode, decoded-size preflight, deterministic
compressed-or-stored alloc/append/into encoding, and explicit stored-only
writer variants. `LzopIncrementalDecoder` adds a true block-bounded streaming
surface: it accepts arbitrary compressed-input splits, drains through arbitrary
caller output (including zero-byte backpressure), walks concatenated streams,
and exposes resettable snapshots and diagnostics. The writer accepts blocks up
to 256 KiB so its output is readable by default lzop installations.

```zig
var decoder = vort.LzopIncrementalDecoder.initWithOptions(allocator, .{
    .max_output_len = 256 * 1024 * 1024,
    .max_block_size = 16 * 1024 * 1024,
    .max_header_len = 1024 * 1024,
    .expected_output_len = expected_size,
});
defer decoder.deinit();

var input_offset: usize = 0;
var output_offset: usize = 0;
while (input_offset < compressed.len) {
    const result = try decoder.step(
        compressed[input_offset..],
        output[output_offset..],
    );
    input_offset += result.progress.input_read;
    output_offset += result.progress.output_written;
}
try decoder.finish();
```

The incremental decoder retains at most one encoded block and one decoded
block. It validates compressed-payload checksums before decompression, then
reverses any delta filter and validates decoded-data checksums before exposing
the first byte of that block. A terminal zero block is mandatory before
`finish`; partial headers, checksum fields, payloads, and terminators report
`TruncatedFrame` with streaming diagnostics.

`LzopIncrementalEncoder` provides the matching block-bounded writer. It
supports the normal per-block compressed-or-stored choice and an explicit
stored-only mode, reusing the exact one-shot header, block checksum, compressed
checksum, and terminal-zero writers. Without `flush`, output is independent of
caller fragmentation and matches one-shot bytes exactly.

```zig
var encoder = try vort.LzopIncrementalEncoder.initExactSize(allocator, .{
    .block_size = 256 * 1024,
    .checksum = .crc32,
    .compressed_checksum = true,
    .header_checksum = .crc32,
    .filename = "payload.bin",
    .payload_mode = .compressed_or_stored, // or .stored
    .max_input_len = 256 * 1024 * 1024,
    .max_pending_output_len = 1024 * 1024,
    .max_block_count = 1024 * 1024,
}, input.len);
defer encoder.deinit();
```

The caller keeps filename metadata alive until the stream finishes. Idempotent
`flush` closes the current LZOP block, `finish` writes the terminal zero block,
and `nextStream`/`nextStreamExactSize` continue concatenated streams with new
metadata, checksum, block-size, or payload-mode options. Reset retains plain,
LZO, and encoded scratch capacities; max/pledged input, pending-output, block
count, and zero-output backpressure remain explicit.

CLI validation surfaces:

```sh
zig build run -- encode-lzop-file input.bin output.lzo 262144 crc32 compressed-checksum
zig build run -- encode-lzop-stored-file input.bin output.lzo 262144 crc32
zig build run -- decode-lzop-file input.lzo output.bin 268435456 67108864
zig build run -- size-lzop-file input.lzo 268435456 67108864
zig build run -- inspect-lzop-file input.lzo
zig build run-lzop-diff
```

The writer uses bounded greedy LZO1X matching with the complete 48 KiB match
distance range, then independently falls back to stored representation for any
block that would not shrink. Data and optional compressed-payload checksums may
use Adler-32 or CRC-32. The TAR composition layer uses the same adaptive writer
and decoder for `.tar.lzo` and `.tzo` archives. Deeper match planning remains
future ratio work.
