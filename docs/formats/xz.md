# XZ and LZMA2 support

Vort provides dependency-free XZ decoding for LZMA2 streams with optional
Delta and x86, PowerPC, IA-64, ARM, ARM-Thumb, SPARC, ARM64, or RISC-V BCJ
preprocessing filters. Its deterministic writer emits LZMA2 chunks with greedy LZ77 matches,
repeat-distance coding, literal context coding, a stored fallback, and a
caller-selected 4 KiB...64 MiB dictionary retained across chunk
boundaries. The
explicit stored writer remains available, and both paths can apply the same
filter chains.

The container implementation validates:

- stream magic, flags, header CRC-32, footer CRC-32, backward size, and footer
  magic;
- block headers, canonical variable-length integers, LZMA2 filter properties,
  ordered filter chains, declared packed/unpacked sizes, and zero padding;
- Index record count, per-block unpadded/uncompressed sizes, and Index CRC-32;
- block checks `none`, CRC-32, CRC-64/XZ, and SHA-256.

Normal multi-block streams and concatenated streams with four-byte-aligned
stream padding are supported. `StreamInfo` reports the check type, block count,
compressed and uncompressed sizes, and largest declared LZMA2 dictionary. It
also reports aggregate and per-architecture filter block counts.

```zig
const info = try vort.inspectXz(allocator, compressed);
const decoded = try vort.decodeXzAllocLimited(
    allocator,
    compressed,
    256 * 1024 * 1024,
);
defer allocator.free(decoded);

const tightly_bounded = try vort.decodeXzAllocWithLimits(
    allocator,
    compressed,
    256 * 1024 * 1024,
    64 * 1024 * 1024,
);
defer allocator.free(tightly_bounded);

const filter_chain = [_]vort.XzFilter{
    vort.XzFilter.x86(0),
    try vort.XzFilter.delta(4),
};
const encoded = try vort.encodeXzAlloc(allocator, input, .{
    .check = .crc64,
    .block_size = 1024 * 1024,
    .dictionary_size = 128 * 1024,
    .filters = &filter_chain,
});
defer allocator.free(encoded);

const ratio_encoded = try vort.encodeXzLazyAlloc(allocator, input, .{
    .check = .crc64,
    .block_size = 1024 * 1024,
    .dictionary_size = 128 * 1024,
    .filters = &filter_chain,
});
defer allocator.free(ratio_encoded);
```

`XzIncrementalDecoder` exposes the same format validation through a
caller-driven state machine. Its default `Options.input_policy` is
`.progressive_block`: LZMA2 range symbols advance through bounded input, inverse
filters retain only their required suffixes, and decoded output can be
published before the block is complete. Unfiltered blocks write into caller
output directly. `.prevalidated_block` retains the complete decoded block until
its check succeeds and uses the same bounded encoded-symbol input.

