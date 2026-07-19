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
- [x] Portable CRC32C slice-by-16 fallback selected when hardware CRC32C is unavailable.
- [x] Runtime checksum dispatch API selecting portable fast path.
- [x] Adler-32, CRC-32, and CRC-32C combine helpers compose independently checksummed blocks without rereading payload bytes.
- [x] Adler-32 update uses 64-byte vector folding for zlib wrapper throughput.
- [x] CPU feature/dispatch report tool.
- [x] x86 checksum CPU feature reporting with IEEE-vs-CRC32C safety distinction.
- [x] x86 SSE4.2 CRC32C hardware path selected by dispatch.
- [x] Architecture-specific IEEE CRC32 dispatch plan and safety gates.
- [x] x86 PCLMUL candidate reporting for future IEEE CRC32 dispatch.
- [x] ARM CRC32 feature reporting for future IEEE CRC32 dispatch.
- [x] Architecture-specific IEEE CRC32 implementation / dispatch.
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
- [x] Concatenated gzip alloc decoder exposes an exact-size variant.
- [x] File CLI and Python differential smoke cover raw deflate file decode with output limits.
- [x] File CLI and Python differential smoke cover raw preset-dictionary file decode.
- [x] File CLI and Python differential smoke cover raw preset-dictionary one-shot/split/adaptive file encode.
- [x] zlib/gzip wrappers reject truncated non-final raw deflate streams across stored/fixed/dynamic blocks.
- [x] zlib wrapper and Adler verification for stored blocks.
- [x] zlib decode option APIs can ignore Adler-32 and/or allow trailing data
  while preserving strict defaults for PNG compatibility and relaxed-reader
  integrations.
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
- [x] ZlibDecoder direct chunk initializers decode multi-IDAT-style zlib chunks
  without requiring a compressed join scratch buffer.
- [x] ZlibDecoder direct chunk initializers include strict, relaxed-option,
  exact-size, and preset-dictionary variants without compressed join scratch.
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
- [x] PNG scratch footprint report records caller-owned zlib/row/output memory baselines for non-interlaced and Adam7 PNG-like paths.
- [x] ZlibDecoder chunk initialization supports preset dictionary zlib streams without allocation.
- [x] ZlibDecoder exact-size initializers reject decoded-size mismatches for PNG/IHDR-sized buffers.
- [x] ZlibDecoder reports bad-header, missing-dictionary, truncated-footer, and Adler mismatch diagnostics.
- [x] gzip wrapper and CRC/ISIZE verification for stored blocks.
- [x] gzip optional header fields: FEXTRA, FNAME, FCOMMENT, FHCRC validation.
- [x] gzip encoders can emit configurable MTIME/XFL/OS plus FEXTRA/FNAME/FCOMMENT/FHCRC metadata while preserving deterministic defaults.
- [x] Public gzip header metadata parser exposes MTIME/XFL/OS/FEXTRA/FNAME/FCOMMENT/FHCRC slices for library callers.
- [x] GzipDecoder drains validated gzip-wrapped deflate payloads and caller-provided gzip byte chunks through reusable caller-owned scratch and bounded output.
- [x] GzipDecoder drains concatenated gzip members, including empty middle members, from caller-owned scratch and chunked compressed input.
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
