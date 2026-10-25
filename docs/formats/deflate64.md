# Deflate64 support

Vort provides dependency-free Deflate64 encoding and decoding for raw streams
and ZIP method 9 entries. Deflate64 retains the stored, fixed-Huffman, and
dynamic-Huffman block structure of Deflate while extending the history window
and match lengths.

The decoder implements and validates:

- stored, fixed-Huffman, and dynamic-Huffman blocks;
- all 32 distance symbols and distances through 65,536 bytes;
- length code 285 with its 16-bit extension, producing lengths through 65,538;
- dynamic code-length repeats and mandatory end-of-block symbols;
- exact input consumption in allocating APIs and ZIP extraction;
- caller-provided output capacity and allocating output limits.

```zig
const decoded = try vort.decodeDeflate64AllocLimited(
    allocator,
    compressed,
    256 * 1024 * 1024,
);
defer allocator.free(decoded);

const encoded = try vort.encodeDeflate64Alloc(allocator, input, .{});
defer allocator.free(encoded);
```

ZIP method 9 extraction uses `decodeDeflate64Into` directly and therefore does
not require temporary allocation beyond the caller's ZIP output buffer. CRC-32
and declared uncompressed size are still verified by the ZIP container layer.

The one-shot encoder uses a bounded greedy matcher and chooses the smaller of
a fixed-Huffman stream and stored blocks. It emits distance codes 30 and 31 for
matches beyond the ordinary 32 KiB Deflate window. Because Deflate64 assigns a
16-bit extension to length symbol 285, the encoder represents a 258-byte match
with symbol 284 instead of emitting ordinary Deflate's incompatible code 285.
`encodeDeflate64StoredAlloc`, `encodeDeflate64StoredAppend`, and
`encodeDeflate64StoredInto` provide an explicit no-compression path;
`deflate64EncodedBound` covers both modes.

ZIP writing accepts `.method = .deflate64`, records version-needed 2.1 (or 4.5
for ZIP64), and uses the same encoder. The differential suite generates method
9 archives in both directions with 7-Zip, including a large duplicated region
intended to exercise references beyond the ordinary 32 KiB Deflate window:

```sh
zig build run-zip-diff
```

The one-shot encoder still limits matches to 258 bytes and distances to 65,535.
The incremental compressed encoder below covers the full Deflate64 match range.

## Incremental compressed encoding

`Deflate64IncrementalEncoder` accepts caller input and drains encoded bytes into
caller output. The default `.adaptive` strategy compares exact fixed-Huffman
and stored-block costs, retaining the smaller representation. `.fixed` and
`.stored` select explicit strategies. All three keep continuous bit packing
until finish, and retain at most the last 65,536 bytes of history across blocks.
The previous `Deflate64IncrementalStoredEncoder` remains available with its
existing stored-only behavior.

```zig
var encoder = vort.Deflate64IncrementalEncoder.initWithOptions(allocator, .{
    .block_len = 128 * 1024,
    .compression = .adaptive,
    .max_input_len = 64 * 1024 * 1024,
    .max_pending_output_len = 128 * 1024 + 16,
});
defer encoder.deinit();
const result = try encoder.step(input, output);
// Advance input/output by result.progress before the next call.
// After all input is accepted, request finish and drain step("", output)
// until result.status is .done.
```

`init`, `initWithOptions` and `initExactSize` create explicit state without
allocating. Owned block, history, output and hash-index storage grows lazily;
block size is checked in 1...128 KiB. The matcher uses block-local coordinates
and emits actual distances through 65,536 and lengths through 65,538. Code 285
carries the full 16-bit extension; length 258 retains code 284 with extra value
31. Stored alternatives split at 65,535-byte boundaries. Their output overhead
is based on the actual chosen block segmentation, not the one-shot
`deflate64EncodedBound` formula.

`max_chain` and `nice_length` bound search work; zero chain depth produces
literals without matching. The input limit and optional pledged size check the
entire offered slice before draining or accepting bytes. The pending-output
limit charges complete bytes retained for one emission event, including final
padding. Neither limit is a process RSS limit. Reset retains prior capacities.

Block flush preserves history without alignment; partial flush emits an empty
fixed block; sync flush emits an empty stored byte boundary. Full flush uses
that boundary and clears match history. Repeated flush requests do not duplicate
the same completed boundary. Finish emits BFINAL once after the input pledge
matches and pending output drains.

All step errors are sticky until reset. `failedProgress()` preserves the first
failed call's accepted input and delivered output, including a prefix delivered
before a later allocation or quota failure. Later calls return the same error
without touching caller buffers. `reset`, `resetWithOptions` and
`resetExactSize` permit explicit reuse; `snapshot()` is diagnostic state and
does not provide a checkpoint or clone.

ZIP's incremental writer uses this compressed encoder for method 9, including
known/unknown lengths, descriptors, ZIP32/ZIP64 and existing encryption adapters.
Its default Deflate64 planning block changes from 65,535-byte stored-only blocks
to 128 KiB adaptive blocks. Explicit smaller block settings remain supported.

The [functional baseline](../performance/deflate64-stream-functional-baseline.md)
records independent token parsing, Info-ZIP decoding and bounded ownership.
Dynamic-Huffman planning, preset dictionaries and complete ratio/speed/memory
leadership remain future work.
