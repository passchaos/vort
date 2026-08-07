# Vort roadmap

This roadmap is a living checklist toward the larger goal: outperform and
out-feature `zlib`, `zlib-ng`, `zlib-rs`, and `zstd` without copying their
architecture blindly.

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
- [x] Dashboard strict-mode smoke covers every validation unhealthy reason with isolated negative fixtures.
- [x] Dashboard strict-mode validation unhealthy reason matrix is stored in a schema-checked external JSON config.
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

- Added a dependency-free Brotli `br` bootstrap module for stored/uncompressed
  streams. `src/br.zig` emits RFC-valid WBITS=16 streams with uncompressed
  meta-blocks plus final empty terminators, decodes the same stored subset with
  output limits and trailing-data checks, and exposes root/CLI smoke APIs. This
  is intentionally a first compatibility slice, not full Brotli Huffman/LZ77
  support yet.

- Added a dependency-free Snappy raw block module. `src/snappy.zig` covers the
  raw block varint length header, literal tags, copy1/copy2/copy4 decode,
  decoded-size preflight, output limits, caller-owned output, allocator-returning
  helpers, and a literal-compatible encoder. The CLI and
  `run-snappy-block-cli-probe` cover hex and file workflows without depending on
  a system Snappy library. Framed Snappy streams remain a follow-up format slice.

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

- Added five-block-type coverage for Brotli literal and distance block
  switching. The compressed literal-switch smoke walks to the fifth literal block
  type, while the distance-switch smoke walks to the fifth distance block type
  and selects its distance tree. Both frames are covered by Zig tests and the
  Node-backed CLI differential smoke.

- Added fifth-distance-context-tree coverage for Brotli compressed decode. The
  distance context map can now be proven to select tree index four for copy-length
  context one (`copy_len = 3`), with both Zig tests and the Node-backed CLI
  differential smoke decoding the same frame.

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
