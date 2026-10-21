# ARJ archive support

Vort provides dependency-free ARJ archive reading and deterministic writing for
the five ordinary data methods used by classic ARJ archives.

The reader scans a bounded number of `60 ea` candidates so self-extracting
prefixes are supported without allowing adversarial inputs to trigger unlimited
header attempts. Main, local-file, and chained extended headers are bounded to
2,600 bytes and validated with IEEE CRC-32 before their fields are exposed.
Every entry records its borrowed name, flags, type, method, compressed and
uncompressed sizes, data offset, and expected content CRC-32. DOS backslashes
are normalized only by the `ArjName` view; the library never joins a name to a
host filesystem path. Encrypted entries additionally expose the archive
encryption generation and per-file password modifier.

Supported data methods are:

- method 0, stored;
- methods 1–3, ARJ's LH6-compatible LZ/Huffman stream;
- method 4, the fastest fixed-code LZ77 stream;
- methods 8/9 as explicit no-data metadata entries.

Methods 1–3 reuse Vort's pure Zig new-style LH decoder. Method 4 has a separate
MSB-first variable-value decoder covering literals, overlapping matches,
distance validation, truncation, output-size mismatches, and exact compressed
byte consumption. Allocating extraction checks the caller's output limit before
allocation and verifies the final content CRC-32.

Legacy Garble encryption is supported for stored and methods 1–4 in both
directions. Vail owns the symmetric cyclic byte stream: each compressed byte is
XORed with the wrapping sum of the header modifier and the next password byte.
Vort owns ARJ flags, encryption-version dispatch, compression ordering,
allocation, and final data CRC verification. Garble is historical obfuscation,
not modern cryptographic security. A missing password returns
`EncryptedArjEntry`; password-based extraction uses the allocator-backed
options API. GOST40 and GOST256 are identified separately and fail as
`UnsupportedArjEncryption` rather than being mislabeled as Garble.

The deterministic writer emits a main header, level-compatible local headers,
header/extension CRC-32, Unix epoch timestamps, per-file content CRC-32,
optional directories, and the standard zero-size terminator. Methods 1–3 use a
valid literal new-style LH baseline; method 4 uses valid fixed-code literals.
Match planning remains later ratio work, but every writer mode handles arbitrary
input and is interoperable with ARJ and 7-Zip.

```zig
const entries = [_]vort.ArjEncodeEntry{
    .{ .name = "plain.bin", .data = plain, .method = .stored },
    .{
        .name = "compressed.txt",
        .data = text,
        .method = .method_1,
        .encryption = .{ .password = "secret", .modifier = 0xa7 },
    },
};
const bytes = try vort.encodeArjAlloc(allocator, &entries);
defer allocator.free(bytes);

const archive = try vort.parseArjArchive(bytes);
const entry = (try archive.find("compressed.txt")) orelse
    return error.ArjEntryNotFound;
const decoded = try archive.extractAllocWithOptions(allocator, entry, .{
    .password = "secret",
    .max_output_len = 64 * 1024 * 1024,
});
defer allocator.free(decoded);
```

CLI validation surfaces:

```sh
zig build run -- create-arj-file archive.arj payload.bin input.bin method1
zig build run -- create-arj-file secret.arj payload.bin input.bin method1 secret a7
zig build run -- list-arj-file archive.arj
zig build run -- extract-arj-file secret.arj payload.bin output.bin 67108864 secret
zig build test-arj
zig build run-arj-diff
```

The differential checks deterministic Vort writing and self-extraction for all
five methods plus deterministic Garble output. With external tools and fixtures
supplied, Debian ARJ validates all five ordinary methods and Garble, unarc-rs
extracts Garble output, 7-Zip validates ordinary output, and five unarc-rs
fixtures validate the reverse direction. The independent encrypted fixture is
decoded with password `secret` and pinned by its plaintext SHA-256; missing and
wrong passwords plus unsupported GOST dispatch are explicit failures:

```sh
zig build run-arj-diff -- \
  --seven-zip path/to/7zz \
  --arj path/to/arj \
  --unarc path/to/unarc \
  --fixtures path/to/unarc-rs/crates/unarc-rs/tests/arj
```

GOST40/GOST256 encryption, recovery records, chapter labels, and multi-volume
continuation are not yet implemented. Their flags are detected and extraction
fails explicitly rather than treating partial data as an ordinary file.
