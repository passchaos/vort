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

Vendor signatures use bounded proto2 `Signatures` messages with repeated data
and optional fixed32 unpadded lengths. Metadata verification hashes exactly
`header + manifest`; payload verification hashes that same metadata followed
by data blobs while skipping both signature protobufs, matching AOSP
update_engine. Multiple signatures and trusted keys are tried under explicit
count/blob/signature/key limits. Vail owns strict SubjectPublicKeyInfo PEM/DER
parsing plus RSA-2048/4096 PKCS#1-v1.5 SHA-256 and P-256 ECDSA verification.
Unsigned payloads fail by default; either section becomes optional only through
an explicit verification option.

Full OTA extraction supports `REPLACE`, `REPLACE_BZ`, `REPLACE_XZ`, and `ZERO`.
Delta payload `SOURCE_COPY`, legacy `SOURCE_BSDIFF`, `BROTLI_BSDIFF`, and
`PUFFDIFF` operations are also supported with an explicit old partition image.
`LZ4DIFF_BSDIFF` and `LZ4DIFF_PUFFDIFF` are supported for uncompressed,
ordinary LZ4, and LZ4HC clusters. Their bounded proto3 metadata parser validates
contiguous logical block offsets, exact physical and logical sizes, zero
padding, hashes, and postfix patches. Source clusters are partially decoded to
their declared logical lengths, the nested BSDIFF or PUFFDIFF patch is applied,
and target clusters are reconstructed with pure-Zig byte-exact equivalents of
liblz4 1.9.3 `LZ4_compress_destSize` and `LZ4_compress_HC_destSize`. LZ4HC
levels 1 through 12, the default-level mapping for non-positive values, and the
level-12 cap for larger values follow upstream behavior. Optional pre-postfix
SHA-256 values and per-cluster postfix BSDIFF corrections are enforced.

ZUCCHINI operations first decode Android's Brotli envelope, then parse the
little-endian Zucchini ensemble-patch v1 format. The bounded reader validates
file sizes and CRC-32 values, complete destination element coverage, element
versions and geometry, length-prefixed substreams, synchronized signed/unsigned
varints, ordered equivalences, exact extra-data accounting, raw-delta offsets,
target-pool limits, trailing bytes, and output limits. NoOp/raw elements apply
equivalence copies, literal gaps, and byte deltas and are available through the
standalone `parseAndroidZucchiniAlloc` and `applyAndroidZucchiniAlloc` APIs as
well as OTA extraction. AArch64 ELF (`EA64`), Intel ELF32/ELF64 (`Ex86` /
`Ex64`), and PE32/PE32+ (`Px86` / `Px64`) elements are also supported. The
bounded ELF readers validate headers, sections, program ranges, file/RVA
mapping units, relocation tables, and reference quotas. The PE readers
additionally validate DOS/COFF/optional headers, data-directory geometry,
executable sections, image bases, and bounded base-relocation blocks.
Correction covers `R_AARCH64_RELATIVE`, `R_386_RELATIVE`, `R_X86_64_RELATIVE`,
and PE HIGHLOW/DIR64 relocation targets; width-appropriate absolute targets;
AArch64 14-, 19-, and 26-bit branch immediates; Intel `CALL`, `JMP`, and
long-form conditional rel32 branches; and x86-64 RIP-relative call, jump,
move, and address-load instructions. The shared application engine reproduces
Zucchini's source-pruned offset mapper, projected/extra target pools,
nearest-key tie breaking, and global signed reference-delta order. AArch32 ELF,
DEX, and ZTF elements are parsed but explicitly return
`UnsupportedZucchiniPatch`.

The bsdiff patch
reader accepts traditional `BSDIFF40` with three Bzip2 streams and Android's
`BSDF2`, whose control, diff, and extra streams independently select Bzip2 or
Brotli. Patch output, decompressed control bytes, stream consumption, signed
source seeks, and forward progress are bounded and validated. Whole-partition
and bounded range extraction share the same operation engine; range extraction
only expands intersecting compressed or patch operations and enforces separate
per-operation and bsdiff-control limits.

The Puffin layer parses bounded `PUF1` proto3 metadata, validates sorted and
non-overlapping source/destination bit extents and byte-addressed puff extents,
converts raw Deflate to Puffin's stable token stream, applies the nested bsdiff
patch, and reconstructs the target Deflate bit-for-bit. Stored, fixed-Huffman,
and dynamic-Huffman blocks are supported, including multi-block streams,
non-byte-aligned extents, exact dynamic-table recreation, and raw bytes between
multiple deflates. Header, extent count, puff-stream size, nested patch control,
operation output, and final partition output all have independent bounds.

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

const puff_patched = try vort.applyAndroidPuffinAlloc(
    allocator,
    old_bytes,
    puffdiff_patch,
    expected_size,
    .{ .max_output_len = expected_size },
);
defer allocator.free(puff_patched);

const lz4diff_patched = try vort.applyAndroidLz4diffAlloc(
    allocator,
    old_lz4_clusters,
    lz4diff_patch,
    expected_physical_size,
    .{ .max_output_len = expected_physical_size },
);
defer allocator.free(lz4diff_patched);

const trusted = try vort.AndroidOtaSignaturePublicKey.parsePem(public_key_pem);
const verified = try payload.verifySignatures(&.{trusted}, .{});
```

Large seekable payloads and old partition images can remain outside memory.
`AndroidOtaSource` is a stable caller-owned length plus short-read-capable
`read_at` callback. `AndroidOtaSourceArchive` copies only the bounded header,
manifest, and metadata signature; operation blobs and old-image extents are
read on demand. The same range engine covers every supported operation and
retains at most one explicitly limited operation blob/output plus the caller's
requested range. Opening verifies operation-data hashes by streaming each blob;
callers may disable that pass explicitly, while decode still enforces source,
operation, and final partition hashes according to `AndroidOtaDecodeOptions`.

```zig
var source_archive = try vort.parseAndroidOtaSourceAlloc(
    allocator,
    .{ .context = ctx, .len = payload_len, .read_at = readAt },
    .{},
);
defer source_archive.deinit();

