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

## One-shot encoding

The one-shot encoder uses the incremental encoder's bounded matcher and fixed
block primitives, with distances through 65,536 bytes and matches through
65,538 bytes. Length symbol 285 carries Deflate64's 16-bit extension; length
258 still uses symbol 284 and extra value 31. The encoder borrows input in
128 KiB chunks and each chunk's preceding 65,536 bytes of history. It retains
neither a complete input copy nor a complete token plan.

It first measures a complete fixed-Huffman candidate with checked private
`u128` bit accounting and final-byte padding applied once. Candidate byte cost
stays wide during comparison; only a strict winner converts to `usize` for
allocation. A losing fixed candidate can therefore exceed the target's physical
size range without rejecting a representable stored result. Only a candidate strictly
smaller than the original whole-input stored representation is emitted into an
exact output allocation. Ties and larger fixed candidates use the established
global stored-block encoder, preserving `deflate64EncodedBound` without adding
per-chunk stored overhead. Match-index workspace is allocated and reused for
planning and emission; the returned complete output still belongs to the caller.

`Deflate64EncodeOptions.nice_length` is now `u32`, with its default remaining
128. Values 0...2 preserve stopping after the first eligible match; values above
65,538 return `InvalidBlockPlan` before allocation. Zero `max_chain` disables
matching, while fixed literal blocks may still beat stored output; callers
wanting explicit no-compression output should use the stored APIs.
`encodeDeflate64StoredAlloc`, `encodeDeflate64StoredAppend`, and
`encodeDeflate64StoredInto` provide an explicit no-compression path;
`deflate64EncodedBound` covers both modes.

`encodeDeflate64Into` and `encodeDeflate64Append` finish encoding before writing
or growing caller output. Too-small output, allocation failure and overlapping
input/output retain the established atomicity rules. Adaptive one-shot bytes
may change with the broader matcher and block construction; stored APIs keep
their established bytes. Incremental strategies, options and input limits are
unchanged by this one-shot reuse.

The [one-shot functional baseline](../performance/deflate64-one-shot-functional-baseline.md)
records final native Debug, native ReleaseFast and x86 codec contracts at
99/99, the complete ZIP suite at 1992/1992, build checks at 176/176 and CLI help
at 7/7 on stable source after the wide-cost correction. Native and x86 external
campaigns each verify 48 artifacts, 64 member plaintexts and 90 recorded
commands. Their complete input/wire/progress manifests match across targets and
the initial candidate; the private cost widening does not alter those outputs.

At the same default settings, repeated 65,539-byte input shrinks from 576 to
6 encoded bytes, and a 64 KiB random prefix plus its duplicate shrinks from
131,087 to 69,098. This does not establish a broad memory win: the separately
recorded total allocator requests for Tiny16 rise from 131,379 to 393,234 bytes,
and Pattern12079 rises from 205,181 to 393,269 bytes. These are cumulative
requests from the size/allocation probe, not peak memory or RSS, and were not
retraced on the final cost-only revision. Final external wires match that probe.
No competitor throughput or all-corpus compression-quality lead is claimed.

ZIP writing accepts `.method = .deflate64`, records version-needed 2.1 (or 4.5
for ZIP64), and uses the same encoder. The differential suite generates method
9 archives in both directions with 7-Zip, including a large duplicated region
intended to exercise references beyond the ordinary 32 KiB Deflate window:

```sh
zig build run-zip-diff
```

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
