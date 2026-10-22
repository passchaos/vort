# LZMA-Alone and MicroLZMA support

Vort provides dependency-free encoding and decoding for the legacy `.lzma` /
LZMA-Alone format. It parses and emits the 13-byte properties header, validates
`lc`/`lp`/`pb`, normalizes the minimum dictionary size, and supports both
declared and unknown (`0xffffffffffffffff`) uncompressed sizes. The encoder
uses bounded greedy or one-byte-lookahead lazy match finding, new/repeated
distance coding, and the normal LZMA range-coded literal contexts.

```zig
const header = try vort.parseLzmaHeader(compressed);
const decoded = try vort.decodeLzmaAllocWithOptions(allocator, compressed, .{
    .max_output_len = 256 * 1024 * 1024,
    .max_dictionary_size = 64 * 1024 * 1024,
});
defer allocator.free(decoded);

const encoded = try vort.encodeLzmaAlloc(allocator, input, .{
    .dictionary_size = 32 * 1024,
    .mode = .lazy, // .greedy remains the default
    .size_mode = .end_marker,
});
defer allocator.free(encoded);
```

`LzmaIncrementalDecoder` is a true symbol-progressive LZMA-Alone surface. It
keeps the range decoder, probability model, and circular dictionary alive
across calls while retaining only a bounded compressed lookahead and one
committed literal/match of pending output:

```zig
var decoder = vort.LzmaIncrementalDecoder.initWithOptions(allocator, .{
    .max_output_len = 256 * 1024 * 1024,
    .max_dictionary_size = 64 * 1024 * 1024,
    .max_compressed_buffer_len = 1024 * 1024,
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
decoder.finish();
while (true) {
    const result = try decoder.step("", output[output_offset..]);
    output_offset += result.progress.output_written;
    if (result.status == .done) break;
}
```

Available APIs:

- `parseLzmaHeader`;
- `decodeLzmaInto`;
- `decodeLzmaAlloc` and `decodeLzmaAllocLimited`;
- `decodeLzmaAllocWithOptions` for independent output and dictionary limits;
- `lzmaDecodedSize` and `lzmaDecodedSizeLimited`;
- `LzmaIncrementalDecoder` for fragmented caller input/output, resettable
  state, snapshots, diagnostics, and exact output pledges;
- `encodeLzmaAlloc`, `encodeLzmaInto`, and transactional `encodeLzmaAppend`;
- known-size and end-marker writer modes with configurable LZMA properties,
  bounded dictionaries, and greedy/lazy one-shot parsing.

ZIP method 14 uses a related raw LZMA payload with a ZIP-specific properties
prefix and mandatory end marker. Vort reads and writes those entries through
the ZIP APIs; `ZipEncodeOptions.lzma_options` selects the properties,
dictionary size, and parser mode. Allocating ZIP extraction APIs work directly;
caller-owned extraction must use
`zipExtractEntryIntoWithAllocator` so dictionary scratch remains explicit.

MicroLZMA is a distinct raw format used by EROFS. Its first byte is the bitwise
inverse of the usual `lc`/`lp`/`pb` property byte and replaces raw LZMA's leading
zero range-coder byte. It has neither a dictionary-size field nor an end marker,
so callers must provide the exact decoded size and dictionary limit out of
band. Vort verifies the final range state and requires every compressed byte to
be consumed; it does not treat LZMA-Alone bytes as MicroLZMA.

`encodeMicroLzmaAlloc`, `encodeMicroLzmaAppend`, and `encodeMicroLzmaInto`
encode a complete stream using `MicroLzmaEncodeOptions`. The default is a
32 KiB dictionary with lc/lp/pb = 3/0/2 and greedy matching. Dictionaries from
4 KiB through 64 MiB and literal-only, greedy, or lazy modes are supported;
lc/lp/pb must satisfy lc + lp <= 4 and pb <= 4. The append and caller-buffer
APIs preserve destination bytes on error.

`encodeMicroLzmaDestSizeAlloc` and `encodeMicroLzmaDestSizeInto` encode a
terminated input prefix within a caller-selected capacity. The allocating
result owns `bytes` and reports `consumed`; the caller-buffer result reports
`written` and `consumed`. Both require at least six destination bytes, even
for empty input, and guarantee progress for non-empty input. A symbol is
accepted only when its range state plus final flush fits; the first rejected
symbol is discarded. Increasing capacity cannot reduce the consumed prefix
for the same input/options. Sufficient capacity preserves the complete-stream
wire. Parser choices and consumed lengths need not match XZ Utils' presets.
These are independent one-shot streams, with size and dictionary metadata
still provided by the enclosing format. Greedy/lazy modes currently plan the
complete input before applying the range budget; scratch memory therefore
depends on input size rather than destination capacity alone.

