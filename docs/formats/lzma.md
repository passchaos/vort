# LZMA-Alone support

Vort provides dependency-free decoding for the legacy `.lzma` / LZMA-Alone
format. It parses the 13-byte properties header, validates `lc`/`lp`/`pb`,
normalizes the minimum dictionary size, and supports both declared and
unknown (`0xffffffffffffffff`) uncompressed sizes.

```zig
const header = try vort.parseLzmaHeader(compressed);
const decoded = try vort.decodeLzmaAllocWithOptions(allocator, compressed, .{
    .max_output_len = 256 * 1024 * 1024,
    .max_dictionary_size = 64 * 1024 * 1024,
});
defer allocator.free(decoded);
```

Available APIs:

- `parseLzmaHeader`;
- `decodeLzmaInto`;
- `decodeLzmaAlloc` and `decodeLzmaAllocLimited`;
- `decodeLzmaAllocWithOptions` for independent output and dictionary limits;
- `lzmaDecodedSize` and `lzmaDecodedSizeLimited`.

ZIP method 14 uses a related raw LZMA payload with a ZIP-specific properties
prefix. Vort recognizes those entries through the ZIP reader. Allocating ZIP
extraction APIs work directly; caller-owned extraction must use
`zipExtractEntryIntoWithAllocator` so dictionary scratch remains explicit.

CLI validation surfaces:

```sh
zig build run -- decode-lzma-file input.lzma output.bin 268435456 67108864
zig build run -- size-lzma-file input.lzma 268435456
zig build run-lzma-diff
zig build run-zip-diff
```

LZMA-Alone does not carry an integrity checksum. Known-size streams are checked
against their declared output size, while unknown-size streams require the
range-coder end marker. Applications that require corruption detection should
use XZ or a checksummed container such as ZIP. LZMA-Alone encoding is not yet
implemented.
