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

Available decoding forms include caller-owned output, bounded allocation,
validated decoded-size preflight, and explicit concatenated-stream variants.
The compressed and stored writers provide alloc, transactional append, and
caller-owned output APIs.

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