```zig
const encoded_micro = try vort.encodeMicroLzmaAlloc(allocator, input, .{
    .dictionary_size = 128 * 1024,
    .mode = .lazy,
});
defer allocator.free(encoded_micro);

var prefix = try vort.encodeMicroLzmaDestSizeAlloc(allocator, input, 4096, .{});
defer prefix.deinit(allocator);
// prefix.bytes represents exactly input[0..prefix.consumed].

const decoded = try vort.decodeMicroLzmaAllocLimited(
    allocator,
    compressed,
    exact_decoded_size,
    dictionary_size,
    max_output,
);
defer allocator.free(decoded);
```

The TAR composition layer also reads and writes `.tar.lzma` / `.tlz` archives
through the same LZMA-Alone codec. Automatic detection accounts for the
format's lack of magic by preferring a structurally valid raw TAR and requiring
TAR-aligned declared output size (or the unknown-size marker) in the LZMA
header.

CLI validation surfaces:

```sh
zig build run -- encode-lzma-file input.bin output.lzma end-marker
zig build run -- decode-lzma-file input.lzma output.bin 268435456 67108864
zig build run -- size-lzma-file input.lzma 268435456
zig build run -- encode-microlzma-file input.bin output.microlzma 32768
zig build run -- encode-microlzma-prefix-file input.bin prefix.microlzma 4096 32768
zig build run -- decode-microlzma-file input.microlzma output.bin 1048576 32768
zig build test-microlzma
zig build run-microlzma-diff
zig build run-lzma-diff
zig build run-zip-diff
```

The MicroLZMA differential driver compares Vort and XZ Utils in both
directions across empty/tiny/repetitive/mixed/source data, independent
properties, and a repeated suffix beyond 80 KiB. Every encoder mode is decoded
with XZ Utils, with exact output and compressed-input accounting. Focused
tests also cover transactional output, invalid options, dictionary bounds,
and exhaustive allocation failures for narrow greedy and wide lazy paths.
The capacity matrix additionally validates 186 Vort prefixes with XZ Utils
and 62 XZ Utils prefixes with Vort, including six-byte destinations, partial
input, complete input, all modes/properties, and exact consumed/written
accounting. Unit tests sweep every capacity from 6 through 96 and verify
monotonic progress, untouched destination tails, and every allocation failure.

LZMA-Alone does not carry an integrity checksum. Known-size streams are checked
against their declared output size, while unknown-size streams require the
range-coder end marker. Applications that require corruption detection should
use XZ or a checksummed container such as ZIP. The current encoder offers
bounded greedy and lazy parsers. Its wide-distance lazy path augments length
gains with a gated static literal/length/distance price; adaptive probability
and repeat-state pricing plus deeper optimal parsing remain future ratio work.
The decoder's
local circular dictionary keeps lookbehind validation tied to the declared
window while safely handling outputs larger than that window.

The incremental decoder preserves the same distinction: unknown-size streams
must reach an end marker and reject any following bytes, while known-size
streams complete after the declared output and retain the existing
LZMA-Alone behavior of accepting range-coder tail bytes until the caller calls
`finish`. Before a non-final symbol is executed, at least 64 compressed bytes
are staged. This bound exceeds the maximum flags, length tree, distance slot,
direct distance, and align bits consumed by one LZMA symbol, preventing a split
input from partially mutating the probability model. Final short tails are
processed only after `finish`, when input exhaustion can be reported exactly.

`LzmaIncrementalEncoder` provides the symmetric symbol-progressive writer. It
retains the range coder, probability model, recent distances, a bounded
dictionary, and at least one complete 258-byte greedy lookahead window across
calls. A persistent absolute-position hash chain uses the same insertion and
candidate order as the one-shot planner, so caller fragmentation does not
change greedy tokens or wire bytes.

```zig
var encoder = try vort.LzmaIncrementalEncoder.initExactSize(allocator, .{
    .properties = .{ .lc = 3, .lp = 0, .pb = 2 },
    .dictionary_size = 32 * 1024,
    .mode = .greedy, // or .literal_only
    .size_mode = .end_marker, // .known requires initExactSize
    .input_buffer_len = 64 * 1024,
    .max_input_len = 256 * 1024 * 1024,
    .max_pending_output_len = 1024 * 1024,
}, input.len);
defer encoder.deinit();
```

The encoder supports unknown-size end-marker streams, pledged end-marker or
known-size streams, zero-output backpressure, input/output limits, resettable
retained input/history/token/output scratch, and detailed token counters.
This symbol-progressive API supports literal-only and greedy modes. Lazy mode
is one-shot-only because arbitrary caller splits cannot guarantee its required
next-byte lookahead without changing backpressure semantics.
LZMA-Alone has no block-level sync-flush marker and no standardized
concatenation boundary, so this API intentionally exposes `finish` and `reset`
but not a misleading flush/next-stream operation. A 40,000-byte repeated
binary corpus crosses both multiple 1 KiB planning windows and the 32 KiB
dictionary ring while matching one-shot greedy bytes under one-byte input and
seven-byte output; literal-only known-size output is independently byte-exact.
