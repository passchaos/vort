# XZ and LZMA2 support

Vort provides dependency-free XZ decoding for LZMA2 streams with optional
Delta and x86, PowerPC, IA-64, ARM, ARM-Thumb, SPARC, ARM64, or RISC-V BCJ
preprocessing filters. Its deterministic writer emits LZMA2 chunks with greedy LZ77 matches,
repeat-distance coding, literal context coding, a stored fallback, and a
caller-selected 4 KiB...65,535-byte dictionary retained across chunk
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
    .dictionary_size = 32 * 1024,
    .filters = &filter_chain,
});
defer allocator.free(encoded);
```

`XzIncrementalDecoder` exposes the same validation through a caller-driven,
block-bounded state machine. It retains only the current compressed block or
Index/Footer candidate plus one check-validated decoded block, rather than
joining a complete multi-block or concatenated stream:

```zig
var decoder = vort.XzIncrementalDecoder.initWithOptions(allocator, .{
    .max_output_len = 256 * 1024 * 1024,
    .max_dictionary_size = 64 * 1024 * 1024,
    .max_compressed_block_len = 64 * 1024 * 1024,
    .max_decoded_block_len = 64 * 1024 * 1024,
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
preflight, explicit concatenated-stream variants, and block-bounded incremental
decode with snapshots and phase diagnostics.
The compressed and stored writers provide alloc, transactional append, and
caller-owned output APIs.

The incremental decoder verifies the stream and block headers before accepting
payload limits, applies Delta/BCJ filters only after complete LZMA2 decode, and
publishes a block only after its none/CRC-32/CRC-64/SHA-256 check succeeds.
Index records, Index CRC, Footer CRC/backward size/flags/magic, four-byte stream
padding, and concatenated stream headers are then validated incrementally.
Incomplete block and Index candidates are retried at exponentially growing
input thresholds so one-byte fragmentation does not trigger a full reparse on
every byte.

Transient Zig 0.16 LZMA2 state is owned by a per-block arena. This avoids a
standard-library partial-reset double-free when probability-table allocation
fails, while preserving caller allocator accounting and deterministic cleanup.
Decoded output is copied out of that arena only after the complete block check
passes.

`XzIncrementalEncoder` provides the symmetric block-bounded writer for both
compressed and explicitly stored LZMA2 payloads. It reuses the one-shot stream
header, block, check, Index, and Footer writers, so omitting `flush` yields the
same wire regardless of caller input/output fragmentation.

```zig
var encoder = try vort.XzIncrementalEncoder.initExactSize(allocator, .{
    .check = .sha256,
    .block_size = 1024 * 1024,
    .dictionary_size = 32 * 1024,
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
zig build run -- encode-xz-file input.bin output-32k.xz crc64 1048576 none 32768
zig build run -- encode-xz-stored-file input.bin output.xz crc64 1048576 x86,delta:4
zig build run -- encode-xz-file input.bin output.xz crc64 1048576 arm64:4096
zig build run -- encode-xz-file input.bin output.xz crc64 1048576 riscv:4096
zig build run -- decode-xz-file input.xz output.bin 268435456
zig build run -- decode-xz-concat-file streams.xz output.bin 268435456
zig build run -- size-xz-file input.xz 268435456
zig build run -- inspect-xz-file input.xz
zig build run-xz-diff
```

The reader and writer support Delta plus all eight XZ BCJ filters. Filter
chains may contain up to three preprocessing filters followed by LZMA2, and
BCJ start offsets are checked for their architecture's alignment. The current
ARM64 transform covers BL and ADRP instructions; the RISC-V transform covers
JAL plus the canonical AUIPC/JALR address pairs. Vort output is validated by
7-Zip 26.02 because the locally installed XZ 5.2/Python binding predates these
two filter IDs. The current compressor uses bounded greedy match finding. Each
compressed chunk resets its LZMA probability state and properties while
retaining the configured preceding dictionary. Requests from 4 KiB through
65,535 bytes are encoded with the smallest covering LZMA2 property, so decoder
memory is rounded to one of 4/6/8/12/16/24/32/48/64 KiB while match distance
never exceeds the caller's requested bound.
Stored fallbacks likewise retain history: the first chunk uses dictionary-reset
control `1` or `0xe0`, while later stored/compressed chunks use `2` or `0xc0`.
This lets a match cross a 64 KiB chunk boundary without making chunks dependent
on hidden state outside their XZ block. Deeper parsing and a wider-distance
LZMA matcher remain later ratio and performance work.
