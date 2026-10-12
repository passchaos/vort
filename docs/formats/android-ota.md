# Android OTA payloads

Vort provides a dependency-free parser and deterministic writer for modern
Android update-engine `payload.bin` files using major version 2. The payload
header is parsed directly and the proto2 manifest is decoded with Vort's small,
bounded protobuf wire reader; protobuf and Android runtime libraries are not
required.

The reader indexes every partition, install operation, and source/destination
extent while retaining partition names and hashes as borrowed views into the
payload. It validates:

- the `CrAU` header, big-endian sizes, manifest and metadata-signature bounds;
- protobuf varints, wire types, required partition and operation fields;
- configurable partition, operation, extent, name, block, image, and blob
  limits;
- destination and source extent geometry and checked byte arithmetic;
- ordered, non-overlapping operation blobs and payload-signature bounds;
- every present operation-data SHA-256 before extraction;
- old partition, per-operation source, and final partition SHA-256 values when
  the corresponding data is supplied.

Full OTA extraction supports `REPLACE`, `REPLACE_BZ`, `REPLACE_XZ`, and `ZERO`.
Delta payload `SOURCE_COPY`, legacy `SOURCE_BSDIFF`, and `BROTLI_BSDIFF`
operations are also supported with an explicit old partition image. The patch
reader accepts traditional `BSDIFF40` with three Bzip2 streams and Android's
`BSDF2`, whose control, diff, and extra streams independently select Bzip2 or
Brotli. Patch output, decompressed control bytes, stream consumption, signed
source seeks, and forward progress are bounded and validated. Whole-partition
and bounded range extraction share the same operation engine; range extraction
only expands intersecting compressed or patch operations and enforces separate
per-operation and bsdiff-control limits.

```zig
var payload = try vort.parseAndroidOtaAlloc(allocator, payload_bytes, .{
    .max_manifest_size = 64 * 1024 * 1024,
    .max_operations = 1 << 20,
    .max_partition_size = 64 * 1024 * 1024 * 1024,
});
defer payload.deinit();

const system_index = payload.findPartition("system") orelse
    return error.MissingPartition;
const system = try payload.decodePartitionAllocLimited(
    allocator,
    system_index,
    null, // pass the old system image for SOURCE_COPY payloads
    max_output,
);
defer allocator.free(system);

// The low-level patch API is also available independently of payload.bin.
const patched = try vort.applyAndroidBsdiffAlloc(
    allocator,
    old_bytes,
    patch_bytes,
    expected_size,
    .{ .max_output_len = expected_size },
);
defer allocator.free(patched);
```

The deterministic full-payload writer accepts multiple named, block-aligned
partition images. It divides them into bounded operations, emits ZERO operations
for all-zero chunks, and can force raw, Bzip2, or XZ storage. Automatic mode
tries both codecs and retains the smallest result only when it beats raw data.
XZ output uses CRC-32 as required by Android's embedded decoder. Every stored
blob and final partition carries a SHA-256 value.

```zig
const ota = try vort.encodeAndroidOtaAlloc(
    allocator,
    &.{
        .{ .name = "boot", .data = boot_image },
        .{ .name = "system", .data = system_image },
    },
    .{
        .block_size = 4096,
        .operation_size = 1024 * 1024,
        .compression = .auto,
        .max_output_len = limit,
    },
);
defer allocator.free(ota);
```

CLI and validation surface:

```sh
zig build run -- inspect-android-ota payload.bin
zig build run -- extract-android-ota payload.bin system system.img 8589934592
zig build run -- extract-android-ota-range payload.bin system range.bin 1048576 65536
zig build run -- encode-android-ota system.img payload.bin system auto 4096 1048576
zig build test-android-ota
zig build run-android-ota-diff
```

The differential uses an independent Python protobuf implementation and the
standard-library Bzip2/XZ decoders. It checks a byte-exact raw manifest, all four
writer modes, a separately generated mixed-operation payload, bounded ranges,
an independently generated BSDIFF40/SOURCE_BSDIFF payload, malformed metadata,
and deterministic mutations. When an upstream-compatible `bspatch` is present,
it independently applies the same Python-generated patch. When the Rust
`payload_dumper` command is installed, it independently extracts all four Vort
outputs; an explicit binary can be supplied with
`-- --payload-dumper /path/to/payload_dumper`; select bspatch with
`--bspatch /path/to/bspatch`. Passing an AOSP update-engine
checkout with `--aosp-update-engine /path/to/update_engine` additionally checks
both partitions in its official full payload and both partitions in its delta
payload, including its genuine all-Brotli BSDF2 kernel patch.

Current explicit limitations are major-version-1 payloads, cryptographic
verification of vendor metadata/payload signatures, and patch engines for
PUFFDIFF, ZUCCHINI, and LZ4DIFF. Those operations are retained in the parsed
model but extraction returns
`UnsupportedAndroidOtaOperation`. DISCARD is likewise rejected by default
because Android defines its read-back contents as undefined; callers may opt
into deterministic zero interpretation through `DecodeOptions.discard_as_zero`.
Streaming file I/O remains future work.