const index = source_archive.findPartition("system") orelse
    return error.RangeOutOfBounds;
try source_archive.readPartitionRangeInto(
    allocator,
    index,
    null, // or a second AndroidOtaSource for delta payloads
    range_offset,
    output,
    .{ .max_output_len = output.len, .verify_partition_hash = false },
);
```

The symmetric seekable writer is `encodeAndroidOtaSourcesTo`. Its first pass
reads one operation at a time, selects compression, hashes the partition and
wire blob, and retains only the manifest plan. Its second pass re-reads and
deterministically recompresses each operation into a short-write-capable caller
sink. A changed source is rejected as `UnstableAndroidOtaSource` before its
changed blob is emitted. Memory is bounded by one input operation, the codec's
candidate buffers, manifest metadata, and the sink's own state; neither whole
partitions nor the complete payload are retained. For identical stable inputs,
all four compression policies are byte-identical to `encodeAndroidOtaAlloc`.

```zig
const result = try vort.encodeAndroidOtaSourcesTo(
    allocator,
    &.{.{
        .name = "system",
        .source = .{ .context = input_ctx, .len = image_len, .read_at = readAt },
    }},
    .{ .compression = .auto },
    .{ .context = output_ctx, .write = write },
);
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
zig build run -- inspect-android-ota-source payload.bin
zig build run -- extract-android-ota payload.bin system system.img 8589934592
zig build run -- extract-android-ota-source payload.bin system system.img 1048576 old-system.img
zig build run -- verify-android-ota-signatures payload.bin vendor-public.pem
zig build run -- verify-android-ota-source-signatures payload.bin vendor-public.pem
zig build run -- extract-android-ota-range payload.bin system range.bin 1048576 65536
zig build run -- encode-android-ota system.img payload.bin system auto 4096 1048576
zig build run -- encode-android-ota-source system.img payload.bin system auto 4096 1048576 65536 65536
zig build run -- puff-android-deflate input.deflate output.puff
zig build run -- huff-android-deflate output.puff restored.deflate 0 12345
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
The retained AOSP update-engine PUFFDIFF fixture validates complete PUF1
application through an OTA operation. An optional Puffin codec oracle compares
Vort's puff stream byte-for-byte and huffs stored, fixed, and dynamic Deflate
streams back to the exact original bytes; supply it with
`--puff-codec-oracle /path/to/oracle`. An installed AOSP `puffin` command can
also be selected with `--puffin /path/to/puffin` for the pinned full patch.
When a system liblz4 is available, the differential additionally generates
ordinary and zero-padded LZ4DIFF_BSDIFF/LZ4DIFF_PUFFDIFF payloads with
`LZ4_compress_destSize` and `LZ4_compress_HC_destSize`; Vort must reconstruct
both complete clusters and bounded ranges byte-for-byte. The LZ4HC cases span
hash-chain levels 5 and 9 plus optimal-parser levels 10 and 12.
When Python's Brotli module is available, the same driver independently emits
a canonical Zucchini v1 NoOp patch with equivalences and raw deltas plus an
`EA64` patch that retargets an AArch64 branch and `Ex86`/`Ex64` patches that
retarget relocation, absolute, and rel32 references. Independent `Px86`/`Px64`
fixtures cover the corresponding PE base-relocation and image-base semantics.
It wraps all six in Brotli and verifies whole-partition and bounded-range OTA
extraction.
The required source-backed matrix uses real positional file callbacks for all
four writer modes, the independent Python mixed payload, SOURCE_COPY,
SOURCE_BSDIFF, PUFFDIFF, six LZ4/LZ4HC diff variants, and six Zucchini variants.
It writes outputs in 257-byte chunks, checks final bytes and SHA-256, reports
physical read counts, and currently requires `source_reader=20` plus
`source_inspect=4`. Supplying the local AOSP update-engine corpus additionally
requires both full and both delta kernel/root partitions through this path,
raising the result to `source_reader=24`, `source_aosp=4`.
The source writer differential forces three-byte input reads and five-byte sink
writes for raw, Bzip2, XZ, and automatic policies, requires exact equality with
the corresponding one-shot payloads, and independently decodes all four with
Rust `payload_dumper` (`source_writer=4`, `source_writer_oracle=4`).
When OpenSSL is available, the differential independently generates temporary
RSA-2048 and P-256 keys, signs both metadata and payload ranges, verifies all
four raw signatures with OpenSSL, then requires both Vort slice/source APIs to
select the correct key after a wrong-key candidate. Wrong-only keys, damaged
signatures, and unsigned payloads fail (`signature_cases=9`,
`signature_openssl=4`). Fixed Vail vectors additionally cover RSA-4096.

Current explicit limitations are major-version-1 payloads, certificate-bundle
trust-store discovery/revocation policy, and architecture-specific
Zucchini reference correction for AArch32 ELF, DEX, and ZTF elements. DISCARD is
likewise rejected by default
because Android defines its read-back contents as undefined; callers may opt
into deterministic zero interpretation through `DecodeOptions.discard_as_zero`.
Non-seekable network input, a single-pass writer for callers unable to replay
input, and the remaining architecture-specific Zucchini reference models
remain future work.