```zig
var decoder = vort.XzIncrementalDecoder.initWithOptions(allocator, .{
    .max_output_len = 256 * 1024 * 1024,
    .max_dictionary_size = 64 * 1024 * 1024,
    .max_compressed_block_len = 64 * 1024 * 1024,
    .max_decoded_block_len = 64 * 1024 * 1024,
    .max_compressed_buffer_len = 128 * 1024,
    .max_decoded_buffer_len = 4096,
    .max_working_memory = 128 * 1024 * 1024,
    .max_index_footer_len = 16 * 1024 * 1024,
    .max_block_count = 1024 * 1024,
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

Available decoding forms include caller-owned output, bounded allocation,
separate decoded-output and LZMA2-dictionary limits, validated decoded-size
preflight, explicit concatenated-stream variants, and progressive incremental
decode with snapshots and phase diagnostics.
The compressed and stored writers provide alloc, transactional append, and
caller-owned output APIs.

Stream and block headers validate before payload decoding. Default LZMA2 input
uses a conservative 64-byte range-symbol guard and fixed staging for one
literal/match of at most 273 bytes. It does not collect an entire compressed
chunk or decoded XZ block before output. Delta and BCJ stages apply in inverse
chain order, including their final suffix flush. The selected none/CRC-32/
CRC-64/SHA-256 check is accumulated over final decoded bytes; a late block check
failure can follow already-published output. `validated_output` advances only
when the complete block check succeeds, while `output_written` reports bytes
already delivered to the caller.

Index records, Index CRC, Footer CRC/backward size/flags/magic, stream padding
and following stream headers retain strict validation. Explicit
`.prevalidated_block` keeps check-before-output behavior. Its decoded storage is
bounded by the configured decoded-buffer, decoded-block and working-memory
limits. The decoded-buffer cap covers live requested allocations for filter
suffix/work buffers and publication staging, including a withheld complete
decoded block. It defaults to unlimited, while the progressive execution window
remains structurally small.

`max_output_len` bounds cumulative logical output, including concatenated or
explicitly resumed streams. Block limits remain independent of retained-buffer
limits. `max_working_memory` bounds live requested allocations across the
container, LZMA2 probabilities/history, filters, records and temporary decode
storage. It excludes caller buffers, fixed state, stack staging and allocator
bookkeeping. Budget rejection reports `WorkingMemoryLimitExceeded`; backing
allocator failure reports `OutOfMemory`.

On `step` failure, `snapshot().last_step_progress` records input accepted and
output published during that call, with global detection offsets. Fatal errors
are sticky until reset. Advance caller input/output by those deltas before
handling the error. `reset()` retains reusable storage and resets operation
counters; `resetWithOptions()` validates new settings and releases old owned
buffers on successful reconfiguration. Its existing void signature records an
invalid configuration for the next `step`; callers can use `Options.validate()`
first when they need an immediate result.

`stop_after_first_stream` stops after validated Index/Footer. Preserve both
`trailingInput()` and the unconsumed caller-input suffix. `nextStream()` resumes
that boundary while retaining cumulative output limits, counters and allocation
peak. The exact output pledge may span multiple stopped streams. `finish()`
declares input EOF; remaining output and terminal validation drain through
`step("", output)`.

An active decoder value can be moved while retaining single ownership; discard
the old value. Stateful methods rebind nested allocator callbacks before
processing or releasing owned storage.

`RawLzma2IncrementalDecoder` exposes the same symbol-progressive core to
containers carrying `dictionary_property` out of band. It retains at most the
configured compressed guard and one fixed 273-byte decoded symbol, alongside
the bounded dictionary and probability state. Its default guard cap is 64
bytes; stored chunks also work with a compressed-buffer cap of zero.
`stop_after_end_marker` stops at LZMA2 control byte zero without accepting the
following container bytes. The default instead rejects trailing input. Raw
snapshots expose actual input/output progress and live/peak working allocation;
`resetWithOptions()` returns errors directly after validating new settings.

`XzIncrementalEncoder` provides the symmetric block-bounded writer for both
compressed and explicitly stored LZMA2 payloads. It reuses the one-shot stream
header, block, check, Index, and Footer writers, so omitting `flush` yields the
same wire regardless of caller input/output fragmentation.

`RawLzma2IncrementalEncoder` is the lower-level payload writer used by 7z and
other containers. Its fixed 64 KiB chunks retain the standard 4 KiB preceding
dictionary, LZMA probability model, recent distances, and property state across
boundaries. Compressed continuations therefore use control `0x80`; a stored
fallback retains dictionary bytes and makes the next compressed chunk use the
appropriate state reset without resending unchanged properties. Its output is
byte-exact with the one-shot raw LZMA2 writer for identical input and is
independent of caller fragmentation.

```zig
var encoder = try vort.XzIncrementalEncoder.initExactSize(allocator, .{
    .check = .sha256,
    .block_size = 1024 * 1024,
    .dictionary_size = 128 * 1024,
    .filters = &filter_chain,
    .payload_encoding = .compressed, // or .stored
    .max_input_len = 256 * 1024 * 1024,
    .max_pending_output_len = 16 * 1024 * 1024,
    .max_block_count = 1024 * 1024,
}, input.len);
defer encoder.deinit();

