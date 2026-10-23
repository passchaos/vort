# WOF file-provider streams

Vort supports the backing-stream format used by the Windows Overlay Filter
(WOF) file provider, also known as System Compression or CompactOS. This is the
content of the NTFS `WofCompressedData` named stream; callers provide the
logical file size and the algorithm recorded in the file's WOF reparse point.

Supported algorithms are:

- XPRESS4K, XPRESS8K, and XPRESS16K using independently compressed
  XPRESS-Huffman chunks;
- LZX using independent 32 KiB WIM-LZX chunks and WIM E8 postprocessing.

The parser validates the `num_chunks - 1` cumulative-offset table, chooses
32-bit entries for logical sizes through `UINT32_MAX` and 64-bit entries above
that boundary, checks monotonic offsets, bounds each stored chunk by its decoded
size, and recognizes equal-size raw chunks. Individual chunks are independently
addressable, so range decoding touches only overlapping chunks and uses bounded
caller-owned output.

The module also parses and emits the 20-byte `WOF_EXTERNAL_INFO` plus
`FILE_PROVIDER_EXTERNAL_INFO_V1` ioctl buffer and the 28-byte current WOF
reparse-point representation. Legacy 24-byte reparse data without the flags
field is accepted; unknown providers, versions, algorithms, and flags are
rejected explicitly.

```zig
const backing = try vort.parseWofBacking(
    compressed_stream,
    .xpress16k,
    logical_size,
);
const decoded = try vort.decodeWofAllocLimited(
    allocator,
    backing,
    max_output,
);
defer allocator.free(decoded);

const range = try vort.decodeWofRangeAllocLimited(
    allocator,
    backing,
    offset,
    length,
    max_output,
);
defer allocator.free(range);
```

The deterministic writer uses the shared XPRESS-Huffman encoder for all three
XPRESS modes and selects raw chunks whenever compression would not save space.
LZX uses the shared adaptive verbatim/aligned WIM-LZX encoder with long matches,
repeat offsets and mandatory E8 preprocessing. It also retains raw chunks when
compression does not save space, preserving independent range access.

```sh
zig build run -- encode-wof-file input.bin backing.bin xpress16k
zig build run -- inspect-wof-file backing.bin xpress16k 1048576
zig build run -- decode-wof-file backing.bin output.bin xpress16k 1048576
zig build run -- decode-wof-range backing.bin range.bin xpress16k 1048576 65536 4096
zig build test-wof
zig build run-wof-diff
```

The differential gate constructs mixed compressed/raw multi-chunk streams with
wimlib and decodes them through Vort for all four algorithms. It also encodes
streams with Vort, independently parses their chunk tables, and decodes every
compressed chunk with wimlib. The checked-in XPRESS4K fixture pins the framing
and codec behavior even when no external oracle is installed.

This module handles WOF file-provider metadata and backing bytes, not NTFS
attribute/runlist parsing or the separate WOF WIM provider. A future NTFS layer
can pass the sparse unnamed-stream size, reparse bytes, and `WofCompressedData`
attribute directly to these APIs.
