# Vort roadmap

This roadmap is a living checklist toward the larger goal: outperform and
out-feature `zlib`, `zlib-ng`, `zlib-rs`, and `zstd` without copying their
architecture blindly.

### Current completion audit (2026-08-20)

The long-term objective is **not complete**. Current evidence still leaves these
major gaps before Vort can claim broad industry-best parity:

- Brotli general-purpose compression is not implemented; production encoding
  currently covers stored streams, single-byte RLE, and externally gated short
  alternating patterns only.
- True byte-progressive Brotli compressed-meta-block decoding remains future
  work; the general incremental facade buffers a bounded complete payload.
- Incremental DEFLATE source throughput remains behind the local zlib-ng level-6
  comparison on stable runs, despite leading several binary/history shapes.
- Zstd-compatible dictionary training, seekable/indexed framing, and broader
  entropy-mode parity still require completion and competitor evidence.
- Cross-platform optimized kernels and reproducible competitor measurements are
  not yet comprehensive enough for a blanket performance-leadership claim.

The next highest-value deliverable is a general Brotli literal/command encoder
built from an upstream-verified command LUT, followed by a byte-progressive
compressed-meta-block decoder. Performance work should then resume on the
profiled DEFLATE matcher/tree stages with pinned, interleaved A/B evidence.

## Milestone 0: repository and validation spine

- [x] Zig 0.16 package scaffold.
- [x] Public root module and library artifact.
- [x] Unit-test build step.
- [x] Compile-only `check` step for tests, CLI, and benchmark entrypoints.
- [x] Local CI smoke aggregate step covering tests, fuzz, differential checks, and reports.
- [x] CLI smoke surface for library APIs.
- [x] Initial benchmark entrypoint.

## Milestone 1: compatibility primitives

- [x] Adler-32 with streaming state and zlib-known vectors.
- [x] IEEE CRC-32 with streaming state and known vectors.
- [x] CRC-32C for modern storage/network workloads.
- [x] Portable CRC32 slice-by-4 fast variant with scalar reference checks.
- [x] Portable CRC32 slice-by-8 fast variant.
- [x] Portable CRC32 slice-by-16 fast variant selected by dispatch.
- [x] Portable CRC32C slice-by-8 fallback.
- [x] Portable CRC32C slice-by-16 fallback.
- [x] Portable CRC32C slice-by-32 fallback selected when hardware CRC32C is unavailable.
- [x] Runtime checksum dispatch API selecting portable fast path.
- [x] Adler-32, CRC-32, and CRC-32C combine helpers compose independently checksummed blocks without rereading payload bytes.
- [x] Adler-32 update uses 64-byte vector folding for zlib wrapper throughput.
- [x] CPU feature/dispatch report tool.
- [x] x86 checksum CPU feature reporting with IEEE-vs-CRC32C safety distinction.
- [x] x86 SSE4.2 CRC32C hardware path selected by dispatch.
- [x] Architecture-specific IEEE CRC32 dispatch plan and safety gates.
- [x] x86 PCLMUL candidate reporting for future IEEE CRC32 dispatch.
- [x] ARM CRC32 feature reporting for future IEEE CRC32 dispatch.
- [x] Architecture-specific IEEE CRC32 implementation / dispatch on validated targets.
- [x] Differential checksum smoke against Zig std reference implementations.
- [x] Differential checksum tests against Python zlib and local/system gzip wrapper trailers.
- [x] Python zlib differential smoke covers malformed zlib/gzip wrapper cases
  (bad headers, checksum/size mismatches, trailing data, truncated frames) and
  exposes their counts in validation/dashboard JSON health.
- [x] Python zlib differential smoke covers malformed raw/zlib/gzip deflate
  payloads (invalid Huffman codes, dynamic header failures, and invalid
  matches) with dashboard/schema health counts.

## Milestone 2: native frame plumbing

- [x] Native `VORT` store frame for uncompressed payloads.
- [x] Header parsing with explicit version, size, checksum, and corruption errors.
- [x] Native frame inspection exposes mode, encoded length, payload length, and dictionary requirement before decode allocation.
- [x] Header-only native frame inspection supports allocation preflight before payload bytes are available.
- [x] Exact native frame inspection rejects trailing bytes for single-frame preflight.
- [x] Concatenated native inspection summarizes data-frame count, total uncompressed bytes, combined CRC-32, modes, and dictionary requirement without decoding.
- [x] Concatenated native inspection options enforce expected frame count, total length, and combined checksum without payload decode.
- [x] One-shot encode/decode APIs.
- [x] Allocator-returning convenience APIs.
- [x] Bounded-output streaming encoder/decoder smoke coverage.
- [x] Fully incremental input/output store-frame decoder.
- [x] Store-frame streaming encoder and incremental decoder can reset for caller-owned state reuse.
- [x] Store-frame bounded-output decoder can reset and expose progress/error snapshots for caller-owned state reuse.
- [x] Store-frame incremental decoder exposes snapshot diagnostics for phase, byte progress, expected output, and remaining payload.
- [x] Store-frame incremental decoder snapshots retain the latest header/payload error name, phase, and recoverability hint.
- [x] Store-frame bounded and incremental decoders expose a shared StreamingDiagnostics view.
- [x] Store-frame streaming encoder exposes snapshot diagnostics and the shared StreamingDiagnostics view.
- [x] Native non-dictionary AnyDecoder drains store/deflate/RLE frames through reusable caller-owned streaming state and scratch.
- [x] Dictionary-aware AnyDecoder drains dictionary-patch/deflate frames through caller-owned payload and patch scratch.
- [x] Concatenated store-frame iterator and decode helper.
- [x] Concatenated native decode supports non-dictionary compressed frame modes with exact-size and output-limited allocator variants.
- [x] Concatenated native decode supports caller-supplied dictionaries for dictionary-patch/deflate members.
- [x] Concatenated native auto decode uses embedded dictionaries for self-contained dictionary streams.
- [x] Concatenated native caller-owned decode reports bytes, data-frame count, and CRC-32.
- [x] Allocator-returning concatenated native decode preflights total output and reuses caller-owned decode internally.
- [x] Native allocation report records allocation counts for concatenated alloc/into/auto/limited decode paths.
- [x] Native allocation report emits retained JSON/Markdown artifacts.
- [x] Native allocation report compares indexed range decode with and without caller-owned index buffers.
- [x] Native allocation smoke gates key caller-owned decode paths at zero allocations.
- [x] Native allocation smoke gates non-zero allocation paths with maximum allocation/byte budgets.
- [x] Native allocation smoke verifies allocation/free count and byte balance.
- [x] Native allocation negative smoke verifies allocation gate regressions fail.
- [x] Native allocation negative smoke emits schema-validated JSON artifacts.
- [x] Native allocation smoke/report artifacts are validated by the shared JSON schema manifest.
- [x] Native allocation report/smoke artifacts are indexed in the dashboard producer manifests.
- [x] Native allocation negative smoke artifact is indexed in the dashboard producer manifests.
- [x] Dictionary-deflate validation can reuse caller-owned patch scratch for zero-allocation full validation and reports.
- [x] Native allocation report/smoke gates dictionary-deflate validation buffer paths at zero allocations.
- [x] Embedded dictionary inspection validates dictionary metadata without allocating dictionary bytes.
- [x] Embedded dictionary inspection options enforce expected dictionary ID and content length.
- [x] Auto dictionary range/validation/concatenated decode paths borrow embedded dictionary bytes instead of copying them.
- [x] Embedded dictionary view API returns borrowed bytes and validated metadata in one scan.
- [x] Embedded dictionary view API rejects reserved, truncated, and ID-mismatched metadata.
- [x] Store/native fuzz smoke corpus covers embedded dictionary metadata accept/reject cases.
- [x] Store/native fuzz smoke corpus covers concatenated dictionary auto decode accept/reject cases.
- [x] External native hex fuzz corpus covers store and dictionary concatenated accept/reject cases.
- [x] Native hex fuzz corpus emits JSON/Markdown artifacts and has coverage smoke gates.
- [x] Native hex fuzz corpus covers RLE, LDM, and dictionary-deflate accept/reject cases.
- [x] Native hex fuzz corpus covers dictionary-patch malformed opcode errors.
- [x] Native hex fuzz corpus covers RLE zero/overflow and LDM truncated payload errors.
- [x] Deterministic malformed-header/frame smoke corpus.
- [x] Skippable native frames.
- [x] In-memory frame indexes for concatenated native store streams.
- [x] Serialized/sidecar frame indexes.
- [x] Serialized frame indexes carry per-frame checksums validated by range decode.
- [x] Serialized frame indexes expose entry-count preflight and caller-owned decode APIs.
- [x] Embedded frame indexes expose borrowed payload views and caller-owned decode APIs.
- [x] Indexed and sidecar range-into APIs can reuse caller-provided frame-index buffers.
- [x] Dictionary-aware indexed and sidecar range-into APIs can reuse caller-provided frame-index buffers.
- [x] Auto and self-contained dictionary range-into APIs can reuse caller-provided frame-index buffers.
- [x] Frame indexes can compose per-frame CRC-32 values into a whole-stream checksum without rereading payload bytes.
- [x] Public frame-index summary API exposes frame count, total uncompressed length, and combined checksum.
- [x] Validation reports expose frame-count, total-uncompressed, and combined-checksum summaries for successful indexed streams.
- [x] Sidecar validation options can enforce expected whole-stream length and combined checksum from frame-index metadata.
- [x] Sidecar and embedded validation can reuse caller-provided index and payload scratch buffers.
- [x] Sidecar and embedded validation expose sizing helpers for caller-owned index, payload, and patch buffers.
- [x] Embedded deflate/LDM validation can reuse caller-owned payload scratch at zero allocations.
- [x] Sidecar deflate/LDM validation can reuse caller-owned payload scratch at zero allocations.
- [x] Sidecar and embedded validation reports can reuse caller-provided index and payload scratch buffers.
- [x] Default full validation pre-reserves scratch for the largest indexed frame to avoid repeated growth.
- [x] Indexed and sidecar range-decode summary APIs return range bytes with CRC-32 summaries.
- [x] Indexed and sidecar range-decode into APIs fill caller-owned buffers while returning range CRC-32 summaries.
- [x] Dictionary-backed embedded and sidecar auto range-decode summary APIs support CRC-32 summaries and caller-owned buffers.
- [x] Allocator-returning single-range APIs reuse the caller-owned range-into path and mode-specific fast paths.
- [x] One-shot native `decodeAnyInto` covers store/deflate/RLE/LDM caller-owned output paths.
- [x] One-shot native `decodeAnyAllocExactSize` and `decodeAnyAllocLimited` bound allocator-returning output.
- [x] Indexed and sidecar batch range-decode summary APIs reuse one parsed index for multiple logical ranges.
- [x] Indexed and sidecar batch range-decode into APIs fill caller-owned buffers after one parsed index.
- [x] Batch range-decode into APIs cache decoded frames within a batch to avoid repeated same-frame decode work.
- [x] Batch range-decode into APIs allocate decoded-frame caches lazily so fast-path-only batches avoid cache allocation.
- [x] Batch range-decode summary APIs reuse the cached batch-into path and preflight invalid requests.
- [x] Batch range-decode summary APIs preflight invalid requests before allocating range buffers.
- [x] Batch range-decode APIs cover LDM and dictionary-deflate indexed frame modes.
- [x] Batch range-decode error tests cover LDM out-of-bounds and dictionary-deflate missing-dictionary requests without buffer mutation.
- [x] Range-decode into paths copy directly from checksum-validated store-frame payloads without whole-frame decode allocation.
- [x] Native RLE frame decode-into expands runs directly into caller buffers.
- [x] Native RLE range-decode into streams compact runs and avoids whole-frame decoded allocation for full and partial ranges.
- [x] Full-frame native deflate range-decode into path writes directly to caller buffers without temporary decode allocation.
- [x] Partial native deflate range-decode can reuse caller-owned payload scratch at zero allocations.
- [x] Partial native LDM range-decode can reuse caller-owned payload scratch at zero allocations.
- [x] Sidecar partial native deflate/LDM range-decode can reuse caller-owned payload scratch at zero allocations.
- [x] Dictionary patch codec exposes caller-owned decode-into and decoded-size helpers.
- [x] Full-frame native dictionary-patch range-decode into path writes directly to caller buffers without temporary decoded-frame allocation.
- [x] Native dictionary-deflate frame decode-into uses caller buffers after inflating the patch payload.
- [x] Full-frame native dictionary-deflate range-decode can reuse caller-owned patch scratch and index buffers at zero allocations.
- [x] Partial native dictionary-deflate range-decode can reuse caller-owned payload and patch scratch at zero allocations.
- [x] Dictionary range decode exposes sizing helpers for caller-owned index, payload, and patch buffers.
- [x] Auto and self-contained dictionary-deflate range-decode can reuse caller-owned payload and patch scratch at zero allocations.
- [x] Native dictionary-patch/deflate allocator decoders expose exact-size and output-limited variants.
- [x] Native dictionary-deflate patch inflation is bounded by declared decoded output size.
- [x] Allocating deflate inflate paths reuse the caller-buffer overlapping-match
  doubling copy for no-dictionary matches after reserving the output span, avoiding
  byte-at-a-time ArrayList appends on long repeated matches.
- [x] Huffman fast decode uses staged-bit reader advances after lookup peeks, so
  contiguous and chunked inflate hot paths avoid a redundant fill call per symbol.
- [x] Chunked zlib direct decode uses tiered stack join buffers for small
  non-stored compressed members, keeping tiny PNG IDAT joins off the 64 KiB stack
  path while preserving the direct cursor path for large streams.
- [x] Chunked zlib benchmark repeat3 CSV now has a schema/value gate for the PNG-like contiguous/join/direct chunked decode cases, including a `direct_strategy` column and large literal/match rows that record current `span-reader` execution instead of bounded stack-join.
- [x] Chunked zlib benchmark rows now include exact-size allocating chunk decode
  throughput (`chunk_exact_mib_s`) and `exact_over_direct` ratios, so known-size
  callers such as imx split-IDAT full-inflate fallback have direct evidence
  beside join-then-decode and caller-buffer direct chunked decode.
- [x] Extended the chunked zlib benchmark/gate with a large match-heavy dynamic row that also exceeds the bounded stack-join limit, keeping true chunked-reader match-copy/history costs visible beside the literal-only row.
- [x] Extended the dynamic decode profile gate with the same chunked-window-match shape, requiring a match-heavy non-overlap-dominated row above the stack-join threshold so future chunked-reader optimizations can see match/history/extra-bit attribution.
- [x] Tested routing every stored chunked zlib stream through the direct stored reader, but rejected it because the repeat5 chunked benchmark regressed tiny/empty stored chunks; the existing stack-join cutoff remains the safer policy.
- [x] Optimized chunk joining to skip empty zlib chunks, improving tiny/empty PNG-IDAT-style join evidence while keeping direct chunked decode behavior unchanged.
- [x] Extended the chunked zlib benchmark/gate with a stored one-byte empty-chunk case so the worst fragmented stored IDAT shape remains visible before changing direct-vs-join policy.
- [x] Tried advancing `ChunkCursor` past consumed/empty chunks inside read/copy hot paths, but rejected it because repeat5 chunked evidence was noise-level overall and regressed the stored one-byte empty case.
- [x] Tried a known-total stack join helper to avoid recomputing chunked zlib total length, but rejected it because repeat5 join evidence regressed the stored one-byte empty chunk row.
- [x] Extended the extra-bit reader benchmark/gate with 4 KiB chunked reads so large split-IDAT chunked-reader bit overhead is visible beside 64-byte and 1-byte chunk extremes.
- [x] Extended the extra-bit reader benchmark/gate with `span_4096` / `span_64` / `span_1` rows, confirming the span reader improves length/distance extra-bit reads across all tracked widths.
- [x] Optimized `ChunkedBitReader.fill` to skip full staged-cursor synchronization while staging bytes from the cached chunk, improving the large literal chunked-reader row under the chunked zlib gate.
- [x] Tried applying the same cached-chunk guard to the consumed cursor advance path, but rejected it because extra-bit benchmarks regressed across all chunk sizes.
- [x] Tried chunk-local multi-byte staging inside `ChunkedBitReader.fill`, but rejected it because the extra-bit benchmark regressed across 4 KiB, 64-byte, and 1-byte chunks.
- [x] Added a focused chunk cursor microbenchmark/gate covering read-byte and copy-to kernels over one-byte empty, seven-byte empty, and 256-byte chunk layouts before further direct stored reader changes.
- [x] Tried applying the chunk cursor empty-advance optimization only to `copyTo`; kept the microbenchmark evidence but rejected the production change because full chunked zlib direct decode still regressed stored 256-byte chunks.
- [x] Tried two stored-footer read tweaks for chunked zlib direct decode (`readChunkedBigU32` and an in-cursor 4-byte loop), but rejected both because full repeat5 chunked benchmarks were noise-level to negative.
- [x] Tried a conditional copy-only empty-chunk advance in `ChunkCursor.copyTo`, but rejected it because complete chunked zlib direct decode still regressed stored 256-byte and literal chunk rows.
- [x] Dictionary patch decoder rejects non-progress literal operations.
- [x] Native LDM frame decode-into replays literals and matches directly into caller buffers.
- [x] Full-frame native LDM range-decode into path writes directly to caller buffers without temporary decoded-frame allocation.
- [x] Sidecar-indexed stream encoder keeps index external.
- [x] Sidecar frame-index bytes can drive range decode without embedded index.
- [x] Sidecar frame-index bytes can drive dictionary range decode.
- [x] Sidecar frame-index bytes can auto range-decode streams with embedded dictionaries.
- [x] Sidecar index validation decodes referenced frames and catches payload corruption, including dictionary streams.
- [x] Full sidecar/embedded validation reuses decoded-payload scratch buffers across frames.
- [x] Sidecar index validation exposes explicit metadata-only and full-decode modes for large corpus workflows.
- [x] Embedded-index validation exposes the same metadata-only/full-decode semantics as sidecar validation.
- [x] Sidecar and embedded-index validation reports expose structured failure context for diagnostics.
- [x] Sidecar verification reports include validation stage and frame context fields in CSV/Markdown/JSON output.
- [x] CLI verify commands print structured validation failure context before returning errors.
- [x] CLI verify commands support machine-readable JSON validation output.
- [x] Validation JSON outputs include schema and schema_version fields for script compatibility.
- [x] Validation JSON schema smoke parses CLI/report/corrupt JSON outputs and runs in CI smoke.
- [x] Validation JSON schema smoke validates generated JSON against the shared schema manifest.
- [x] Validation JSON schema smoke validates generated dashboard index manifests against the shared schema manifest.
- [x] Validation JSON schema smoke validates raw/zlib/gzip wrapper fuzz corpus dashboard artifacts.
- [x] Validation JSON schema smoke can write a fixed zig-out summary artifact.
- [x] Validation JSON schema reference documents field meanings and compatibility rules.
- [x] Validation JSON schema reference includes example objects for every validation/dashboard schema.
- [x] Validation JSON schema reference examples are checked by a build step.
- [x] Validation JSON schema reference checker validates required top-level and item fields.
- [x] Validation JSON schema reference checker validates documented example field types.
- [x] Validation JSON schema reference checker validates documented enum values.
- [x] Validation JSON schema checker reads field/type/enum expectations from an external manifest.
- [x] Validation JSON schema checker validates conditional null/non-null fields and numeric field relations.
- [x] Dashboard index links zig-out validation, sidecar, and benchmark artifacts from a single Markdown entrypoint.
- [x] Dashboard index includes artifact sizes and UTC update timestamps.
- [x] Dashboard index emits a JSON artifact manifest with schema, category, size, timestamp, and row metadata.
- [x] Dashboard index records producer build steps for known artifacts.
- [x] Dashboard index reads producer build-step mappings from an external JSON config.
- [x] Dashboard producer config schema is documented alongside validation JSON schemas.
- [x] Dashboard producer config is validated by the shared JSON schema checker.
- [x] Dashboard manifest reports producer-step coverage and missing producer mappings.
- [x] Dashboard index build step fails when producer-step coverage is incomplete.
- [x] Dashboard producer config supports allowlisted temporary artifacts without producer mappings.
- [x] Dashboard producer config records expected artifact formats and smoke gates in the manifest.
- [x] Dashboard producer config covers standard multi-corpus dashboard artifacts.
- [x] Dashboard manifest reports smoke-gate coverage and missing smoke gates.
- [x] Dashboard index build step fails when required smoke gates are missing.
- [x] Validation diagnostics include readable frame mode names alongside numeric frame flags.
- [x] Validation diagnostics include recoverability hints for corruption/index/dictionary failures.
- [x] Sidecar corrupt-payload smoke verifies metadata mode accepts header-consistent streams while full mode rejects store/deflate/RLE/dictionary/LDM/self-contained/seekable sidecar/embedded-index payload corruption.
- [x] Sidecar corrupt-payload smoke can emit Markdown/JSON artifacts for dashboard retention.
- [x] Sidecar corrupt-payload dashboard step writes fixed zig-out Markdown/JSON artifacts and runs in CI smoke.
- [x] CLI smoke for embedded-index encode and metadata/full validation.
- [x] CLI smoke for embedded-index range decode.
- [x] CLI smoke for embedded-index self-contained dictionary encode and auto range decode.
- [x] CLI help lists sidecar and embedded-index file workflows.
- [x] CLI help groups basics, compatibility formats, and native indexed file workflows.
- [x] CLI smoke for sidecar-index range decode.
- [x] CLI smoke for sidecar-index dictionary auto range decode.
- [x] Frame index monotonicity/gap validation before range decode.
- [x] Extensible hex-sample fuzz corpus harness for headers and malformed frames.
- [x] Coverage-guided fuzz integration plan and reusable corpus entrypoint.
- [x] Raw-byte fuzz target function and smoke executable.
- [x] Deflate fuzz smoke corpus covers valid raw streams and malformed dynamic/non-final cases.
- [x] Deflate fuzz smoke corpus covers fixed-Huffman reserved literal/distance symbols.
- [x] Deflate fuzz smoke corpus covers dynamic code-length repeat overrun cases.
- [x] Deflate wrapper hex corpus covers dynamic repeat-17 overrun samples.
- [x] Hex-sample fuzz corpus harness supports raw deflate samples.
- [x] Hex-sample fuzz corpus harness supports zlib/gzip wrapper samples.
- [x] Hex-sample fuzz corpus harness can load deflate/zlib/gzip samples from corpus files.
- [x] Hex-sample fuzz corpus harness enforces expected accept/reject outcomes.
- [x] Hex-sample fuzz corpus harness supports exact expected error-name assertions.
- [x] Hex-sample fuzz corpus harness supports preset dictionaries for raw/zlib samples.
- [x] Hex-sample fuzz corpus harness supports explicit output limits for raw/zlib/gzip samples.
- [x] Hex-sample fuzz corpus harness can emit schema-checked JSON and Markdown dashboard artifacts.
- [x] Deflate wrapper hex corpus includes malformed dynamic-Huffman samples.
- [x] Deflate wrapper hex corpus includes raw/zlib/gzip repeat17 and repeat18 overrun samples.
- [x] Deflate wrapper hex corpus includes header-only, missing-footer, and trailing-garbage boundary samples.
- [x] Deflate wrapper hex corpus pins representative raw/zlib/gzip boundary samples to exact expected errors.
- [x] Deflate wrapper hex corpus dashboard records per-sample expected/actual error matches.
- [x] Deflate wrapper hex corpus dashboard summarizes coverage by wrapper mode and actual error name.
- [x] Deflate wrapper hex corpus dashboard has a schema-checked minimum coverage matrix for wrapper/error combinations.
- [x] Deflate wrapper hex corpus pins malformed dynamic-Huffman and output-limit samples to exact expected errors.
- [x] Deflate wrapper hex corpus covers concatenated gzip second-member corruption.
- [x] libFuzzer-compatible exported entrypoint smoke.
- [x] AFL-style file-input fuzz driver smoke.
- [x] Local CI smoke runner wiring for fuzz entrypoints.
- [x] Local CI smoke runs the raw/zlib/gzip wrapper hex corpus file, including exact error-name checks.
- [x] Local CI smoke retains raw/zlib/gzip wrapper fuzz corpus JSON/Markdown artifacts in the dashboard index.
- [x] Hosted CI fuzz runner wiring.

## Milestone 3: deflate/zlib/gzip compatibility

- [x] LSB-first bit reader primitive.
- [x] Canonical Huffman decode table foundation for fixed-Huffman inflate.
- [x] Canonical Huffman table construction rejects oversubscribed trees.
- [x] LSB-first bit writer primitive.
- [x] Stored deflate blocks.
- [x] Stored deflate decoders ignore non-zero byte-alignment padding bits.
- [x] Stored raw/zlib/gzip alloc decoders support explicit output limits.
- [x] Fixed-Huffman inflate for literals and back-references.
- [x] Fixed-Huffman fast lookup decode path for literals and distances.
- [x] Fixed-Huffman inflate rejects reserved literal/length symbols through raw/zlib/gzip paths.
- [x] Fixed-Huffman inflate rejects reserved distance symbols through raw/zlib/gzip paths.
- [x] Dynamic-Huffman header and code-length parser foundation.
- [x] Dynamic-Huffman code-length parser rejects invalid repeat symbols and overrun repeats.
- [x] Dynamic-Huffman inflate rejects oversubscribed code-length alphabets through raw/zlib/gzip paths.
- [x] Dynamic-Huffman inflate rejects literal/length alphabets that omit end-of-block.
- [x] zlib/gzip wrappers propagate malformed dynamic-Huffman code-length repeat failures.
- [x] Dynamic-Huffman inflate for single final blocks.
- [x] Dynamic-Huffman inflate uses a fast lookup decoder with fallback for long codes.
- [x] Dynamic-Huffman inflate uses a smaller distance lookup table to reduce per-block setup overhead.
- [x] Dynamic-Huffman inflate specializes single-symbol distance alphabets without
  building distance lookup tables, improving PNG-style dynamic blocks that only
  use one match distance code.
- [x] Huffman fast decoder value lookups are explicitly inline, reducing the
  per-symbol call overhead in dynamic PNG inflate hot paths.
- [x] Buffered bit-reader padded peeks are explicitly inline, removing another
  per-symbol call boundary from fast Huffman lookup probes.
- [x] Buffered bit-reader staged availability checks are explicitly inline for
  fast Huffman lookup hit validation.
- [x] Buffered bit-reader fill is explicitly inline for fast Huffman padded
  peek probes without changing the reservoir fill policy.
- [x] BitReader skipBits advances directly for fast Huffman decode hot paths.
- [x] BitReader read/peek use little-endian byte windows instead of per-bit loops.
- [x] Deflate decode stage report isolates raw/zlib/gzip alloc and caller-buffer decode overhead, including wrapper/checksum costs.
- [x] Deflate decode stage report includes exact-size alloc decode rows for raw/zlib/gzip APIs.
- [x] Deflate decode stage report separates literal-only dynamic streams from dynamic streams with LZ77 matches.
- [x] Deflate decode stage dashboard records raw/zlib/gzip malformed, truncated, checksum, and concatenated-gzip error-path smoke results.
- [x] Dynamic-Huffman inflate rejects matches when the distance alphabet has no usable codes.
- [x] Deflate fuzz smoke and hex corpus cover dynamic matches without distance codes.
- [x] zlib/gzip wrappers propagate malformed dynamic-Huffman distance-code failures.
- [x] Deflate fuzz smoke and hex corpus cover match distances beyond available history.
- [x] Deflate fuzz smoke and hex corpus cover dynamic match distances beyond output history.
- [x] Single-block fixed/dynamic inflate rejects non-final blocks instead of accepting incomplete streams.
- [x] Multi-block raw/zlib/gzip inflate across stored/fixed/dynamic block types.
- [x] Raw auto inflate rejects truncated streams after non-final stored/fixed/dynamic blocks.
- [x] Raw preset-dictionary decode API supports dictionary back-references.
- [x] Raw preset-dictionary encode API can emit dictionary back-references for fixed/dynamic/best blocks.
- [x] Raw/zlib/gzip one-shot decode APIs support explicit output limits.
- [x] Public raw deflate first-block header parser exposes BFINAL/BTYPE and payload offsets.
- [x] Raw deflate header parser exposes stored-block LEN/NLEN and payload offsets.
- [x] Raw deflate header parser exposes dynamic-block HLIT/HDIST/HCLEN fields.
- [x] Raw deflate header parser exposes dynamic code-length-code lengths.
- [x] Raw deflate header parser exposes dynamic literal/distance code-length summary counts.
- [x] Raw deflate header parser exposes dynamic literal/distance zero counts and max bit lengths.
- [x] Raw deflate header parser exposes dynamic literal/distance code-length histograms.
- [x] Raw deflate header parser exposes dynamic code-length RLE operation counts.
- [x] Raw deflate header parser reports how many bits/bytes the lightweight inspection consumed.
- [x] CLI raw deflate header inspection supports text and schema-checked JSON output.
- [x] Allocator-returning raw/zlib/gzip decoders use larger capped output capacity hints for highly compressed frames.
- [x] Raw/zlib/gzip alloc decoders expose exact-size variants for callers that know the output length.
- [x] Public raw deflate chunked helpers decode split raw input through
  caller-provided compressed join scratch, including caller-buffer,
  allocator-returning, exact-size, output-limited, and preset-dictionary
  variants.
- [x] Public raw deflate header inspection supports split input through
  caller-provided compressed join scratch.
- [x] Root module compile-time smoke pins public raw/zlib/gzip chunked decode
  helper exports so README-visible split-input APIs cannot drift silently.
- [x] Concatenated gzip alloc decoder exposes an exact-size variant.
- [x] File CLI and Python differential smoke cover raw deflate file decode with output limits.
- [x] File CLI and Python differential smoke cover raw preset-dictionary file decode.
- [x] File CLI and Python differential smoke cover raw preset-dictionary one-shot/split/adaptive file encode.
- [x] zlib/gzip wrappers reject truncated non-final raw deflate streams across stored/fixed/dynamic blocks.
- [x] zlib wrapper and Adler verification for stored blocks.
- [x] zlib decode option APIs can ignore Adler-32 and/or allow trailing data
  while preserving strict defaults for PNG compatibility and relaxed-reader
  integrations.
- [x] zlib concatenated decode option APIs can ignore per-member Adler-32 and/or
  allow trailing non-member data across caller-buffer, allocator-returning,
  exact-size, output-limited, and preset-dictionary variants.
- [x] Public zlib chunked decode helpers cover strict, relaxed, exact-size,
  output-limited, and preset-dictionary variants. Legacy caller-buffer variants
  can still join into caller scratch, while the new `decodeZlibChunksInto*` and
  allocator-returning variants decode directly from chunked input through a
  chunk-aware bit reader instead of first materializing a contiguous compressed
  copy.
- [x] zlib relaxed decode options report/gate covers strict rejection, relaxed
  success, exact/limited allocator variants, output-limit rejection, and preset
  dictionary streams.
- [x] zlib relaxed decode report is indexed in validation/dashboard producer
  metadata with schema documentation and required smoke-gate coverage.
- [x] zlib relaxed decode report emits a Markdown dashboard alongside JSON for
  human review of strict/relaxed/dictionary/output-limit coverage.
- [x] zlib header CINFO/window metadata compatibility test verifies Vort reports
  smaller advertised windows while matching zlib-compatible decode behavior for
  otherwise-valid streams.
- [x] zlib wrapper reports preset-dictionary streams as dictionary requirements.
- [x] Public zlib header metadata parser exposes CMF/FLG, window, FDICT/DICTID, and FLEVEL fields.
- [x] Public zlib header metadata parser supports split input through
  caller-provided compressed join scratch.
- [x] CLI zlib header inspection prints parsed metadata for hex/file workflows.
- [x] CLI zlib header inspection supports schema-checked JSON output.
- [x] raw/zlib/gzip header inspection CLI smoke runs in local CI aggregate.
- [x] raw/zlib/gzip header inspection smoke covers malformed-header failure paths.
- [x] raw/zlib/gzip header inspection smoke covers header-only and missing-trailer wrapper boundaries.
- [x] raw/zlib/gzip header inspection smoke covers multiple malformed dynamic code-length failure paths.
- [x] raw/zlib/gzip header inspection smoke checks malformed dynamic samples stay mirrored in the shared hex corpus.
- [x] raw/zlib/gzip header inspection smoke covers malformed dynamic code-length failures through zlib/gzip inner-deflate inspection.
- [x] zlib/gzip inner-deflate inspection smoke covers oversubscribed code-length alphabet failures.
- [x] zlib/gzip inner-deflate inspection smoke covers dynamic repeat17 overrun failures.
- [x] raw/zlib/gzip inner-deflate inspection smoke covers dynamic repeat18 overrun failures.
- [x] raw/zlib/gzip header inspection smoke records successful zlib/gzip inner-deflate inspection cases.
- [x] raw/zlib/gzip header inspection smoke covers zlib/gzip inner-deflate file workflows.
- [x] gzip inner-deflate header inspection smoke covers concatenated gzip first-member behavior.
- [x] gzip inner-deflate header inspection supports selecting a concatenated member index.
- [x] gzip inner-deflate header inspection smoke rejects out-of-range member indexes.
- [x] gzip inner-deflate header inspection locates member boundaries via raw deflate input length and gzip trailers.
- [x] gzip inner-deflate header inspection docs clarify deflate_bytes for concatenated streams.
- [x] README documents concatenated gzip inner-deflate inspection as first-member behavior.
- [x] Validation JSON docs include zlib/gzip inner-deflate file workflow examples.
- [x] zlib/gzip inner-deflate header inspection JSON includes wrapper offset context.
- [x] zlib/gzip inner-deflate header inspection JSON reports wrapper scope and member index.
- [x] zlib/gzip inner-deflate header inspection JSON labels deflate byte span semantics.
- [x] gzip inner-deflate header inspection JSON reports exact selected-member footer and end offsets.
- [x] gzip inner-deflate header inspection JSON reports exact member deflate length plus CRC32/ISIZE trailer diagnostics.
- [x] gzip inner-deflate header inspection smoke covers CRC32 and ISIZE trailer mismatch diagnostics without rejecting inspection.
- [x] gzip inner-deflate header inspection smoke covers second-member CRC32/ISIZE mismatch diagnostics.
- [x] Public gzip member inspector API exposes member offsets, exact deflate length, decoded byte count, and trailer diagnostics.
- [x] zlib inner-deflate header inspection JSON reports exact stream deflate length and Adler-32 footer diagnostics.
- [x] Public zlib stream inspector API exposes stream offsets, exact deflate length, decoded byte count, and Adler-32 diagnostics.
- [x] zlib dictionary-aware inner-deflate header inspection CLI emits full Adler-32 stream diagnostics for FDICT streams.
- [x] Wrapped deflate header JSON exposes wrapper-neutral exact_deflate_bytes alongside legacy header-tail deflate_bytes.
- [x] zlib/gzip inner-deflate header inspection schema cross-checks wrapper type and scope.
- [x] zlib/gzip inner-deflate header inspection schema-validates nested raw headers.
- [x] raw/zlib/gzip header inspection smoke records and schema-checks malformed case formats and per-format negative counts.
- [x] raw/zlib/gzip header inspection smoke reports schema-checked per-command success/failure coverage.
- [x] raw/zlib/gzip header inspection smoke reports hex/file workflow coverage per inspect command.
- [x] raw/zlib/gzip header inspection smoke enforces a required hex/file workflow coverage matrix.
- [x] Header inspection required workflow coverage matrix is stored in a schema-checked external JSON config.
- [x] Header inspection smoke cross-checks CLI help inspect commands against the required workflow matrix.
- [x] Validation docs checker cross-checks header inspect required workflow config against schema command enums.
- [x] raw/zlib/gzip header inspection smoke records the schema name for each successful case.
- [x] raw/zlib/gzip header inspection smoke enum-checks successful case names.
- [x] raw/zlib/gzip header inspection smoke records replayable command/sample fields for each successful case.
- [x] raw/zlib/gzip header inspection smoke records replayable argv arrays for success and malformed cases.
- [x] raw/zlib/gzip header inspection smoke cross-checks case format, schema, and replay command.
- [x] raw/zlib/gzip header inspection smoke schema-checks argv arrays against command/sample fields.
- [x] raw/zlib/gzip header inspection smoke checks summary counters against recorded cases.
- [x] raw/zlib/gzip header inspection smoke moves summary counter checks into the shared schema manifest.
- [x] raw/zlib/gzip header inspection smoke schema-checks error distribution totals.
- [x] raw/zlib/gzip header inspection smoke reports structured malformed-header failure items.
- [x] raw/zlib/gzip header inspection smoke writes a schema-checked dashboard JSON artifact.
- [x] raw/zlib/gzip header inspection smoke writes a Markdown dashboard artifact.
- [x] raw/zlib/gzip header inspection Markdown dashboard includes per-format summary totals.
- [x] raw/zlib/gzip header inspection Markdown dashboard groups successful inspections by format.
- [x] raw/zlib/gzip header inspection Markdown dashboard surfaces human-readable success-case details.
- [x] raw/zlib/gzip header inspection Markdown dashboard shows dynamic RLE16/RLE17/RLE18 counts.
- [x] raw/zlib/gzip header inspection Markdown dashboard shortens long hex samples while JSON keeps full replay data.
- [x] raw/zlib/gzip header inspection smoke verifies Markdown sample shortening without losing JSON replay data.
- [x] raw/zlib/gzip header inspection Markdown dashboard groups malformed-header failures by format.
- [x] raw/zlib/gzip header inspection Markdown dashboard summarizes malformed-header failures by expected error.
- [x] raw/zlib/gzip header inspection schema enum-checks malformed error distribution keys.
- [x] Dashboard index classifies raw/zlib/gzip header inspection artifacts under validation.
- [x] Dashboard index surfaces header inspection required/missing workflow coverage health.
- [x] Dashboard index strict mode fails when header inspection coverage is missing or unhealthy.
- [x] Dashboard index exposes missing header inspection workflow details in the top-level manifest and strict failure message.
- [x] Dashboard strict-mode smoke covers producer, smoke-gate, and header-inspection health gates.
- [x] Dashboard strict-mode smoke writes a schema-checked JSON artifact retained by the dashboard index.
- [x] Dashboard strict-mode smoke writes a Markdown artifact and records expected-output/returncode fields per check.
- [x] Dashboard strict-mode smoke records actual-output fields and dashboard category smoke verifies strict artifacts are validation artifacts.
- [x] Dashboard strict-mode smoke reports per-mode check counts in JSON and Markdown artifacts.
- [x] Dashboard strict-mode smoke enforces an expected per-mode coverage matrix.
- [x] Dashboard strict-mode smoke reports actual/minimum/delta coverage per expected mode.
- [x] Dashboard strict-mode expected coverage matrix is stored in a schema-checked external JSON config.
- [x] Validation docs checker cross-checks dashboard strict expected modes against schema mode enums.
- [x] Dashboard index surfaces dashboard strict-mode check and mode counts.
- [x] Dashboard index surfaces dashboard strict expected-failure and matched check totals.
- [x] Dashboard index exposes direct header-inspection and dashboard-strict health booleans.
- [x] Dashboard index exposes producer, smoke-gate, and overall validation health booleans.
- [x] Dashboard index exposes validation unhealthy reasons with schema-checked reason enums.
- [x] Dashboard index reports fine-grained validation unhealthy reasons for missing producers, smoke gates, and coverage artifacts.
- [x] Dashboard index strict mode fails when aggregate validation health is false and reports unhealthy reasons.
- [x] Validation JSON schema checker validates dashboard health booleans against their component fields.
- [x] Dashboard index gates header-inspection health on format, negative, command, workflow, dictionary, optional-header, and FHCRC coverage counts.
- [x] Dashboard index gates validation health on sidecar corrupt-payload smoke artifacts.
- [x] Dashboard index gates validation health on Huffman length-limit oracle artifacts.
- [x] Dashboard index gates validation health on fuzz corpus report and coverage-smoke artifacts.
- [x] Dashboard index gates validation health on deflate decode-stage error-path smoke artifacts.
- [x] Dashboard index gates validation health on Python zlib differential smoke artifacts.
- [x] Dashboard strict-mode smoke covers sidecar corrupt, Huffman, fuzz, and decode-stage health failures with isolated negative fixtures.
- [x] Dashboard index surfaces dashboard strict expected/missing mode details.
- [x] Dashboard index surfaces aggregate dashboard strict coverage deltas.
- [x] Dashboard strict-mode smoke records actual-output truncation limit and truncation flag per check.
- [x] Dashboard strict-mode smoke records original actual-output length per check.
- [x] Dashboard strict-mode smoke exercises the actual-output truncation path with a synthetic long-output check.
- [x] Dashboard strict-mode smoke directly covers dashboard-strict self-health drift, including check/mode/expected-mode/missing-mode/validation-reason count mismatches, unmatched check rows, missing requirement deltas, and retained Markdown missing/unmatched rows.
- [x] Dashboard strict-mode smoke directly covers dashboard-configuration health drift, including config index, negative config/category smokes, required producer metadata, producer-negative guardrails, count mismatches, unmatched rows, and required smoke-gate coverage loss.
- [x] Dashboard strict-mode smoke directly covers validation JSON health drift, including checked/observed/unchecked schema drift, JSON artifact count and manifest floors, CLI result invariants, report/corrupt row floors, and docs-negative ok/count drift.
- [x] Dashboard strict-mode smoke directly covers Brotli static-dictionary health drift, including candidate/upstream/node/audit/negative/report count, CSV, Markdown, category, matrix, and duplicate-entry drift.
- [x] Dashboard strict-mode smoke directly covers LZ4/Zstd native stream summary floor drift, including frame, skippable, checksum, dictionary, content-size, block, raw-block, compressed-byte, payload-byte, and skippable-payload floors.
- [x] Dashboard strict-mode smoke directly covers zstd comparison gate and data-row drift, including compare/standard/sweep `ok` flags, data-row floors, missing Markdown companions, and sweep path/block-length metadata mismatches.
- [x] Dashboard strict-mode smoke covers every validation unhealthy reason with isolated negative fixtures.
- [x] Dashboard strict-mode validation unhealthy reason matrix is stored in a schema-checked external JSON config.
- [x] Dashboard strict-mode smoke directly covers native codec probe health drift, including probe ok/timeout/case-floor drift, probe count/case-sum mismatches, missing/duplicate probes, coverage/capability count/missing/duplicate drift, unhealthy capability rows, and Markdown unmatched rows.
- [x] Dashboard strict-mode smoke directly covers zlib relaxed health drift, including missing gate/Markdown artifacts, gate `ok` drift, gate check missing/extra/rule drift, every report exact/floor metric, and malformed/duplicate/unknown/value-mismatched Markdown metrics.
- [x] Dashboard strict-mode smoke directly covers Snappy report health drift, including missing/duplicate/unknown mode-case rows, positive timing/ratio/throughput drift, repetitive-ratio regressions, framed-overhead drift, and reusable checksum mismatches.
- [x] Dashboard strict-mode smoke directly covers PNG scratch health drift, including missing Markdown, report count drift, missing/duplicate/unknown cases, row accounting mismatches, stored/fixed streaming regressions, streaming-savings drift, and Markdown row drift.
- [x] Dashboard strict-mode smoke directly covers checksum benchmark health drift, including missing/duplicate/unknown algorithms, positive/workload/throughput row drift, and CRC32/CRC32C digest mix-group mismatches.
- [x] Dashboard strict-mode smoke directly covers chunk cursor benchmark health drift, including missing/duplicate/unknown case-kernel rows, positive/shape/throughput row drift, and checksum mismatches between current and optimized kernels.
- [x] Dashboard strict-mode smoke directly covers deflate match-copy benchmark health drift, including missing/duplicate/unknown case-kernel rows, positive/class/output/throughput row drift, and checksum mismatches across kernels.
- [x] Dashboard strict-mode smoke directly covers deflate Huffman build benchmark health drift, including missing/duplicate/unknown case-build rows, positive/lookup/throughput row drift, and checksum variant mismatches.
- [x] Dashboard strict-mode smoke directly covers deflate Huffman lookup benchmark health drift, including missing/duplicate/unknown case-decoder rows, positive/lookup/throughput row drift, and checksum mismatches across decoders.
- [x] Dashboard strict-mode smoke directly covers deflate chunked Huffman benchmark health drift, including missing/duplicate/unknown case-reader rows, positive/shape/buffered/chunk-count/throughput row drift, and checksum mismatches across readers.
- [x] Dashboard strict-mode smoke directly covers deflate extra-bit benchmark health drift, including missing/duplicate/unknown case-reader-kernel rows, positive/shape/throughput row drift, per-case checksum mismatches, and paired-kernel checksum mismatches.
- [x] Dashboard strict-mode smoke directly covers dictionary decode benchmark health drift, including missing/duplicate/unknown case-format-encoder-mode rows, positive/output-size/throughput row drift, and per-payload checksum mismatches.
- [x] Dashboard strict-mode smoke directly covers PNG scanline benchmark health drift, including missing/duplicate/unknown stage-bpp rows, positive/I/O/throughput row drift, and per-bpp checksum mismatches.
- [x] Dashboard strict-mode smoke directly covers chunked zlib benchmark health drift, including missing Markdown, missing/duplicate/unknown cases, positive/shape/chunk-count/ratio row drift, and Markdown row drift.
- [x] Dashboard strict-mode smoke directly covers PNG streaming zlib benchmark health drift, including missing/duplicate/unknown cases and positive/shape/image-size/chunk-count/ratio row drift.
- [x] Dashboard strict-mode smoke directly covers native allocation health drift, including report count/unbalanced/duplicate rows, zero/budget smoke mismatches and duplicate cases, negative-smoke unmatched rows, and Markdown malformed/duplicate/unknown rows.
- [x] Dashboard strict-mode smoke directly covers native fuzz corpus health drift, including report ok/mode/floor drift, summary row drift, report count/matched-row drift, coverage ok/floor/requirement mismatches, and Markdown unmatched rows.
- [x] Dashboard strict-mode smoke directly covers decode-stage health drift, including report/error count mismatches, internally consistent unmatched error rows, CSV positive/header/fixed/dynamic/stored row drift, CSV missing/duplicate/unknown cases, and Markdown unmatched rows.
- [x] Dashboard strict-mode smoke directly covers fuzz corpus health drift, including report ok/mode/floor drift, summary row drift, report count/matched-row drift, coverage ok/floor/requirement mismatches, and Markdown unmatched rows.
- [x] Dashboard strict-mode smoke directly covers dynamic-plan health drift, including missing sources, missing/duplicate/unknown paths, positive row drift, malformed rows, token-accounting mismatches, histogram/ratio drift, and bit-slack/wrapper invariants.
- [x] Dashboard strict-mode smoke directly covers compression level-report health drift, including missing Markdown, missing/duplicate/unknown rows, positive row drift, token accounting drift, ratio drift, roundtrip checksum drift, and Markdown summary/detail mismatches.
- [x] Dashboard strict-mode smoke directly covers Huffman length-report health drift, including missing Markdown, malformed/blank/duplicate cases, non-optimal rows, gap-bit drift, and Markdown summary/case mismatches.
- [x] Dashboard strict-mode smoke directly covers sidecar corrupt health drift, including missing Markdown, row floors, metadata/full rejection count drift, JSON item count/malformed/duplicate drift, Markdown row count drift, and unmatched/malformed/duplicate/unknown Markdown rows.
- [x] Dashboard strict-mode smoke directly covers header-inspect health drift, including report count mismatches, duplicate case/negative/command/workflow/required/help rows, command coverage missing/unknown/mismatch rows, negative error-count drift, missing-workflow drift, help/required workflow drift, and Markdown unmatched rows.
- [x] Dashboard strict-mode smoke directly covers Python zlib differential health drift, including top-level ok drift, payload/file/dictionary/malformed floors, raw-dictionary undercoverage, CLI success/failure floors, exact outcome mismatches, and coverage shortfalls.
- [x] Dashboard strict-mode smoke directly covers validation JSON smoke/docs-negative health drift, including observed-schema count mismatches, unchecked observed schemas, JSON artifact audit parse/missing-schema/manifest/accounting failures, and docs-negative row/count mismatches.
- [x] Dashboard strict-mode smoke directly covers non-JSON artifact manifest drift, including CSV file layout failures, CSV header membership/column/signature mismatches, Markdown file layout failures, Markdown heading membership/count/first-heading/signature mismatches, and Markdown table-row/separator-row count mismatches.
- [x] Validation JSON docs negative smoke catches dashboard strict config drift cases.
- [x] Dashboard producer-map negative smoke catches format, producer-step, and smoke-gate drift cases.
- [x] Dashboard producer-map required artifact matrix is stored in a schema-checked external JSON config.
- [x] Dashboard category smoke uses a schema-checked matrix covering validation, benchmark, corpus, native, and other artifacts.
- [x] Dashboard category negative smoke catches classifier, required-artifact, producer, and smoke-gate drift cases.
- [x] Dashboard external configuration index tracks config schemas, docs sections, consumers, and validation steps.
- [x] Dashboard config-index negative smoke catches missing paths, docs, build steps, consumers, and unchecked schemas.
- [x] Dashboard category smoke protects raw/zlib/gzip header inspection validation classification.
- [x] zlib stored-block preset-dictionary API validates DICTID before decode.
- [x] Public zlib stream inspector supports split input through caller-provided
  compressed join scratch, including preset-dictionary variants.
- [x] zlib preset-dictionary decode API validates DICTID and decodes dictionary back-references.
- [x] zlib preset-dictionary encoders emit FDICT/DICTID frames for stored/fixed/dynamic/best modes.
- [x] zlib preset-dictionary fixed/dynamic/best encoders seed LZ77 matching from preset history.
- [x] Dictionary deflate report quantifies raw/zlib preset-dictionary encode savings.
- [x] Raw/zlib preset-dictionary decode covers stored/fixed/dynamic block cases.
- [x] CLI and Python differential smoke cover raw/zlib preset-dictionary decode.
- [x] CLI and Python differential smoke cover raw preset-dictionary encode through Vort and Python zlib decoders.
- [x] CLI and Python differential smoke cover zlib preset-dictionary encode through Vort and Python zlib decoders.
- [x] File CLI and Python differential smoke cover zlib preset-dictionary decode.
- [x] File CLI and Python differential smoke cover zlib preset-dictionary one-shot/split/adaptive file encode.
- [x] CLI decode commands expose optional output limits for raw/zlib/gzip workflows.
- [x] README API sketch documents limited raw/zlib/gzip decode APIs.
- [x] raw/zlib CLI differential smoke rejects empty hex/file inputs.
- [x] File CLI and Python differential smoke cover zlib file decode with output limits.
- [x] zlib dictionary-file differential smoke rejects too-small output limits.
- [x] zlib concatenated stream decode support.
- [x] zlib concatenated stream decode supports caller-owned buffers, exact-size alloc, and explicit total output limits.
- [x] zlib concatenated stream decode supports preset dictionary members.
- [x] CLI and Python differential smoke cover zlib concatenated hex/file decode.
- [x] CLI and Python differential smoke cover dictionary-aware zlib concatenated hex/file decode.
- [x] File CLI exposes non-dictionary raw/gzip best encoders for differential harnesses.
- [x] zlib wrapper integration for fixed-Huffman blocks.
- [x] zlib wrapper integration for single final dynamic-Huffman blocks.
- [x] zlib wrapper integration for multi-block dynamic streams.
- [x] ZlibDecoder drains multi-filter RGB/RGBA PNG-like zlib-wrapped payloads through reusable caller-owned scratch and bounded output.
- [x] ZlibDecoder initializes from caller-provided zlib byte chunks for multi-IDAT-style PNG payloads without allocation.
- [x] ZlibDecoder join-scratch chunk initializers expose relaxed-option,
  exact-size, and preset-dictionary variants, matching the gzip chunked decoder
  API while preserving legacy compressed-join compatibility.
- [x] ZlibDecoder direct chunk initializers decode multi-IDAT-style zlib chunks
  without requiring a compressed join scratch buffer.
- [x] ZlibDecoder direct chunk initializers include strict, relaxed-option,
  exact-size, and preset-dictionary variants without compressed join scratch.
- [x] ZlibDecoder exposes single-buffer `WithOptions` initializers/resets for
  strict, exact-size, and preset-dictionary caller-scratch decode, matching the
  direct chunked relaxed-option surface.
- [x] ZlibDecoder exposes concatenated zlib initializers/resets with strict,
  relaxed-option, exact-size, and preset-dictionary variants for caller-scratch
  bounded output, aligning zlib multi-member workflows with `GzipDecoder`.
- [x] ZlibDecoder exposes chunked-input concatenated zlib initializers/resets,
  including relaxed-option, exact-size, and preset-dictionary variants using
  caller-provided compressed join scratch.
- [x] ZlibDecoder chunk smoke covers varied RGB/RGBA PNG-like rows across widths 1, 2, 8, and 17 with filters 0-4.
- [x] ZlibDecoder drains PNG-style scanlines one row at a time, returning filter bytes separately from caller-owned row payload buffers.
- [x] PNG scanline reconstruction supports filter methods 0-4 with caller-owned previous/current row buffers.
- [x] PngZlibScanlineDecoder packages chunked zlib IDAT decode and PNG row reconstruction into a caller-owned row pipeline.
- [x] PngStoredZlibScanlineDecoder reconstructs stored-deflate PNG scanlines,
  including chunked IDAT-style zlib streams, directly from the zlib frame
  without full decoded-payload scratch.
- [x] PngStreamingZlibScanlineDecoder and PngStreamingZlibChunkedScanlineDecoder
  reconstruct non-interlaced contiguous/chunked zlib PNG scanlines for
  fixed/dynamic Huffman IDAT streams without full decoded-payload scratch, using
  caller-owned 32 KiB DEFLATE history plus row scratch.
- [x] Adam7 fixed/dynamic PNG helpers stream contiguous and chunked zlib payloads
  through the same 32 KiB history window, reconstructing and placing pass rows
  without full decoded-payload scratch.
- [x] Adam7 streaming row decoders expose reconstructed pass rows directly for
  high-level PNG transform consumers that do not want a full raw-sample image
  intermediate.
- [x] PngZlibScanlineDecoder and PNG-like image helpers expose direct chunk
  decode variants that avoid compressed join scratch while preserving caller-owned
  zlib row/output buffers.
- [x] PNG-like direct chunk helpers expose relaxed-option variants for
  checksum/trailing-tolerant integrations without compressed join scratch.
- [x] PNG scanline metadata helper derives row bytes, filter stride, and exact zlib payload length from IHDR-style width/height/bit-depth/color-type values.
- [x] PNG-like zlib image helper reconstructs IDAT chunks into caller-owned full-image buffers without allocation.
- [x] PNG zlib decode buffer-size helpers expose caller-owned scratch/output lengths and cover sub-byte indexed/grayscale-style rows.
- [x] PNG Adam7 metadata planning reports per-pass dimensions, row bytes, filtered payload bytes, and scratch/output preflight sizes.
- [x] PNG Adam7 placement scatters reconstructed pass rows into byte-aligned and sub-byte packed final image buffers without allocation.
- [x] PNG-like Adam7 zlib image helper reconstructs interlaced IDAT chunks into caller-owned final image buffers.
- [x] PNG-like Adam7 zlib image helper covers packed 2-bit indexed interlaced full-image reconstruction without allocation.
- [x] PNG-like Adam7 zlib image helper covers 16-bit RGBA interlaced full-image reconstruction without allocation.
- [x] PNG-like Adam7 zlib image helper rejects corrupt filters and decoded payload length mismatches without allocation.
- [x] PNG-like zlib image helpers reject bad zlib headers, truncated frames, and Adler mismatches without allocation.
- [x] PNG-like chunked zlib image helpers explicitly reject wrapper-only no-payload and reserved first raw-DEFLATE block inputs across scratch-backed, direct, and Adam7 streaming paths.
- [x] PNG scratch footprint report records caller-owned zlib/row/output memory baselines for non-interlaced and Adam7 PNG-like paths.
- [x] ZlibDecoder chunk initialization supports preset dictionary zlib streams without allocation.
- [x] ZlibDecoder exact-size initializers reject decoded-size mismatches for PNG/IHDR-sized buffers.
- [x] ZlibDecoder reports bad-header, missing-dictionary, truncated-footer, and Adler mismatch diagnostics.
- [x] gzip wrapper and CRC/ISIZE verification for stored blocks.
- [x] Gzip allocator-returning unknown-size decode validates the gzip header before trusting trailer ISIZE as an allocation hint, avoiding attacker-controlled allocation attempts on malformed headers.
- [x] Gzip allocator-returning stored-block decode validates footer availability, ISIZE, and trailing-data boundaries from the stored-block plan before allocating output, preserving strict errors without unnecessary heap work.
- [x] Zlib allocator-returning stored-block decode validates footer availability and trailing-data boundaries from the stored-block plan before allocating output, matching the gzip no-allocation strict-boundary behavior.
- [x] Zlib/gzip exact-size allocator-returning decode validates wrapper headers before allocating the caller-declared output size, preserving malformed-header errors without heap work.
- [x] Zlib/gzip concatenated exact-size allocator-returning decode validates the first wrapper header before allocating the caller-declared output size, matching single-member no-allocation malformed-header behavior.
- [x] Zlib chunked exact-size allocator-returning decode validates the chunked wrapper header before allocating the caller-declared output size, preserving bad-header errors without heap work.
- [x] Zlib/gzip stored-specific exact-size allocator-returning decode validates wrapper headers before allocating output, aligning stored convenience APIs with the general exact-size no-allocation malformed-header path.
- [x] Zlib/gzip allocator-returning stored-block decode computes wrapper checksums directly from stored payload bytes before allocating output, preserving checksum errors without heap work.
- [x] Zlib/gzip stored-specific exact-size allocator-returning decode uses the stored-block plan to validate expected length and wrapper checksums before allocating output.
- [x] General zlib/gzip exact-size allocator-returning decode also uses stored-block plans for stored frames, rejecting expected-length and checksum mismatches before allocating output.
- [x] Zlib chunked allocator-returning decode applies a stored-block cursor precheck before allocating output, covering exact-size, unknown-size, and limited variants across contiguous and split stored chunks.
- [x] Zlib chunked allocator-returning decode rejects wrapper-only inputs with no DEFLATE payload before allocating output, covering exact-size, unknown-size, and limited variants across split chunks with zero-allocation TruncatedFrame tests.
- [x] Zlib chunked allocator-returning decode rejects a reserved first raw-DEFLATE block type before allocating output, covering exact-size, unknown-size, and limited variants across split chunks with zero-allocation malformed-block tests.
- [x] Zlib chunked allocator-returning dictionary variants share the wrapper-only and reserved first raw-DEFLATE block prechecks, covering exact-size and unknown-size split-dictionary chunks with zero-allocation tests.
- [x] ZlibDecoder chunked direct exact-size initialization reports wrapper-only no-payload and reserved first raw-DEFLATE block errors consistently with allocator-returning chunked zlib paths, including dictionary variants.
- [x] Raw stored allocator-returning decode uses the stored-block plan to reject limit, exact-length, and trailing-data errors before allocating output.
- [x] Raw auto allocator-returning decode uses the stored-block plan for stored frames with or without preset dictionaries, rejecting limit, exact-length, and trailing-data errors before allocating output.
- [x] Zlib/gzip concatenated allocator-returning decode prechecks all-stored member sequences, rejecting aggregate length, limit, and member checksum errors before allocating output across exact-size, unknown-size, and limited variants.
- [x] gzip optional header fields: FEXTRA, FNAME, FCOMMENT, FHCRC validation.
- [x] gzip encoders can emit configurable MTIME/XFL/OS plus FEXTRA/FNAME/FCOMMENT/FHCRC metadata while preserving deterministic defaults.
- [x] Public gzip header metadata parser exposes MTIME/XFL/OS/FEXTRA/FNAME/FCOMMENT/FHCRC slices for library callers.
- [x] Public gzip header metadata parser supports split input through
  caller-provided compressed join scratch.
- [x] Public gzip member inspector supports split input through
  caller-provided compressed join scratch.
- [x] GzipDecoder drains validated gzip-wrapped deflate payloads and caller-provided gzip byte chunks through reusable caller-owned scratch and bounded output.
- [x] Public gzip chunked caller-buffer helpers decode split gzip input through
  caller-provided compressed join scratch, including relaxed CRC/ISIZE/trailing
  options.
- [x] Public gzip chunked allocator-returning helpers cover unknown-size,
  exact-size, output-limited, and relaxed-option variants over caller-provided
  compressed join scratch.
- [x] Legacy chunked wrapper helpers borrow a single non-empty compressed chunk directly, avoiding an unnecessary join copy and scratch-size requirement for already-contiguous chunk callers.
- [x] GzipDecoder drains concatenated gzip members, including empty middle members, from caller-owned scratch and chunked compressed input.
- [x] GzipDecoder exposes `WithOptions` initializers/resets for single-member, concatenated, and chunked caller-scratch decode so trusted streaming users can opt into relaxed CRC/ISIZE/trailing-data handling without switching to allocation-returning APIs.
- [x] Public gzip concatenated chunked helpers cover caller-buffer,
  allocator-returning, exact-size, output-limited, and relaxed-option workflows
  over caller-provided compressed join scratch.
- [x] GzipDecoder exact-size initializers reject decoded-size mismatches before payload drain.
- [x] GzipDecoder reports bad-header, truncated-frame, CRC, and ISIZE diagnostics through the shared streaming diagnostics surface.
- [x] CLI gzip header inspection prints parsed metadata for hex/file workflows.
- [x] CLI gzip header inspection supports schema-checked JSON output.
- [x] gzip wrapper integration for fixed-Huffman blocks.
- [x] gzip wrapper integration for single final dynamic-Huffman blocks.
- [x] gzip wrapper integration for multi-block dynamic streams.
- [x] gzip concatenated member decode support.
- [x] gzip concatenated member decode supports explicit total output limits.
- [x] gzip concatenated member decode supports caller-owned output buffers.
- [x] gzip concatenated decoders preserve later members after an empty middle member.
- [x] gzip concatenated decoders reject corrupt third members after an empty middle member.
- [x] gzip concatenated decoders reject empty input as truncated data.
- [x] gzip CLI differential smoke rejects empty gzip hex/file inputs.
- [x] raw/zlib/gzip CLI differential smoke rejects header-only truncated inputs.
- [x] zlib/gzip CLI differential smoke rejects missing footer/trailer inputs.
- [x] raw/zlib/gzip CLI differential smoke rejects trailing garbage inputs.
- [x] gzip CLI differential smoke rejects corrupt or truncated second concatenated members.
- [x] Decode-stage dashboard fails its smoke step when representative raw/zlib/gzip error paths drift from expected errors.
- [x] File CLI and gzip differential smoke cover gzip file decode with output limits.
- [x] File CLI and gzip differential smoke cover concatenated gzip file decode.
- [x] gzip differential smoke rejects too-small file output limits.
- [x] Stored-block vectors checked against Python/zlib level-0 output.
- [x] Black-box differential smoke against Python zlib.
- [x] Black-box differential smoke against system gzip CLI.
- [x] Match-heavy dynamic/split/adaptive differential vectors.
- [x] Python zlib dynamic/adaptive match-heavy differential vectors.
- [x] System gzip CLI dynamic/adaptive match-heavy differential vectors.
- [x] zlib-family harness verifies Vort dynamic/adaptive outputs through zlib.
- [x] zlib-family harness verifies raw/zlib split-best match-heavy outputs.
- [x] Local external implementation/tool availability probe.
- [x] Optional zlib-ng/zlib-rs differential harness with explicit skip reporting.
- [x] Built zlib-ng minigzip differential test running in local validation.
- [x] zlib-rs gzip corpus differential decode coverage.
- [x] Built zlib-rs compress example differential test running in local validation.
- [x] CI zlib-rs binary differential test.
- [x] External probe discovers local fdeflate and miniz_oxide checkouts as Rust deflate baselines.
- [x] External probe reports git revisions for local compressor checkouts.
- [x] fdeflate/miniz_oxide path-dependency differential smoke runs through Cargo and Vort CLI.
- [x] fdeflate/miniz_oxide differential smoke covers raw deflate encode/decode API directions where exposed.
- [x] fdeflate/miniz_oxide differential smoke verifies Vort raw/gzip file encoder output.
- [x] fdeflate/miniz_oxide decode-throughput smoke benchmark runs through Cargo.
- [x] Rust deflate decode benchmark reports Vort/fdeflate/miniz_oxide rows in one CSV.
- [x] Rust deflate decode benchmark documentation requires ReleaseFast Vort rows.
- [x] Rust deflate decode benchmark performs warmup decodes before timing.
- [x] Rust deflate decode benchmark includes raw-deflate Vort/miniz_oxide rows to isolate wrapper overhead.
- [x] Rust deflate encode benchmark reports Vort/fdeflate/miniz_oxide size and throughput rows.
- [x] Rust deflate encode benchmark reports multiple Vort level presets.
- [x] Rust deflate encode benchmark includes a Vort best preset row for strongest-size tracking.
- [x] Rust deflate encode benchmark records per-row iteration counts for slow best-preset rows.
- [x] Rust deflate encode benchmark includes a Vort fixed-fast row to isolate best-selection overhead.
- [x] Rust deflate encode benchmark includes a Vort dynamic-default row to isolate dynamic encoder cost.
- [x] Rust deflate encode benchmark includes a Vort dynamic-literal row to isolate literal-only wrapper cost.
- [x] Rust deflate encode benchmark includes Vort split/adaptive rows to isolate wrapper block-planning overhead.
- [x] Rust deflate encode benchmark includes raw-deflate Vort/fdeflate/miniz_oxide rows to isolate wrapper overhead.
- [x] Rust deflate encode benchmark includes raw fastest/fast/default/best and split/adaptive rows for fair raw core speed/size tracking.
- [x] Rust deflate encode benchmarks include overlap-RLE, distance-heavy, and dynamic-match payloads.
- [x] Rust deflate encode benchmarks include deterministic incompressible payloads.
- [x] Vort zlib encode benchmark exposes a dynamic-literal mode for literal-only wrapper timing.
- [x] Rust deflate benchmark CSV artifact steps write decode and encode rows to zig-out.
- [x] Dashboard index tracks Rust deflate benchmark CSV artifacts.
- [x] Dashboard index reports CSV benchmark row counts.
- [x] Rust deflate benchmarks include real README/roadmap payloads.
- [x] Rust deflate decode benchmarks include overlap-RLE, distance-heavy, and dynamic-match payloads.
- [x] Rust deflate decode benchmarks include stored binary payloads.
- [x] Rust deflate benchmark Markdown summary includes geomean gap overview rows.
- [x] Rust deflate benchmark Markdown summary highlights weakest cases in overview rows.
- [x] Rust deflate benchmark Markdown summary highlights Vort vs Rust gaps.
- [x] Rust deflate benchmark Markdown summary reports raw-deflate decode ratios against miniz_oxide.
- [x] Rust deflate benchmark summary reports exact-size decode allocation overhead.
- [x] Rust deflate benchmark Markdown summary reports raw-deflate encode ratios against Rust baselines.
- [x] Rust deflate benchmark summary reports Vort default-vs-dynamic encode overhead.
- [x] Rust deflate benchmark summary reports Vort split/adaptive encode speed and size ratios.
- [x] Rust deflate benchmark summary reports Vort default and best-preset size ratios against Rust.
- [x] Rust deflate benchmark summary flags benchmark-only rows with high size overhead.
- [x] Rust deflate decode/encode benchmark scripts accept `--repeat N` and
  report median elapsed rows, with discoverable `repeat3` Zig build steps for
  less noisy optimization decisions without slowing default smoke steps.
- [x] Deflate decode stage report accepts `--repeat N` and selects a median-ish
  raw/zlib/gzip stage row by aggregate elapsed score for less noisy local
  wrapper/decode hotspot investigations.
- [x] Deflate decode stage report has a repeat3 CSV build step wired into the
  Rust repeat3 benchmark summary so decode-stage evidence and Rust comparison
  evidence use matching repeat semantics.
- [x] Lazy parser scan/hash heuristic uses a trigram sketch to avoid split-default source/text slow paths.
- [x] Minimal literal-only dynamic Huffman encoder for raw/zlib/gzip, verified by Python zlib.
- [x] zlib/gzip dynamic-literal wrappers preserve the literal-only raw deflate stream.
- [x] Dynamic Huffman encoder with LZ77 match support, verified by Python zlib.
- [x] Dynamic Huffman encoder code-length RLE using symbols 16/17/18.
- [x] Frequency-weighted tree Huffman length builder used by dynamic encoder.
- [x] Frequency-weighted tree Huffman length builder used by dynamic code-length alphabet.
- [x] Block cost selection across stored/fixed/dynamic encoders.
- [x] Raw fixed multi-block encoder with final/non-final block splitting.
- [x] Raw dynamic multi-block encoder with final/non-final block splitting.
- [x] Raw split-best encoder selecting stored/fixed/dynamic per bounded block.
- [x] zlib/gzip split-best wrappers verified by Python zlib.
- [x] Adaptive split-best raw/zlib/gzip wrappers verified by Python zlib.
- [x] Fixed-Huffman bit-cost selector for stored-vs-fixed block decisions.
- [x] Dynamic-Huffman bit-cost selector avoiding materialized dynamic candidates for block decisions.
- [x] One-shot best encoder reuses a single LZ77 token plan across stored/fixed/dynamic selection.
- [x] One-shot best encoder reuses dynamic Huffman coding plans between cost and write.
- [x] Dynamic Huffman plan report exposes LZ77/token and code-length planning stats.
- [x] Dynamic Huffman plan report includes stats/dynamic/best encode timings.
- [x] Dynamic Huffman plan report can write a CSV artifact for dashboard tracking.
- [x] Dynamic Huffman plan report includes size and timing ratio diagnostics.
- [x] Dynamic Huffman plan report compares default and best-preset token/size ratios.
- [x] Dynamic Huffman plan report includes match length/distance shape diagnostics.
- [x] Dynamic Huffman plan report breaks down header/literal/match/extra bit cost ratios.
- [x] Dynamic Huffman plan report separates length-extra and distance-extra bit cost ratios.
- [x] Dynamic Huffman plan report emits length/distance extra-bit bucket histograms.
- [x] Dynamic Huffman plan report emits length/distance symbol histograms.
- [x] Rust deflate benchmark summary displays length/distance extra-bit bucket histograms.
- [x] Rust deflate benchmark summary highlights largest length/distance symbol histogram deltas.
- [x] Huffman tree length builder uses sorted-leaf/internal-node queues instead of repeated full scans.
- [x] Huffman tree length builder preserves unbounded depths before deterministic length-limit redistribution.
- [x] Huffman length-limit report records small brute-force oracle cases for package-merge replacement work.
- [x] Huffman length-limit report generates multiple deterministic oracle families and summarizes optimality gaps.
- [x] Huffman length-limit report compares a package-merge candidate against brute-force oracles.
- [x] Production Huffman length builder uses package-merge length-limited code generation.
- [x] Production package-merge Huffman builder has large DEFLATE-alphabet regression coverage.
- [x] Production package-merge Huffman builder uses widened internal counters with final length assertions.
- [x] Huffman length-limit dashboard summarizes production-sized alphabet Kraft and determinism checks.
- [x] Huffman length-limit dashboard records production-sized alphabet generation timing.
- [x] Rust benchmark summary includes Huffman length-limit oracle totals when available.
- [x] Dynamic HCLEN trimming helper with boundary tests.
- [x] Dynamic HLIT/HDIST trimming helpers with boundary tests.
- [x] Adaptive split search using stored/fixed/dynamic bit-cost candidates.
- [x] Level-specific adaptive split policy config and report coverage.
- [x] Adaptive split policy size-delta report across built-in corpora.
- [x] Adaptive split policy report covers default and filtered strategies.
- [x] Adaptive split policy report accepts ad-hoc file corpora.
- [x] Adaptive split policy report across bounded Silesia files.
- [x] Adaptive split encoder falls back to one-shot best output when smaller.
- [x] Production dynamic Huffman encoder with optimized block splitting and block-type decisions.
- [x] Compatibility benchmark smoke suite comparing Vort/gzip/zstd on sample files.
- [x] Standard-corpus smoke benchmark comparing Vort/gzip/zlib-ng/zlib-rs/zstd.
- [x] Full local Silesia corpus benchmark mode.
- [x] Per-file Silesia suite automation against gzip/zlib-ng/zlib-rs/zstd.
- [x] External path/directory benchmark suite mode for additional corpora.
- [x] External tar-archive benchmark suite mode for packed standard corpora.
- [x] Discoverable multi-standard-corpus benchmark dashboard automation.
- [x] Discoverable corpus dashboards support row limits for smoke automation.
- [x] Full-mode discoverable multi-standard-corpus benchmark dashboard automation.
- [x] Discoverable multi-standard-corpus CSV suite automation.
- [x] Full-mode discoverable multi-standard-corpus CSV suite automation.
- [x] Full compatibility benchmark suite automation across multiple standard corpora.

## Milestone 4: compression performance foundation

- [x] Match finder interfaces, scalar reference matcher, and hash-chain matcher.
- [x] Greedy LZ77 parser experiment with deterministic options and replay tests.
- [x] Lazy greedy LZ77 parser experiment with deterministic options.
- [x] Optimal LZ77 parser prototype with deterministic options.
- [x] Fixed-Huffman bit-cost model for optimal LZ77 parser decisions.
- [x] Optimal LZ77 parser evaluates multiple match-distance candidates.
- [x] Fixed encoder parser strategy config selecting greedy/lazy/optimal prototypes.
- [x] Compression strategy config selecting default, filtered, Huffman-only, and RLE plans.
- [x] Strategy-specific parser knob normalization for filtered/Huffman-only/RLE modes.
- [x] Compression level presets for fast/default/best strategy configs.
- [x] Fast preset skips dynamic block candidate generation.
- [x] Fastest preset with shallow hash-chain search for speed.
- [x] Fastest preset can select dynamic Huffman blocks while retaining the
  shallow hash-chain search, improving source/text compression ratio for
  speed-oriented corpus dashboards without changing the parser budget.
- [x] Tuned fastest preset's shallow parser budget to a 16 KiB window, six-entry
  hash-chain scan, and 96-byte match cap so speed-oriented Silesia/source
  dashboards keep better matches without moving to the heavier fast preset.
- [x] Hash-chain parsers spend their match-check budget on viable prefix
  candidates with a bounded walk cap, reducing collision waste for shallow
  fastest/dictionary searches while preserving parser runtime limits.
- [x] Best raw/zlib/gzip one-shot encoders compare against production default
  and filtered parser outputs and keep the smaller frame, preventing fixed-cost
  optimal parsing from regressing dynamic Huffman size on mixed payloads.
- [x] Dynamic literal-only blocks omit unused distance code lengths, shrinking
  headers for Huffman-only and literal-only zlib/gzip/raw deflate payloads while
  remaining valid for streams that never decode a distance symbol.
- [x] Audited a decoder-side literal-only dynamic shortcut that skipped distance
  setup entirely; rejected it after ReleaseFast A/B showed caller-buffer raw/gzip
  regressions despite some exact-size gains.
- [x] Allocating inflate paths use a smaller capacity hint for tiny compressed
  frames, reducing over-reservation and shrink work for small API/CLI payloads
  while keeping the larger capped expansion hint for real compressed data.
- [x] Small raw allocating decode first tries the caller-buffer decoder against
  stack scratch and then copies into an exact owned slice, reducing ArrayList
  growth/shrink overhead for tiny dynamic/fixed raw DEFLATE members.
- [x] Compression-level report validating parser/cost-model settings and round trips.
- [x] Compression-level report exposes incompressible stored fast-path decisions.
- [x] Compression-level report accepts ad-hoc file corpora.
- [x] Compression-level report exposes token mix, match coverage, fixed bit density, and size-ratio diagnostics.
- [x] Compression-level report can write a dashboard-indexed CSV artifact.
- [x] Compression-level report can write a Markdown dashboard for human review.
- [x] Compression-level Markdown dashboard summarizes best raw/adaptive rows per case.
- [x] Level-specific optimal parser match-candidate limits.
- [x] Ratio-oriented `.best` preset uses a measured 256-candidate optimal
  parser budget with a larger custom cap for experiments, improving weak
  source/binary corpus sizes without applying the full deep-search cost to
  production best-level callers.
- [x] Level-specific lazy parser gain thresholds.
- [x] Default lazy parser accepts one-byte lazy gains to improve binary/source default-size competitiveness against Rust fdeflate/miniz_oxide baselines.
- [x] Level-specific minimum match length parser setting.
- [x] Level-specific minimum match savings parser setting.
- [x] Level-specific maximum match length parser setting.
- [x] Level-specific match window parser setting.
- [x] Production optimal parser with full level/strategy configs.
- [x] Optimal parser stops hash-chain candidate scanning once a candidate
  already reaches the maximum match length for that position, preserving ratio
  while avoiding pointless deeper walks on long exact repeats.
- [x] zlib-style numeric compression-level helpers for raw/zlib/gzip encoders,
  including stored level 0 and 1..9 option mapping for callers such as PNG
  encoders that expose numeric DEFLATE levels.
- [x] Backward-scan LZ77 parser uses word-at-a-time match length for repeated/text payload speed.
- [x] Lazy hash parser uses a stack-resident tiny-input table for source/text chunks below one deflate window.
- [x] Huffman code generation, simple length building, and canonical-code validation.
- [x] Decompression hot-path smoke benchmarks for raw/zlib/gzip fixed and dynamic samples.
- [x] Deflate decode hot-path benchmark reports allocator-returning,
  exact-size allocation, and caller-buffer rows for each raw/zlib/gzip sample,
  separating allocation overhead from inflate-core throughput.
- [x] Deflate decode hot-path benchmark includes dynamic-block stage rows for
  header inspection and total caller-buffer decode, exposing how much small
  dynamic streams spend before payload copying.
- [x] Dynamic decode stage benchmark breaks small dynamic blocks into length
  parsing, literal-table construction, distance-table construction, payload
  decode, and total caller-buffer timing to identify the next hot path.
- [x] Dynamic Huffman length parsing writes directly into literal/distance
  arrays, avoiding the combined temporary buffer and final split copies.
- [x] Huffman table initialization records active symbols during length
  validation and builds canonical entries from that compact list, avoiding a
  second full-length scan for sparse dynamic alphabets.
- [x] Huffman table initialization groups canonical decode entries by bit
  length, so dynamic/fallback decoders scan only entries that can match the
  current code width instead of rescanning the full active alphabet.
- [x] Huffman table initialization uses the target's bit-reverse primitive for
  canonical code reversal, removing the per-symbol bit loop in dynamic table
  construction.
- [x] Huffman table initialization returns immediately for empty alphabets,
  avoiding fixed validation/setup loops for literal-only dynamic distance tables.
- [x] Dynamic literal/length decoding uses a 9-bit fast lookup table, cutting
  per-block lookup construction for small dynamic streams while preserving the
  fallback path for longer canonical codes.
- [x] Dynamic deflate block decode uses a `FastDecoder.decodeValue` path for
  literal/length and distance symbols, avoiding Symbol struct construction when
  only the numeric symbol is needed in hot loops.
- [x] `FastDecoder.decodeValue` now returns directly from the lookup fast path,
  avoiding the internal Symbol construction used by full decode metadata calls.
- [x] `FastDecoder.decodeValue` now also has a value-only long-code fallback,
  so dynamic literal/distance misses avoid constructing Symbols after the fast
  lookup path has already selected the first viable code width.
- [x] `HuffmanTable.decodeValue` provides the same value-only path for long-code
  fallback decoding, so FastDecoder fallback misses also avoid Symbol materialization.
- [x] `HuffmanTable.decodeValue` now returns directly from its table scan rather
  than routing through the full Symbol-returning helper, reducing long-code
  fallback overhead.
- [x] Huffman fallback scans rely on bit-length bucket boundaries and no longer
  re-check each candidate entry's bit width inside the hot loop.
- [x] FastDecoder construction skips zeroing the lookup table when short codes
  fully cover it, cutting setup work for complete dynamic literal/distance
  alphabets while preserving fallback entries for incomplete tables.
- [x] FastDecoder construction now optimistically fills lookup entries first and
  only clears/refills when short codes do not fully cover the table, avoiding an
  extra coverage pass for complete dynamic alphabets.
- [x] FastDecoder lookup construction writes exact-width codes directly instead
  of running the replicated-entry fill loop once, shaving setup work for dense
  dynamic lookup tables.
- [x] Dynamic literal/length decode selects a 9-bit lookup for very short-code
  blocks and an 11-bit lookup otherwise, preserving tiny-block setup wins without
  regressing larger corpus decode throughput.
- [x] Dynamic length parsing records the literal alphabet's maximum code length
  so adaptive literal lookup selection avoids a second per-block scan.
- [x] Dynamic length parsing also records the distance alphabet's maximum code
  length, and raw header inspection reuses the parsed literal/distance maxima
  instead of rescanning for max-bit diagnostics.
- [x] Dynamic code-length decoding uses the value-only Huffman fast path,
  avoiding Symbol construction while parsing literal/distance code lengths.
- [x] Huffman fast lookup hits advance bit readers through an availability
  check plus unchecked offset update, avoiding the full `skipBits` path in
  dynamic literal/distance hot loops for contiguous and chunked readers.
- [x] Bit readers' `readBits` hot path now uses `hasBits` plus unchecked advance
  directly, avoiding an extra `skipBits` call after the padded peek for dynamic
  header, extra-bit, and fallback Huffman reads.
- [x] FastDecoder long-code misses resume decoding at the first width beyond
  the lookup table and stop at the table's recorded maximum code length,
  avoiding redundant short-code rescans on text-heavy dynamic Huffman blocks;
  latest Rust deflate summary shows zlib caller-buffer decode geomean at 0.949
  of the best Rust row and raw caller-buffer decode geomean at 1.411 of
  miniz_oxide after this optimization.
- [x] FastDecoder lookup hits trust `peekBitsPadded`'s width mask and avoid a
  redundant lookup-index mask in both full-symbol and value-only decode paths.
- [x] Fixed-Huffman lookup decoders now share the same unchecked-advance hot
  path and expose value-only helpers for raw/zlib/gzip fixed blocks, cutting
  Symbol materialization and the legacy `skipBits` path; latest Rust deflate
  summary shows zlib caller-buffer decode geomean at 1.006 of the best Rust row.
- [x] Overlapping match replay seeds one history window and then doubles the
  initialized output prefix for medium/long matches, replacing the previous
  byte-at-a-time loop while preserving DEFLATE overlap semantics.
- [x] Complex dynamic literal alphabets can select a 12-bit fast lookup,
  improving repeat3 zlib decode geomean on text-heavy blocks while retaining
  9-bit lookup for tiny alphabets and 11-bit lookup for ordinary dynamic blocks.
- [x] Raw allocating decode uses a bounded stack scratch caller-buffer fast
  path for compressed members up to 8 KiB that expand within 64 KiB, reducing
  ArrayList growth/shrink overhead for common small/medium exact-owned decode
  calls while falling back to the streaming allocator path for larger expansion.
- [x] zlib allocating decode can validate small/medium non-stored members
  directly into bounded stack scratch before copying the exact owned slice,
  reusing the parsed zlib header, the buffered bit reader, and skipping
  redundant stored-only probing while preserving the streaming fallback for
  larger expansion.
- [x] Stored-only caller-buffer decode and wrapper checksum validation now copy
  and hash in one pass instead of planning stored blocks first, reducing
  repeated scans for exact-size zlib/raw/gzip stored decode paths.
- [x] Stored-only allocating wrapper decode validates block headers first and
  then computes Adler-32/CRC-32 while copying validated payload bytes, avoiding
  a second full payload read before returning the owned output slice.
- [x] Default deflate LZ77 search budget increased modestly (`max_chain=160`,
  `nice_len=80`, `max_candidates=6`) to recover a smaller distance-heavy
  dynamic stream while keeping the production preset below best/optimal cost.
- [x] Dynamic plan diagnostics can run on the built-in Rust benchmark samples,
  making `distance-heavy` and `dynamic-match` header/token bit gaps visible
  without adding expensive header-search heuristics to production encoding.
- [x] Dynamic plan diagnostics report bit-boundary slack for default and best
  dynamic streams, making near-byte-size wins visible before changing encoder
  heuristics.
- [x] Dynamic deflate header RLE treats literal and distance code lengths as
  one RFC-1951 sequence, so zero runs crossing the HLIT/HDIST boundary can use a
  single repeat opcode instead of restarting at the distance alphabet.
- [x] Length/distance decode handles no-extra-bit symbols through direct
  hot-path formulas, avoiding table lookup and zero-bit reader calls for the
  most common short matches while preserving RFC table decoding for longer
  symbols.
- [x] Contiguous raw/zlib/gzip inflate now uses a buffered bit reader for
  caller-buffer and allocating auto-decode paths, reducing repeated input-window
  reloads in Huffman and extra-bit hot loops while retaining the scalar reader
  for chunked inputs and inspection helpers.
- [x] Buffered contiguous inflate now stages a 32-bit word whenever its bit
  reservoir falls below the requested Huffman width, following the larger
  reservoir strategy used by image-png's `fdeflate` backend while preserving
  logical bit/byte offsets and strict tail truncation checks. A same-machine
  ReleaseFast imx Lohengrin decode-into A/B moved the repeat3 median from
  `158.54` to `214.38` MiB/s (`+35.2%`, `0.279x` to `0.377x` versus the local
  image-png Criterion result).
- [x] No-dictionary caller-buffer inflate has specialized fixed/dynamic block
  loops and direct output-offset match copy, avoiding per-match dictionary
  boundary checks on the common PNG/source/text path.
- [x] Chunked zlib/PNG IDAT bit reads keep a forward chunk cursor and copy
  aligned spans per chunk, avoiding repeated scans from the first IDAT chunk
  during Huffman peeks and stored-block reads.
- [x] Chunked zlib benchmark report compares contiguous, join-then-decode, and
  direct chunked decode on PNG-like payloads, including tiny/empty IDAT-style
  chunks and a repeat3 build step for optimization evidence.
- [x] Direct chunked stored-block reads and zlib footer checks avoid repeated
  cursor resynchronization/offset rescans, improving tiny IDAT-style stored
  chunk decode evidence in the chunked zlib repeat3 report.
- [x] Small highly fragmented zlib chunks can use a bounded stack-join fast
  path to reuse the contiguous buffered inflater for dynamic/tiny IDAT streams
  without requiring caller-provided compressed scratch.
- [x] Dynamic deflate decode profile reports literal/distance fast-table lookup
  coverage and table size, making sparse lookup-table setup costs visible beside
  fast-hit/miss ratios before changing Huffman initialization policy.
- [x] Dynamic deflate decode profile classifies match replay bytes into RLE,
  small-distance, non-overlapping memcpy, and overlapping copy categories, so
  match-copy work can target the corpus shape actually dominating a weak case.
- [x] Dynamic deflate decode profile attributes length/distance extra-bit reads
  and bit counts to the same RLE/small-distance/non-overlap/overlap match
  classes, keeping copy-path and bitreader costs separable in weak cases.
- [x] Focused DEFLATE extra-bit reader microbenchmark/gate covers 1/3/5/9/13-bit
  reads on contiguous buffered and chunked readers, so bitreader A/Bs can be
  measured before touching production inflate loops.
- [x] ChunkedBitReader fill batching for extra-bit reads was measured and
  rejected when the focused gate showed most chunked widths regressing, preserving
  the existing per-byte staged cursor fill.
- [x] Distance-code formula decode was measured and rejected when README
  repeat3 raw/zlib/gzip rows regressed despite synthetic text/binary gains,
  preserving the table-based distance decoder.
- [x] Non-overlap match-copy small-length and branch-order experiments were
  measured and rejected when README/roadmap/dynamic-match repeat3 probes were
  mixed or regressed, keeping the existing copy order until a stronger corpus-
  specific variant appears.
- [x] Focused DEFLATE match-copy microbenchmark/gate compares current,
  non-overlap-first, and small-unrolled kernels across RLE, small-distance,
  non-overlapping, and overlapping cases before production copy-path changes.
- [x] FastDecoder sparse-table initialization experiments were measured and
  rejected when repeat3 decode-stage probes were mixed/negative, preserving the
  existing table setup while retaining coverage counters for a narrower future
  optimization.
- [x] PNG streaming zlib scanline decoders batch pending DEFLATE matches directly
  into row buffers and use the vectorized Adler helper for longer batches,
  avoiding the old per-byte match emission path on repetitive IDAT payloads.
- [x] PNG streaming zlib dynamic literal decode selects a 9-bit FastDecoder for
  <=9-bit literal alphabets while capping complex PNG streaming blocks at the
  previous 11-bit resident state; a longer ReleaseFast PNG row-streaming A/B
  kept a small geomean throughput win and rejected the larger 12-bit streaming
  decoder variant as mixed/noisy for image workloads.
- [x] Tried direct-dispatching PNG streaming `readInflatedBytes` around
  `readInflatedByteOrEnd`, but rejected it after ReleaseFast repeat5 row
  benchmarks showed mixed results and sub-1.0 geomean throughput, especially on
  chunked small-distance/RLE rows.
- [x] PNG streaming zlib scanline benchmark report covers contiguous/chunked RLE,
  small-distance, repeated-row dynamic, and fixed payloads with a schema/value
  gate for future row-streaming hot-path changes.
- [x] Larger decompression hot-path benchmarks across built-in text/structured/binary corpora.
- [x] Fixed-Huffman raw deflate encoder backed by greedy LZ77 tokens.
- [x] zlib/gzip fixed-Huffman encoder wrappers.
- [x] Built-in small-corpus compression ratio report.
- [x] File-path compression ratio report for ad-hoc corpora.
- [x] zstd CLI compressed-size comparison smoke for sample files.
- [x] File-path compression/decompression throughput report for ad-hoc corpora.
- [x] Markdown file-corpus throughput dashboard for ad-hoc corpora.
- [x] File-corpus throughput dashboard includes average encode/decode throughput.
- [x] File-corpus throughput dashboard expands directory inputs recursively.
- [x] File-corpus throughput dashboard expands tar archive inputs.
- [x] File-corpus throughput dashboard discovers standard corpora.
- [x] File-corpus throughput dashboard supports row limits for smoke automation.
- [x] Silesia-sample standard corpus benchmark smoke.
- [x] Automated per-file Silesia throughput report.
- [x] Markdown benchmark dashboard export for Silesia suite.
- [x] Standard corpus Markdown dashboard per-codec summary totals.
- [x] Standard corpus report records Vort fastest, default, and best zlib rows side
  by side, so speed-oriented, production-default, and strongest-ratio presets
  are compared against gzip, zlib-ng, zlib-rs, and zstd without relying on a
  single proxy row.
- [x] Standard corpus benchmark accepts `--progress`, printing per-case stderr
  progress so long Silesia/standard-corpus dashboard runs are observable instead
  of appearing hung.
- [x] External file/directory throughput dashboard input mode.
- [x] External tar-archive throughput dashboard input mode.
- [x] Full-size Silesia Markdown dashboard export.
- [x] Full-size Silesia Markdown dashboard forwards external path/limit args.
- [x] Automated throughput dashboards across multiple full standard real corpora.

## Milestone 5: native Vort format research

- [x] Initial design note for native block/frame layout.
- [x] Dictionary IDs and training-plan metadata.
- [x] Deterministic n-gram dictionary training prototype.
- [x] Dictionary trainer retains higher-value phrase candidates after candidate cap.
- [x] Dictionary training metadata/report validation.
- [x] Dictionary training coverage and baseline ratio validation report.
- [x] Dictionary match scanner and coverage summary API for future encoder integration.
- [x] Dictionary patch codec prototype with round-trip validation and ratio report.
- [x] Compact dictionary patch op encoding for lower frame overhead.
- [x] Native dictionary-patch frame prototype requiring caller dictionary on decode.
- [x] Deflate-wrapped native dictionary patch frame candidate.
- [x] Dictionary-aware native best-frame selection with fallback to non-dictionary modes.
- [x] Dictionary-aware blocked native stream with indexed range decode.
- [x] Self-contained native dictionary stream embeds trained dictionary for indexed range decode.
- [x] Self-contained native dictionary stream can use external sidecar index.
- [x] Trained dictionary stream best-selection API with automatic range decode.
- [x] Compression report includes trained dictionary stream selection metrics.
- [x] CLI smoke for trained dictionary best stream auto range decode.
- [x] Dictionary training and patch report accepts ad-hoc file corpora.
- [x] Dictionary training and patch report across bounded Silesia files.
- [x] Per-file dictionary training and patch report for bounded Silesia files.
- [x] Markdown dictionary corpus dashboard for bounded Silesia files.
- [x] Dictionary report supports target-size tuning.
- [x] Dictionary corpus dashboard supports target-size sweeps.
- [x] Production dictionary training integrated into encoder with ratio/throughput gains.
- [x] Splittable/seekable frame index range decode API.
- [x] Embedded skippable index frame for seekable native store streams.
- [x] Native VORT deflate-compressed frame flag and generic decode path.
- [x] Native RLE compressed frame mode prototype beyond deflate.
- [x] Native best frame selection across store/deflate/RLE.
- [x] Native frame mode summary for validating block-mode selection.
- [x] Embedded index range decode for native deflate-compressed frames.
- [x] Embedded index range decode for native LDM reference frames.
- [x] CLI smoke for indexed native LDM range decode and mode summary.
- [x] Native range report accepts ad-hoc file corpora.
- [x] Native range report accepts configurable range offset/length.
- [x] Native range report can sweep multiple offsets per stream.
- [x] Native range report covers external sidecar index range decode.
- [x] Native range report validates sidecar indexes before range decode.
- [x] Sidecar index range decode rejects tampered checksums.
- [x] Sidecar index verifier API and file CLI.
- [x] Sidecar verifier report for stream/index file pairs.
- [x] Sidecar verifier report discovers .vort/.vidx pairs in directories.
- [x] Markdown sidecar verifier report with aggregate totals.
- [x] JSON sidecar verifier report with aggregate totals.
- [x] Sidecar verifier report supports row limits for directory smoke runs.
- [x] Sidecar verifier report supports keep-going error classification.
- [x] Native range report covers self-contained dictionary streams.
- [x] Native range report covers sidecar-indexed self-contained dictionary streams.
- [x] CLI/range report coverage for blocked native LDM selection.
- [x] Blocked native deflate stream with embedded index and range decode.
- [x] Blocked native best-mode stream with embedded index and range decode.
- [x] Blocked native best-mode stream with external sidecar index and range decode.
- [x] CLI smoke for blocked best stream with external sidecar index.
- [x] File CLI encode/decode for blocked best stream with external sidecar index.
- [x] File CLI encode/decode for self-contained dictionary stream with external sidecar index.
- [x] File CLI encode/decode for LDM stream with external sidecar index.
- [x] Production seekable native format integration with native block modes.
- [x] Long-distance matching scanner experiment.
- [x] Long-distance matching summary integrated into compression reports.
- [x] Long-distance-match-aware block planner annotations.
- [x] Skippable long-distance summary metadata embedded in native blocked streams.
- [x] Native blocked stream planning aligns blocks to long-distance match starts.
- [x] Prototype native LDM reference frame with opt-in best-frame selection.
- [x] Blocked native best stream can opt into long-distance frame selection.
- [x] Blocked native LDM stream can use external sidecar index.
- [x] CLI/range report coverage for sidecar-indexed native LDM streams.
- [x] Native LDM frame size and selection metrics in compression report.
- [x] Production long-distance matching integration into native/block encoder.
- [x] Deterministic block planning metadata for future multi-threaded encoding.
- [x] Deterministic block-planned encoder execution API.
- [x] Parallel multi-threaded encoder execution with deterministic output order.
- [x] Fixed worker-count thread-pool encoder scheduling.
- [x] Work-queue encoder scheduling with deterministic output order.
- [x] Parallel/thread-pool/work-queue worker-count edge-case tests.
- [x] Native parallel/thread-pool/work-queue encoder benchmark smoke.
- [x] Native parallel/thread-pool/work-queue benchmark accepts real file corpora.
- [x] Native parallel/thread-pool/work-queue benchmark accepts configurable worker counts.
- [x] Native parallel/thread-pool/work-queue benchmark across bounded Silesia files.
- [x] Native parallel/thread-pool/work-queue Markdown dashboards for bounded/full Silesia.
- [x] Native parallel/thread-pool/work-queue dashboard accepts external path/tar corpora.
- [x] Native parallel/thread-pool/work-queue full dashboard accepts external path/tar corpora.
- [x] Native parallel/thread-pool/work-queue dashboard discovers standard corpora.
- [x] Native parallel/thread-pool/work-queue full dashboard discovers standard corpora.
- [x] Native parallel/thread-pool/work-queue dashboard per-mode throughput summaries.
- [x] Native parallel/thread-pool/work-queue dashboard worker-count sweeps.
- [x] Native parallel/thread-pool/work-queue dashboard configurable block length.
- [x] Production thread-pool encoder benchmarking across full standard real corpora.
- [x] Added a focused DEFLATE Huffman table-build benchmark/gate covering literal, distance, and code-length alphabets so FastDecoder setup cost is visible before table-construction changes.
- [x] Added a focused DEFLATE Huffman lookup benchmark/gate covering fixed literals/distances, code-length symbols, dynamic mixed/long-tail literal alphabets, and dynamic distance alphabets across compact-table and FastDecoder lookup widths 5/8/9/11/12.
- [x] Added a chunked Huffman decode benchmark/gate covering fixed literals and dynamic literal fast tables over buffered, 4 KiB, 64-byte, and 1-byte chunked readers to expose combined reader/Huffman costs.
- [x] Extended the chunked Huffman benchmark/gate with coalesced 4 KiB/64-byte/1-byte rows, measuring the contiguous-buffer upper bound for bounded refill/coalescing designs before touching production chunked inflate.
- [x] Added joined 4 KiB/64-byte/1-byte chunked Huffman benchmark rows that include per-iteration copy cost, bracketing the practical cost/benefit of bounded refill or chunk coalescing.
- [x] Added `windowed1024_*` chunked Huffman benchmark rows for a naive 1 KiB refill-window prototype; kept it as evidence-only because the first smoke did not reliably beat the current chunked reader.
- [x] Added `windowed4096_*` rows for the same naive refill-window prototype at 4 KiB; kept it evidence-only as well because larger windows were still mixed and did not close the gap to joined/coalesced rows.
- [x] Added `span_*` chunked Huffman benchmark rows for a per-chunk slice/local-offset reader prototype; results are benchmark-only but show a stronger production-candidate direction than the naive windowed refill rows.
- [x] Tried a small production `ChunkedBitReader.fill` staged-local offset patch inspired by the span benchmark, but rejected it because chunked Huffman was mixed and chunked zlib literal/match/stored direct rows regressed.
- [x] Added an isolated `ChunkedSpanBitReader` production candidate for chunked zlib direct decode, preserving the existing reader while using per-chunk span/local-offset state for non-stored Huffman paths; local A/B improved literal and match-heavy true chunked-reader rows while keeping stored-direct neutral.
- [x] Routed PNG streaming chunked zlib decode through `ChunkedSpanBitReader`, improving most split-IDAT streaming rows in local A/B while keeping the existing generic chunked reader available.
- [x] Optimized PNG streaming small-distance pending-match copy by seeding the short pattern and doubling for longer copies, improving the small-distance dynamic split-IDAT benchmark row without moving other PNG streaming rows materially.
- [x] Tested lowering the PNG small-distance seed-and-doubling threshold from 16 to 8 bytes, but rejected it because the short smoke did not improve small-distance and regressed row-repeat dynamic.
- [x] Routed chunked zlib allocating unknown-size decode through `ChunkedSpanBitReader` as well, preserving allocation-count coverage while sharing the faster span reader with owned-output callers.
- [x] Removed the duplicate chunk-length scan in `ZlibDecoder` direct chunked reset paths by reusing the frame length computed before direct decode.
- [x] Tested localizing `ChunkedSpanBitReader.fill` state into stack variables, but rejected it after mixed zlib direct results and a clear PNG streaming regression.
- [x] Optimized generic FastDecoder availability checks to reuse the bit reservoir staged by the preceding padded peek, reducing buffered/chunked reader hot-path overhead while preserving truncated-input rejection tests; fixed Huffman specialized helpers remain on direct `hasBits` after noisy fixed-code A/B rows.
- [x] Added a known-total ChunkedBitReader initializer and routed chunked zlib/PNG decode paths through it when they already have compressed length, avoiding duplicate chunk-length scans in true chunked-reader setup.
- [x] Optimized chunked zlib footer validation to read the common final Adler-32 from tail chunks with the already-known total length, preserving split-footer and empty-chunk correctness.
- [x] Tested skipping stored-direct probing for non-stored large chunked zlib streams by reusing the first block-type byte, but rejected it after literal, match-heavy, and stored-direct rows were mixed to negative.
- [x] Narrowed dynamic literal lookup selection so blocks with literal max bits <=9 use the cheaper 9-bit lookup table while max-bit-10 blocks keep the 11-bit table after a broader <=10 experiment regressed the binary repeat3 row.

- [x] Optimized FastDecoder initialization to use lookupCoverage for full-table detection, preserving the no-memset path for fully-covered fixed-style tables while avoiding duplicate fillLookup work on partial dynamic tables.

- [x] Tried switching the production dynamic distance FastDecoder from 8-bit to 5-bit lookup to reduce setup cost, but reverted it because `run-deflate-dynamic-decode-profile-gate` failed the distance lookup-size expectation and exposed much higher distance miss pressure on the roadmap row (coverage 31/32, miss ratio about 3.74%). Keep the 8-bit distance lookup policy until a strategy can preserve profile coverage and repeat3 decode results.
- [x] Cleaned dynamic decode profiling for zero-extra distance symbols by matching the production distance fast path for symbols 0..3, removing a profile-only 0-bit read before future extra-bit evidence comparisons.
- Optimized PNG streaming zlib pending matches for overlapping distances greater
  than four bytes by seeding one distance window from the DEFLATE history ring and
  then doubling within the caller row buffer, matching the caller-owned inflate
  match-copy strategy instead of replaying byte-by-byte. Added ring-wrap unit
  coverage for the pending-match row helper. ReleaseFast A/B on
  `run-png-streaming-zlib-bench-report -- --repeat 3 --iterations 800` against
  the pre-change path moved the row-repeat dynamic/fixed rows from about
  `153.33` / `154.61` MiB/s to about `1208.80` / `1224.76` MiB/s for contiguous
  decode and from about `153.63` / `152.97` MiB/s to about `1174.51` /
  `1177.64` MiB/s for chunked decode, while RLE/small-distance rows stayed in
  the same throughput class.

- Added explicit ReleaseFast throughput floors to `run-png-streaming-zlib-bench-report-gate` for the repeated-row dynamic and fixed PNG streaming rows. The floor is deliberately conservative (`700` MiB/s for contiguous and chunked rows) but high enough to catch a regression back to the old byte-at-a-time overlapping-match path, which measured around `153` MiB/s before the row-buffer doubling optimization.
- Optimized dictionary-backed allocating raw/zlib inflate so matches whose
  distance is fully inside the current output history use the same bulk
  small-distance, memcpy, or overlapping doubling copy paths as no-dictionary
  inflate. Only matches that still reach back into the preset dictionary keep the
  byte-at-a-time dictionary fallback. Added fixed/dynamic token coverage where
  the first match seeds from the preset dictionary and the next overlapping match
  replays from decoded history, and verified the existing dictionary-deflate
  report still round-trips built-in raw/zlib dictionary cases.
- Added `run-dictionary-decode-bench-gate`, a ReleaseFast preset-dictionary decode
  throughput CSV/gate for raw dynamic, raw best, zlib fixed, and zlib dynamic
  streams over history-replay, JSON-prefix, and log-prefix fixtures, including
  allocator-returning, exact-size allocator, and caller-buffer decode modes where
  applicable. The benchmark protects the new
  dictionary-backed history-only bulk match-copy path with automatic throughput
  and round-trip validation, and the CSV is registered in dashboard producer
  metadata.
- Tightened the dictionary decode benchmark's caller-buffer rows so `into` modes reuse one caller-owned output buffer across iterations instead of allocating inside the timed loop. This makes the benchmark better reflect application-owned decode buffers and keeps allocator-returning, exact-size, and caller-buffer dictionary decode rows comparable under the same gate.
- Optimized preset-dictionary inflate matches that still start in the dictionary prefix by seeding the contiguous virtual-history window (`dictionary ++ history`) into the destination and then doubling from the initialized output prefix. This removes the remaining byte-at-a-time dictionary replay for long initial dictionary-overlap matches while preserving the history-only bulk-copy path added earlier. Added direct caller-buffer and allocating helper coverage, and made `run-dictionary-decode-bench-gate` enforce throughput floors only for non-Debug/ReleaseFast runs so ordinary `zig build check` remains a correctness smoke.
- Optimized PNG streaming zlib history recording for wide scanlines and long pending DEFLATE matches by skipping bytes that will be overwritten inside the 32 KiB history ring before any later symbol can reference them. The streaming decoder now records only the retained tail window while preserving final history cursor semantics for both contiguous and chunked PNG zlib row decoders. Added direct tail-window unit coverage plus a `png-stream-wide-rle-dynamic` ReleaseFast benchmark/gate row so wide PNG rows cannot regress to copying every emitted byte through the history ring.

- Refreshed the Rust deflate gap snapshot after a local ReleaseFast `run-rust-deflate-benchmark-summary-repeat3` run. The decode rows improved materially versus the previous ledger (`zlib decode into` geomean now `1.258`, `raw decode into` now `2.069`), while compression-size gaps remain centered on `distance-heavy` and `dynamic-match`. A code-length RLE policy-selection experiment was tested against README/roadmap dynamic-plan rows and not kept because it did not reduce emitted bytes or header bits on those tracked cases.
- Optimized PNG scanline reconstruction in `vort` for None and Up filters. None now returns after an alias-safe copy/no-op, and Up uses a 32-byte vector add when a previous row is present while preserving in-place Adam7 row reconstruction. Added a `png-stream-up-filter-dynamic` benchmark/gate row and ReleaseFast floors so both imx/vort PNG row streaming and future scanline changes keep coverage for non-filter0 Up rows.
- Added a `png-stream-sub-filter-dynamic` benchmark/gate row to keep PNG streaming coverage for non-filter0 Sub rows. A direct Sub reconstruction fast-path experiment was measured and not kept because it did not produce a robust ReleaseFast win over the existing generic predictor loop, so the row is coverage-only for now rather than a throughput floor.

- Added PNG streaming zlib benchmark/gate rows for Average and Paeth filtered scanlines (`png-stream-average-filter-dynamic` and `png-stream-paeth-filter-dynamic`). These are coverage-only rows for now, complementing the existing Sub row, so future predictor-specific optimizations have direct evidence before any production rewrite is kept.
- Added an Average-specific PNG scanline reconstruction path in `vort`, splitting filter 3 out of the generic predictor loop while preserving alias-safe/in-place behavior. The `png-stream-average-filter-dynamic` row measured about `1.190x` contiguous and `1.019x` chunked in a same-machine ReleaseFast A/B, so the row now has conservative ReleaseFast floors while Sub/Paeth remain coverage-only rows.
- Added `run-png-scanline-bench-gate`, a focused PNG scanline reconstruction microbenchmark/gate for filter methods None/Sub/Up/Average/Paeth across bpp 1/2/3/4/6/8. This isolates predictor work from zlib streaming so future Average/Paeth rewrites can be accepted or rejected on direct evidence instead of end-to-end proxy rows.
- Added ReleaseFast throughput floors to `run-png-scanline-bench-gate` for the optimized Up and Average scanline rows. Debug builds still validate only structure/correctness so `zig build check` remains a smoke gate, while ReleaseFast protects the vector Up path and Average-specific path from regressing to generic predictor-loop throughput.
- Added a Paeth bpp=1 PNG scanline reconstruction path for indexed and low-bit-depth grayscale payloads, preserving alias-safe Adam7 in-place row reconstruction. Alternating same-machine ReleaseFast A/B runs of the focused scanline benchmark moved Paeth bpp=1 median throughput from about `222.37` to `281.94` MiB/s (`+26.79%`), so the scanline gate now enforces a low-noise ReleaseFast floor for that row while leaving broader Paeth bpp values coverage-only.
- Split wider PNG Paeth scanline reconstruction out of the generic predictor loop for RGB/RGBA-style rows while preserving in-place Adam7 behavior. The focused scanline A/B showed Paeth bpp=4/6/8 median gains around `+27.85%` / `+24.28%` / `+24.36%`, and the new `png-stream-paeth-rgba8-dynamic` end-to-end row improved contiguous/chunked medians from about `385.37` / `374.97` MiB/s to `523.11` / `505.76` MiB/s. The streaming gate now tracks that RGBA Paeth row with conservative ReleaseFast floors.
- Split PNG Sub scanline reconstruction out of the generic predictor loop and add fixed bpp=1/4/8 left-neighbor vector steps. Focused ReleaseFast scanline rows moved Sub bpp=1/4/8 from old evidence around `917.55` / `865.89` / `1124.76` MiB/s to about `3437.59` / `2250.69` / `4351.40` MiB/s, while bpp=2/3/6 remain on the scalar Sub loop after fixed-vector variants were noisy. The scanline gate now carries conservative Sub ReleaseFast floors.
- Added fixed-bpp Paeth dispatch for bpp=3/4/6/8 to remove the byte-stride loop check from RGB/RGBA-style Paeth rows. Short ReleaseFast scanline A/B kept the strongest signal on bpp=4/6/8, moving representative rows from about `554.68` / `561.18` / `575.05` MiB/s to about `708.27` / `738.92` / `713.77` MiB/s; bpp=3 was positive but treated as lower-confidence evidence. The scanline gate now also protects Paeth bpp=8 with a conservative floor.
- Optimized whole-image PNG zlib drainers so decoded image paths use the
  already-written destination row as the next row's PNG predictor input instead
  of copying every reconstructed row into the public row-iteration
  `previous_row_scratch`. A follow-up moved full-image filtered row storage into
  the destination row too: zlib history/checksum accounting happens while the
  row still holds filtered bytes, then PNG reconstruction runs in place. The
  public `step` APIs still maintain their scratch because callers may reuse one
  output row buffer; only full-image drain helpers take the no-copy path. Local
  imx ReleaseFast stage evidence moved the PNG `decode-into` comparison to about
  `297.85` MiB/s against Rust image-png's `1010.02` MiB/s (`0.295x`
  aggregate), with the matching stage breakdown reporting `decode-into` at about
  `298.30` MiB/s and `dynamic-decode` at about `274.95` MiB/s.
- Routed PNG streaming dynamic literal decoding through the same 9/11/12-bit
  lookup-width policy as the general dynamic inflater. Real PNG IDAT profiling
  showed high literal lookup pressure on near-full long alphabets, and the
  12-bit streaming path improved the imx ReleaseFast `decode-into` total from
  the recent `292.11` MiB/s artifact to `300.16` MiB/s, with `filtered-inflate`
  at `291.70` MiB/s. The Vort PNG streaming zlib gate still passes, including
  row-repeat, wide-RLE, Up/Average/Paeth rows.
- Added a contiguous `decodePngZlibImageWithOptions` helper and matching
  `PngZlibScanlineDecoder` options initializer. This lets PNG callers keep
  `ignore_adler`/`allow_trailing_data` behavior without wrapping a single IDAT
  payload as a one-element chunked stream, preserving the direct contiguous zlib
  decode path for full-image PNG drainers.
- Reworked full-image PNG zlib drains to reconstruct directly from the decoded
  zlib scratch row into the final image row. The public scanline step API still
  copies into caller row storage first, but whole-image drain helpers now skip
  the extra filtered-row copy before unfiltering. Local imx ReleaseFast evidence
  stayed roughly neutral after the larger contiguous-helper win (`decode-into`
  about `352.91` MiB/s, `0.349x` aggregate versus image-png), so this mainly
  keeps the full-drain dataflow simpler for the next zlib/unfilter pass.
- Added a direct filter-0 branch inside the full-image PNG zlib drain so None
  rows copy straight from decoded zlib scratch into the final image row without
  entering the generic scanline reconstruction function. This slightly improved
  the local imx ReleaseFast `decode-into` comparison (`356.25` MiB/s,
  `0.353x` aggregate), with Lohengrin around `142.27` MiB/s.
- Optimized dynamic Huffman FastDecoder setup for nearly-covered lookup tables.
  When every lookup slot is either covered by a short code or is a long-code
  fallback prefix, initialization now fills short-code entries and clears only
  the long prefixes instead of memseting the whole table. This targets PNG IDAT
  blocks like Lohengrin whose literal lookup coverage is close to full; local imx
  ReleaseFast `decode-into` moved to about `359.30` MiB/s (`0.354x` aggregate)
  with Lohengrin around `145.56` MiB/s.
- Extended the dynamic DEFLATE profile with Huffman table signature reuse
  counters (`unique`, `repeated`, and consecutive repeats). This keeps decoder
  cache ideas evidence-based: imx's PNG zlib profile can now show whether many
  dynamic blocks actually reuse identical literal/distance tables before any
  production cache is attempted.
- Added a single-symbol dynamic distance decoder variant. Dynamic distance
  alphabets with one active symbol no longer build an 8-bit lookup table and
  instead validate/consume that one canonical code directly; Lohengrin's PNG IDAT
  profile uses only distance symbol 0 in its dynamic blocks. Local imx
  ReleaseFast `decode-into` moved to about `361.72` MiB/s (`0.358x` aggregate),
  with Lohengrin around `149.15` MiB/s.
- Rechecked stored-binary allocation/wrapper weak paths after the decode-stage ledger identified `stored-binary` as a decode-alloc gap. Rejected a single-pass stored-only allocator rewrite because it regressed raw/zlib/gzip alloc rows in the focused probe, and rejected enabling the existing x86 IEEE CRC-32 hardware path because a scalar/table differential check failed. Keep future work focused on a correct faster CRC-32 path, exact-size stored wrapper APIs, or allocation policy instead of repeating those experiments.
- Extended the deflate decode-stage report with explicit raw/zlib/gzip stored allocator throughput and stored-vs-generic allocation time ratios. This keeps the `stored-binary` wrapper weakness visible separately from generic decode alloc rows and from caller-buffer stored copy speed.

- Added a portable IEEE CRC-32 slice-by-32 implementation, exposed it through `crc32Slice32`, switched `crc32Best` to dispatch to it on portable/x86 builds, and wired gzip stored-only wrapper fast paths to the same wider table state while leaving the unvalidated x86 PCLMUL path disabled. Local ReleaseFast checksum smoke moved CRC-32 best from about `2493.10` to `2971.17` MiB/s with matching scalar/slice digest mixes, and the stored-binary decode-stage row now reports gzip/gzip-stored alloc around `1609.57` / `1622.22` MiB/s, directly targeting the gzip stored/wrapper CRC-bound gap.

- Extended the checksum benchmark/gate with CRC-32 slice-by-32 segmented update rows at 64/256/1024/4096 byte batches. These rows model future gzip streaming CRC fusion without changing production inflate paths, exposing the minimum batch size needed to avoid the rejected per-symbol CRC update overhead.

- Added a portable CRC-32C slice-by-32 implementation, exposed `crc32cSlice32`, included it in the checksum benchmark CSV, and made it the non-hardware `crc32cBest` fallback while preserving SSE4.2 hardware dispatch when available. Local ReleaseFast checksum smoke on the same 1 MiB benchmark reported `crc32c-slice32` around `2967.36` MiB/s versus the previous portable `crc32c-slice16` baseline around `2478.71` MiB/s; hardware `crc32c-best` remains faster on this machine at about `10099.78` MiB/s.

- Added stored-only fast paths for concatenated zlib and gzip members in both caller-buffer and allocator-returning APIs. Stored members now append/copy while computing the per-member Adler-32/CRC-32 instead of materializing then re-reading the member payload for trailer validation; `bench-deflate-decode` now carries `zlib-concat-stored-{alloc,exact,into}` and `gzip-concat-stored-{alloc,exact,into}` rows, with the latest local ReleaseFast smoke around zlib `18228.62` / `23057.08` / `24119.46` MiB/s and gzip `2594.14` / `2876.94` / `2901.15` MiB/s.

- Added an exact-size trailer-ISIZE fast path for `decodeGzipStoredAlloc`, letting ordinary stored gzip members allocate the final output slice once and validate/copy/CRC in the caller-buffer stored decoder instead of first planning stored blocks into an owned result. The latest local ReleaseFast decode-stage smoke reports `stored-binary` gzip exact/gzip stored rows around `1629.90` / `1627.90` MiB/s while preserving checksum, ISIZE, trailing-data, and allocation-failure coverage.

- Moved the `decodeGzipStoredAlloc` trailer-ISIZE fast path behind the stored-block plan precheck. Stored-specific gzip allocating decode now validates CRC-32, ISIZE, trailing-data boundaries, and output limits before heap allocation, while still using the single-copy fast path for ordinary members whose ISIZE exactly matches the planned output length.

- Routed exact-size stored zlib/gzip allocation paths through the already-validated stored-block plan. Stored-specific and general exact-size wrappers now copy planned stored payload bytes directly after checksum/size/boundary precheck instead of re-running wrapper decode over the same member.

- Extended the stored-plan reuse to unknown-size and output-limited zlib/gzip allocator-returning decode paths. Single-member all-stored wrappers now validate checksum, size, and trailing policy before allocation, then copy planned stored payload bytes once instead of recomputing wrapper hashes during allocation.

- Routed raw stored allocator-returning decode through the same validated stored-block plan used by wrapper paths. Raw stored unknown-size, exact-size, and output-limited APIs now reject trailing/size/limit errors before allocation and copy planned stored payload bytes once instead of re-running stored decode after preflight.

- Refreshed ReleaseFast decode-stage evidence for the stored-plan reuse work after including the raw stored allocator paths. The local repeat3 `stored-binary` row now reports raw stored alloc/exact/into around `3746.44` / `3775.82` / `43776.01` MiB/s, zlib stored alloc/exact/into around `3282.02` / `3194.62` / `17584.83` MiB/s, and gzip stored alloc/exact/into around `1601.41` / `1575.41` / `2656.78` MiB/s. Stored allocation ratios remain near neutral in this smoke (`raw=0.9769`, `zlib=0.9910`, `gzip=1.0167`; exact ratios `1.0078` / `0.9734` / `0.9838`).

- Gzip allocator-returning decode now rejects a reserved first raw-DEFLATE block type before trusting trailer ISIZE or caller-declared exact sizes for allocation, covering both unknown-size and exact-size APIs with zero-allocation malformed-block tests.

- Zlib allocator-returning decode now applies the same reserved first raw-DEFLATE block precheck before owned-output allocation, covering unknown-size and exact-size APIs with zero-allocation malformed-block tests.

- Raw allocator-returning auto decode now rejects a reserved first raw-DEFLATE block type before owned-output allocation, covering unknown-size, dictionary, exact-size, and output-limited APIs with zero-allocation malformed-block tests.

- Raw exact-size allocator-returning auto decode now rejects empty input before allocating the caller-declared output length, matching the unknown-size TruncatedFrame behavior with zero-allocation tests for dictionary and non-dictionary APIs.

- Zlib/gzip exact-size allocator-returning decode now rejects wrapper-only inputs with no DEFLATE payload before allocating the caller-declared output length, adding zero-allocation TruncatedFrame tests for both wrappers.

- Zlib/gzip concatenated exact-size allocator-returning decode now applies the same wrapper-only no-payload precheck before allocating the caller-declared output length, covering the first concatenated member with zero-allocation TruncatedFrame tests.

- Zlib/gzip concatenated exact-size allocator-returning decode now also rejects a reserved first raw-DEFLATE block type before allocating the caller-declared output length, covering the first concatenated member with zero-allocation malformed-block tests.

- Zlib/gzip concatenated unknown-size and output-limited allocator-returning decode now share the same first-member reserved raw-DEFLATE block precheck before ArrayList growth, with zero-allocation malformed-block tests.

- Extended the dynamic deflate decode profile CSV and gate with match-class extra-bit density columns (`*_extra_bits_per_match` and `*_extra_bits_per_byte`). The latest README/roadmap profiles show non-overlap matches spend about `7.946` / `9.824` extra bits per match and `0.612` / `0.970` extra bits per non-overlap byte, giving the next dynamic-decode work a clearer target than repeating rejected distance-formula or branch-order experiments.

- Added README/roadmap mixed distance-extra distributions to `run-deflate-extra-bits-bench-gate`, derived from the dynamic decode profile width histograms. The first local ReleaseFast gate shows span 4 KiB rows around `227.61` / `241.66` Mreads/s versus legacy chunked `145.07` / `176.11` Mreads/s for those mixed distributions, making real text-heavy extra-bit reader costs visible before production bitreader changes.

- Added README/roadmap mixed length-extra distributions to the same extra-bit
  benchmark/gate, derived from the dynamic profile length width histograms
  (`1026;216;191;125;20;2` and `7435;1982;709;291;31;0`). This keeps the
  recently rejected length-extra staged-reader idea measurable as first-class
  `current`/`staged` benchmark rows instead of relying on noisy end-to-end
  decode-stage probes; the gate now checks that staged/current checksums
  match and prints median-of-3 staged/current geomean/min/max ratios so
  reader microbenchmarks preserve bitstream semantics while exposing
  production-candidate signal.

- Extended `run-deflate-extra-bits-bench-gate` again with README/roadmap distance-symbol-plus-extra distributions, so it now measures a closer proxy for production distance decode rather than only raw extra-bit reads. The first local ReleaseFast gate shows 4 KiB span rows around `207.36` / `204.05` Mreads/s versus legacy chunked `144.98` / `138.96` Mreads/s for README/roadmap symbol+extra streams.

- Rejected a production hot-distance-symbol switch for symbols `12/13/20/22/24/26/28` after the new mixed distance+extra benchmark suggested a target. The ReleaseFast repeat3 README probe improved some rows, but `docs/roadmap.md` regressed (`~313.27/300.05/308.80` MiB/s baseline raw/zlib/gzip caller-buffer versus `~269.45/266.90/270.21` MiB/s with the switch), so future distance decode work should look for a narrower fused path rather than symbol-specific branching in `decodeDistance`.

- Extended the dynamic deflate profile with distance Huffman code-bit accounting, total distance code+extra bits, and match-class distance code+extra density. The latest README/roadmap rows show non-overlap distance fields costing about `11.707` / `13.703` bits per match including Huffman code bits, which helps separate Huffman-symbol cost from extra-bit reader cost before designing a fused distance decode path.

- Added a benchmark-only `fused18` kernel to the mixed distance-symbol-plus-extra rows, using a single staged peek/advance for the extra bits after the 5-bit distance symbol proxy. The first local ReleaseFast gate improved buffered README/roadmap rows from `315.81` / `318.52` to `321.30` / `327.20` Mreads/s and 4 KiB span rows from `167.72` / `167.19` to `181.60` / `175.56` Mreads/s, suggesting a future production fused distance API may be worth designing carefully.

- Added a narrow production helper for distance extra-bit reads that uses the staged peek/advance path after distance symbol decode, without changing length decoding or introducing symbol-specific branches. ReleaseFast repeat3 README/roadmap probes were mixed-positive overall, and the chunked zlib plus PNG streaming zlib gates passed, so this keeps the safer fused-extra signal while avoiding the rejected hot-distance-symbol switch.

- Extended `DynamicDecodeProfile` with a full-deflate-stream profile helper that can walk stored, fixed, and dynamic blocks while accumulating output and match-class totals. The older first-dynamic-block helper remains for narrow probes, but PNG IDAT diagnostics now use the full-stream surface so large multi-block files such as Lohengrin are not characterized by their first block alone.

- Tried extending the same staged extra-bit helper to length extra bits, but did
  not keep it. A short ReleaseFast repeat3 candidate improved some
  README/roadmap caller-buffer rows, yet the same sample regressed README
  `gzip_into` and showed mixed binary/structured behavior; the immediate
  rollback probe also showed enough variance that the change was not
  corpus-safe evidence. Keep length extra-bit reads on the generic reader path
  until a broader A/B proves consistent wins across raw/zlib/gzip and binary
  dynamic rows.

- Retried a narrower production length-extra staged helper only in the no-dictionary caller-buffer dynamic block path after the median-of-3 extra-bit gate turned positive. It was rejected because ReleaseFast decode-stage repeat3 still regressed end-to-end rows: README `gzip_into` fell from about `553.72` to `436.26` MiB/s, structured `gzip_into` from about `2180.39` to `1817.18` MiB/s, and several exact-size rows were mixed. Keep the staged length-extra path benchmark-only until a variant proves raw/zlib/gzip caller-buffer and wrapper rows together.

- Added `GzipDecodeOptions`, `decodeGzipWithOptions`, allocator-returning `decodeGzipAllocWithOptions*`, and concatenated `decodeGzipConcatenated*WithOptions` APIs, mirroring the zlib relaxed decode surface with `ignore_crc32`, `ignore_isize`, and `allow_trailing_data`. Default gzip decode behavior remains strict, while future wrapper/checksum profiling can now separate DEFLATE payload cost from trailer validation without private test hooks across single-member and concatenated streams. A narrow production experiment that updated `Crc32Slice32` per literal/match span in single-member caller-buffer gzip was rejected because the call granularity overwhelmed the avoided final scan; keep future CRC fusion batched by decoded spans/blocks. A block-level 4 KiB batched retry was also rejected after mixed ReleaseFast decode-stage results: structured improved but README/dynamic-match/binary caller-buffer gzip regressed, so future work needs a selective span accumulator instead of flushing only at deflate block boundaries. The checksum benchmark now carries decoded-span threshold rows for 256/1024/2048/4096-byte pending spans so selective CRC batching can be evaluated as evidence before another production attempt. An initial local ReleaseFast gate reported `crc32-slice32` around `2852.49` MiB/s, threshold256 around `2476.88` MiB/s, and threshold1024 around `2704.02` MiB/s; after extending the sweep, the next local gate reported threshold256 `2218.33`, threshold1024 `2270.45`, threshold2048 `1731.56`, and threshold4096 `2616.12` MiB/s, making 4096-byte pending spans the strongest simple-threshold candidate. A follow-up selective4096 benchmark row that flushes pending tiny spans but updates already-large spans directly reported about `2726.13` MiB/s versus `crc32-slice32` around `2847.67` MiB/s and `crc32-best` around `2883.34` MiB/s, making selective4096 the best benchmark-only shape before any production A/B. The decode-stage report now carries strict zlib/gzip rows beside zlib no-Adler, standalone `adler32_mib_s`, `zlib_adler_time_ratio`, gzip alloc/exact/into no-CRC rows, no-ISIZE, fully relaxed gzip, standalone `crc32_mib_s`, and `gzip_crc_time_ratio`, so Adler-32/CRC-32 scan costs and trailer-size checks can be separated across caller-buffer and allocator-returning paths; allocator-returning zlib relaxed decode skips Adler calculation when `ignore_adler` is set.

- Rejected a broader production fused dynamic-distance FastDecoder hit path that consumed the distance Huffman code and extra bits together. It helped `docs/roadmap.md` in the targeted repeat3 probe but regressed README caller-buffer raw/zlib/gzip rows to about `474.04` / `495.73` / `453.28` MiB/s, so production keeps only the narrower staged helper for distance extra bits.

- Combined DEFLATE block-header reads in raw/zlib and PNG streaming decode paths,
  reading `BFINAL+BTYPE` as one 3-bit field before dispatch. This avoids a second
  reader fill/check at every block boundary without touching Huffman, distance,
  or extra-bit decode policy. ReleaseFast repeat3 decode-stage, PNG streaming
  zlib, and chunked zlib gates passed after the change.

- Routed public caller-buffer `decodeRawStored` through the same byte-level
  stored-only decoder used by auto/stored wrapper fast paths, removing its
  separate BitReader stored-block loop. Two ReleaseFast repeat3 decode-stage
  smokes kept the `stored-binary` raw stored allocation row in the same throughput
  class while preserving malformed stored-block coverage.

- Extended the deflate decode-stage CSV/Markdown/JSON schema with
  `raw_stored_into_mib_s`, measuring public caller-buffer `decodeRawStored`
  directly on stored payloads. This keeps the no-allocation stored decode path
  visible beside allocator-returning raw/zlib/gzip stored rows after routing it
  through the byte-level stored-only helper.

- Extended the same decode-stage stored-path ledger with `zlib_stored_into_mib_s`
  and `gzip_stored_into_mib_s`, measuring public caller-buffer
  `decodeZlibStored`/`decodeGzipStored` beside their allocator-returning stored
  helpers. This makes wrapper validation/checksum overhead visible separately
  from allocation for stored members.

- Shared stored-block header decoding now uses a byte-level BTYPE predicate and
  a single little-endian LEN/NLEN word load for contiguous stored-only paths
  (raw stored decode, zlib/gzip stored wrappers, header inspection, and stored
  PNG scanlines). The decode-stage repeat3 median selector now includes
  stored-only timing columns when those rows are populated, keeping
  `stored-binary` medians representative of the explicit stored APIs as well as
  generic raw/zlib/gzip inflate. A same-machine ReleaseFast probe kept explicit
  raw/zlib/gzip stored allocator rows near baseline with small positive movement
  on the alloc rows, while preserving caller-buffer stored correctness.

- Added exact-size allocation APIs for raw, zlib, zlib-with-dictionary, and gzip
  stored wrappers. These paths allocate the caller-declared output length and
  decode/checksum stored streams directly into that exact slice, returning
  `SizeMismatch` for both undersized and oversized expectations. The
  decode-stage report now tracks `raw_stored_exact_mib_s`,
  `zlib_stored_exact_mib_s`, and `gzip_stored_exact_mib_s`, plus stored
  alloc/exact time ratios, so known-size users can compare explicit stored
  alloc, exact-size alloc, and caller-buffer decode paths. The first local
  ReleaseFast repeat3 probe kept stored exact rows in the same throughput class
  as stored allocator rows on `stored-binary`.

- Added `decodeZlibConcatenated*WithOptions` APIs so concatenated zlib streams
  now match the single-member/chunked relaxed surface and gzip concatenated
  options. The new caller-buffer, allocator-returning, exact-size,
  output-limited, and dictionary-aware variants preserve strict defaults while
  allowing integrations to ignore per-member Adler-32 checks or stop before
  trailing non-zlib data. Stored-only concatenated preflights honor those
  options before allocating, including zero-allocation limit and size-mismatch
  failures for relaxed corrupt-Adler/trailing-data streams.

- Added single-buffer `ZlibDecoder` `WithOptions` initializers and resets for
  caller-owned scratch, including exact-size and preset-dictionary variants.
  This closes the API gap between one-shot zlib relaxed decode, direct chunked
  `ZlibDecoder` relaxed decode, and gzip decoder options. The relaxed wrapper
  report now records zlib decoder successes alongside zlib concatenated and gzip
  decoder coverage, so schema/dashboard validation catches future drift.

- Added `ZlibDecoder` concatenated zlib initializers and resets for
  caller-owned scratch, including `WithOptions`, exact-size, dictionary, and
  dictionary-plus-options variants. This lets bounded-output users drain
  multi-member zlib streams through the same decoder shape used for gzip
  concatenation, while the relaxed wrapper report now covers both single-member
  and concatenated zlib decoder option paths.

- Added `ZlibDecoder` concatenated-from-chunks initializers and resets with the
  same strict/options/exact-size/dictionary matrix. These join compressed zlib
  member bytes into caller scratch before using the concatenated decoder, giving
  multi-IDAT-style integrations a bounded-output multi-member path analogous to
  `GzipDecoder.initConcatenatedFromChunks*`; the relaxed wrapper report now
  includes the chunked concatenated zlib decoder path.

- Added join-scratch `ZlibDecoder.initFromChunks*WithOptions` and dictionary
  options variants for single zlib streams. This fills the compatibility-path
  gap beside the existing direct chunked relaxed decoder, so callers that still
  need a compressed join buffer can use the same relaxed Adler/trailing-data API
  shape as `GzipDecoder` and the zlib direct chunk path. The relaxed wrapper
  report now covers both non-dictionary and dictionary join-scratch chunked
  zlib decoder option paths.

- Added single-stream zlib/gzip append decode helpers for library callers.
  Zlib now exposes append, exact-size append, and output-limited append variants
  across dictionary and relaxed-option combinations; gzip exposes the same
  strict/options matrix. These preserve caller prefixes and reuse the existing
  wrapper validation paths without adding CLI surface.

- Added split-input zlib/gzip append decode helpers. Zlib chunked append now
  covers strict, dictionary, relaxed-option, exact-size, and output-limited
  library workflows without requiring callers to allocate an owned decoded slice
  first; gzip chunked append mirrors the strict/options/exact/limited matrix via
  caller-provided compressed join scratch.

- Added concatenated zlib/gzip append decode helpers for library callers. Multi-member
  zlib and gzip streams now have append, exact-size append, and output-limited
  append variants that preserve caller prefixes and reuse existing per-member
  wrapper validation without routing through CLI or forcing an owned decoded
  slice first.

- Added split-input concatenated zlib/gzip append decode helpers. Chunked
  multi-member wrapper streams can now append into caller-owned `ArrayList`
  output with exact-size and output-limited variants while reusing caller-owned
  compressed join scratch for the compatibility path.

- Added public one-shot `decodeGzipChunks` and `decodeGzipChunksWithOptions`
  helpers for caller-buffer gzip decode from split compressed input. They reuse
  the existing caller-owned compressed join scratch policy (including the
  single-non-empty-chunk borrow fast path) and then validate via
  `decodeGzipWithOptions`, giving gzip the same small-payload convenience shape
  already available to zlib chunk callers.

- Added allocator-returning gzip chunked decode helpers
  (`decodeGzipChunksAlloc*`) for unknown-size, exact-size, output-limited, and
  relaxed-option workflows. These reuse the same join-scratch compatibility
  policy before dispatching to the existing gzip allocator paths, so split-input
  callers can avoid writing their own coalescing logic while preserving strict
  prechecks, size/limit errors, and relaxed CRC/ISIZE/trailing behavior.

- Added public one-shot `decodeGzipConcatenatedChunks*` helpers for split-input
  concatenated gzip streams, including caller-buffer, allocator-returning,
  exact-size, output-limited, and relaxed-option variants. They share the same
  join-scratch compatibility layer as single-member gzip chunk helpers before
  reusing the existing concatenated gzip validators.

- Added public raw deflate chunked decode helpers (`decodeRawChunks*` exported
  from the root module as `decodeRawDeflateChunks*`). The new caller-buffer and
  allocator-returning paths reuse caller-provided compressed join scratch before
  dispatching to existing raw inflate APIs, covering exact-size, output-limited,
  and preset-dictionary workflows for split raw streams.

- Added raw deflate append decode helpers for contiguous and split-input
  library callers. Raw deflate now mirrors the wrapper append surfaces with
  prefix-preserving append, exact-size append, output-limited append, and
  preset-dictionary variants without requiring an intermediate owned decoded
  slice.

- Added a reusable caller-owned raw deflate `RawDeflateDecoder` library facade.
  It validates/decodes complete raw streams into caller-provided scratch during
  reset, supports exact-size and split-input reset variants, and drains through
  bounded `step` calls with snapshots and shared streaming diagnostics.

- Added non-throwing raw deflate probe helpers for contiguous and split-input
  library callers. The probes decode into caller-owned scratch and return
  `ok`, decoded byte counts, error names, and streaming diagnostics for support
  and exact-size preflight without requiring integrations to wrap throwing APIs.

- Added caller-scratch decoded-size helpers for raw deflate contiguous and
  split-input streams, including preset-dictionary variants. Raw callers now
  have throwing size preflights to match the wrapper size helper surface.

- Added non-throwing zlib/gzip probe helpers for contiguous and split-input
  library callers. Wrapper probes reuse caller-owned decoded/compressed scratch
  and report decoded byte counts, exact-size mismatches, error names, and shared
  streaming diagnostics without adding CLI surface.

- Added non-throwing concatenated zlib/gzip probe helpers for multi-member
  wrapper streams, including split-input variants. These probes reuse
  caller-owned scratch and expose decoded byte counts plus exact-size mismatch
  diagnostics before callers commit to an append or allocator-returning decode.

- Extended zlib probe helpers across preset-dictionary workflows, including
  split-input and concatenated streams. Dictionary-aware probes now surface
  `NeedDictionary` without throwing and preserve the same decoded-byte/exact-size
  diagnostics as non-dictionary zlib/gzip probes.

- Refined zlib/gzip probe diagnostics with wrapper-aware failure phases. Probe
  results now distinguish header/dictionary failures, DEFLATE payload failures,
  footer checksum/trailing-data failures, and output-size/limit failures while
  retaining the non-throwing API shape.

- Added caller-scratch decoded-size helpers for zlib/gzip single streams and
  split-input streams, including zlib preset-dictionary variants. These provide
  throwing size preflights for callers that already manage scratch and do not
  want to inspect a full probe result.

- Added caller-scratch decoded-size helpers for concatenated zlib/gzip streams,
  including split-input variants and zlib preset-dictionary workflows. Multi-member
  callers now have throwing size preflights alongside the non-throwing probe
  APIs before selecting append, caller-buffer, or allocator-returning decode.

- Extended concatenated zlib/gzip probes with failing member indexes. Multi-member
  probe failures now report which member failed, while preserving wrapper-aware
  phases such as footer checksum failures for the offending member.

- Extended the same concatenated zlib/gzip probe failures with member byte
  offsets, so callers can jump directly to the failing wrapper member in a
  multi-member stream after a non-throwing preflight.

- Added successful concatenated zlib/gzip probe member counts. Multi-member
  preflights now report how many wrapper members were consumed, including
  exact-size and split-input probe variants.

- Extended successful concatenated zlib/gzip probe summaries with total consumed
  input bytes and the last member's byte offset, giving callers enough member
  boundary context to pair non-throwing preflight results with their own stream
  indexes.

- Added zlib stream inspection helpers for split compressed input
  (`inspectZlibStreamFromChunksAlloc*`), reusing caller-provided join scratch
  before running the existing diagnostic inspector. They report the same
  deflate/footer offsets, decoded byte count, and Adler diagnostics as the
  contiguous inspector, including preset-dictionary streams, and the root API
  smoke now pins these exports.

- Added gzip member inspection helpers for split compressed input
  (`inspectGzipMemberFromChunksAlloc*`). They reuse caller-provided join scratch
  before the existing member inspector, preserving concatenated-member offsets,
  exact DEFLATE byte counts, and CRC/ISIZE diagnostics for chunked gzip callers.

- Added `parseRawDeflateHeaderInfoFromChunks` and rooted it in the public API
  smoke. Split raw-deflate callers can now inspect the first block header through
  the same caller-owned compressed join scratch used by raw/zlib/gzip chunked
  decode helpers, preserving stored/fixed/dynamic diagnostics without writing
  their own temporary coalescing layer.

- Added split-input wrapper header metadata parsers
  (`parseZlibHeaderInfoFromChunks` and `parseGzipHeaderInfoFromChunks`). They
  use the same caller-owned compressed join scratch policy as chunked decode and
  inspection helpers, preserving zlib CMF/FLG/DICTID fields and gzip optional
  metadata/FHCRC validation for callers that receive wrapper headers in pieces.

- Added a root-module compile-time smoke for public split-input decode helpers
  across raw deflate, zlib, gzip, and concatenated gzip. Codec behavior remains
  covered in `src/deflate.zig`; the root smoke specifically guards the public
  export surface used by README examples and downstream callers.

- Hardened the Python zlib black-box differential harness against operating
  system per-argument limits. Small vectors continue to exercise inline
  text/hex CLI commands, while large README/roadmap payloads now use raw/zlib/
  gzip file decode plus Vort file encode paths. The retained JSON/dashboard
  records and requires `large_file_payloads`, ensuring CI covers this transport
  branch instead of silently shrinking the corpus.

- Switched x86_64 PNG Paeth reconstruction to the stb_image threshold
  formulation used by Rust image-png while retaining the PNG specification
  predictor as the portable reference. Exhaustive `256^3` predictor coverage
  pins exact equivalence and tie-breaking. Isolated same-machine ReleaseFast
  Kodak RGB reconstruction moved from a `560.43` MiB/s repeat3 median to
  `1116.66` MiB/s (`+99.2%`), and the focused bpp=3 Paeth scanline gate now
  protects the optimized path.

- Specialized PNG Average reconstruction for bpp=3 RGB rows using the
  image-png-style per-pixel left-state loop. The optimized kernel retains a
  generic scalar reference and compares every row length through 257 bytes,
  including non-pixel-aligned tails and no-previous-row behavior. Synthetic
  bpp=3 Average throughput moved from about `1258` to `2319` MiB/s, while the
  real Kodak-trio repeat3 median moved from the Paeth-only `1116.66` to
  `1218.78` MiB/s (`+9.1%`).

- Split PNG metadata, Adam7 placement, and scanline reconstruction into the new
  `src/png.zig` module, leaving `src/deflate.zig` to alias the public PNG
  surface while keeping zlib/DEFLATE orchestration there. This removes roughly
  600 lines of PNG-specific helpers from the already-large deflate module and
  roots PNG primitives directly through `root.png`/root-level aliases. The same
  change extends fixed-bpp Average reconstruction to common bpp=2/4/6/8 rows by
  retaining the previous reconstructed pixel in registers; bpp=1 stays on the
  generic path because the fixed-bpp variant was not a robust win locally. The
  latest local ReleaseFast `run-png-scanline-bench-gate` passed with Average
  bpp2/4/6/8 rows around `1666.61` / `2614.60` / `2629.03` / `2658.92` MiB/s.

- Moved the root-level PNG export ledger and its public API smoke into
  `src/root_exports/png.zig`. `src/root.zig` still spells explicit compatibility
  aliases because Zig 0.16 does not support the old top-level `usingnamespace`
  re-export shape, but the source-of-truth mapping and root drift test now live
  in a nested exports module instead of growing the root file directly. This is
  the first root-export modularization slice after the PNG primitive split.

- Made PNG scanline reconstruction faster and the focused scanline gate more
  robust on a clean checkout. The benchmark writer now creates artifact parent
  directories before writing `zig-out/vort-png-scanline-bench.csv`. Paeth fixed
  bpp rows use the image-png/stb threshold predictor and stateful per-channel
  loop on every architecture instead of only x86_64, restoring the aarch64
  bpp=3 gate margin. Sub fixed bpp=2/4/6/8 rows now keep per-channel prefix sums
  in registers, removing the prior left-neighbor output reload. Local
  ReleaseFast `run-png-scanline-bench-gate` passed with Sub bpp=2/4/6/8 around
  `3161.27` / `4977.06` / `5444.98` / `5484.38` MiB/s and Paeth bpp=3/4/6/8
  around `809.03` / `935.57` / `966.00` / `1065.70` MiB/s.

- Re-aligned IEEE CRC-32 dispatch reporting on AArch64 with the actually
  validated implementation. ARM CRC32 feature detection remains visible through
  `arm_crc32`, but `bestCrc32Dispatch` stays on the portable slice-by-32 path
  until the Zig 0.16 AArch64 inline-asm path is validated across targets, so
  `zig build test` is not blocked by an unvalidated hardware candidate.

- Made the focused PNG scanline reconstruction gate repeat-aware. The benchmark
  now accepts `--repeat`, records a `repeat` CSV column, and reports the median
  elapsed row for each filter/bpp case. ReleaseFast
  `run-png-scanline-bench-gate` now runs with `--repeat 3` and requires
  `--min-repeat 3`, reducing false throughput failures from transient CPU load
  while keeping Debug smoke checks fast.

- Removed optional system codec linkage from the library build. Vort no longer
  exposes `-Dsystem-codecs` or links `libzstd`/`liblz4`; the public one-shot
  Zstd/LZ4 frame facades always use dependency-free Zig implementations.
  External zstd/LZ4 tools remain validation inputs for differential probes, not
  runtime support paths.

- Exposed the dependency-free LZ4 pure-frame encode helpers through the root
  module. `lz4EncodePureFrameAlloc`, `lz4EncodePureFrameWithOptionsAlloc`, and
  `lz4EncodePureFrameAppend` now let library callers choose the pure Zig LZ4
  writer explicitly without dropping into the `lz4` submodule.

- Exposed single-input stored wrapper size preflight helpers through the root
  module. `rawStoredDeflateEncodedSize`, `zlibStoredEncodedSize`,
  `zlibStoredWithDictionaryEncodedSize`, and `gzipStoredEncodedSize` now sit
  beside the existing chunk/header variants so library callers can allocate
  exact buffers for raw/zlib/gzip stored encodes without reaching into
  `deflate.zig`.

- Exposed root-level raw deflate partial allocator decode helpers and their
  owned-result type. `decodeRawStoredDeflateAllocPartial`,
  `decodeRawFixedAllocPartial`, `decodeRawDynamicAllocPartial`, and
  `decodeRawDeflateAllocPartial` let library callers decode the first raw
  member and inspect `input_read` before deciding how to handle trailing bytes.

- Exposed root-level codec error/constant aliases for library preflight and
  allocation logic. Deflate, Brotli, Snappy, LZ4, and Zstd callers can now read
  the relevant error sets, stored/meta/chunk size limits, and default
  compression levels from the root facade instead of importing submodules.

- Exposed root-level raw deflate token encoders. Library callers that already
  own `Lz77Token` streams can now call `encodeRawFixedTokensAlloc` and
  `encodeRawDynamicTokensAlloc` from the root module, with root tests proving
  token-level fixed/dynamic streams round trip through the public raw decoder.

- Extended the public Zstd frame encode facade with encoded-bound, append, and
  caller-owned into-slice helpers across level/options variants. Library callers
  no longer need to drop to native-specific APIs or allocate an owned frame just
  to write into existing buffers.

- Extended the same public Zstd encode facade with dictionary-aware bound,
  allocator, append, and into-slice helpers. Callers using explicit
  `NativeDictionary` values can stay on the top-level frame API instead of
  dropping to native-specific entrypoints for basic dictionary workflows.

- Extended the Zstd encode facade again with dictionary-set helpers, including
  bound, allocator, append, and into-slice variants keyed by `Dictionary_ID`.
  Top-level frame encoding now covers both single dictionaries and checked
  dictionary catalogs without requiring native-specific entrypoints.

- Added output-limited caller-buffer Zstd decode helpers across the public,
  raw/RLE, native, and concatenated frame facades, including split-input,
  preset-dictionary, dictionary-set, and reusable decoder variants. These
  limited `into` paths preflight decoded size before mutating caller-owned
  output, matching the existing allocator-returning and append limited behavior
  without adding CLI surface.

- Tightened Zstd Huffman-literals candidate handling. Oversized Huffman literal
  headers or four-stream length fields now decline the compressed-literals
  candidate and fall back to raw literals instead of failing the whole encode
  with `UnsupportedZstdFeature`, preserving correctness while keeping the
  candidate encoder bounded by the wire-format limits.

- Tightened Zstd predefined sequence-table planning. When the candidate planner
  is asked to score a symbol table larger than its bounded internal state array,
  it now declines the predefined candidate instead of failing the whole encode
  with `UnsupportedZstdFeature`; a focused unit test covers the fallback.

- Added a dependency-free Brotli `br` bootstrap module for stored/uncompressed
  streams. `src/br.zig` emits RFC-valid WBITS=16 streams with uncompressed
  meta-blocks plus final empty terminators, decodes the same stored subset with
  output limits and trailing-data checks, and exposes root/CLI smoke APIs. This
  is intentionally a first compatibility slice, not full Brotli Huffman/LZ77
  support yet.

- Extended the public Brotli stream facade with exact-size allocator, append,
  and into helpers plus split-input chunked decode/size helpers. These reuse the
  existing dependency-free Brotli parser through caller-owned compressed scratch
  so known-size and fragmented-input callers no longer need private preflight or
  coalescing code while the codec remains clearly scoped to the current Brotli
  subset.

- Added output-limited caller-buffer Brotli decode helpers for contiguous and
  split-input streams. `decodeStreamIntoLimited` and
  `decodeStreamChunksIntoLimited` preflight decoded size against the caller's
  policy before mutating the output buffer, bringing the Brotli into-slice API
  in line with existing allocator-returning and append limited variants without
  adding CLI surface.

- Exposed Brotli compressed-subset support limits through a library
  introspection API. `compressedSupportLimits` reports the current bounded
  literal/command/distance block and context-tree capacities, so callers can
  make fallback decisions without depending on private constants or CLI probes.

- Exposed the Brotli `PrefixCode` type factory through the root module as
  `BrotliPrefixCode`, keeping the root facade complete for library users that
  build small compatibility probes around the public Brotli prefix decoder.

- Added a reusable caller-owned Brotli `StreamDecoder` library facade. It
  validates/decodes the current supported Brotli subset into caller-provided
  output scratch during reset, then drains through bounded `step` calls with
  snapshots and shared streaming diagnostics. This closes the immediate
  library-interface gap without adding CLI surface or hiding allocations.

- Added a Brotli `StreamSummary` library preflight API for contiguous and
  split-input streams. It reports window bits, decoded bytes, meta-block counts
  by kind, metadata bytes, and output-limit failures without materializing
  decoded output, giving library callers a cheap capability/capacity probe for
  the current Brotli subset.

- Added diagnostics-bearing Brotli summary entrypoints for contiguous and
  split-input streams. `StreamSummaryDiagnostics` reports the failing phase,
  byte offset, and meta-block index for truncated window bits, metadata blocks,
  compressed-block unsupported features, padding/trailing-data failures, and
  output-limit rejections without adding CLI surface.

- Added non-throwing Brotli stream probe helpers for contiguous and split-input
  callers. The probe returns `ok`, optional `StreamSummary`, `error_name`, and
  diagnostics in one value, so library integrations can preflight support and
  capacity without wrapping the throwing summary APIs themselves.

- Added exact-size Brotli stream probe variants for contiguous and split-input
  library callers. Known-size integrations now get a non-throwing `SizeMismatch`
  result that preserves the parsed `StreamSummary` and marks the diagnostic
  phase as output-size validation.

- Extended Brotli `StreamSummary` with capability flags and static-dictionary
  counters. Library callers can now distinguish stored-only streams from
  metadata-bearing, compressed, and minimal static-dictionary streams before
  deciding which decode path or fallback policy to use.

- Added a dependency-free Snappy raw block module. `src/snappy.zig` covers the
  raw block varint length header, literal tags, copy1/copy2/copy4 decode,
  decoded-size preflight, output limits, caller-owned output, allocator-returning
  helpers, and a literal-compatible encoder. The CLI and
  `run-snappy-block-cli-probe` cover hex and file workflows without depending on
  a system Snappy library. Framed Snappy streams remain a follow-up format slice.

- Exposed the Snappy raw-block limited summary helper through the root module.
  `snappySummarizeBlockLimited` now lets library callers preflight raw-block
  decoded-size policy and tag statistics without allocating or dropping to the
  `snappy` submodule.

- Extended the dependency-free Snappy module to framed streams. The frame path
  writes the stream identifier plus checked uncompressed chunks, decodes
  compressed and uncompressed chunks, validates masked CRC-32C, skips skippable
  chunks, and exposes size preflight, output limits, caller-owned output, and
  allocator-returning helpers through root/CLI APIs. The existing
  `run-snappy-block-cli-probe` gate now covers both raw-block and framed-stream
  hex/file workflows plus malformed checksum handling.

- Upgraded the dependency-free Snappy encoder from literal-only output to a
  greedy hash-table match encoder. Repeated raw blocks now emit copy tokens, and
  framed streams choose compressed chunks only when they beat uncompressed
  chunks. Unit tests and the CLI probe both assert that a repeated payload
  shrinks, so ratio regressions are covered by regular validation instead of
  relying only on round-trip correctness.

- Added `run-snappy-report-gate`, a focused Snappy raw/framed ratio and
  throughput CSV gate. The report records input bytes, encoded bytes, ratio,
  encode/decode timings, and checksums across tiny, text, structured,
  repetitive, and incompressible payloads. The gate enforces the full row matrix,
  positive throughput/timing fields, consistent iterations, framed-vs-raw
  overhead sanity, and repeated-payload ratio wins.

- Added a reusable Snappy encoder state (`SnappyEncoder`) so applications can
  reuse the hash table and framed-stream block scratch across repeated raw and
  framed encodes. The Snappy report now carries reusable raw/framed rows and the
  gate requires their encoded sizes to match the one-shot rows, keeping the
  reusable path covered without letting it drift from public one-shot behavior.

- Added split-input Snappy decode helpers for both raw blocks and framed
  streams. Library callers can now preflight, decode into caller buffers, append
  to existing output, or allocate with limits from `[]const []const u8` chunks
  using caller-provided compressed scratch, matching the chunked convenience
  shape already available for deflate and LZ4 without adding hidden buffering.

- Added exact-size Snappy decode helpers across raw block, framed stream, and
  split-input variants. Callers that know the expected output length can now
  reject size drift before allocation/append and keep existing output buffers
  unchanged on mismatch, matching the exact-size API shape used by LZ4 and
  deflate wrapper decoders.

- Added Snappy encoded-bound helpers for raw blocks and framed streams.
  `snappyEncodedBlockBound` and `snappyEncodedFrameBound` let callers size
  caller-owned encode buffers before using `snappyEncode*Into`, with tests
  proving the bounds cover one-shot output for literal and compressed frames.

- Added Snappy framed-stream summary helpers. `snappySummarizeFrame` and the
  split-input variant validate chunk structure/checksums while reporting stream
  identifiers, compressed/uncompressed chunks, skippable payload bytes, and total
  decoded bytes before callers materialize output.

- Exposed Snappy framed-stream summaries through the CLI as
  `summary-snappy-frame-hex` and `summary-snappy-frame-file`, and extended the
  black-box Snappy CLI probe to validate compressed, skippable, concatenated,
  and file summary rows.

- Added Snappy raw-block summary helpers and CLI commands. The block summary
  validates Snappy tokens while reporting literal/copy token counts and bytes,
  with split-input and file/hex CLI probe coverage for encoded and known-copy
  blocks.

- Removed the duplicate full-token/checksum decode from allocating, append,
  and exact-size Snappy frame APIs. These paths now preflight only framing and
  declared block lengths before their single validating decode; raw block
  allocation similarly consumes the length prefix once and decodes tokens
  once. Error-priority tests retain output-limit, exact-size, malformed-token,
  and checksum behavior. The old 1,500-line facade now delegates block
  parsing/validation and overlapping history copies to focused
  `snappy/{block_decode,match_copy}.zig` modules with independent oracles.
  A same-machine ReleaseFast 1,000-iteration comparison improved framed decode
  by about `1.50x...1.53x` on text, structured, repetitive, and incompressible
  rows (`1.513x` geomean); the gate now enforces conservative ReleaseFast
  floors for those rows.

- Removed the remaining duplicate raw-block token validation inside successful
  Snappy framed decode. Compressed chunks now read their length prefix once and
  run the shared out-of-line token decoder once; malformed tokens and short
  output retain their established error priority. Framing, U24 fields, and
  allocation preflight moved from the facade into `snappy/frame.zig`, reducing
  `src/snappy.zig` from 1,540 to about 1,460 lines while keeping only three
  cohesive files in the Snappy subdirectory. The frame checksum path now uses
  Vort's selected CRC-32C backend rather than the byte-at-a-time scalar API.
  Against commit `68684c6`, a same-machine ReleaseFast 1,000-iteration A/B
  improves framed text/structured/repetitive/incompressible decode by about
  `1.84/1.77/1.86/1.88x` and framed encode by about
  `1.94/2.05/1.98/1.13x`; framed decode geomean across all report rows is
  `1.677x`. ReleaseFast gate floors were raised to cover the new performance
  envelope without relying on the A/B report alone.

- Added an opt-in same-process Snappy decode comparison that dynamically loads
  the installed `libsnappy` C ABI, so competitor evidence does not require
  development headers or contaminate default CI. Both codecs consume identical
  Vort-generated blocks into caller-owned output; the CSV also records literal
  and copy-token distributions. Against Ubuntu `libsnappy` 1.1.10 on the local
  i9-13900K, Vort leads tiny/text/structured/incompressible/RLE rows by roughly
  `5.13/1.50/1.29/2.38/3.21x`. The 32-byte-period repetitive row is the only
  measured gap at about `0.93x`; its exact shape is one literal plus 546 COPY_2
  tokens. Direct/non-overlap copy specializations were tested and rejected when
  repeat5 evidence failed to improve that row. The optional gate requires Vort
  to retain clear wins on five rows and bounds the known repetitive weakness,
  making the next token-loop optimization target explicit rather than claiming
  blanket Snappy leadership.

- Closed the locked Snappy 32-byte-period decode gap. Profiling showed the row
  is exactly one 32-byte literal followed by 546 COPY_2 tokens, almost all
  around length 60/distance 32. `snappy/match_copy.zig` now replays matches with
  offset >=8 and length >=16 in eight-byte words; every source word precedes
  its store, so overlapping Snappy semantics remain valid. The existing oracle
  exhaustively covers offsets 1...96 and lengths 1...64. A same-process
  libsnappy 1.1.10 comparison moved the 20,000-iteration repetitive row from
  about `0.93x` to `1.13x`; repeat5 text/structured/repetitive rows are about
  `1.86/1.39/1.12x`, while RLE and literal-only rows retain clear wins. The
  optional reference gate now requires repetitive decode to remain above
  `1.02x`, replacing the prior bounded-known-gap contract.

- Added the matching opt-in caller-owned raw-block comparison for LZ4, with
  runtime `liblz4` loading isolated under `tools/lz4/`. The common compressed
  input is generated by the reference library because Vort's bootstrap raw
  encoder does not yet enforce liblz4's terminal-literal constraints on highly
  compressible payloads; recording that distinction avoids treating Vort-only
  permissive blocks as interoperability evidence. Against Ubuntu `liblz4`
  1.9.4 on the local i9-13900K, Vort decode leads tiny/text/structured/
  repetitive/RLE by at least about `1.28/6.15/12.60/4.60/7.41x` in the initial
  repeat5 run, while incompressible literal decode is effectively tied at
  `1.00x`. A 20,000-iteration repetitive confirmation measured `4.89x`; the
  retained gate rerun remains positive on every row. The optional gate validates version, token
  accounting, common-input round trips, clear wins on five rows, and a bounded
  incompressible row. No production decoder change was justified by this
  matrix; the newly exposed work is encoder terminal-format compatibility.

- Fixed that LZ4 raw-block encoder compatibility gap. Both independent and
  linked hash-chain encoders now share `lz4/block_format.zig`, which codifies
  the wire-format terminal requirements: the final match starts at least 12
  bytes before the end and a final literal-only sequence retains at least five
  bytes. Match search still uses the same candidates and back-extension, but
  the selected match is clipped before emission rather than consuming the
  mandatory tail. The runtime liblz4 comparison now differentially decodes
  both liblz4- and Vort-generated blocks for all six cases and records both
  token layouts/sizes. Vort output matches liblz4 size exactly on the locked
  tiny/text/structured/repetitive/incompressible/RLE matrix, retains its
  caller-owned decode lead on the compressed rows, and exposes at least five
  Vort literal bytes on every match-capable case. The 113-case native LZ4
  probe, 93-row native library gate, and 814 unit tests cover the broader
  regression surface.

- Added an opt-in same-process Zstd caller-owned decode comparison under
  `tools/zstd/`, dynamically loading Ubuntu libzstd 1.5.5 and using level-1
  reference frames as common input. Initial runs put Vort around `0.86/0.57/
  0.20/0.22/0.89/0.60x` on tiny/text/structured/repetitive/incompressible/RLE
  rows; the retained repeat5 gate currently records comparable gaps, while a
  256 KiB raw multi-block row is around `0.8x`. The four compressed
  cases all have raw literals, exactly one sequence, and predefined LL/OF/ML
  tables, isolating the first optimization target to generic compressed-block
  parse/sequence setup rather than Huffman or FSE table construction. A direct
  RLE-match memset candidate was tested and reverted after end-to-end slowdown.
  The evidence-first gate records reference version, block/literal/sequence
  shape, exact per-case ratios, and conservative regression floors; it does not
  misrepresent the current gaps as leadership.

- Began structural work on that Zstd sequence target by moving the 178-line
  predefined LL/OF/ML decode tables and checked state lookup into
  `src/zstd/sequence/predefined.zig`. This reduces the already-large
  `src/zstd.zig` facade by roughly 176 lines and gives future predefined fast
  paths a cohesive module instead of adding more tables/logic to the 15K-line
  file. A single-sequence shortcut and an RLE-match memset were both measured
  and rejected after repeat5 end-to-end results were neutral-to-negative; only
  the behavior-preserving extraction remains. The libzstd matrix stays at the
  established baseline, and the new module has its own invalid-state tests.

- Added a focused raw-frame fast path under `src/zstd/frame/raw.zig` rather
  than expanding the Zstd facade. It accepts only checksum-free, dictionary-
  free, single-segment frames containing raw blocks, validates the complete
  frame and declared size before mutating output, and falls back without side
  effects for every other shape. Payloads below 256 bytes stay on the general
  decoder to avoid two-pass fixed overhead. In the libzstd repeat5 matrix, the
  1 KiB raw row moves from roughly parity to over `30x` the reference call and
  the 256 KiB/two-block row improves from about `0.8x` to `0.94x`; compressed
  rows remain byte-identical and unchanged. The reference gate now requires a
  clear 1 KiB raw win and at least `0.85x` on the large raw row.

- Extended the same isolated Zstd frame module to mixed raw/RLE block streams.
  The first pass distinguishes stored payload length (`len` for raw, one byte
  for RLE), validates non-zero RLE regeneration sizes and the declared total,
  then the decode pass uses `memcpy`/`memset` without reparsing the full general
  codec. A handcrafted 256-byte RLE oracle covers byte changes and output.
  libzstd level 1 normally represents the locked repeated-byte corpora as one
  compressed sequence rather than an RLE block, so this is compatibility/hot-
  path coverage for valid externally produced RLE frames, not a benchmark win
  falsely attributed to the current reference matrix.

- Extracted Zstd's shared Huffman/sequence reverse-bit reader into
  `src/zstd/sequence/bit_reader.zig`, reducing the facade below 14,920 lines.
  The module owns marker-bit parsing and a cross-byte reservoir reader, with a
  per-bit reference oracle covering input lengths and widths 1...16. The first
  reservoir implementation exposed a bit-order bug through that oracle before
  integration; the corrected reader keeps the libzstd repeat5 matrix at the
  established compressed/raw performance envelope. This is a structural hot-
  path boundary for further reservoir work, not an unsupported speed claim.

- Extended the opt-in Zstd comparison with separate header, first-block, and
  sequence-inspection timings. Header/block inspection cost only about 13/27 ns
  per call on the locked frames, while single-sequence inspection costs roughly
  12 microseconds—essentially the whole decode. This localizes the dominant
  setup cost to sequence parsing and its large inline FSE-table objects, not
  frame headers. A narrow production early return now handles all-predefined
  sequence modes without constructing or resolving unused FSE tables, improving
  the locked compressed decode rows by roughly 5–10% in the short matrix. A
  broader table-view extraction was separately tested and reverted after code-
  layout regressions; future work should redesign ownership/view boundaries
  inside `src/zstd/sequence/`, not copy those large tables between modules.

- Reused the extracted predefined module for a zero-allocation sequence-shape
  inspection fast path. `isModeByte` recognizes the all-predefined mode byte,
  allowing `inspectNativeFrameBlockSequenceModes` to return its public summary
  without constructing three empty 512-entry FSE tables. On the locked
  libzstd rows, sequence inspection drops from roughly 12 microseconds to about
  2.3 microseconds per call. The same shape predicate remains available to a
  future production decoder fast path, while decode behavior and the generic
  mixed/RLE/FSE/repeat-table fallback are unchanged.

- Added that production fast path without growing the facade: the bitstream-
  only decoder lives in `src/zstd/sequence/single_predefined.zig`, while the
  parent retains repeat-offset mutation and output/history ownership. For an
  exactly-one-sequence, all-predefined block, dispatch occurs before constructing
  the three inline 512-entry FSE tables. In repeat5 libzstd comparisons,
  text/structured/repetitive improve from about `0.52/0.19/0.21x` to
  as high as `0.93/0.33/0.37x`, and the repeated-byte row can reach roughly
  reference parity. Short gate runs are noisier (text has remained above about
  `0.64x`), so conservative floors protect material improvement without encoding
  the best observed sample as a guarantee. Raw rows remain on their isolated
  fast path.

- Removed the remaining terminal-block state materialization from Zstd sequence
  decode. Frame loops now pass an explicit continuation context from each block
  header; only blocks with a successor retain entropy tables and repeat offsets
  for possible `Repeat_Mode` use. The policy lives in
  `src/zstd/sequence/continuation.zig`, keeping lifecycle intent out of the
  already-large facade, and both one-shot and direct incremental decode share
  it. Multi-block repeat-table fixtures still exercise the retained-state path,
  while a focused terminal/continuing state test covers the ownership boundary.
  This avoids writing three unused 512-entry FSE tables on the dominant one-
  block shape. In the local repeat5 libzstd 1.5.5 matrix, text/structured/
  repetitive/repeated-byte improve from roughly `0.92/0.33/0.37/0.99x` to
  `2.67/1.13/1.61/2.39x`; raw-frame paths remain separate and unchanged.

- Extended the same-process libzstd comparison to measure Vort's allocator-
  returning decode beside caller-owned decode. The first measurement exposed a
  `6.0–7.2x` gap on the locked single-block compressed rows: the allocator path
  performed a complete decoded-size preflight and then parsed/decoded the block
  again. A new shape planner in `src/zstd/frame/known_size.zig` recognizes one
  dictionary-free frame with declared content size and exactly one block, then
  allocates the final slice once and delegates all actual validation and output
  to the caller-owned decoder. Concatenated, skippable, dictionary, no-size, and
  multi-block streams retain the general path. The allocator/caller-owned ratio
  first fell to about `1.36–1.86x` on text/structured/repetitive/repeated-byte.
  Reusing the public caller-owned facade from that final allocation also lets
  raw/RLE shapes retain their specialized frame decoder; the locked compressed
  rows now sit around `0.97–1.00x` and the 1 KiB raw row around `1.7x`, including
  allocation/free overhead. The optional gate protects conservative `2.5x`
  compressed and `3.0x` 1 KiB raw ceilings. Focused tests
  cover checksum and declared-size corruption plus concatenated/multi-block
  fallback without duplicating block decoding logic in the planner.

- Expanded the libzstd decode matrix beyond the favorable one-sequence shape.
  Deterministic numbered-JSON, 80 KiB patterned-symbol, and 64 KiB printable-
  ASCII rows now lock multi-sequence/FSE, large FSE-sequence, and Huffman-
  literal-only coverage respectively. The first measurements exposed much
  larger general-path gaps (`0.077/0.014/0.012x` reference throughput), so the
  gate records conservative floors instead of treating the earlier matrix as a
  complete leadership claim. The dominant multi-sequence defect was structural:
  three inline 512-entry FSE tables were copied by value for every decoded
  sequence. Changing symbol lookup to borrow `SequenceDecodeState`/tables lifts
  numbered JSON to about `0.12x` and the 5,161-sequence row to about `0.30x`
  without changing table layout. A new `src/zstd/literals/huffman_lookup.zig`
  module adds fixed-prefix literal lookup using peek/skip support in the shared
  reverse reader; exact stream-boundary fallback retains malformed-input
  behavior. Literal-only Huffman remains the largest gap and is now explicitly
  visible rather than hidden by the original corpus.

- Routed sequence-free Huffman literal blocks through the same fixed-prefix
  table instead of leaving them on the canonical linear tree scan. The shared
  reverse reader now exposes an oracle-tested small-width peek specialized for
  Zstd's at-most-11-bit Huffman codes, touching at most three bytes without the
  generic u72 gather loop. On the 64 KiB printable-ASCII row this raises Vort
  from roughly `0.013x` to about `0.11x` libzstd throughput (over `8x` faster),
  while the multi-sequence rows remain around `0.12/0.32x`. The gate floors now
  protect those material gains; libzstd still leads the general Huffman/FSE
  paths, so further table/state and match-loop work remains necessary.

- Extracted Zstd's current-frame match replay into
  `src/zstd/sequence/match_copy.zig`, keeping match mechanics beside sequence
  decoding rather than growing the facade. Non-overlapping matches now take one
  exact memcpy, while overlapping matches seed one period and double the
  initialized prefix. Focused period/non-overlap tests lock LZ semantics. A
  1,000-iteration huffman80k A/B improved from roughly `0.290x` to `0.302x`
  libzstd throughput (about `4%` faster), and the expanded gate raises that
  row's floor to preserve the gain without claiming parity.

- Removed a redundant per-bit reconstruction loop from the shared Zstd reverse
  reader. Its gathered `little` value already has the same integer order as the
  prior loop; the existing per-bit oracle, plus explicit peek/skip alignment
  tests, verifies the equivalence across widths and byte boundaries. On the
  1,000-iteration huffman80k row this improves Vort from roughly `0.302x` to
  `0.326x` libzstd throughput (about another `7–8%`), while the single-sequence
  and literal-only Huffman rows remain within their established envelope. The
  huffman80k gate floor rises to `0.29x`.

- Replaced the reverse reader's dynamic byte-gather loop with bounded fixed-
  width loads: direct one/two-byte reads, a padded u64 for three through eight
  bytes, and a u64-plus-tail case for the maximum nine-byte request. The same
  per-bit oracle covers every alignment and width before benchmark use. On the
  1,000-iteration matrix huffman80k rises again from roughly `0.326x` to
  `0.349x` libzstd throughput (about `7%` faster), numbered JSON improves to
  about `0.125x`, and single-sequence/Huffman-literal-only rows stay within
  their established envelopes. The huffman80k floor increases to `0.32x`.

- Changed the Huffman literal hot path to borrow the 256-node canonical tree
  instead of passing it by value through cursor lookup and fallback queries.
  This mirrors the earlier FSE-state ownership fix and keeps the API boundary
  explicit without changing tree layout. On the 1,000-iteration general matrix
  numbered JSON rises from roughly `0.125x` to `0.133x` libzstd throughput,
  huffman80k remains around `0.34x`, and the literal-only row remains in its
  existing range. All Huffman, treeless, four-stream, and high-byte fixtures
  continue to share the same decoder; the numbered-JSON floor rises to `0.11x`.

- Added an opt-in same-process Brotli caller-owned decode comparison under
  `tools/br/`, dynamically loading Ubuntu libbrotli 1.1.0. The locked quality-0
  frames keep all rows inside Vort's supported subset and show the real split:
  tiny/stored-random paths lead libbrotli by roughly `11x/3x`, while compressed
  text/structured/repetitive initially reached only about `0.24/0.20/0.27x`.
  Separate decoded-size timing shows the strict preflight itself is even more
  expensive than output decode on those compressed rows, localizing future work
  to shared prefix/header parsing rather than allocation. The optional gate
  records version, exact round trips, throughput, and conservative row floors.

- Extracted Brotli in-window match replay into `src/br/match_copy.zig`. The
  decoder now copies one source period and doubles the initialized prefix, with
  exact memcpy for non-overlap, instead of advancing one byte at a time. Focused
  period and non-overlap tests lock LZ77 semantics. Same-machine A/B raises the
  compressed libbrotli ratios from roughly `0.24/0.20/0.27x` to
  `0.31/0.25/0.36x` for text/structured/repetitive (about `22–34%` faster),
  while stored/random leadership remains intact.

- Removed redundant decoded-size passes from Brotli exact-size decode APIs.
  `decodeStreamIntoExactSize` now decodes once into the caller's exact window
  and maps an early `OutputTooSmall` or final length mismatch to `SizeMismatch`;
  allocator and append exact-size helpers reuse that contract instead of
  parsing every prefix tree two or three times. Existing undersized/oversized
  tests preserve public error behavior and append rollback. The libbrotli tool
  now records exact-allocation timing and gates it to at most twice caller-owned
  decode; on compressed rows allocation plus decode is roughly one decode pass
  (`~61 ms` per 1,000 calls) instead of decode plus the `~87–95 ms` preflight.

- Eliminated eager zero-initialization of all 96 bounded Brotli prefix-tree
  slots in each compressed meta-block header. The retained capacities remain
  unchanged (32 literal, command, and distance trees), but only the wire-
  declared slots are now initialized before use; context/block indices already
  validate every access. Layout diagnostics showed why this dominates: a
  `PrefixCode(256)` is 1,624 bytes, `PrefixCode(704)` is 4,312 bytes, and the
  full header is about 290 KiB. On the 1,000-call libbrotli matrix, text/
  structured/repetitive improve from roughly `0.31/0.25/0.36x` to
  `1.03/0.81/1.10x`, a `3.3–3.7x` Vort speedup without lowering feature limits.
  The gate floors rise to protect most of those gains.

- Changed production Brotli compressed-header parsing to construct the roughly
  290 KiB `MinimalCompressedHeader` directly in its caller-provided slot. A
  small value-returning wrapper remains for parser tests, but decode and strict
  size-preflight no longer return/copy the giant header object through function
  boundaries. Combined with lazy tree-slot initialization, the 1,000-call
  libbrotli matrix now reaches roughly `1.55/1.25/1.64x` on text/structured/
  repetitive, up from `1.03/0.81/1.10x`; exact-size allocation stays near one
  decode pass. Feature limits and all 32-tree fixtures remain unchanged.

- Expanded the Brotli reference matrix from quality 0 to supported quality-3
  text, structured, and repetitive frames. Probe runs showed qualities 1–3 all
  decode through the current native subset, while quality 4 introduces an
  unsupported shape and remains explicit follow-up work. On quality 3, Vort
  leads libbrotli 1.1.0 by roughly `1.85/1.49/2.20x`; the optional gate now
  locks both quality-0 and quality-3 rows so the header-layout wins are not
  limited to a single encoder setting.
  The tool also accepts `--case` and `--quality` for narrow support diagnostics.
  Quality-4 probing shows tiny/text/repetitive/random are already supported;
  structured data reaches missing static-dictionary transform tuples
  `(27, 9, 161)` and `(42, 9, 721)`. Experimental tuple additions advanced
  past `UnsupportedBrotliFeature` but did not yet produce the exact payload, so
  they were rejected rather than claiming incomplete dictionary compatibility.

- Replaced that narrow Brotli quality-4 dictionary dead end with a complete,
  dependency-free static dictionary module. `src/br/dictionary.bin` embeds the
  RFC 7932 122,784-byte dictionary, while the 207-line
  `src/br/static_dictionary.zig` owns length offsets, all 121 transforms, UTF-8
  uppercase behavior, and transformed-word scratch ownership. The previous
  proven tuple table remains the introspection/report surface and fast subset;
  missing tuples now fall back to the complete module. A focused transform test
  covers the quality-4 omit-last references, all 833 unit tests pass, and the
  structured quality-4 reference row now decodes exactly at about `1.38x`
  libbrotli throughput instead of returning `UnsupportedBrotliFeature`.

- Probed the expanded Brotli decoder through libbrotli qualities 5...11 on the
  locked text/structured/repetitive corpora. Every combination now round-trips
  natively; quality-11 rows are retained in the gate as the strongest encoder
  setting. Vort leads libbrotli 1.1.0 there by roughly `1.93/1.34/2.20x`, so the
  optional matrix now protects quality 0, 3, 4, and 11 instead of extrapolating
  from a fast encoder mode.

- Added a deterministic full-dictionary transform differential to the optional
  libbrotli gate. It samples five word indices at every RFC dictionary length
  4...24 and all 121 transforms (`12,705` cases), comparing Vort's embedded
  dictionary and UTF-8 transform implementation byte-for-byte with
  `libbrotlicommon`. This validates the complete fallback beyond the single
  quality-4 frame and catches offset, omit, affix, and uppercase drift without
  making the production library depend on the system runtime.

- Expanded the Zstd/libzstd gate with 512 KiB multi-block text, numbered JSON,
  and mixed structured/binary corpora. The easy repeated-text shape already
  reaches about `1.08x` libzstd, while realistic multi-sequence JSON and mixed
  binary currently reach only about `0.21/0.26x`; allocator decode is another
  `1.8–2.3x` slower because multi-block frames still use the strict preflight
  path. These rows prevent the strong single-sequence and raw results from
  hiding the remaining general FSE/Huffman and multi-block gaps.

- Extended the isolated known-size Zstd frame planner from exactly one block to
  one complete dictionary-free frame with any number of raw/RLE/compressed
  blocks. It scans only block headers and stored payload lengths, leaving all
  entropy/checksum/declared-size validation to the production decoder. This
  lets allocator decode reserve the declared output once and skip the full
  decoded-size preflight on common multi-block frames. The large text/JSON/
  mixed-binary allocator ratios fall from roughly `2.31/1.94/1.79x` caller-
  owned cost to about `0.96/1.00/0.99x`; concatenated, dictionary, and no-size
  streams retain the general path, with focused single/multi-block planner tests.

- Compacted Zstd sequence symbols from two machine-word fields to spec-bounded
  `u32` bases and `u16` next states, halving each FSE table entry on 64-bit
  targets without changing the public wire/API surface. Checked casts sit at
  parser/planner construction boundaries; 834 tests cover predefined, RLE, FSE,
  Repeat_Mode, malformed, and encoder use. On the 100-iteration general matrix,
  numbered JSON rises to about `0.22x`, huffman80k to `0.39x`, 512 KiB JSON to
  `0.24x`, and mixed binary to `0.32x` libzstd throughput. The corresponding
  conservative floors increase, while single-sequence text remains above `3x`.

- Compacted the temporary FSE table-construction baseline from `usize` to the
  format-bounded `u16`, with checked casts at the two state-assignment sites.
  This reduces the raw builder scratch footprint before symbols are converted
  into the already-compact decode table. The 100-iteration matrix keeps
  huffman80k near `0.39x`, lifts 512 KiB JSON to about `0.25x`, and mixed binary
  to about `0.32x` libzstd throughput; all 834 sequence/parser/encoder tests and
  the 124-case lib-generated probe pass. Multi-block floors rise accordingly.

- Reused the bounded reverse-bit-reader prefix extraction for Zstd's narrow
  initial and transition FSE states. These reads are at most 11 bits, so the
  sequence loop now avoids the generic `u72` gather while retaining one shared
  reader implementation and an independent per-bit oracle. Ten interleaved
  ReleaseFast 100-iteration A/B rounds against the prior commit improve median
  huffman80k, 512 KiB JSON, and mixed-binary decode time by about
  `2.8%/2.7%/1.3%`; single-sequence text is neutral. The retained 13-row gate
  reports about `0.45x/0.26x/0.32x` libzstd throughput for those FSE-heavy rows,
  raises their conservative regression floors, and all 835 tests plus the
  124-case lib-generated differential pass.

- Moved Zstd FSE decode-table construction into the focused
  `zstd/sequence/fse_builder.zig` module and replaced per-symbol spread-position
  sorting with the standard linear state-order pass for 256/512-state tables.
  The smaller tables retain the compact reference constructor; the linear path
  is kept out of line so table setup does not inflate the sequence loop. Ten
  alternating fixed-P-core ReleaseFast rounds improve huffman80k, 512 KiB JSON,
  and mixed binary by about `10.2%/5.9%/4.8%`, while no-FSE rows are neutral.
  The retained gate reaches about `0.46x/0.29x/0.34x` libzstd on those rows and
  raises their floors. A byte-for-byte oracle compares the new constructor to
  the sorted reference, all 837 tests pass, and the 124-case lib-generated
  differential remains clean.

- Removed three unconditional 4 KiB FSE-table clears from Zstd sequence-mode
  parsing. Non-compressed modes observe only zero `len`/`accuracy_log`, while a
  compressed mode overwrites every active entry before the mode-guarded decoder
  can access it; the parser now initializes only that metadata instead of all
  1,536 unused symbols per block. Ten alternating fixed-P-core ReleaseFast
  rounds improve numbered JSON, mixed binary, huffman80k, and 512 KiB JSON by
  about `17.8%/4.5%/2.0%/1.2%`; the retained gate reports roughly
  `0.29x/0.35x/0.51x/0.29x` libzstd and raises conservative floors. All 837
  tests and the 124-case lib-generated differential pass.

- Inlined Zstd's repeat/direct offset resolver into the FSE sequence loop after
  perf attributed about 6% of `readModeSequence` samples to the small helper's
  call boundary. Ten interleaved fixed-CPU ReleaseFast rounds improve median
  huffman80k, 512 KiB JSON, binary-mixed, and numbered-JSON caller-owned decode
  time by about `4.0%/3.5%/0.5%/4.4%`, respectively. The retained conservative
  libzstd floors rise to `0.44/0.27/0.32/0.24x`; the existing repeat-selector,
  direct-offset, `rep0 - 1`, and invalid-match tests remain the expanded-path
  behavior oracle.

- Split large zero-sequence Zstd Huffman literal sections into a compact lookup
  loop plus an out-of-line canonical stream-tail fallback. Perf showed
  `HuffmanLiteralCursor.readSymbol` at about 71% of the 64 KiB ASCII decode and
  revealed that the fallback's Zig std tree query takes the 1 KiB tree by value;
  keeping that rare path inline gave every successful lookup a roughly 1.1 KiB
  frame. The specialized path is limited to 16 KiB+ full literal sections so
  sequence-interleaved and small sections retain their prior code shape. Ten
  fixed-CPU interleaved rounds improve `ascii64k` median decode time by about
  `4.9%`; the conservative libzstd floor rises from `0.07x` to `0.10x`, while
  huffman80k, large JSON, mixed binary, and numbered JSON stay neutral or
  improve in the same matrix.

- Added a four-stream bulk Huffman loop for the same 16 KiB+ zero-sequence
  literal sections. Zstd defines each regenerated stream segment as
  `ceil(literals / 4)`, so the decoder now advances streams at known output
  boundaries and keeps full-width lookup guarantees inside each segment. This
  removes the per-symbol `min(available, max_bits)` and stream-tail decision
  while retaining the canonical decoder for the few trailing bits in each
  stream. Ten fixed-CPU 500-iteration A/B rounds reduce `ascii64k` median time
  from about `218.9 ms` to `181.3 ms` (`17.2%`); the libzstd floor rises from
  `0.10x` to `0.13x`. Existing four-stream, checksum, malformed-tail, and
  lib-generated compatibility coverage exercise the stream-boundary behavior.

- Specialized the four-stream bulk loop's reverse prefix gather. Once the loop
  has established that a full Huffman width remains, the touched byte count is
  determined entirely by `start & 7 + width`; the new reader chooses its
  one-, two-, or three-byte reservoir directly instead of recomputing both end
  byte indexes and their difference. An exhaustive alignment/width oracle
  compares it with the checked generic prefix reader for widths 1...11. Seven
  fixed-CPU 500-iteration A/B rounds reduce `ascii64k` median time from about
  `219.2 ms` to `182.9 ms` (`16.5%`), raising its conservative libzstd floor
  from `0.13x` to `0.14x`; other decode shapes do not call this bulk helper.

- Removed the redundant checked skip after a successful four-stream bulk
  Huffman lookup. The outer loop has already established that at least the full
  table width remains, while every valid entry consumes no more than that
  width, so the reader can update `remaining_bits` directly without another
  comparison. Seven fixed-CPU 500-iteration A/B rounds reduce `ascii64k` median
  time from about `182.48 ms` to `180.46 ms` (`1.1%`). A broader attempt to
  fuse the table load and reader update regressed and was fully reverted.

- Added a narrow Zstd sequence executor for large raw-literal blocks whose
  literal-length and offset tables are FSE while match length is RLE. The path
  is gated to 1,024+ sequences, eliminating three per-sequence mode switches
  and the never-changing match-length state without perturbing mixed Huffman or
  smaller blocks. Ten fixed-CPU 1,000-iteration A/B rounds reduce the 512 KiB
  mixed-binary median from about `142.72 ms` to `137.09 ms` (`3.9%`), raising
  its conservative libzstd floor from `0.32x` to `0.36x`. Broader raw-literal
  and extra-bit fast paths regressed other FSE shapes and were fully reverted.

- Added a matching executor for 1,024+ sequence blocks whose LL/OF/ML tables
  are all FSE and whose literals are Huffman-compressed. It hoists the three
  table-mode switches out of the sequence loop and keeps Huffman literal replay
  beside the decoded match, while preserving the generic path for small and
  mixed-mode blocks. Ten fixed-CPU 200-iteration A/B rounds reduce the 512 KiB
  JSON median from about `46.997 ms` to `39.972 ms` (`14.9%`) and improve the
  5,161-sequence raw-literal stress row by about `4.2%`. The conservative
  `large_json` libzstd floor rises from `0.27x` to `0.32x`; smaller numbered
  JSON stays on the generic path.

- Expanded the LZ4/liblz4 caller-owned matrix with a deterministic 256 KiB
  incompressible, literal-only block. This separates real bulk-copy throughput
  from the existing 1 KiB row's fixed call overhead and locks the one-literal,
  zero-match shape. Current ReleaseFast evidence is about `0.76x` liblz4, so the
  gate records a conservative `0.70x` floor instead of hiding the remaining
  large-literal gap behind Vort's strong compressed rows. Two production
  fast-path attempts were rejected: a general literal-only precheck regressed
  1 KiB input by about 9.8%, while a large-only precheck gained about 1.8% at
  256 KiB but regressed tiny and 1 KiB rows sharply. Both were fully reverted.
  A later parser-only optimization keeps the ordinary scalar length-extension
  loop intact but scans genuinely long 0xff extension runs in 32-byte chunks.
  Seven alternating fixed-CPU baseline/candidate rounds improved Vort elapsed
  time by about 9.6% at the median (`0.83x -> 0.90x` liblz4), while targeted
  ordinary compressed rows stayed within noise or improved. The gate now
  requires `0.85x`; malformed unterminated extensions have a focused oracle.
  Perf then attributed about 52% of the remaining literal-only time to Zig's
  generic compiler-rt memcpy. The caller-owned decoder now sends only final
  literals of at least 512 bytes through an out-of-line four-vector copy loop,
  leaving ordinary literal/match decoding on the compact existing path. Five
  interleaved fixed-CPU rounds move the 256 KiB row from roughly `0.91x` to
  `0.99x` liblz4 median throughput, with text/structured/repetitive/RLE rows
  within noise; the retained conservative floor rises to `0.88x`. Focused copy
  tests cover the threshold, vector tail, and scalar tail boundaries.

- Added a true system-libzstd compatibility probe under `tools/zstd/`, separate
  from the native-writer probe. It dynamically loads libzstd only in the tool,
  generates 160 frames across compression levels 1/3/9/19, four corpus shapes,
  and sizes from empty through 512 KiB, then decodes every frame through Vort's
  dependency-free public API and requires byte-exact output. All 160 currently
  pass against libzstd 1.5.5. This closes a validation naming/coverage blind
  spot without adding a runtime dependency to the production library.

- Added a same-process Zstd encode comparison against libzstd 1.5.5 at levels
  1/3/9. It validates both directions (libzstd decodes Vort output and Vort
  decodes reference output) before timing, and records compressed size plus
  interleaved fixed-process throughput for text, JSON, and mixed binary. The
  first pinned evidence exposes the encoder gap directly: text is `1.16x` the
  reference size, JSON is `18.5–25.0x`, and mixed binary is `3.71x`; encoding
  throughput is below 1% of libzstd on every row. Vort output is currently
  identical across levels 1/3/9 in this first matrix, confirming that output
  strategy differentiation remains incomplete. Levels now at least map to
  increasing bounded planner budgets (`16/64/512` for 1/3/9); the pinned JSON
  row shows the expected search-cost progression, while its unchanged size
  localizes the next ratio target to the 32-sequence bootstrap-plan ceiling
  rather than another budget increase. The gate is intentionally evidence-first
  and will anchor the next sequence-planner work.
  Raising that bounded plan to 128 sequences reduces the locked 32 KiB JSON
  stream from 16,893 to 13,688 bytes (`19.0%`) while leaving text and binary
  unchanged. A 64-entry intermediate produced 15,740 bytes; 256 entries were
  byte-identical to 128, so the larger footprint was rejected. Even after this
  gain, JSON remains `15–20x` libzstd, showing that candidate quality and the
  one-plan-per-block model—not only sequence capacity—remain major gaps.
  The lookahead planner now considers a second duplicate candidate that begins
  exactly at the current literal cursor, in addition to the prior globally
  cheapest later match. This preserves already-emitted block history and gives
  level 9 enough budget to avoid locally skipped bytes, reducing the same JSON
  wire further from 13,688 to 13,506 bytes (`1.3%`) without changing level-1/3,
  text, or binary sizes. Large-block cursor lookup uses the existing eight-byte
  hash predicate rather than adding another unconditional bytewise quadratic
  scan; focused lookahead/cache tests lock the new candidate choice.
  One-shot level encoding now evaluates a level-specific smaller-block frame
  beside the standard 128 KiB-block frame and returns only the shorter complete
  interoperable stream. This preserves the 93-byte cross-block repeated-text
  result that a forced 8 KiB split expanded to 437 bytes, while level-1 JSON
  falls from 13,688 to 13,042 bytes and mixed binary from 31,953 to 30,690.
  Focused tests require the selector never to expand repeated text and to pick
  the split winner for structured data; the encode gate locks both improvements.
  Expanding that selection from one split to a two-entry per-level ladder finds
  much smaller entropy blocks without risking the repeated-text regression. For
  levels 1/3/9 it evaluates `1/2`, `2/4`, and `4/8 KiB` respectively; JSON now
  measures 11,208/9,983/9,728 bytes, while mixed binary reaches
  29,073/29,735/30,690. The full-frame selector retains the original 93-byte
  text frame at every level. This remains ratio-first and expensive because each
  one-shot call builds three complete candidates; reusable planning and cheap
  split scoring are explicit follow-up performance work.
  The encoder now adds a full-block greedy hash-chain sequence candidate built
  on the shared LZ77 planner. Unlike bounded recursive lookahead, it covers the
  whole entropy block linearly and then reuses the existing RLE/predefined/FSE
  wire cost selection. On the locked 32 KiB matrix this is the first order-of-
  magnitude ratio improvement: JSON level 1/3/9 falls to 2,568/1,782/1,336
  bytes and mixed binary to 11,809/10,176/9,384, while repeated text remains
  93 bytes. Libzstd is still smaller (`838/912/677` JSON and `8,609` binary),
  but the gap contracts from roughly `10–14x` to `1.1–3.1x`. Existing shape-
  specific tests now assert semantic properties rather than a fixed sequence
  count/table mode when the new strictly smaller candidate legitimately wins.
  The same shared-parser candidate now compares a 128-chain greedy parse with a
  lazy parse (`lazy_min_gain=1`) and keeps the shorter final Zstd block. This
  trims JSON level 1/3/9 again to 2,484/1,697/1,312 bytes and mixed binary to
  11,802/10,170/9,358, with no text regression. The remaining ratio gap is now
  about `1.94–2.96x` on JSON and `1.09–1.37x` on binary; throughput remains far
  behind because ratio-first one-shot mode evaluates multiple complete parser,
  table, block-size, and frame candidates.
  Adding the shared fixed-cost optimal parser to that same final-wire selection
  trims JSON level 1/3/9 to 2,443/1,671/1,262 bytes and binary level 3/9 to
  10,155/9,344, while text and binary level 1 remain unchanged. The optimal
  parser is not trusted as universally better: it competes with greedy/lazy and
  only its smaller actual Zstd block survives. JSON remains `1.83–2.92x`
  libzstd, so future ratio work needs a Zstd-specific entropy-aware parser rather
  than further tuning the shared deflate-style fixed-cost model.
  One-shot multi-block encoding now uses the same caller-owned rolling-history
  index as the incremental encoder. Completed blocks are indexed before the next
  block is planned, letting adaptive splits retain legal cross-block matches
  instead of treating every entropy block as an independent stream. JSON level
  1/3/9 falls to 2,420/1,648/1,239 bytes; text and binary remain unchanged. The
  history is bounded to the advertised Zstd window and allocator reservation
  occurs before emitting each block, preserving deterministic failure semantics.
  Expanding the bounded rolling-history plan from 8 to 32 matches lets one block
  exploit many repeated regions from its predecessors instead of stopping after
  the first few. JSON level 1/3 falls from 2,420/1,648 to 1,505/1,505 bytes and
  mixed binary from 11,802/10,155 to 9,274/9,274; text and level-9 winners are
  unchanged. Each lookup remains four-way set associative, so work is bounded
  at 128 candidate comparisons per block rather than growing with stream size.
  The Zstd encode comparison accepts `--case` and `--level` filters in addition
  to iteration/round controls. Development experiments can now run one pinned
  row (for example JSON level 9) before the complete 3x3 compatibility gate is
  executed once at integration, avoiding repeated multi-minute matrices.
  A final capacity sweep from 64 to 128 history matches unlocks the high-budget
  level-9 winner: JSON falls from 1,239 to 1,058 bytes and mixed binary from
  9,116 to 9,009, with all other rows unchanged. The fixed plan grows by about
  1.5 KiB (`Match` plus four `usize` arrays), while lookup work stays bounded to
  four candidates per emitted match. Level-9 binary is now `1.046x` libzstd and
  JSON `1.563x`.
  Raising only the history-plan output capacity from 32 to 64 (without changing
  four-way hash associativity) gives the remaining structured blocks room to
  retain more valid cross-block matches. JSON level 3 falls from 1,505 to 1,350
  bytes and mixed binary level 3/9 from 9,274/9,344 to 9,116/9,116; other rows
  are unchanged. The plan remains fixed-size and bounded to 256 candidate checks
  per block.
  Added a dependency-free standard Zstandard full-dictionary inspector. It
  validates the `0xEC30A437` magic and non-zero Dictionary_ID, parses the
  embedded Huffman plus OF/ML/LL FSE entropy headers through the production
  readers, validates all three repcodes against the remaining history content,
  and returns a borrowed `{id, content}` view. A locally trained libzstd 1.5.5
  dictionary is accepted with the same ID reported in its header; malformed
  magic, entropy payloads, zero IDs, truncated repcodes, and out-of-range
  repcodes are rejected. Entropy seeding for Repeat_Mode remains the next full-
  dictionary integration step rather than silently treating headers as content.
  `StandardDictionaryView` now exposes the three validated repcodes and exact
  raw-content offset, and `NativeDictionary.initFromStandardDictionary` creates
  a borrowed preset-history dictionary with the standard Dictionary_ID while
  returning the full view for future entropy-state seeding. This makes partial
  support explicit: content matches interoperate today, but callers can see that
  trained entropy tables/repcodes are parsed rather than falsely claimed active.
  The libzstd runtime harness now exposes dictionary-aware encode/decode calls,
  and a focused differential verifies that libzstd 1.5.5 decodes Vort output
  produced from a standard full dictionary's borrowed content and ID. The
  reverse direction now also passes: `NativeDictionary` retains an optional
  borrowed full-dictionary byte view, and all one-shot size/decode paths seed
  the frame's Huffman tree, OF/ML/LL FSE tables, and repcodes before the first
  block. This closes libzstd full-dictionary first-block `Repeat_Mode` decoding
  without changing raw-content dictionary behavior or introducing global state.
  The incremental direct-output preflight and active sequence state now receive
  the same parsed dictionary entropy seed, and the bidirectional differential
  drains a libzstd full-dictionary frame through 3-byte input and 5-byte output
  chunks before `finish()`. One-shot, size-preflight, buffered fallback, and
  direct incremental decoding therefore share full-dictionary behavior.
  The same externally generated frame now passes through a mixed raw/full
  `DictionarySet`, two compressed input chunks, and dictionary-set incremental
  direct output. Selection is strictly by frame Dictionary_ID, so a preceding
  unrelated raw dictionary cannot shadow the full dictionary's entropy state.
  `run-zstd-full-dictionary-diff` now creates a deterministic 40-file JSON
  training corpus, invokes the installed zstd trainer with a fixed Dictionary_ID,
  and runs the bidirectional one-shot/chunked/incremental Zig probe. Standard
  dictionary compatibility is therefore reproducible from a clean checkout
  instead of depending on a manually retained temporary dictionary.
  Added `OwnedStandardDictionary.initCopy` for applications that load trained
  dictionaries from temporary I/O buffers. It validates before allocation,
  reparses the owned slice so the view/content/full-byte borrows share its
  lifetime, exposes `asDictionary()` with entropy-capable standard bytes, and
  has explicit allocator deinitialization. The external probe checks ownership
  pointer relationships as well as ID/repcodes/content metadata.
  Public dictionary values now report `DictionaryKind` (`raw_content` versus
  `standard_full`) and standard dictionaries can return a revalidated optional
  `standardView()`. The lightweight deterministic trainer explicitly produces
  raw-content dictionaries, while imported full dictionaries retain entropy and
  repcode metadata. This removes API ambiguity without falsely labeling the
  phrase trainer as COVER/fastCover-compatible.
  Public Zstd compression levels now declare and enforce the supported `0...22`
  range across bound, alloc, append, into, dictionary, and dictionary-set
  facades. Invalid negative or above-maximum levels fail with
  `InvalidBlockPlan` instead of silently mapping to fastest or maximum search;
  level 0 remains the explicit raw/RLE fastest mode.
  `summarizeStandardDictionary` exposes validated entropy metadata without
  leaking internal decode tables: LL/OF/ML entry counts and accuracy logs, the
  content boundary, Dictionary_ID, and repcodes. The trained-dictionary probe
  prints and cross-checks this summary, giving catalogs an auditable surface for
  selecting compatible dictionaries before constructing codec state.
  Added allocation-free `isStandardDictionary` and `standardDictionaryId`
  probes for catalog discovery. They inspect only the bounded 8-byte magic/ID
  prefix and intentionally do not imply entropy validity; callers use the strict
  inspector before codec construction. Tests distinguish short input, zero IDs,
  valid prefixes with truncated entropy, and strict full validation.
  Added dictionary-set-aware native stream summaries. They resolve every
  non-zero frame Dictionary_ID against the caller's catalog, fail early with
  `NeedDictionary` when missing, and report resolved plus standard-full frame
  counts alongside existing block/checksum/content-size metadata.
  Single-dictionary convenience and dictionary/dictionary-set diagnostics
  variants complete the summary API matrix, matching the decode surfaces while
  retaining phase/offset context for missing catalog entries.
  ReleaseFast profiling of the native Zstd encoder found that recursive
  mixed-family lookahead dominated levels 1-3 even though the hash planners
  selected equally small output on the locked 32 KiB corpus. The encoder now
  reserves that ratio-oriented search for level 4+ (or explicit budgets of at
  least 96 states). A same-machine one-iteration smoke retained all nine wire
  sizes while moving level-1 text/JSON/binary from roughly 2.36/11.08/0.48 s to
  0.43/2.49/0.33 s and level-3 from 20.03/15.24/0.52 s to
  1.27/2.99/0.35 s. These absolute times still trail libzstd by orders of
  magnitude; the ReleaseFast gate now prevents the low-level planner cliff from
  returning while broader parser consolidation remains open.
  Candidate-family ablation then showed that the separate lazy hash pass does
  not improve any locked level-1 wire. Level 1 now defers that duplicated search
  while level 2+ retains it; this preserves all nine encode-gate sizes instead
  of taking the observed two-byte level-3 regression from a broader cutoff.
  Scheduler variance obscured a stable end-to-end multiplier, so this is
  retained as a structural full-pass removal rather than a throughput claim.
  The ReleaseFast encode gate pins the level-1/3 1505/1350-byte wires and
  cross-decoder round trips; unit tests pin the level-to-budget boundary.
  A second candidate-family ablation found the legacy multi-duplicate planner
  was also redundant at level 1: greedy/optimal plans preserved all nine locked
  sizes, while removing both single- and multi-duplicate paths broke the 93-byte
  text wire. Level 1 therefore skips only multi-duplicate scanning and keeps the
  single-match fallback. The same one-iteration smoke moved JSON from about
  2.60 s to 0.88 s, text from 0.46 s to 0.26 s, and binary from 0.31 s to
  0.17 s with byte-identical gate outputs; level 2+ retains ratio arbitration.
  The required single-match fallback no longer uses an O(n²) byte-pair scan on
  blocks up to 4 KiB. An exact 8-byte hash chain visits every possible >=8-byte
  match in the same earliest-position order, with randomized plus adversarial
  equivalence tests against the retained scan oracle. Repeat-3 level-1 smokes
  kept 93/1505/9274-byte text/JSON/binary wires and measured roughly
  0.18/0.85/0.14 s; JSON is now dominated elsewhere, while text and binary
  benefit from removing the quadratic small-block matcher.
  The bounded large-block duplicate hash path now tracks the valid length of
  each eight-entry bucket, replacing a 1 MiB sentinel initialization with a
  32 KiB count clear. A retained sentinel-table oracle test covers multiple
  start offsets and long competing matches, proving identical candidate order
  and selection.
  Both exact and bounded large-block duplicate matchers now stop once the
  remaining suffix is shorter than the current longest match: later positions
  cannot win the existing length-first ordering. An explicit late equal-length
  boundary test complements the scan-oracle comparison. A repeat-5 level-1
  smoke kept the 93-byte text wire and measured about 0.097 s; binary remained
  scheduler-variable at about 0.21 s, so the safe search-bound reduction is
  retained without claiming an across-corpus multiplier.
  Single-sequence candidates now skip generic mixed/compressed FSE table-plan
  enumeration during both scoring and emission. RLE and predefined dedicated
  paths already cover the useful one-sequence representations, and the focused
  planner test proves the generic mixed plan is no smaller on the locked case.
  Repeat-3 level-1 smokes retained 93/1505/9274-byte wires while measuring about
  0.046/0.255/0.121 s for text/JSON/binary, substantially reducing repeated
  full-payload pricing on the remaining single-match fallback.
  Generic multi-sequence table planning now computes the literals-section size
  once per sequence plan and reuses it across the LL/OF/ML alternative Cartesian
  product. This removes repeated literal scans and Huffman length construction
  without changing table enumeration or wire selection. Repeat-3 JSON smokes
  retained 1505/1350-byte level-1/3 output at roughly 0.30/0.95 s; this is a
  structural cost reduction because shared-machine timing remains variable.
  LL/OF/ML generic table alternatives now also precompute their independent
  table-payload and bit-count contribution once, instead of rebuilding the full
  interleaved read-field stream for every Cartesian-product combination. Offset
  alternatives retain their own repeated-offset simulation, so direct/repeat
  selector validity and wire cost remain exact. Focused RLE/predefined and all
  compressed-FSE emitter tests pass; repeat-3 JSON retained 1350/1058-byte
  level-3/9 wires while measuring roughly 1.36/8.98 s.
  Final sequence emission now materializes the selected plan's literals section
  once and shares the encoded prefix across RLE, predefined, and generic table
  candidates. Direct focused emitter APIs retain their self-contained wrappers,
  while the production best-of-three path avoids two repeated literal/Huffman
  builds. Focused compressed-FSE and mixed-table wires remain unchanged;
  repeat-3 JSON level 3 measured about 0.92 s at the same 1350 bytes.
  The winning generic table-plan candidate now also retains its already-built
  interleaved read fields. Production emission consumes those fields directly
  instead of repeating LL/OF/ML symbol lookup, FSE transition reconstruction,
  and repeated-offset simulation after selection. Focused direct-emitter calls
  keep the rebuilding fallback; repeat-3 JSON level 3 remained 1350 bytes at
  roughly 0.88 s.
  The best-of-three sequence emitter now reuses one candidate scratch buffer and
  one retained-best buffer instead of keeping three independently allocated
  complete blocks alive. Tie behavior remains first-candidate-wins, preserving
  deterministic wires. Focused RLE/predefined/FSE tests remain byte-identical;
  timing was mixed on the shared host, so this is retained for lower allocation
  churn and peak temporary memory rather than a throughput claim.
  The outer native match best-of-seven now applies the same scratch-plus-retained
  winner design across mixed, greedy, lazy, optimal, repeated, multi-duplicate,
  and single-duplicate candidates. Candidate order and strict-shorter tie rules
  are unchanged; focused shortest-plan and non-greedy lookahead tests pass. A
  repeat-3 smoke retained JSON level-3 at 1350 bytes around 0.87 s and text
  level-1 at 93 bytes around 0.068 s.
  Greedy hash parsing on <=32 KiB blocks now reuses a token ArrayList owned by
  the outer match planner instead of allocating a fresh token slice per block.
  Larger blocks keep the existing heap/ring parser. A focused A/B test proves
  byte-identical output against the allocating greedy path and verifies retained
  capacity across calls; repeat-3 JSON level 1 retained 1505 bytes around
  0.27 s.
  The small-block lazy hash parser now exposes the same reusable-token core and
  Zstd owns a separate lazy token scratch for level 2+ candidates. Allocating
  wrappers delegate to that shared state machine, and LZ77 plus Zstd focused
  tests prove token/stat and wire identity while retained capacity remains
  stable. Repeat-3 JSON level 3 retained 1350 bytes around 0.88 s.
  The optimal parser now accepts an explicit reusable scratch that owns DP
  costs, chosen steps, hash head/predecessor arrays, and output tokens. Its
  allocating API delegates to the same core, while Zstd retains one scratch per
  outer match decision. LZ77 and Zstd A/B tests prove token/stat/wire identity
  and stable capacities; repeat-3 JSON level 3 remained 1350 bytes around
  0.85 s.
  Optimal hash-chain construction now protects its uninitialized reusable head
  array with the existing 4 KiB initialization bitmap instead of clearing the
  full 256 KiB head table on every block. The predecessor invariant remains
  unchanged, and all optimal parser candidate-budget and token-bound tests pass.
  Optimal's reusable hash storage is now a standalone `HashIndex` with explicit
  build, ownership, and per-position best-match query contracts. Optimal parsing
  consumes this index unchanged; focused tests pin deterministic position
  matches, input-length validation, and the existing optimal token/budget wires.
  This establishes the shared candidate-graph boundary needed to migrate greedy
  and lazy parsing without coupling those strategies to optimal DP storage.
  A direct greedy-on-prebuilt-index experiment round-tripped but did not preserve
  streaming-greedy token distances because a completed index exposes different
  head order/visibility than incremental insertion. It was rejected rather than
  silently changing fast-parser wires; future sharing must preserve an explicit
  per-position snapshot or candidate list, not reuse only final hash heads.
  Optimal's fixed-distance bit costs are now a compile-time 32 KiB lookup rather
  than a stack table rebuilt for every block. An exhaustive 1...32768 test pins
  every entry to the scalar formula. Together with the extracted `HashIndex`,
  this removes another fixed per-block pass without changing parser choices.
  Optimal's three-byte hash chain now rejects fourth-byte mismatches before the
  full word-at-a-time match-length loop whenever `min_match >= 4` (the Zstd
  configuration). An exact-four-byte regression test protects the boundary.
  Repeat-3 level-9 binary/JSON retained 9009/1058-byte wires at roughly
  0.12/9.25 s; the binary hot shape benefits while JSON remains DP-heavy.
  Optimal DP now builds one per-position prefix table mapping each reachable
  maximum match length to the exact best `(fixed length cost + suffix cost)`
  and longest equal-cost length. Hash-chain candidates then query that table in
  O(1) instead of rescanning every shorter length for every distance. A randomized
  exhaustive 4...258 oracle test preserves the old descending-scan tie rule;
  repeat-3 level-9 JSON retained 1058 bytes at roughly 9.46 s on the noisy host.
  The prefix table is now extended lazily only when a real hash candidate
  reaches a new maximum match length, so positions without matches and shorter
  later candidates avoid unnecessary suffix-cost work. The oracle exercises
  staged 4...37...131...258 growth and retains the exact longest-on-tie rule; repeat-3
  level-9 JSON/binary kept 1058/9009 bytes at roughly 8.37/0.13 s.
  Profiling then exposed the recursive mixed planner, rather than optimal
  LZ77, as the level-9 JSON bottleneck: Huffman scoring copied a roughly 3 KiB
  plan by value and linearly searched its symbol list for every literal on
  every explored branch. Huffman helpers now borrow that plan and finalized
  plans carry a dense byte-to-bit-count lookup. The 32 KiB JSON wire remains
  1058 bytes while repeat-3 encode time fell from roughly 8.25 s to 2.55 s on
  the same host. Mixed lookahead now also accumulates its winner in place:
  losing recursive branches no longer copy five fixed 128-entry plan arrays
  on return and again while unwinding. An interleaved four-pair check retained
  the 1058-byte wire and measured roughly 2.51 s versus the prior 2.52 s
  median, a small improvement after the much larger Huffman lookup win. Each
  finalized mixed candidate now also computes its literal-section size once
  and shares it across RLE, predefined, and mixed table scoring; a six-pair
  interleaved check retained 1058 bytes and moved the median from roughly
  2.50 s to 2.41 s. Generic table arbitration now defers construction of the
  768-entry read-field schedule until after choosing the cheapest LL/OF/ML
  combination instead of rebuilding it for interim winners. A further six-pair
  interleaved check retained 1058 bytes and moved the median from roughly
  2.55 s to 2.17 s. The scoring result itself is now compact as well: it no
  longer returns the 768-entry read-field array through recursive lookahead;
  that schedule is built only when the winning table plan is actually emitted.
  A final six-pair check retained 1058 bytes and moved the median from roughly
  2.11 s to 1.63 s. Predefined-table DP now stores next-state choices as `u8`
  and relies on the existing per-row write invariant instead of clearing an
  8 KiB `usize` matrix on every attempt. Another six-pair check retained 1058
  bytes and moved the median from roughly 1.94 s to 1.71 s. Duplicate matching
  now verifies its (possibly colliding) eight-byte hash anchor and extends true
  matches with unaligned word loads plus `ctz` rather than a byte loop. The
  existing exact/sentinel matcher oracles and the 328-case external probe
  retain candidate, tie, and wire behavior; a six-pair check kept 1058 bytes
  and moved the level-9 JSON median from roughly 1.56 s to 0.96 s. Predefined
  sequence planning now represents each viable-state row as a `u64`; range
  masking plus `ctz` replaces per-transition scans while preserving the lowest
  viable-state tie rule. The independent `usize`-matrix oracle covers all
  three predefined tables through 128-value plans; a six-pair check retained
  1058 bytes and moved the median from roughly 0.93 s to 0.86 s. The duplicate
  extension loop now compares two words per iteration after the verified hash
  anchor, preserving the exact `ctz` mismatch offset while reducing loop
  overhead on long structured matches. A six-pair check retained 1058 bytes
  and moved the median from roughly 0.87 s to 0.83 s. Canonical LL/ML/OF
  value-to-code conversion now uses their monotone range structure rather than
  scanning all table entries, with an exhaustive oracle over the supported
  value ranges; a six-pair check retained 1058 bytes and moved the median from
  roughly 0.82 s to 0.79 s. Predefined FSE planning now also uses compile-time
  code-to-state masks, iterating only states that can encode the current value
  instead of rechecking every state; the independent matrix oracle still
  matches through 128-value plans. A six-pair check retained 1058 bytes and
  moved the median from roughly 0.79 s to 0.64 s. Mixed lookahead now maintains
  a backtracked histogram of the logical literal stream, removing each match's
  covered interval on descent and restoring it on unwind. Exact payload scoring
  builds Huffman weights from that histogram instead of rescanning all literal
  runs; a direct full-scan oracle covers a non-zero first match and three-level
  path. A six-pair check retained 1058 bytes and moved the median from roughly
  0.65 s to 0.63 s. Huffman length generation now uses a 64-symbol compact
  alphabet whenever the plan's highest byte permits it, avoiding full 256-way
  package-merge state for JSON/text candidates. A full-width length oracle
  preserves every active symbol length; a six-pair check retained 1058 bytes
  and moved the median from roughly 0.76 s to 0.64 s. Single-stream Huffman
  sizing now sums bit lengths directly rather than routing every byte through
  the four-stream boundary tracker. A fragmented-run oracle preserves the
  exact serialized length; a six-pair check retained 1058 bytes and moved the
  median from roughly 0.66 s to 0.63 s. Mixed-candidate memoization now uses a
  fixed open-addressed index instead of linearly scanning up to 512 cached
  positions on every recursive lookup. Collision and repeat-hit oracles preserve
  candidate snapshots; a fixed-CPU eight-pair check retained 1058 bytes and
  moved the median from roughly 0.82 s to 0.69 s. Public allocating level encode
  now evaluates the two adaptive split candidates on worker threads while the
  caller thread evaluates the primary frame through a mutex-wrapped caller
  allocator, then applies the original strict primary...4 KiB...8 KiB
  shortest-frame order. A serial-selection oracle preserves the exact wire;
  fixed-CPU-8..10 eight-pair JSON checks retained 1058 bytes and moved the
  median from roughly 0.63 s to 0.31 s. Compressed sequence-plan scratch now
  stores FSE states and transition values as `u8`, matching the 64-state table
  bound and shrinking the large union copied during LL/OF/ML arbitration. A
  state-bound oracle covers the compact fields; fixed-CPU-8..10 eight-pair
  checks retained 1058 bytes and moved the median from roughly 0.312 s to
  0.298 s. Mixed-prefix scoring now uses a payload-only table selector that
  never materializes or returns the large LL/OF/ML plan union; the emitter keeps
  the full-plan path and an oracle checks both selectors choose the same byte
  length. Fixed-CPU-8..10 eight-pair checks retained 1058 bytes and moved the
  median from roughly 0.327 s to 0.318 s. A search-budget sweep showed that
  4/8 KiB candidates retain 1350/1058 bytes from 96 through 512 states, while
  the one-block candidate reaches its 13506-byte plateau at 192. Levels 6+ now
  cap mixed search at 192 states; fixed-CPU-8..10 eight-pair level-9 checks
  retained 1058 bytes and moved the median from roughly 0.317 s to 0.207 s.
  An end-to-end fixed-core comparison against the start of this optimization
  series (`36518f8`) measures 8.283 s versus 207.425 ms, a 39.93x cumulative
  speedup with the same 1058-byte frame. Fresh profiling then put 42% of sampled
  self time in the bounded duplicate matcher. Its eight-entry newest-first hash
  buckets now use a packed length/insertion-index ring instead of shifting up to
  seven entries for every source byte, while preserving traversal and eviction
  order. The sentinel reference oracle explicitly covers wraparound; fixed-CPU-
  8..10 eight-pair checks retained 1058 bytes and reduced the median from
  207.480 ms to 166.766 ms (1.244x). Long duplicate extensions now compare
  32-byte vectors and use the first unequal-lane bit instead of issuing two
  scalar word comparisons per loop. An explicit anchor/vector/word/byte boundary
  oracle preserves exact match lengths; another fixed-core eight-pair run kept
  1058 bytes and reduced the median from 166.959 ms to 160.659 ms (1.039x).
  Huffman stream sizing now proves its worst-case aggregate bit count once from
  `(regenerated length * maximum code width)`, then uses unchecked additions in
  the per-literal loop. Existing single-stream and mixed-histogram full-scan
  oracles preserve the byte count; two fixed-core eight-pair runs retained 1058
  bytes and consistently improved the median by about 1.7% (160.265 ms to
  157.527 ms in the first run).
  Sequence-table bit-cost scoring now dispatches once per RLE/predefined/
  compressed alternative and walks that representation directly. This avoids
  copying and reopening the large tagged plan for every sequence symbol while
  retaining identical offset-history validation. A generic-symbol reference
  oracle covers every available mode across LL/OF/ML; two fixed-core interleaved
  runs kept 1058 bytes and improved the median by roughly 7.7-7.8% (157.287 ms
  to 146.031 ms in the first run).
  The exact matcher for <=4 KiB candidates now clears a 512-byte occupancy
  bitmap instead of initializing two 16 KiB head/tail arrays. Head and tail are
  initialized lazily on first use, preserving the append-only earliest-first
  collision chains; a constructed same-bucket/non-equal-anchor oracle matches
  the quadratic reference. Fixed-core eight-pair level-9 JSON checks retained
  1058 bytes and reduced the median from 145.951 ms to 143.013 ms (1.021x).
  Huffman stream sizing now accumulates eight symbol widths per iteration when
  the group cannot cross a one- or four-stream boundary, exposing independent
  lookup/add chains while leaving short boundary tails on the scalar path. A
  scalar four-stream oracle covers irregular literal runs and a non-divisible
  regenerated length; fixed-core eight-pair checks retained 1058 bytes and
  reduced the median from 143.089 ms to 139.158 ms (1.028x). The helper now
  advances one maximal run bounded by the next Huffman stream edge, unrolling
  eight-byte groups and handling each boundary tail before recomputing its
  stream. This removes division and pointer write-back from the scalar tail
  loop; another fixed-core eight-pair run retained 1058 bytes and reduced the
  median from 139.424 ms to 123.109 ms (1.133x).
  Mixed lookahead now builds each large block's newest-eight hash predecessors
  once and reuses them across different `start_min` queries, instead of rebuilding
  the 1 MiB ring table at every uncached search position. Multi-offset random and
  heavily wrapped repeated-input oracles match the old rebuilt search exactly; a
  fixed-core eight-pair check retained 1058 bytes and reduced the median from
  122.779 ms to 119.927 ms (1.024x).
  The same reusable index now stores a compact full predecessor link for each
  position, letting the exact-cursor alternative visit only equal-hash history
  instead of rehashing every earlier byte. Its explicit longest/closest tie
  rule makes newest-first traversal equivalent; indexed-vs-scan oracles cover
  random long matches and buckets wrapped hundreds of times. Fixed-core
  eight-pair checks retained 1058 bytes and reduced the median from 119.842 ms
  to 118.753 ms (1.009x).
  Native match arbitration now owns one large-block predecessor index and shares
  it across mixed lookahead, multi-duplicate, and single-duplicate candidates.
  This removes two complete ring-table rebuilds after lookahead while preserving
  each candidate's original scan and tie order; focused lookahead, parallel-wire,
  and index oracles pass. Fixed-core eight-pair checks retained 1058 bytes and
  reduced the median from 118.418 ms to 114.985 ms (1.030x).
  The exact <=4 KiB matcher now uses the same 15-bit hash width as the bounded
  large matcher instead of truncating it to 12 bits. Since equal eight-byte
  anchors necessarily share all 15 bits, this only removes false collisions and
  leaves every real candidate and earliest-first tie intact. Existing scan and
  constructed-collision oracles pass; fixed-core eight-pair checks retained 1058
  bytes and reduced the median from 115.602 ms to 114.111 ms (1.013x).
  The exact matcher also stops reloading its already-compared eight-byte anchor
  when extending a surviving bucket candidate; the bounded large matcher keeps
  the validating entry point because its hash can collide. Existing scan,
  collision, and SIMD-boundary oracles preserve exact lengths and selection;
  fixed-core eight-pair checks retained 1058 bytes and reduced the median from
  113.817 ms to 111.870 ms (1.017x).
  Exact <=4 KiB matching now indexes full eight-byte anchors in an 8192-slot
  open-addressed table and links positions with compact `u16` indices. This
  shrinks head/tail metadata, removes false-collision anchor checks, and keeps
  every real match in earliest-first order. A constructed full-anchor collision
  oracle plus the exhaustive scan comparison preserve selection; fixed-core
  eight-pair checks retained 1058 bytes and reduced the median from 110.861 ms
  to 109.672 ms (1.011x).
  Duplicate match finders now return the exact single-sequence payload score
  they already computed while selecting their winner. Mixed-candidate material-
  ization reuses that score rather than rebuilding the literal histogram and
  Huffman plan for the same match. A focused oracle recomputes the score from
  the selected match; fixed-core eight-pair checks retained 1058 bytes and
  reduced the median from 109.760 ms to 107.025 ms (1.026x).
  Small-Huffman symbol ordering now passes the 256-entry code-length table to
  the sort comparator by const pointer instead of by value. The ordering remains
  exactly `(code length descending, symbol ascending)` under the compact/full
  length oracles; fixed-core eight-pair checks retained 1058 bytes and reduced
  the median from 107.982 ms to 107.126 ms (1.008x).
  Small-Huffman finalization no longer clears its dense bit-count and weight
  arrays a second time: every caller supplies a fresh zero-initialized plan, and
  finalization overwrites the complete active weight prefix while leaving absent
  symbols at zero. Existing compact/full length and dense-lookup oracles pass;
  fixed-core eight-pair checks retained 1058 bytes and reduced the median from
  106.613 ms to 106.166 ms (1.004x).
  A final fixed-CPU-8..10 six-pair comparison from the pre-Huffman-hotspot
  baseline (`36518f8`) through the completed batch measured 8.316 s versus
  107.454 ms, a 77.39x cumulative speedup while retaining the 1058-byte JSON
  level-9 frame. This remains far behind libzstd's roughly 0.14-0.19 ms result
  on the same harness, so the evidence is a milestone rather than parity.
  A dedicated ReleaseFast native encode stage benchmark is now available via
  `run-zstd-native-encode-stage-bench{-gate}`. It derives the primary/4 KiB/
  8 KiB candidate ladder from the production level policy, warms reusable
  scratch, reports median time across configurable rounds, and separates the
  shared large-block duplicate-index setup from mixed, greedy, lazy, optimal,
  repeated, multi-duplicate, and single-duplicate candidate emission. The first
  fixed-CPU-8..10 nine-round level-9 JSON baseline measured aggregate family
  times of about 20.35/0.12/8.58/2.44/0.13/7.16/0.47 ms for the primary block,
  59.31/0.30/0.38/2.57/0.60/13.27/1.86 ms across 4 KiB blocks, and
  26.41/0.21/0.31/2.54/0.83/3.28/0.33 ms across 8 KiB blocks, respectively.
  This localizes the next work to mixed search first and multi-duplicate second,
  rather than continuing low-signal whole-frame micro-tuning. The CSV coverage
  gate requires all 81 case/candidate/stage rows and pins the current level-9
  split policy so future reports cannot silently compare different pipelines.
  The stage tool additionally accepts `--candidate` and `--stage`, allowing perf
  and interleaved A/B runs to execute only one isolated row rather than spending
  most samples in unrelated families. An isolated 4 KiB mixed profile puts
  `findBestDuplicateMatchIn` at about 29.0% self time. Reusing the already loaded
  eight-byte anchor for its hash preserves the exact open-addressed lookup and
  avoids a redundant load; twelve fixed-CPU-8..10 interleaved pairs retained the
  9823-byte aggregate candidate output and moved the median from 60.394 ms to
  60.031 ms (1.006x). Two broader structural trials—borrowing the large duplicate
  index in the candidate cache and pruning generic FSE planning with a proven
  lower bound—were neutral or slower and were fully reverted.
  Predefined sequence plans no longer duplicate their caller-owned LL/OF/ML
  values into three fixed 128-`usize` arrays. They now retain only the selected
  FSE states, while scoring and emission explicitly borrow the original values;
  this shrinks every alternative and combined-plan copy without changing state
  selection or wire output. Fixed-CPU-8..10 interleaved stage checks improved
  primary/4 KiB/8 KiB JSON mixed medians by about 1.8%/8.0%/7.8%; the focused
  4 KiB twelve-pair run moved from 59.640 ms to 55.221 ms (1.080x), retaining
  the 9823-byte aggregate candidate output.
  The remaining predefined state paths are bounded to 64 states, so their plan
  arrays now use `u8` rather than `usize`. The independent usize-matrix oracle
  still proves every chosen state across LL/OF/ML. Eight fixed-CPU-8..10 pairs
  retained the same candidate bytes while improving primary/4 KiB/8 KiB JSON
  mixed medians by about 4.8%/4.4%/5.4%; a twelve-pair 4 KiB run measured
  55.255 ms to 53.080 ms (1.041x).
  Compressed-FSE transition planning now builds compact per-symbol state chains
  once and walks only states matching the current code, rather than rescanning
  all 32 table entries for every sequence. Reverse construction preserves the
  former lowest-state tie order, and a randomized scan-reference oracle matches
  initial states, baselines, state widths, transition values, and transition
  widths for plans of 12 through 128 sequences. Ten fixed-CPU-8..10 pairs kept
  all mixed candidate bytes while improving primary/4 KiB/8 KiB JSON medians
  by about 5.4%/5.3%/6.8%; the 4 KiB median moved from 55.287 ms to 52.514 ms.
  The earlier budget sweep also showed both level-9 adaptive split candidates
  had already reached their locked wire plateau at 96 mixed states. Adaptive
  4/8 KiB candidates now cap only their own search at 96 while the primary
  candidate retains the level's full 192-state fallback. The policy is shared by
  serial selection, parallel selection, and stage diagnostics, whose CSV now
  records and gates each candidate's effective budget. Ten fixed-CPU-8..10
  end-to-end pairs retained 93/1058/9009-byte text/JSON/binary frames; median
  text and JSON times improved from 77.619/99.391 ms to 66.943/84.028 ms
  (1.159x/1.183x), while binary remained within noise at 0.996x.
  A follow-up 64-state cutoff disables mixed recursion in only the adaptive
  candidates while retaining the 192-state primary safety net. The full nine-row
  encode gate still preserves every locked wire. Ten fixed-CPU-8..10 pairs
  against the 96-state version retain 93/1058/9009-byte text/JSON/binary frames
  and improve their level-9 medians from 66.839/83.803/26.387 ms to
  55.565/53.433/21.164 ms (1.203x/1.568x/1.247x). The stage CSV/gate now records
  the effective 192/64/64 budgets explicitly.
  Broader primary-candidate ablation found a generated 32 KiB repeated corpus
  where budgets below 96 expand the selected frame from 51 to 94 bytes, while
  96 and 128 preserve all 20 generated/source cases against 192. Levels 6+ now
  stop at that measured 96-state floor for their primary candidate as well. Ten
  fixed-CPU-8..10 pairs against the 192-state version retained 93/1058/9009-byte
  text/JSON/binary frames and improved medians from 56.485/49.946/21.154 ms to
  33.881/44.209/21.196 ms (1.643x/1.213x/1.001x).
  Multi-duplicate planning now returns its first global-best match to the final
  single-duplicate candidate, whose first lookup was identical. Reusing that
  match removes one full matcher/score pass per block whenever multi planning
  runs, while a focused oracle proves the direct and reused single-candidate
  wires are byte-identical. Ten fixed-CPU-8..10 end-to-end pairs retained the
  93/1058/9009-byte level-9 outputs; JSON improved from 44.241 to 42.474 ms
  (1.042x), binary from 21.141 to 19.964 ms (1.059x), and text regressed about
  1.1%, so the change is retained for its net structured/binary gain.
  Native stage diagnostics now expose the aggregate sequence count produced by
  greedy, lazy, and optimal hash parsers even when the 128-sequence encoder
  ceiling rejects their block. On the locked 32 KiB JSON input, primary optimal
  currently produces 471 matches while every 4/8 KiB block stays within the
  limit (476/473 total across all blocks). Primary greedy, lazy, and optimal all
  report 471 matches on this corpus. This explains why raising the fixed
  ceiling to 256 still did not admit the primary hash plan. The native sequence
  representation now has a separate 512-entry capacity while recursive mixed,
  multi-duplicate, and repeated planners retain their measured 128-entry bound.
  This admits the complete 471-match optimal block without expanding recursive
  search state: locked level-9 JSON improves from 1058 to 831 bytes (the
  libzstd 1.5.5 row is 677), and binary from 9009 to 8850 bytes (reference
  8609), while text remains 93 bytes. Ten fixed-CPU-8..10 pairs measured about
  2.6%/3.5% encode-time regressions for JSON/binary and 1.3% for text, accepted
  for the substantial ratio improvement. A focused round-trip test covers a
  real block whose optimal plan exceeds the 128-entry bootstrap capacity.
  Re-evaluating whole-frame selection after the 512-sequence change showed that
  adaptive splitting remains essential: across 73 generated/source prefixes,
  28 frames were smaller at 4/8 KiB, including source-sized reductions of tens
  of KiB when a primary block still exceeded the sequence ceiling. Removing the
  split ladder was therefore rejected. For level 6+ inputs above 24 KiB, the
  encoder now races the primary and 8 KiB candidates first and evaluates the
  costlier 4 KiB frame only when 8 KiB can tie or beat primary. The same corpus
  retained every serial three-candidate winner, while twelve fixed-CPU-8..10
  interleaved level-9 pairs retained 93/831/8850-byte text/JSON/binary frames
  and reduced median encode time by about 3.4%/1.3%/19.1%, respectively.
  The lazy LZ77 dispatch sketch now routes inputs with more than 64 distinct
  first-KiB trigram buckets to the hash-chain parser instead of waiting for 96.
  This catches the numbered-JSON shape (83 buckets) while keeping the repeated
  text benchmark (61) on its faster backward scan, and does not change either
  parser's match semantics. Twelve fixed-CPU-8..10 interleaved level-9 pairs
  retained 93/831/8850-byte outputs and reduced JSON median time by 23.4%; text
  and binary remained within about 0.7%/0.3% noise. An attempted lazy candidate
  depth reduction from eight to four produced no stable end-to-end gain and was
  reverted.
  The encode CSV gate no longer requires single-sample wall time to increase
  monotonically from level 1 through 9. Two-stage candidate scheduling can
  legitimately make level 9 faster than level 3, while shared-machine noise
  made the old ordering assertion flaky. Broad latency ceilings remain, and the
  dedicated 81-row stage gate continues to pin each level/candidate search
  budget directly.
  The optimal LZ77 dynamic program now indexes a compile-time 259-entry fixed
  match-length cost table instead of re-running the length-code branch ladder
  for every candidate length. An exhaustive scalar oracle covers every legal
  length. Twenty fixed-CPU-8..10 primary-optimal pairs retained the 824-byte
  JSON block and reduced the stage median by about 15.1%; twelve end-to-end
  pairs retained 93/831/8850-byte frames, improving text by 28.2% and JSON by
  1.1% while binary stayed within 0.3% noise.
  At budgets that enable ratio-oriented mixed lookahead, block arbitration now
  evaluates mixed on a worker while the caller handles greedy/lazy/optimal,
  repeated, and duplicate families. The worker uses Zig's thread-safe SMP
  allocator for its isolated temporary block, so advanced callers can still
  supply a single-threaded allocator; it owns an independent duplicate index
  and falls back to the unchanged serial selector if thread
  creation fails; mixed retains its historical equal-length tie priority. A
  direct serial-wire oracle covers both repetitive shapes. Twelve fixed-CPU-
  8..10 level-9 pairs retained 93/831/8850-byte frames and improved text/JSON
  medians by about 14.8%/12.1%, with binary improving 1.7%.
  FSE count normalization now follows upstream zstd's low-probability handling,
  fixed-point rounding thresholds, largest-symbol correction, and secondary
  fallback instead of assigning every present symbol a floored positive count.
  Randomized table-log-5...8 distributions verify exact probability mass, and
  a focused non-uniform distribution proves the new result differs from the old
  approximation. The improved level-9 sequence tables reduce JSON from 831 to
  821 bytes and binary from 8850 to 8846 bytes while text remains 93 bytes.
  Twelve fixed-CPU-8..10 pairs kept text/binary within 0.5% and measured JSON
  about 1.2% slower, accepted for the deterministic ratio improvement.
  Sequence streams with at least 256 symbols now use one upstream-style
  source-size-selected 128-state FSE table instead of always forcing 32 states.
  This avoids the much slower four-table-log exhaustive experiment while still
  reducing the locked JSON frame from 821 to 816 bytes; binary stays at 8846
  and text at 93. Twelve fixed-CPU-8..10 pairs against the 64-state version
  measured only 0.5–0.6% differences across all three cases. A focused oracle
  pins the large-plan tableLog and the compact u8 state bound; 256 states were
  rejected because one measured distribution could not construct a valid state
  chain with the current compact planner.
  Native encode stage diagnostics now split each available candidate's encoded
  bytes into block header, literals section, and sequence section. The 81-row
  CSV gate enforces exact accounting for every case/candidate/family. On the
  current level-9 primary JSON optimal block this records 809 bytes as a 3-byte
  block header, 318 literal bytes, and 488 sequence bytes, making the remaining
  libzstd ratio gap directly attributable and regression-testable.
  Level 9+ now adds a two-state recent-offset beam parser over the best hash
  match at each position. It keeps a backpointer/token per state, charges repeat-distance
  matches cheaply, and leaves levels 1–8 plus advanced callers on the prior
  parser set. The locked JSON frame falls from 816 to 678 bytes (libzstd 677),
  and binary from 8846 to 8611 (libzstd 8609), while text remains 93 bytes. A
  wider eight-state/eight-match beam can reach 677 bytes but costs materially
  more; a broader two-state/four-match search did not improve JSON and emitted
  binary at 8619 bytes. The retained single-match shape is the measured speed/
  ratio compromise. The
  beam hot path bypasses the generic accept-match calculation after its indexed
  candidates have already satisfied the minimum/window invariants and reads the
  precomputed length-cost table directly, reducing focused JSON/binary stage
  medians from roughly 2.46/2.55 ms to 2.26/2.28 ms without wire changes.
  Beam storage now keeps one byte of valid-slot counts per source position
  instead of clearing every full state object before parsing. Focused JSON and
  binary medians move further to about 2.22/2.26 ms with identical output.
  Beam path costs are bounded well below 32 bits for the supported <=64 KiB
  block, so storing them as `u32` shrinks each state and improves the focused
  JSON/binary medians again to about 2.12/2.20 ms without changing tokens.
  The fixed two-slot beam insertion is specialized to direct duplicate/update/
  replacement comparisons instead of a generic loop; focused medians reach
  about 2.09/2.17 ms for JSON/binary with identical 671/8612-byte blocks.
  The parser's 64 KiB input cap proves every accumulated fixed-bit path cost is
  below `u32`, so hot literal/match transitions now use direct additions rather
  than checked generic arithmetic. Twenty fixed-CPU-8..10 stage pairs preserve
  671/8604-byte JSON/binary blocks and improve medians by about 3.2%/1.8%.
  The beam's complete-position match index now uses a 4096-entry hash head,
  matching the established tiny parsers instead of reserving 32768 buckets.
  Sixteen fixed-CPU-8..10 stage pairs preserve the same block bytes and improve
  JSON/binary medians by about 19.1%/10.6%.
  Reducing the per-position hash alternatives from four to one preserves the
  678-byte JSON frame, improves binary from 8619 to 8611 bytes, and cuts the
  focused JSON beam stage to about 1.28 ms. Twelve fixed-CPU-8..10 end-to-end
  pairs against the four-match beam improved JSON/binary medians by roughly
  1.6%/1.2%, with text unchanged.
  The end-to-end encode gate now locks the achieved level-9 ratio floors at
  678 bytes for numbered JSON and 8611 bytes for mixed binary, replacing the
  obsolete pre-beam 1058/9009-byte ceilings. Levels 1 and 3 retain their
  independent latency-oriented bounds.
  Match arbitration now evaluates the beam before the ordinary optimal parser
  and skips that redundant DP when the beam block is at most 1/32 of source
  size. An explicit structured oracle proves the beam beats the ordinary
  families at this threshold, while the expanded generated/source corpus stays
  byte-identical. Twelve fixed-CPU-8..10 pairs improve level-9 text/JSON by
  about 21.2%/9.6%, with binary within 0.8% noise.
  Decisive beam blocks now run only the first global duplicate query needed by
  the single-duplicate fallback and skip multi-duplicate's iterative follow-up
  searches. This preserves the 93-byte repetitive-text winner without paying
  for a complete multi plan after the beam has already compressed the source
  below 1/32. A focused indexed-path oracle proves that this direct query equals
  multi's first match and emits the same single-candidate wire. The 76-case
  generated/source comparison remained byte-identical; twelve fixed-CPU-8..10
  pairs retained the 93/678/8611-byte text/JSON/binary frames and reduced their
  medians by about 3.4%/5.8%/1.5%, respectively.
  Profile-guided mixed-planner work now builds candidate literal histograms in
  four independent frequency lanes, then merges the 256 counters before the
  unchanged Huffman construction. This removes the loop-carried dependency on
  frequent JSON symbols while preserving the exact scalar plan. The shared
  large-block duplicate index also links positions with non-empty predecessor
  buckets, allowing each suffix query to skip positions that cannot contain a
  match; Huffman stream sizing uses an unchecked internal accumulator only after
  its freshly built histogram has proved that every referenced symbol is
  present. Focused oracles cover the striped histogram, duplicate-index suffix
  search, and Huffman stream boundaries. Two twelve-pair fixed-CPU-8 stage runs
  retained candidate bytes and improved mixed JSON by about 13–14%, repetitive
  text by about 5–6%, and binary by about 11%; twelve fixed-CPU-8..10 end-to-end
  pairs retained 93/678/8611-byte frames and improved JSON/binary medians by
  about 13.9%/3.6%, with text improving about 1.2%.
  Indexed cursor-match search now stops at the first match that reaches the end
  of the block. The hash chain is newest-first, so this match has both the
  maximum possible length and the smallest offset among every remaining
  equal-length candidate. A focused scan-reference oracle pins that tie rule,
  and the 76-case generated/source comparison remains byte-identical. Twelve
  fixed-CPU-8 stage pairs retain candidate bytes while reducing repetitive-text
  mixed time by about 56.6%; two end-to-end runs improve the 93-byte level-9
  text case by about 39–45%, while JSON and binary remain within roughly 1%.
  The decisive-beam test now also accepts a relative margin: when the emitted
  beam block is at least 1/32 smaller than every preceding linear candidate,
  arbitration skips the ordinary optimal DP even if the compressed block is
  not itself below 1/32 of the source. A focused mixed-binary oracle pins both
  the new threshold and the beam win, while the 76-case generated/source corpus
  remains byte-identical. Twelve fixed-CPU-8..10 end-to-end pairs keep the
  81/644/8611-byte text/JSON/binary frames and improve binary by about 10.2%; a
  24-pair binary rerun measures about 10.6%, with text/JSON within about 3%.
  Level-9 block selection now probes the first 1 KiB for a prefix duplicate
  that reaches the block end before launching the full candidate race. When its
  normal single-match encoding is already at most 1/32 of the source, the same
  decisive threshold returns it immediately instead of running beam, optimal,
  mixed, repeated, and duplicate searches. A focused oracle compares the fast
  path with full serial arbitration. The 76-case generated/source comparison
  has no regressions and shrinks four strongly periodic cases by four bytes; a
  24-pair fixed-CPU-8..10 run retains the 81-byte text frame and improves its
  median by about 5.2%, with JSON unchanged within 0.1%.
  The large-block duplicate index now also records the whole block's high-byte
  count and maximum byte frequency. If a single match cannot remove every byte
  above the native direct-Huffman alphabet and no symbol can fill the retained
  literal stream, its literal section is provably raw; indexed scoring skips
  both Huffman passes in that case. A focused non-zero-suffix oracle compares
  the shortcut with the complete scorer, and the 76-case generated/source set
  remains byte-identical. Twelve fixed-CPU-8 stage pairs reduce binary mixed
  time by about 24.8%; two end-to-end binary runs retain the 8611-byte frame and
  improve medians by about 3.8–10.1%, while text/JSON remain scheduler-noisy.
  Repeated-pattern discovery now checks the three-byte minimum-match anchor
  before entering its dependent extension loop for each candidate period. This
  is an exact rejection because every emitted Zstd match requires at least three
  bytes. A randomized scan-reference oracle covers multiple suffix starts, and
  the 76-case generated/source comparison stays byte-identical. Twelve
  fixed-CPU-8 stage pairs reduce JSON repeated/mixed measurement by about 5.9%;
  a 24-pair end-to-end JSON rerun retains 678 bytes and improves the median by
  about 0.7%, with the smaller cases within measurement noise.
  Huffman tree emission now compares the legacy direct-weight header with the
  existing FSE-compressed weight writer even when the alphabet fits the direct
  format, retaining the shorter valid representation. A focused low-byte
  alphabet oracle proves FSE wins and is selected; the expanded 76-case corpus
  improves 40 frames with no regressions, including source prefixes by up to
  631 bytes. Level-9 repetitive text drops from 93 to 81 bytes (libzstd 80),
  numbered JSON from 678 to 644 bytes (libzstd 677), and binary remains 8611
  bytes (libzstd 8609). Twenty-four fixed-CPU-8..10 A/B pairs improve text/JSON
  medians by about 9.1%/2.4% while preserving external decoder compatibility.
  Finalized literal Huffman plans now cache each symbol's canonical code beside
  its already-dense bit count. Emission copies those tables directly instead of
  rebuilding every code through repeated sorted-symbol scans for each candidate
  block. A focused oracle compares every cached code with the prior derivation,
  and the 76-case generated/source corpus remains byte-identical. Two fixed-CPU
  end-to-end binary runs retain 8611 bytes and improve medians by about 22%,
  while text/JSON remain within roughly 2% noise.
  The repeat-aware beam's configurable cost model now charges four extra proxy
  bits when introducing a new distance, while generic LZ77 callers retain a
  zero default. Sequence comparison against libzstd exposed a late switch from
  the dominant distance 256 to distance 7424 for only two extra matched bytes;
  preserving the repeat run reduces the locked binary frame from 8611 to 8607
  bytes (two bytes below libzstd 1.5.5) and JSON from 644 to 641 bytes. A focused
  token oracle pins all 508 binary matches to distance 256. Across the original
  76 cases and a new 128-case generated corpus, no frame grows; the latter has
  five improved cases totaling 147 bytes. Strict same-source A/B keeps stage
  and end-to-end throughput within about 1%, while longer noisy runs show no
  systematic regression.
  Huffman weight compression now evaluates both tableLog 5 and 6 and retains
  the shorter serialized FSE stream, rather than forcing one global table size.
  A focused low-byte tree oracle proves tableLog 5 wins and is selected for the
  repetitive text alphabet. The original 76-case corpus improves 39 frames by
  308 bytes total with no regressions; the broader 128-case generated corpus
  exposed three one-byte losses from globally forcing tableLog 5, which the
  per-tree arbitration avoids. Level-9 text now matches libzstd at 80 bytes,
  JSON improves from 641 to 640 bytes, and binary remains 8607 bytes.
  Before spawning adaptive frame candidates, level 9 now probes the same bounded
  prefix-tail shape as block arbitration. If the complete single-block frame is
  below 1/256 of the source, it returns immediately instead of waiting for split
  encoders whose additional block headers cannot be competitive on the measured
  shape. A focused primary-wire oracle covers the cutoff. The 76-case corpus has
  no regressions and 13 improvements, while the independent 128-case generated
  corpus is byte-identical. Twelve fixed-CPU-8..10 pairs retain 80-byte text and
  reduce its level-9 median from about 7.54 ms to 0.56 ms (13.4x); JSON/binary
  remain within 1%.
  Exact-cache profiling of the remaining level-9 JSON mixed search found 95
  scored prefixes at depths 2...96, with 95 distinct full score keys, literal
  histograms, and LL/OF/ML vectors, so no speculative memoization was retained.
  Instead, large level-9 primary frames now join the existing adaptive worker
  set rather than running on the coordinator while split candidates occupy the
  worker pool. Deterministic shortest-frame arbitration and the low-level
  scheduling path stay unchanged. Twelve interleaved fixed-CPU-8..10 JSON pairs
  retained the 640-byte frame and reduced the median from about 53.78 ms to
  39.37 ms (1.37x); an additional eight-pair run measured 1.44x, while binary
  remained at 8607 bytes and showed about 1.06x in the corresponding sample.
  Mixed Huffman sizing now caches cumulative physical-input bit costs keyed by
  the exact 256-entry code-width table. Adjacent JSON prefixes changed their
  literal histogram every time but reused the same code widths on 86 of 95
  scoring calls; those calls now price each retained literal run with two
  prefix lookups while preserving the four logical stream boundaries. A
  focused scalar oracle covers offset slices, every mismatch boundary, and the
  cache reuse path. Twelve fixed-CPU-8 pairs retained the 14619-byte stage
  candidate and improved its median by about 4.3%; both 76- and 128-case frame
  probes remained byte-identical, including the locked 80/640/8607-byte frames.
  Adaptive 4/8 KiB candidates explicitly disable the beam: their lower-budget
  parsers remain the ratio fallback, while only the primary level-9 block pays
  the stateful search. Twelve fixed-CPU-8..10 end-to-end pairs versus the
  pre-beam encoder retained the improved 678/8619-byte JSON/binary wires; text
  and JSON timing stayed within 0.2%, while binary paid about 8.0% for its
  227-byte ratio gain.
  Large-block predecessor snapshots now carry a lazy `u16` match-length cache.
  The first mixed lookup still performs the exact existing extension and tie
  logic, while later mixed branches plus multi/single duplicate passes reuse the
  result for the same `(second, predecessor-age)` pair. The cache adds 1 MiB to
  the temporary index but needs no full clear: build marks only populated slots
  with the reserved `0xffff` sentinel. Ten fixed-CPU-8..10 stage pairs retained
  primary JSON candidate bytes while improving mixed from 19.033 to 17.497 ms
  (1.083x) and multi-duplicate from 6.983 to 5.492 ms (1.271x); index setup rose
  from 0.113 to 0.151 ms. Twelve end-to-end pairs kept the 1058-byte frame and
  moved the median from 53.596 to 49.964 ms (1.073x).
  Sequence-literal RLE detection now skips empty/already-disproved runs and uses
  the standard library's vectorized `allEqual` scan for each remaining run
  instead of branching once per byte. A focused reference oracle covers empty,
  single-byte, equal, mismatching, and cross-run cases; fixed-core eight-pair
  checks retained 1058 bytes and reduced the median from 111.996 ms to
  110.518 ms (1.013x).
  Top-level per-block arbitration now also reuses one candidate scratch and one
  retained winner across dictionary, frame-history, Huffman, and native-match
  blocks. The historical Huffman-wins-equal tie and transactional tree-state
  commit are preserved; focused shortest-match plus multi-block treeless reuse
  tests pass. Repeat-3 JSON level 3 remained 1350 bytes around 0.87 s.

- Added `summary-lz4-native-file`, a CLI surface for the existing native LZ4
  stream summary API, and extended the LZ4 native probe to assert block/stream
  summary consistency for generated native frames. The black-box
  `run-lz4-native-summary-cli-probe` smoke now checks the user-facing summary
  text/JSON fields for single-frame and concatenated/skippable streams, including
  the frame-level checksum/content-size/Dictionary_ID metadata counters and
  malformed/truncated failure paths. The LZ4 library now exposes
  `lz4SummarizeNativeStreamWithDiagnostics` so CLI JSON errors use parser
  phase/offset diagnostics reported by the summary API rather than CLI-only
  inference; the phase value is backed by a public enum, and checksum-truncation
  offsets are reported at the exact failing byte. The retained
  `run-lz4-native-summary-dashboard` step writes
  `zig-out/vort-lz4-native-stream-summary.json` for dashboard indexing. A shared
  `run-native-summary-error-dashboard` artifact now retains representative
  structured LZ4/Zstd summary error JSON plus error/phase counts, and
  `run-native-summary-error-negative-smoke` verifies those aggregate counts fail
  on drift.

- Added LZ4 raw-block summary helpers and CLI commands, including prefix-history
  variants. The summary validates block token structure while reporting decoded
  bytes, literal token/byte counts, and match token/byte counts.

- Added explicit gzip concatenated decode CLI aliases (`decode-gzip-concat-hex`
  and `decode-gzip-concat-file`) and extended the gzip CLI differential smoke to
  cover both aliases. The existing `decode-gzip-*` commands remain compatible
  and continue to decode concatenated members.

- Added raw/gzip file-to-hex best encoder CLI commands (`encode-raw-best-file-hex`
  and `encode-gzip-best-file-hex`) to match the existing zlib file-hex helper,
  and extended the Python zlib differential smoke to decode all three file-hex
  outputs with Python's raw/zlib/gzip modes. The retained smoke/dashboard
  schema now records `file_hex_encode_cases`, so raw/zlib/gzip file-to-hex
  coverage is a first-class health gate instead of an unreported assertion.

- Bounded native LZ4/Zstd codec probe runtime for Debug dashboard/CI smoke.
  Zstd frame lib-generated coverage now uses the raw/RLE compatibility writer
  for the generated decode/API matrix, while hand-authored frame fixtures retain
  compressed-block, Huffman, sequence-table, and repeat-mode coverage. The Zstd
  dictionary probe now keeps the expensive dictionary Huffman/sequence-table
  writer shapes as fixed fixtures, so the probe still validates dictionary
  requirement, compressed literals, FSE-Huffman weights, sequence-table inspect,
  and decode behavior without repeating bootstrap match-planning work on every
  smoke run. The native codec probe dashboard now also enforces a per-probe
  timeout and records `timed_out`/`timeout_seconds` in retained JSON/Markdown,
  so future probe-runtime regressions fail with a specific artifact instead of
  hanging CI indefinitely. Dashboard validation now also exposes a top-level
  timed-out-probe count and requires Zstd frame/dictionary probe case counts, so
  broad capability totals cannot hide timeout regressions or accidental loss of
  the public Zstd sequence-table/repeat-offset fixtures.

- Extended the public Zstd native frame probe with a concatenated stream that
  places two skippable metadata frames between two data frames. The fixture
  validates stream summary counts, iterator order, concatenated size preflight,
  allocator exact-size decode, caller-buffer decode, and output-limit errors so
  multiple adjacent skippables remain covered through library APIs rather than
  only via single-skippable smoke.

- Added `summary-zstd-native-file` to the CLI smoke surface. It prints the
  existing library-level Zstd native stream summary fields (data frames,
  skippable frames, checksum-bearing frames, Dictionary_ID-bearing frames,
  content-size-bearing frames, declared content bytes, block type counts,
  compressed payload bytes, and skippable payload bytes), matching
  the LZ4 native summary command and making concatenated/skippable Zstd stream
  layout visible without decoding. The
  command supports text and `vort.zstd_native_stream_summary` JSON output. The
  new `run-zstd-native-summary-cli-probe` black-box smoke encodes single-frame
  and concatenated/skippable streams through the CLI, checks both text and JSON
  summary fields, verifies malformed/truncated failure paths, and uses
  `zstdSummarizeNativeStreamWithDiagnostics` for parser phase/offset context in
  JSON errors, with phase values backed by a public enum and checksum-truncation
  offsets reported at the exact failing byte. It runs in `ci-smoke`. The retained
  `run-zstd-native-summary-dashboard` step now writes
  `zig-out/vort-zstd-native-stream-summary.json` and is indexed by the dashboard
  producer/category manifests. Dashboard strict validation now treats missing or
  undercovered Zstd native stream summary artifacts as aggregate validation
  health failures with dedicated negative fixtures.

- Extended the public Zstd native frame probe with valid non-single-segment
  frames that exercise the two-, four-, and eight-byte content-size field
  encodings with RLE blocks. This keeps the non-single-segment
  `Frame_Content_Size` header paths covered through public inspect, size,
  summary, and decode APIs rather than only through single-segment content-size
  fixtures.

- Tightened Zstd native encoded-frame bound helpers to mirror the writer's
  shortest single-segment `Frame_Content_Size` width instead of reserving an
  eight-byte content-size field for every size-bearing frame. Caller-owned
  encode buffers now get exact bounds for raw/RLE small and medium frames, while
  dictionary IDs, no-content-size window descriptors, checksums, and large
  widths remain covered by the same helper.

- Promoted the tightened Zstd native encoded-bound behavior into the public
  frame probe. The probe now checks exact raw/RLE caller-owned encode bounds for
  one-, two-, and four-byte single-segment content-size fields, no-content-size
  window descriptors, and Dictionary_ID header bytes so dashboard counts catch
  future bound/writer drift.

- Added public single-segment Zstd frame fixtures for two-, four-, and eight-byte
  `Frame_Content_Size` fields with RLE blocks. These pin the larger
  single-segment content-size header widths through inspect, block summary,
  decoded-size, limit, and caller-owned decode APIs without requiring huge
  output allocations.

- Added public Zstd frame fixtures for one-, two-, and four-byte `Dictionary_ID`
  fields. Each fixture verifies inspect offsets, missing-dictionary diagnostics,
  dictionary-aware size preflight, output limits, and caller-owned decode so
  header field-width regressions are visible without relying only on internal
  unit tests.

- Added public Zstd frame fixtures for explicitly present but zero-valued one-,
  two-, and four-byte `Dictionary_ID` fields. The probe verifies that header
  inspection preserves the payload offset while size preflight and caller-owned
  decode treat ID zero as dictionary-free instead of returning `NeedDictionary`.

- Added a no-content-size Zstd frame fixture with a non-default 1536-byte
  `Window_Descriptor` and an RLE block. This covers window decoding beyond the
  1 KiB descriptor through header inspect, bounded decoded-size preflight, and
  caller-owned decode without adding a large fixture payload.

- Added a malformed no-content-size Zstd frame fixture that ends before the
  required `Window_Descriptor` byte. The public header, size, decode, summary,
  and stream-iterator APIs now agree on `TruncatedFrame` for this header-length
  boundary.

- Promoted Zstd frame descriptor bit 4 acceptance into the public frame probe.
  The fixture keeps the true reserved bit 3 rejection separate while proving
  that the unused neighboring bit can still decode through inspect, size, and
  caller-owned output APIs like reference decoders.

- Added a handcrafted Zstd checksum-success fixture beside the existing mismatch
  and truncated-checksum cases. The public frame probe now exercises checksum
  presence, decoded-size preflight, allocator decode, and caller-owned decode
  for a valid raw/RLE frame without depending on the generated encoder path.

- Added a no-content-size multi-block Zstd checksum-success fixture beside the
  existing mismatch and truncated-checksum variants. This pins successful
  checksum validation for frames whose decoded length must be discovered from
  blocks rather than the frame header.

- Promoted the extended two-byte zero `Sequence_Count` compressed-block form into
  the public Zstd frame probe. The fixture validates block-mode inspection,
  decoded-size preflight, and caller-owned decode for a legal sequence-free
  compressed block whose count is not encoded in the single-byte short form.

- Extended LZ4 native stream summaries with frame-level metadata counts for
  content-size fields, content checksums, block checksums, Dictionary_ID fields,
  and the total declared content bytes. The LZ4 native probe now checks those
  fields for ordinary data frames, skippable-only streams, and checksum-mismatch
  streams so summary drift is visible through public APIs.

- Extended the dependency-free Brotli stored-stream slice to all RFC 7932 stream
  window-bit encodings (`WBITS=10...24`). The default remains `WBITS=16`, but
  root and CLI encode paths can now select a legal stored-stream window size,
  and the Node-backed `run-br-stored-cli-diff` smoke covers representative
  `10/16/24` encodings for empty, text, repeated, and binary payloads.

- Added Brotli metadata meta-block handling to the stored-stream slice. Encoders
  can attach metadata bytes that do not contribute to decoded output, while the
  decoder and size preflight now skip legal `MNIBBLES=0` metadata blocks and
  reject malformed reserved bits, truncated metadata, and non-minimal skip
  lengths. The Node-backed stored-stream smoke covers metadata-bearing streams.

- Added `run-br-stored-corpus`, a pure Zig Brotli stored-stream corpus smoke
  that covers round-trip, decoded-size preflight, caller-owned decode,
  append decode, output limits, WBITS variants, metadata-bearing streams, and
  representative corrupt/truncated/trailing cases. This complements the
  Node-backed differential smoke with library-level API coverage.

- Added the first Brotli compressed-block prerequisite: prefix-code parsing
  backed by the shared canonical Huffman table. The implementation reads RFC
  7932 simple prefix codes for one to four symbols, rejects duplicate or
  out-of-range symbols, and now supports complex prefix-code headers with the
  code-length alphabet plus repeat-16/repeat-17 expansion, including chained
  repeat-count modification for consecutive repeat symbols.

- Added the Brotli block-type-count variable-length reader used by `NBLTYPESL`,
  `NBLTYPESI`, and `NBLTYPESD` in compressed meta-block headers. Boundary tests
  cover the full RFC range from 1 to 256 and truncated selector handling.

- Added a minimal Brotli compressed meta-block header parser for the single block
  type / single tree shape. It reads `NBLTYPESL/I/D`, `NPOSTFIX`, `NDIRECT`,
  literal context mode, `NTREESL/D`, and the literal/insert-copy/distance prefix
  trees, while explicitly rejecting context-map and multi-block-type shapes until
  those parser branches are implemented.

- Added Brotli insert-and-copy length decoding for symbols `0...703`, including
  insert/copy extra-bit reads, high-range length families, and the implicit
  distance-zero marker for symbols below 128. This is the next command-stream
  primitive needed before literal-only compressed meta-block decoding.

- Added the first Brotli compressed data decode slice: a final single-tree
  literal-only meta-block whose command inserts exactly `MLEN` bytes, allowing
  the copy length to be ignored per RFC 7932. This validates the interaction
  between the minimal compressed header parser, insert-and-copy lengths, and
  literal prefix-code decoding without claiming full copy/distance support.

- Extended the minimal Brotli literal-only compressed decode path to non-final
  meta-blocks, so a supported compressed literal-only block can now be followed
  by stored/meta/final-empty blocks in the same stream.

- Added `run-br-literal-cli-diff`, a Node-backed black-box smoke for the minimal
  Brotli literal-only compressed path. The gate generates final and non-final
  literal-only compressed streams, decodes them through the Vort CLI and Node's
  Brotli decoder, and checks output-limit failures so the new compressed wire
  shape is validated outside the internal unit tests.

- Extended the minimal Brotli compressed decode path with direct-distance copy
  support. The first copy slice handles explicit direct distance symbols such as
  distance 1, performs overlapping output-buffer copies, and is covered by both
  a synthetic unit test and the Node-backed literal CLI differential smoke.

- Extended the minimal Brotli compressed decode path with last-distance reuse.
  Decode and decoded-size preflight now maintain the Brotli last-distance ring
  for explicit direct distances, and implicit distance-zero commands can reuse
  the most recent distance. The Node-backed literal CLI differential smoke now
  covers this shape without relying on system codec libraries for Vort support.

- Extended the minimal Brotli compressed decode path with RFC 7932 distance
  short-code support for symbols `1...15`. The decoder now keeps the recent
  distance ring at stream scope across compressed meta-blocks, resolves last /
  second-last distance deltas with invalid zero/negative rejection, and covers
  the new short-distance copy shape in both Zig tests and the Node-backed CLI
  differential smoke.

- Extended the minimal Brotli compressed decode path with regular distance
  symbols (`16 + NDIRECT` and above). The decoder now reads distance extra bits,
  applies the RFC 7932 `NPOSTFIX` / `NDIRECT` formula, updates the recent-distance
  ring for regular matches, and covers a postfix-bearing regular-distance frame
  in both Zig tests and the Node-backed CLI differential smoke.

- Extended the minimal Brotli compressed header parser with trivial context-map
  support. Literal and distance tree groups may now declare multiple trees when
  the encoded context maps resolve entirely to tree 0; the parser consumes the
  unused prefix trees while the current decoder continues using the first tree.
  Zig tests and the Node-backed CLI differential smoke cover an RLE-all-zero
  context-map frame.

- Extended the minimal Brotli compressed decode path with non-trivial distance
  context-map selection for the single distance block type shape. The decoder
  now preserves the four distance context-map entries, supports up to two
  distance prefix trees in the current minimal header shape, selects the distance
  tree from copy-length context IDs, and covers the context-1/tree-1 path in both
  Zig tests and the Node-backed CLI differential smoke.

- Extended the minimal Brotli compressed decode path with non-trivial literal
  context-map selection for the single literal block type shape. The decoder now
  preserves 64 literal context-map entries, supports up to two literal prefix
  trees, computes LSB6/MSB6 context IDs from recent output bytes, and covers a
  context-selected literal tree in both Zig tests and the Node-backed CLI
  differential smoke.

- Extended the minimal Brotli compressed decode path with insert-and-copy block
  switching for the two-command-block-type shape. The header parser now reads the
  command block type/count trees and the initial command block count, while the
  command stream switches command prefix trees when the current count reaches
  zero. Zig tests and the Node-backed CLI differential smoke cover the switch.

- Extended the minimal Brotli compressed decode path with literal block
  switching for the two-literal-block-type shape. The parser now reads the
  literal block type/count trees and initial block count, preserves per-block
  literal context modes and context-map slices, and switches literal prefix tree
  selection when the literal block count reaches zero. Zig tests and the
  Node-backed CLI differential smoke cover the switch.

- Extended the minimal Brotli compressed decode path with insert-and-copy block
  switching for the two-command-block-type shape. The parser now reads the
  command block type/count prefix trees and initial block count, the decoder
  switches command trees when the block count reaches zero, and the behavior is
  covered by both Zig tests and the Node-backed CLI differential smoke.

- Extended the minimal Brotli compressed decode path with distance block
  switching for the two-distance-block-type shape. The parser now reads distance
  block type/count prefix trees and initial block count, preserves per-distance
  block context-map slices, and switches distance prefix tree selection only
  when an explicit distance symbol is decoded. Zig tests and the Node-backed CLI
  differential smoke cover a frame whose second copy requires the switched
  distance tree.

- Extended the Brotli context-map reader with inverse move-to-front (`IMTF`)
  decoding. The same pure Zig parser now handles non-trivial IMTF maps instead
  of rejecting them, and a compressed literal-context frame proves the restored
  tree index is used by both decoded-size preflight and output decode. The
  Node-backed Brotli CLI differential smoke covers the same wire frame.

- Expanded the minimal Brotli compressed header to keep up to four literal and
  distance context trees instead of rejecting tree groups above two. A compressed
  literal-context frame now selects the third literal tree through a non-trivial
  context map, and the Node-backed CLI differential smoke validates the same
  wire frame.

- Expanded the minimal Brotli compressed header to keep up to four literal,
  command, and distance block types instead of rejecting block-type groups above
  two. A compressed literal-block-switch frame now walks through three literal
  block types and selects the third block's literal tree, with the same frame
  covered by the Node-backed CLI differential smoke.

- Added three-block-type coverage for Brotli command and distance block
  switching. The compressed command-switch smoke now walks command block types
  0/1/2 and the distance-switch smoke walks distance block types 0/1/2 with
  distinct distance trees, proving the widened block-type capacity is exercised
  beyond literal blocks. Both frames are covered by Zig tests and the Node-backed
  CLI differential smoke.

- Added Brotli Signed literal context mode support. Literal context selection now
  uses the RFC `Lut2` bucket formula for mode 3 in both decoded-size preflight
  and output decode, while UTF8 mode remains explicitly unsupported. A compressed
  literal-context frame exercises signed context ID 8 and is covered by Zig tests
  plus the Node-backed CLI differential smoke.

- Added Brotli UTF8 literal context mode support. Literal context selection now
  implements the RFC `Lut0[p1] | Lut1[p2]` behavior for mode 2 in both
  decoded-size preflight and output decode. A compressed literal-context frame
  exercises UTF8 context ID 56 and is covered by Zig tests plus the Node-backed
  CLI differential smoke.

- Improved Brotli decoded-size preflight literal history simulation. The
  preflight path now keeps a small recent-byte tail so short backward copies with
  distances beyond two can still feed later literal context selection instead of
  forcing `UnsupportedBrotliFeature`. A compressed UTF8-context frame copies with
  distance three and then decodes another context-selected literal, covered by
  Zig tests and the Node-backed CLI differential smoke.

- Raised the minimal Brotli literal and distance context-tree retention limit to
  eight. A compressed UTF8 literal-context frame now declares five literal trees
  and selects the fifth tree through context ID 56, with matching Zig and
  Node-backed CLI differential coverage.

- Raised the minimal Brotli literal, command, and distance block-type retention
  limit to eight. A compressed command-block-switch frame now declares five
  command block types and walks through the fifth type, with matching Zig and
  Node-backed CLI differential coverage.

- Raised the minimal Brotli command block-type / insert-copy-tree retention
  limit to 32. A compressed command-switch frame now declares 17 command block
  types, walks through tree index 16, and verifies decoded-size and output
  decode agree on the widened table.

- Added five-block-type coverage for Brotli literal and distance block
  switching. The compressed literal-switch smoke walks to the fifth literal block
  type, while the distance-switch smoke walks to the fifth distance block type
  and selects its distance tree. Both frames are covered by Zig tests and the
  Node-backed CLI differential smoke.

- Raised the minimal Brotli distance block-type retention limit to 32. A
  compressed distance-block-switch frame now declares 17 distance block types,
  walks through block type 16, and selects the corresponding distance tree and
  context-map slice through decoded-size and output decode.

- Raised the minimal Brotli literal block-type retention limit to 32. A
  compressed literal-block-switch frame now declares 17 literal block types,
  walks through block type 16, and selects the corresponding literal tree and
  context-map slice through decoded-size and output decode.

- Added fifth-distance-context-tree coverage for Brotli compressed decode. The
  distance context map can now be proven to select tree index four for copy-length
  context one (`copy_len = 3`), with both Zig tests and the Node-backed CLI
  differential smoke decoding the same frame.

- Raised the minimal Brotli distance context-tree retention limit to 32. A
  compressed copy frame now declares 17 distance trees and selects tree index 16
  for the copy-length-three distance context, matching the recent literal-tree
  capacity increase for broader compressed-block compatibility.

- Raised the minimal Brotli literal context-tree retention limit to 32. A
  compressed UTF8 literal-context frame now declares 17 literal trees and selects
  tree index 16 through context ID 56, extending coverage beyond the previous
  16-tree ceiling while keeping the bounded table representation explicit.

- Expanded Brotli decoded-size preflight's recent literal history window to 64
  bytes. A compressed context-selected literal frame now copies with distance 33
  and then decodes another literal using the copied history, keeping preflight in
  sync with output decode for a wider short-copy class.

- Preserved Brotli decoded-size preflight literal history across uncompressed
  meta-blocks. The preflight path now feeds skipped stored payload bytes into the
  recent literal history, so a following compressed meta-block can use stored
  bytes for context-selected literal decoding. A stored-then-compressed
  differential frame covers the behavior.

- Added compressed-frame coverage for Brotli complex literal prefix codes. A
  literal-only frame now uses a complex prefix-code header for its literal tree
  and is decoded by both the Zig unit tests and the Node-backed CLI differential
  smoke, proving complex prefix parsing works in the actual meta-block pipeline.

- Added compressed-frame coverage for Brotli complex insert/copy prefix codes.
  A literal-only frame now uses a complex prefix-code header for the command tree
  while keeping the literal tree simple, and is decoded by both Zig tests and the
  Node-backed CLI differential smoke.

- Added compressed-frame coverage for Brotli complex distance prefix codes. A
  match-copy frame now keeps literal and command trees simple while using a
  complex prefix-code header for the distance tree, with matching Zig and
  Node-backed CLI differential coverage.

- Added compressed-frame coverage for Brotli complex block-length prefix codes.
  A literal-block-switch frame now uses a complex prefix-code header for the
  block length tree while switching literal block types, with matching Zig and
  Node-backed CLI differential coverage.

- Expanded Brotli decoded-size preflight's recent literal history window to 256
  bytes and switched the preflight tail to a ring buffer so larger tracked
  histories avoid per-byte sliding copies. Compressed context-selected literal
  frames now copy with distances 65 and 129 before decoding another literal from
  the copied `b` context, keeping allocator-returning decode preflight aligned
  with the full-output decode path. Zig tests and the Node-backed CLI
  differential smoke cover both frames.

- Expanded Brotli decoded-size/summary preflight's recent literal history window
  to 512 bytes. A compressed context-selected literal regression frame now copies
  with distance 257 and then decodes another literal from the copied `b`
  context, ensuring allocator-returning, summary, limited-size, and caller-buffer
  decode paths agree without materializing full output during preflight.

- Expanded Brotli decoded-size/summary preflight's recent literal history window
  to 1024 bytes. A compressed context-selected literal regression frame now
  copies with distance 513 and then decodes another literal from the copied `b`
  context, extending the same no-full-output preflight parity to the next
  regular-distance range.

- Improved Brotli decoded-size/summary preflight for copies beyond its bounded
  recent-history window. If a later literal block is context-independent because
  all 64 literal contexts select the same tree, preflight now continues decoding
  instead of returning `UnsupportedBrotliFeature`; a distance-1025 compressed
  regression frame covers decoded-size, summary, limited, and caller-buffer
  decode parity.

- Added the first narrow Brotli static-dictionary decode slice. A real Node
  quality-5 frame for `hello brotli hello brotli` starts with a copy from
  distance 720 before any bytes have been emitted; Vort now resolves that
  distance/copy-length pair to the built-in word `hello` in both size preflight
  and output decode. The Node-backed CLI differential now treats that frame as a
  successful decode while broader static dictionary words/transforms remain a
  follow-up.

- Extended the narrow Brotli static-dictionary slice with the next real Node
  quality-5 word. A `the quick brown fox...` frame copies `quick` from static
  dictionary distance 112 after emitting `the `, and now round-trips through both
  size preflight and output decode. This keeps the static dictionary support
  evidence tied to real encoder output while the complete dictionary table is
  still pending.

- Added another real Node quality-5 static-dictionary word to the narrow Brotli
  slice. A 256-byte Lorem Ipsum frame copies `dolor` from static dictionary
  distance 1002 after emitting `Lorem ipsum `, and now decodes through the same
  preflight/output path plus the Node-backed CLI differential smoke.

- Cached exact dynamic-Huffman bit cost and the existing fixed-block planning
  cost while collecting Deflate token frequencies. Best-block selection now
  scans the token stream once instead of rescanning it for fixed cost, dynamic
  frequencies, and dynamic cost; the remaining cost calculation is bounded by
  the 286 literal/length and 30 distance histograms. The implementation keeps
  synthetic single-symbol tree frequencies separate from actual emitted
  frequencies and preserves the historical fixed-cost model so block choices
  and encoded bytes do not change. A retained token-scan reference covers empty,
  literal-only, match-only, mixed, and 4096-token full-range inputs. On imx's
  fixed-CPU-12 PNG encode harness, an 11-round alternating old/new A/B measured
  adaptive L8/RGB8/RGBA8 speedups of `1.098/1.072/1.118x`, a nine-row geomean
  of `1.035x`, and identical encoded lengths, checksums, and guards.
  Final validation passed `zig build test -j1` in 1:53.79 at 4,124,084-KiB
  peak RSS and `zig build check -j1` in 5:01.65 at 687,136-KiB peak RSS; both
  completed with zero swap.

- Bounded the hash-greedy predecessor table by its active power-of-two history
  window for inputs of at least 512 KiB. The production PNG-fastest path now
  uses 16 KiB predecessor slots instead of one `isize` per filtered input byte,
  while short inputs and custom non-power-of-two or above-DEFLATE windows retain
  the original full table. A full-table oracle compares the public ring-backed
  planner token-for-token and stat-for-stat across 1/8/1024/4096/16384-byte
  windows and inputs that wrap every slot repeatedly. An unrestricted ring was
  rejected because changing allocator reuse after the first small PNG case
  regressed later stored/Up rows; the retained 512 KiB threshold preserves that
  short-stream behavior. On imx's fixed-CPU-12 harness, a final 11-round
  alternating old/new A/B measured `1.008x` nine-row throughput geomean,
  `1.078x` adaptive RGB, and all other rows within about 1.7%, with identical
  encoded lengths/checksums/guards. A separate seven-round external-time A/B
  reduced median imx child RSS from 21,041,152 to 10,055,680 bytes (`0.478x`);
  all 14 children reported zero swap.
  Final validation passed `zig build test -j1` in 1:54.17 at 4,125,704-KiB
  peak RSS and `zig build check -j1` in 4:48.77 at 689,532-KiB peak RSS, both
  with zero swap.

- Removed the redundant package sort at every length-limited Huffman
  package-merge depth. Each input package list is sorted, so sums of adjacent
  pairs are nondecreasing; equal sums require four equal input weights, where
  the existing reverse-symbol counts tie-break remains ordered under
  component-wise addition. Production now merges those naturally ordered pairs
  directly with the leaves, while the original sorted-pair implementation
  remains as a test reference. Dense/sparse/equal 286-symbol literal/length,
  30-symbol distance, and 19-symbol code-length distributions compare exact
  code-length arrays, including 32 collision-heavy seeds. The Huffman
  length/build gates pass, and imx's fixed-CPU-12 11-round PNG A/B measured
  `1.020x` adaptive L8, `1.140x` Up L8, `1.017x` nine-row geomean, neutral
  RGB/RGBA rows, and identical encoded lengths/checksums/guards.
  Final validation passed `zig build test -j1` in 1:40.89 at 4,125,424-KiB
  peak RSS and `zig build check -j1` in 4:16.08 at 687,376-KiB peak RSS, both
  with zero swap.

- Fused each dynamic-Huffman LZ77 match's length symbol, length extra value,
  distance symbol, and distance extra value into one LSB-first `BitWriter`
  update. The maximum concatenated field is 48 bits, below the writer's 56-bit
  limit, and eliminates up to three repeated ArrayList/capacity calls per
  match. A retained four-write reference compares final bytes across every
  RFC length/distance code's first and last value and all eight starting bit
  alignments. On imx's fixed-CPU-12 11-round PNG encode A/B, adaptive
  L8/RGB8/RGBA8 improved `1.105/1.054/1.108x`, the nine-row geomean improved
  `1.029x`, stored/Up rows stayed neutral, and every encoded length, checksum,
  and guard remained identical.
  Final validation passed `zig build test -j1` in 1:42.83 at 4,125,496-KiB
  peak RSS and `zig build check -j1` in 4:16.48 at 686,048-KiB peak RSS, both
  with zero swap.

- Added a reserved-capacity bit-writer path for best dynamic Deflate blocks.
  `writeBestTokensBlock` already reserves the exact encoded byte count before
  emitting a selected dynamic block; that path now appends complete bytes
  without rechecking/growing the ArrayList for every header field, Huffman
  symbol, and fused match. Other dynamic/split writers retain checked writes.
  Exhaustive 0..56-bit/all-alignment packing tests compare checked and reserved
  writers, while a full dynamic-block reference compares header, code-length
  tree, literal/match payload, EOB, and final bytes across all starting
  alignments. On imx's fixed-CPU-12 11-round PNG A/B, adaptive
  L8/RGB8/RGBA8 improved `1.022/1.017/1.019x`, the nine-row geomean improved
  `1.007x`, other modes stayed neutral, and all encoded lengths, checksums, and
  guards remained identical.
  Final validation passed `zig build test -j1` in 1:40.82 at 4,124,876-KiB
  peak RSS and `zig build check -j1` in 5:07.71 at 687,304-KiB peak RSS, both
  with zero swap.

- Removed the package-order proof scan from ReleaseFast/ReleaseSmall
  package-merge builds. Debug/ReleaseSafe still assert every naturally ordered
  pair list, and the sorted-pair reference continues to compare exact code
  lengths over dense/sparse/equal DEFLATE alphabets and collision-heavy seeds,
  so production no longer pays a second full-package traversal solely for a
  development invariant. On imx's fixed-CPU-12 11-round PNG A/B, Up L8
  improved `1.214x`, adaptive L8/RGB8 improved `1.008/1.011x`, the nine-row
  geomean improved `1.020x`, and every encoded length, checksum, and guard
  remained identical.
  Final validation passed `zig build test -j1` in 1:41.55 at 4,126,468-KiB
  peak RSS and `zig build check -j1` in 4:12.35 at 688,748-KiB peak RSS, both
  with zero swap.

- Packed package-merge symbol multiplicities into 4-bit nibbles. Code lengths
  are capped at 15, so two symbols fit in each byte; component-wise package
  addition cannot carry between nibbles, and reverse byte comparison preserves
  the original reverse-symbol tie-break. Production literal/length package
  records are roughly halved, while the old byte-per-symbol implementation
  remains the exact-code-length reference. Dense, sparse, equal, and seeded
  collision-heavy 286/30/19-symbol distributions compare identically, with
  Debug assertions covering every intermediate nibble sum. On imx's
  fixed-CPU-12 11-round PNG A/B, Up L8 improved `1.152x`, adaptive
  L8/RGB8/RGBA8 improved `1.009/1.006/1.023x`, the nine-row geomean improved
  `1.019x`, and encoded lengths/checksums/guards stayed identical. A separate
  seven-round external-time A/B reduced median imx child RSS from 10,055,680 to
  9,592,832 bytes (`0.954x`), with zero swap in all 14 children.
  Final validation passed `zig build test -j1` in 1:59.58 at 4,125,180-KiB
  peak RSS and `zig build check -j1` in 5:03.48 at 687,060-KiB peak RSS, both
  with zero swap.

- Replaced repeated DEFLATE length-code arithmetic with a compile-time table
  covering every match length from 3 through 258. The original log2/division
  formula remains a test reference and matches every table entry, so token
  frequencies, block decisions, and encoded bytes are unchanged. On imx's
  fixed-CPU-12 11-round PNG A/B, adaptive L8/RGB8/RGBA8 improved
  `1.044/1.035/1.037x`, the nine-row geomean improved `1.012x`, and every
  encoded length, checksum, and guard remained identical.
  Final validation passed `zig build test -j1` in 1:57.52 at 4,124,928-KiB
  peak RSS and `zig build check -j1` in 5:04.65 at 688,456-KiB peak RSS, both
  with zero swap.

- Replaced distance-code log2/division arithmetic with a compact zlib-style
  two-level symbol table. Distances 1...256 index directly; larger distances
  use `(distance - 1) >> 7` into the upper 256 entries, while existing RFC
  metadata supplies extra-bit widths and base values. The original formula is
  exhaustively compared over all 32,768 valid distances. On imx's fixed-CPU-12
  11-round PNG A/B, adaptive L8/RGBA8 improved `1.028/1.051x`, the nine-row
  geomean improved `1.009x`, other rows stayed neutral, and every encoded
  length, checksum, and guard remained identical.
  Final validation passed `zig build test -j1` in 1:51.75 at 4,125,404-KiB
  peak RSS and `zig build check -j1` in 4:17.82 at 688,028-KiB peak RSS, both
  with zero swap.

- Added a capacity-available fast path to the PNG-ultrafast reservoir's
  eight-byte flush. The writer keeps the same growable allocation fallback and
  output format, but no longer enters ArrayList's generic capacity helper for
  every flush after capacity has already been proved. A zero-loss fixed-core
  profile previously attributed `6.54%` of the complete nine-case PNG runner
  to that generic append; the post-change profile no longer contains the
  symbol. Two independent CPU-12, 41-round alternating old/new A/Bs retained
  exact encoded sizes, checksums, and guards. Compressed-case geomean improved
  `1.116x` and `1.109x`; the second run measured `1.085x` adaptive,
  `1.135x` Up, `1.001x` stored, and `1.072x` across all nine rows, with all
  six compressed rows faster.
- Rejected packing the 65,536-entry PNG literal-pair table from u64 to u32.
  The representation was byte-exact against the scalar writer and fdeflate
  goldens and halved table storage, but a CPU-12, 41-round alternating A/B
  measured `0.99684x` compressed and `0.99766x` all-row throughput; all six
  compressed rows regressed slightly. Do not repeat it as a throughput change
  without a different access or emission strategy.
- Final validation for the retained PNG-ultrafast append change passed focused
  scalar/fdeflate byte-exact tests, imx PNG integration tests, full
  `zig build test -j1` in 3:45.46 at 4,125,068-KiB peak RSS, and
  `zig build check -j1` in 5:07.50 at 689,668-KiB peak RSS. Both full Vort
  commands reported zero swap.

- Directly emit the two literal quads for a complete non-zero eight-byte
  PNG-ultrafast input word. The run detector had already loaded that u64, so
  the common path now derives four pair-table indexes from the existing word
  instead of entering the variable-slice helper and loading every byte again.
  Boundary-zero chunks and scalar tails retain the generic path. A dedicated
  37-word-plus-tail oracle joins the existing batched/scalar comparisons and
  fdeflate byte-exact goldens.
- Two independent CPU-12, 41-round alternating old/new A/Bs retained exact
  encoded sizes, checksums, and guards. Compressed geomean improved
  `1.194x/1.188x`; the repeat measured `1.150x` adaptive, `1.227x` Up,
  `1.002x` stored, and `1.122x` overall, with all six compressed rows faster.
  A zero-loss post-change profile reduced `writeLiterals` from `38.77%` to
  `11.70%` of the complete nine-case PNG runner.
- The refreshed imx/image-png gate reports `0.931x` overall, `0.865x`
  adaptive, `0.862x` Up, `1.082x` stored, `0.863x` compressed-only, and
  `0.966x` RSS. Every mode remains size-exact; six compressed sizes, three Up
  checksums, three stored files, 18 cross-decodes, and all zero-swap checks
  remain green. Final validation passed imx PNG focused tests, full
  `zig build test -j1` in 3:50.05 at 4,125,540-KiB peak RSS, and
  `zig build check -j1` in 5:03.26 at 688,936-KiB peak RSS, both with zero
  swap.

- Profiled both Adler symbols after the direct-literal optimization. Vort's
  PNG-ultrafast `checksum.Adler32.update` is already lowered to an AVX2/VNNI
  64-byte loop and represented only `1.64%` of the full nine-case runner. The
  larger scalar `hash.Adler32.update` sample belongs to imx's stored-PNG helper,
  not the ultrafast zlib encoder. Adler changes were therefore rejected as the
  wrong next layer rather than optimizing the misleading aggregate symbol.
- Rejected an incremental PNG-ultrafast encoder intended to let imx avoid its
  complete filtered-image allocation and second payload scan. The state kept
  eight-byte input grouping across arbitrary updates, continued zero runs
  across PNG row boundaries, and maintained an incremental Adler footer.
  Every split point, one-byte updates, variable row updates, the scalar writer,
  fdeflate goldens, and all 30 real-corpus encoded size/checksum/guard tuples
  agreed byte-for-byte. Despite that, a CPU-12 21-round imx old/new A/B
  measured only `0.92936x` adaptive, `0.89383x` Up, `0.91142x` overall
  geomean, and `0.95060x` aggregate. A second version combined each filter byte
  and row into one update and added a scalar/vector-verified deferred Adler
  state that reduces at the normal 5,552-byte boundary instead of per update;
  it still measured `0.92723x` adaptive, `0.88581x` Up, `0.90628x` overall,
  and `0.94998x` aggregate. Both versions were fully reverted. The contiguous
  one-shot loop's compiler optimization and locality are more valuable than
  avoiding that intermediate scan in this design; do not repeat per-row
  streaming without retaining the one-shot loop shape.
- Replaced PNG-ultrafast zero-run residual length selection's linear 29-range
  scan with a compile-time 256-entry lookup for lengths 3...258. This is
  separate from the previously rejected literal code/length-table layouts:
  only RFC length symbol/extra-bit selection changed, while the 512-KiB
  literal-pair table and reservoir writes remain intact. The old range scan is
  retained as a reference and exhaustively matches every lookup entry; scalar
  writer comparisons and fdeflate 0.3.7 goldens remain byte-exact.
- The optimization was selected from a post-imx-u8-row profile where
  `writeZeroRun` represented about `6.97%` of the full Exoplanet adaptive
  encode and its inlined `lengthCode` scan about `2.58%`. A CPU-12 21-round
  real-corpus old/new A/B measured `1.04508x` adaptive, `1.05916x` Up,
  `1.05210x` overall geomean, and `1.04088x` aggregate. The 61-round
  confirmation measured **`1.05339x` adaptive, `1.05825x` Up, `1.05582x`
  overall, and `1.05068x` aggregate**, with all 30 encoded sizes, checksums,
  and guards exact and no swap activity. A separate 101-round, 20-encode
  focused check of the initially noisy non-indexed Exoplanet adaptive row
  measured `1.01235x` median and `1.01821x` paired geomean, also exact.
- The refreshed fixed-CPU imx/image-png 15-file gate reports `0.904x`
  throughput geomean, `0.903x` aggregate, `0.922x` median, `0.860x`
  adaptive, `0.952x` Up, and `1.046x` RSS. All 15 raw normalizations, 60
  cross-decodes, 15 Up filtered payloads, encoded-size constraints, and the
  formal gate's zero-swap checks pass. Vort full test/check passed in
  237.94/308.31 seconds at 4,125,724/688,536-KiB peak RSS; the full test saw
  one page of system swap-in while check was stable. imx full test/check passed
  in 570.19/64.34 seconds at 6,418,192/693,776-KiB peak RSS with stable swap
  counters.
- Tested batching eight 64-byte Adler folds into one 512-byte u32-vector
  weighted sum, aiming to reduce horizontal reductions while preserving the
  existing 5,552-byte modulo boundary. New differential coverage matched Zig
  std at 64/512/5,552 boundaries, four input alignments, and an all-`0xff`
  NMAX worst case; all 17 checksum tests and the external checksum differential
  passed. The ReleaseFast checksum benchmark nevertheless fell from about
  `23.65` to `10.57 GiB/s`. LLVM already lowers the 64-byte expression to
  efficient AVX2/VNNI `vpsadbw`/`vpdpbusd`; the direct 512-byte u32 weighting
  destroyed that code shape. The experiment was fully reverted before any PNG
  corpus run. Do not retry wide u32 vector weights; a future Adler attempt must
  retain narrow-lane dot-product lowering.
- Added a narrower Adler ILP optimization modeled on zlib-ng's two-block
  structure without importing target intrinsics. Two independent 64-byte
  `sum/weighted` folds are exposed to LLVM together, then combined with the
  exact two-step Adler recurrence; the existing weight vector, u32/NMAX
  overflow proof, modulo boundary, streaming API, and scalar tail remain.
  LLVM therefore retains the efficient AVX2/VNNI dot-product lowering rather
  than generating the rejected wide-weight form.
- Known vectors, all checksum families, external Zig-std differential cases,
  63/64/65 and 127/128/129 boundaries, 5,551/5,552/5,553 boundaries, four
  input alignments, and an all-`0xff` NMAX input remain exact. A CPU-12
  31-round alternating checksum A/B measured `1.06030x` median and `1.04396x`
  paired geomean with identical digest mix. On imx's 15-file PNG corpus,
  21 rounds measured `1.00141x` throughput geomean; the 61-round confirmation
  measured `1.00219x` adaptive, `1.00287x` Up, `1.00253x` overall, and
  `1.00457x` aggregate with all 30 output tuples exact.
- The refreshed formal image-png gate remains effectively unchanged at
  `0.905x` geomean, `0.903x` aggregate, `0.925x` median, `0.860x` adaptive,
  `0.951x` Up, and `1.046x` RSS, with all correctness/size/zero-swap checks
  green. Final Vort test/check passed in 218.40/266.59 seconds at
  4,125,488/689,176-KiB peak RSS; imx test/check passed in 574.94/95.70
  seconds at 6,421,264/695,948-KiB. The first three runs kept swap counters
  stable; imx check observed one page of system swap-in.
- Tested exposing four independent 64-byte folds per Adler loop turn while
  retaining the committed two-block and one-block tails. All 17 checksum tests
  and the external differential remained exact, but a CPU-12 31-round
  alternating checksum A/B measured only `0.98854x` median and `0.99011x`
  paired geomean versus the committed two-block implementation. The added
  expression/register pressure outweighed further ILP, so the four-block loop
  was reverted before any PNG corpus run. Keep the two-block unroll as the
  measured portable sweet spot.
- Rejected forcing the remaining boundary `writeLiterals` helper inline.
  Scalar/fdeflate output stayed byte-exact and two 41-round CPU-12 A/Bs showed
  `1.020x/1.018x` compressed geomeans, but a 121-round repeat reproduced a
  `0.9877x` Luma-stored row even though that mode does not call the helper.
  This is an observable release-binary layout tradeoff, so the change was
  fully reverted instead of accepting the aggregate gain.
- Rejected batching short zero-run fields into one reservoir write. Expanding
  the scalar-byte oracle to every run length `1...2048` first caught an
  incorrect long-run batching boundary at length 1,304. Restricting fusion to
  runs at most 258 restored exact output, but a 41-round A/B measured
  `0.9994x` compressed, `0.9946x` Up, and `0.9890x` RGBA Up. The complete
  experiment was reverted; do not revisit it without a different zero-run
  representation and the expanded oracle.

- Profiled the six generated ultrafast filtered payloads before changing the
  remaining literal helper. Across 4,197,376 input bytes there were 414,073
  complete non-zero words and 110,599 boundary literal calls; every boundary
  call contained exactly seven literals followed by a one-byte zero run. No
  all-zero eight-byte words occurred. This justified a narrow shape-specific
  path rather than another generic literal-table experiment.
- Added a seven-literal PNG-ultrafast path for words ending in exactly one zero.
  It derives one literal quad and one literal triple from the u64 already
  loaded for run detection, reducing four reservoir writes to two. All other
  suffix lengths retain the existing helper. A 1,785-chunk oracle varies every
  one of the seven literal positions through byte values `1...255` and compares
  the complete stream against the scalar writer; fdeflate goldens remain exact.
- Two CPU-12, 41-round alternating A/Bs improved compressed geomean by
  `1.066x/1.069x`; the second measured `1.073x` adaptive, `1.066x` Up,
  `1.001x` stored, and `1.046x` overall. A 121-round repeat measured
  `1.067x` compressed, `1.074x` adaptive, `1.061x` Up, and `1.001x` stored.
  Every encoded size, checksum, and guard remained exact; the standalone
  `writeLiterals` symbol disappeared from the post-change profile.
- The refreshed imx/image-png gate reports `1.011x` overall, `1.006x`
  adaptive, `0.925x` Up, `1.110x` stored, `0.964x` compressed-only, and
  `0.966x` RSS. Overall and adaptive now clear parity on the generated matrix,
  but Up and individual Luma/RGB rows remain below parity. Final validation
  passed imx PNG focused tests, full `zig build test -j1` in 3:41.26 at
  4,125,140-KiB peak RSS, and `zig build check -j1` in 4:21.52 at
  689,188-KiB peak RSS, both with zero swap.

- Built a temporary same-scope filtered-payload comparison against fdeflate
  0.3.7 after the generated full-PNG gate reached overall parity. Both sides
  allocate, encode, and release in the timer, while file I/O and full checksum
  validation stay outside. Across the six adaptive/Up payloads, all zlib bytes,
  checksums, and guards match exactly. A CPU-12, 41-round alternating run
  measured Vort/fdeflate at `0.918x` geomean, `0.892x` Up, and `0.946x`
  adaptive. RGB adaptive reached `1.032x` and RGBA adaptive `0.998x`; the two
  Luma payloads remained the largest gap at about `0.82x`. This establishes
  that the remaining generated compressed-only gap is mainly inside the
  ultrafast encoder rather than PNG chunk/filter wrappers.
- Hardware counters on the no-zero Luma Up payload showed Vort executing fewer
  instructions than fdeflate (`12.66B` versus `13.55B`) but spending more
  cycles (`2.68B` versus `2.25B`), with roughly `239k` versus `50k` cache
  misses and IPC around `4.72` versus `6.03`. The 512-KiB pair table therefore
  trades instruction count for a longer memory/dependency path. Exact
  `toOwnedSlice` shrinking was inspected but `SmpAllocator.remap` represented
  only about `0.07%`, so output ownership was not the main gap.
- Rejected several measured alternatives to that pair table. A 256-entry
  packed code/length table reduced RSS to about `0.903x image-png` but measured
  `0.875x` compressed throughput, with every compressed row 10--15% slower.
  Separate u16-code/u8-length tables, matching fdeflate's source layout, raised
  Luma cycles by about 19% and instructions by about 27%. Software-prefetching
  four future pair entries raised cycles by about 9% and instructions by 14%,
  while loading all four current entries before either reservoir write raised
  cycles by about 2%. None reduced measured cache misses enough to offset their
  extra instructions; all were fully reverted.
- Real-payload frequency analysis also rejected narrow constant-code guesses.
  Pair lengths `(12,12)` represented only `0.1%`; the leading combinations
  were `(3,6)`, `(3,3)`, `(3,2)`, and `(2,3)`. Exact pairs were highly
  concentrated, and repeated-byte words covered 92.3% of Luma Up, but a
  repeated-octet branch measured `0.973x` compressed and caused large
  full-matrix regressions despite a 1% isolated Luma gain. Direct single-zero
  emission likewise measured `0.989x` Up. Both were reverted. Future
  pure-literal work should use a materially different table/layout or
  target-specific gather strategy and must pass the complete matrix, not only
  a favorable isolated payload.
- Extended PNG-ultrafast's already-accepted seven-literal boundary path to all
  one-through-seven-literal prefixes followed by zero bytes. The encoder
  reuses the u64 loaded for run detection and emits each prefix through
  symbol/pair/triple/quad combinations; zero-run detection, the literal-pair
  table, bitstream, and Adler footer are unchanged. A 7,140-word oracle varies
  every literal position through values 1...255 for every prefix length and
  requires complete byte equality with the scalar writer; all fdeflate goldens
  remain exact.
- The change was driven by the real 128-pixel RGBA icon: adaptive/Up payloads
  contain 1,225 Up boundary words ending in two-through-seven zeros, which the
  old seven-literal specialization left on scalar symbol writes. A CPU-12
  21-round real-corpus A/B measured `1.02227x` adaptive, `1.03675x` Up,
  `1.02949x` overall geomean, and `1.02048x` aggregate. The 61-round
  confirmation measured **`1.01743x` adaptive, `1.03331x` Up, `1.02534x`
  overall, and `1.01376x` aggregate**, with all 30 encoded tuples exact and
  stable swap counters. The 128-pixel adaptive/Up rows improved
  `1.060/1.084x`, while 16/32-pixel Up improved `1.086/1.104x`.
- The refreshed image-png gate reports `0.919x` geomean, `0.910x` aggregate,
  `0.926x` median, `0.866x` adaptive, `0.975x` Up, and `1.046x` RSS. All
  raw, cross-decode, Up-filtered-payload, size, and zero-swap gates pass. Vort
  full test/check passed in 221.77/317.92 seconds at
  4,124,900/687,300-KiB peak RSS with stable swap counters.
- Audited whether adjacent trained-Huffman literal groups could be fused into
  one reservoir write when their total bit length is at most 56. Across the 30
  real payloads, 68.5% of full eight-literal words and 90.2% of one-through-
  seven-literal boundary prefixes satisfy that bound; scalar/fdeflate output
  remained exact for every prototype.
- Fusing both full words and boundary prefixes improved many Up rows but
  regressed Lohengrin adaptive/Up to `0.924/0.959x` and aggregate to `0.995x`
  in a 21-round corpus A/B. Restricting fusion to prefixes restored much of the
  full-word path but still left several 1--2% large-image regressions.
  Restricting again to only five/six-literal prefixes measured `0.99856x`
  adaptive, `0.99695x` Up, `0.99776x` overall, and `0.99518x` aggregate, with
  the 128-pixel Up row at `0.96086x`. All three forms were fully reverted.
  Avoid conditional multi-group fusion in this loop unless a branch-free
  representation can preserve the accepted hot-code shape.
- Rejected raising PNG-ultrafast's initial output capacity to 24 KiB for small
  filtered payloads. Allocation diagnostics showed the 32-pixel RGBA payloads
  growing through three/four allocation calls, while a general 24-KiB floor
  removed those growths and improved a fixed-CPU-12, 61-round alternating
  focused A/B by `1.00833x` adaptive and `1.01560x` Up. The same floor was
  neutral for the 16- and 128-pixel rows, but it over-reserved substantially
  outside the one useful size.
- Narrowing the floor to only 4--16-KiB inputs retained the 32-pixel gain
  (`1.01055x` adaptive and `1.01496x` Up) and left encoded checksums/guards
  exact, but changed release code layout enough to regress the non-matching
  128-pixel adaptive/Up rows to `0.91927x/0.88956x`. Marking the window
  unlikely and rebuilding reproduced the failure in a second 61-round run at
  `0.93226x/0.91861x`, despite the 65-case scalar/golden oracle passing and
  those 65,536-byte raw inputs never taking the capacity branch. Both forms
  were fully reverted before the real-corpus/RSS gate. Do not trade global
  release-binary layout for this isolated allocation win; revisit output
  sizing only with a branch-free hint or a caller-provided exact-capacity API.
- Rejected an unconditional u128 reservoir submission for each complete
  eight-literal PNG-ultrafast word. Unlike the earlier conditional group-fusion
  attempts, this prototype always combined all four pair-table entries (up to
  96 bits) and let a dedicated writer emit one or two complete u64 words in one
  ArrayList append. A 16,384-case low-level oracle covered every pending
  reservoir bit count, representative 1...96-bit widths/patterns, split-write
  state equality, a trailing write, and final byte alignment. The complete-word
  scalar oracle, 7,140 boundary-prefix oracle, and fdeflate goldens also stayed
  exact; all 65 focused tests passed.
- The wider arithmetic was nevertheless much slower than two normal quad
  writes. A fixed CPU-12, 21-round alternating A/B over all 30 real filtered
  payloads measured `0.97669x` adaptive, `0.96445x` Up, `0.97055x` overall,
  and `0.98435x` aggregate. The 128-pixel adaptive/Up rows fell to
  `0.79114/0.80713x`, and 16/32-pixel rows also regressed. The experiment was
  fully reverted before complete PNG/reference gates. Do not use generic u128
  shifts to fuse this hot path; a future wide submission would need native
  two-word operations with lower overhead than the current pair of u64 writes.
- Profiled maximal zero runs across the 30 real filtered payloads before
  revisiting the rejected short-field batching idea. The corpus contains
  7,536,859 runs and 133,945,321 zero bytes; 346,725 repeated 258-byte
  length-285 tokens are emitted, but nearly all long-run opportunity is
  concentrated in Exoplanet. Runs at least 5,160 bytes occur only in its four
  adaptive/Up payloads.
- Tested batching five identical length-285-plus-distance-zero fields into one
  ordinary 50-bit u64 writer call. A complete-stream oracle compared every
  all-zero length 1...4,096 against the per-token reference, including the
  previously problematic 1,304 boundary; all 65 focused tests and output
  signatures passed. Applying batching to every eligible run nevertheless
  measured only `0.99258x` adaptive, `0.98972x` Up, `0.99115x` overall, and
  `0.99199x` aggregate in a CPU-12 21-round 30-payload A/B.
- A second form moved batching to a noinline helper and used it only above
  5,160 bytes, with extra exact boundaries around 5,160/6,450/10,320 bytes.
  A 31-round focused A/B still left the four Exoplanet rows at only
  `0.98453...1.00391x`, while the non-matching 128-pixel adaptive/Up controls
  fell to `0.79883/0.85008x` from release-code layout movement. Both forms were
  fully reverted. Do not batch length-285 output fields in this implementation;
  future long-zero work should reduce input scanning without changing the
  compact token-writer shape.
- Profiled aligned all-zero input scanning next. Across the 30 real filtered
  payloads, 14,446,622 u64 words are zero; after one zero word is known,
  1,592,694 aligned 64-byte probes can skip 12,741,552 further word loads
  (`88.2%`). A lane-mask scanner consumes all leading zero u64 lanes even when
  a 64-byte probe contains a later nonzero word, while retaining the original
  run/token writer. Offset/run boundary oracles, scalar encoder parity, all
  7,140 literal-prefix cases, and fdeflate goldens stayed exact.
- The scanner itself was strongly positive. A bounded three-interior-window
  classifier selected only sustained-zero payloads before entering a scan
  specialization. Fixed CPU-12 A/Bs over all 30 real filtered payloads measured
  `1.06198x/1.06733x` adaptive/Up at 21 rounds and
  `1.06533x/1.06464x` at 61 rounds; overall/aggregate were
  `1.06499/1.03171x`, every row improved, and every encoded signature matched.
  Exoplanet improved roughly 9--17%, while zero-dominated Transparency improved
  roughly 52%.
- The optimization was still rejected because every production integration
  enlarged or moved the complete PNG release binary enough to regress important
  nonmatching rows. Inlining scan/non-scan specializations gave a positive
  61-round complete-PNG geomean (`1.01728x`) but regressed 128/16-pixel
  adaptive by about 1.5%. A noinline scan wrapper reduced the complete-PNG
  21-round geomean to `1.00970x` and left several ordinary rows negative.
  Exposing a separate byte-identical root API and selecting it in imx, with and
  without an unlikely hint, still regressed 128-pixel Up by about 5--6% and
  16-pixel Up by about 3% in the final 31-round focused run. All production
  forms were fully reverted before the formal image-png/RSS gate. The measured
  scanner remains a valid future candidate only if build-time feature
  partitioning or stronger function-placement control can keep it out of the
  ordinary encoder's release layout.
- Audited Zig 0.16's standard-memory search as a possible no-new-loop route to
  the same optimization. `std.mem.findNone(u8, bytes, &.{0})` / `findNonePos`
  use a scalar nested loop; a local ReleaseFast object confirmed that
  first-nonzero search compiles to one byte compare per iteration. In contrast,
  `findScalar` has a vector fast path but expresses the opposite query. The
  standard helper was therefore rejected before production benchmarking rather
  than replacing the existing u64 loop with a byte-at-a-time scan.
- Also tested layout-only hints on the unchanged `word == 0` branch. Real
  payloads have a 64.14% aggregate zero-word ratio, but distributions range from
  below 2% on Kodak to above 90% on Exoplanet/Transparency. Marking zero likely
  improved the 21-round 30-payload geomean by `1.03560x` with 29/30 rows
  positive, yet regressed the 128-pixel adaptive row to `0.92109x`. Marking it
  unlikely still left 128-pixel adaptive/Up at `0.89402/0.95655x` in a
  31-round focused run and made several Exoplanet rows negative. Both one-line
  experiments were fully reverted. Do not globally bias this bimodal branch.
- Re-profiled the committed imx real-corpus runner after the rejected allocator
  experiments. On indexed Exoplanet Up, Vort zlib represented `46.29%` of
  complete PNG encode, with `writeZeroRun`/`writeLiterals` at
  `11.57/8.95%`; RGBA lorem Up attributed `16.46/14.83%` to those helpers.
  Adler and final container copy were smaller, so the next retained change
  stayed inside the existing 654-line `png_ultrafast.zig` module.
- Audited the branch reached when a zero run carries from the preceding u64
  word into a nonzero boundary word. Across the 30 filtered payloads it occurs
  1,451,701 times. The encoder already loaded the word, counted its prefix and
  suffix zero bytes, then rebuilt an interior slice of one through seven
  literals and entered generic `writeLiterals`. It now right-shifts that
  existing u64 and reuses the established one-through-seven
  `writeLiteralPrefix` emitter. Zero scanning, token shape, pair tables,
  reservoir writes, and Adler output remain unchanged.
- A complete-stream oracle covers every legal prefix/suffix combination, every
  interior literal position, and values 1...255 after a carried all-zero word.
  It compares the optimized stream with the scalar writer; all existing
  boundary-prefix and fdeflate 0.3.7 goldens remain exact. The 65 focused
  ReleaseFast tests pass.
- Fixed CPU-12 alternating old/new corpus runs required all 30 sizes,
  pixel/encoded checksums, and guards to match. The 21-round result was
  `1.03968x` geomean / `1.02741x` aggregate with all rows positive. The
  61-round confirmation measured **`1.03648x` geomean, `1.02991x` aggregate,
  `1.03338x` adaptive, and `1.03959x` Up**; the minimum row was `1.01027x`
  and swap-page delta stayed zero.
- The formal 15-file image-png gate retained 15 raw-byte matches, 60
  cross-decodes, 15 exact Up filtered payloads, Up size non-regression, and
  zero swap. Current throughput is `0.947x` geomean / `0.931x` aggregate /
  `0.957x` median, adaptive `0.889x`, and Up **`1.009x`**; encoded-size
  geomean is `0.99811x` and median RSS remains `1.046x`. Overall real-corpus
  parity is not yet reached, but fixed Up now clears parity.
- Post-change profiles no longer show `writeLiterals` above the 0.5% reporting
  threshold on indexed Exoplanet Up or RGBA lorem Up; `writeZeroRun` remains
  the leading named Vort helper. Its short-field and long-token batching
  variants are already rejected, so future work should not repeat them.
- Final validation passed Vort `zig build test -j1` in 3:37.19 at
  4,131,124-KiB peak RSS and `zig build check -j1` in 5:05.93 at
  694,280-KiB. imx codec tests passed in 28.02 seconds at 607,460-KiB,
  full test in 10:01.21 at 6,429,236-KiB, and full check in 2:56.88 at
  700,048-KiB. Every measured validation reported zero swap.
- Rejected replacing PNG-ultrafast's zero-run length accumulator with an
  optional run-start offset. The candidate removed the serial `run += 8`
  dependency on each all-zero u64 and computed the complete run length once at
  its closing boundary. The former accumulator remained as the scalar
  full-stream reference; new tests covered 7/8/9, 257/258/259,
  1,304, repeated-258-token, terminal-run, and partial-tail boundaries. All 66
  focused ReleaseFast tests, fdeflate goldens, and 30 real encoded tuples were
  exact.
- The additional optional/state arithmetic cost more than the removed add.
  A CPU-12 21-round A/B measured `0.98332x` geomean, `0.98638x` aggregate,
  `0.98998x` adaptive, and `0.97671x` Up; Transparency Up was the `0.90389x`
  worst row. The code was fully reverted before reference/full gates. Keep the
  simple run-length accumulator unless a future scanner can skip multiple
  loads without introducing the already rejected specialization/layout cost.
- Rejected forcing `writeZeroRun` inline after post-carried-literal profiles
  made it the leading named Vort helper at roughly 10--17% of fixed Up encode.
  All 65 focused tests and all 30 encoded tuples remained exact, but a CPU-12
  21-round A/B measured `0.98760x` geomean, `0.99646x` aggregate,
  `0.98907x` adaptive, and `0.98612x` Up. The 16/32-pixel adaptive rows fell
  to `0.94270/0.94475x`; code growth and layout outweighed removing the helper
  call. The annotation should not be retried without materially shrinking the
  helper body first.
- Reworked the narrow Brotli static-dictionary slice to resolve identity-word
  addresses relative to the current output length instead of matching only raw
  distance codes. Real Node quality-5 frames now prove additional dictionary
  stems/words (`about`, `press`, `dictionary`, and `information`) through both
  decoded-size preflight and output decode, while transformed dictionary entries
  remain explicitly unsupported until the full transform table is implemented.

- Added another identity-word batch to the Brotli static-dictionary slice.
  Node quality-5 frames now cover `release`, `expression`, and `depression`
  through unit tests and the CLI differential smoke, exercising 7-byte and
  10-byte dictionary buckets beyond the earlier 5/10/11-byte examples.

- Added the first Brotli static-dictionary transform slice. The decoder now
  recognizes RFC transform index 12 (`OMIT_LAST_1`) for the known `words` stem,
  allowing a real Node quality-5 `wordpress` frame to decode through both
  size preflight and output paths while the broader transform table remains
  intentionally unsupported.

- Added a second Brotli static-dictionary transform slice for RFC transform
  index 6 (leading-space identity). Node-accepted synthetic frames now cover
  ` words`, ` games`, and ` release`, giving the preflight/output decoder and
  CLI differential smoke transform coverage beyond bare omit-last behavior.

- Added uppercase identity entries to the Brotli static-dictionary slice. Real
  Node quality-5 frames for `Dictionary` and `Information` now decode through
  the same preflight/output dictionary path, covering uppercase dictionary words
  that Node emits directly before broader transform-table support lands.

- Added a Brotli static-dictionary trailing-space transform slice for RFC
  transform index 1. Node-accepted synthetic frames now cover `words `,
  `games `, `release `, `dictionary `, and `information ` through both
  preflight and output decode, balancing the earlier leading-space coverage.

- Extended the Brotli static-dictionary trailing-space transform slice with the
  `history ` entry. A synthetic compressed frame now resolves transform index 1,
  copy length 7, and word index 37 through both decoded-size preflight and
  output decode, broadening transform coverage beyond the existing words/games
  and release/dictionary examples.

- Refactored the narrow Brotli static-dictionary support into a small
  table-driven `(transform, length, word_index)` map instead of separate
  per-transform branch ladders. The table now also covers `words`, `games`, and
  `games -> game` (`OMIT_LAST_1`) with Node-accepted synthetic frames, keeping
  the growing subset easier to audit before importing the full dictionary.


- Added another real Node quality-5 identity-word batch to the Brotli static
  dictionary table: `internet`, `language`, `available`, `important`,
  `different`, and `government`. These cover 8/9/10-byte dictionary buckets
  with generated Node frames in the CLI differential smoke.

- Added the first real Brotli `UPPERCASE_FIRST` static-dictionary transform
  entries (RFC transform index 9) to the table. Node-accepted synthetic frames
  now cover `Content`, `History`, `English`, `Dictionary`, and `Information`,
  proving transformed uppercase-first output separately from Node's uppercase
  identity entries.

- Added `run-br-static-dictionary-report`, a small coverage report for the
  current Brotli static-dictionary subset. It validates duplicate/invalid table
  entries, emits transform/length/word-index CSV rows, prints aggregate counts,
  and is compiled by `zig build check` plus run by CI smoke so future dictionary
  slices have an auditable manifest.

- Extended `run-br-static-dictionary-report` with JSON and Markdown outputs in
  addition to CSV. The report now creates parent directories for output paths,
  emits schema/version metadata in JSON, and keeps the default stdout CSV path
  for quick terminal inspection.

- Added `run-br-static-dictionary-report-smoke`, a focused gate for the Brotli
  static dictionary coverage artifacts. It cross-checks CSV/JSON/Markdown row
  counts, required transform/word tuples, duplicate keys, byte counts, and now
  serves as the required dashboard smoke gate for the report artifacts.

- Added another real Node quality-5 identity-word batch to the Brotli static
  dictionary table, covering `system`, `number`, `public`, `history`,
  `English`, `through`, `another`, `because`, `between`, `example`, `however`,
  `children`, and `American`. The CLI differential smoke now exercises these
  6/7/8-byte dictionary buckets directly.

- Added another Node quality-5 Brotli static-dictionary batch covering
  `examples`, `history.`, `one another`, `to another`, and `however, `. This
  extends the table beyond bare identity words into additional punctuation and
  phrase-style transform outputs observed from Node's encoder.

- Added Node quality-5 Brotli phrase entries for `one of the ` and `number of `,
  extending the static-dictionary subset with two common space-terminated
  multi-word outputs and differential CLI coverage.

- Strengthened the Brotli static-dictionary report smoke so required coverage
  now includes representative phrase entries (`number of `, `one of the `) and
  the `one an` omit-last tuple used by Node's `one another` frame.

- Added the Node quality-5 Brotli phrase entry `large number of ` to the static
  dictionary subset, extending retained phrase coverage into the 16-byte bucket
  with CLI differential validation.


- Strengthened the Brotli static-dictionary report smoke with the 16-byte
  `large number of ` phrase tuple so the longer retained phrase bucket cannot
  silently regress.

- Moved the Brotli static-dictionary report smoke's required coverage tuples into
  `tools/br_static_dictionary_required_coverage.json`, documented the new schema,
  and made both positive and negative smoke tests read the same config so future
  coverage growth no longer requires editing tuple lists in multiple scripts.

- Extended the Brotli static-dictionary report negative smoke with a duplicate
  required-coverage tuple fixture, proving the external required coverage config
  is validated rather than accepted blindly.


- Added `reason` and `source_case` metadata to each Brotli static-dictionary
  required coverage tuple, and taught the smoke to reject missing metadata so
  required rows explain both why they exist and which case introduced them.

- Taught the Brotli static-dictionary report smoke to verify each required
  coverage tuple's `source_case` against `tools/br_literal_cli_diff.py`, and
  added a negative fixture for stale source-case references.

- Added a `category` field to Brotli static-dictionary required coverage tuples
  (`identity`, `transform`, or `phrase`) and taught the smoke/schema checks to
  reject unknown categories, making coverage intent easier to review.


- Extended the Brotli static-dictionary coverage report with category-count
  summaries for identity, transform, and phrase entries, and taught the report
  smoke to cross-check the JSON and Markdown counts against the entry rows.


- Added a transform/category matrix to the Brotli static-dictionary coverage
  report and smoke checks, so dashboard artifacts show how identity, transform,
  and phrase entries are distributed per transform index.


- Extended the Brotli static-dictionary report negative smoke with an
  `invalid_category` fixture, proving required coverage category values are
  constrained to the documented `identity` / `transform` / `phrase` set.

- Added another Node quality-5 Brotli common-phrase batch to the static
  dictionary subset: `of the `, `from the `, `those who`, and `in order to`.
  Unit tests, the Node-backed CLI differential smoke, and the required coverage
  config now pin these identity phrase tuples so the report/dashboard artifacts
  continue to expose phrase growth.

- Added `run-br-static-dictionary-source-audit` and a source-anchor fixture for
  the retained Brotli static-dictionary subset. The audit ties every supported
  `(transform, length, word_index)` tuple back to its raw dictionary word and
  minimal transform kind, and can optionally verify those anchors against a
  local upstream Brotli `common/dictionary_inc.h` / `common/transform.c` checkout,
  and emits a generated Zig table fragment that must match `src/br.zig` before
  the project moves from hand-picked tuples to generated dictionary data. A
  companion negative smoke now mutates anchors, source rows, generated-order
  expectations, and optional upstream source paths to prove the audit fails on
  drift rather than merely producing a happy-path artifact.


- Added a Brotli static-dictionary candidate report that derives not-yet-enabled
  tuples from the current source anchors and supported transform subset. The
  retained JSON/Markdown artifacts expose concrete follow-up rows such as
  trailing-space and uppercase-first candidates, giving future coverage growth a
  generated backlog instead of another purely manual search pass.

- Promoted the first candidate-report batch into real Brotli static-dictionary
  decode coverage. Node quality-5 frames now cover lowercase `english`,
  `english `, ` english`, and `english.`, with source
  anchors and required coverage updated so generated candidates feed back into
  the decoder table.

- Extended the same candidate-probe workflow to the remaining short Node
  quality-5 misses discovered from the generated report. Several requested
  transformed payloads were encoded by Node as different identity dictionary
  words (for example `Through`, `Another`, `Language`, `Government`, and
  `One of the `), so the table now records those actual source tuples along
  with a focused unit batch and required-coverage metadata.

- Added `run-br-static-dictionary-node-probe`, a bounded Node-backed report that
  compresses generated dictionary-candidate payloads with Brotli quality 5 and
  checks whether Vort decodes the exact frames. The retained JSON/Markdown
  artifacts turn candidate triage into machine-readable evidence instead of a
  one-off shell loop.

- Added `run-br-static-dictionary-node-probe-wide`, an opt-in 160-candidate
  sweep, and made the default Node probe fail if any probed Node frame is no
  longer accepted by Vort. This keeps the candidate backlog measurable without
  forcing the wider sweep into every smoke path.

- Added `run-br-static-dictionary-node-probe-full` after the generated candidate
  set reached a clean full sweep. The full step uses the candidate report count
  instead of a magic numeric limit, while the default and wide probes remain
  cheaper checkpoints for routine validation.

- Extended the Brotli Node probe report with transform-kind summary rows, so the
  default, wide, and full probe artifacts show how many affix, uppercase, and
  omit-last candidates were exercised and accepted without manually scanning the
  per-candidate table.

- Extended the Brotli Node probe rows with payload/compressed byte counts and a
  smaller/equal/larger size classification, plus a size summary table in
  Markdown/JSON. Candidate probe artifacts can now identify not only whether
  Vort accepts Node frames, but also whether Node achieved a size win for each
  generated candidate payload.

- Copied candidate-report source metadata into Brotli Node probe artifacts.
  Probe JSON/Markdown now records whether rows came from anchors or upstream
  slices, plus source limits and raw-word counts, so retained probe artifacts are
  self-describing even when compared outside their generating build step.

- Added explicit size-winner rows to the Brotli Node probe report. The JSON and
  Markdown artifacts now list every candidate whose Node Brotli frame is smaller
  than the original payload, sorted by byte savings, so high-value dictionary
  imports can be selected directly from the report.

- Promoted the first size-winning Brotli candidate rows into decoder coverage:
  ` large number of `, ` information`, `  Information`, `large number of  `,
  and ` government`. These rows came directly from `size_winner_rows` and now
  have Node quality-5 differential cases, source anchors, and required coverage
  metadata.

- Added a no-size-winner gate to `run-br-static-dictionary-node-probe-full`.
  After promoting the first size-winning rows, the full anchor-derived probe now
  fails if future generated candidates become smaller than their payloads until
  they are either promoted or intentionally investigated.

- Extended the no-size-winner gate to the opt-in `upstream256` Node probe after
  the current source-limit 256 slice reached zero remaining size winners. This
  gives the larger official-dictionary prefix the same explicit backlog guard as
  the anchor-derived full probe.

- Extended the same no-size-winner gate to the opt-in `upstream512` Node probe
  after the current source-limit 512 slice also reached zero remaining size
  winners. Both larger upstream slices now fail if newly generated candidates
  create a size-winning backlog without explicit promotion or investigation.

- Extended the Brotli static-dictionary candidate report with an optional
  upstream-source mode. When a local Brotli `common/` checkout is supplied with
  `--source-limit`, the report merges bounded official dictionary raw words into
  the anchor-derived candidate pool and records source-limit / anchor / upstream
  raw-word counts, creating a controlled path toward larger generated imports.

- Added transform-kind and copy-length summaries to the Brotli candidate report,
  so anchor and upstream candidate artifacts expose the distribution of affix,
  uppercase, omit-last, and length buckets before selecting the next import
  slice.

- Added a portable upstream-mode smoke for the Brotli candidate report. The
  smoke builds a tiny temporary `common/dictionary_inc.h` fixture, proves
  upstream raw words are merged into the candidate pool, and now retains the
  generated upstream candidate JSON/Markdown artifacts so this import path is
  both tested and visible in dashboard review without depending on a local
  checkout path.

- Added `run-br-static-dictionary-node-probe-upstream`, completing the portable
  upstream-candidate chain. The fixture-derived upstream candidates are now
  compressed by Node and decoded by Vort, with retained JSON/Markdown probe
  artifacts proving the generated import path remains executable end to end.

- Added opt-in `upstream80` candidate and Node-probe steps for local Brotli
  checkouts. With `-- --brotli-common-dir <path>`, the source-limit 80 candidate
  pool produced 775 generated candidates and the Node/Vort probe accepted all
  775 frames locally, giving the larger official-dictionary slice a reproducible
  retained artifact path.

- Added the next opt-in `upstream128` slice for local Brotli checkouts. The
  source-limit 128 candidate pool produced 1063 generated candidates locally and
  the Node/Vort probe accepted all 1063 frames, extending the reproducible
  upstream import evidence beyond the first 80 raw dictionary words.

- Added the opt-in `upstream256` slice for local Brotli checkouts. The
  source-limit 256 candidate pool produced 1831 generated candidates locally and
  the Node/Vort probe accepted all 1831 frames, further expanding generated
  upstream import evidence while keeping the larger sweep out of default smoke.

- Added the opt-in `upstream512` slice for local Brotli checkouts. The
  source-limit 512 candidate pool produced 3367 generated candidates locally and
  the Node/Vort probe accepted all 3367 frames, doubling the covered official
  dictionary prefix while keeping the long-running sweep explicit.

- Added a lightweight opt-in `upstream1024` candidate-report slice for local
  Brotli checkouts. The source-limit 1024 report produced 6426 generated
  candidates locally, exposing the next official-dictionary prefix distribution
  without immediately requiring the much longer Node/Vort probe.

- Added `--start-index` support to the Brotli Node probe and the first five
  opt-in upstream1024 probe windows (`0-1024`, `1024-2048`, `2048-3072`,
  `3072-4096`, and `4096-5120`). This lets large upstream candidate reports be
  validated in bounded chunks instead of requiring one very long all-candidate
  probe.

- Promoted the first upstream1024 window failures into decoder coverage. The
  `5120-6144` probe exposed seven leading-space 5-byte words (` first`,
  ` video`, ` light`, ` world`, ` media`, ` white`, and ` close`). Node encodes
  those concrete frames as one literal space plus identity dictionary words, so
  the actual source tuples (`first`, `video`, `light`, `world`, `media`,
  `white`, `close`) are now in the static dictionary table with source anchors
  and leading-space Node differential cases.

- Added the upstream1024 `5120-6144` Node/Vort probe window to `build.zig`,
  dashboard producer metadata, required-artifact metadata, and validation JSON
  docs. The window now has the same opt-in artifact path as earlier 1024-row
  probe slices instead of requiring a one-off script invocation.

- Probed and promoted the upstream1024 final `6144-tail` Node/Vort window. The
  tail contains the remaining 275 generated candidates, and the formal gate now
  requires both Vort decode success and no compressed-size winners so future
  upstream1024 candidate drift is visible.

- Started the upstream2048 Brotli static-dictionary expansion from the first
  incremental 1024-row probe. The first uncovered Node frame was ` money`, which
  again used a literal leading space plus the identity source tuple `money`; that
  tuple is now anchored and covered by both unit and CLI differential tests.

- Continued the upstream2048 tail probe and promoted the first five 6-byte
  identity-source misses (`&quot;`, `domain`, `common`, `master`, and `banner`).
  Their direct and leading-space Node frames now keep the minimal static
  dictionary aligned with actual encoder output while the full dictionary import
  remains future work.

- Backfilled the upstream2048 insertion-window gap that appeared before the old
  upstream1024 tail boundary. The window produced 36 leading-space 5-byte
  identity-source misses (`black` through `again` with sparse official word
  indexes); these Node frames now have source anchors, required coverage, CLI
  differential cases, and direct unit coverage.

- Added opt-in upstream2048 candidate-report and Node/Vort probe build steps,
  plus dashboard producer/category metadata and validation JSON docs. The
  incremental windows start at candidate index 6137, where source-limit 2048
  first diverges from the upstream1024 candidate ordering, and cover through the
  current 12461-candidate tail with no Vort failures or size winners.

- Started the upstream4096 Brotli static-dictionary expansion. The first changed
  candidate window begins at index 12223 and exposed 126 additional 6-byte
  identity source words; their observed Node frames are now pinned in unit
  coverage while source anchors keep the imported subset tied to upstream data.

- Continued upstream4096 with the next 1024-row candidate window starting at
  index 13247. The Node probe exposed 117 more actual identity source tuples,
  including 7-byte alternatives selected for some 6-byte transformed payloads;
  those observed frames are now pinned by unit coverage and source anchors.

- Continued upstream4096 again with the 14271-15295 candidate window. The Node
  probe exposed 104 additional actual identity source tuples, mostly 6-byte
  leading-space payloads plus a few 7-byte alternatives; these are now captured
  in the static dictionary subset and unit-frame coverage.

- Continued upstream4096 with the 15295-16319 candidate window. The probe
  exposed 125 unique actual identity tuples, including CJK/non-ASCII 6-byte
  dictionary words and a few shorter alternate identities selected by Node; the
  observed frames now extend the static dictionary subset and unit coverage.

- Continued upstream4096 with the 16319-17343 candidate window. The probe
  exposed another 125 actual identity tuples dominated by CJK 6-byte dictionary
  words; these observed frames now extend the source-anchored subset and unit
  coverage.

- Continued upstream4096 with the 17343-18367 candidate window. The probe
  exposed 110 more actual identity tuples in the same CJK-heavy 6-byte slice,
  and those observed frames are now covered by source anchors and unit tests.

- Continued upstream4096 with the 18367-19391 candidate window. The probe
  exposed another 110 actual identity tuples from the CJK-heavy 6-byte range;
  these observed frames are now source-anchored and covered by unit tests.

- Continued upstream4096 with the 19391-20415 candidate window. The probe
  exposed 119 additional actual identity tuples in the CJK-heavy 6-byte range;
  their observed Node frames are now source-anchored and unit-tested.

- Continued upstream4096 with the 20415-21439 candidate window. The probe
  exposed 90 more actual identity tuples as the source-limit 4096 slice moves
  from CJK dictionary entries into Latin/Spanish words; the observed frames are
  now source-anchored and unit-tested.

- Continued upstream4096 with the 21439-22463 candidate window. The probe
  exposed 87 actual identity tuples spanning Latin/Spanish, Russian, and Hindi
  6-byte dictionary entries; the observed frames are now source-anchored and
  unit-tested.

- Continued upstream4096 with the 22463-23487 candidate window. The probe
  exposed 69 unique actual identity tuples, covering late Arabic 6-byte words
  and the first early 7-byte identity entries in this larger source slice.

- Added opt-in upstream4096 candidate-report and Node/Vort probe build steps,
  plus dashboard producer/category metadata and validation JSON docs. The formal
  windows start at candidate index 12223, where source-limit 4096 first diverges
  from the upstream2048 candidate ordering, and cover through the current
  23494-candidate tail with no Vort failures or size winners.

- Ran the full generated-candidate Node probe and resolved its remaining five
  failures by adding the shared ` numbers` identity tuple. The full probe now
  has a concrete source row for Node frames that encode ` numbers`, ` numbers `,
  `  numbers`, and ` numbers.` through the same static dictionary address.

- Started the upstream8192 Brotli static-dictionary expansion at the first
  changed candidate window (`23076..24100`). The Node probe exposed 156 actual
  identity tuples, mostly 7-byte English dictionary words plus several 8-byte
  identity alternatives selected for affix-equivalent payloads; all 506 observed
  failing frames are now pinned by source anchors and unit coverage.

- Continued upstream8192 with the next 1024-row candidate window starting at
  index 24100. The probe exposed 101 actual identity tuples, mostly 7-byte
  English/markup words plus a handful of 8-byte identity alternatives selected
  by Node for affix-equivalent payloads; the original 356 failing frames plus
  reindexed-tail frames are source-anchored and unit-tested.

- Continued upstream8192 with the 25124-26148 candidate window. The probe
  exposed 89 actual identity tuples, dominated by 7-byte English and markup
  words plus a few alternate-length identities selected by Node; the observed
  failing frames are source-anchored and unit-tested.

- Continued upstream8192 with the 26148-27172 candidate window. The probe exposed 81 actual identity tuples, mostly 7-byte English/markup words
  plus a few 8-byte alternates selected by Node for transformed payloads; the
  initial 304 failing frames and reindexed-tail frames are source-anchored and
  unit-tested.

- Continued upstream8192 with the 27172-28196 candidate window. The probe exposed 94 actual identity tuples, primarily 7-byte dictionary
  words plus a couple of 8-byte alternates selected by Node; the initial 365
  failing frames and reindexed-tail frames are source-anchored and unit-tested.

- Continued upstream8192 with the 28196-29220 candidate window. The probe exposed 79 actual identity tuples, mostly 7-byte words with one
  8-byte alternate selected by Node; the initial 220 failing frames and
  reindexed-tail frames are source-anchored and unit-tested.

- Continued upstream8192 with the 29220-30244 candidate window. The initial
  probe exposed 69 actual identity tuples, almost all 7-byte words plus
  one 8-byte alternate selected by Node; the observed failing frames are
  source-anchored and unit-tested.

- Continued upstream8192 with the 30244-31268 candidate window. The initial
  probe and reindexed tail exposed 70 actual identity tuples: 67 direct
  7-byte words and three alternate 5-, 6-, and 8-byte addresses selected by
  Node. All 138 unique observed failing frames are source-anchored and
  unit-tested; the reindexed 1024-row window now has no Vort failures.

- Continued upstream8192 with the 31268-32292 candidate window. The initial
  probe and reindexed tail exposed 65 actual identity tuples: 61 direct
  7-byte words and four alternate 5-, 6-, and 8-byte addresses selected by
  Node. All 124 unique observed failing frames are source-anchored and
  unit-tested; the reindexed 1024-row window now has no Vort failures. Static
  dictionary Markdown reports now render embedded control bytes as visible
  escapes, so CRLF-bearing dictionary words remain valid single table rows.

- Continued upstream8192 with the 32292-33316 candidate window. The initial
  probe and reindexed tail exposed 73 direct 7-byte identity tuples and 145
  unique failing Node frames; all observed addresses are source-anchored and
  unit-tested, and the reindexed 1024-row window now has no Vort failures.

- Continued upstream8192 with the 33316-34340 candidate window. The initial
  probe and reindexed tail exposed 75 direct identity tuples (72 7-byte and
  three 8-byte words) and 153 unique failing Node frames; all observed
  addresses are source-anchored and unit-tested, and the reindexed 1024-row
  window now has no Vort failures.

- Continued upstream8192 with the 34340-35364 candidate window. The initial
  probe and reindexed tail exposed 136 actual addresses: 127 direct 8-byte
  identity tuples and nine alternate 9-byte identity/omit-last-one tuples
  selected by Node. All 501 unique failing frames are source-anchored and
  unit-tested, and the reindexed 1024-row window now has no Vort failures.

- Restored dashboard producer completeness for existing exploratory artifacts
  without adding any new compression-format scope. `dashboard_producers.json`
  now records reproducible fallback producer commands for manual Brotli
  upstream8192/static-dictionary and alternate dashboard-index artifacts, and
  exact producer metadata for the optional Snappy report CSV. The current
  `zig-out` dashboard strict run now reports zero missing producer steps and an
  aggregate healthy validation state while keeping Snappy classified as benchmark
  evidence.

- Tightened aggregate dashboard validation health for existing validation
  artifacts without adding new compression-format scope. Native fuzz corpus,
  PNG scratch, zlib relaxed compatibility, and native allocation dashboards now
  participate directly in `validation_healthy`, each has fine-grained missing
  and failed unhealthy reasons, and `dashboard_strict_smoke.py` exercises all 53
  strict-validation-health reasons with isolated fixtures.

- Completed the dashboard health-field coverage audit for current retained
  artifacts. `native_tier_range_healthy` now participates in aggregate
  `validation_healthy`, has missing/failed strict-validation reasons, and the
  schema manifest now leaves no top-level `*_healthy` dashboard field outside the
  validation formula or its own boolean formula. The strict smoke covers 55
  validation-health reasons with isolated fixtures.

- Tightened native tier range direct strict-smoke coverage for row-level CSV and
  summary-vs-CSV drift. The native-tier mode now has isolated negative fixtures
  for missing/duplicate/unknown `(source, fixture, tier)` pairs, positive row,
  shape, throughput formula checks, and each summary mismatch counter for rows,
  fixtures, tiers, paths, index totals, and minimum range/full-input throughput.

- Tightened native tier corpus-discovery strict-smoke coverage with isolated
  negative fixtures for `ok`, source-mode, candidate/source/selected counts,
  malformed selected cases, CSV path, missing-reason, summary fixture, CSV
  fixture, and CSV byte drift. Discovery health now has direct evidence for the
  report/summary/CSV linkage instead of relying only on a byte mismatch smoke.

- Tightened dashboard strict-smoke self-health by adding isolated fixtures for
  JSON count drift, unmatched check rows, validation-reason row loss, missing
  requirement deltas, missing-mode count drift, and retained Markdown
  missing/unmatched rows. `dashboard_strict_healthy` now also requires zero
  requirement deltas and at least one retained validation-reason row.

- Tightened dashboard-configuration strict-smoke direct drift coverage for all
  retained meta-smoke artifact families: config index, config negative, category
  negative, producers-required, and producers-negative. Isolated fixtures now
  fail aggregate health for `ok` drift, count mismatches, unmatched rows, and
  required-smoke-gate count loss before `dashboard_configuration_healthy` can
  pass.

- Tightened validation JSON strict-smoke direct drift coverage for schema lists,
  observed/unchecked schema accounting, JSON artifact inventory counts, manifest
  validation floors, CLI success/failure expectations, report/corrupt rows, and
  docs-negative `ok`/count loss. These fixtures keep validation JSON health from
  relying only on broad parse/missing-schema failures.

- Tightened Brotli static-dictionary strict-smoke direct drift coverage for the
  existing candidate, upstream, Node probe, source-audit, negative-smoke, and
  retained report artifacts without adding new compression-format scope. The
  strict validation gate now has isolated fixtures for candidate/upstream count
  drift, Markdown summary/sample/row drift, Node decode-count drift, audit
  anchor loss, negative-smoke count drift, report entry/category/matrix/CSV
  mismatches, duplicate JSON entries, and report Markdown/negative-smoke drift.

- Tightened LZ4/Zstd native stream summary strict-smoke direct drift coverage for
  existing retained summary artifacts without adding codec scope. The strict
  validation gate now isolates every positive floor in the summary health formula:
  frame, skippable-frame, checksum-frame, dictionary-id, content-size,
  declared-content, block, raw-block, compressed-byte, payload-byte, and
  skippable-payload coverage, plus the LZ4-only block-checksum floor.

- Tightened zstd comparison strict-smoke direct drift coverage for existing
  compare, standard-suite, and block-sweep artifacts without changing comparison
  scope. The strict validation gate now isolates failed gate `ok` flags,
  zero-data-row floors that still have internally consistent CSV/Markdown rows,
  missing Markdown companions, and block-sweep path/block-length metadata drift.

- Tightened native codec probe strict-smoke direct drift coverage for existing
  LZ4/Zstd probe dashboard artifacts without adding codec scope. The strict
  validation gate now isolates top-level `ok` drift, per-probe `ok` and timeout
  drift, coverage row `ok` and case-sum drift, total-case floors, key capability
  case floors, and Zstd frame/dictionary probe case floors.

- Tightened native fuzz corpus strict-smoke direct drift coverage for the
  existing retained native fuzz report and coverage-smoke artifacts without
  adding codec scope. The strict validation gate now isolates report `ok` and
  mode drift, exact-error and summary-row floors, mode/error summary mismatch,
  missing, and duplicate rows, plus coverage `ok` and mode/error requirement
  floors before native fuzz coverage can pass.

- Promoted the existing Snappy report CSV from dashboard inventory metadata to
  aggregate validation health without adding new compression-format scope. The
  dashboard now parses `vort-snappy-report.csv`, validates the 20-row
  raw/framed/reusable matrix, positive timing, repetitive compression, and
  reusable-size stability, and exposes missing/failed Snappy report reasons in
  strict-validation-health. `run-validation-json-dashboard` and
  `run-dashboard-index` now depend on `run-snappy-report-gate` so clean
  dashboards retain the CSV before enforcing aggregate health.

- Promoted the existing checksum benchmark CSV into aggregate dashboard
  validation health. The dashboard now parses `vort-checksum-bench.csv`, checks
  the 21 expected Adler/CRC32/CRC32C algorithm rows, workload size/iteration
  consistency, positive throughput rows, and CRC32/CRC32C digest-mix agreement;
  strict-validation-health now includes missing/failed checksum benchmark
  reasons, and validation/dashboard steps depend on the checksum bench gate so
  clean dashboards retain the CSV before enforcing aggregate health.

- Promoted the existing chunk cursor microbenchmark CSV into aggregate dashboard
  validation health. The dashboard now parses `vort-chunk-cursor-bench.csv`,
  validates the 8-row read/copy and current/skip-empty kernel matrix, checks
  chunk shape metadata and positive timing rows, and exposes missing/failed
  chunk-cursor benchmark reasons in strict-validation-health. Validation JSON
  dashboard generation now depends on `run-chunk-cursor-bench-gate` so clean
  dashboard runs retain the CSV before aggregate health is enforced.

- Promoted the existing deflate match-copy microbenchmark CSV into aggregate
  dashboard validation health. The dashboard now parses
  `vort-deflate-match-copy-bench.csv`, validates the 28-row case/kernel matrix,
  class coverage, and positive timing/checksum rows, and exposes missing/failed
  match-copy benchmark reasons in strict-validation-health. Validation JSON
  dashboard generation now depends on `run-deflate-match-copy-bench-gate` so
  clean dashboard runs retain the CSV before aggregate health is enforced.

- Promoted the existing deflate Huffman table-build microbenchmark CSV into
  aggregate dashboard validation health. The dashboard now parses
  `vort-deflate-huffman-build-bench.csv`, validates the 14-row case/build
  matrix, lookup-bit metadata, and positive timing/checksum rows, and exposes
  missing/failed Huffman-build benchmark reasons in strict-validation-health.
  Validation JSON dashboard generation now depends on
  `run-deflate-huffman-build-bench-gate` so clean dashboard runs retain the CSV
  before aggregate health is enforced.

- Promoted the existing deflate Huffman lookup microbenchmark CSV into
  aggregate dashboard validation health. The dashboard now parses
  `vort-deflate-huffman-lookup-bench.csv`, validates the 21-row case/decoder
  matrix, lookup-bit metadata, and positive symbol-throughput/checksum rows, and
  exposes missing/failed Huffman-lookup benchmark reasons in
  strict-validation-health. Validation JSON dashboard generation now depends on
  `run-deflate-huffman-lookup-bench-gate` so clean dashboard runs retain the CSV
  before aggregate health is enforced.

- Promoted the existing deflate chunked-Huffman microbenchmark CSV into
  aggregate dashboard validation health. The dashboard now parses
  `vort-deflate-chunked-huffman-bench.csv`, validates the 57-row case/reader
  matrix, decoder/lookup/chunk-shape metadata, buffered zero-chunk rows, and
  positive symbol-throughput/checksum rows, and exposes missing/failed
  chunked-Huffman benchmark reasons in strict-validation-health. Validation JSON
  dashboard generation now depends on `run-deflate-chunked-huffman-bench-gate`
  so clean dashboard runs retain the CSV before aggregate health is enforced.
- Promoted `run-deflate-extra-bits-bench-gate` into dashboard aggregate validation health: the dashboard now checks the 105-row extra-bit CSV shape, positive timing fields, expected case/reader/kernel coverage, and paired checksum equivalence for staged/current and fused/current rows, with strict missing/failed reasons plus schema/docs smoke coverage.
- Promoted `run-dictionary-decode-bench-gate` into dashboard aggregate validation health: the dashboard now checks the 18 preset-dictionary decode rows across raw/zlib, dynamic/fixed/best encoders, alloc/exact/into modes, positive throughput fields, and output-size accounting, with strict missing/failed reasons plus schema/docs smoke coverage.
- Promoted `run-png-scanline-bench-gate` into dashboard aggregate validation health: the dashboard now checks the 30 PNG scanline reconstruction rows across none/sub/up/average/paeth filters and 1/2/3/4/6/8 byte-per-pixel variants, positive timing fields, and input/output byte accounting, with strict missing/failed reasons plus schema/docs smoke coverage.
- Promoted `run-chunked-zlib-bench-report-gate` into dashboard aggregate validation health: the dashboard now checks the 8 repeat3 contiguous/join/direct/exact chunked zlib rows, expected PNG-like case shapes and direct strategies, positive throughput/ratio fields, chunk-count accounting including empty-chunk layouts, and ratio consistency, with strict missing/failed reasons plus schema/docs smoke coverage.
- Promoted `run-png-streaming-zlib-bench-report-gate` into dashboard aggregate validation health: the dashboard now checks the 10 repeat3 PNG streaming zlib rows, expected filter/pattern geometry, positive contiguous/chunked throughput fields, row/image byte accounting, and chunked-over-contiguous ratio consistency, with strict missing/failed reasons plus schema/docs smoke coverage.
- Promoted `run-deflate-dynamic-decode-profile-gate` into dashboard aggregate validation health: the dashboard now checks the required README/roadmap/chunked-window dynamic profile rows, histogram and lookup consistency, match-class accounting, and the chunked-window match-heavy/non-overlap invariants, with strict missing/failed reasons plus schema/docs smoke coverage.
- Promoted `run-native-library-bench-gate` into dashboard aggregate validation health: the dashboard now checks the 93-row native LZ4/Zstd public-library benchmark matrix, positive timing/throughput fields, single iteration count, computed throughput consistency, dictionary/chain/budget/sequence size-improvement checks, and compressed lib-generated/decode rows, with producer/category registration plus strict missing/failed reasons and schema/docs smoke coverage.
- Tightened native tier range dashboard health by parsing the three required CSV artifacts (`vort-native-tier-range-bench.csv`, `vort-native-tier-range-files-bench.csv`, and `vort-native-tier-range-corpus-bench.csv`) in addition to their gate JSON summaries; aggregate health now checks row presence, tier/block shape, positive timing fields, range bounds, and recomputed range/full-input throughput consistency.
- Tightened zlib relaxed dashboard health by requiring `vort-zlib-relaxed-report-gate.json` beside the report JSON; aggregate health now checks gate presence, `ok=true`, all 11 gate checks passing, and no failed gate checks before relaxed zlib/gzip compatibility is considered healthy.
- Tightened deflate decode-stage dashboard health by parsing `vort-deflate-decode-stage-report.csv` beside the JSON report; aggregate health now checks the 10 built-in timing rows, positive decode/checksum throughput fields, fixed/dynamic/stored header shapes, and missing-case drift before decode-stage health can pass.
- Promoted the existing compression level CSV/Markdown report into dashboard aggregate validation health. The dashboard now parses `vort-level-report.csv`, validates the 48-row built-in case/level/strategy matrix, token accounting, recomputed ratio fields, round-trip CRC evidence, and Markdown best-row summary drift before `validation_healthy` can pass. Strict validation now exposes missing/failed level-report reasons, and validation JSON dashboard generation depends on `run-level-report-dashboard` so clean dashboard runs retain both report artifacts.
- Tightened Brotli static-dictionary dashboard health by consuming the retained `vort-br-static-dictionary-report.{csv,json,md}` and `vort-br-static-dictionary-report-negative-smoke.json` artifacts in addition to the candidate/node/source-audit smokes. Aggregate health now cross-checks JSON entry counts, transform/length/category/matrix totals, CSV row identity, Markdown summary drift, and report negative-smoke matches before static-dictionary coverage can pass.
- Promoted the existing dynamic-plan CSV reports into dashboard aggregate validation health. The dashboard now parses both `vort-dynamic-plan-report.csv` and `vort-dynamic-plan-builtins-report.csv`, validates the README/roadmap plus built-in path coverage, token accounting, histogram widths, recomputed ratio fields, bit-boundary slack, and zlib-wrapper byte accounting, with strict missing/failed reasons plus schema/docs smoke coverage.
- Tightened zstd compare dashboard health by cross-checking the retained
  `vort-zstd-compare*.csv` and `vort-zstd-compare*.md` companions against the
  three gate JSON summaries. Aggregate health now verifies compare/standard
  TOTAL rows, block-sweep row counts and best-block metrics, Markdown metadata
  and summary snippets, and the validation/dashboard build steps now depend on
  the compare gates so clean dashboard runs retain all companion artifacts.
- Tightened native allocation dashboard health by consuming the retained
  `vort-native-allocation-report.md` companion alongside the report, smoke, and
  negative-smoke JSON. Aggregate health now verifies report row/count balance,
  allocation/free byte balance, zero-allocation and budget smoke rows against
  measured report rows, negative-smoke matches, and Markdown table drift before
  native allocation coverage can pass.
- Tightened native codec probe dashboard health by requiring the retained
  `vort-native-codec-probes.md` companion beside the JSON summary. Aggregate
  health now cross-checks Markdown coverage, capability, and executable rows
  against the JSON probe data, verifies coverage case totals against total
  cases, and exposes Markdown drift counters in the validation dashboard.
- Tightened native fuzz corpus dashboard health by requiring the retained
  `vort-native-fuzz-corpus.md` companion beside the JSON report and coverage
  smoke. Aggregate health now cross-checks Markdown mode/error/sample rows,
  report item counts, accepted/rejected/matched totals, and coverage-smoke
  matched mode/error requirements before native fuzz coverage can pass.
- Tightened PNG scratch dashboard health by requiring the retained
  `vort-png-scratch-report.md` companion beside the JSON report. Aggregate
  health now cross-checks every Markdown row against JSON scratch metrics,
  verifies per-row scratch/total arithmetic, and exposes row-consistency plus
  Markdown drift counters before PNG scratch coverage can pass.
- Tightened zlib relaxed dashboard health by requiring the retained
  `vort-zlib-relaxed-report.md` companion beside the report and gate JSON.
  Aggregate health now cross-checks Markdown metric rows and gate check names
  against the JSON report, and exposes gate/report plus Markdown drift counters
  before relaxed wrapper coverage can pass.
- Tightened sidecar corrupt-payload dashboard health by requiring the retained
  `vort-sidecar-corrupt-smoke.md` companion beside the JSON report. Aggregate
  health now cross-checks every Markdown row against JSON `items` case names,
  metadata/full rejection booleans, error names, and stream/sidecar byte counts,
  and exposes item-count plus Markdown drift counters before corrupt-payload
  validation coverage can pass.
- Tightened deflate wrapper fuzz corpus dashboard health by requiring the
  retained `vort-deflate-wrapper-fuzz-corpus.md` companion beside the JSON
  report and coverage smoke. Aggregate health now cross-checks Markdown
  metadata, mode/error summaries, and sample rows against the JSON corpus
  report, verifies coverage-smoke matched requirements, and exposes report,
  coverage, and Markdown drift counters before wrapper fuzz coverage can pass.
- Tightened header-inspect dashboard health by requiring the retained
  `vort-header-inspect-smoke.md` companion beside the JSON smoke. Aggregate
  health now cross-checks JSON row totals for successes, negatives, command and
  workflow coverage, required/help workflows, and Markdown format/command/
  workflow/success/failure rows before header-inspect coverage can pass.
- Tightened decode-stage dashboard health by requiring the retained
  `vort-deflate-decode-stage-report.md` companion beside the JSON and CSV
  reports. Aggregate health now cross-checks timing/error item counts,
  malformed/error-path Markdown rows, and the retained Markdown table snippets
  before decode-stage coverage can pass.
- Tightened dashboard strict smoke dashboard health by requiring the retained
  `vort-dashboard-strict-smoke.md` companion beside the JSON summary.
  Aggregate health now cross-checks strict check rows, mode counts, expected
  mode requirements, validation-unhealthy reason rows, and Markdown snippets
  before dashboard-strict coverage can pass.
- Tightened Huffman length oracle dashboard health by requiring the retained
  `vort-huffman-length-report.md` table rows to match every CSV oracle row.
  Aggregate health now exposes Markdown case-row matched/unmatched counters in
  addition to the existing summary counters before Huffman length coverage can
  pass.
- Tightened compression level dashboard health by requiring the retained
  `vort-level-report.md` detail table to match every CSV level/strategy row.
  Aggregate health now exposes Markdown detail-row matched/unmatched counters
  alongside the existing best-row summary checks before level-report coverage
  can pass.
- Tightened chunked zlib dashboard health by requiring the retained
  `vort-chunked-zlib-bench-report.md` rows to match the repeat3 CSV gate rows.
  The dashboard generation step now writes the CSV/Markdown pair together, and
  aggregate health exposes Markdown matched/unmatched counters before chunked
  zlib benchmark coverage can pass.
- Tightened zstd compare dashboard health by requiring the retained
  `vort-zstd-compare*.md` tables to match every CSV compare/standard/block-sweep
  row, not just metadata and TOTAL snippets. Aggregate health now exposes
  Markdown detail-row matched/unmatched counters before zstd compare coverage
  can pass.
- Tightened Brotli static-dictionary candidate dashboard health by requiring
  the retained `vort-br-static-dictionary-candidates.md` summary and sampled
  candidate rows to match the canonical JSON report. Aggregate health now
  exposes candidate Markdown summary/sample matched-unmatched counters before
  static-dictionary core coverage can pass.
- Tightened Brotli static-dictionary node-probe dashboard health by requiring
  the retained `vort-br-static-dictionary-node-probe.md` summary and candidate
  rows to match the canonical JSON probe. Aggregate health now exposes node
  Markdown summary/row matched-unmatched counters before static-dictionary core
  coverage can pass.
- Tightened Brotli static-dictionary report Markdown dashboard health by requiring
  the retained `vort-br-static-dictionary-report.md` matrix and entry rows to
  match the canonical JSON report. Aggregate health now exposes report
  Markdown matrix/entry matched-unmatched counters before report coverage can
  pass.
- Tightened Brotli static-dictionary upstream candidate dashboard health by
  requiring the retained `vort-br-static-dictionary-candidates-upstream.json`
  and Markdown companion to match the upstream smoke summary. Core static
  dictionary health now exposes upstream report and Markdown matched-unmatched
  counters before coverage can pass.
- Tightened native stream summary dashboard health by checking retained LZ4
  and Zstd summary JSON for block-count consistency, declared-content slack,
  and impossible metadata/checksum frame overflows. Dashboard health now exposes
  mismatch/slack/overflow counters before native summary coverage can pass.

- Added direct dashboard strict-smoke drift coverage for LZ4/Zstd native stream
  summaries. The strict validation gate now exercises block-count mismatches,
  declared payload slack, metadata/checksum-frame overflows, and LZ4
  block-checksum overflow so native stream summary health cannot rely only on
  aggregate undercovered fixtures.
- Tightened LZ4/Zstd native stream summary strict-smoke direct overflow
  coverage for content-size metadata. The strict validation gate now isolates
  impossible content-size frame counts separately from dictionary metadata
  overflow while preserving checksum and block-checksum overflow counters.
- Tightened dashboard configuration health by requiring config, category,
  required-producer, and producer-negative smoke row counts to match their
  declared counts and by exposing count-mismatch/row-unmatched counters in the
  dashboard manifest and Markdown summary.
- Tightened validation-JSON dashboard health by requiring checked schemas to
  be unique, CLI failure smoke to retain a recoverability hint, and docs-negative
  smoke rows to match their declared case count. Dashboard health now exposes
  schema duplicate and docs-negative row/count mismatch counters.
- Tightened Python zlib differential dashboard health by deriving expected
  file-hex, dictionary, malformed, and CLI outcome floors from the retained
  summary. Dashboard health now exposes mismatch and shortfall counters before
  the differential smoke can pass.
- Tightened native tier range dashboard health by cross-checking each retained
  summary JSON against its CSV companion for source cardinality, row/fixture/tier
  coverage, CSV path, per-tier stream/index totals, and per-tier minimum range
  and full-input throughput. Dashboard health now exposes summary-vs-CSV mismatch
  counters before native tier range coverage can pass.
- Tightened native tier corpus discovery dashboard health by cross-checking the
  retained discovery JSON selected labels and byte sizes against the standard
  corpus range summary and CSV companion. Dashboard health now exposes discovery
  mismatch counters before corpus-discovery coverage can pass.
- Tightened Snappy benchmark dashboard health by recomputing ratio and encode/decode
  throughput from the retained CSV rows and by requiring reusable raw/framed
  outputs to preserve both size and checksum per fixture. Dashboard health now
  exposes ratio, throughput, and reusable-checksum counters before Snappy coverage
  can pass.
- Tightened checksum benchmark dashboard health by recomputing throughput from
  bytes, iterations, and elapsed time for every retained CSV row. Dashboard
  health now exposes throughput-row counters before checksum benchmark coverage
  can pass.
- Tightened chunk cursor benchmark dashboard health by recomputing bytes/s and
  MiB/s from payload bytes, iterations, and elapsed time, and by requiring the
  current and skip-empty kernels to preserve per-case checksums. Dashboard health
  now exposes throughput-row and checksum-match counters before chunk cursor
  coverage can pass.
- Tightened deflate match-copy benchmark dashboard health by validating expected
  class labels, recomputing output bytes and throughput from each CSV row, and
  requiring all kernels for each case to preserve checksums. Dashboard health now
  exposes output-byte, throughput, and checksum-match counters before match-copy
  coverage can pass.
- Tightened deflate Huffman build benchmark dashboard health by recomputing
  builds/s from iterations and elapsed time and by requiring each case's table
  builder variants to retain distinct non-zero checksums. Dashboard health now
  exposes throughput-row and checksum-variant counters before Huffman build
  coverage can pass.
- Tightened deflate Huffman lookup benchmark dashboard health by recomputing
  symbols/s and MiB/s from each CSV row and by requiring all decoder variants for
  each case to preserve the same non-zero checksum. Dashboard health now exposes
  throughput-row and checksum-match counters before Huffman lookup coverage can
  pass.
- Tightened deflate chunked Huffman benchmark dashboard health by recomputing
  symbols/s and MiB/s from each CSV row, requiring chunk counts to match the
  per-iteration compressed input size, and requiring all reader variants for each
  case to preserve the same non-zero checksum. Dashboard health now exposes
  chunk-count, throughput-row, and checksum-match counters before chunked Huffman
  coverage can pass.
- Tightened deflate extra-bit benchmark dashboard health by recomputing reads/s
  and MiB/s from each CSV row and by requiring every case's reader/kernel rows to
  preserve a shared non-zero checksum. Dashboard health now exposes
  throughput-row and checksum-match counters before extra-bit coverage can pass.
- Tightened dictionary decode benchmark dashboard health by recomputing decode
  MiB/s from output bytes and elapsed time and by requiring each payload family
  to keep a shared non-zero checksum across raw/zlib, encoder, and allocation
  modes. Dashboard health now exposes throughput-row and checksum-payload
  counters before dictionary decode coverage can pass.
- Tightened PNG scanline benchmark dashboard health by recomputing output MiB/s
  from output bytes and elapsed time and by requiring each byte-per-pixel group
  to keep a shared non-zero checksum across all filter stages. Dashboard health
  now exposes throughput-row and checksum-bpp counters before scanline coverage
  can pass.
- Tightened PNG streaming zlib benchmark dashboard health by requiring reported
  chunk counts to match the zlib payload length and chunk size. Dashboard health
  now exposes a chunk-count counter before streaming zlib benchmark coverage can
  pass.
- Tightened deflate dynamic decode profile dashboard health by recomputing lookup
  coverage, fast-miss, match-class byte, and per-match/per-byte extra-bit ratios
  from the CSV counters. Dashboard health now exposes a ratio-row counter before
  dynamic decode profile coverage can pass.
- Tightened native allocation dashboard health by requiring zero-allocation and
  budget smoke rows to classify every report case exactly once, with no overlap,
  missing report cases, or extra smoke-only cases. Dashboard health now exposes
  smoke-classification counters before native allocation coverage can pass.
- Tightened native summary error dashboard health by recomputing aggregate error,
  phase, per-codec count, and offset-range summaries from the retained case rows.
  Dashboard health now exposes aggregate-drift counters before native summary
  malformed-stream coverage can pass.
- Tightened native stream summary dashboard health by requiring declared content
  bytes to match decoded payload bytes exactly for retained LZ4 and Zstd
  summaries. Schema relations now reject declared/payload slack before native
  stream summary coverage can pass.
- Tightened native summary error negative-smoke dashboard health by requiring
  retained negative rows to match the declared case count and to be both matched
  and expected-failure rows. Dashboard health now exposes negative row/count
  drift counters before malformed-summary guardrail coverage can pass.

- Added direct dashboard strict-smoke drift coverage for native summary error
  dashboards. The strict validation gate now exercises case/codec/error/phase
  count mismatches, codec-specific count drift, offset-range drift, missing
  required codec phases, and negative-smoke count/matched/expected-failure drift
  so native malformed-summary health cannot hide aggregate counter regressions.
- Tightened native summary error strict-smoke direct drift coverage for retained
  malformed-stream floor requirements. The strict validation gate now moves
  concrete cases between error classes while keeping aggregate counters
  internally consistent, isolating checksum and corrupt-frame floor regressions
  from the existing count-mismatch checks.
- Extended native summary error strict-smoke floor coverage to truncated-frame
  and frame-checksum phase floors. The new fixtures keep error/phase aggregates,
  codec-specific aggregates, offset ranges, and required-phase metadata
  internally consistent so these floor regressions cannot hide behind existing
  mismatch checks.
- Completed the remaining native summary error phase-floor direct coverage for
  magic, skippable-payload, frame-body, and frame phases. The strict validation
  gate now isolates every aggregate phase floor while keeping phase counts,
  codec phase counts, offset ranges, and required-phase metadata consistent.
- Tightened Brotli static-dictionary negative-smoke dashboard health by requiring
  both source-audit and report guardrail rows to match declared case counts with
  no unmatched rows. Dashboard health now exposes row/count drift counters before
  static-dictionary guardrail coverage can pass.
- Tightened native codec probe dashboard health by requiring declared
  probe/capability/coverage counts to match retained rows, probe case sums to
  match total cases, and required probe labels, coverage pairs, and capability
  keys to be present exactly once. Dashboard health now exposes row/count/key
  drift counters before native codec probe coverage can pass.
- Tightened Python zlib differential dashboard health by recomputing exact
  CLI success, expected-failure, and total outcome counts from the retained
  payload, file-transport, dictionary, dynamic, and malformed coverage counters.
  Dashboard health now exposes exact outcome mismatch counters before zlib
  differential coverage can pass.

- Added direct dashboard strict-smoke drift coverage for Python zlib differential
  health. The strict validation gate now exercises large-file payload overflow,
  file-hex count drift, CLI success/failure shortfalls, exact outcome mismatches,
  missing match-heavy/dynamic payload coverage, dictionary-encode undercoverage,
  and malformed-wrapper coverage loss so `python_zlib_diff_failed` cannot hide
  differential summary counter regressions behind its aggregate fixture.

- Tightened Python zlib differential strict-smoke direct drift coverage for the
  retained black-box differential smoke without changing compatibility scope. The
  strict validation gate now isolates top-level `ok` drift, payload and
  large-file floors, file-hex floors, dictionary and raw-dictionary encode
  floors, malformed-deflate coverage loss, and CLI success/failure floors before
  the differential summary can pass.

- Tightened zlib/gzip relaxed-wrapper dashboard health by recomputing the
  retained gate's exact and floor rules from report counters instead of trusting
  gate booleans alone. Dashboard health now exposes missing/extra gate checks,
  recomputed pass/fail counts, rule drift, exact mismatch, and floor shortfall
  counters before relaxed-wrapper compatibility coverage can pass.

- Tightened Snappy report dashboard health by exposing duplicate and unknown
  mode/case pairs plus framed-overhead parity across one-shot and reusable
  paths. Dashboard health now rejects pair drift and framed/raw size drift before
  Snappy CSV coverage can pass.

- Tightened checksum benchmark dashboard health by exposing duplicate and
  unknown algorithm rows alongside missing algorithms. Dashboard health now
  rejects checksum CSV algorithm drift before checksum benchmark coverage can
  pass.

- Tightened chunk cursor benchmark dashboard health by exposing duplicate and
  unknown `(case, kernel)` rows alongside missing pairs. Dashboard health now
  rejects chunk cursor CSV pair drift before cursor benchmark coverage can pass.

- Tightened deflate match-copy benchmark dashboard health by exposing duplicate
  and unknown `(case, kernel)` rows alongside missing pairs. Dashboard health now
  rejects match-copy CSV pair drift before benchmark coverage can pass.

- Tightened deflate Huffman build benchmark dashboard health by exposing
  duplicate and unknown `(case, build)` rows alongside missing pairs. Dashboard
  health now rejects Huffman build CSV pair drift before benchmark coverage can
  pass.

- Tightened deflate Huffman lookup benchmark dashboard health by exposing
  duplicate and unknown `(case, decoder)` rows alongside missing pairs. Dashboard
  health now rejects Huffman lookup CSV pair drift before benchmark coverage can
  pass.

- Tightened deflate chunked Huffman benchmark dashboard health by exposing
  duplicate and unknown `(case, reader)` rows alongside missing pairs. Dashboard
  health now rejects chunked Huffman CSV pair drift before benchmark coverage can
  pass.

- Tightened deflate extra-bit benchmark dashboard health by exposing duplicate
  and unknown `(case, reader, kernel)` rows alongside missing pairs. Dashboard
  health now rejects extra-bit CSV pair drift before benchmark coverage can pass.

- Tightened dictionary decode benchmark dashboard health by exposing duplicate
  and unknown `(case, format, encoder, mode)` rows alongside missing pairs.
  Dashboard health now rejects dictionary decode CSV pair drift before benchmark
  coverage can pass.

- Tightened PNG scanline benchmark dashboard health by exposing duplicate and
  unknown `(stage, bpp)` rows alongside missing pairs. Dashboard health now
  rejects PNG scanline CSV pair drift before benchmark coverage can pass.

- Tightened native library benchmark dashboard health by exposing duplicate and
  unknown `(codec, mode, case)` rows alongside missing pairs. Dashboard health
  now rejects native library CSV pair drift before benchmark coverage can pass.

- Added direct dashboard strict-smoke drift coverage for native library benchmark
  health. The strict validation gate now exercises missing/duplicate/unknown
  `(codec, mode, case)` rows plus positive-row, throughput, iteration, and
  compression-improvement mismatches so `native_library_bench_failed` coverage
  cannot hide field-level CSV drift.
- Tightened native library benchmark strict-smoke improvement coverage by
  isolating a Zstd match-budget row that no longer improves over its zero-budget
  baseline while keeping positive timing, throughput, and iteration accounting
  valid.
- Tightened native library benchmark strict-smoke improvement coverage by
  isolating a Zstd sequence-Huffman-literals row that no longer improves over
  its plain baseline while keeping positive timing, throughput, and iteration
  accounting valid.
- Tightened native library benchmark strict-smoke improvement coverage by
  isolating a compression-floor regression for the retained high-byte Zstd row.
  The new fixture keeps positive timing, throughput, and iteration accounting
  valid while forcing the row to stop compressing below its input size.
- Tightened native library benchmark strict-smoke compression coverage by
  isolating a decode-mode retained row that no longer compresses below its input
  size while keeping positive timing, throughput, and iteration accounting
  valid.
- Tightened native library benchmark strict-smoke compression coverage by
  isolating a library-generated retained row that no longer compresses below its
  input size while keeping positive timing, throughput, and iteration accounting
  valid.
- Tightened native library benchmark strict-smoke dictionary improvement
  coverage by isolating an LZ4 dictionary row that no longer improves over its
  plain baseline while leaving positive timing, throughput, and iteration
  accounting intact.
- Extended native library benchmark strict-smoke dictionary coverage to a Zstd
  trained-dictionary improvement pair. The retained row now has an isolated
  negative fixture that keeps positive timing, throughput, and iteration
  accounting valid while removing the trained-dictionary size win.
- Extended native library benchmark strict-smoke dictionary coverage to a Zstd
  dictionary-set improvement pair. The retained row now has an isolated negative
  fixture that keeps non-improvement accounting valid while removing the
  dictionary-set size win over its plain baseline.
- Extended native library benchmark strict-smoke dictionary coverage to a
  reusable LZ4 dictionary-set improvement pair. The new negative fixture keeps
  the benchmark row otherwise healthy while removing the reusable dictionary
  size win over its plain baseline.
- Extended native library benchmark strict-smoke dictionary coverage to a Zstd
  direct dictionary-set improvement pair. The fixture keeps positive timing,
  throughput, and iteration accounting healthy while removing the direct
  dictionary-set size win over its plain baseline.
- Extended native library benchmark strict-smoke dictionary coverage to a Zstd
  fallback dictionary-set improvement pair. The fixture keeps all non-improvement
  row accounting valid while removing the fallback dictionary-set size win over
  its plain baseline.
- Extended native library benchmark strict-smoke dictionary coverage to a Zstd
  chunked dictionary-set improvement pair. The fixture keeps positive timing,
  throughput, and iteration accounting healthy while removing the chunked
  dictionary-set size win over its plain baseline.
- Extended native library benchmark strict-smoke dictionary coverage to an LZ4
  chunked-append dictionary-set improvement pair. The fixture keeps the row's
  non-improvement accounting healthy while removing the append dictionary-set
  size win over its plain baseline.
- Extended native library benchmark strict-smoke dictionary coverage to a Zstd
  chunked-append-exact dictionary-set improvement pair. The fixture preserves
  positive timing, throughput, and iteration accounting while removing the exact
  append dictionary-set size win over its plain baseline.
- Extended native library benchmark strict-smoke dictionary coverage to a Zstd
  reusable-append-exact dictionary-set improvement pair. The fixture keeps the
  benchmark row otherwise healthy while removing the reusable exact append
  dictionary-set size win over its plain baseline.

- Tightened native tier range CSV dashboard health by deriving expected
  `(fixture, tier)` rows from each source's JSON summary and exposing duplicate
  and unknown source-qualified pairs alongside missing pairs. Dashboard health
  now rejects row-level native tier CSV drift before summary/CSV aggregate
  coverage can pass.

- Tightened deflate decode-stage CSV dashboard health by exposing duplicate and
  unknown `case` rows alongside missing cases. Dashboard health now rejects
  decode-stage CSV case drift before timing/header coverage can pass.

- Tightened decode-stage strict-smoke direct drift coverage for the remaining
  field-level dashboard invariants. Isolated fixtures now fail aggregate health
  for internally consistent unmatched error rows, non-positive CSV throughput,
  malformed dynamic headers, and missing fixed/dynamic/stored block-type
  coverage before broader decode-stage health can pass.

- Tightened chunked zlib benchmark dashboard health by exposing duplicate and
  unknown `case` rows alongside missing cases. Dashboard health now rejects
  chunked zlib CSV case drift before benchmark and Markdown coverage can pass.

- Tightened PNG streaming zlib benchmark dashboard health by exposing duplicate
  and unknown `case` rows alongside missing cases. Dashboard health now rejects
  PNG streaming CSV case drift before benchmark coverage can pass.

- Tightened deflate dynamic decode profile dashboard health by exposing duplicate
  required `case` rows alongside missing cases while still allowing additional
  profiling rows. Dashboard health now rejects required profile case drift before
  decode-profile coverage can pass.

- Added direct dashboard strict-smoke drift coverage for deflate dynamic decode
  profile health. The strict validation gate now exercises missing/duplicate
  required profile cases plus positive-row, histogram, lookup, match-class,
  ratio-accounting, and chunked-window-shape mismatches, so aggregate
  `deflate_dynamic_decode_profile_failed` coverage cannot hide field-level CSV
  drift.

- Tightened compression level report dashboard health by exposing duplicate and
  unknown `(case, level, strategy)` rows alongside missing pairs. Dashboard
  health now rejects level report CSV pair drift before Markdown and row
  accounting coverage can pass.

- Tightened dynamic plan dashboard health by exposing duplicate and unknown
  `(source, path)` rows alongside missing sources/paths. Dashboard health now
  rejects dynamic-plan CSV path drift before token, histogram, ratio, and wrapper
  accounting coverage can pass.

- Tightened deflate wrapper fuzz corpus dashboard health by recomputing
  `mode_counts` and `error_counts` from row-level `items`, exposing missing,
  duplicate, unknown, and mismatched summary rows. Dashboard health now rejects
  stale fuzz summary aggregates before coverage and Markdown checks can pass.

- Tightened deflate wrapper fuzz corpus strict-smoke direct drift coverage for
  existing retained wrapper fuzz artifacts without adding format scope. The
  strict validation gate now isolates report `ok` and mode drift,
  exact-error and summary-row floors, mode/error summary mismatch, missing, and
  duplicate rows, plus coverage `ok` and mode/error requirement floors before
  wrapper fuzz coverage can pass.

- Tightened native fuzz corpus dashboard health by applying the same row-level
  recomputation to native `mode_counts` and `error_counts`, exposing missing,
  duplicate, unknown, and mismatched summary rows. Dashboard health now rejects
  stale native fuzz summary aggregates before coverage and Markdown checks can
  pass.

- Tightened header inspect dashboard health by exposing duplicate successful,
  negative, command, workflow, required-workflow, and help-workflow rows, and by
  recomputing command coverage, negative error counts, missing workflows, and
  help-vs-required workflow drift. Dashboard health now rejects stale or
  duplicated header inspect aggregates before Markdown coverage can pass.

- Tightened PNG scratch dashboard health by pinning the expected scratch case
  matrix and exposing missing, duplicate, and unknown case rows. Dashboard health
  now rejects stale or drifted PNG scratch report cases before scratch accounting
  and Markdown coverage can pass.

- Tightened sidecar corrupt smoke dashboard health by exposing malformed and
  duplicate JSON item rows plus malformed, duplicate, and unknown Markdown rows.
  Dashboard health now rejects sidecar row drift before corrupt-payload coverage
  can pass.

- Tightened sidecar corrupt strict-smoke direct drift coverage for the existing
  corrupt-payload JSON/Markdown artifacts without adding format scope. The
  strict validation gate now isolates missing Markdown companions, zero-row
  report floors, Markdown row-count loss, and item metadata/full-rejection count
  drift before corrupt-payload coverage can pass.

- Tightened Huffman length oracle dashboard health by exposing blank and
  duplicate CSV case rows alongside malformed/cost checks. Dashboard health now
  rejects duplicated Huffman oracle case rows before Markdown coverage can pass.

- Tightened Huffman length strict-smoke direct drift coverage for the existing
  oracle CSV/Markdown artifacts. The strict validation gate now isolates missing
  Markdown companions, worst-gap drift, and package-merge worst-gap drift in
  addition to malformed, blank, duplicate, non-optimal, and Markdown row drift.

- Tightened compression level-report strict-smoke direct drift coverage for the
  existing CSV/Markdown artifacts. The strict validation gate now isolates a
  missing Markdown companion and non-positive row accounting without relying on
  token, ratio, roundtrip, or Markdown detail drift to catch those failures.

- Tightened dynamic-plan strict-smoke direct drift coverage for the existing
  project-file and built-in CSV artifacts. The strict validation gate now
  isolates missing source artifacts and positive-row drift before token,
  histogram, ratio, slack, or wrapper invariants are evaluated.


















- Promoted Markdown heading layouts to a hard per-artifact gate by adding
  `tools/dashboard_markdown_heading_manifest.json` and comparing every retained
  Markdown artifact against its expected heading count, first heading, and
  heading hash.

- Extended the Markdown artifact layout manifest to also pin table-row and
  separator-row counts, so dashboard health now catches retained Markdown
  reports whose table bodies disappear, duplicate, or otherwise drift while
  headings remain unchanged.

- Tightened Markdown artifact table auditing by requiring a Markdown separator
  row in every retained Markdown artifact. Dashboard health now rejects files
  that contain pipe-delimited text without a real table layout.

- Tightened Markdown artifact layout auditing by requiring every retained
  Markdown artifact to contain at least one table row. Dashboard health now
  rejects heading-only or prose-only Markdown artifacts before inventory can pass.

- Tightened Markdown artifact layout auditing by requiring the first non-empty
  line of every retained Markdown artifact to be a heading. Dashboard health now
  rejects heading-late Markdown artifacts before inventory can pass.

- Tightened Markdown artifact auditing by requiring each retained Markdown
  artifact to include a heading. Dashboard health now rejects heading-less
  Markdown even when the file is readable, non-empty, and contains table markers.




- Promoted CSV header signatures to a hard layout gate by adding
  `tools/dashboard_csv_header_manifest.json` and comparing every retained CSV
  artifact against its expected column count and header hash.

- Added CSV header signature inventory to the non-JSON artifact audit. The
  dashboard now records per-artifact CSV column counts and stable header hashes,
  establishing the baseline needed for future per-artifact expected-header gates.

- Tightened CSV artifact auditing by rejecting ragged rows whose column count
  differs from the header. Dashboard health now catches truncated or over-wide
  CSV data rows across retained CSV artifacts.

- Tightened CSV artifact auditing by requiring at least one data row per retained
  CSV artifact in addition to unique non-blank headers. Dashboard health now
  rejects header-only CSV artifacts before artifact inventory can pass.

- Tightened non-JSON artifact auditing by rejecting CSV artifacts with blank or
  duplicate headers, and fixed the deflate decode-stage CSV header so wrapper
  timing columns are uniquely named.

- Added a hard dashboard health gate for non-JSON retained artifacts. The
  dashboard now audits indexed CSV and Markdown artifacts for parse/read failures,
  empty content, and missing Markdown markers, and strict-validation smoke covers
  the new `non_json_artifact_failed` reason.

- Locked the validation JSON artifact audit exclusion list behind shared manifest
  enums and a negative smoke case. Future attempts to exclude an unapproved JSON
  artifact name now fail schema validation instead of silently shrinking the
  audit surface.

- Promoted validation JSON artifact manifest failures to a hard dashboard health
  gate now that the retained artifact backlog is zero. The audit excludes only
  current-run self outputs and stale dashboard self-snapshots, and any remaining
  manifest validation failure now makes validation JSON health fail.

- Closed the validation JSON artifact manifest backlog by excluding known
  dashboard/validation self-output snapshots from the current-run audit and
  validating every remaining retained `zig-out` JSON artifact against the shared
  manifest. The dashboard now reports zero artifact manifest failures.

- Reduced the validation JSON artifact manifest backlog by making the shared
  schema checker understand optional top-level and item fields, then marking
  older Brotli static-dictionary candidate/probe metadata fields as optional.
  Current artifact audit failures are limited to the two derived dashboard-index
  JSON snapshots.

- Added validation JSON artifact-level manifest audit fields. The smoke now
  records retained `zig-out` JSON artifact parse/schema/manifest validation
  counts plus failure name lists, and the dashboard exposes the current manifest
  cleanup backlog instead of relying only on schema-set coverage.

- Tightened validation JSON schema coverage by recording schemas observed in
  retained `zig-out` JSON artifacts, exposing unchecked observed schemas in the
  dashboard, and failing validation health when any produced schema is not listed
  in `vort.validation_json_smoke.checked_schemas`.

- Added shared schema/docs/smoke coverage for the retained zlib relaxed report
  gate JSON. The manifest now fixes the gate check key set, enforces boolean
  check values, and recomputes `ok` from nested check values so stale or malformed
  gate summaries cannot validate as healthy.

- Tightened zlib relaxed dashboard health by parsing retained Markdown metric rows
  as structured evidence and exposing malformed, duplicate, unknown, and
  value-mismatched metrics. Dashboard health now rejects relaxed wrapper
  Markdown drift before gate/report coverage can pass.

- Tightened zlib relaxed strict-smoke direct drift coverage for the existing
  retained relaxed-wrapper report/gate/Markdown artifacts without adding
  compatibility scope. The strict validation gate now isolates `ok=false` gate
  drift, each exact report metric, and each floor metric before relaxed
  zlib/gzip compatibility coverage can pass.

- Tightened native allocation dashboard health by exposing duplicate report,
  zero-allocation smoke, budget smoke, and negative smoke identities plus
  malformed, duplicate, and unknown Markdown rows. Dashboard health now rejects
  native allocation row drift before allocation balance and smoke coverage can
  pass.

- Tightened zstd compare dashboard health by exposing duplicate CSV row
  identities across compare, standard, and block-sweep artifacts. Dashboard
  health now rejects duplicated zstd-compare CSV identities before aggregate
  CSV/Markdown drift checks can pass.

- Added direct dashboard strict-smoke drift coverage for zstd compare health.
  The strict validation gate now exercises missing CSV companions, gate-vs-CSV
  summary drift, duplicate CSV identities, block-sweep best-row drift, Markdown
  summary drift, and Markdown detail-row drift so `zstd_compare_failed` cannot
  hide comparison artifact inconsistencies behind its aggregate fixture.

- Added top-level Zstd dictionary and dictionary-set decode facade helpers for
  allocator, exact-size, output-limited, append, caller-owned buffer, and decoded
  size flows. Public `zstd.decodeFrame*` and root `zstdDecodeFrame*` APIs can
  now round-trip dictionary-compressed frames without callers dropping down to
  the native-specific decode names.

- Extended the top-level Zstd public decode facade to chunked dictionary and
  dictionary-set input. Split compressed buffers now have allocator,
  exact-size, output-limited, append, caller-owned buffer, and decoded-size
  `zstd.decodeFrameChunks*` / root `zstdDecodeFrameChunks*` helpers matching the
  contiguous dictionary decode surface.

- Added explicit top-level Zstd concatenated-frame facade aliases for contiguous
  and chunked decode flows, including dictionary and dictionary-set variants.
  Public `zstd.decodeConcatenatedFrame*` and root
  `zstdDecodeConcatenatedFrame*` names now mirror the native concatenated
  surface without forcing callers to depend on native-specific identifiers.

- Added non-`Native*` Zstd reusable and dictionary facade aliases for public
  library callers. `zstd.FrameEncoder`, `zstd.FrameDecoder`,
  `zstd.IncrementalFrameDecoder`, `zstd.Dictionary`, `zstd.DictionarySet`, and
  top-level train/catalog helpers now expose the same reusable dictionary
  workflows without requiring applications to name the native-specific types.

- Added public Zstd advanced-encode facade aliases for callers that need
  `AdvancedFrameOptions` without depending on `encodeNativeFrame*` names.
  Bound, alloc, append, and caller-owned encode helpers now cover plain,
  dictionary, and dictionary-set advanced options through `zstd.encodeFrame*`
  / root `zstdEncodeFrame*` public names.

- Added Brotli stored-stream encoded-size preflight helpers so callers can size
  exact output buffers before using the caller-owned encode path. The root
  Brotli stored-stream coverage now checks bound equality, caller-owned encode
  parity, short-buffer failure, and invalid window/metadata planning errors.

- Added Brotli stored-stream chunked encode helpers for split caller input.
  Bound, allocator-returning, append, and caller-owned output variants now cover
  both default and option-bearing stored-stream encodes, with root tests checking
  round-trip decode, byte parity across alloc/append/into, and short-buffer
  failure.

- Added a reusable Brotli `StoredStreamEncoder` facade. It exposes alloc,
  scratch, append, caller-owned, and chunked encode flows while reusing internal
  scratch between calls, and root tests verify parity against the top-level
  stored-stream helpers for default and option-bearing encodes.

- Added append-style stored encode helpers for raw deflate, zlib, zlib preset
  dictionaries, gzip, and metadata-rich gzip headers. The root stored-wrapper
  smoke now verifies prefix preservation, byte parity with allocator-returning
  encoders, and decode round trips for each wrapper.

- Added split-input stored encode helpers for raw deflate, zlib, zlib preset
  dictionaries, gzip, and metadata-rich gzip headers. Chunked bound, caller-owned,
  allocator-returning, and append helpers now match contiguous stored output
  while updating zlib Adler-32 and gzip CRC/ISIZE across caller chunks.

- Added a reusable raw-deflate `RawDeflateEncoder` stored facade. It exposes
  allocator-returning, scratch, append, caller-owned, and chunked stored encode
  flows while reusing internal scratch, with root coverage verifying byte parity
  against top-level stored helpers and raw-deflate decode round trips.

- Added a reusable zlib `ZlibEncoder` stored facade. It exposes
  allocator-returning, scratch, append, caller-owned, dictionary, and chunked
  stored encode flows while reusing internal scratch, with root coverage
  verifying parity against top-level zlib stored helpers and dictionary
  round trips.

- Added a reusable gzip `GzipEncoder` stored facade. It exposes
  allocator-returning, scratch, append, caller-owned, header-options, and chunked
  stored encode flows while reusing internal scratch, with root coverage
  verifying parity against top-level gzip stored helpers and metadata-rich
  header round trips.

- Extended `RawDeflateEncoder` beyond stored blocks with fixed, option-bearing
  fixed, best, and zlib-level raw deflate encode helpers. The reusable facade now
  exposes alloc, scratch, and append flows for these modes, with root tests
  checking byte parity against the top-level raw deflate encoders.

- Extended `ZlibEncoder` beyond stored blocks with fixed, option-bearing fixed,
  best, and zlib-level encode helpers. The reusable facade now exposes alloc,
  scratch, and append flows for these modes, with root tests checking byte parity
  against the top-level zlib encoders.

- Extended `ZlibEncoder` with preset-dictionary fixed, best, and zlib-level
  helpers. The reusable facade now exposes alloc, scratch, and append flows for
  dictionary modes, with root tests checking byte parity against top-level
  dictionary encoders and dictionary decode round trips.

- Extended `RawDeflateEncoder` with dynamic-literal and option-bearing dynamic
  raw deflate helpers. The reusable facade now exposes alloc, scratch, and append
  flows for dynamic modes, with root tests checking byte parity against top-level
  dynamic encoders and decode round trips.

- Extended `ZlibEncoder` with dynamic-literal and option-bearing dynamic zlib
  helpers. The reusable facade now exposes alloc, scratch, and append flows for
  dynamic modes, with root tests checking byte parity against top-level dynamic
  zlib encoders and decode round trips.

- Extended `ZlibEncoder` with preset-dictionary dynamic zlib helpers. The
  reusable facade now exposes alloc, scratch, and append flows for dictionary
  dynamic mode, with root tests checking byte parity against top-level dynamic
  dictionary encoders and dictionary decode round trips.

- Extended `GzipEncoder` beyond stored blocks with fixed, option-bearing fixed,
  best, zlib-level, and metadata-rich header encode helpers. The reusable facade
  now exposes alloc, scratch, and append flows for these modes, with root tests
  checking byte parity against the top-level gzip encoders and header variants.

- Extended `GzipEncoder` with dynamic-literal, option-bearing dynamic, and
  metadata-rich dynamic header encode helpers. The reusable facade now exposes
  alloc, scratch, and append flows for these modes, with root tests checking byte
  parity against top-level gzip dynamic encoders and decode round trips.

- Extended `RawDeflateEncoder` with preset-dictionary fixed, best, and zlib-level
  raw deflate helpers. The reusable facade now exposes alloc, scratch, and
  append flows for dictionary modes, with root tests checking byte parity against
  top-level dictionary encoders and dictionary decode round trips.

- Extended `RawDeflateEncoder` with preset-dictionary dynamic raw deflate
  helpers. The reusable facade now exposes alloc, scratch, and append flows for
  dictionary dynamic mode, with root tests checking byte parity against top-level
  dynamic dictionary encoders and dictionary decode round trips.

- Extended `RawDeflateEncoder` with best split and adaptive split raw deflate
  helpers, including preset-dictionary variants. The reusable facade now exposes
  alloc, scratch, and append flows for split block-planning modes, with root
  tests checking byte parity against top-level split encoders, invalid split-plan
  errors, and decode round trips.

- Extended `ZlibEncoder` with best split and adaptive split zlib helpers,
  including preset-dictionary variants. The reusable facade now exposes alloc,
  scratch, and append flows for split block-planning modes, with root tests
  checking byte parity against top-level split zlib encoders, invalid split-plan
  errors, and strict/dictionary decode round trips.

- Extended `GzipEncoder` with best split and adaptive split gzip helpers,
  including metadata-rich header variants. The reusable facade now exposes
  alloc, scratch, and append flows for split block-planning modes, with root
  tests checking byte parity against top-level split gzip encoders, invalid
  split-plan errors, and strict decode round trips.

- Extended `RawDeflateEncoder` with dynamic split raw deflate helpers. The
  reusable facade now exposes alloc, scratch, and append flows for forced dynamic
  split block planning, with root tests checking byte parity against the
  top-level dynamic split encoder, invalid block-length errors, and decode round
  trips.

- Extended `RawDeflateEncoder` with fixed split raw deflate helpers. The
  reusable facade now exposes alloc, scratch, and append flows for forced
  fixed-Huffman split block planning, with root tests checking byte parity
  against the top-level fixed split encoder, invalid block-length errors, and
  decode round trips.

- Added zlib/gzip dynamic split encode helpers and reusable encoder facades.
  Zlib and gzip callers now have alloc, scratch, and append flows for forced
  dynamic-Huffman split block planning, including gzip metadata-rich header
  variants, with root tests checking top-level parity, invalid block-length
  errors, and strict decode round trips.

- Added raw/zlib/gzip fixed split dictionary and wrapper encode helpers plus
  reusable encoder facades. Raw, zlib, and gzip callers now have alloc, scratch,
  and append flows for forced fixed-Huffman split block planning, including raw
  and zlib preset-dictionary variants and gzip metadata-rich headers, with root
  tests checking top-level parity, invalid block-length errors, and decode round
  trips.

- Added raw/zlib preset-dictionary dynamic split encode helpers and reusable
  encoder facades. Raw deflate and zlib callers now have alloc, scratch, and
  append flows for forced dynamic-Huffman split block planning with preset
  dictionaries, with root tests checking top-level parity, invalid block-length
  errors, and dictionary decode round trips.

- Added top-level raw deflate append encode helpers beyond stored blocks. Raw
  callers now have prefix-preserving append convenience for fixed, best, zlib
  level, dynamic, split, adaptive split, and preset-dictionary modes, with root
  tests checking byte parity against allocator-returning encoders, invalid-plan
  propagation, and decode round trips.

- Added top-level zlib append encode helpers beyond stored blocks. Zlib callers
  now have prefix-preserving append convenience for fixed, best, zlib level,
  dynamic, split, adaptive split, and preset-dictionary modes, with root tests
  checking byte parity against allocator-returning encoders, invalid-plan
  propagation, and strict/dictionary decode round trips.

- Added top-level gzip append encode helpers beyond stored blocks. Gzip callers
  now have prefix-preserving append convenience for fixed, best, zlib level,
  dynamic, split, adaptive split, and metadata-rich header modes, with root tests
  checking byte parity against allocator-returning encoders, invalid-plan
  propagation, and strict decode round trips.

- Exposed Brotli minimal static-dictionary introspection through the root module.
  Library callers can now inspect the currently supported dictionary entry subset
  and copy-length size-bit mapping without reaching into `br.zig`, with root
  tests pinning representative identity and transformed entries.

- Extracted Adler-32 from the broad `src/checksum.zig` facade into
  `src/checksum/adler.zig`, reducing the facade from 1,330 to 1,186 lines.
  The module owns the streaming state, portable 64-byte vector fallback,
  target-selected AVX2 implementation, scalar oracle, and boundary/fragment
  tests. `bestAdler32Backend` exposes the compiled backend without changing
  existing `Adler32` or `adler32` APIs.
- Added an AVX2 Adler kernel after directly auditing image-png's locked
  `simd-adler32` 0.3.9 dependency. It keeps sum, weighted sum, and cross-block
  prefix accumulators in YMM registers across each 5,536-byte chunk and uses
  `vpsadbw` plus `vpmaddubsw`/`vpmaddwd`, with an eight-block inner unroll and
  one horizontal reduction per chunk. The kernel stays noinline: the initial
  inline candidate changed the large PNG decode call graph and regressed a
  128-pixel icon even though the checksum microbenchmark improved.
- Nine fixed-CPU-6 alternating checksum rounds moved the 1 MiB workload from
  `29,392.73` to `53,327.73 MiB/s`, with `1.67798x` paired median,
  `1.72238x` paired geomean, and `1.45921x` worst round. Seven serial
  fixed-CPU-6 imx PNG corpus rounds improved strict decode from `775.61` to
  `781.98 MiB/s`, with `1.00821x` aggregate, `1.01063x` fixture geomean,
  and `1.01303x` fixture median. Focused 15-round repeats kept Lohengrin,
  `kodim07`, and `paletted-zune` at `1.00175x`, `1.00700x`, and `1.00562x`
  medians rather than accepting aggregate evidence over a hidden fixture loss.
- Adler correctness now covers known zlib vectors, 32/64/256/NMAX boundaries,
  four alignments, fragmented streaming updates, the all-`0xff` NMAX case,
  generic x86_64 and AArch64 portable compilation, Zig std differential tests,
  and Python zlib/system gzip black-box differentials.
- Audited image-png `4ab5484` stable and optional-SIMD Paeth implementations
  against Vort source and ReleaseFast assembly. An explicit four-lane RGBA
  predictor generated the intended XMM min/max/select loop and substantially
  improved isolated 16/32/128-pixel reconstruction, but complete decode
  candidates repeatedly moved non-target fixtures backward. The most isolated
  imx/Vort dispatch still left RGB Exoplanet and Fantasy at about `0.9921x` and
  `0.9920x` in 101-round fixed-CPU confirmations; ELF text-section isolation
  could not prevent unwind metadata from moving the main text base. All
  production changes were reverted rather than accepting aggregate gains over
  fixture losses.
- Rejected image-png's optional bpp=3 SIMD shape under Zig 0.16 as well.
  Pixel-at-a-time four-lane and 48-byte/16-pixel deferred-store ports both
  passed scalar/in-place oracles and emitted XMM predictor instructions, but
  Fantasy reconstruction fell to about `728` / `709 MiB/s` versus the committed
  stable-style kernel near `1,075 MiB/s`. Do not retry these exact Paeth forms
  unless Zig vector lowering or linker ordering changes materially; pursue a
  different intrinsic/assembly or profile-guided layout strategy instead.
- Added an isolated whole-image reconstruction path for Up-dominant RGBA8 PNGs.
  A format/size policy plus 15-row Up prefix selects the 91.3%-Up
  `Transparency.png` workload while all other current image-png fixtures keep
  the established drainer. The 287-line `png/up_dominant.zig` module owns the
  policy, direct vector Up loop, mixed-row fallback, executable section, and
  scalar/malformed tests instead of adding another responsibility to the
  20K-line DEFLATE facade.
- Thirty-one fixed-CPU-6 active/control rounds use byte-identical `.text` and
  `.rodata` binaries and an identically sized isolated section.
  `Transparency.png` improves `1.0071x` strict / `1.0072x` no-Adler; all
  no-Adler non-target medians remain in `0.9985x...1.0029x`. Hardware counters
  reduce instructions by about 1.3--1.5%, branches by 2.1--2.3%, and cycles by
  0.3--0.5%.
- Rejected 64-byte horizontal Up unrolling, 2/4-row vertical pipelines, and
  consecutive-run grouping. The first reduced instructions without reducing
  cycles; vertical pipelines reduced instructions but regressed cycles/time
  about 5--7% through longer dependencies; run grouping did not beat the
  simpler isolated per-row path.
- Rejected a single 16-byte vector tail after the accepted 32-byte Up loop.
  Scalar/sentinel coverage included standalone and combined vector thresholds
  through 65 bytes plus 1,199/1,200/1,201-byte real-row boundaries, and
  same-source terminal reserves kept the isolated section at 1,290 bytes with
  shared runtime sections/addresses identical. Thirty-one target counter
  rounds improved strict elapsed/cycles/instructions by
  `1.00635/1.00858/1.00977x` and no-Adler by
  `1.00938/1.00912/1.01135x`.
- The guarded 30-item corpus matrix still rejected that tail.
  `Transparency.png` improved `1.00982x` strict / `1.00510x` no-Adler and
  fixture geomeans were slightly positive, but sums of fixture median times
  regressed to `0.99960x/0.99950x`. A 101-round confirmation cleared the
  strict indexed-Exoplanet fluctuation, while no-Adler Exoplanet remained at
  `0.99866x` paired median / `0.99905x` independent medians /
  `0.99952x` paired geomean. The candidate and its oracle were fully reverted;
  do not retry the exact YMM-plus-XMM tail without a different layout/schedule
  that also clears aggregate and worst-real-fixture gates.
- Audited image-png's incremental `UnfilteringBuffer` and prototyped a distinct
  direct-history layout for the Up-dominant workload. It reconstructed pixels
  directly into final output, kept only one residual row plus filter bytes, and
  recovered old residuals by applying the inverse PNG predictor to completed
  rows, avoiding both the 360.3 KiB filtered image and a duplicate 32 KiB ring.
  A read-only parser found 60.6% RLE match bytes, 54.4% in-row Up RLE258 bytes,
  91.1% target-Up bytes, 95.9% same-filter source/target bytes, and no non-RLE
  overlapping matches. Literal/RLE/whole-row-boundary/mixed-Paeth/Adler oracles
  and real strict/no-Adler output checks passed.
- Rejected that direct-history architecture before a corpus gate. The generic
  no-Adler sink reached only about `1,167 MiB/s`; a dedicated canonical RLE258
  sink entry improved it `1.1686x` to about `1,363 MiB/s`, versus about
  `2,781 MiB/s` for the committed same-layout control (`0.4903x`). The saved
  scratch pass could not offset residual-history mapping and per-match row
  reconstruction. The API, imx dispatch, semantic-loop instance, 520-line
  candidate module, and tests were fully reverted. A future direct-output
  design must preserve linear-inflater match cost rather than only reduce
  scratch memory.
- Added a canonical RLE258 semantic-loop specialization for final dynamic
  blocks with the profiled 12-bit literal / 9-bit distance table shape.
  `Transparency.png` uses one-bit code zero for both length 258 and distance
  one, so the loop consumes the two-bit pair directly and reuses the existing
  258-byte vector fill. Table proof and section ownership live under
  `src/deflate/semantic/rle258.zig`; ordinary semantic loops retain their prior
  generated-code instances.
- Specialized/reference differential tests match output bytes, consumed bits,
  and reader byte offsets. Thirty-one fixed-CPU-6 active/control counter rounds
  improve Transparency no-Adler elapsed/cycles/instructions/branches by
  `1.034/1.031/1.044/1.040x`; non-selected kodim17 remains effectively
  `1.000x`. The 15-file gate improves Transparency `1.033x` strict and `1.031x`
  no-Adler, with positive aggregate/geomean and a `0.9979x` worst non-target
  no-Adler median.
- Rejected a branch in every semantic loop and a broader all-matching-block
  dispatch. The former regressed unrelated dynamic streams; the latter retained
  multi-block indexed noise. The accepted final-block 12/9-bit policy keeps the
  optimization narrow and evidence-backed.
- Rejected inline non-overlap `memcpy` inside only the isolated RLE258 loop.
  Instructions/branches fell slightly, but fixed-core strict/no-Adler elapsed
  ratios were about `0.996x/0.990x` and cycles `0.999x/0.998x`; the candidate
  was fully reverted before a corpus gate.
- Rejected replacing the generic RLE258 speculative tail with a fixed exact
  two-byte tail. The all-alignment redzone oracle and generated AVX2 body were
  correct, and fixed-core target counters improved strict
  elapsed/cycles/instructions by `1.0081/1.0055/1.0075x` and no-Adler by
  `1.0123/1.0111/1.0094x`. The 31-round corpus gate nevertheless regressed
  aggregate strict/no-Adler throughput to `0.99922/0.99935x`; indexed
  Exoplanet reached `0.99594x` strict and the 32-pixel icon `0.99793x`
  no-Adler. Production code and the candidate-only oracle were fully reverted.
- Profiled consecutive decode-side canonical RLE258 pairs with an independent
  PNG/DEFLATE parser whose complete output lengths match Python zlib.
  Transparency has 783 pairs in 287 runs: lengths 1/2/3/4 occur
  96/6/65/120 times, so four-pair batches could cover 480 pairs (`61.3%`)
  without broadening the existing final 12/9-bit dispatch.
- Rejected an inline four-pair decode despite that coverage. The 0...9-pair
  differential oracle matched output and reader state, and same-source fenced
  binaries isolated the generated loop, but LLVM expanded the 1,032-byte fill
  into 32 AVX2 stores plus a tail. Thirty-one target rounds measured strict
  elapsed/cycles/instructions at `1.0009/0.9974/0.9935x` and no-Adler at
  `0.9955/0.9986/0.9933x`. Branches fell about 1.7%, but bulk stores outweighed
  loop-control savings. The candidate was fully reverted; only a materially
  different out-of-line fill boundary would justify revisiting batch four.
- Rejected that out-of-line boundary as well. Standalone and production
  ReleaseFast codegen reduced the noinline fixed fill to a 20-byte tail call
  into `compiler_rt.memset`; 0...9-pair output/state oracles remained exact,
  and same-source retention/fencing isolated code plus FDE/jump-table companion
  metadata. Target strict elapsed/cycles/instructions still collapsed to
  `0.8862/0.8883/0.8970x`, with no-Adler at
  `0.8799/0.8871/0.8908x`; non-selected kodim17 stayed neutral. Register
  save/restore and generic memset control overwhelm the saved pair-loop work.
  Both inline and noinline decode-side batch-four families are now closed.
- Rejected bounded consecutive-pair grouping while preserving the existing
  258-byte store schedule. The 0...9-pair oracle matched output and reader
  state; ReleaseFast reused one YMM broadcast and moved refill/literal lookup
  to each run boundary. Same-source fenced counters still measured strict
  elapsed/cycles/instructions at `0.9944/0.9952/0.9960x` and no-Adler at
  `0.9977/0.9956/0.9954x`. Branches improved about 1.0% and branch misses
  6--9%, but inner-loop control/register pressure cost more than the saved
  lookup work. Production code was fully reverted. Exact-tail, inline/noinline
  batch four, and run grouping close the current RLE258 follow-up family.
- Captured a committed-binary DWARF callgraph: the prior `memcpyFast` sample
  comes entirely from the isolated RLE258 loop's `copyMatchAt`, not PNG
  transform scratch. Since inline non-overlap copying already failed counters,
  memcpy is not a separate untried direction.
- Audited symbol-285 joint distributions. Of 1,280 occurrences in
  Transparency, 783 are the accepted distance-one pair and 497 use other
  distances, led by distance symbols 20/16/17 at 299/86/48 occurrences.
  Rejected a one-branch length-only metadata shortcut that assigned
  bits/base/extra as `1/258/0` before reusing ordinary distance/copy logic.
  Pair and distance-two non-pair oracles matched output and reader state;
  ReleaseFast emitted one low-bit test and shrank the isolated loop, but strict
  elapsed/cycles/instructions/branches were
  `1.0021/1.0004/0.9985/0.9914x` and no-Adler
  `0.9991/1.0007/0.9986/0.9913x`. Production code was reverted. RLE258
  metadata/copy/store/batch/run follow-ups are now closed on this target.
- Retested image-png's four-lane RGBA Paeth source shape behind the new
  Up-dominant executable-section boundary. The isolated scalar/in-place oracle
  and expected XMM loop were correct, and instructions fell 17--19%, but cycles
  improved at most about 0.6%. Thirty-one corpus rounds left Transparency near
  neutral (`1.0005x` strict / `1.0030x` no-Adler) and regressed strict
  aggregate/geomean to `0.9952x/0.9984x`; all production code was reverted.
- Audited Vort's semantic DEFLATE loop against image-png's `fdeflate` 0.3.7
  backend and isolated speculative 16-byte match copying as the remaining
  concrete loop-shape difference. The match-copy benchmark now has an
  `overcopy16` kernel, logical-output oracle/checksum, and case/kernel filters;
  its dashboard contract expands from 21 to 28 case/kernel rows. Broad
  screening improved non-overlap lengths 3/6/32 by about `2.59x` / `2.68x` /
  `2.35x`, but overlap distance 45 and distance 2 fell to about `0.40x` /
  `0.29x`, so the kernel remains benchmark-only.
- Rejected an exact-size-only production specialization limited to deep-distance
  dynamic blocks and short non-overlapping matches. It preserved ordinary
  caller-buffer suffixes, passed exact-size/sentinel and scalar oracles, and
  added only a separate `0xcf0` semantic body while existing `0xc90`/`0xcc0`
  specializations remained unchanged. Nevertheless, nine alternating fixed
  CPU-6 Fantasy PNG rounds produced an old/new instruction median of
  `1.028824714x` but a cycle median of only `0.999749144x`; all production and
  exact-size API changes were reverted rather than accepting instruction-count
  evidence without a latency win.
- Tested a primary-only 12-bit literal / 9-bit distance decoder only inside the
  accepted final-block canonical RLE258 boundary. This was not a repeat of the
  old broad semantic-12 policy: Transparency has only 277 double-literal slots
  and never met that policy's 1,024-slot threshold. A modular
  `deflate/semantic/primary.zig` candidate and complete max-12/max-9 oracle
  covered a long literal, long distance, ordinary match, RLE258 pair, EOB,
  output, and reader state; all 263 ReleaseFast Deflate tests passed.
- Thirty-one fixed-CPU-6 target rounds improved no-Adler
  elapsed/cycles/instructions/branches by
  `1.0100/1.0041/1.0169/1.0397x`, but strict cycles were only `0.9997x` and
  branch misses regressed. The guarded corpus gate then measured strict indexed
  Exoplanet at `0.995024x` independent-median / `0.993418x` paired-geomean and
  no-Adler lorem oxipng at `0.996983x`. The wider builder, loop, dispatch, and
  oracle were fully removed. Do not retry a per-image 12/9 table build without
  materially changing table storage or amortizing its lifetime.
- Added a bounded filtered-history whole-image helper for the accepted final
  dynamic canonical RLE258 shape. A resumable direct semantic loop keeps the
  newest 32 KiB of raw filtered bytes immutable inside a contiguous 64 KiB
  window, reconstructs only complete rows that have left DEFLATE lookback, and
  compacts only released row prefixes. This preserves cheap linear match
  emission, unlike the rejected reconstructed-output-as-history architecture.
- The 300x300 RGBA8 `Transparency.png` path now replaces 360,300 bytes of full
  filtered scratch with 65,536 bytes, removing 294,764 bytes and the complete
  second filtered-buffer traversal. Transactional tail decode preserves reader
  state at output pauses; strict Adler uses original filtered rows. Public
  contracts reject short/overlapping storage, unsupported tables, and forged
  overflowing metadata before unsafe use or fallback-visible output.
- Moved row lifecycle and compaction into
  `src/deflate/png/windowed_history.zig`, exported an explicit 64 KiB scratch
  constant, and moved public helper contract tests under
  `src/root_exports/png/`. Only the resumable token loop remains in the large
  DEFLATE facade. Real strict/no-Adler output matches the independent streaming
  reference for all 360,000 bytes at CRC32 `2202190348`.
- Final v6 active/control binaries are equal-sized with byte-identical ordinary
  `.text`, `.rodata`, RLE258, and Up-dominant sections. Thirty-one complete
  fixed-CPU-6 pairs improve strict elapsed/cycles/branches by
  `1.163/1.156/1.299x` and no-Adler by `1.197/1.180/1.358x`.
  Instructions regress to `0.802/0.817x` control/active, confirming that the
  end-to-end win is reduced memory/dependency cost rather than fewer
  instructions. The prior guarded 30-item corpus remains positive at
  `1.000183/1.000912x` aggregate and `1.009268/1.012307x` fixture geomean.
- Generalized bounded filtered history to arbitrary dynamic, fixed, and stored
  block sequences. Resumable semantic and compact reference loops commit only
  complete tokens, preserve raw filtered distances across EOB/table changes,
  and transactionally segment maximal stored blocks. The public minimum remains
  64 KiB; a 128 KiB exported scratch recommendation amortizes compaction.
- Added a >128 KiB RGB8/RGBA8 imx policy while retaining indexed in-place,
  grayscale, small-image, and 300x300 RLE258 paths. A mixed-filter 1024x128
  oracle covers multi-dynamic/multi-fixed/multi-stored output against full
  scratch, the 64 KiB stored minimum, Adler/trailing/truncation/filter errors,
  overlap, and short scratch.
- Seven selected real fixtures completed strict and no-Adler 31-round
  same-layout gates with every row positive. Strict aggregate/geomean/minimum
  are `1.142/1.121/1.044x`; no-Adler are `1.120/1.109/1.028x`.
  RGB Exoplanet and RGBA screenshot improve about 30%, Fantasy about 7.7%, and
  all four Kodak rows about 4.4--5.7%.
- Rejected extracting the hot row-commit lifecycle behind a cross-module
  function: fixed-core structure A/Bs regressed RGB Exoplanet, kodim07, and
  screenshot by roughly 1--2%. Kept history/row state modular and split general
  versus RLE258 contract tests into a descriptive subdirectory, but retained
  the token/commit driver beside the semantic loop for generated-code locality.
- Added a caller-owned incremental Snappy framed-stream decoder. Chunk headers
  and payloads can split at arbitrary input boundaries; compressed and
  uncompressed chunks are checksum-validated into bounded per-chunk scratch and
  drained through arbitrarily small output buffers. The state machine supports
  skippable chunks, explicit finish/truncation semantics, reset/reuse, compressed
  chunk and total-output limits, snapshots, and shared streaming diagnostics.
  The implementation lives under `src/snappy/incremental/` behind a narrow codec
  interface instead of expanding the already-large Snappy facade.
- Added the matching incremental Snappy framed encoder under
  `src/snappy/incremental/frame_encoder.zig`. It accepts arbitrary input
  fragments, emits the stream identifier once, accumulates at most one 64 KiB
  format chunk, reuses the existing greedy block encoder and compressed-vs-raw
  selection, and drains encoded chunks through arbitrarily small caller output.
  Explicit finish, input limits, reset/reuse, snapshots, and multi-chunk round
  trips are covered beside the incremental decoder tests.
- Added `initExactSize` to the incremental Snappy encoder. Although framed
  Snappy has no content-size header field, applications can pledge total input
  size and receive `SizeMismatch` on underflow or overflow while retaining the
  same split-input, chunking, and tiny-output behavior.
- Added `expected_output_len` to the incremental Snappy decoder. Declared data
  chunks cannot exceed the remaining pledged output, and `finish` rejects a
  shorter stream with `SizeMismatch`, giving framed Snappy symmetric exact-size
  contracts for incremental encode and decode.
- Incremental Snappy framed encoders/decoders can reuse retained buffers across
  independent streams through `nextStream`; the encoder also accepts a new
  pledged input size. Every stream emits/requires its own identifier and keeps
  checksum/chunk state independent, while snapshots expose cumulative bytes and
  completed stream count/index. Two-stream exact-size round trips and root API
  coverage protect the continuation contract.
- Incremental Snappy encoders can insert borrowed skippable chunks with any
  valid `0x80...0xfe` type after accepted content. The encoder flushes the data
  boundary, drains the event through tiny output, then resumes content; duplicate,
  invalid-type, oversized, or post-finish requests fail deterministically. Frame
  summary and decode tests verify payload accounting and transparent skipping.
  Incremental decoders can optionally capture bounded skippable payload bytes
  and caller-owned `(type,length)` events. Snapshots distinguish total versus
  captured bytes/events and truncation, preserving transparent decode without
  hidden allocations.
- Added a no-content-size incremental native LZ4 frame encoder under
  `src/lz4/incremental/`. It preserves linked or independent block policy, one
  bounded frame block, 64 KiB linked history, block/content XXH32 checksums, and
  reusable match-finder state while accepting split input and draining through
  tiny caller output. Explicit finish emits the end mark/footer; content-size
  and Dictionary_ID modes are rejected because their headers require metadata
  before streaming input begins.
- Extended the incremental LZ4 encoder with `initExactSize`. Callers that know
  the total input length can emit the content-size header while retaining split
  input and tiny-output behavior; underflow or overflow against the pledged
  length returns `SizeMismatch`.
- Added preset-dictionary constructors for the incremental LZ4 encoder, with
  optional pledged size. Dictionary_ID is emitted before streaming begins and
  dictionary bytes seed the first block's match history; later linked blocks
  continue from the rolling 64 KiB frame history. Zero or mismatched IDs are
  rejected before output.
- Added dictionary-set constructors for the incremental LZ4 encoder, including
  pledged-size mode. The encoder resolves Dictionary_ID once at construction,
  borrows the selected history bytes, and returns `NeedDictionary` before any
  frame output when the catalog has no matching entry.
- The incremental LZ4 encoder can reuse its block encoder and buffers for new
  frames through `nextFrame` variants. Each frame may change block/checksum
  policy, content-size pledge, and preset dictionary; history/hash/content
  checksum state resets independently while snapshots retain cumulative bytes
  and completed frame count/index. A mixed independent/no-dictionary plus
  linked/dictionary concatenation round-trips through dictionary-set decode.
  After a drained data frame, `writeSkippable` can queue a standard LZ4
  skippable frame and drain it through tiny output before `nextFrame` starts the
  next data frame. Stream summary and concatenated decode tests cover the
  data-skippable-data layout without illegally embedding it inside a data frame.
  The native incremental decoder can capture bounded skippable payload bytes and
  caller-owned `(id,length)` events while continuing concatenated data frames.
  Snapshots report total/captured/truncated metadata without allocating.
- Added a no-content-size incremental native Zstd raw/RLE frame encoder under
  `src/zstd/incremental/`. It retains one bounded block, delays the Zstd final
  block bit until explicit finish, maintains the optional XXH64 content checksum
  incrementally, and drains through tiny caller output. The streaming header
  advertises a legal 128 KiB window without requiring total content size;
  this initial slice left content-size, Dictionary_ID, and entropy-coded
  selection on complete-input APIs before the extensions below.
- Extended the incremental Zstd encoder with `initExactSize`, using the normal
  shortest single-segment content-size header when the caller pledges total
  input length. Split input and tiny-output behavior remain unchanged; pledged
  length underflow or overflow returns `SizeMismatch`.
- Added Dictionary_ID constructors for the incremental Zstd raw/RLE encoder,
  including pledged-size mode. Because raw/RLE blocks never reference preset
  history, these constructors carry and validate dictionary metadata without
  borrowing dictionary bytes; matching dictionary-aware decode APIs enforce the
  ID before returning the payload.
- Added dictionary-set constructors for the incremental Zstd raw/RLE encoder,
  including pledged-size mode. Dictionary_ID is resolved once at construction;
  missing catalog entries return `NeedDictionary` before any frame output.
- Extended the incremental Zstd encoder to use the native Huffman/sequence block
  planner for `literal_only` and `auto`, while retaining raw/RLE compatibility
  mode. Preset-dictionary constructors borrow history bytes for the encoder
  lifetime, emit real dictionary-referencing sequences, and share a narrow
  incremental block-emitter module instead of adding codec policy to the generic
  streaming state machine. Dictionary-set constructors now resolve and retain
  the selected history rather than carrying Dictionary_ID metadata alone.
- Added a bounded rolling frame-history buffer and a separate cross-block match
  finder for the incremental Zstd entropy encoder. Completed blocks retain only
  the newest advertised-window bytes; later blocks can emit real sequences that
  reference earlier input while split input, tiny output, checksum, and reset
  behavior continue through the same streaming state machine.
- Replaced the initial per-block linear prefix lookup with a persistent
  four-way hash index over absolute stream positions. The matcher now finds up
  to eight non-prefix history regions per block and emits them as one bounded
  multi-sequence plan, while stale positions are rejected against the sliding
  window without rebuilding the index.
- Added resumable `flush()` to the incremental Zstd encoder. A flush emits the
  accepted partial block as non-final, drains through arbitrary caller output,
  acknowledges completion with `need_input`, preserves rolling history for
  subsequent writes, and treats repeated empty flushes as idempotent. Encoder
  instances can now reuse retained history/index/block buffers for independent
  frames through `nextFrame` variants. Each frame may change raw/entropy
  selection, checksum/content-size pledge, and preset dictionary; frame-local
  entropy/history/checksum state resets while snapshots retain cumulative bytes
  and frame count/index. Mixed entropy plus dictionary-backed concatenation is
  decoded through a dictionary set and covered by the root facade.
  At a drained frame boundary, `writeSkippable` can queue and tiny-output drain
  a standard Zstd skippable frame before `nextFrame` starts the next data frame.
  Stream summary and concatenated decode cover data-skippable-data ordering.
  The native incremental decoder can capture bounded skippable payload bytes and
  caller-owned `(id,length)` events before discarding metadata frames; snapshots
  expose total/captured/truncated state across concatenated data frames.
  state and helpers now live under `src/zstd/incremental/encoder/` instead of
  expanding the incremental directory as a flat list.
- Extended the same resumable, idempotent flush contract to the LZ4 and framed
  Snappy incremental encoders. LZ4 linked mode retains its 64 KiB history and
  checksums across flushed blocks; Snappy publishes a complete checksummed data
  chunk. Both drain through tiny output, resume input after `need_input`, and
  remain finish/reset compatible.
- Extended resumable flush to the Brotli stored encoder, preserving its
  bit-writer state across flushed uncompressed meta-blocks. Input limits are now
  validated before pending prefix output is drained, so deterministic limit
  errors no longer depend on whether the caller supplied an empty output slice.
- Added pledged compressed length to the general Brotli incremental decoder. A
  framed transport can now trigger validation and stored/compressed meta-block
  decode automatically at the known payload boundary, consume the boundary
  call's tiny output immediately, and receive deterministic short/long
  `SizeMismatch` errors without a separate finish call.
- The general Brotli incremental decoder can reuse its retained compressed and
  decoded allocations across independently framed payloads through `nextFrame`
  and `nextFrameExactCompressedSize`. Per-frame limits/pledges reset while
  snapshots retain cumulative compressed/output bytes plus completed frame
  count/index. Tests continue from a stored frame to a compressed meta-block
  frame and exercise the root public facade.
- Added a modular raw-DEFLATE incremental stored-block encoder under
  `src/deflate/incremental/`. It accepts split input, drains through tiny output,
  emits resumable non-final flush blocks, supports pledged and maximum input
  sizes, and writes the sole BFINAL block only at finish.
- Added a fixed-Huffman raw-DEFLATE incremental encoder beside the stored core.
  It keeps bit packing continuous, plans each block against a rolling 32 KiB
  history, supports tiny output and pledged input, and emits an empty stored
  block for byte-aligned zlib-compatible sync flush without ending the stream.
- Wrapped the fixed stream core with `ZlibIncrementalFixedEncoder`, adding a
  streamed CMF/FLG header, optional preset-dictionary DICTID/history, incremental
  Adler-32 footer, exact input sizes, tiny-output draining, and the same sync
  flush continuation semantics.
- Added `GzipIncrementalFixedEncoder` over the same raw core, including standard
  or metadata-rich RFC 1952 headers, optional FHCRC, incremental CRC-32, ISIZE,
  exact input sizing, tiny-output draining, and resumable sync flush.
- Added `RawDeflateIncrementalBestEncoder`, reusing the fixed stream state
  machine while selecting stored, fixed, or dynamic Huffman representation per
  block. It retains rolling history, pledged-size handling, tiny output, BFINAL,
  and sync-flush semantics across all three wire choices.
- Added zlib/gzip best incremental wrappers over the same raw selector plus
  public level-to-options helpers. Wrapper checksum, dictionary/metadata, flush,
  exact sizing, and tiny-output behavior now automatically cover stored, fixed,
  and dynamic block choices.
- Gzip fixed and best incremental encoders can now continue with
  `nextMember(header)` after a completed member has been fully drained. Each
  RFC 1952 member gets independent DEFLATE history, CRC-32, ISIZE, and metadata
  while allocations are retained; stream-level input/output and completed
  member counts remain cumulative in the new encoder snapshot. Transitions
  before completion are rejected, and tests round-trip two differently headed
  members through the concatenation-aware incremental decoder using tiny output.
  `nextMemberExactSize` additionally changes the pledged uncompressed size for
  each member, with strict too-short/too-long validation rather than carrying
  the first member's size contract into later members.
  `nextMemberWithOptions` and `nextMemberExactSizeWithOptions` also switch raw
  compression/block settings as well as metadata, enabling dynamic, fixed, or
  stored members with different levels in one stream. Mixed dynamic-text and
  stored-random members are wire-inspected and concatenated-decoder tested. The
  encoder snapshot exposes pending output and the active/last member index so
  tiny-output schedulers can distinguish a drained boundary from an in-flight
  member before calling `nextMember`. Both fixed and best encoders share this
  surface; fixed-member concatenation and the root public export have dedicated
  coverage rather than relying only on generic instantiation.
- Zlib fixed/best incremental wrappers now have symmetric `nextStream` and
  `nextStreamExactSize` continuation for the library's established
  concatenated-zlib convention. Each stream can switch raw compression options,
  preset dictionary/DICTID, and pledged size while retaining allocations; a
  mixed level/no-dictionary + dictionary stream round-trips through the public
  concatenated decoder with exact-size enforcement. Zlib snapshots mirror the
  gzip member diagnostics with cumulative/current byte counts, pending output,
  stream count, and active/last index. Wrapper continuation tests now live in a
  focused submodule instead of further expanding the main incremental test file.
  Concatenated decode can resolve a different preset dictionary for each stream
  through borrowed `ZlibDictionarySet` entries keyed by DICTID; the focused API
  covers caller-provided output and exact-size allocation, reports
  `NeedDictionary` when a later ID is absent, and is exported from the root.
  The byte-progressive `ZlibIncrementalDecoder` accepts the same borrowed set,
  waits for a split four-byte DICTID, selects/seeds the matching history before
  raw decoding, and retains its existing retry-oriented `NeedDictionary`
  diagnostic when no entry matches.
  It also supports opt-in concatenated streams with cumulative output limits
  and exact-size validation, independent raw history/Adler state, per-stream
  dictionary reselection, boundary/count/index snapshots, and later-stream error
  offsets. Byte-at-a-time two-dictionary input and a corrupt second stream are
  covered alongside the one-shot concatenated APIs.
  Regression coverage pins cumulative `max_output_len`, short/long exact sizes,
  EOF validation, and reset after an error so wrapper limits cannot silently
  degrade into per-stream limits.
- Added bounded adaptive block sizing to the incremental best core. Full input
  windows use the existing stored/fixed/dynamic cost scorer and split policy to
  choose a shorter prefix, while buffering never exceeds `max_block_len`; raw,
  zlib, and gzip wrappers share the option through their common raw core.
- Added bounded cross-call lookahead to incremental DEFLATE block planning. The
  encoder retains a configurable suffix beyond the normal target, plans it with
  the next input prefix, and moves the cut to a complete LZ77 token boundary so
  matches spanning a caller/block boundary are not truncated. Flush and finish
  still publish all accepted bytes immediately.
- Added a persistent rolling hash-chain match finder for incremental DEFLATE
  hash-parser levels under `src/deflate/incremental/encoder/match_finder/`. Fixed,
  best, zlib, and gzip wrappers now share epoch-tagged 32 Ki-entry hash heads and
  a bounded predecessor ring across blocks instead of allocating and rebuilding
  dictionary tables per block. Preset dictionaries and cross-block hash anchors
  seed the same state; reset is O(1), retains table allocation, and reproduces
  deterministic output. Other parser modes retain their existing planner paths.
- Extended that persistent matcher to the lazy parser used by default and
  middle compression levels. The shared state now performs the existing
  one-byte lazy probe with safe hash/lazy/anchor mode transitions, while sparse
  tail insertion avoids indexing every byte of long matches. The dedicated
  `bench-deflate-incremental-encode` comparison and its non-regression gate
  require persistent lazy encoding to be both no slower and no larger than the
  per-block rebuilt reference; the initial local ReleaseFast smoke measured
  about `402.76` versus `225.61` MiB/s (`1.785x`) and `2371` versus `4489` bytes
  (`0.528x`) on a 256 KiB structured-log stream.
- Expanded that benchmark from one favorable stream to five deterministic
  256 KiB corpora: JSON logs, source, repetitive bytes, mixed binary, and exact
  32 KiB cross-window repetition. It now invokes zlib 1.3 level 6 directly via
  its in-memory raw-DEFLATE API, and `-Dzlib-ng-root=...` links a local zlib-ng
  compat build (locally 2.3.90) through the same API without process/file timing
  noise. The gate requires the full case/mode matrix, limits persistent ratio
  drift versus per-block rebuild to 1%, bounds compressible output against the
  competitor, and protects aggregate non-binary throughput. Multi-corpus evidence
  also exposed two hot paths now fixed in production: word-at-a-time history
  match comparison and stored fast-path selection guarded by sparse history
  probes so unrelated random blocks skip search while repeated binary windows
  remain compressible. A 32 KiB-block local zlib-ng smoke showed Vort around
  `2.1x` faster on JSON and `2.3x` on source than its per-block rebuild baseline,
  while zlib-ng remained roughly `2.1-2.5x` faster than Vort on those rows and
  materially smaller on repetitive input; those measured gaps remain active
  optimization targets.
- Dynamic DEFLATE encoder tables now build canonical code arrays directly from
  code lengths instead of first materializing the decoder-oriented bucketed
  `HuffmanTable` and rescanning its entries. The focused Huffman build benchmark
  gained equivalent `encoder` and legacy `encoder-reference` rows for literal,
  long-tail, distance, and code-length alphabets; its gate requires the direct
  path to win every shape while matching canonical codes in unit tests. The
  latest local ReleaseFast smoke improved the 286-symbol mixed/long-tail encoder
  rows by about `1.24x`/`1.23x`; smaller distance/code-length tables improve more
  modestly, and the multi-corpus zlib-ng DEFLATE gate remains green.
- Sparse package-merge code-length planning now compacts active symbols into
  32- or 64-symbol workspaces before running the same optimal algorithm, then
  maps lengths back to the full DEFLATE alphabet. This avoids moving 286-symbol
  multiplicity vectors through every depth for sparse literal trees while
  preserving the full-width path for dense alphabets. Full-width reference
  equivalence tests cover deterministic sparse layouts, and the new focused
  `run-huffman-length-bench-gate` compares both paths directly. Initial local
  ReleaseFast evidence improved 18- and 48-active-symbol literal trees by about
  `3.36x` and `3.39x` respectively with identical output checksums.
- Dense 286-symbol package-merge now stores only weight plus compact child
  back-references per package and accumulates code lengths from the selected
  DAG, instead of carrying a 144-byte packed multiplicity vector through every
  list merge. Stable creation-order tie-breaking may assign equal-frequency
  symbols different but interchangeable optimal lengths; randomized tests and
  the gate therefore require identical weighted cost, valid Kraft space, and
  deterministic output rather than symbol-by-symbol identity. Current local
  ReleaseFast evidence improves the dense literal alphabet by about `4.18x`
  while retaining the full-width implementation as the reference.
- Dynamic-header code-length RLE is now isolated under
  `src/deflate/dynamic/code_length_rle.zig` and walks HLIT/HDIST as one logical
  sequence without materializing their 316-entry concatenation. It emits ops,
  accumulates the 19-symbol frequency histogram, and totals repeat extra bits
  in the same pass, removing two subsequent op scans from dynamic block
  planning while preserving cross-boundary zero runs. A fused-vs-legacy-shape
  benchmark/gate covers sparse, mixed, boundary, and dense code-length patterns;
  initial local ReleaseFast evidence improves the geometric mean by about
  `1.18x`, with exact plan/frequency/extra-bit checksums on every row; individual
  sparse or dense shapes can remain setup/layout-bound, so the gate protects the
  aggregate workload rather than claiming a universal per-shape win.
- Incremental best encoding now offers `low_entropy_block_len`, an explicit
  bounded buffering cap that expands a block only when its first normal-sized
  prefix contains at most four distinct bytes. This keeps ordinary text/source
  latency at `block_len` while amortizing repeated dynamic-tree headers for runs
  and tiny alphabets. On the 256 KiB single-byte corpus, a 32 KiB normal block
  with a 256 KiB low-entropy cap falls from `373` to `271` raw bytes, matching
  the one-shot Vort stream and narrowly beating the local zlib-ng level-6 raw
  result (`272` bytes). Tests pin the exact one-shot size, bounded option
  validation, round-trip behavior, and the zlib-ng gate now requires this row
  to match or beat the competitor rather than merely remain within a loose ratio.
- Split rolling-match hashing into `match_finder/hash.zig` and specialized the
  overwhelmingly common block-local path to hash contiguous 3/4-byte anchors
  directly; only the two history/block boundary anchors use joined access. A
  same-machine ReleaseFast before/after comparison on 256 KiB rows improved
  persistent JSON from about `988` to `1270` MiB/s, source from `1151` to `1425`
  MiB/s, and exact 32 KiB cross-window repetition from `352` to `441` MiB/s,
  without changing compressed sizes or CRC mixes. Hash-layout equivalence tests
  cover contiguous and boundary inputs, and the zlib-ng multi-corpus gate remains
  green; zlib-ng still leads the JSON/source rows by roughly `2x`. The gate uses
  32 iterations because 8-iteration sub-millisecond rows proved scheduler-noise
  sensitive despite identical bytes/mixes; the strict `>=1.0` geometric threshold
  remains unchanged.
- Incremental raw fixed/best state now owns a reusable token buffer alongside
  the persistent matcher. Rolling plans borrow that buffer instead of allocating
  a token list, converting it to an owned slice, and freeing it for every block;
  reset clears the length while retaining capacity. Encoder snapshots expose the
  retained capacity and tests pin its reuse plus byte-identical reset output. In
  the latest local 32-run zlib-ng comparison, source reached about `2268` MiB/s
  versus zlib-ng `2702` (remaining gap ~`1.19x`), repetitive `2300` versus `3058`,
  and cross-window `487` versus `67`, with unchanged sizes and CRC mixes.
- Rolling token emission now mirrors the one-shot parser's proven ArrayList
  shape: an inline capacity check writes with `appendAssumeCapacity` in the hot
  path, and only a true growth boundary calls allocator-backed `append`. This
  compounds the reusable token-buffer change without changing ownership or wire
  output. The latest 32-run local evidence reports about `2069` MiB/s JSON,
  `2211` source, `2277` repetitive, and `483` exact-window history; compressed
  sizes and CRC mixes are unchanged and the strict zlib-ng gate remains green.
- Rolling match planning now accumulates dynamic literal/length and distance
  frequencies plus length/distance extra-bit totals while it emits tokens. The
  incremental best writer consumes those cached statistics to construct its
  `DynamicCodingPlan`, eliminating the full token rescan before Huffman tree
  construction; non-rolling planners retain the original path. Formula tests
  cover every DEFLATE length `3...258` and distance `1...32768`, and wire sizes/
  CRC mixes remain unchanged. Latest 32-run evidence reports about `2079` MiB/s
  JSON versus local zlib-ng `2294` (remaining gap ~`1.10x`) and `2134` source
  versus `2637` (~`1.24x`); multi-corpus gate geomean reaches `1.933x` over the
  per-block rebuild baseline.
- Incremental dynamic statistics now retain active literal/length and distance
  symbol counts. `DynamicCodingPlan` uses those counts to decide single-symbol
  completion and whether a distance tree exists, avoiding the 286+30 frequency
  presence scans on every rolling block while leaving non-rolling planners on
  the reference path. Synthetic-symbol/wire tests and CRC/size evidence remain
  unchanged. The latest 32-run local comparison reports about `2224` MiB/s JSON
  (ahead of that run's zlib-ng `1878`), `2233` source versus `2768`, `2351`
  repetitive versus `3063`, and `487` cross-window versus `67`.
- Incremental match profitability now uses fixed-code lower/upper bounds before
  inspecting replaced literal bytes: if all 8-bit literals already pay the
  match it accepts immediately, and if even all 9-bit literals cannot pay it
  rejects immediately. Only the narrow ambiguous interval scans bytes. The
  proof is isolated in `match_finder/profitability.zig` with exhaustive
  representative byte/length/distance/savings comparison against the full scan.
  A same-machine 32-iteration before/after run improved persistent JSON from
  about `1394` to `1652` MiB/s, source from `1459` to `2087` MiB/s, and repetitive
  input from `1443` to `2225` MiB/s without changing compressed sizes or CRC
  mixes. The remaining local zlib-ng lead on JSON/source is now about `1.26x`/
  `1.28x`, down substantially from the earlier roughly `2x` gap.
- Candidate-chain traversal now prefetches the next source only when the hash
  head begins in the retained history window. An unconditional prefetch trial
  improved cross-window input but regressed JSON/source and was rejected; the
  history-only guard leaves their block-local chains untouched. Against the
  no-prefetch bounded-profitability baseline, the latest same-machine 32-run
  evidence moved JSON from about `1652` to `1669` MiB/s, source `2087→2155`,
  repetitive `2225→2270`, and exact-window repetition `376→479`, with identical
  sizes and CRC mixes. The multi-corpus zlib-ng gate remains strict and green.
- The incremental DEFLATE benchmark now reports staged `matcher-lazy` and
  `tree-emit` rows for the JSON/source corpora, using the same persistent
  matcher, retained 32 KiB history, token buffer, cached dynamic statistics,
  and bit writer as production. Token-count checksums keep staged work
  observable, while the emitted byte count must match the full encoder. In a
  local 32-iteration ReleaseFast run, matcher-only throughput was about `2874`
  MiB/s for JSON and `3908` MiB/s for source, tree planning plus emission was
  about `7081`/`8286` MiB/s, and the corresponding full paths were `1602`/
  `1646` MiB/s. This shows the remaining source gap is not a single Huffman
  emission hotspot: matcher and tree/emission together account for most but not
  all full-path time, so future optimization should measure stream buffering,
  history retention, and pending-output copying rather than blindly changing
  the match search.
- Expanded those staged rows with `history-retain`, `staged-pipeline`, and
  `stage-reset`, fixed the build target to forward caller iteration arguments,
  and made the gate require every staged row, equal token checksums, and staged
  output sizes matching production. The persistent benchmark now also reuses
  its scratch/output buffers between iterations so allocation noise is not
  misattributed to the encoder. A local 64-iteration sample measured source at
  about `2296` MiB/s end-to-end versus `2534` for the staged pipeline, `3983`
  for matcher-only, `8733` for tree/emission, and `38097` for history retention.
  This bounds the remaining stream-state/buffering overhead to roughly 9% of
  the staged pipeline on that run. Full-window buffer swapping and direct
  caller-input planning trials did not improve aggregate throughput (and the
  latter defeated low-entropy block coalescing), so both were rejected rather
  than adding complexity without reproducible benefit.
- Revisited direct caller-input planning with an explicit low-entropy guard and
  byte-identical buffered-path tests. Alternating 128/256-iteration A/B runs
  showed repeatable gains of roughly `4.5-4.9%` on JSON/source, about `0.4-1.0%`
  on binary and exact-window repetition, while low-entropy input deliberately
  stays on the coalescing path and retains its `271`-byte result. The direct
  path now avoids the `plain` copy only for contiguous non-final blocks with no
  adaptive split or lookahead; history remains caller-independent before
  `step` returns.
- The incremental DEFLATE benchmark accepts an optional corpus name after the
  iteration count, allowing long source-only or JSON-only matcher experiments
  without paying for unrelated competitor rows. A source-only `perf` profile
  confirmed rolling `findBest`/match-length as the largest Vort matcher hotspot
  and dynamic tree construction as the next major stage. Two plausible local
  changes—pointer-indexed match comparison and contiguous first-window seeding—
  were both rejected after 2048/4096-iteration A/B runs failed to show stable
  gains. The filter is retained as reproducible tooling; neither speculative
  matcher change remains in production.
- Added an optional Linux CPU index after the corpus filter for pinned
  incremental-DEFLATE measurements. This machine mixes 5.8 GHz performance
  cores with 4.3 GHz efficiency cores; unpinned 4096-iteration source runs had
  swung by more than 30% and obscured small A/B effects. Five consecutive
  2048-iteration source runs pinned to one selected logical CPU held full-stream
  throughput far tighter than unpinned runs, making subsequent matcher/tree experiments
  substantially more trustworthy without changing the default gate behavior.
  Profiling also ruled out two more speculative tree changes: adjacent dynamic
  stats were almost never identical (JSON 1/7, source 0/7), both corpora already
  fit the existing 64-symbol compact package-merge path, and neither a 96-symbol
  specialization nor an unconstrained-Huffman fast path produced a pinned
  source win; none remains in production.
- Rolling DEFLATE history/block match extension now compares 32-byte vectors
  before its existing 8-byte and scalar tails. The first differing-lane mask
  preserves exact byte offsets and removes three dependent word comparisons on
  long source-like matches. A focused oracle covers every mismatch position
  and every maximum length through 321 bytes with different slice offsets. In
  nine fixed-CPU-8, 4096-iteration A/B pairs, matcher-only medians improved by
  about 16% on JSON logs and 18% on source; stable end-to-end samples improved
  by roughly 10%, repetitive input by about 4%, and compressed bytes/checksum
  mixes remained identical. A whole-run source profile measured 2779.93 MiB/s
  versus local zlib-ng 2.3.90 at 2812.29 MiB/s, narrowing the remaining gap to
  about 1.2%.
- Added a byte-progressive raw-DEFLATE stored-block decoder under
  `src/deflate/incremental/decoder/`. It preserves split header state, streams
  payload directly caller-to-caller through tiny output, enforces exact/maximum
  output bounds before copying, and reports reserved type, LEN/NLEN, truncation,
  trailing input, and recoverability diagnostics without buffering a frame.
- Added a byte-progressive fixed-Huffman decoder with a persistent bit
  reservoir and partial canonical-code state. It handles arbitrary byte splits
  and tiny output without frame buffering, decodes split length/distance extra
  fields and overlapping copies through a caller-owned 32 KiB history ring, and
  enforces output limits/exact size before match execution.
- Unified stored and fixed block execution in that byte-progressive decoder.
  Stored LEN/NLEN and aligned payload state now share the same bit reservoir and
  caller-owned history ring, enabling mixed block streams without handing
  prefetched bytes between separate decoder objects.
- Began byte-progressive dynamic-Huffman parsing in the same state machine.
  HLIT/HDIST/HCLEN and the permuted code-length alphabet survive arbitrary input
  splits and validate RFC bounds/Kraft oversubscription. Code-length Huffman
  symbols and repeat codes 16/17/18 now build the complete literal/distance
  length arrays with persistent extra-bit state and validate EOB/table shapes.
  Dynamic literal/length and distance canonical codes now execute through the
  same split extra-bit and caller-owned history-ring match phases as fixed blocks.
- Added a byte-progressive zlib decoder wrapper over the unified raw core. CMF/FLG
  parsing, output Adler-32, split big-endian footer validation, exact/max output,
  trailing input, truncation, and FDICT diagnostics preserve caller-owned history
  and prevent raw bit prefetch from consuming wrapper footer bytes.
- Added preset-dictionary support to that wrapper. A split four-byte DICTID is
  checked against the supplied bytes before raw decode, the dictionary tail seeds
  the caller-owned 32 KiB history ring, and missing/wrong dictionaries report
  `NeedDictionary` with retry diagnostics.
- Added a byte-progressive single-member gzip decoder. It composes the unified
  raw decoder one byte at a time, validates streaming CRC-32 and ISIZE from a
  split footer, and incrementally parses/skips bounded FEXTRA, FNAME, FCOMMENT,
  and FHCRC fields with header CRC validation and truncation diagnostics.
- Extended the byte-progressive gzip decoder with opt-in concatenated-member
  traversal. Member headers, DEFLATE history, CRC-32, and ISIZE reset at each
  boundary while stream input/output accounting, exact-size and output limits
  remain cumulative; snapshots expose validated member counts and later-member
  corruption/truncation retains the completed-member context.
- Extended those snapshots with the active or last validated member index, its
  compressed-stream offset and local input progress. Failure snapshots retain
  the failing member index/offset, phase, and cumulative detection offset across
  split headers, payloads, and footers, and reset clears all error context.
- Added a bounded split-input Brotli incremental facade under
  `src/br/incremental/`. It accumulates compressed fragments under an explicit
  limit, performs complete supported-stream preflight and decode at `finish`,
  enforces optional exact/maximum output lengths, then drains through arbitrary
  caller-owned output slices with shared progress, reset, snapshot, and
  diagnostics semantics. The narrow codec interface leaves the 13k-line Brotli
  facade unchanged except for a small adapter and keeps the state machine ready
  for a future byte-progressive compressed meta-block core.
- Added a true byte-progressive Brotli decoder for the stored/uncompressed
  subset under `src/br/incremental/stored/`. It preserves bit-level window and
  meta-block header state across arbitrary one-byte input splits, skips metadata
  without retaining it, and copies aligned payload bytes directly from caller
  input to arbitrarily small caller output. Output limits, compressed-block
  rejection, padding validation, explicit finish/truncation, reset, snapshots,
  and diagnostics are covered in the colocated module tests.
  After a finished stream it can continue another independently framed stored
  stream with new limits through `nextStream`; cumulative compressed/output
  byte counts and stream count/index remain visible without allocating. Tests
  switch window bits and metadata across frames and exercise the root facade.
  Callers may now provide bounded metadata scratch to the byte-progressive
  stored decoder. Metadata remains excluded from content output, but snapshots
  expose captured and total metadata bytes plus truncation; split metadata can
  therefore be inspected without hidden allocation or unbounded retention. A
  second caller-owned slice captures per-meta-block lengths and independently
  reports boundary truncation, so multiple metadata events remain distinguishable.
- Added the matching incremental stored Brotli encoder under
  `src/br/incremental/stored/encoder.zig`. It preserves bit-writer state across
  metadata and multiple configurable meta-blocks, buffers only one block of
  caller input, drains encoded bytes through tiny caller output, and supports
  input limits, explicit finish, reset/reuse, and snapshots. Split-input,
  multi-block, metadata, and window-bit round trips use the production decoder.
  It can now start independent streams with new window/metadata/block options
  through `nextStream`, retaining allocations and cumulative byte/count/index
  diagnostics. Tests decode both differently configured outputs and cover the
  root public facade.
  `writeMetadata` can insert additional metadata meta-blocks after previously
  accepted content, drain them through tiny output, and resume content in the
  same bitstream. Caller metadata remains borrowed only until `need_input`; a
  payload-metadata-payload round trip validates captured event bytes/boundary.
  Snapshots expose pending metadata length and flush state, while duplicate or
  post-finish requests fail deterministically.
- Added the first production compressed Brotli encoder slice for single-byte
  runs. `encodeRleStream{Alloc,Append,Into}` emits a real compressed meta-block
  with one seed literal plus a direct-distance-one copy, rejects non-runs rather
  than pretending to be a general encoder, and provides a conservative bound.
  A 4096-byte run encodes to 12 bytes, round-trips through Vort, and decodes
  successfully with Node v26's Brotli implementation. The reproducible
  `run-br-rle-node-diff` gate now generates production API output, decodes it
  with Node, checks all 4096 bytes, and protects a minimum 16x ratio win. The
  same gate now covers the first externally proven distance-copy production
  slice, `encodeAbabaStreamAlloc`, derived from the existing Node/Vort fixture
  and yielding an 11-byte interoperable compressed stream. The parameterized
  `encodeAbabaPatternStreamAlloc(first,second)` supports any distinct byte pair;
  both ASCII and binary `00 ff 00 ff 00` patterns pass Vort and Node decoding.
  The same externally gated command shape now covers alternating lengths
  `5...16777216` through `encodeAlternatingStreamAlloc`; copy-length extra bits and
  command symbols are selected from the upstream-verified LUT, and every odd
  and even length uses the matching two-byte seed/copy pattern. Representative
  command and meta-block-length boundaries are Node-gated. `encodeSimpleStream` selects
  these patterns automatically and otherwise retains its stored fallback.
  `encodeSimpleStream` provides a safe general entry point over this initial
  slice: eligible runs use compressed RLE, while all other inputs deterministically
  fall back to the mature stored encoder. Alloc/append/into/bound and root APIs
  therefore improve useful ratios without narrowing accepted input.
- Replaced the compressed Brotli decoder's hand-simplified command-range logic
  with a generated 704-entry table from upstream `dec/prefix_inc.h`, including
  exact insert/copy bases, extra-bit widths, distance-code mode, and context.
  All unit tests, the production RLE/alternating Node gate, and the 225-case
  Vort/Node literal differential suite remain green, establishing a trustworthy
  oracle for the next general command encoder slice.
  A focused interleaved benchmark compares the generated table with the exact
  upstream construction formula across all 704 symbols. The first local
  ReleaseFast run measured about `11.6 ms` versus `310.7 ms` for 16384 sweeps
  (`~26.8x`), so production retains the verified table rather than recomputing.
- Added the first production multi-command Brotli encoder slice.
  `encodeRepeatedPrefixStreamAlloc` encodes distinct two-, three-, or four-byte
  seeds and subsequent non-overlapping copies as separate command symbols up to
  the 16 MiB meta-block limit, using the verified command LUT and direct seed
  distance. Representative 2/3/7/31-repeat streams, including binary seeds,
  round-trip through Vort and the Node interoperability gate. The simple
  encoder now detects exact three- and four-byte repetitions through the focused
  `src/br/pattern.zig` helper (two-byte repetitions retain the smaller alternating
  stream); this establishes command-tree emission and repeated command sequencing
  needed by a future general match planner.
- Added the first planner-backed Brotli command encoder under
  `src/br/encoder/command_plan.zig`. The shared LZ77 hash matcher now feeds a
  validated insert/copy command plan; production encoding emits simple literal,
  command, and direct-distance trees whenever each alphabet contains at most
  four symbols and distances fit the initial direct range. A mixed literal/copy
  payload (`abcabcX...`) compresses from 21 to 16 bytes and passes both Vort and
  Node decoding. `encodeSimpleStream` selects this planned path when supported
  and retains the stored fallback for plans that need broader Huffman trees or
  broader Huffman trees. The planner now uses the normal 32 KiB LZ77 window;
  `src/br/encoder/distance.zig` inverts Brotli's regular-distance formula and
  emits the matching extra bits beyond the 15 direct distances. A gated
  distance-42 payload compresses from 82 to 18 bytes and round-trips through
  both Vort and Node.
  Planner prefix alphabets now expand from four to the full 256-byte literal
  literal alphabet and all 704 command symbols through the focused
  `src/br/encoder/complex_prefix.zig` writer. It emits valid Brotli
  complex prefix trees and `src/br/encoder/code_length_rle.zig` chains symbol-17
  zero runs across sparse literal/command/distance alphabets and symbol 16
  chains repeated non-zero lengths. The code-length tree is frequency-built
  rather than fixed. The seven-literal fixture is 20 bytes for 39 source bytes,
  the 16-literal fixture is 23 for 128, and a full 0...255 alphabet repeated
  three times is 276 for 768; all pass Node. Broader command/distance alphabet
  stress now includes real-shape JSON, Zig source, and log corpora through
  `run-br-planned-corpus` plus the independent `run-br-planned-node-diff` gate.
  Their first results are respectively 92/2640, 131/3600, and 125/3320 encoded
  versus source bytes. Command alphabets up to 704 entries are now representable;
  further prefix-cost optimization and heterogeneous corpus expansion remain
  follow-up work.
  Complex-prefix code-length RLE now writes into a fixed 704-token stack buffer,
  whose size is the trivial worst-case bound (one output token per input length),
  eliminating three temporary heap allocations per planner stream. The bounded
  encoder is byte-for-byte tested against the allocating reference. Header time
  fell from roughly 12–19 µs to 4.7–9.6 µs on JSON/source/log; short A/B reached
  87/100/101 MiB/s with unchanged 92/130/122-byte output.
  Complex-prefix RLE stack storage is now specialized to the actual alphabet
  class (256 literal, 520 distance, 704 command) instead of reserving 704 tokens
  for every tree. This reduces stack/cache pressure without changing tokens or
  wire. A clean 100-iteration run measured 158/182/188 MiB/s for JSON/source/log
  versus libbrotli q3 at 352/328/435 MiB/s.
  A ReleaseFast interleaved encoder A/B against runtime libbrotli 1.1.0 quality
  3 is available through `run-br-planned-encode-bench{-gate}`. The persisted
  100-iteration gate sample measured Vort/reference ratios of `0.101x`, `0.159x`,
  and `0.127x` throughput, with size ratios `1.484x`, `1.523x`, and `1.437x` for
  JSON/source/log.
  This is explicit evidence that planner-backed encoding is now functional on
  these shapes but still trails the industry reference in both speed and ratio.
  Switching sub-32-KiB inputs from heap-backed hash tables to the existing
  stack-table LZ77 planner preserves byte-identical output and raises the
  persisted 100-iteration throughput ratios to `0.186x`, `0.236x`, and `0.214x`
  (38.0/47.7/52.9 MiB/s). A focused max-chain 8 experiment did not improve the
  interleaved result and was rejected, so the production search budget remains
  unchanged.
  A caller-owned scratch API (`encodePlannedStreamWithScratchAlloc`) now bounds
  all planner intermediate allocations and returns only final bytes through the
  caller allocator. It is intended for allocation control/reuse; an A/B trial
  found it slower than the ordinary allocator path on the current small corpus,
  so production convenience encoding and throughput benchmarks retain the faster
  default path.
  `PlannedStreamEncoder` now owns typed reusable LZ77-token and Brotli-command
  buffers; retained capacity is observable and outputs remain independently
  owned. It replaces the initial arena prototype and is benchmarked after a
  warmup call. The persisted 100-iteration run measured 37.4/43.4/56.7 MiB/s
  for JSON/source/log; this is roughly neutral/noisy versus the default path,
  so reuse is exposed primarily to bound allocation churn rather than claimed
  as a throughput win.
  Planner alphabet collection now accumulates fixed literal/command/distance
  frequency arrays and compacts them once, replacing the former per-symbol
  linear search through up to 704 entries. The persisted 100-iteration sample
  improved source/log throughput from 47.7/52.9 to 61.8/56.6 MiB/s while JSON
  measured 42.4 MiB/s; output remains byte-identical.
  The shared Brotli bit writer now packs up to the remaining byte width per loop
  instead of iterating once per bit. Known-byte stored fixtures and all planner
  wires remain identical. Short interleaved samples rose to 114.5/123.1/128.8
  MiB/s; the longer 100-iteration run remained scheduler-sensitive (104.0/56.5/
  50.3 MiB/s), so the change is retained for its deterministic reduction from
  O(bits) to O(bytes) writer work rather than a single claimed multiplier.
  Planner output now reserves a capped `max(input/8,64)` bytes (up to 4 KiB)
  before header emission, avoiding the early ArrayList growth ladder. The latest
  100-iteration sample measured 44.2/90.8/93.7 MiB/s for JSON/source/log with
  unchanged 92/131/125-byte streams; JSON remains scheduler-variable while the
  source/log improvement is consistent with fewer output reallocations.
  Wire-stage subprofiling splits frequency collection, alphabet compaction,
  package-merge lengths, complex header, canonical encoder setup, and payload.
  On JSON/source/log the dominant pieces are lengths (10.6–15.9 µs) and header
  (12.1–18.6 µs), while payload emission is only 1.8–2.6 µs. PrefixAlphabet
  therefore runs package-merge directly on 32/64/256-sized compact frequency
  arrays and scatters once, avoiding full 704/520 sparse compaction. Besides
  lowering length-build time, this improved source/log wire sizes from 131/125
  to 130/122 bytes; Node and corpus gates accept the new deterministic wire.
  For the currently dominant <=64-symbol alphabets, a focused heap-based Huffman
  builder now computes unconstrained optimal depths in O(active²) over compact
  nodes and falls back to package-merge only if depth exceeds Brotli's 15-bit
  limit. Length time dropped to roughly 6.7–8.3 µs, with wires unchanged. Short
  A/B reached 108/123/119 MiB/s; the persisted 100-iteration sample measured
  99/70/120 MiB/s for JSON/source/log under the noisy mixed-core environment.
  The small-tree builder now maintains its active nodes in a binary min-heap
  keyed by the same `(weight,serial)` order, reducing construction from O(n²)
  scans to O(n log n) without changing depths or wire. Focused length time fell
  further to about 4.0–6.1 µs; a clean 100-iteration run measured stable
  102/118/118 MiB/s versus libbrotli q3's 315/289/376 MiB/s.
  Command selection no longer scans all 704 upstream LUT entries for every
  planned match. A compile-time 24×24 insert/copy-code index retains the first
  exact upstream symbol for O(1) lookup; an exhaustive equivalence test covers
  both ends of every LUT range. The latest 100-iteration sample measured
  49.1/42.8/73.8 MiB/s for JSON/source/log with byte-identical output; variance
  remains high enough that this is recorded as a structural hot-path reduction,
  not an across-the-board speed claim.
  Insert/copy length-code selection is now a direct RFC range mapping rather
  than a 24-entry scan per query. Boundary tests cover both ends of all 48
  insert/copy ranges plus out-of-range rejection; command/LUT and corpus output
  remain byte-identical. The attempted token-cursor removal of the command plan
  regressed the stable A/B and was fully reverted, preserving the faster typed
  command representation.
  `run-br-planned-stage-profile` now records token/command/alphabet shape plus
  optional in-process LZ77/command/wire timing. Initial profiles put wire and
  Huffman construction at 61–71% after optimization (previously 66–78%), versus
  20–30% LZ77 and 7–15% command planning. Passing precomputed code lengths from
  payload encoder construction into complex-prefix header writing removes three
  duplicate package-merge builds. The persisted 100-iteration sample improved
  to 79.3/87.8/89.2 MiB/s for JSON/source/log with identical sizes.
  The transient `PlannedWireCommand[]` materialization is removed: frequency
  collection and final emission now derive indexed command/distance metadata
  directly from the typed command plan in two passes. This eliminates one
  allocation and one command-sized copy while preserving byte-identical wire;
  short A/B samples improved, but the 100-iteration run remained scheduler-noisy
  and is therefore recorded as a structural allocation reduction only.
  Symbol-16/17 repeat-chain inversion now derives the unique extra value from
  `(current-3) & (radix-1)` and computes the predecessor directly, replacing an
  inner 4/8-way modulo search at every RLE chain level. An exhaustive run test
  covers both radices through 703 symbols; all planner wires remain unchanged.
  Complex-prefix validation and trailing-zero discovery now share one forward
  pass (`validatedStopIndex`) instead of validating the full alphabet and then
  scanning backward. Focused header time is 3.5–5.8 µs for source/log and about
  13 µs for JSON; 20-iteration A/B reached 102/116/116 MiB/s, with unchanged
  planner streams and successful Node decoding.
  `PrefixAlphabet` is an approximately 11 KiB full-command-space value. Its
  code-length and header helpers now take const pointers rather than copying
  three alphabets by value. Focused JSON alphabet time fell from roughly
  19–21 µs to about 10 µs with unchanged wire; short A/B reached 92/103/122
  MiB/s for JSON/source/log.
  Planner payload setup now bypasses full 704/520 length arrays and canonical
  encoders for simple command/distance alphabets (<=4 symbols), deriving the
  exact canonical reversed codes directly from the already ordered alphabet.
  Direct/generic code equivalence is tested for 2–4 symbols. A clean 100-run
  sample measured 139/155/166 MiB/s versus libbrotli q3 at 231/234/283 MiB/s,
  with unchanged 92/130/122-byte streams.
  A ratio-oriented `encodePlannedStreamLazyAlloc` now shares the same wire path
  with the lazy LZ77 parser. Adjacent copy tokens with zero intervening
  literals and the same distance are now coalesced into one Brotli command;
  this is exact even for overlapping matches and removes the artificial
  258-byte limit inherited from the shared DEFLATE-oriented LZ77 tokens. On
  JSON/source/log it now emits 62/91/83 bytes versus
  the fast planner's 92/130/122 and libbrotli q3's 62/86/87. The persisted
  size gate locks these results: JSON matches libbrotli, log is four bytes
  smaller, and source is within six percent. A focused command-plan test covers
  both allocating and reusable builders; both modes remain Node-gated. Ten
  interleaved 1000-iteration runs also improved balanced JSON/source/log
  throughput by about 5.5%/6.4%/3.8%, because fewer commands shrink both
  planning and wire-emission work.
  The balanced planner additionally evaluates replacing each isolated
  three-byte copy with literals. This exact, bounded local search captures tree
  overhead that the fixed-bit LZ77 profitability model cannot see; it reduces
  the locked log stream once more from 83 to 82 bytes while JSON/source stay at
  62/91. The size gate now pins 62/91/82, respectively.
  For small plans with up to four three-byte matches, balanced mode now also
  enumerates every non-empty subset to literalize and keeps only a strictly
  smaller complete stream. This catches interactions between command, distance,
  and literal trees that no per-match estimate can prove: removing the first
  two isolated source matches reduces 91 to 88 bytes. A second bounded candidate
  now literalizes one dense leading run of at least three copies no longer than
  five bytes; removing the source plan's first four copies reaches 84 bytes, two
  bytes below libbrotli q3. This stronger structural candidate supersedes the
  three-byte subset enumeration for matching plans, so source needs only one
  alternative full-stream encode instead of four. The transformation uses
  original command indexes, preserves later absolute insert positions/distances,
  and has focused candidate-selection and multi-removal tests.
  Stable public planner options now expose `.fast` and `.balanced` compression
  levels through `encodePlannedStreamWithOptionsAlloc`; `.balanced` maps to the
  proven lazy parser and is tested to round-trip with size no worse than fast.
  The same API now exposes an explicit `.ratio` level (and direct
  `encodePlannedStreamRatioAlloc` helper) with a 512-chain, 258-byte nice-match
  budget. On twelve 128 KiB Silesia prefixes it improves the aggregate balanced
  size from 560,528 to 555,446 bytes before command coding. Ratio mode also
  evaluates a second complete stream that maps recent copy distances to Brotli's
  16 short codes, including the implicit last-distance command form, when at
  least 64 commands qualify, keeping it only when smaller. The threshold avoids doubling tiny-input wire
  work while retaining every measured material win. On
  the same corpus this reduces aggregate output again to 551,235 bytes, 6.95%
  below libbrotli quality 3; representative `mozilla`/`nci`/`xml` rows fall from
  22,472/10,699/9,909 to 21,478/10,065/9,545 bytes. `mozilla` remains the only
  measured loss at 0.97%, while every other row is protected by exact
  full-stream arbitration and every selected stream passes libbrotli decoding.
  Ratio mode additionally evaluates one UTF-8 literal-context split that maps
  contexts 56...63 (lowercase-letter history) to a second Huffman tree. Its
  compact contiguous map and complete-stream arbitration reduce the same
  Silesia aggregate again to 549,017 bytes, 7.33% below libbrotli q3, and turn
  `mozilla` into a nine-byte win (21,262 versus 21,271 bytes). This is a single
  bounded entropy candidate rather than an input-specific multi-threshold scan.
  The fixed 56-zero/eight-one context map now uses Brotli zero-run RLE instead
  of emitting 64 raw map bits, reducing the aggregate another 53 bytes to
  548,964 bytes and the `mozilla` row to 21,256 bytes.
  It also subsumes the weaker recent-distance-only candidate on the measured
  corpus, so ratio mode now encodes only the explicit baseline and the combined
  recent-distance/context alternative rather than materializing three streams.
  When that combined candidate is already at most 80% of input, ratio mode
  returns it directly: its margin exceeds every measured tree-interaction loss,
  avoiding the baseline wire pass on the compressible Silesia rows. Fixed-CPU
  A/B improved `mozilla`/`nci`/`xml` by about 14.7%/10.3%/11.7% with identical
  output.
  This level is intentionally separate because four
  representative fixed-CPU samples traded roughly 1.6–2.4x encode time for the
  additional 0.8–4.2% size reduction.
  The lazy planner also exposes an explicit search-budget options API and a
  reproducible `run-br-lazy-sweep` target. All 24 combinations across chain
  budgets 64–512, nice lengths 64–258, and lazy gains 1–2 retained the same
  77/116/106-byte corpus streams. A pinned, interleaved 1000-iteration A/B
  therefore reduced the balanced default from chain/nice 256/128 to 64/64:
  JSON improved by about 8%, while source/log stayed within 0.3% noise.
  The planner wire path now also supports RFC 7932 built-in static-dictionary
  commands, including transformed-output length versus base copy length and
  distance addressing. An experimental exhaustive reference planner compresses
  dictionary-heavy input without depending on libbrotli and is externally
  decoded by Node; stable levels await an indexed matcher before enabling it.
  A caller-owned 15-bit base-word index now reduces lookup to 13,504 entries
  and verifies all 121 transforms through the independent transform routine.
  Differential tests match the exhaustive reference and the 146,560-byte
  memory budget is enforced by the Node compatibility gate.
  PrefixAlphabet's small-active insertion sort now caches the candidate pair and
  shifts predecessors instead of swapping both parallel arrays at every step.
  It preserves the exact `(frequency desc,symbol asc)` order and wire while
  reducing typical alphabet time to roughly 6–7 µs. A clean 100-iteration sample
  measured 104/166/143 MiB/s for JSON/source/log.
  Alphabet compaction now fills caller-owned PrefixAlphabet objects through an
  out-parameter instead of returning/copying ~11 KiB values. Focused alphabet
  time is about 7–8 µs; short A/B reached 117/133/134 MiB/s while source/log
  100-iteration samples reached 123/169 MiB/s (JSON remained scheduler-noisy).
