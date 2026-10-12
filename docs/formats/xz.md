# XZ and LZMA2 support

Vort provides dependency-free XZ decoding for LZMA2 streams with optional
Delta and x86, PowerPC, IA-64, ARM, ARM-Thumb, SPARC, ARM64, or RISC-V BCJ
preprocessing filters. Its deterministic writer emits LZMA2 chunks with greedy LZ77 matches,
repeat-distance coding, literal context coding, and a stored fallback. The
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

CLI validation surfaces:

```sh
zig build run -- encode-xz-file input.bin output.xz crc64 1048576 x86,delta:4
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
two filter IDs. The current
compressor uses bounded greedy match finding and resets each chunk
independently; deeper parsing and cross-chunk dictionary reuse remain later
ratio and performance work.