// step() accepts plaintext and drains XZ bytes through caller output.
// flush() closes the current block; finish() emits Index and Footer.
```

The caller keeps the filter slice alive until the stream finishes. The encoder
supports idempotent flush, resettable retained scratch, unknown or pledged
input sizes, zero-output backpressure, pending-output/block-count limits, and
`nextStream`/`nextStreamExactSize` concatenated continuation. Explicit flush
intentionally changes block boundaries; without it, compressed SHA-256 plus
x86/delta and stored CRC-32 fixtures are required to match their corresponding
one-shot streams byte-for-byte under tiny input/output splits.

CLI validation surfaces:

```sh
zig build run -- encode-xz-file input.bin output.xz crc64 1048576 x86,delta:4
zig build run -- encode-xz-file input.bin output-128k.xz crc64 1048576 none 131072
zig build run -- encode-xz-file input.bin output-lazy.xz crc64 1048576 none 131072 lazy
zig build run -- encode-xz-stored-file input.bin output.xz crc64 1048576 x86,delta:4
zig build run -- encode-xz-file input.bin output.xz crc64 1048576 arm64:4096
zig build run -- encode-xz-file input.bin output.xz crc64 1048576 riscv:4096
zig build run -- decode-xz-file input.xz output.bin 268435456
zig build run -- decode-xz-concat-file streams.xz output.bin 268435456
zig build run -- size-xz-file input.xz 268435456
zig build run -- inspect-xz-file input.xz
zig build run-xz-diff
zig build test-xz test-xz-progressive -Doptimize=ReleaseFast
zig build test-xz-consumers -Doptimize=ReleaseFast
zig build run-xz-progressive-diff -Doptimize=ReleaseFast -- \
  --seven-zip /path/to/modern/7zz --report /tmp/xz-progressive.json
zig build -Doptimize=ReleaseFast run-xz-encode-bench-gate
zig build run-lzma2-incremental-report -- 3
```

The raw incremental report compares persistent state with the former
dictionary-reset-per-chunk behavior on a deterministic 256 KiB boundary-repeat
corpus. On an Intel Core i7-10700K, ReleaseFast, five iterations, the persistent
wire is 252,525 bytes versus 262,157 bytes (9,632 bytes smaller), at 12.18 MiB/s
versus 12.60 MiB/s. The report fails if persistent state does not improve size;
throughput is reported rather than gated because the persistent path performs
useful match/range coding where the reset baseline falls back to stored chunks.

The reader and writer support Delta plus all eight XZ BCJ filters. Filter
chains may contain up to three preprocessing filters followed by LZMA2, and
BCJ start offsets are checked for their architecture's alignment. The current
ARM64 transform covers BL and ADRP instructions; the RISC-V transform covers
JAL plus the canonical AUIPC/JALR address pairs. Vort output is validated by
7-Zip 26.02 because the locally installed XZ 5.2/Python binding predates these
two filter IDs. The current compressor uses bounded greedy match finding. Each
compressed chunk resets its LZMA probability state and properties while
retaining the configured preceding dictionary. Requests from 4 KiB through
64 MiB are encoded with the smallest covering LZMA2 property from 0 through
28, including the common 1.5/2/3/4/6/8/12/16/24/32/48/64 MiB tiers; match
distance never exceeds the caller's requested bound. The public
`xzMaxEncodeDictionarySize` constant exposes this encoder ceiling.
Requests above
65,535 bytes select a dedicated LZMA `u32`-distance hash-chain planner; the
shared LZ77 token and all other codecs retain their compact u16 distance. One
block-local hash state advances across every compressed or stored 64 KiB chunk,
so history positions are indexed once rather than rebuilt for each chunk.
Stored fallbacks likewise retain history: the first chunk uses dictionary-reset
control `1` or `0xe0`, while later stored/compressed chunks use `2` or `0xc0`.
Consecutive compressed chunks also retain LZMA probability state and recent
distances through control `0x80`; after a stored fallback, control `0xa0`
resets that state without redundantly resending unchanged properties.
The public lazy APIs add one-byte lookahead for callers prioritizing ratio;
incremental XZ selects the same path with `.parser = .lazy`, while greedy stays
the default. Symbol-progressive LZMA-Alone incremental encoding deliberately
rejects lazy mode because it cannot promise the required next byte at every
caller split.
For wide dictionaries, lazy parsing preserves one-byte length gains and also
uses a gated static LZMA cost estimate for far-current/near-next matches. The
estimate covers literal, length-tree, distance-slot, and direct-distance bit
shapes, but intentionally does not claim to track adaptive range probabilities
or repeat-distance state.
This lets a match cross a 64 KiB chunk boundary without making chunks dependent
on hidden state outside their XZ block. Adaptive price modeling and deeper
optimal parsing remain later ratio and performance work.

Progress, allocation, compatibility and error evidence for the progressive
decoder is recorded in
[the functional baseline](../performance/xz-progressive-functional-baseline.md).
