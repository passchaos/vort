# Vort roadmap

This roadmap is a living checklist toward the larger goal: outperform and
out-feature `zlib`, `zlib-ng`, `zlib-rs`, and `zstd` without copying their
architecture blindly.

### Current completion audit (2026-09-05)

The long-term objective is **not complete**. Current evidence still leaves these
major gaps before Vort can claim broad industry-best parity:

- Full libbrotli-class general-purpose compression is not implemented. The
  production encoder now covers stored streams, compressed-or-stored
  planner-backed LZ77/Huffman streams, bounded multi-meta-block input, and a
  vetted static-dictionary subset, but still lacks libbrotli's complete adaptive
  block splitting, context modeling, and quality/ratio range.
- True byte-progressive Brotli decoding now covers stored data, metadata,
  insert-only Huffman literals, compressed RLE, copy commands, context maps,
  entropy block switching, static dictionaries, consecutive compressed
  meta-blocks, and the full 256 literal/command/distance block-type ranges.
  Arbitrary upstream Brotli streams still need broader corpus coverage, and the
  general fallback facade buffers a bounded complete payload.
- Incremental DEFLATE source and JSON throughput now reach or exceed the local
  zlib-ng level-6 comparison on the locked 256 KiB fixtures, while broader
  real-corpus, ratio, memory, and cross-platform parity still needs evidence.
- COVER/FastCover-class history selection and broader Zstd entropy-mode parity
  still require completion and competitor evidence.
  Vort can now wrap caller-selected history in a dependency-free standard full
  dictionary, train its complete 256-symbol literal Huffman table from sample
  bytes, and train its OF/ML/LL FSE tables from dictionary-aware LZ77 sequence
  codes. Its repcode trainer now ranks the first two explicit offsets and keeps
  a retrained candidate only after an actual forced-compressed corpus-size win
  of at least 1%; ties and sub-threshold changes retain baseline `1/4/8`. This
  does not claim COVER/FastCover equivalence.
  Standardized seek-table parsing/
  iteration, one-shot encoding, checksum-aware range decode, and
  dictionary-aware encoding/range decode are also in place.
- Cross-platform optimized kernels and reproducible competitor measurements are
  not yet comprehensive enough for a blanket performance-leadership claim.

The libbrotli-generated compatibility matrix now also includes 7,056 one-shot
frames spanning four deterministic entropy shapes, seven payload sizes from one
byte through 64 KiB, all qualities 0...11, generic/text/font modes, and window
bits 10/12/16/18/20/22/24. Every frame decodes byte-exactly through Vort's
public allocating decoder and through the byte-progressive decoder with
17-byte input and 31-byte output chunks. This broad sweep complements the
deeper flushed, metadata, context-tree, 256-block-type, large-header, and full
chunk-matrix fixtures; it strengthens decoder evidence without implying
equivalent encoder quality or speed.
The same differential accepts repeatable `--real-file` inputs with a bounded
`--real-limit` prefix, so local upstream and application checkouts can extend
coverage without becoming repository dependencies. A first fixed-CPU run over
1 MiB prefixes of Godot C source, Qwen tokenizer JSON, OpenCV XML, and an
OpenType font passed all 16 representative q0/q4/q8/q11, generic/text/font,
window-10/16/20/24 one-shot and 17-byte-input/31-byte-output progressive cases
against libbrotli 1.1.0. The build step now forwards arguments to the probe,
and its summary reports real-corpus counters so an accidentally ignored corpus
cannot appear green.

The next highest-value deliverable is broader real-corpus and cross-platform
Brotli decoder evidence, followed by the remaining general Brotli encoder
features and ratio work. Performance work should then resume on the profiled
DEFLATE matcher/tree stages with pinned, interleaved A/B evidence.

One-shot planned Brotli encoding now accepts an explicit 10...16-bit window at
all fast/balanced/ratio levels, plus 17...24-bit windows at ratio level. The
advertised window, matcher distance bound,
optimal-parser proposal, static-dictionary candidate, stored fallback, size
bound, reusable encoder, and caller-buffer path use one policy. Tests cover all
21 level/window combinations, stored fallback, invalid 9/17-bit requests, and
the 1,008/1,009-byte WBITS=10 distance boundary. The runtime libbrotli 1.1.0
differential independently decodes those combinations, six 10/11-bit boundary
frames, one 80 KiB-distance 17-bit frame, one 160 KiB-distance 18-bit frame,
one 320 KiB-distance 19-bit frame, one 640 KiB-distance 20-bit frame, and one
1.25 MiB-distance 21-bit frame, one 2.5 MiB-distance 22-bit frame, and one
5 MiB-distance 23-bit frame, and one 10 MiB-distance 24-bit frame
(`planned_window_cases=35`).
Omitting the option remains byte-identical for all
three levels, and the existing eight-row planned encode gate stays green. Full
Ratio planned matching, stored encoding, and decoding now all expose the
complete RFC 10...24 window range.
The Brotli-only long-distance matcher now accepts an explicit maximum distance
through 1,048,560 bytes and sizes its predecessor ring to the active distance
band: the default 17-bit path retains its 65,536-entry/256 KiB ring, while an
18/19/20-bit requests use 262,144/524,288/1,048,576 entries (about 1/2/4
MiB). All three exact maximum distances have matcher oracles; 160/320/640 KiB
whole-frame fixtures are substantially smaller than their next-narrower
counterparts and decode through both Vort and libbrotli. WBITS=20 is the final
dense-ring tier. WBITS=21 uses a compile-time stride-two predecessor index,
keeping its ring at 1,048,576 entries/about 4 MiB while covering the complete
2,097,136-byte legal distance range. WBITS=22 uses stride four with the same
memory cap and covers distances through 4,194,288 bytes. Non-zero source phases
retain at most `stride-1` leading literals before using the sampled phase;
focused oracles cover the stride-two and worst stride-four cases. Windows
WBITS=23/24 use stride eight/sixteen with the same 4 MiB ring cap and have
exact-limit plus worst-seven/fifteen-byte-phase oracles. Fifteen
alternating fixed-CPU-30 default-path pairs preserved the 20,788-byte wire and
checksum 1,446,304; median ratio time was 133.43 ms versus 133.06 ms baseline
(`0.9973x`), within the retained non-target floor.
The one-shot chunked planned surface now matches the stored and incremental
stream option model: bound/alloc/append/into and reusable-scratch APIs accept
10...24-bit windows plus an initial metadata meta-block. Each independently
planned block caps matcher distance at `2^WBITS-16`; all 15 windows, metadata
accounting, output forms, invalid windows, and the 1,008/1,009-byte boundary
have direct tests. Four representative window/metadata streams also decode
byte-exactly through libbrotli (`planned_chunked_window_cases=4`), while the
default chunked size/performance gate remains unchanged.
Explicit-window ratio inputs larger than Brotli's 2^24-byte meta-block limit
now reuse that options-aware bounded multi-meta-block compressor instead of
falling back to an all-stored stream. WBITS=10 and WBITS=24 tests on a
16 MiB+17-byte repetitive input both retain the requested header, emit at least
two compressed meta-blocks, remain below 1% of the input size, and round trip.
The upstream differential independently decodes both frames through libbrotli
1.1.0 (`planned_large_window_cases=2`).
One-shot `PlannedEncodeOptions` now also carries an optional initial metadata
meta-block at fast, balanced, and ratio levels. Metadata participates in each
complete compressed candidate and the stored fallback before exact-size
arbitration, so the selected wire and conservative bound remain consistent.
Tests cover all three levels, WBITS=10/24, caller-buffer and reusable output,
byte-progressive metadata capture, short-input stored fallback, a winning
static-dictionary candidate, an automatic 17-bit long-distance winner, and the
65,536-byte metadata limit. libbrotli 1.1.0 independently decodes all five
generated payloads (`planned_metadata_cases=5`); omitting metadata preserves established wire
bytes and the existing performance gates.
Ratio one-shot encoding now also exposes an opt-in
`extended_dictionary_probes` budget for 257-byte through 4 KiB inputs. The
default remains zero and therefore preserves the established 256-byte
automatic dictionary gate byte-for-byte; non-zero budgets are accepted only
for ratio mode, are capped by `max_extended_dictionary_probes` (4096), and
reject larger inputs rather than silently skipping the requested work. Both
existing LZ plans and literal-only plans can be augmented, but the search
examines at most the requested number of literal positions and the resulting
candidate is retained only when its complete metadata-inclusive Brotli wire is
strictly smaller. Full dictionary scans through 4 KiB were rejected after
raising ratio latency by roughly 3x to 23x. A 64-probe experiment instead
reduced seven of eight real 4 KiB source/HTML/XML/JSON prefixes (representative
changes include 1166 to 1156, 1752 to 1729, and 357 to 350 bytes), left the
eighth unchanged after final arbitration, and preserved WOFF2/OTF/PNG control
wires. The option remains explicitly opt-in because even bounded probing adds
material ratio latency on some small text shapes. Three fixed-CPU interleaved
default-path A/B rounds kept all seven stable built-in wire fields identical;
the aggregate speed ratio was 1.0767x and the weakest control row was 0.9942x.
The runtime libbrotli 1.1.0 differential independently decodes the retained
extended-dictionary stream (`planned_extended_dictionary_cases=1`).
The planned encode benchmark now accepts an explicit dictionary-probe budget
for direct measurement of this opt-in path. Static-dictionary indexing was
audited against the locally available upstream Brotli matcher. The current
146,560-byte base-word index does not discover every omit-first, short
omit-last-plus-suffix, or non-ASCII uppercase transform shape. Complete
supplemental-index prototypes were rejected because they increased memory to
roughly 0.5--0.7 MiB and slowed the 64-probe aggregate by about 15% to 21%. An
exact four-byte Hash15 collision prefilter was also rejected: filtering every
collision lost existing omit-transform matches, while retaining those matches
made a same-binary fixed-CPU matcher microbenchmark neutral (`0.9998x`). Keep
complete transform coverage as a future compact-index design target rather
than trading memory, latency, or existing deterministic choices for nominal
coverage.

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
  Added dependency-free standard Zstandard full-dictionary generation from
  caller-selected history content. The bound, caller-buffer, and owned APIs
  emit the standard magic, requested non-zero Dictionary_ID, complete portable
  baseline Huffman/FSE tables, repcodes `1/4/8`, and the selected content. The
  implementation validates before mutating short output buffers and reparses
  owned output so all returned views share the owned lifetime. The external
  full-dictionary differential now exercises both Vort-encode/libzstd-decode
  and libzstd-encode/Vort-decode with the generated artifact. This is a valid
  interoperability baseline, not corpus-specific COVER/FastCover entropy
  training; the native trainer still selects raw history content.
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
  The same structural shortcut now covers latency-oriented levels 1-3 with a
  deliberately strict 1/256 admission threshold. Their primary block encoder
  and top-level adaptive selector both return the single prefix-to-tail match
  before running optimal, repeated, and duplicate-family searches. Across 512
  independently generated inputs at both levels, no frame grew and fourteen
  inputs improved by 47 bytes per level. Twenty-four alternating fixed-CPU-8..10
  pairs retained the locked 80-byte text frame while reducing level-1/3 median
  encode time to about 2.3%/2.2% of baseline; JSON and binary controls remained
  within roughly 2.6% noise.
  Shared LZ77 match extension now compares 32-byte vectors before its existing
  eight-byte and scalar tails. An exhaustive oracle covers every mismatch and
  maximum length through 321 bytes at an unaligned second offset. Sixteen
  fixed-CPU-8 stage pairs retained every candidate byte while improving primary/
  4 KiB/8 KiB optimal JSON medians by about 15.5%/14.3%/16.1%; primary binary
  improved about 8.6%. Twenty fixed-CPU-8..10 end-to-end pairs retained every
  locked frame, improved level-1 JSON/binary by about 2.4%/2.3%, and kept
  levels 3/9 within roughly 1.2% noise.
  Level 1 now applies the high-level scheduler's existing deferred-smallest
  policy above 24 KiB: it races the primary and 2 KiB frames first and only
  evaluates the 1 KiB split when the larger split can tie or beat primary. A
  512-input generated matrix proved this implication for the level-1 policy,
  and a separate 512-input end-to-end comparison was byte-identical. Twenty-four
  alternating fixed-CPU-8..10 pairs retained the locked frames while improving
  level-1 JSON by about 16.0% and binary by about 30.1%; the decisive text
  control stayed within 0.3% noise. Level 3 deliberately keeps the full ladder:
  the same matrix contains twelve cases where 2 KiB uniquely beats both primary
  and a losing 4 KiB screen.
  Level 1 now also returns a completed primary frame immediately when it is at
  most 1/32 of the source, regardless of whether the repetition starts at byte
  zero. The same 128-input block-size matrix had no split winner beyond this
  threshold, and the 512-input end-to-end comparison remained byte-identical.
  Twenty-four alternating fixed-CPU-8..10 pairs improved the locked JSON row by
  about 66.2% versus the already deferred-split baseline; binary remained within
  1.6% noise and the prefix-tail text case was already handled by its stricter
  structural shortcut. Level 3 again keeps full arbitration because the matrix
  contains highly compressible counterexamples where a split still wins.
  Level-1 block arbitration now evaluates its required single-duplicate fallback
  before the optimal/repeated passes on blocks above 4 KiB. If that complete
  one-sequence block is at most 1/256 of the source, it returns immediately;
  otherwise the encoded candidate is retained until its original final
  arbitration position, preserving tie order without recomputation. A 512-input
  candidate matrix found seventeen decisive cases and no optimal/repeated winner
  among them, while an end-to-end 512-case comparison remained byte-identical.
  Twenty fixed-CPU-8..10 pairs on a non-prefix 32 KiB run fixture retained the
  30-byte frame and reduced median level-1 encode time to about 33.0% of
  baseline. The locked JSON row improved about 10.6%; text and binary controls
  stayed within roughly 0.9% noise.
  The shared optimal LZ77 parser now applies an exact prefix-cost lower bound
  after validating a four-byte anchor. When a candidate fails before extending
  the already-built length range and even that range's cached minimum plus the
  candidate distance cannot improve the current path, it skips full match
  extension while preserving the candidate budget and tie order. A 32-shape
  generic-vs-bounded token oracle and a 512-input Zstd frame corpus are
  byte-identical. Twenty-four fixed-CPU-8 stage pairs improved primary/4 KiB/
  8 KiB optimal JSON by about 28.9%/24.4%/25.7% and primary binary by about
  20.7%. Thirty-two fixed-CPU-8 end-to-end pairs retained every locked frame
  while improving level-1/3/9 JSON by about 13.3%/4.7%/3.0% and binary by about
  4.9%/2.6%/2.6%; the very short text rows remained within roughly 2% noise.
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
  Parallel primary-block arbitration now cooperatively cancels its recursive
  mixed worker when the repeat-aware beam is the retained non-mixed winner and
  beats both primitive repeated/single candidates by at least 24x. Cancellation
  is sampled only at bounded search nodes and a cancelled partial plan is never
  published, preserving deterministic output. A 24-case structured oracle
  compares the parallel result with full serial arbitration. Eight alternating
  CPU-8 JSON level-9 pairs retained the 640-byte frame and checksum while moving
  median encode time from about 20.9 ms to 14.3 ms (about 1.46x); libzstd 1.5.5
  remains far faster despite emitting 677 bytes, so throughput is still the
  dominant Zstd gap.
  The enclosing block selector now evaluates ratio-mode matching before its
  standalone Huffman candidate when no dictionary/history candidate exists. A
  complete non-RLE match block at or below one eighth of the source is provably
  smaller than any literal-only prefix code, whose symbols require at least one
  bit each, so this path returns without building a redundant literal tree and
  stream. A focused wire oracle covers the bound. Eight more alternating CPU-8
  JSON level-9 pairs retained 640 bytes and reduced median time from about 14.41
  to 12.20 ms (about 1.18x on top of worker cancellation, 1.71x combined).
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
- Deferred bounded-history compaction across non-final DEFLATE EOBs. The
  transactional compressed and stored paths already pause at the real append
  boundary, so this removes redundant retained-history copies without changing
  the 32 KiB lookback or 128 KiB recommended scratch contract. A generated
  dynamic-to-65,535-byte-stored transition is byte-exact. Thirty-one
  fixed-CPU-25 imx PNG rounds improve the seven selected rows by
  `1.036x/1.034x` strict/no-Adler geomean, including `kodim17` at
  `1.014x/1.017x`; four non-selected controls stay within
  `0.9945x..1.0054x` and `0.9966x..1.0026x`.
- Added a PNG windowed semantic specialization for the measured Kodak table
  shape: literal code lengths at most 14 bits plus a distance tree at least 12
  bits deep. This passes the parsed table shape into the resumable block driver
  and reuses the existing non-overlap semantic template instead of duplicating
  Huffman decode. Fifteen-bit literal trees such as Fantasy remain on the
  ordinary loop after a broad-policy A/B exposed a real regression.
- The specialized window loop copies its dominant 1..8-byte, distance>=8
  matches with one fixed 8-byte load/store; longer, small-distance, overlapping,
  tail, and compact-reference cases retain established paths. The isolated
  scalar oracle covers all 264 length/distance pairs plus source/output guards,
  and module policy tests lock both thresholds. Vort full tests, AArch64/PPC64
  compile checks, fuzz smoke, imx full tests/check, and the 195-case PNG corpus
  remain green.
- A fixed-CPU-25 active/control ELF pair differs in exactly one policy immediate
  byte. In 101 alternating rounds, `kodim17` improves `1.079x` strict and
  `1.076x` no-Adler by paired geomean; Fantasy, paletted-zune, indexed lorem,
  and kodim07 controls remain neutral. The synchronized image-png comparison
  moves `kodim17` to about `0.872x/0.878x`, so this is a substantial weak-row
  improvement rather than uniform PNG leadership.
- Reordered the deep-distance semantic match dispatch around its measured
  dominant class: `kodim17` has only 225 distance-one matches among roughly
  207,000 match tokens, while about 99.2% of match bytes are non-overlapping.
  The specialization now tests the likely `distance >= length` case first and
  reaches RLE/small-distance handling only through the overlap branch. Generic
  semantic loops retain their prior distance-one-first layout.
- Mixed-match oracles compare both the resumable window and full-output
  specializations against their generic counterparts, including exact output,
  full bit-reader state, RLE, short/long overlap, short/long non-overlap, and a
  resume boundary. The x86-64 window body shrinks from `0x816` to `0x6c2`
  bytes; focused counters reduce instructions about 1.38% and branches about
  3.94%. A dual-layout ELF whose active/control files differ only in one data
  selector byte measures `kodim17` at `1.095x/1.076x` strict/no-Adler paired
  geomean across 101 alternating rounds with three samples per side per round.
  Four non-selected controls have paired medians within `0.995x..1.001x`; the
  wider geomean spread under host contention is retained as noise rather than
  claimed as a cross-fixture gain.
- Removed the remaining per-token `consumed_bits` dependency from the same
  deep-distance semantic specialization. `BufferedBitReader` stages whole bytes
  and stores unread bits at the low end of its reservoir, so the exact logical
  position is `byte_index * 8 - bit_count`; the loop now derives it only when
  committing EOB or handing off to the transactional tail. Generic loops keep
  their incremental accounting. Existing mixed-match tests compare the entire
  reader struct at a resume boundary and EOB, and the full-output oracle checks
  both the generic semantic loop and public decode.
- The derived-position x86-64 window body shrinks again from `0x6c2` to `0x683`
  bytes and its stack frame from `0xe8` to `0xc8`. An 11-round fixed-CPU-25
  dual-layout counter A/B reduces cycles by `4.97%` and instructions by `8.41%`;
  branches fall `0.53%` while branch misses are effectively neutral. A separate
  one-byte-selector 101-round A/B, taking three process medians per side per
  round, measures `1.042x/1.051x` strict/no-Adler paired-geomean gains on
  `kodim17`. Fantasy, kodim07, paletted-zune, and the lorem screenshot retain
  paired medians within `0.999x..1.002x`.
- Optimized the PNG filter-0 single-distance RLE semantic loop by writing each
  packed literal entry with one explicit little-endian `u16` store instead of
  two byte stores. The semantic table already stores the two speculative
  literal lanes in that order, and the loop guarantees two bytes of output
  headroom. An exhaustive 65,536-pair oracle checks four aligned/unaligned
  offsets and surrounding guards; the RLE block oracle additionally compares
  exact output and the complete buffered-reader state against the generic
  single-distance semantic loop.
- The x86-64 RLE1 loop shrinks from `0xaea` to `0xa9c`. A correct dual-loop ELF
  retains independent word/byte-store bodies and differs only in one selector
  byte: 101 alternating fixed-CPU-25 rounds with three process samples per side
  improve Lohengrin by `1.044x/1.041x` strict/no-Adler paired geomean. Eleven
  counter rounds reduce instructions by `7.79%` and cycles by `2.68%` paired
  geomean; branch misses remain neutral. Four non-selected fixture paired
  medians stay within `0.994x..1.003x`.
- Added a 12-bit primary literal table only for PNG filter-0 dynamic blocks
  whose distance alphabet is exactly the canonical one-bit distance-one code.
  The ordinary semantic decoder retains its 11-bit table; the RLE1 decoder
  omits unused distance tables, remains no larger than the general decoder,
  and lives in a dedicated executable section so unrelated DEFLATE/PNG layout
  stays stable. A complete 1..12-bit-tree oracle proves that a 12-bit literal
  moves from the general secondary table to the RLE1 primary table while exact
  output and the complete buffered-reader state remain identical.
- On fixed P-core 14, 101 alternating process rounds against Vort `122f1c1`
  improve Lohengrin median throughput `1.026x` strict and `1.026x` no-Adler.
  The final repeat-9 image-png `4ab5484` comparison reaches `1.022x` strict and
  `1.049x` no-Adler for Lohengrin. The 15-fixture comparison reports
  `1.290x/1.301x` aggregate/geomean strict and `1.309x/1.325x` no-Adler; strict
  `kodim17` remains about `0.992x`, so PNG-wide per-fixture leadership is not
  claimed. Fifty-one-round non-RLE controls are noise-bound rather than a
  claimed benefit.
- Reused the proven packed little-endian semantic literal store only in the
  resumable deep-distance non-overlap loop, and bypassed dynamic mask/shift work
  for its dominant zero-extra-bit length symbols. The mixed-match oracle now
  includes three consecutive literals and compares exact output plus complete
  reader state at pause and EOB against the generic loop. The isolated x86-64
  body shrinks from `0x683` to `0x633`; ordinary semantic/reconstruction/commit
  symbols remain byte-identical at the same addresses.
- On fixed P-core 14, 101 alternating rounds against `534e7e4` improve
  `kodim17` `1.0094x/1.0105x` strict/no-Adler. The final repeat-9 image-png
  `4ab5484` gate has all 15 rows above parity: aggregate/geomean/median are
  `1.280x/1.288x/1.297x` strict and `1.311x/1.327x/1.317x` no-Adler, with
  `kodim17` the minimum at `1.0017x/1.0116x`. This is locked-corpus decode-into
  parity, not a claim that the complete PNG or image-rs surface is surpassed.
- Rejected three nearby alternatives: row-span Adler updates regressed both
  strict and no-Adler by about 1%; a global 12-bit semantic literal table only
  gained about `1.004x/1.002x` on `kodim17` while risking broader cache cost;
  and 16-byte speculative non-overlap match copies were neutral.
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
- Fixed two incremental Snappy continuation boundaries exposed by the full root
  suite. Encoder snapshots now report cumulative `input_read` across
  `nextStream` while retaining `current_input` for the active stream. Decoder
  output that exactly fills the caller slice no longer prevents following
  identifier/skippable chunks from being consumed and captured; a following
  data chunk remains buffered with `need_output`, preserving backpressure.
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
  Incremental output now retains a partially filled header byte until a later
  meta-block or final marker makes it immutable, allowing runtime metadata and
  subsequent payload blocks to share the Brotli bitstream safely under tiny
  output buffers. Continued-stream snapshots also distinguish cumulative byte
  totals from the current stream's counters.
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
  degrade into per-stream limits. Exhaustion of an exact cumulative output
  pledge is reported as `SizeMismatch`, while a lower explicit safety cap
  remains `OutputLimitExceeded`. The concatenated-gzip test adapter now
  declares EOF with `finish()` after the last complete member instead of
  repeatedly polling the intentionally resumable `between_members` state with
  empty input; progress guards prevent future zero-progress regressions from
  becoming unbounded test hangs.
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
  Incremental low-entropy block expansion now caches its positive diversity
  decision until the expanded block is emitted, instead of rescanning the same
  32 KiB prefix on every caller step while buffering toward 256 KiB. The cache
  resets at each block and stream boundary; a mixed low-entropy/high-entropy
  regression pins the next block's return to the normal target. Nine
  alternating fixed-CPU-30 pairs retain the exact 271-byte repetitive stream
  while improving throughput by 2.047x (9/9 wins), from roughly 1.54 to
  3.14 GiB/s. JSON/source/binary controls remain within 0.2%, cross-window
  improves about 1.5%, and the repetitive row now exceeds local zlib-ng level 6
  while remaining one byte smaller.
  Uniform-prefix detection now checks the common one-byte alphabet before
  allocating and updating the saturated 256-byte seen set. Nine further
  fixed-CPU-30 pairs improve the retained 271-byte repetitive path by another
  1.028x (9/9 wins); JSON/source/binary remain within 0.2% and cross-window
  improves about 1.5%. The incremental zlib-ng gate now requires this row to
  match or beat the linked competitor in both output size and throughput.
  That uniform-prefix probe now compares 32-byte vectors followed by word and
  scalar tails instead of relying on the standard scalar `allEqual` loop. Tests
  cover every mismatch position and vector/word tail boundary. Nine alternating
  fixed-CPU-30 pairs improve the same 271-byte repetitive stream by another
  1.257x (9/9 wins); JSON/source/binary/cross-window controls remain within
  0.4%, bringing the locked repetitive path to roughly 4 GiB/s and about 1.8x
  local zlib-ng level 6 throughput.
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
- Dense back-reference package-merge now recovers code lengths with one
  multiplicity array and a reverse pass over the package DAG instead of
  traversing that DAG independently from every selected root. Selection, stable
  tie-breaking, and output lengths remain unchanged; the original traversal is
  retained as a focused oracle. Nine alternating fixed-CPU-30 ReleaseFast pairs
  improve dense literal, 128-active Zstd, and 256-active Zstd construction by
  `1.290x`/`1.447x`/`1.469x`, all 9/9 wins. The full validated dictionary path
  improves text/JSON/binary medians by `1.013x`/`1.011x`/`1.237x` with 24/27
  wins overall and identical checksums. The Huffman-length gate directly checks
  exact output and a conservative recovery-throughput floor against the old
  root traversal.
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
- The same benchmark now accepts `persistent-only` after its optional CPU
  index, keeping Linux `perf` captures limited to the production incremental
  encoder instead of also timing the rebuild, zlib-compatible competitor, and
  staged reference paths. An 8192-iteration CPU-8 source capture attributes
  roughly 56.6% of samples to the rolling matcher (`plan`, `findBest`, and
  cross-slice match length), 14.4% to dynamic-plan construction, 10.8% to
  block emission, and 7.4% to memory copying. The ordinary default invocation
  and CSV schema remain unchanged, and the five-corpus zlib-ng gate still
  passes.
- Rolling matcher search bounds derived solely from compression options are
  now normalized once per block and passed to both the current-position and
  one-byte lazy probes. This removes nested min/max recomputation from nearly
  every source-like token without changing token selection. Sixteen alternating
  fixed-CPU-8 source pairs at 4096 iterations improved the paired median by
  about 1.3% (15/16 wins; one scheduler outlier), while twelve equivalent JSON
  pairs improved about 1.8% (12/12 wins); encoded sizes and checksum mixes were
  identical, and the five-corpus zlib-ng gate remains green.
- Incremental dynamic histograms now live in reusable matcher state and the
  completed plan borrows them until the next `plan` or `reset`, instead of
  copying 316 counters through the matcher, codec adapter, and block writer. A
  lifecycle test pins address reuse and reset semantics. Twelve alternating
  fixed-CPU-8, 4096-iteration pairs improve source and JSON medians by about
  1.8% and 1.6%, respectively (9/12 and 11/12 wins), with identical encoded
  sizes/checksum mixes; the
  five-corpus zlib-ng gate remains green.
- Reusable incremental histograms now remember exactly which literal/length
  and distance symbols became active, so the next block clears only those
  counters instead of memset-zeroing all 316 entries. Twelve alternating
  fixed-CPU-8, 4096-iteration pairs improve source and JSON medians by about
  1.1% and 1.7% (12/12 and 11/12 wins), respectively; encoded sizes and mixes
  remain exact and the five-corpus zlib-ng gate stays green.
- Incremental fixed-Huffman cost calculation now walks those active-symbol
  lists as well, rather than rescanning all 286 literal/length and 30 distance
  counters after matching. An oracle compares cached and token-scanned fixed/
  dynamic plans, including exact code lengths. Twelve alternating fixed-CPU-8,
  4096-iteration pairs improve source and JSON medians by about 2.2% and 2.4%
  (10/12 and 12/12 wins); output sizes and checksum mixes are unchanged and the
  five-corpus zlib-ng gate remains green.
- Sparse package-merge now also accepts a trusted active-symbol list. The
  incremental dynamic planner reuses the matcher's list, sorts at most 64
  symbols to preserve canonical tie order, and avoids rescanning the 286/30
  frequency arrays before compacting them. An exhaustive 2...64 active-count
  oracle matches the scanned builder exactly. Twelve alternating fixed-CPU-8,
  4096-iteration pairs improve source and JSON medians by about 1.7% and 2.3%
  (11/12 wins each); encoded sizes/mixes are exact and the zlib-ng gate passes.
  The at-most-64-symbol canonical tie-order step now uses a stable insertion
  sort instead of generic introsort setup. The list arrives in near-source
  order and remains small by construction; the same active-count oracle pins
  exact lengths. Twelve alternating CPU-8 pairs improve source by about 1.3%
  (10/12 wins) and JSON by about 0.5% (9/12 wins), with unchanged output and a
  green five-corpus zlib-ng gate.
  Active-symbol arrays are now kept in ascending order at first activation, so
  the planner can consume canonical order directly without another per-block
  sort. The insertion cost is paid only for a new symbol and the lists remain
  bounded to 64 on this path. Twelve alternating CPU-8 pairs improve source and
  JSON medians by about 0.9% and 1.2% (8/12 and 11/12 wins); exact-output oracles
  and the five-corpus zlib-ng gate remain green.
  The rolling matcher's `findBest` search is now inlined into its per-block
  planner, allowing block-invariant limits and hash-chain state to stay in the
  surrounding loop instead of crossing up to two call boundaries per token.
  Twelve alternating fixed-CPU-8, 4096-iteration pairs improve source and JSON
  medians by about 4.1% and 4.0% (11/12 and 12/12 wins); encoded sizes and mixes
  remain exact, and the five-corpus zlib-ng gate stays green.
  A post-series 16-run CPU-8 comparison measures current persistent source and
  JSON medians at about 2902 and 3042 MiB/s, respectively; the same benchmark's
  local zlib-ng 2.3.90 level-6 rows cluster near 2822 and 2880 MiB/s. This is a
  narrow lead on the two locked 256 KiB fixtures, not broad DEFLATE parity;
  repetitive, binary, cross-window, ratio, memory, and wider real corpora remain
  part of the required claim surface.
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
- Incremental fixed/best block publication now exchanges the bit writer's
  completed-byte allocation with the pending-output queue instead of copying
  every encoded block through a second `ArrayList`. The partial bit remains in
  writer state, and the final alignment byte uses the existing append fallback
  because it follows final-block publication in the same step. Seven
  alternating CPU-8, 512-iteration binary A/B pairs kept identical 262184-byte
  output and CRC mixes while improving median throughput from about 156.64 to
  157.25 MiB/s (about 0.4%); structured text is effectively neutral because its
  encoded blocks are only a few hundred bytes. Incremental raw-DEFLATE tests
  cover tiny output, sync flush, final alignment, reset, direct/buffered input,
  stored selection, and retained history with the exchanged ownership.
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
  `run-br-planned-encode-bench` now accepts repeatable `--path` inputs with a
  bounded `--limit`, validates every Vort level through libbrotli before timing,
  and has a checked-in file-path gate. This makes wider real-corpus ratio and
  throughput experiments reproducible without embedding large corpora.
  Ratio mode now also uses the full distance range allowed by its 16-bit Brotli
  stream window (65,520 bytes), rather than inheriting DEFLATE's 32 KiB search
  ceiling. The shared LZ77 token distance remains `u16`, so DEFLATE's ABI and
  default window are unchanged. A deterministic 60 KiB long-distance fixture
  with a 48 KiB offset shrinks from 61,502 balanced bytes to 49,213 ratio bytes
  and round-trips through the exact-size decoder.
  A Brotli-specific second pass now searches the literal runs left by that
  shared parser for 65,521...131,056-byte distances, allowing ratio mode to use
  a 17-bit stream window without doubling the six-byte shared LZ77 token used by
  DEFLATE and Zstd. A deterministic 92 KiB fixture with a repeated 12 KiB prefix
  at distance 80 KiB shrinks from 94,282 balanced bytes to 82,192 bytes and is
  externally decodable with Node/libbrotli. The augmented command plan is still
  compared against the original complete stream before selection.
  Across twelve 128 KiB Silesia prefixes, that post-pass lowers ratio mode from
  548,964 to 544,150 bytes overall (8.15% below libbrotli q3). Ten files improve;
  the two regressions are discarded by the same complete-stream arbitration.
  The long-distance path now reuses the original lazy token and command plan
  instead of parsing/building it twice. A fixed-CPU 10-pair A/B on 128 KiB
  `mozilla`/`nci`/`xml` prefixes reduced ratio encode time to roughly
  58.4%/53.8%/55.2% of the duplicated-plan implementation with byte-identical
  output.
  Its hash chain now delays insertion until a position enters the eligible
  65,521...131,056-byte distance band. This halves predecessor scratch to
  256 KiB and prevents recent same-hash positions from consuming the 512-entry
  search budget. Twelve fixed-CPU A/B pairs improved representative 128 KiB
  `dickens`/`mozilla`/`nci`/`xml` rows by about 0.7%/1.5%/0.8%/1.3% with
  byte-identical output.
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
  The indexed matcher now rejects RFC transforms whose complete-word omission
  produces fewer than four output bytes; those non-advancing candidates could
  previously trap the dictionary planner on ordinary JSON punctuation. Ratio
  mode now evaluates the static-dictionary stream for inputs up to 256 bytes
  and keeps it only when the complete frame is strictly smaller. A focused
  short-payload matrix reduced representative 36/57/59/65/83-byte English,
  JSON, and source inputs by 4–33 bytes; the dictionary pass cost roughly
  12–40x the LZ path below 154 bytes and becomes sharply less attractive above
  256 bytes, which is why the production gate remains deliberately narrow.
  The selected ratio stream is decoded through Node in the external gate.
  The immutable 146,560-byte base-word index is now initialized once with the
  thread-safe allocator and reused across independent encodes. Fixed-CPU
  1000-iteration samples reduced short ratio encode time by roughly 30% for
  dictionary-heavy English/JSON/source inputs and by about 78% when the static
  candidate finds no match, with byte-identical output.
  Static-dictionary matching now groups the 121 RFC transforms by their 0/1/2/5
  byte prefix length at compile time. Each indexed bucket candidate evaluates
  only the group compatible with the already-selected input prefix. Fixed-CPU
  1000-iteration A/B reduced representative 65-byte English, 57-byte JSON, and
  59-byte source ratio encodes by about 32%, 40%, and 52%, respectively; the
  no-dictionary-match case improved by roughly 10%, with unchanged wire output.
  Whole-word transforms are now rejected from their immutable suffix metadata
  when the remaining input is too short or the first suffix byte differs,
  before materializing a candidate in scratch. A fixed-CPU follow-up reduced
  those same short ratio rows by a further roughly 38%, 44%, and 39%, and the
  no-match row by about 31%; exhaustive transform metadata tests cover all 121
  transforms across every dictionary word length.
  Those immutable prefix/suffix properties are now stored in one compile-time
  `TransformMetadata` table and shared by the matcher helpers, replacing repeated
  NUL-terminated prefix/suffix scans in the candidate loop. Fixed-CPU 1000-run
  A/B reduced the same short ratio rows by another roughly 19–24% and the
  no-match case by about 17%, with unchanged output and metadata-oracle results.
  Transform metadata now packs each complete suffix (up to eight bytes) into a
  little-endian `u64`, allowing the matcher to validate the whole suffix before
  materializing a candidate instead of checking only its first byte. Fixed-CPU
  1000-run A/B improved the 65-byte English, 57-byte JSON, and 59-byte source
  rows by a further roughly 8%, 6%, and 7%; the already-cheap no-match row was
  neutral to about 2% faster.
  Ratio mode now also builds a mixed command plan for short inputs by replacing
  only literal runs in the existing LZ77 plan with verified static-dictionary
  commands. Existing backward copies keep their exact positions and distances,
  and full-stream arbitration still rejects any size loss. A 53-byte mixed
  repetition/dictionary fixture falls from 33 to 29 bytes versus dictionary-only
  encoding and from the previous ratio path's 33 to 29 bytes; Node decodes the
  selected stream. The extra candidate costs roughly 42% on that fixture and is
  currently limited to the existing <=256-byte ratio dictionary gate.
  Indexed matching now resolves each bucket's base-word slice once and passes
  it directly to a shared `transformWord` helper, instead of decoding the same
  address and recomputing the dictionary offset for every compatible transform.
  An exhaustive sampled-word oracle covers all word lengths and 121 transforms.
  Fixed-CPU 1000-run A/B improved mixed/English/JSON/source short-ratio rows by
  roughly 2%/3%/5%/3%, with the no-match row about 2.5% faster.
  The compile-time transform prefix groups now carry an explicit active length,
  so the matcher iterates a bounded slice rather than testing a sentinel on
  every transform. Fixed-CPU 1000-run A/B improved mixed/English/JSON/source
  short-ratio rows by roughly 4%/10%/8%/6%, with the no-match row about 3%
  faster and identical output. A per-position shared match-cache prototype was
  also tested and rejected because eager full-input scanning made representative
  rows 4–56% slower despite eliminating some duplicate lookups.
  Ratio mode now falls through to its RFC static-dictionary encoder when the
  LZ77 parser finds no backward match, instead of rejecting dictionary-only
  short inputs before dictionary planning. The standalone 11-byte word
  `information` now produces a 9-byte Brotli stream and is decoded through Node.
  The same branch now compares dictionary output against a stored stream and
  falls back to stored when the dictionary expands or finds no match, so ratio
  mode also handles arbitrary 5–256-byte incompressible inputs instead of
  exposing the planner's internal `InvalidBlockPlan` limitation.
  The stored ceiling now applies to every ratio path across the complete
  one-meta-block input range, including LZ77 and 17-bit long-distance plans. The
  exact stored bound avoids materializing the fallback unless the selected
  compressed stream is larger; deterministic random inputs at 8/64/256/4096
  bytes round-trip with ratio size no greater than stored, and a 34-byte
  incompressible fixture is externally decoded by Node from its 38-byte stream.
  The stable `encodePlannedStreamWithOptionsAlloc` facade now applies the same
  stored fallback and exact size ceiling to `.fast` and `.balanced`. All three
  public levels therefore accept arbitrary 5-byte-to-one-meta-block inputs and
  never return a frame larger than stored, while direct experimental planner
  entry points retain their precise `InvalidBlockPlan` behavior. Deterministic
  random inputs at 8/64/256/4096 bytes cover all levels, and Node decodes the
  fast/balanced incompressible fixtures.
  `PlannedStreamEncoder` now exposes matching `encodeWithOptionsAlloc`. Its fast
  level retains reusable token/command capacity while applying the same stored
  fallback and ceiling; balanced/ratio delegate to their stable one-shot paths
  until their larger parser state is reusable. Tests require byte parity with
  the one-shot API for all levels, capacity retention for fast, and successful
  incompressible round trips bounded by stored size.
  Stable levels now also cover empty through four-byte inputs with stored
  streams. The reusable fast encoder delegates inputs above its 32 KiB retained-
  scratch range to the stable one-shot fast path instead of rejecting them, so
  it remains byte-identical at both tiny and large boundaries; Node decodes the
  new four-byte fixtures for all three levels.
  The command-plan wire encoder now has an append core, and
  `PlannedStreamEncoder.encodeScratch` writes fast-level output directly into
  retained encoder-owned storage. After warmup, repeated similarly sized calls
  reuse token, command, and output capacities and avoid an owned output
  allocation; returned bytes remain valid until the next call or `deinit`. A
  fixed-CPU 10,000-run JSON sample improved from roughly 15.4 µs per allocating
  reusable encode to 14.4 µs, with byte-identical output.
  The reusable facade also exposes `encodeInto` for fast-level streams. Its
  caller buffer is sized by the exact stored-stream bound, the command writer
  runs in bounded mode without output allocation, and a compressed result that
  crosses the ceiling is overwritten by the stored representation. Tests lock
  byte parity with stable fast output, undersized-buffer `OutOfMemory`, and an
  incompressible caller-buffer round trip. Bounded fast encoding now also treats
  command-writer `OutOfMemory` as a compressed-candidate overflow and rewrites
  the exact-size caller buffer with stored output. An eight-byte payload with a
  four-byte repeated suffix reproduces this boundary: its compressed attempt
  exceeds the 12-byte stored bound, while `encodeInto` now succeeds at exactly
  12 bytes; a deterministic 100,000-case search finds no remaining false OOM.
  Static-dictionary lookup now recovers ASCII uppercase-first and uppercase-all
  transforms without adding a second dictionary index: it lowercases the four-
  byte hash prefix, probes the existing base-word buckets, and visits only the
  matching case transform group. The sampled 121-transform coverage matrix
  improves from 6,751/9,836 to 8,656/9,836 full-length matches while retaining
  the 146,560-byte index. `INFORMATION` now compresses as an 11-byte dictionary
  stream instead of falling back, and fixed-CPU 1000-run short-ratio A/B improves
  representative mixed/English/JSON/source rows by roughly 10%/15%/16%/14%.
  Shared-index lookup now uses an acquire/release ready flag, so only first
  initialization takes the mutex and steady-state short encodes avoid locking.
  A fixed-CPU 1000-run A/B improved mixed/English/JSON/source rows by roughly
  3%/4%/4%/2% and the no-match row by about 2%; an eight-thread test covers
  concurrent first access and matching after publication.
  Public `encodedPlannedStreamBound*` and `encodePlannedStream*Into` helpers now
  expose that stored ceiling to one-shot callers. The reusable encoder's
  `encodeIntoWithOptions` supports all stable levels: fast writes directly in
  bounded mode, while balanced/ratio retain exact one-shot selection before
  copying into caller storage. Tests cover empty, repetitive, dictionary-heavy,
  and incompressible inputs, all levels, exact parity, and undersized buffers.
  The <=64-symbol Brotli Huffman builder now uses a stable two-queue merge over
  the already frequency-ordered `PrefixAlphabet`, replacing binary heap pop/push
  operations with linear construction while preserving `(weight, serial)` tie
  behavior. A 1,024-shape oracle requires exact length-vector equality with the
  retained heap reference. Fixed-CPU 10,000-run fast-encoder A/B improved JSON,
  source, and log by roughly 2%/3%/2%, respectively, with identical wire sizes.
  Leaf depths in that two-queue tree are now recovered by one reverse node pass.
  Parent nodes are always appended after their children, so parent depths are
  available before child assignment and repeated leaf-to-root walks disappear.
  The builder's descending-frequency precondition is now explicit and asserted
  in debug builds; its package-merge weighted-cost oracle sorts generated inputs
  into the same `PrefixAlphabet` order instead of accidentally exercising an
  unsupported unsorted queue.
  The same exact heap oracle passes; fixed-CPU 10,000-run A/B adds roughly
  0.8%/0.9%/1.9% on JSON/source/log with unchanged streams.
  Static-dictionary candidate verification now compares RFC prefix, transformed
  base-word bytes, and suffix directly against the input instead of materializing
  every candidate into a 64-byte scratch buffer before comparison. An exhaustive
  oracle checks all 13,504 base words through all 121 transforms against the
  existing materializing implementation. Seven alternating fixed-CPU-8,
  2,000-iteration A/B pairs improved the 65-byte dictionary and 53-byte mixed
  ratio cases by median 4.8% and 2.3%, respectively; uppercase was neutral and
  selected stream sizes remained byte-for-byte unchanged.
  Short ratio arbitration now shares an on-demand per-position dictionary-match
  cache between its mixed and dictionary-only planners. Unlike the rejected
  eager cache, it scans only positions reached by a planner and performs a
  bounded re-probe when the cached full-input match crosses an LZ literal-run
  boundary. Seven alternating fixed-CPU-8, 2,000-iteration A/B pairs improved
  the affected mixed case by median 7.8%; dictionary-only, uppercase, and
  no-match controls were not meaningfully affected, and all output metrics were
  equal.
  Short ratio dictionary candidates are now encoded into a stack-backed buffer
  bounded by the exact stored-stream size. Candidate overflow proves it cannot
  win the strict size comparison; only the selected compressed result is copied
  to caller-owned allocation. This covers both dictionary-only and mixed/LZ
  arbitration without changing public ownership. Seven alternating fixed-CPU-8,
  2,000-iteration A/B pairs improved dictionary, mixed, uppercase, and
  incompressible short cases by median 1.9%, 1.5%, 1.9%, and 9.7%, respectively,
  with unchanged sizes and dictionary-use metrics.
  Zstd mixed-lookahead candidate caches now borrow the duplicate index already
  prepared by the enclosing selector instead of copying its multi-megabyte
  predecessor and lazy match-length tables into the recursive search frame. An
  explicit initializer also leaves the owned fallback index untouched until a
  standalone search actually needs it. Eleven alternating fixed-CPU-8 stage A/B
  pairs improved level-9 primary mixed search by median 4.4% on text, 3.7% on
  JSON, and 33% on the no-mixed-candidate binary control; complete level-9
  encoding improved by 0.3%/1.7%/2.8%, with byte-identical output sizes.
  A review of local upstream zstd (`v1.4.7-3025-g5233c58e`) confirmed that its
  fastest strategy checks recent offsets in the main hash-match loop. Vort
  level 1 now enables its bounded two-state repeat-offset beam as the equivalent
  independent candidate, with exact block/frame arbitration retaining the old
  winner whenever repcodes do not help. On the locked 32 KiB benchmark, level-1
  JSON falls from 781 to 640 bytes and binary from 8,846 to 8,607 bytes while
  text stays at 80 bytes. Eleven alternating fixed-CPU-8 runs improved complete
  encode medians by roughly 23.8% for JSON, 3.1% for binary, and 1.1% for text;
  decisive beam results also bypass the slower generic optimal pass.
  The same upstream review showed that double-fast and greedy strategies keep
  repcode checks active rather than reserving them for high-ratio modes. Vort
  therefore extends its already bounded repeat-offset candidate through level 3
  (level 2 follows the same policy between the public benchmark points). On the
  locked matrix, level-3 JSON drops from 781 to 640 bytes and binary from 8,846
  to 8,607 while text remains 80 bytes. Nine alternating fixed-CPU-8 runs
  improved complete level-3 JSON and binary medians by about 11.1% and 1.9%;
  text was within 0.6% noise. Final-wire arbitration remains authoritative.
  A dedicated diagnostic `double_fast` stage now mirrors the important shape
  of upstream `zstd_double_fast.c`: independent 4-byte and 8-byte hash tables,
  the one-byte-ahead rep0 probe, immediate zero-literal rep1 continuation,
  complementary insertion around consumed matches, and exact Zstd repcode
  history updates. It remains outside production selection until it closes the
  remaining structured-data ratio gap. On the locked 32 KiB stage corpus it
  produces 210/695/8,600-byte text/JSON/binary blocks versus the repeat beam's
  210/633/8,600, while fixed-CPU-8 medians are about 13.4x, 3.6x, and 3.6x
  faster on the corresponding primary blocks. Adaptive 1/2 KiB output is at
  most seven bytes larger per complete corpus. The stage benchmark and coverage
  gate expose the parser explicitly so later policy work can require measured
  parity instead of replacing the beam on an unverified speed result.
  The two-state repeat beam now keeps a different recent-offset history when
  its fixed-cost estimate is at most two bits above the current replacement
  boundary. That small tolerance reflects the offset FSE savings that the
  parser's fixed-bit proxy cannot see. It preserves all locked primary and
  binary stage sizes while reducing the 8 KiB adaptive JSON candidate from
  2,157 to 2,156 bytes. An explicit state-insertion test and per-stage size
  ceilings make both the intended beam diversity and the wire result stable.
  The diagnostic double-fast parser now probes rep1/rep2 only when its selected
  hash match would otherwise introduce a direct distance, accepting no more
  than a one-byte match-length deficit. This narrow upstream-style safeguard
  reduces the locked primary JSON block from 695 to 687 bytes while preserving
  all text/binary and adaptive candidate sizes. Eleven-round fixed-CPU-8 A/B
  measured unchanged primary throughput within noise (about 0.995x elapsed),
  and a focused structured-input test pins the selected 687-byte wire size.
  Double-fast complementary insertion now also records the match-start `+2`
  position in the long hash table, matching upstream's `curr + 2` anchor while
  leaving the short table untouched. All nine locked stage sizes remain
  identical. Eleven alternating fixed-CPU-8 A/B pairs improved median primary
  text/JSON/binary stage time by about 0.9%/1.7%/1.6%, respectively.
  Double-fast's short/long hash tables are now sized at 10/12 bits instead of
  14/15. The smaller stack footprint and cheaper initialization outweigh the
  additional collisions on the locked corpus: all primary and binary sizes are
  unchanged, while JSON adaptive 4/8 KiB output improves from 3,678/2,164 to
  3,673/2,158 bytes. Eleven alternating fixed-CPU-8 A/B pairs improved median
  primary text/JSON/binary stage time by about 20.9%/5.8%/1.7%, and adaptive
  rows by roughly 14.5% to 44.0%.
  The repeat-offset beam parser now exposes caller-owned reusable scratch for
  its states, per-position occupancy, 4 KiB match index, and reconstructed token
  stream. The stage benchmark exercises that reuse across repetitions rather
  than paying four allocator lifecycles per block. Eleven alternating
  fixed-CPU-8 A/B pairs preserved every locked wire size while improving
  primary text/JSON/binary beam time by about 22.0%/25.4%/21.6%; adaptive rows
  improved by roughly 10.7%–25.4%. The allocating API remains as a convenience
  wrapper and an exact token/capacity test protects scratch reuse behavior.
  Repeat-beam's dedicated 4 KiB index now stores predecessor positions as
  `u16` rather than machine-width signed integers. Its input is already bounded
  to 65,535 bytes, so the compact sentinel representation is exact and reduces
  predecessor storage from eight bytes to two bytes per input position. Eleven
  alternating fixed-CPU-8 A/B pairs preserved every stage size while improving
  primary text/JSON/binary beam time by about 22.8%/26.0%/25.6%; adaptive rows
  improved by about 14.5%–25.3%. A focused oracle compares compact and generic
  index matches at positions up to the u16 input boundary.
  The beam hot loop now trusts the per-position active-slot count maintained by
  `insertRepBeamState` instead of rechecking every yielded state against the
  unreachable max-cost sentinel; final-state selection uses the same invariant.
  Eleven alternating fixed-CPU-8 A/B pairs preserved every wire size and
  improved median primary text/JSON/binary beam time by about 6.2%/2.9%/1.8%;
  most adaptive rows also improved, while the smallest binary row was neutral.
  The beam transition helpers are now explicitly inline and return `void`: both
  mutate only bounded caller-owned arrays and have no error path, so the former
  error-union calls added avoidable control-flow overhead on every literal and
  match edge. Eleven alternating fixed-CPU-8 A/B pairs preserved every wire
  size while improving median primary text/JSON/binary beam time by about
  6.1%/2.6%/5.7%; adaptive text/JSON improved by roughly 1.6%–3.7%, with binary
  adaptive rows neutral.
  When repeat-beam's sole indexed match already uses a state's current rep0,
  the explicit rep0 probe now reuses that work instead of repeating the same
  vectorized match-length scan and identical state insertion. Eleven alternating
  fixed-CPU-8 A/B pairs preserve all wire sizes; repetitive text improves by
  roughly 16.6%/6.0%/9.3% for primary/4 KiB/8 KiB, while other rows stay near
  neutral. A focused replay test covers consecutive matches at one distance.
  The beam loop now computes whether a minimum-length match can fit once per
  position and skips both hash-index and recent-offset probes for the final
  literal-only tail. Eleven alternating fixed-CPU-8 A/B pairs preserved every
  wire size while improving primary text/JSON/binary beam time by about
  0.8%/4.3%/2.8%; the two larger adaptive JSON/binary rows improved by roughly
  0.9%–2.7%. A focused replay test covers a three-byte tail.
  A second hash-width sweep reduced the same tables further to 8/11 bits. The
  complete locked size matrix remains unchanged. Eleven alternating fixed-CPU-8
  A/B pairs against the 10/12-bit version improved median primary text/JSON/
  binary stage time by about 4.2%/1.0%/3.2%, with adaptive rows another
  1.1%–7.0% faster and the parser's stack tables reduced from 20 KiB to 9 KiB.
  Repeat-beam's compact predecessor index now hashes the parser's actual
  four-byte minimum-match prefix instead of the generic three-byte anchor. This
  avoids walking false-collision chains that can never pass the fourth-byte
  guard. Eleven alternating fixed-CPU-8 A/B pairs preserved every wire size and
  improved median primary text/JSON/binary beam time by about 3.7%/5.1%/13.8%;
  adaptive rows improved by roughly 2.9%–7.3%.
  Double-fast's zero-literal rep2 transition now snapshots old rep0/rep1 before
  replacing the queue. Zig aggregate assignment observes earlier element writes,
  so the previous expression could collapse `{rep0, rep1, rep2}` into three
  copies of rep2 even though the resulting token distances still formed a valid
  stream. A focused state test now pins the required `{rep2, rep0, rep1}`
  rotation; all locked stage sizes remain unchanged.
  Equal-length double-fast candidates now prefer shorter direct distances after
  retaining repcode priority. This lowers offset extra-bit cost and produces a
  more useful future rep0 without changing any locked candidate size. Eleven
  alternating fixed-CPU-8 A/B pairs improved median primary text/JSON/binary
  stage time by about 3.1%/6.9%/2.0%; adaptive text and 8 KiB JSON improved by
  roughly 6.4%–7.1%, while the remaining adaptive rows were neutral.
  Brotli complex-prefix emission now receives the highest active symbol from
  the already-built sparse alphabet instead of rescanning the complete dense
  256/704-entry code-length array to rediscover its stop index. Eleven
  alternating fixed-CPU-8 A/B pairs preserved every fast/balanced/ratio wire
  size and improved median full encode time for JSON/source/log by about
  0.6%/2.0%/0.8%, respectively. The public generic writer keeps its validating
  scan, while the new precomputed-stop entry point validates the supplied
  boundary before encoding.
  Canonical Huffman encoder construction now has a trusted sparse path for
  planners that already own at most 64 active symbols. Brotli uses it for
  literal, command, distance, and UTF-8 context trees, avoiding repeated dense
  scans and zero-fills across 256- and 704-entry encoder tables while retaining
  the generic constructor for larger alphabets. Randomized sparse-versus-dense
  oracle tests pin identical canonical codes. Eleven alternating fixed-CPU-8
  A/B pairs preserve all fast/balanced/ratio wire sizes and improve fast JSON/
  source/log throughput by about 4.8%/8.0%/3.4%; balanced improves about
  3.1%/8.0%/1.0%, and ratio improves about 3.6%/9.2%/0.3%.
  Brotli's compact `PrefixAlphabet` now stores frequencies as `u32`, matching
  the wire planner's source counters and the 2^24-byte meta-block bound instead
  of widening every entry to `usize`. This reduces each temporary alphabet
  from about 7.0 KiB to 4.2 KiB on 64-bit targets and removes conversion before
  package-merge fallback. Eleven alternating fixed-CPU-8 A/B pairs preserve all
  fast/balanced/ratio wire sizes and improve full JSON/source/log fast encoding
  by about 10.8%/9.4%/10.5%; balanced improves about 9.1%/11.6%/12.2%, and ratio
  improves about 7.9%/3.4%/12.6%. The 2^24-byte meta-block bound also proves
  that every frequency increment fits the compact representation.
  `PrefixAlphabet` is now capacity-parameterized instead of always reserving
  the 704-symbol command maximum. Literal and UTF-8-context trees use 256-entry
  instances, while command and distance trees retain their exact wire bounds;
  a layout test pins the resulting 1,544-byte literal scratch versus 4,232
  bytes for the full command alphabet. Eleven alternating fixed-CPU-8 A/B pairs
  preserve all locked output sizes and improve fast JSON/source/log encoding by
  about 5.2%/3.9%/4.7%; balanced improves about 8.9%/8.4%/6.9%, and ratio about
  8.1%/12.7%/6.6%.
  The compact Brotli alphabet now stores only its active symbol ordering and
  borrows the wire planner's existing dense `u32` frequency tables for sorting
  and code-length construction. This removes the second frequency copy entirely:
  a 256-symbol alphabet is now 520 bytes and the full 704-symbol form is 1,416
  bytes. Eleven alternating fixed-CPU-8 A/B pairs preserve all locked streams
  and improve fast JSON/source/log encoding by about 7.0%/5.7%/7.1%; balanced
  improves about 6.6%/8.2%/8.4%, and ratio about 6.0%/7.2%/8.9%.
  Dense-frequency collection and sparse-alphabet ordering now happen in one
  pass: each non-zero symbol is inserted directly into frequency order while
  the dense table is scanned. Because symbol IDs arrive in ascending order,
  equal-frequency stability is preserved without a separate active-array sort.
  Eleven alternating fixed-CPU-8 A/B pairs preserve every locked wire size and
  improve the main fast/balanced/ratio corpus paths by roughly 0.5%–1.6%, with
  the clearest gains on source and log data.
  The reusable Brotli fast encoder now owns a tiny-greedy hash scratch whose
  4K head array and predecessor storage survive across calls. A per-plan 512-byte
  initialization bitmap replaces clearing the 32 KiB head table, while the
  one-shot and Zstd callers keep their existing paths. A multi-input oracle
  verifies exact tokens and statistics after scratch reuse, and retained-capacity
  reporting includes the predecessor buffer. Eleven alternating fixed-CPU-8
  full-encoder A/B pairs preserve every fast output size while improving JSON/
  source/log by about 62%/48%/56%; short dictionary/mixed inputs improve by
  about 1.8x/2.0x and no-match inputs by about 4.4x.
  The same reusable tiny-greedy scratch now stores positions as `i16`. A 32 KiB
  input can only insert positions through 32,765 because a complete three-byte
  hash anchor is required, so all live positions plus the `-1` sentinel fit
  exactly. This halves the retained head and predecessor storage again; an exact
  32 KiB boundary oracle matches the allocating parser token-for-token. Eleven
  alternating fixed-CPU-8 full-encoder A/B pairs preserve all fast wire sizes
  and improve JSON/source/log by about 1.9%/2.4%/1.3%, with short dictionary/
  mixed inputs improving about 1.1%/1.6%.
  The reusable tiny-greedy scratch now stores its 32 KiB-bounded head and
  predecessor positions as `i32` rather than machine-width `isize`. This halves
  both retained index buffers without changing the generic one-shot parser.
  Eleven alternating fixed-CPU-8 full-encoder A/B pairs preserve every fast
  stream and improve JSON/source/log by about 3.9%/2.9%/4.7%; dictionary and
  mixed inputs improve by roughly 5.3%/4.4%, and the no-match control by about
  36%. A focused multi-input oracle pins exact tokens, statistics, and the
  16 KiB head-table footprint.
  The one-shot three-byte tiny-greedy parser now uses the same bounded `i16`
  position representation and lazy head initialization as the reusable Brotli
  path. The four-byte Zstd specialization deliberately retains its former
  tables because fixed-core measurements found its primary rows neutral to
  slightly slower with bitmap checks. Eleven alternating CPU-8 A/B pairs keep
  every Brotli byte identical while making the standalone parser about 3.3x–
  3.6x faster and complete JSON/source/log encoding about 63%/48%/55% faster.
  A 32 KiB boundary oracle and the Zstd stage gate protect both specializations.
  Added the first true byte-progressive compressed Brotli decode slice for the
  single-command RLE streams emitted by `encodeRleStream*`. The decoder retains
  at most a 64-byte encoded header, validates the exact command/literal/distance
  shape and copy-extra length, and expands directly into caller output under
  backpressure rather than buffering either the complete compressed frame or
  decoded run. One- and two-byte input splits cover copy-length boundaries up
  through 65,536 bytes; limit, exact-size, truncation, trailing-data, and
  unsupported-shape tests pin the new API, while the existing Node differential
  gate continues to validate its production encoder wire format.
  Extended true byte-progressive compressed decoding to final insert-only
  meta-blocks. A bounded header parse retains the decoded literal Huffman tree,
  then a fixed 64-bit reservoir consumes split payload bytes and emits literals
  directly into caller output. Atomic symbol rollback preserves progress when a
  Huffman code crosses an input boundary. Tests cover one-byte input, three-byte
  output backpressure, insert/meta-block length boundaries through 65,536 bytes,
  output limits, exact sizes, truncation, trailing data, and copy-command
  rejection. Copy-command streams outside the single-block-type subset below
  remain on the existing bounded whole-frame facade.
  Added the first byte-progressive Brotli copy-command decoder. It accepts final
  compressed streams with one literal/command/distance block type, retaining
  only a bounded entropy header plus a caller-owned history ring, and resumes
  overlapping match copies across tiny output buffers. A shared fixed-size
  reservoir bit reader now gives literal and copy decoders atomic rollback at
  input boundaries. Tests cover alternating runs up
  to 65,536 bytes, multi-command repeated prefixes, history-ring wrap, missing or
  undersized history, output limits, truncation, and trailing input.
  Extended the progressive copy state machine to decode distance symbols after
  each command's inserted literals, matching Brotli wire order. Dynamic distance
  Huffman trees, direct and regular distances, short codes, implicit rep0, and
  the four-entry recent-distance ring are now supported. One-byte input tests
  cover the existing last-distance, short-distance, and regular-distance
  fixtures plus representative fast-planner streams with simple and complex
  literal/command alphabets.
  The progressive copy decoder now retains all parsed literal and distance
  context trees instead of requiring all context-map entries to select tree
  zero. It derives literal context from the last two streamed history bytes and
  selects the distance tree from the current copy length, with state snapshots
  restored alongside bit-reader rollback. One-byte input/output tests cover the
  established LSB6 literal-context and distance-context fixtures, while a ratio
  planner fixture exercises its two-tree UTF-8 context map.
  Generalized the existing block-length, command-symbol, and block-switch
  helpers over the progressive bit reader and retained the complete mutable
  entropy header in the copy decoder. Literal, command, and distance block
  switches now advance atomically with the bitstream and roll back together on
  split input. One-byte input/output tests cover two- and three-type switches as
  well as a complex block-length tree.
  Added progressive static-dictionary copies to the same decoder. Distances
  beyond produced history are resolved through the shared complete Brotli
  dictionary/transform implementation into a fixed 64-byte scratch, then
  drained through caller output and the caller-owned history ring under
  backpressure. Dictionary copies deliberately do not update recent-distance
  state. One-byte input/output tests cover identity, capitalization, multiple
  dictionary commands, and mixed LZ77/dictionary planner output.
  Final and non-final compressed headers now share the progressive literal/copy
  parser. Non-final compressed blocks may be terminated by a following final-
  empty meta-block without whole-frame buffering; the two-bit terminator and
  trailing zero padding are consumed incrementally. One-byte split tests cover
  successful termination and truncated streams at the final input-byte
  boundary.
  Extended non-final progressive compressed streams to accept one or more
  following stored meta-blocks before the final-empty terminator. The decoder
  parses each stored header incrementally, enforces cumulative output limits,
  validates byte-alignment padding, and copies stored payload bytes directly
  from caller input to caller output. Literal and copy decoder tests cover
  one-byte input, tiny output buffers, multiple stored blocks, exact-size
  completion, output-limit rejection, and truncated boundaries.
  The copy decoder now also crosses consecutive non-empty compressed
  meta-blocks without buffering the complete stream. It repacks prefetched
  boundary bits into its bounded header buffer, parses the next entropy header,
  and preserves output history, literal context, and the recent-distance ring.
  Byte-at-a-time tests cover cross-block short-distance reuse, context-tree
  selection, tiny output backpressure, and a truncated second block; both
  synthetic streams are additionally accepted by Node's Brotli decoder.
  A separate runtime differential now drives libbrotli 1.1's streaming encoder
  with a completed flush between chunks, verifies the resulting summaries
  contain the expected non-empty compressed-block count, then feeds each real
  multi-block stream to Vort one byte at a time. The matrix now covers 94
  flushed/metadata streams across generic, text, and font modes; window bits
  10/16/18/20/22/24; qualities 0/1/3/4/5/6/9/11; enabled and disabled literal
  contexts; explicit postfix/direct distances; short dense flushes; Unicode;
  compressed-to-stored-to-compressed transitions; and history that crosses the
  64 KiB boundary. Actual block-type counts are checked rather than inferred
  from requested operations, and real metadata payload bytes plus split block
  lengths are verified through the incremental decoder. The original binary
  corpus exposed an RFC UTF-8 context-table transcription bug: second-last
  bytes D0..DF were incorrectly classified like E0..FF. Correcting that range
  restores one-shot and incremental parity with libbrotli's quality 5+ output.
  The same copy decoder now starts from a progressive window parser and the
  shared meta-block state machine, so upstream streams may begin with stored or
  metadata blocks before reaching compressed data. Focused byte-split tests pin
  stored-to-context-compressed and metadata-to-compressed transitions.
  A larger real-source case exposed that static-dictionary addresses must be
  based on `min(total_output, 2^WBITS - 16)`, not total output after the ring
  window fills. One-shot decode, summary/preflight, and the byte-progressive
  copy decoder now retain the parsed window and use that RFC maximum for both
  dictionary classification and recent-distance updates. The upstream matrix
  initially reached 90 cases with a 1.26 MiB source stream at window 20, and a
  focused boundary test pins the post-window dictionary-address calculation.
  Quality-11 source streams at window bits 18/20/22/24 add 1.26 MiB real-world
  decode coverage. Their caller-buffer and byte-progressive output is exact; the
  allocation-free summary deliberately reports `UnsupportedBrotliFeature` for
  four cases whose literal context depends on history beyond its fixed 65,520-
  byte scratch. New allocator-backed summary variants size history from the
  stream's declared window, and allocator-returning decode uses that path, so
  all four large-window cases also pass ordinary `decodeStreamAlloc`. Summary
  history now tracks zero, one, or two known suffix bytes
  after such a copy, preventing one newly decoded literal from incorrectly
  making a two-byte context look valid and turning the limitation into a later
  misleading `CorruptFrame`.
  Added caller-owned-history summary APIs for contiguous and chunked Brotli
  input, including output limits and diagnostics. They preserve the fixed
  allocation-free helper's `UnsupportedBrotliFeature` result when supplied
  history is genuinely too short, but let integrations provide the declared
  window without hidden allocation. The upstream multi-meta-block differential
  now exercises this path for all eight large-window cases that require more
  than the inline 65,520-byte ring and reports zero unsupported summaries across
  its 99-case matrix.
  Added byte-progressive metadata handling after compressed blocks. Metadata
  headers and payloads can span arbitrary input chunks, payload bytes are
  skipped without affecting decoded-size accounting, and callers may provide
  bounded metadata and per-block-length buffers matching the stored decoder's
  observability model. Tests cover truncated capture, exact block-length
  reporting, and metadata followed by stored data and a final-empty terminator.
  Fixed decoded-size preflight for ratio-mode Brotli streams whose matches reach
  beyond 32 KiB. `LiteralHistory` now retains the encoder's full advertised
  16-bit-window maximum (`2^16 - 16` bytes), so copied history remains known for
  subsequent UTF-8 literal-context decisions. The previously failing embedded
  `br.zig` ratio round trip and explicit 48/80 KiB distance tests now pass; a
  layout assertion pins the history capacity to the encoder limit.
  Allocator-backed Brotli summaries now try that fixed 65,520-byte history
  before reserving the stream's full declared window. This keeps ordinary
  WBITS=24 streams from allocating almost 16 MiB merely because their header
  permits far copies, while preserving an exact retry for the quality-11 source
  cases that genuinely need older context. A failing-allocator test pins the
  allocation-free fast path across all four public allocator-summary variants
  and pre-reserved append decode.
  Brotli summary history no longer zero-fills its 65,520-byte inline ring before
  decoding, because `tail_len` makes unwritten bytes unobservable. Stored and
  dictionary slices are now appended with at most two contiguous copies instead
  of a modulo operation per byte, while match copies retain their overlap-aware
  byte loop. A focused wrap/replacement oracle pins logical ring ordering. Seven
  alternating ReleaseFast CPU-8 A/B pairs on the structured quality-11 stream
  reduce median decoded-size summary time by about 8.9%, while exact-size decode
  remains effectively neutral and decoded bytes stay identical.
  Brotli summary match copies now seed a bounded scratch from at most two ring
  spans, expand overlapping repetitions by doubling, and append each batch with
  the contiguous history path. This replaces a modulo-heavy operation per output
  byte while preserving RFC forward-copy overlap. A deterministic 500-operation
  oracle compares retained ring contents against materialized output across
  random literals, distances, lengths up to 700 bytes, and repeated wraps. Seven
  alternating ReleaseFast CPU-8 A/B pairs on the structured quality-11 stream
  reduce median decoded-size summary time from about 44.34 ms to 6.65 ms for 500
  iterations (6.67x); exact-size decode improves about 2.2%, while direct decode
  remains effectively neutral.
  Brotli clustered decoding now covers the remaining observed bounded-tree
  gaps: literal context trees retain the full 256-entry wire range, distance
  block types/context trees use a 64-entry tier, and the progressive copy
  decoder retains up to 16 KiB of compressed header bytes. Stream summaries
  report the observed literal and distance maxima. Deterministic 1 MiB corpora
  exercise 169 literal trees and a real `src/deflate.zig` quality-8 stream
  exercises 35 distance block types/context trees; both pass allocator summary,
  one-shot decode, and byte-progressive decode. The libbrotli differential
  matrix grows again from 95 to 98 cases. Ten long fixed-CPU-8 A/B pairs keep
  ordinary compressed decode within roughly 2% of the previous build on most
  rows (structured quality 4 improves about 4%); summary overhead rises about
  1--2% on most rows in exchange for the broader bounded state.
  Ordinary allocator-returning Brotli decode now consumes each declared
  meta-block length, grows its owned output under the caller's limit, and
  decodes that block immediately. This removes the full summary/preflight pass
  from `decodeStreamAlloc*`; caller-owned append APIs retain preflight so a
  failed validation cannot change their logical output length. Shared meta-block
  header parsing keeps the one-shot paths behaviorally aligned, and the
  libbrotli reference benchmark now measures ordinary allocation separately.
  Seven alternating ReleaseFast CPU-8 A/B pairs on structured quality-11 reduce
  median ordinary alloc decode time from about 12.86 ms to 5.78 ms for 500
  iterations (2.23x), with direct caller-buffer decode neutral. The expanded
  12-case reference performance gate and 94-case multi-block differential pass.
  Zstd's parallel mixed-search worker now observes cooperative cancellation
  inside the indexed duplicate suffix scan, rather than only between recursive
  lookahead nodes. Once the caller proves a non-mixed repeat-beam result is
  decisively better, the worker stops at its next candidate position and never
  publishes the partial plan. A pre-cancelled scan/cache oracle and the existing
  24-case full-serial winner comparison pin that behavior. Twelve alternating
  ReleaseFast CPU-8 A/B pairs retain the 640-byte level-9 JSON frame and reduce
  median end-to-end time from about 11.57 ms to 10.55 ms (about 8.8%); repetitive
  text is neutral and the mixed-binary control remains within about 1.2% noise.
  Additional cancellation polls now bracket exact candidate scoring, cursor-
  match discovery, and repeated-pattern discovery. They affect only a mixed
  worker whose result has already become ineligible for publication. Twelve
  fixed-CPU-8 pairs against the preceding commit keep the 80/640/8607-byte
  text/JSON/binary frames while improving their medians by about 1.0%/0.6%/0.3%,
  respectively. Together with cancellable indexed scans, the JSON improvement
  over the pre-cancellation baseline is about 9.4%; the 9-row encode gate,
  90-row stage gate, and 328-case system-zstd compatibility probe all pass.
  One-shot native Zstd encoding now allocates and populates cross-block history
  only for non-final blocks. A single-block frame cannot have a later block that
  references its output, and the last block of a multi-block frame likewise
  never needs to enter the rolling index. A fixed-buffer test proves a 4 KiB
  single-block literal-only frame no longer requires the roughly 1 MiB history
  index, while existing multi-block Huffman/history coverage preserves cross-
  block behavior. Twenty alternating ReleaseFast CPU-8 A/B pairs retain the
  80/640/8607-byte level-9 text/JSON/binary frames and improve their median times
  by about 80.0%/5.8%/3.4%, respectively. The 9-row encode gate, 90-row stage
  gate, 328-case CLI compatibility probe, and 237-case frame probe all pass.
  Native Zstd automatic block selection now materializes the entropy/match frame
  before its raw/RLE competitor. When the input has no qualifying RLE run, the
  existing encoded-frame bound is the exact raw-frame size; a strictly smaller
  entropy result can therefore win without copying the complete input and
  computing its checksum a second time. Equal-size cases still materialize and
  select raw, preserving the established tie rule and byte output. Tests cover
  both the incompressible raw winner and the structured compressed winner.
  Sixteen alternating ReleaseFast CPU-8 A/B pairs retain the 80/640/8607-byte
  level-9 text/JSON/binary frames while improving median encode time by about
  8.5%/2.2%/1.3%, respectively; the 9-row encode gate, 90-row stage gate,
  328-case CLI probe, and 237-case frame probe all pass.
  The delayed raw/RLE comparison now uses an exact zero-copy shape pass for all
  supported inputs, including short whole-block RLE and runs split out of raw
  blocks. If entropy loses or ties, an all-raw result is emitted directly
  without repeating RLE discovery; mixed raw/RLE winners retain the existing
  writer. Sixteen fixed-CPU-8 A/B pairs against the initial delayed-materialize
  implementation preserve the 80/640/8607-byte level-9 frames and improve text,
  JSON, and binary medians by about 1.7%, 2.0%, and 1.1%. Focused tests pin the
  exact raw and short-RLE sizes, and all Zstd encode/stage/compatibility gates
  continue to pass.
  Zstd duplicate arbitration now builds the reusable predecessor index for
  1--4 KiB blocks as well as larger blocks. Small-block queries retain exact
  behavior by walking the complete predecessor chain in oldest-first order;
  mixed, multi-duplicate, and single-duplicate candidates share that one build
  instead of rebuilding an open-addressed exact table for every suffix. The
  level-3 JSON stage profile drops 2/4 KiB multi-duplicate work from about
  5.78/13.50 ms to 2.29/2.13 ms. Sixteen alternating ReleaseFast CPU-8 A/B
  pairs retain the 80/640/8607-byte frames and improve level-3 JSON/binary
  medians by about 41.1%/8.6%; level-9 remains effectively neutral. The exact
  small matcher, reusable-index oracle, 9-row encode gate, 90-row stage gate,
  328-case CLI probe, and 237-case frame probe all pass.
  Level-3 adaptive blocks now omit the legacy multi-duplicate candidate at and
  below 4 KiB. The greedy, lazy, optimal, repeat-beam, repeated-pattern, and
  single-duplicate families still participate; the removed path repeatedly
  rebuilt an exact hash table for each suffix and did not win any final frame in
  a 512-case deterministic mix of structured, periodic, copied, and noisy 32 KiB
  inputs. Baseline and candidate runs produced the same aggregate frame hash.
  Twenty fixed-CPU-8 A/B pairs retain the 80/640/8607-byte benchmark frames and
  improve level-3 JSON from about 81.69 ms to 37.82 ms for two encodes (2.16x),
  and binary from about 62.23 ms to 51.63 ms (1.21x); level 1 is unaffected and
  level 9 remains within roughly 1.5% noise. All encode, stage, CLI-compatibility,
  and native-frame gates continue to pass.
  Levels 2--5 now use the existing deferred-smallest adaptive policy above
  24 KiB, with a conservative 256-byte screen margin: the smaller split still
  runs whenever the larger split is within that margin of the current best. A
  1,024-case, 16-shape level-3 audit found 23 smaller-split winners; one required
  the new margin because the 4 KiB screen trailed primary by 129 bytes, and none
  fell outside 256 bytes. A separate 512-case end-to-end audit remains byte-
  identical. Twenty-four alternating ReleaseFast CPU-8 pairs retain the locked
  80/640/8607-byte frames and reduce two-encode level-3 JSON time from about
  38.56 ms to 20.50 ms (46.8%) and binary from about 53.93 ms to 26.07 ms
  (51.7%); levels 1 and 9 retain their prior screening and remain effectively
  neutral on the long-running controls.
  Repaired the legacy bounded duplicate-matcher reference oracle so it records
  the selected candidate's computed payload length, matching the production
  matcher and the newer exact/indexed references. The stronger full-struct
  equality test had exposed the stale zero-valued field; a focused assertion
  now independently recomputes and pins the returned score before this oracle
  is used to validate future matcher performance changes.
  The bounded duplicate index was configured for four recent predecessors per
  hash instead of eight, halving both its predecessor and lazy match-length
  tables. A later Zig 0.16 integer-width audit (documented below) found that
  this packed-state version actually sampled one predecessor from alternating
  pairs; the historical performance and output evidence therefore describes
  that effective policy rather than a true four-deep search.
  The repaired sentinel oracle, exact/indexed comparisons, a 512-case frame
  hash audit, and a separate 1,024-case split-policy audit all preserve their
  prior results. Twenty-four alternating ReleaseFast CPU-8 pairs retain the
  80/640/8607-byte benchmark frames while improving JSON levels 1/3/9 by about
  2.6%/2.0%/4.1% and binary levels 1/3/9 by about 1.7%/3.1%/4.6%. Isolated
  index construction improves roughly 8--12%; duplicate search itself ranges
  from neutral to a small gain once the shared setup cost is excluded.
  After the <=4 KiB multi-duplicate candidate was removed, those blocks no
  longer had a second production consumer for the shared predecessor index.
  They now use the standalone full-key exact matcher for the remaining single-
  duplicate candidate, avoiding a roughly 0.7--1.1 ms index build per complete
  32 KiB benchmark input. The exact/indexed oracle and 512-/1,024-case frame
  audits preserve their hashes. Twenty-four alternating ReleaseFast CPU-8 pairs
  retain the 80/640/8607-byte frames while improving level-3 JSON by about
  9.9% and binary by about 3.9%; level 1 and level 9 remain within roughly 1.5%
  noise.
  Brotli compressed decoding now retains up to 128 literal context trees per
  meta-block, up from 32, and reports the observed maximum in stream summaries.
  The header parser writes block-switch state, context maps, and prefix trees
  directly into the caller-provided header object; this removes the large
  temporary aggregates and final copy that otherwise made the wider bound
  expensive. A deterministic 1 MiB dictionary-derived corpus makes libbrotli
  quality 5 emit 65 literal context trees and now passes allocator-backed
  summary, one-shot decode, and byte-progressive decode. The upstream
  differential matrix grows from 94 to 95 cases. Sixteen alternating
  ReleaseFast CPU-8 pairs on the existing 12-case reference benchmark show the
  direct-header implementation improving compressed caller-owned decode by
  roughly 49--66% and summary by about 37--48%, while the random/stored control
  remains effectively neutral.
  Brotli's remaining clustered-tree ceiling is now removed for literal trees:
  the decoder retains the complete 256-entry wire range, while distance block
  types and distance context trees move from 32 to a bounded 64-entry tier. The
  general copy decoder also raises its bounded compressed-header prefix from
  4 KiB to 16 KiB. A second deterministic 1 MiB corpus forces libbrotli quality
  5 to emit 169 literal trees, and quality 8 coverage crosses the old distance
  limits; allocator summaries now report observed literal/distance maxima so
  the 99-case upstream differential proves those shapes rather than merely
  decoding them. An optional local-upstream source row additionally reaches
  247 literal trees and 43 distance types/trees when that checkout is present.
  Direct-to-header parsing keeps ordinary 12-case decode medians
  mostly within about 2% of the prior build (with structured quality 4 about 4%
  faster); summary medians trade roughly 1--2% on most compressed rows for the
  broader bounded state.
  ReleaseFast profiling of the planned Brotli encoder found dense scratch
  clearing responsible for about 15.7% of balanced source samples, ahead of
  compressed-header construction at about 7.8%. Literal-context histograms are
  now initialized only when the selected wire candidate actually emits two
  context trees; fast, balanced, and ordinary ratio candidates no longer clear
  the unused 2 KiB array. Ten alternating fixed-CPU-8 A/B pairs preserve every
  fast/balanced/ratio stream size and improve JSON by roughly 3.6%/3.0%/2.9%,
  source by 3.5%/5.2%/3.6%, and log by 3.2%/3.6%/3.1%, respectively.
  Brotli complex-prefix construction now tries the existing linear small-
  alphabet Huffman builder for its at-most-18-symbol code-length alphabet,
  falling back to five-bit package merge only when the unbounded tree is too
  deep. A 1,024-shape deterministic oracle proves the same optimal weighted
  cost, a legal complete tree, and no larger code-length declaration. Ten
  alternating ReleaseFast CPU-8 A/B pairs preserve benchmark stream sizes and
  improve fast JSON/source/log by about 3.2%/2.5%/2.8%; balanced improves by
  0.6%/1.4%/1.4%, and ratio by 0.7%/0.5%/1.9%.
  Planned Brotli distance scratch now follows the encoder's fixed NPOSTFIX=0,
  NDIRECT=15 header: frequency, alphabet, length, and canonical-code arrays use
  79 entries instead of the decoder's RFC-wide 520-symbol maximum. A boundary
  test proves the highest 24-bit meta-block distance still maps inside that
  alphabet and round trips through the distance formula. Ten alternating
  ReleaseFast CPU-8 pairs preserve all benchmark stream sizes; median paired
  speedups are about 13.1%/8.7%/10.9% for fast JSON/source/log, 2.2%/7.2%/6.6%
  for balanced, and 0.9%/1.4%/6.0% for ratio.
  Planner prefix alphabets now use undefined backing arrays because
  `alphabetFromFrequenciesInto` always initializes `len` and every symbol below
  it; unused tail entries are never observable. A focused test starts from
  undefined storage and pins the complete active ordering. Ten alternating
  ReleaseFast CPU-8 pairs preserve every fast/balanced/ratio benchmark size and
  improve paired medians by about 3.6%/2.5%/2.8% for JSON, 1.7%/1.0%/0.5% for
  source, and 3.7%/2.7%/2.9% for log, respectively.
  Command-frequency collection now tracks its small active symbol set while
  commands are scanned, initializing only touched counters and sorting those
  symbols directly instead of clearing and rescanning all 704 command codes. A
  dense-reference oracle pins identical frequencies and deterministic alphabet
  ordering from undefined scratch. Ten alternating ReleaseFast CPU-8 pairs
  preserve every benchmark stream size and improve paired fast/balanced/ratio
  medians by about 11.5%/4.8%/4.4% for JSON, 7.5%/8.6%/5.9% for source, and
  9.9%/6.1%/7.3% for log.
  The all-FSE/Huffman Zstd sequence decoder now keeps its full-width literal
  lookup directly inside each literal-run loop, falling back to the existing
  cold canonical decoder only at stream tails or invalid lookup prefixes. This
  removes a helper boundary and repeated width dispatch from the dominant
  libzstd-produced large-frame path without weakening four-stream validation.
  Ten alternating ReleaseFast CPU-8 pairs preserve decoded checksums while
  improving both 512 KiB `large_json` and `binary_mixed` caller-buffer decode
  by about 2.0%.
  The two high-volume sequence decode specializations now read their bounded
  offset, match-length, and literal-length fields from one 64-bit reservoir
  whenever eight source bytes remain, falling back to the exact-width reverse
  reader at the physical stream boundary. An exhaustive alignment/width oracle
  covers both paths. Twelve alternating ReleaseFast CPU-8 pairs at 200 decodes
  per sample preserve checksums and improve the 512 KiB `large_json` all-FSE/
  Huffman path by a paired median 10.8%, while the `binary_mixed` FSE/FSE/RLE
  path improves 2.3%; both candidates won all twelve pairs.
  Repeat-offset selection now inlines its bounded three-entry queue update into
  sequence decoding. The optimized profile had attributed about 2.4% of large-
  JSON cycles to the remaining call boundary, while the raw-literal mixed-
  binary path uses repeat selectors more heavily. Ten alternating fixed-CPU-8
  pairs at 500 decodes per sample improve `binary_mixed` by a paired median
  7.8% (10/10 wins) and keep `large_json` modestly positive at 0.7% (7/10).
  An independent eight-pair sweep over all 13 reference rows retains matching
  checksums, measures `binary_mixed` at 7.9%, and finds no material regression
  elsewhere (the lowest median is -0.4%, within run noise).
  Added `run-zstd-decode-profile` plus a five-row CSV gate for pure caller-owned
  Vort decode; the profile is a separate executable so adding instrumentation
  cannot perturb the existing reference benchmark binary. It isolates
  `numbered_json`, raw-literal/all-FSE `huffman80k`, sequence-free Huffman
  `ascii64k`, multi-block `large_json`, and `binary_mixed` without timing
  libzstd, allocator wrappers, or inspection
  passes. Its gate pins block and compressed-block counts for both large rows,
  preventing a libzstd or corpus change from silently replacing the intended
  multi-block workloads. Fixed-CPU perf now attributes `huffman80k`
  primarily to generic sequence decoding, `large_json` to the all-FSE/Huffman
  loop and copy work, and `binary_mixed` to generic sequence/copy work. Several
  measured candidates were rejected: an all-FSE/raw loop improved its target by
  about 27% but regressed `binary_mixed`; fused state/extra-field reads and a
  cached reverse reader were neutral or negative across the full matrix.
  Added a separate `run-lz4-decode-profile` executable and four-row gate for
  caller-owned block decode. It pins three match-heavy shapes plus the exact
  256 KiB single-literal incompressible shape, keeping profiler instrumentation
  out of the liblz4 reference binary. The first pure profile attributes almost
  all Vort cost on that raw row to the existing explicit vector copy. A direct
  compiler-rt `memcpy` replacement regressed it by roughly 8--11%; x86
  `rep movsb` improves the 256 KiB target while losing on 1 KiB literals, so
  the production helper selects it only from 192 KiB on x86_64 and keeps the
  existing explicit-vector path below that threshold. Thirty-two alternating
  ReleaseFast CPU-8 profile pairs measure the isolated raw row at about `1.28x`
  paired median (30/32 wins); all three match-heavy profile rows stay within
  about 0.4% of baseline. A direct compiler-rt `memcpy` replacement and lower
  `rep movsb` thresholds were rejected because they regressed ordinary rows.
  A post-commit eight-run CPU-8 comparison at 20,000 decodes per run measures
  the locked 256 KiB raw row at a `1.0474x` paired median versus liblz4 1.9.4,
  with Vort winning all eight runs (median about 50,728 versus 48,422 MiB/s).
  A 30,000-decode `perf` capture attributes 98.26% of the isolated decoder's
  samples to `copyBulk`, confirming that the remaining cost is the unavoidable
  payload copy rather than token parsing. This establishes a narrow lead for
  this exact caller-owned single-literal shape, not a general LZ4 superiority
  claim.
  Sequence-interleaved Huffman literal runs now use the same unchecked bulk
  prefix peek/consume primitives as whole-section decoding after proving that a
  full-width prefix remains. Stream tails retain the checked canonical fallback.
  Ten alternating fixed-CPU-8 pairs at 500 decodes improve `large_json` by a
  paired median 1.8%; an independent eight-pair 13-row sweep measures 2.1%
  (8/8 wins), keeps the FSE-heavy `huffman80k` row slightly positive, and finds
  no material regression while preserving every decoded checksum.
  Large four-stream, sequence-free literal sections now reuse one reverse-bit
  reservoir load for two consecutive Huffman lookups whenever both full-width
  prefixes remain. A width-1...11/alignment oracle pins the paired peek against
  checked reads, while stream tails keep the canonical fallback. Eight
  alternating fixed-CPU-8 runs improve the 64 KiB high-entropy ASCII row by a
  paired median 16.2% (8/8 wins); `huffman80k`, `large_json`, and `binary_mixed`
  stay within about 0.4% at the median with matching checksums.
  Sequence-driven Huffman literal helpers now borrow their parsed section
  instead of copying the structure (including its roughly 1 KiB canonical
  tree) for each literal run. Sixteen alternating fixed-CPU-8 pairs improve
  `large_json` by a paired median 5.2% (15/16 wins); longer confirmation keeps
  `huffman80k` and `binary_mixed` effectively neutral at roughly +0.1% and
  -0.4%, respectively, with matching checksums.
  The two large compressed-FSE sequence loops now index their validated decode
  tables without repeating three state-range branches per sequence. Initial
  states are bounded by the table logs and every transition is produced by the
  validated FSE entry; generic paths retain checked lookup for hostile states.
  Twelve alternating fixed-CPU-8 pairs at 500 decodes improve `large_json` by
  a paired median 0.9% (10/12 wins), with `binary_mixed` neutral and
  `huffman80k` slightly positive. An independent eight-pair 13-row sweep
  measures `large_json` at 1.7% (8/8) with matching checksums and no material
  control-row regression.
  Single-tree literal-frequency collection now uses a 256-bit first-seen map,
  initializing only active byte counters while retaining O(1) updates. The
  ratio-only two-context candidate keeps dense histograms because both trees
  are populated together. A sparse-vs-dense oracle pins frequencies and final
  ordering. Ten alternating ReleaseFast CPU-8 pairs preserve every benchmark
  stream size and improve paired fast/balanced/ratio medians by about
  4.5%/4.1%/2.7% for JSON, 2.4%/4.2%/2.4% for source, and 3.2%/1.8%/2.4% for
  log.
  `PlannedStreamEncoder` now retains token and command capacity for balanced
  small-block encoding instead of delegating every call to the allocating
  one-shot lazy planner. The reusable entry preserves the production scan/hash
  selection and the balanced short-match wire arbitration; caller-buffer
  encoding shares the same retained path. Cross-input parser and encoder tests
  pin token statistics, exact wire bytes, and stable retained capacity. Ten
  alternating ReleaseFast CPU-8 pairs improve reusable balanced JSON/source/log
  encoding by about 14.9%/13.1%/7.0%, respectively, with identical sizes.
  The reusable Brotli encoder now exposes `encodeScratchWithOptions`, extending
  borrowed encoder-owned output from fast mode to balanced and ratio modes.
  Small balanced blocks reuse parser, command, and output capacity; plans that
  need exact short-match alternatives and one-shot ratio/large inputs copy only
  the selected final stream into retained output. Level-wide wire/capacity tests
  pin the borrowed-slice lifecycle. Ten alternating ReleaseFast CPU-8 pairs
  improve balanced JSON/source/log over allocator-returning reuse by about
  1.6%/1.7%/0.9%, respectively, with identical output sizes.
  The Brotli bit writer now appends a new zero byte directly whenever its
  output capacity is already available, retaining explicit bounded-output
  failure and allocator growth only at true capacity boundaries. A bounded
  two-byte test pins both the byte order and overflow contract. Sixteen
  alternating fixed-CPU-8 stage pairs improve full planned JSON/source/log
  encoding by about 0.5%/1.8%/1.7%, respectively, with every pair positive and
  the seven-row libbrotli encode gate green.
  Planner payload Huffman codes now use a dedicated non-empty, at-most-15-bit
  writer that expands the bounded one-to-three-byte operation directly instead
  of entering the general arbitrary-width loop. Headers and command/distance
  extra bits retain the general writer, while a start-alignment, width, and
  representative-value oracle pins identical bytes and final bit positions; bounded
  overflow remains explicit. Sixteen alternating ReleaseFast CPU-8 stage pairs
  at 20,000 encodes preserve output checksums and improve full planned JSON,
  source, and log medians by about 2.2%, 1.3%, and 2.0%, respectively
  (14/16, 16/16, and 15/16 wins). The seven-row libbrotli encode gate and
  99-case upstream differential remain green.
  The at-most-64-symbol Huffman builder now stores weights, parent indexes, and
  depths in compact parallel arrays instead of a padded node struct, relying on
  the proven creation-order serial invariant for stable equal-weight choices.
  A 1,024-case oracle retains exact lengths against the heap reference. A first
  sixteen-pair ReleaseFast CPU-8 stage run at 20,000 encodes improved full
  planned JSON/source/log medians by about 1.8%/2.9%/1.0% (15/16, 16/16, and
  14/16 wins). A further eight pairs after removing unnecessary parent/depth
  initialization confirmed about 2.5%/3.0%/2.1% medians, with matching output
  checksums, a green seven-row libbrotli encode gate, and the 99-case upstream
  differential still green.
  Complex-prefix RLE generation now accumulates its 18-symbol code-length
  histogram as tokens are emitted instead of scanning the completed token
  array again. A 512-pattern oracle pins both exact tokens and all frequencies
  against the independent scan. Sixteen alternating ReleaseFast CPU-8 stage
  pairs at 20,000 encodes improve full planned JSON/source/log medians by about
  0.6%/1.2%/0.3% (16/16, 16/16, and 10/16 wins), with matching checksums; the
  seven-row libbrotli encode gate and 99-case upstream differential remain
  green.
  Complex-prefix code-length tokens now use the same validated narrow Huffman
  writer as command/literal/distance payload symbols. Their code widths are at
  most five bits, while repeat extras and tree declarations remain on the
  general writer. Sixteen alternating ReleaseFast CPU-8 stage pairs at 20,000
  encodes preserve checksums and improve full planned JSON/source/log medians
  by about 3.5%/3.7%/3.5%, with all 16 pairs positive for every corpus. The
  seven-row libbrotli encode gate and 99-case upstream differential remain
  green.
  The complex-prefix production RLE path now writes directly into its proven
  stop-index-sized token buffer while collecting frequencies, instead of
  repeating an `ArrayList.appendBounded` capacity branch for every token. The
  independent bounded encoder remains the oracle and public internal safety
  path. Sixteen alternating ReleaseFast CPU-8 stage pairs at 20,000 encodes
  preserve checksums and improve full planned JSON/source/log medians by about
  3.1%/3.5%/3.6% (14/16 wins for each); the seven-row libbrotli encode gate and
  99-case upstream differential remain green.
  The shared one-shot tiny hash parser now sizes its lazy-head initialization
  bitmap to the actual 4K bucket table instead of zeroing the generic 32K-table
  bitmap. Reusable scratch uses the same exact 64-word shape, reducing the
  per-plan clear from 4096 bytes to 512 bytes without changing head or
  predecessor indexing. Sixteen alternating ReleaseFast CPU-8 stage pairs at
  20,000 encodes preserve checksums and improve isolated parser medians by
  about 1.71x/1.55x/1.59x for JSON/source/log; full planned encoding improves
  about 14.8%/7.1%/11.8% (16/16, 15/16, and 15/16 wins). Tiny-parser token/stat
  oracles, the DEFLATE incremental gate, the 90-row native Zstd stage gate, the
  nine-row libzstd encode gate, the seven-row libbrotli encode gate, and the
  99-case Brotli differential remain green.
  The shared hash parser's accept-all preflight now proves its fixed-cost
  condition from the shortest permitted match instead of scanning every length
  through 258. The literal-minus-length-code margin is monotonic between the
  fixed-code boundaries and only improves at length 258; an exhaustive matrix
  across windows, normalized min/max lengths, and savings thresholds matches
  the former loop exactly. Sixteen alternating ReleaseFast CPU-8 stage pairs at
  20,000 encodes improve isolated Brotli parser medians by about
  1.78x/1.55x/1.57x for JSON/source/log and full planned encoding by about
  10.9%/6.7%/8.3% (16/16, 16/16, and 15/16 wins). The DEFLATE incremental,
  90-row native Zstd stage, nine-row libzstd encode, seven-row libbrotli encode,
  and 99-case Brotli differential gates remain green.
  Planner wire encoding now caches the command symbol resolved during its
  mandatory frequency pass for plans of at most 128 commands, avoiding a second
  pair of insert/copy length classifications and command-table lookup during
  payload emission. Larger plans keep the previous recomputation path instead
  of growing stack use with input size; a 128/129-command boundary test covers
  both paths. Sixteen alternating ReleaseFast CPU-8 stage pairs at 20,000
  encodes preserve checksums and improve full planned JSON/source/log medians
  by about 3.8%/5.7%/2.6%, with every pair positive. The bounded-output tests,
  seven-row libbrotli encode gate, and 99-case upstream differential remain
  green.
  Code-length RLE now scans zero gaps eight bytes at a time before its scalar
  tail, preserving the exact token stream while avoiding one branch per zero
  in sparse literal/command alphabets. A boundary oracle checks every start/end
  pair around aligned and unaligned non-zero lengths. Sixteen alternating
  ReleaseFast CPU-8 stage pairs at 20,000 encodes preserve checksums and improve
  full planned JSON/source/log medians by about 1.15%/1.05%/1.14% (16/16,
  15/16, and 16/16 wins); the seven-row libbrotli encode gate and 99-case
  upstream differential remain green.
  The small Huffman builder now writes only the active prefix of the caller's
  length buffer instead of clearing all 64 slots first. Every caller consumes
  exactly that prefix before scattering into its already-zero dense table; a
  poison-tail test pins the narrower write contract alongside the existing
  exact heap-reference oracle. Sixteen alternating ReleaseFast CPU-8 stage
  pairs at 20,000 encodes keep JSON neutral-positive and improve source/log by
  about 0.7%/0.66% (10/16, 16/16, and 16/16 wins). Brotli encode/differential,
  DEFLATE incremental, and Zstd native/reference encode gates remain green.
  Brotli complex-prefix decoding now records the ascending active-symbol list
  during its mandatory validation pass and hands it to a trusted sparse
  canonical decoder builder. This avoids rescanning all 256/520/704 code-length
  slots while preserving the same grouped decode entries and validation. A
  focused dense-versus-sparse table oracle pins every active entry and bit-width
  index. Sixteen alternating ReleaseFast CPU-8 pairs preserve checksums across
  the 12-case libbrotli matrix: compressed rows improve by about 0.8--10.0%,
  while tiny and random/stored controls remain within 0.2% noise.
  Brotli simple-prefix decoding now builds its two-to-four canonical entries
  directly from the wire symbol/length pairs, rather than clearing and scanning
  a 256-, 520-, or 704-slot temporary length array. Focused tests compare both
  legal four-symbol tree shapes with the dense constructor and retain malformed
  list rejection. Sixteen alternating ReleaseFast CPU-8 pairs against the
  preceding sparse-complex change improve all compressed rows: roughly
  1.0--2.8% at quality 0, 5.5--6.7% at quality 3, 11.1% for structured quality
  4, and 7.2--14.0% at quality 11. Tiny and random/stored controls remain
  within about 0.5% noise, with matching checksums.
  Complex-prefix code-length symbols now decode through a complete five-bit
  lookup table instead of reading one bit and scanning the 18-symbol table at
  every code width. Single-symbol code-length trees retain their zero-bit fast
  path, and malformed/truncated streams keep the checked table fallback rules.
  Sixteen alternating ReleaseFast CPU-8 pairs against the preceding commit
  preserve all checksums and improve every compressed row: about 15.2--18.5%
  at quality 0, 6.5--9.0% at quality 3, 6.7% for structured quality 4, and
  5.6--14.8% at quality 11. Tiny remains within 0.3% noise.
  Added `run-br-compressed-header-profile` and its CSV gate to isolate Brotli
  compressed-header parsing from payload decode. The q0/q3/q4/q11 cases report
  block-switch setup, context maps, and literal/command/distance tree stages; a
  deterministic 1 MiB clustered q8 case holds 52 literal trees, three command
  trees, and 17 distance trees so high-tree-count costs remain visible. Nested
  counters further split prefix construction into code-length-header parsing,
  RLE expansion, canonical table construction, and simple trees. Initial
  ReleaseFast CPU-8 evidence attributes about 60% of the clustered header to
  literal trees; within all tree construction, code-length RLE is the largest
  measured substage and canonical construction is second. A no-memset tail
  experiment and a bulk repeat-fill experiment were both rejected after the
  12-case libbrotli decode matrix showed mixed or negative results, so this
  commit intentionally adds measurement infrastructure without changing the
  production prefix-code algorithm.
  The compressed-header profile now attributes those prefix-code substages to
  literal, command, and distance tree families independently, including active
  entries and code-length/repeat work. The clustered q8 fixture currently
  reports 43/3/17 complex literal/command/distance trees with 1767/415/653
  active entries and 528/96/80 repeat symbols, respectively. This confirms that
  literal-tree RLE is the dominant high-tree workload while ordinary q3/q4/q11
  command and distance trees are mostly simple. Several measured candidates
  were rejected rather than broadening production code: whole-header and
  literal-only buffered readers regressed the 12-case decode matrix by roughly
  2--6% despite improving the isolated clustered header; context-map preamble
  fusion, zero-repeat write elision, compact active-length construction, small
  MTF specialization, and repeat-extra-bit fusion were also neutral or mixed.
  The libbrotli reference decode gate now includes the same deterministic
  `clustered_q8` payload with a reduced iteration count and validates its
  observed 52 literal trees, three command block types, and 17 distance trees.
  This closes a benchmark blind spot: the previous 12 rows exercised at most a
  few trees, so changes aimed at clustered headers could pass or fail only from
  code-layout effects. The first ReleaseFast CPU-8 result is deliberately
  recorded as a gap rather than a claim: Vort is about 219 MiB/s versus
  libbrotli's 1961 MiB/s (`0.112x`) on this 1 MiB high-tree-count decode.
  Profiling that new end-to-end row corrected the earlier header-only
  hypothesis: roughly 60% of cycles were in `minimalStaticDictionaryWord`,
  which linearly scanned the historical compatibility-coverage list before
  calling the already-complete RFC dictionary transformer. Removing that
  redundant scan keeps the public coverage metadata intact and has an
  exhaustive test showing every retained tuple produces the same transformed
  bytes through the complete implementation. Sixteen alternating ReleaseFast
  CPU-8 pairs improve `clustered_q8` decode by about `2.66x`; structured q4 and
  q11 improve about `1.72x` and `1.74x`, while the remaining compressed rows
  improve roughly 2--4% or remain effectively neutral.
  The reference CSV now records `static_dictionary_copies` and
  `static_dictionary_bytes`; the gate requires the clustered row to retain more
  than 1000 dictionary copies and 4 KiB of transformed output. This prevents a
  future encoder or corpus change from silently removing the workload that
  exposed the linear-scan bottleneck while leaving a misleading green timing
  row. Post-fix profiling moves the dominant cost to compact literal, command,
  and distance Huffman decode. No-extra-memory canonical-range and in-table
  lookup prototypes improved clustered decode by about 6--79%, but regressed
  common q0/q3/q11 rows by up to roughly 37%; both were rejected.
  Added an explicit, opt-in `HuffmanTable` tail-lookup primitive for the next
  clustered-decoder design. It stores a packed 8-bit lookup inside otherwise
  unused canonical-entry capacity, proves the table size is unchanged, refuses
  dense tables without enough slack, and is bit-for-bit checked against compact
  decoding. No production codec calls it yet: the first global-dispatch
  prototype accelerated `clustered_q8` by about `1.79x`, but regressed common
  text/structured rows substantially, so only the isolated reusable primitive
  was retained for a future dedicated clustered state machine.
  Wired that tail lookup into an isolated large-stream decoder selected before
  entering the existing small-stream function. Only meta-blocks with at least
  16 literal context trees build the in-table lookups, and only their literal
  loop uses them; command/distance trees and every ordinary stream retain the
  existing compact decoder. Sixteen alternating ReleaseFast CPU-8 pairs against
  `e90d1e7` improve `clustered_q8` by about `1.19x`, while the twelve established
  rows remain neutral-to-positive at the median. The lookup still falls back to
  compact decoding for long codes and refuses trees without enough unused entry
  capacity, preserving the 290 KiB header footprint.
  Literal lookup preparation now preflights the whole tree group before writing
  any in-table lookup bytes. A mixed sparse/dense regression test proves that a
  later ineligible tree leaves earlier compact trees untouched, so fallback is
  transactional instead of depending on every future corpus sharing the current
  all-eligible clustered shape.
  Header profiling now reports eight-bit tail-lookup eligibility globally and
  per tree family. All 52 literal, three command, and 17 distance trees in the
  current clustered q8 fixture have enough unused canonical-entry capacity,
  proving that the optimization can cover that workload without increasing the
  header footprint. A follow-up that enabled command/distance lookups in the
  same large-stream function improved the clustered row by about 21%, but was
  rejected because unrelated small rows moved backward by roughly 1--4% from
  code-layout effects; future expansion must live in a more isolated module.
  `run-br-reference-bench` now accepts `--vort-only`, skipping dictionary
  differentials, libbrotli timing, summary, and allocation variants so `perf`
  profiles contain only caller-owned Vort decode. The first post-lookup
  clustered profile attributes about 24% to command Huffman decode, 31% to
  distance decode/extra bits, 10% to literal decode, and 7% to UTF-8 context
  selection, providing a clean next-hotspot baseline.
  High-tree literal decoding now uses two compile-time 256-byte tables for the
  RFC UTF-8 previous-byte classes while ordinary Brotli paths retain the
  branch classifier. An exhaustive four-mode, 256x256 byte-pair oracle proves
  the specialized context values are identical. Sixteen alternating
  ReleaseFast CPU-8 pairs against `8333cd5` improve `clustered_q8` by about 7.0%
  at the median; the established small-stream rows remain within about 1.2%
  noise except structured q4, which improves about 2.6%.
  Brotli regular-distance reconstruction now uses validated `u32` arithmetic
  after checking the symbol and extra-bit width. RFC bounds keep the complete
  expression below 2^30, so the former chain of four generic `usize` overflow
  checks was redundant. A maximum NPOSTFIX/NDIRECT/symbol/extra test pins that
  bound and rejects an out-of-range extra value. Twenty-four alternating
  ReleaseFast CPU-8 pairs improve `clustered_q8` by about 0.9% at the median;
  the other twelve rows remain within roughly 1.2% noise.
  Regular-distance parsing now also passes its already-computed `xcode` and
  extra-bit width directly into the arithmetic helper instead of deriving both
  a second time. Sixteen alternating ReleaseFast CPU-8 pairs against `0daaacc`
  improve `clustered_q8` by about 2.3% at the median; the remaining rows stay
  within roughly 2.4%, with their small mixed movement treated as noise rather
  than a broad throughput claim.
  Added the first standardized Zstd seekable-format reader slice.
  `inspectNativeSeekTable` locates the terminal skippable frame from EOF,
  validates its dedicated magic, descriptor reserved bits, payload length,
  entry width, and cumulative compressed extent, and exposes a zero-allocation
  iterator with compressed/decompressed offsets, sizes, and optional XXH64-low
  checksums. Offset lookup and indexed entry access are public. Tests cover
  checksum/no-checksum tables, boundary lookup, malformed/truncated tables, and
  byte-for-byte output generated by the local upstream zstd seekable
  compressor. The writer now serializes checksum/no-checksum seek tables through
  allocating, append, and caller-buffer APIs, and the one-shot seekable encoder
  splits input into independent native frames before appending that table. Vort
  round trips its own output, and the local upstream zstd seekable decoder reads
  an interior byte range from it exactly. Caller-buffer and allocating range
  APIs now decode only intersecting independent frames, preflight exact scratch
  requirements, and verify optional per-entry XXH64-low checksums. Cross-frame,
  zero-length, short-scratch, out-of-range, and corrupt-checksum tests cover the
  new path. Dictionary-set range variants resolve each independently encoded
  frame by its own Dictionary_ID; a two-dictionary cross-frame test also pins
  the missing-dictionary error path. Seekable encoding now also applies one
  preset dictionary to every independent frame, with direct and dictionary-set
  selection APIs; tests pin per-frame Dictionary_ID metadata and range round
  trips. Repeated range reads can now build a caller-owned cumulative
  `NativeSeekIndex` once: entry access is O(1), decompressed-offset lookup is
  O(log n), and indexed decode avoids reparsing the terminal table or scanning
  from frame zero. The direct/caller-buffer and allocating paths both support
  dictionary sets and checksum verification; tests cover undersized index
  storage, empty frames, cross-frame reads, index reuse, and corrupt checksums.
  Indexed decode now also fuses range validation, first-frame lookup, and
  scratch sizing so one request performs only one binary search; the allocating
  wrapper reuses that prepared range instead of repeating preflight. A focused
  16-pair ReleaseFast CPU-8 microbenchmark over 16,384 one-byte frames and
  65,536 random indexed reads measured a 1.24x median speedup, with 10/16
  paired wins; the intentionally tiny payload makes this an index-overhead
  result rather than a general decompression-throughput claim.
  Level-9 match arbitration now stages low-alphabet primary blocks serially:
  it runs the bounded non-mixed families first and entirely avoids recursive
  mixed search when the existing 24x dominance proof succeeds. Four distributed
  256-byte windows and a 40-symbol limit keep wide binary blocks on the parallel
  path and avoid serializing their expensive searches; adaptive 4/8 KiB blocks
  also retain the existing parallel behavior. Two fixed-CPU-8 samples totaling
  40 alternating pairs preserve the locked 80/640/8607-byte level-9 frames and
  improve JSON median encode time by about 1.6--2.4% (12/16 and 14/16 wins);
  binary remains within 1% noise. Text is sub-millisecond and noisy, ranging
  from +0.5% to -4.8%, so no text throughput claim is made. Narrow/wide
  classifier tests, a 200-case generated 16--64 KiB corpus with matching
  aggregate frame hashes, and serial-wire comparisons cover both scheduling
  branches.
  Level 1 now also returns an already-computed primary frame immediately for
  wide-alphabet, single-block input instead of launching its 1/2 KiB adaptive
  split ladder. A 144-case audit spanning 9--128 KiB, 41--256 symbols, and
  plain plus copied-tail shapes found zero adaptive winners and identical
  aggregate frame hashes. Twenty alternating ReleaseFast CPU-8 pairs preserve
  the locked 80/640/8607-byte level-1 frames and improve the binary median by
  5.28x with 20/20 wins; text and JSON remain within about 0.6% noise. The
  low-alphabet JSON path continues to evaluate adaptive candidates because it
  has a known split winner.
  Level-1 primary block arbitration now also reuses that early single-duplicate
  query when its repeat beam is decisive. Previously the decisive branch ran
  the same full-block indexed match search a second time to fill a local value
  that the later `early_single` branch could never consume. A focused policy
  test pins when the query is required, and the existing single-candidate wire
  oracle protects the reused result. Twenty-four alternating ReleaseFast CPU-8
  pairs preserve the 80/640/8607-byte level-1 frames while improving JSON by
  about 14.9% (23/24 wins), binary by about 11.8% (22/24 wins), and text by
  about 1.3% (17/24 wins). A speculative double-fast replacement was rejected:
  it was much quicker, but a 144-case size audit found up to 33.3% expansion
  versus the exact existing winner.
  Added caller-owned `LevelFrameEncoder` scratch/alloc/into/append APIs for
  repeated one-shot-style encoding. They preserve the public compression-level
  and adaptive-selection policy, but reuse the primary native encoder and return
  its borrowed result directly whenever no split arbitration is needed. Tests
  compare levels 0/1/9 and checksum/content-size options byte-for-byte with the
  one-shot facade, cover caller buffers and prefixed append output, verify
  retained repeat-beam capacity, recover after an invalid level, and round trip
  every result. A fixed-CPU-8 median-of-nine benchmark over sixteen repeated
  32 KiB level-1 binary encodes measured 1.14x versus the allocating one-shot
  facade, with identical wire bytes.
  `PlannedStreamEncoder.encodeWithOptionsAlloc` now builds fast streams up to
  32 KiB in the encoder-owned output scratch and allocates only the final
  caller-owned copy. Returned slices remain independent of later calls, and a
  failed final allocation leaves the reusable encoder ready to recover. Sixteen
  alternating ReleaseFast CPU-8 pairs at 20,000 encodes preserve output
  checksums and improve JSON/source/log medians by about 2.7%/2.9%/2.9%
  (16/16, 15/16, and 16/16 wins). The seven-row planned and 13-row libbrotli
  reference gates, root Brotli smoke, and 99-case upstream differential remain
  green.
  Default-window, metadata-free Brotli stored encoding now writes caller-owned
  outputs up to 16 KiB directly: the fixed three-byte uncompressed-block header,
  payload, and final marker bypass the generic bounded bit writer. A generated
  boundary oracle compares exact bytes against the allocating writer through
  16,385 bytes, including the optimized cutoff, and nine representative frames
  decode identically in Node. Twenty alternating ReleaseFast CPU-8 pairs at
  20,000 calls preserve observed output checksums and improve 0/3/39/512-byte
  inputs by about 1.73x/2.54x/2.46x/1.73x; 4/8/16 KiB improve about
  4.7%/3.0%/1.9%. The generic path remains selected above 16 KiB, where the
  fixed writer overhead is no longer material. Brotli stored/root tests, the
  seven-row planned encode gate, 13-row libbrotli reference gate, and 99-case
  upstream differential remain green. Stored-size preflight now also counts
  the four-bit WBITS encodings for windows 18--24 correctly; caller-buffer
  tests cover every legal window size and metadata fallback without the former
  spurious `SizeMismatch`.
  Brotli stored allocating APIs now use their exact encoded-size preflight to
  allocate once and then call the caller-buffer core, rather than growing an
  `ArrayList` and potentially remapping it during `toOwnedSlice`. Contiguous
  and three-chunk output are checked byte-for-byte against the independent
  append writer for default, alternate-window, and metadata configurations;
  first-allocation failure is also covered. Twenty alternating ReleaseFast
  CPU-8 pairs at 20,000 calls preserve observed output checksums. Contiguous
  0/39/512-byte inputs improve about 2.05x/2.73x/2.41x, with 4/16 KiB improving
  about 1.43x/1.16x; the corresponding chunked cases improve about
  1.76x/1.36x/1.60x/1.33x/1.26x, with at least 19/20 wins in every row. The
  stored and root Brotli suites, seven-row planned encode gate, 13-row
  libbrotli reference gate, and 99-case upstream differential remain green.
  The same direct stored-block writer now covers default-window chunked
  caller-buffer streams whose combined payload is at most 16 KiB, while
  preserving one meta-block per non-empty caller chunk and ignoring empty
  chunks exactly as before. A boundary oracle compares the complete wire with
  the independent append implementation, including empty interleaves and the
  16 KiB cutoff; four generated frames also decode byte-for-byte through Node.
  Twenty alternating ReleaseFast CPU-8 pairs at 20,000 calls improve one-chunk,
  three-chunk, empty-interleaved, and 32-by-16-byte inputs by about
  1.68x/1.93x/1.64x/2.36x; a three-chunk 16 KiB stream improves about 8.9%,
  with 17--20 wins out of 20 and unchanged output checksums.
  Reusable `StoredStreamEncoder` owned and borrowed outputs now delegate to the
  exact-size and direct caller-buffer cores instead of rebuilding through the
  append API. Owned results remain independent, while warmed scratch output is
  allocation-free for contiguous and chunked input. Twenty alternating
  ReleaseFast CPU-8 pairs at 20,000 calls preserve all observed checksums and
  win 20/20 in all sixteen measured rows: 39/512-byte contiguous owned and
  scratch paths improve about 2.8--3.6x, chunked variants improve about
  2.1--2.9x, and 16 KiB variants improve about 1.07--1.34x. Brotli stored/root
  tests and the planned, libbrotli-reference, and 99-case upstream gates remain
  green.
  Added production fast-level Brotli chunked encoding as one RFC stream rather
  than concatenated independent streams. Each non-empty caller chunk is planned
  independently and chunks above 32 KiB are split, bounding parser memory; each
  block keeps compressed output only when its exact bit position does not exceed
  the stored alternative. The reusable encoder exposes borrowed, owned,
  caller-buffer, and append variants, while top-level bound/alloc/into/append
  helpers are exported from `root.zig`. Tests cover empty chunks, generated
  mixed data, compressed/stored/compressed transitions, automatic large-chunk
  splitting, output bounds, ownership, failure recovery, and one-byte-input /
  seven-byte-output incremental decoding. Node accepts both the mixed three-
  block stream (126 bytes for 5,410 decoded bytes) and the automatically split
  65,568-byte stream (201 bytes). A 16-run fixed-CPU-8 comparison against three
  separately encoded frames is throughput-neutral (`1.001x`, 9/16 wins) while
  reducing framing from 127 to 126 bytes; this is an API/streaming capability
  gain rather than a broad speed claim.
  The upstream multi-meta-block differential now repeats every libbrotli
  `tiny-flushes` and metadata stream across an 8x7 input/output chunk matrix
  (1--255 compressed bytes per call and 1--256 output bytes per call). Across
  four qualities in each family this adds 448 byte-progressive boundary runs
  while retaining the existing 99-case format matrix. A bounded cross-meta-
  block LZ77-history encoder prototype was also measured and rejected: despite
  shrinking a duplicated 8 KiB fixture from 8,200 to 4,113 bytes, it made the
  established unrelated mixed-chunk workload about five times slower. No part
  of that regressing encoder path was retained.
  The same differential now also feeds seven non-flushed, one-shot libbrotli
  streams through the 8x7 progressive boundary matrix. The cases span quality
  0/1/4/5/6/9/11, generic/text/font modes, windows 10/16/18/20/22/24, Unicode,
  binary, repetitive, and clustered data. Together with the flushed and
  metadata families, the gate now reports 15 matrix streams and 840 distinct
  input/output chunk combinations in addition to its 99 primary cases.
  The byte-progressive copy decoder now computes the ring source once per
  resumed copy span and advances it with a conditional wrap, instead of
  performing an integer remainder for every copied byte. A dedicated 64 KiB
  overlapping-copy benchmark and schema gate keep the hot path observable. In
  twenty alternating ReleaseFast CPU-8 pairs at 500 decodes, the median moved
  from 431.5 ms to 325.2 ms (`1.33x`), with 20/20 candidate wins and identical
  output checksums. A broader dual-cursor design was rejected after regressing
  the same benchmark by about 2.8%.
  Expanded the byte-progressive Brotli decoder's distance block-type and
  context-tree storage from a 64-entry implementation tier to the complete
  256-entry RFC count range. A repository-owned heterogeneous 15 MiB source
  corpus makes libbrotli 1.1 quality 8 at window 22 emit 220 distance
  types/trees, and the
  upstream differential now decodes that real stream through 17-byte input and
  31-byte output chunks. This closes the first incompatibility found by a
  broader local-source audit while keeping the entropy header bounded and
  caller-owned history explicit.
  Ratio-mode Brotli encoding now evaluates bounded dynamic-programming LZ77
  plans with both three- and four-byte minimum matches for 4--64 KiB inputs.
  Each proposal is fully encoded and retained only when its exact Brotli wire
  beats the existing lazy plan, so output size remains monotonic and large
  inputs retain the prior memory/latency path. On the first 32 KiB of
  `src/br.zig`, the selected stream falls from 5,699 to 5,534 bytes: smaller
  than libbrotli quality 5 (5,565 bytes) and within 1.3% of quality 8 (5,467
  bytes), though encoding is intentionally much slower. The planned-encode
  gate now retains this real-source ratio row in addition to its tiny synthetic
  cases. The retained optimal search uses a 256-chain/128-candidate cap and
  only the profitable four-byte minimum-match proposal; sixteen interleaved
  ReleaseFast CPU-8 pairs against the earlier 512-chain/two-proposal version
  preserve source/JSON/log/mixed bytes while improving median ratio-encode
  time by 1.85--1.96x with 16/16 wins in every row.
  Ratio-mode entropy arbitration now tests six compact two-tree UTF-8 context
  suffix maps on the selected optimal command plan. Each map is fully encoded
  and must beat the current exact wire; the source corpus selects context 48
  instead of the previous lowercase-only context 56 split, trimming another
  four bytes (5,534 to 5,530) while remaining within 1.2% of libbrotli quality
  8. Context-map round-trip tests cover every retained cutoff, and the q8
  source gate pins the new 5,530-byte ceiling.
  The same exact-wire search now enumerates NPOSTFIX=0 direct-distance counts
  `0/3/7/15` rather than hard-coding 15. The source plan selects NDIRECT=0,
  reducing its stream by another four bytes to 5,526 (1.08% above libbrotli
  quality 8); every alternative remains guarded by complete final-wire size.
  Stable Brotli ratio encoding now accepts inputs larger than the RFC 2^24-byte
  meta-block maximum instead of returning `InvalidBlockPlan`. It routes such
  slices through the bounded 32 KiB planner and emits one legal multi-meta-
  block stream with per-block compressed/stored fallback. A 2^24+17-byte
  boundary test checks multi-block compression and exact round-trip, and the
  Node differential independently decodes the same oversized stream.
  Added `BrotliIncrementalPlannedStreamEncoder`, a caller-to-caller encoder
  that buffers at most one configurable block, plans each block with the fast
  LZ77/Huffman path, and falls back to stored wire when compression would
  expand. It reuses the stored encoder's backpressure, flush, metadata, limit,
  reset, and continued-stream state machine. Focused tests cover tiny input/
  output slices, mixed compressed/stored blocks, and metadata between flushed
  compressed blocks. Its codec-owned token, command, and hash-index storage is
  retained across blocks and `nextStream` calls; a public retained-capacity
  metric and repeated-stream test pin that warmed reuse contract.
  Incremental planned blocks now retain up to the advertised window of decoded
  source bytes and seed the next block's hash matcher from that history. The
  history remains codec-owned, bounded, and is cleared by `nextStream`; a
  duplicated 4 KiB random block falls from 8,199 independent-block bytes to
  4,113 bytes, while tiny-output Vort and Node decoders reproduce the original
  8 KiB payload. The incremental planner benchmark now retains this as a
  separate `cross_block` row, checks the compression delta and decoded wire,
  and reports the bounded retained state (about 71 KiB on this fixture).
  Cross-block command construction now has direct malformed-token coverage for
  distances beyond combined history and matches beyond block output. A WBITS=10
  incremental regression also verifies that retained history is truncated to
  the advertised 1,008-byte backward limit instead of leaking a block-sized
  reference into the wire.
  The dictionary-seeded cross-block LZ77 path now owns reusable head and
  predecessor arrays instead of allocating and clearing fresh buffers for every
  block. Sixteen interleaved ReleaseFast CPU-8 pairs at 200 streams preserve
  the 4,113-byte cross-block wire and improve median encode time by 1.86x with
  16/16 wins. The reusable combined-history hash positions now use bounded
  32-bit indexes rather than machine-width integers: another sixteen-pair
  CPU-8 run preserves the wire, cuts retained capacity from about 550 KiB to
  310 KiB, and improves median cross-block encode time by 1.23x with 15/16 wins.
  Dictionary-seeded hash heads now use a 4 KiB initialized bitmap instead of
  clearing all 32K buckets on every block. Twenty interleaved CPU-8 pairs retain
  the same 4,113-byte wire and improve cross-block median time by another 9.3%
  with 14/20 wins; a repeated-call oracle changes both dictionary and input to
  prove stale head entries cannot leak between plans.
  Added a focused incremental planned-encoder benchmark/gate comparing warmed
  codec-owned state with rebuilding the one-shot fast encoder. On fixed CPU 8
  at 200 iterations both paths emit 120-byte streams for the 4,992-byte
  payload, while retained state is about 25 KiB and improves elapsed time by
  1.35x. The gate requires at least 1.10x and independently decodes both wires.
  The copy loop now also keeps a local destination cursor while draining each
  output span, removing the remaining per-byte history-write remainder without
  changing literal, stored, or dictionary emission. Twenty alternating
  ReleaseFast CPU-8 pairs at 500 decodes improve the focused 64 KiB overlap
  median by another 5.6%, with 18/20 wins and identical checksums.
  Copy-span accounting now stays local until the current caller output slice is
  full or the copy completes: output/total/pending counts and the two-byte
  literal context are committed once per span rather than once per byte. Twenty
  alternating ReleaseFast CPU-8 pairs at 500 decodes improve the same focused
  benchmark by a further `1.43x` median, with 20/20 wins and identical
  checksums.
  Copy spans of at least 16 bytes now seed one distance period from the history
  ring, expand overlap by doubling in caller output, and commit the finished
  span back to history in at most two contiguous copies. Smaller spans and
  spans larger than the caller's history retain the scalar path. Focused tests
  cover overlap, non-overlap, source wrap, destination wrap, and repeated
  backpressure. Twenty alternating ReleaseFast CPU-8 pairs at 500 decodes show
  a further 2.7% median improvement with 15/20 wins and identical checksums.
  Output spans longer than the caller history now reuse that same bulk kernel
  in history-sized segments while temporarily advancing the logical output
  position between segments. A single-call 64 KiB copy over a 32 KiB history
  is pinned by tests. A fresh twenty-pair ReleaseFast CPU-8 run at 500 decodes
  improves the focused median by another 19.1% (paired median `1.18x`, 19/20
  wins), again with identical output checksums.
  Long copy spans now expand the complete caller-output recurrence first and
  write only the newest history-sized suffix back to the ring, replacing the
  repeated full-ring round trips from the initial long-span implementation. A
  twenty-pair ReleaseFast CPU-8 run at 500 decodes records a further 3.4%
  median improvement (paired median `1.029x`, 14/20 wins) with identical
  checksums.
  Added a dedicated progressive Brotli command/distance benchmark covering
  structured q4, alternating q5, and a deterministic distance-heavy q8 stream,
  with schema, throughput, and workload-shape gates. Incremental rollback now
  snapshots only the mutable literal, command, or distance block-switch state
  for the active operation instead of copying the complete roughly 290 KiB
  compressed header before every symbol attempt. On structured q4, sixteen
  alternating ReleaseFast CPU-8 pairs at 500 decodes improve the median by
  `22.6x`, with 16/16 wins and identical checksums; the gain removes accidental
  state-copy overhead rather than changing Huffman semantics.
  Rollback checkpoints are now narrowed again to the three mutable block-switch
  scalars (`current_type`, `previous_type`, and `remaining`), leaving the type
  and length prefix trees in place. Sixteen alternating ReleaseFast CPU-8 pairs
  keep structured/alternating controls neutral and improve the deterministic
  distance-heavy q8 median by about 6.6% (paired median `1.07x`, 15/16 wins),
  with matching checksums.
  Added `zstdTrainStandardDictionaryAlloc`, the first dependency-free corpus-
  trained literal-entropy stage for RFC 8878 full dictionaries. It uses the
  existing
  deterministic history trainer, builds a complete 256-symbol literal Huffman
  model from raw sample-byte frequencies with a non-zero prior, and combines
  it initially with the validated baseline OF/ML/LL FSE suffix and repcodes
  `1/4/8`. A
  flat-distribution fallback mirrors upstream zstd's slightly perturbed model
  so noisy corpora still produce a legal table. The dictionary entropy summary
  now reports Huffman symbol count and maximum bit width. The libzstd 1.5.5
  differential validates Vort-to-libzstd and libzstd-to-Vort operation with the
  trained dictionary; on its deterministic skewed-literal control, libzstd
  level 1 output fell from 1,019 baseline bytes to 508 trained bytes. This was
  intentionally not full COVER/FastCover; at this stage sequence-table and
  repcode training were left to follow-up work.
  Standard full-dictionary training now derives OF/ML/LL normalized-count FSE
  tables from dictionary-aware greedy LZ77 parses of every sample. Each symbol
  begins with a one-count prior so the first Repeat_Mode block can represent
  arbitrary legal codes, while observed literal lengths, match lengths, and
  repeat/absolute offset codes reshape the distribution. Training reuses the
  existing dictionary-aware scratch and the same sequence-code mapping used by
  the native encoder. Entropy summaries now expose the separate serialized
  Huffman and sequence-table lengths; unit tests prove distinct match corpora
  produce distinct sequence entropy. The libzstd 1.5.5 control remains fully
  bidirectional and improves from 1,019 baseline bytes to 502 bytes, with a
  94-byte trained sequence entropy section. This stage left repcode discovery
  and a stronger COVER/FastCover-class history selector open.
  Expanded the full-dictionary gate from one skewed-text control to three
  independently held-out corpus families, always comparing the trained tables
  with baseline tables wrapped around the exact same selected history. On
  libzstd 1.5.5 level 1, text improves `1019 -> 502` bytes, structured JSON
  improves `100 -> 72`, and skewed binary improves `942 -> 579`; aggregate
  size improves `2061 -> 1153`. The gate requires an aggregate win and no
  per-family regression while running both Vort-to-libzstd and
  libzstd-to-Vort decoding for every trained dictionary.
  Added validation-guided history selection as an explicit opt-in API,
  `zstdTrainValidatedStandardDictionaryAlloc`. The shared dictionary trainer
  evaluates four bounded phrase-length/candidate-cap configurations against
  caller-provided held-out samples, maximizing covered bytes and then
  minimizing match operations; strict ties preserve the original deterministic
  candidate. The selected history is then paired with entropy tables trained
  from the complete training corpus. A focused selector corpus changes the
  chosen 64-byte history, improves libzstd 1.5.5 level-1 output from 95 to 78
  bytes, and round-trips through Vort. This adds an overfitting guard and a
  useful step toward COVER/FastCover-quality selection without claiming parity.
  An attempted upstream-style residual-literal-only Huffman histogram was also
  rejected by the three-family gate: text regressed `502 -> 517`, structured
  `72 -> 80`, and binary stayed at 579 bytes, so raw-byte Huffman statistics
  remain the measured winner. Upstream zstd's dormant repcode ranking is
  disabled behind `#if 0`; Vort therefore left `1/4/8` unchanged in that slice
  pending direct encoder measurement, which the later strict-winner stage below
  now provides.
  Added `run-zstd-dictionary-trainer-compare`, a same-corpus held-out comparison
  against the installed `zstd --train`. It generates deterministic text, JSON,
  and binary sample families, gives Vort 32 training plus 4 selector samples,
  reserves 4 independent payloads, and checks levels 1/3/9. Both dictionaries
  are decoded by Vort, while Vort output is also decoded by libzstd. Current
  aggregate compressed sizes (`Vort/zstd`) are text `364/344`, `346/293`,
  `311/273`; JSON `224/196`, `226/184`, `208/185`; and binary `796/795`,
  `816/796`, `803/810`. This exposes a roughly 0–23% remaining per-row quality
  gap instead of hiding it behind baseline-only wins. The gate caps any row at
  1.50x and each corpus's mean ratio at 1.20x until selection improves further.
  Replaced the deterministic phrase trainer's linear retained-phrase lookup
  and full worst-candidate scan with a content hash map plus an index-stable
  min-heap. A linear path remains below 128 retained phrases to avoid hash-table
  overhead on small jobs, and heap ordering includes the phrase index to keep
  the previous first-equal tie behavior byte-exact. The new
  `run-dictionary-train-bench-gate` covers 24×320-byte text, JSON, and binary
  corpora with 1,024 retained candidates. Against the pre-change implementation
  on fixed CPU 8, the representative runs improved from roughly 0.47/0.40/0.037
  MB/s to 2.79–2.91/2.51–2.71/0.398–0.404 MB/s while preserving identical
  dictionary checksums. The ReleaseFast gate requires at least 0.30 MB/s on
  every row, including the adversarial high-uniqueness binary workload.
  Validation-guided history selection now also considers a reverse-segment
  layout that places the highest-ranked selected phrase nearest the end of the
  Zstd history, where first-block offsets are cheaper. Coverage and match count
  remain the primary selectors; estimated offset bit width breaks exact ties,
  and the original ranked layout remains first on complete ties. The same
  trainer-parity corpus keeps text unchanged, improves JSON level 1/3/9 from
  `224/226/208` to `223/216/198` bytes, and changes binary to
  `800/810/803` versus zstd's `795/796/810`; all rows remain inside the parity
  gate and the aggregate JSON gap narrows without weakening the existing
  full-dictionary controls.
  The validated selector now evaluates a bounded history-size ladder at 100%,
  75%, 62.5%, and 50% of the caller's target. Its codec-independent estimate
  charges both stored dictionary bytes and unmatched literals, then adds match
  and offset-width costs. For the 352-byte trainer-parity target this selects
  264 bytes for text and 176 bytes for JSON/binary. Held-out output becomes
  text `354/352/311`, JSON `205/213/199`, and binary `792/814/796` at levels
  1/3/9 respectively, versus the preceding `364/346/311`, `223/216/198`, and
  `800/810/803`. Aggregate size improves from 4,071 to 4,036 bytes; JSON level
  9 and binary level 3 regress by only 1 and 4 bytes and remain guarded by the
  existing per-corpus parity ceiling.
  Added a cross-sample phrase-ranking candidate that counts how many distinct
  training samples contain each retained phrase before considering total
  frequency, length, and lexical ties. The legacy total-frequency ordering is
  still evaluated first and remains the public non-validated trainer's exact
  output. On the held-out parity corpus, this changes the selected text history
  back to the full 352-byte budget and improves levels 1/3/9 from
  `354/352/311` to `333/301/271`; it now beats zstd at levels 1 and 9 and is
  within 2.8% at level 3 (`301/293`). JSON and binary remain unchanged. The
  gate now pins text to no worse than parity at levels 1/9 and within 5% at
  level 3.
  Added a raw corpus-tail history candidate so the validated selector can keep
  naturally adjacent record bytes instead of always concatenating ranked
  phrases. The same held-out comparison now selects 176-byte histories for
  text and JSON: text reaches `334/290/265` against zstd `344/293/273`, while
  JSON reaches `201/187/187` against `196/184/185` at levels 1/3/9. Binary
  remains `792/814/796` against `795/796/810`. Across all nine rows Vort now
  totals 3,866 bytes versus zstd's 3,876, closing the aggregate trainer-quality
  gap on this deterministic corpus without claiming general COVER/FastCover
  parity. The gate requires aggregate parity, text's existing strict bounds,
  and no JSON row worse than 1.03x. The focused selector control also improves
  from 78 to 76 bytes.
  After validation chooses history parameters, the standard-dictionary trainer
  now uses both the training and selector partitions to estimate final Huffman
  and OF/ML/LL entropy tables; held-out payloads remain untouched. This matches
  the reference trainer's 36-sample entropy corpus rather than discarding four
  representative samples after selection. The baseline-control gate improves
  text `502 -> 486`, structured `72 -> 71`, binary `579 -> 560`, and the focused
  selector `76 -> 70` bytes. On the four-family parity suite, Vort totals
  `9304/9352` bytes against zstd and wins all source-code rows
  (`1842/1808/1788` versus `1857/1819/1800`); text level 3 is within two bytes
  (`291/293`), while binary level 3 remains the largest open row (`814/796`).
  Extended trainer parity to a deterministic 40-chunk held-out corpus sampled
  across `src/zstd.zig`, `src/dictionary.zig`, `src/root.zig`, and the roadmap.
  At levels 1/3/9 Vort records `1883/1841/1826` bytes versus zstd's
  `1885/1870/1847`, winning all three rows. Together with the three synthetic
  families, the suite totals `9416/9478` bytes, so the expanded gate requires
  aggregate parity while retaining the stricter per-family bounds. A
  320–416-byte target scan did not produce a universal replacement; the public
  352-byte target remains and validation chooses the best bounded size/layout
  for each corpus.
  Sequence entropy training now merges dictionary-aware greedy and lazy LZ77
  parses before normalizing OF/ML/LL counts, covering the different match
  decisions used by speed- and ratio-oriented compressors. The baseline-control
  sequence header shrinks from 86 to 76 bytes; structured JSON improves
  `201/187/187 -> 199/185/184`, binary level 1 improves `791 -> 790`, and
  the retained source snapshot also improves. The synthetic nine-row subtotal
  is `3862/3876`, about 0.36% smaller than zstd overall. JSON level 3 is within
  one byte and level 9 wins; binary level 3 (`814/796`) remains the clearest
  unresolved row. The source files are sampled dynamically, so their exact
  sizes remain reported by the gate rather than pinned in this roadmap.
  Extended the bounded history-size ladder with a 25%-of-budget candidate. A
  352-byte parity run selects 88-byte histories for text, JSON, and binary,
  reaching
  text `318/283/270` and JSON `192/184/184` at levels 1/3/9, versus zstd's
  `344/293/273` and `196/184/185`. Binary remained close at `797/802/800`
  versus `795/796/810`. Vort therefore wins or ties every synthetic row,
  including the former binary level-3 gap. The smaller candidate is evaluated
  automatically by the same held-out cost model rather than requiring callers
  to guess it; the gate now requires binary parity at every level.
  Validation-guided phrase training now collects each parameter set once, then
  reuses that bounded phrase array across total-frequency/cross-sample rankings
  and ranked/reverse layouts. Previously all four combinations rescanned the
  complete training corpus. A retained reference selector proves byte-identical
  output across both small and indexed candidate sets. The dictionary training
  benchmark now covers basic and validation-guided text, JSON, and binary rows;
  it also fixes the old JSON fixture's out-of-bounds `% 67` indexing by using
  the real 59-byte pattern length and pins all six legal-input checksums. Nine
  alternating same-source ReleaseFast A/B pairs against the prior selector show
  median validated throughput improving from `0.235/0.237/0.034` MB/s to
  `0.814/0.830/0.109` MB/s (`3.47x/3.51x/3.19x`) for text/JSON/binary with
  identical dictionary checksums.
  Validation-guided training now also shares each collected phrase configuration
  across multiple requested target sizes through `trainValidatedTargetsAlloc`.
  The standard Zstd trainer uses that batch API for its 100/75/62.5/50/25%
  history ladder instead of repeating the complete phrase scan five times. A
  retained separate-call oracle covers zero, duplicate, small-linear, and
  512-candidate indexed targets, while the Zstd-level oracle compares complete
  dictionary bytes including entropy tables and repcodes. The expanded 15-row
  training gate pins basic, single-target, five separate targets, five shared
  targets, and complete Zstd training checksums. Twelve alternating ReleaseFast
  A/B pairs against `38c474df` improve the complete Zstd validated trainer from
  `154.8` ms to `49.1` ms for three runs (`3.16x`, 12/12 wins) with identical
  checksums. Two reuse-aware size experiments were deliberately rejected: a
  multiplied codec-independent estimate selected longer text/binary histories
  that regressed libzstd held-out levels, while selecting by Vort's actual frame
  bytes could not distinguish the retained small payloads and regressed libzstd
  source rows. Neither experimental API remains in the public surface.
  Dictionary match summaries and validation costs now stream over the greedy
  match walk instead of materializing and immediately freeing a match array for
  every candidate/sample pair. `summarizeMatches` and `validationScore` expose
  the allocation-free forms; the old `*Alloc` names remain compatible wrappers
  and succeed with `failing_allocator`. A materialized-match oracle covers
  minimum lengths 1/3/4/8/16 plus overlong limits and pins match count, covered
  bytes, longest match, and distance bits. On the complete fixed text Zstd
  trainer workload, successful allocation calls fall from `1341` to `489`
  (`-63.5%`), resize/remap events from `295` to `35` (`-88.1%`), and cumulative
  requested bytes from `7,967,477` to `7,706,621`, with unchanged peak live
  memory and checksum. Sixteen alternating ReleaseFast timing pairs were noisy
  but neutral-positive (`1.011x`, 9/16 wins), so this is retained as an allocator
  pressure improvement rather than a throughput claim. The 15-row training gate
  now requires balanced allocation bytes/counts on every row and caps complete
  Zstd validation at 501 allocations, 60 resize events, and 8 MiB requested.
  Validation candidate scoring now builds a reusable 256-bucket first-byte
  dictionary index and shares its offset scratch across all held-out samples.
  Bucket entries retain ascending dictionary offsets and only strictly longer
  matches replace the current winner, preserving the linear scanner's earliest
  equal-length tie. Per-position/indexed-summary differential tests cover
  minimum lengths 1/2/3/4/8/16/64 and overlong inputs plus an explicit repeated
  phrase tie. Twelve alternating ReleaseFast A/B pairs against `34644bdd` show
  five-target text/JSON/binary training improving by `1.35x/1.11x/1.20x` and
  complete Zstd validation by `1.28x/1.09x/1.19x`, with 12/12 wins on every row
  and identical checksums. The reusable index adds one allocation and about
  6.1 KiB cumulative scratch to these 512-byte-target workloads; the allocation
  gate permits that single bounded scratch while retaining the preceding
  balance, resize, and 8 MiB limits.
  Expanded Brotli literal block-type storage from 32 to a measured 64-entry
  tier. The first 1.5 MiB of local Graphviz `tests/2475_1.dot` makes libbrotli
  1.1 quality 11 emit 37 literal block types (the 4 MiB prefix reaches 51),
  which the previous decoder rejected as `UnsupportedBrotliFeature`; the
  upstream differential now decodes that real frame through 17-byte input and
  31-byte output chunks when the optional checkout is present, growing the
  local matrix to 100 cases. A dependency-free 33-type hand-built stream pins
  summary, one-shot, and 1-byte-input/3-byte-output progressive decode, while
  64/65 truncated headers originally pinned the measured tier boundary. The
  public progressive decoder grew from 1,397,856 to 1,400,128 bytes (`+2,272`,
  about 0.16%); an initial full 256-entry experiment was rejected because its
  ordinary fixed-CPU evidence regressed. Twenty
  alternating CPU-8 comparisons for the retained 64 tier show structured q4
  and text q11 around `0.986x` paired throughput and clustered q8 at `1.002x`,
  all with identical checksums. This was retained as an explicit small
  compatibility cost; the later maximum-range work below supersedes the 64/65
  limit without changing the independently bounded literal-tree count. The
  self-referential 32 KiB `src/br.zig` ratio fixture moved from 5,526 to 5,814
  bytes as this test code changed; the preceding HEAD and the widened decoder
  both produced 5,814 bytes with checksum 740,269 from the same input. The
  absolute byte assertion was therefore retired in favor of the stable relative
  gates: ratio mode must beat balanced mode by at least 100 bytes and remain
  within 1.02x of libbrotli quality 8.
  Fixed a Brotli byte-progressive copy-decoder livelock exposed by the complete
  test suite's static-dictionary `information` case. Its valid nine-byte stream
  ends the compressed header in a partial retained byte; the decoder consumed
  all input but only offered whole bytes to the bounded header parser, then
  returned zero-progress `need_input` forever. `BitReader.initBitLength` now
  carries the exact logical bit count, allowing header parsing through that
  partial byte without accepting synthetic high padding. The fixed nine-byte
  wire is pinned independently of encoder changes, and every copy-decoder split
  helper now rejects exhausted-input/output no-progress responses. The formerly
  hanging Debug run completes all 419 Brotli tests; the libbrotli 100-case,
  840-run progressive differential and all Brotli benchmark/profile gates
  remain green.
  Extended Zstd compatibility validation through the runtime libzstd API. The
  matrix now reaches level 22, all nine compression strategies, content-size
  and checksum combinations, window logs 10/21, long-distance matching,
  unknown-size streaming frames with explicit flushes, four upstream golden
  streams, and three upstream malformed golden streams. Explicit validated
  sequences pin one-, two-, and three-byte sequence counts through the practical
  128 KiB block maximum of 43,690 entries, plus varied literal/match/offset
  state transitions. The local run covers 273 cases, up to 2,048 blocks per
  frame and 25 observed LL/OF/ML mode combinations. Runtime-trained standard
  dictionaries at 256/1,024/4,096 bytes are decoded at levels 1/9/19 for both
  2.3 KiB and 504 KiB payloads. New dictionary-aware sequence inspectors seed
  Huffman/FSE tables and repcodes from the standard dictionary before replaying
  preceding blocks; a fixed libzstd 1.5.5 all-Repeat fixture pins the public
  single-dictionary and dictionary-set APIs plus missing, wrong, and internally
  inconsistent dictionary errors. Finally, sequence literal-size planning now
  uses the same direct-vs-FSE Huffman weight-tree choice as emission. This
  restores exact estimator/wire agreement for mixed and all-FSE table plans and
  prevents match planning from rejecting candidates based on overstated literal
  tree cost.
  Extended the same Zstd compatibility work with upstream `decodecorpus`
  ingestion. Six deterministic campaigns now cover 5,400 byte-exact frames:
  200 and 1,000 dictionary-free frames at seeds 17 and 919, plus 200, 1,000,
  1,000, and 2,000 dictionary-backed frames at seeds 2,027, 4,242, 31,337,
  and 65,521 with 64 KiB, 1 MiB, 64 KiB, and 256 KiB dictionaries. Their
  cumulative sequence-mode mask is `0xffffffffffffffff`, exercising all 64
  possible LL/OF/ML table-mode tuples. Seed 17's first frame exposed a valid
  zero-length RLE block that the native allocator, caller-buffer, and
  size-preflight paths had rejected; all three now consume its mandatory
  one-byte payload while producing zero bytes. The optional
  `run-zstd-decodecorpus-gate` now regenerates this complete fixed-seed suite
  from a local upstream checkout, validates the cumulative 64/64 mask, and
  cleans each corpus automatically; a self-contained fake-tool smoke keeps the
  orchestration and failure/cleanup behavior covered in ordinary CI. The same
  suite now re-decodes every frame through the incremental API with a
  128 KiB-plus-header input-retention limit. All 5,400 pass and 714 large frames
  enter the new block-streaming state, which releases raw input progressively,
  retains one byte for RLE, and buffers at most one compressed block while
  preserving cross-block entropy/repeat/history state.
  Sequence-free compressed blocks now keep their parsed literal section and
  Huffman cursor across calls, streaming raw/RLE/Huffman literals into tiny
  caller buffers with no decoded-block scratch. The fixed upstream campaigns
  exercise this new path on 132 blocks while retaining the 5,400/5,400 and
  64/64 compatibility results.
  Fixed an incremental DEFLATE wrapper boundary exposed by the full root suite:
  when the final match filled caller output exactly, the raw decoder remained in
  `match_copy` and zlib/gzip returned `need_output` before consuming an already
  buffered EOB and wrapper footer. Raw match completion is now normalized before
  checking output space, and both wrappers perform a zero-input reservoir drain
  before supplying more bytes. One-call exact-output tests now cover raw DEFLATE,
  zlib, gzip, preset dictionaries, dictionary sets, empty payloads, truncated
  footers, and concatenated dictionary-backed streams.
  Removed the remaining whole-payload requirement for incremental Zstd
  skippable frames. The decoder now retains only the eight-byte magic/length
  header, then discards or captures metadata directly from caller input while
  preserving atomic event totals and exact truncation diagnostics. A 4 KiB
  skippable payload passes under a 16-byte compressed-buffer cap and continues
  into a following data frame; an eight-byte cap is sufficient, while seven
  bytes still fails explicitly. Debug and ReleaseFast Zstd tests, the 5,400-frame
  upstream decodecorpus gate, the 273-case libzstd 1.5.5 matrix, public frame and
  dictionary probes, encode/decode benchmark gates, and full repository
  test/check validation remain green.
  Replaced the incremental Zstd block-stream path's decoded-block fallback for
  sequence-bearing compressed blocks with a persistent execution cursor. FSE
  states, reverse bit position, repeated offsets, Huffman literals, and partial
  literal/match runs now survive arbitrary caller-output boundaries; matches
  read from the bounded rolling history and bytes emitted earlier in the same
  call. One-byte-output tests cover Repeat_Mode across blocks, all three tables
  in compressed FSE mode, and preset-dictionary matches. The upstream 5,400-frame
  gate executes 76,578 sequence-bearing blocks on this path and now rejects any
  non-zero decoded-scratch length or capacity during block streaming. Complete
  frames prevalidated for direct output now switch in place to the same cursor
  when a compressed block exceeds the current caller-output slice, preserving
  prior history, entropy tables, checksum progress, and frame boundaries. This
  removes the last decoded-block scratch fallback from supported incremental
  Zstd compressed output while retaining the existing full-block fast path.
  With direct-path switches included, the same corpus now exercises this state
  on 2,699 frames and sequence-free cursor output on 197 blocks.
  LZ4 incremental skippable frames now use the same header-bounded design as
  Zstd: only the eight-byte magic/length header is retained, while arbitrary-size
  metadata is discarded or copied into caller storage as input arrives. Event
  totals remain atomic until payload completion; truncation stays in the public
  `frame` phase; eight bytes is sufficient and seven reports
  `OutputLimitExceeded`. A 4 KiB metadata fixture followed by a normal data
  frame, plus public liblz4 probe coverage, pins the behavior.
  LZ4 incremental data frames now switch to block streaming when a complete
  frame exceeds `max_compressed_buffer_len`. Raw blocks drain directly; linked,
  independent, and dictionary-backed compressed blocks retain at most one
  encoded block and one decoded-block scratch while carrying a bounded 64 KiB
  history and content checksum across blocks. For checksum-bearing compressed
  blocks, the decoder first decodes the block, releases its encoded payload,
  reads and validates the four-byte block checksum, and only then drains decoded
  bytes to the caller. A regression pins a cap exactly equal to compressed
  payload length and verifies corrupt checksums produce zero caller output.
  Expanded Brotli literal block-type storage from the measured 64-entry tier to
  the complete RFC 7932 range of 256. The additional state is limited to literal
  context modes/map entries and the small block-switch tree; the independently
  bounded 256 literal Huffman-tree slots are unchanged. A handcrafted stream
  declares all 256 types, advances through type 255, selects its distinct
  literal tree, and round-trips through summary, allocating, and one-byte-input /
  three-byte-output decode. The upstream differential also sends this exact wire
  through system libbrotli and all 56 progressive chunk combinations, preventing
  a self-generated/self-decoded fixture from serving as the only evidence. The
  256-count truncated header remains `TruncatedFrame`, and the test writer rejects
  the unrepresentable 257 boundary.
  Completed the matching 256-entry RFC command block-type count range without storing
  256 expanded 704-symbol Huffman tables. The common first 32 trees retain their
  direct representation; the remaining 224 store two 4-bit code lengths per
  byte and rebuild only the active overflow tree when block switching reaches
  it. This keeps `BrotliIncrementalCopyStreamDecoder` at 1,499,168 bytes, below
  the existing 1.5 MiB budget instead of adding roughly 1 MiB. A maximum-width
  fixture advances through command type 255 and round-trips through summary,
  one-shot, and one-byte-input / three-byte-output decoding; system libbrotli
  independently accepts the wire, and the upstream matrix exercises it across
  all 56 chunk combinations. A focused complex-tree pack/expand oracle verifies
  canonical entries, while the common-tree ReleaseFast gate protects the hot
  path. The progressive decoder's separate 16 KiB compressed-header cap remains
  explicit: pathological maximum-count complex-tree headers can exceed it even
  though ordinary and maximum-count simple-tree streams are supported; removing
  that cap requires a resumable header parser rather than another large fixed
  buffer.
  Generalized the packed command-tree representation to literal and distance
  Huffman groups. Their first 64 trees remain expanded for measured common
  streams; higher indexes retain packed 4-bit canonical lengths and share one
  lazily expanded active-tree cache per family. This reduces
  `BrotliIncrementalCopyStreamDecoder` from 1,499,168 to 652,288 bytes
  (`-846,880`, about `-56.5%`) while preserving the 16 KiB compressed-header
  bound. Generic single/complex pack-expand tests cover all 256-, 704-, and
  520-symbol alphabets. The upstream differential's real Godot 247-literal-tree
  frame and repository-owned 68-distance-tree frame exercise both cold paths;
  all 952 progressive chunk combinations and the common-tree performance/header
  gates remain green.
  Added caller-owned extended compressed-header scratch to
  `BrotliIncrementalCopyStreamDecoder.Options`. The default remains the embedded
  16 KiB buffer and therefore preserves the 652,288-byte decoder state; a
  larger caller slice is selected only when supplied and survives `reset()`. A
  deterministic valid fixture contains 256 non-trivial 704-symbol command trees
  and a 17,261-byte stream/header: the default decoder returns
  `UnsupportedBrotliFeature` at exactly 16 KiB retained input, while an external
  scratch buffer decodes it incrementally. Python/system libbrotli independently
  accepts the same stream, and the upstream differential feeds it in 257-byte
  chunks with one-byte output. Header ingestion batches up to 4 KiB per parse
  attempt and returns any complete over-read bytes to the current input cursor,
  avoiding excessive reparsing for ordinary chunk sizes without changing
  metadata/stored/next-meta-block boundaries. Because parsing still restarts from
  the retained prefix, adversarial one-byte delivery of very large headers is
  intentionally left to the future resumable header parser.
  Marked the checked compressed-FSE state-table failure edge as unlikely while
  preserving the exact `CorruptFrame` boundary. The initial state is bounded by
  the validated table log and every later state comes from a validated entry, so
  valid sequence-heavy blocks remain on the fallthrough lookup path without
  weakening hostile-input handling; a focused unit test pins both state zero and
  `state == len`. Sixteen alternating fixed-CPU-8 profile pairs at 1,500 decodes
  improve the 5,161-sequence `huffman80k` median by 1.76% (16/16 wins), with
  `large_json` slightly positive and the other rows within about 0.3% at the
  median. Twelve longer pairs at 3,000 target decodes confirm a 1.44% median
  improvement (12/12 wins). An independent eight-pair 13-row caller-owned
  libzstd comparison measures `huffman80k` at +2.42%, `large_json` at +1.47%,
  and `binary_mixed` at +0.12% medians. The ReleaseFast profile/reference gates,
  273-case libzstd 1.5.5 probe, and six-campaign 5,400-frame upstream
  `decodecorpus` gate remain green, including all 64 LL/OF/ML mode tuples.
  Several broader candidates were measured and fully reverted: a separate
  all-FSE/raw-literal loop improved its target by about 11--13% but repeatedly
  regressed the adjacent FSE/FSE/RLE row by roughly 2--4%; handwritten repcode
  rotation, removing the duplicate narrow-reader bounds check, sparse empty
  frame-state initialization, direct final-symbol FSE table construction, and
  moving the complete sequence dispatcher out of line each regressed at least
  one tracked FSE-heavy shape. Future work should avoid repeating these changes
  without first isolating the observed code-layout sensitivity.
  Follow-up fixed-CPU experiments narrowed that warning further. Zeroing the
  complete 13 KiB empty sequence-frame state instead of copying its static
  template kept equivalent initialized storage but still reduced `huffman80k`
  by about 12.0%; shrinking the FSE builder's symbol-next scratch from 256 to
  the format-required 64 entries reduced it by about 6.2%. A 32-bit reservoir
  dedicated to <=9-bit FSE state transitions lost about 11.4%, and hand-copying
  non-overlapping matches up to 16 bytes lost about 11.4% on `huffman80k`, 6.0%
  on `large_json`, and 5.1% on `binary_mixed`. Extending the all-FSE/raw loop
  through the existing FSE/FSE/RLE helper still improved its target by about
  9.9%, but regressed `large_json` by about 2.0% and `binary_mixed` by 1.6%; a
  dictionary-free match-copy shortcut showed a positive isolated profile but
  regressed `huffman80k` by about 11% in the independent reference binary.
  Cache-line aligning the public decode entry, marking the generic non-terminal
  sequence edge likely, and hinting generic reader/offset-mode/offset-zero paths
  were likewise neutral or negative. All candidates were fully reverted. The
  retained cold FSE state-failure hint remains the only change from this pass.
  Added the first decoded-scratch-free LZ4 compressed-block stream tier. After
  the existing full compressed-block preflight, independent dictionary-free
  blocks up to 64 KiB without a block checksum retain a resumable token/literal/
  match cursor and write through arbitrary caller output slices. The encoded
  block remains bounded and retained until the cursor completes; emitted bytes
  are kept as the block's bounded match history, while content checksums update
  incrementally. Public decoded-buffer metrics and a streamed-block counter make
  the zero-scratch path observable. Focused tests cover every output chunk size
  for a mixed literal/match block, long literal and match extensions, one-byte
  frame output, cursor reset across two independent compressed blocks, exact
  compressed-input caps, content checksum completion, and malformed match
  rejection before any caller output. The public native probe adds the same
  one-byte-output path. Checksummed and >64 KiB decoded compressed blocks
  intentionally retain the existing block-atomic
  scratch path until their checksum and rolling-history state can be separated
  without weakening checksum-before-output behavior.
  Registered the new `compressed-block-cursor` probe capability in the public
  probe dashboard, validation smoke, JSON schema, and documentation.
  Extended that cursor to consume bounded prefix history, covering linked blocks
  and preset-dictionary blocks under arbitrary caller backpressure. Frame tests
  force a linked second block to reference a 64 KiB raw prefix and a separate
  dictionary frame to reference its preset bytes; both remain at zero decoded
  scratch. The rolling 64 KiB history also removes the decoded-size restriction:
  a 128 KiB compressed block now drains directly. Finally, block-checksummed
  compressed payloads are hashed and verified while retained, then handed to the
  same cursor, preserving checksum-before-output while eliminating decoded
  scratch from that last compressed-block tier.
  Complete frames that initially select direct output now switch in place to the
  block-stream cursor when a compressed block exceeds the caller's current
  output slice, preserving prior output/history and avoiding the old whole-frame
  decoded-scratch fallback.
  Replaced the cursor's byte-at-a-time match replay with bounded prefix copies
  plus doubling copies from the current output span. A nine-pair ReleaseFast A/B
  run against commit `72609544` on a 256 KiB repetitive frame measured median
  throughput-equivalent speedups of 1.081x, 2.387x, and 5.399x for 1-, 127-,
  and 4096-byte caller output slices respectively.
  Added a second cursor that parses no-block-checksum compressed payloads across
  arbitrary input boundaries. Such blocks no longer require the compressed
  buffer cap to hold their complete payload; tests exercise one-byte input and
  output, split length extensions, truncated payloads, invalid offsets, exact
  output-size diagnostics, linked rolling history, and preset dictionaries.
  Checksummed compressed blocks intentionally remain input-atomic so their
  payload can be verified before any decoded bytes are exposed.
  Reworked the large sequence-free Zstd Huffman path after comparing its hot
  loop with the local upstream `~/Work/zstd` decoder. Four independent literal
  streams now advance together, each decoding five symbols from one 64-bit
  reservoir before reloading; checked per-stream tail decoding still validates
  every reverse-bitstream end marker. A width-1...11/alignment oracle pins the
  five-prefix gather, and the large four-stream fixture corrupts each of the
  four terminal markers independently. Twelve alternating fixed-CPU-8 runs at
  5,000 decodes improve the locked 64 KiB high-entropy ASCII median from about
  188.03 MiB/s to 781.84 MiB/s (`4.16x`, 12/12 wins). The same-process libzstd
  1.5.5 row now reaches about 0.66x instead of 0.16x, so its regression floor is
  raised from 0.14x to 0.50x. The 273-case runtime matrix and all six upstream
  `decodecorpus` campaigns remain byte-exact: 5,400 frames, all 64 sequence-mode
  tuples, 2,699 block-stream frames, and 76,578 streamed sequence blocks with
  zero decoded scratch.
  A follow-up that prevalidated the full Huffman lookup table and removed the
  per-symbol `valid` branch improved `ascii64k` by about 3.5%, but an eight-run
  13-row reference sweep regressed `huffman80k` by about 12% and `large_json`
  by about 3% on average. It was reverted; future table-layout work should use
  a separate specialized table representation rather than perturbing the shared
  decoder's code layout.
  A separate X2-style table was then prototyped only inside the four-stream
  path, combining a second symbol when both codes fit one table-width prefix.
  It measured only about 742--752 MiB/s on `ascii64k`, below the retained X1
  path's roughly 780 MiB/s, so the larger table and decode logic were removed.
  Extended the one-block decisive-primary policy to level 9+ structured inputs.
  When distributed alphabet sampling selects the low-alphabet path and the
  complete primary frame is at most 1/32 of the source, the encoder now returns
  it without evaluating the 8 KiB split; a miss retains the primary for normal
  arbitration instead of recomputing it. Twelve alternating fixed-CPU-8 runs
  improve the locked 32 KiB JSON level-9 row from about 2.45 MiB/s to
  12.5--13.1 MiB/s (`5.2x`, 12/12 wins), with the exact 640-byte wire unchanged.
  An eight-run nine-row matrix preserves every size/checksum and keeps control
  rows within noise. Focused tests compare one-shot and reusable output with
  exhaustive primary/4 KiB/8 KiB arbitration across 12 generated structured
  inputs and pin a non-decisive low-alphabet fallback.
  Auditing the same ratio-only shortcut for level 3 found a bounded speed/ratio
  tradeoff. A temporary
  1,024-case, 16-shape audit found 11 adaptive split winners at every 1/32,
  1/48, and 1/64 primary threshold; 1/128 still retained nine winners, while
  1/256 matched no samples. Both plain structured and copied-tail inputs were
  represented. The level-3 speed policy now accepts this tradeoff explicitly:
  the locked JSON remains 640 bytes while twelve fixed-CPU-8 pairs improve
  throughput from about 3.4 MiB/s to 12.6--13.1 MiB/s (`~3.8x`, 12/12 wins).
  A focused test pins one real 333-versus-326-byte counterexample, while the
  12 generated level-9 cases and level 22 continue to require byte-exact
  primary/exhaustive agreement.
  Replacing adaptive greedy blocks with the diagnostic double-fast parser was
  also rejected: across 31,680 generated 2/4 KiB blocks, double-fast was smaller
  30,897 times but larger 537 times (up to 14 bytes), so it cannot preserve the
  existing best-of-family result. Seeding the remaining exact single-match scan
  from greedy matches preserved wire bytes but slowed the locked level-3 JSON
  row by about 10--11%, even after extending only the longest seed match before
  one payload estimate. Both production experiments were removed.
  A two-vector 64-byte unroll of the exact match extension loop was also
  rejected. Although it preserved every tested boundary, the isolated 4 KiB
  JSON single-duplicate stage slowed from about 235 to 347 microseconds per
  block. The existing one-vector 32-byte loop remains preferable with current
  Zig/LLVM code generation.
  A broader attempt to promote the diagnostic double-fast parser into adaptive
  small-block selection was also rejected. Across 31,680 generated 2/4 KiB
  blocks it beat greedy 30,897 times but lost 537 times by up to 14 bytes, so it
  cannot replace that candidate. Nor can it safely skip optimal based on a
  relative lead: at a strict 1/8 lead, optimal still won 384 of 833 triggered
  blocks by up to six bytes; 1/2 and 1/4 thresholds had zero coverage. The
  temporary audit was removed.
  A final narrow FSE-reader experiment removed the second range check after
  `peekSmall`; although the first check makes the subtraction logically safe,
  the altered optimized code layout reduced `huffman80k` throughput by about
  9.7% across 16 fixed-CPU pairs and left `large_json` neutral. It was reverted.
  Expanding the retained four-stream Huffman batch from five to eight symbols
  for trees with maximum code width seven or less was also rejected. A 12-run
  five-row profile gave only about 0.3% average gain on `ascii64k`, while
  `huffman80k` and `large_json` regressed by about 10% and 4%. The five-symbol
  batch remains the stable production point.
  Level 3 now also returns an already-computed primary frame for wide-alphabet,
  single-block inputs instead of evaluating the 4 KiB screen and possible 2 KiB
  deferred split. This is an explicit speed-level tradeoff: a temporary
  1,152-case audit spanning 9--128 KiB, 41--256 symbols, eight seeds, and plain
  plus copied-tail shapes found 22 split winners totaling 175 bytes, with a
  worst individual gain of 22 bytes; 1,130 cases were unchanged. A focused
  test pins that worst observed 6146-versus-6124-byte counterexample and checks
  one-shot/reusable output plus round-trip decode. Twelve alternating
  fixed-CPU-8 binary level-3 pairs improve mean throughput by `4.01x` with
  12/12 wins. An eight-run complete matrix measures `4.11x` on the target,
  preserves every locked size/checksum, and keeps other rows within
  `0.98--1.06x`; the encode gate now prevents the prior level-3 binary latency
  cliff from returning.
  A corresponding level-9 wide-alphabet shortcut was deliberately not applied
  unconditionally. The first 1,152-case audit found 71 adaptive split winners
  totaling 1,412 bytes, with a 67-byte maximum. Requiring the completed primary
  frame to be at most one third of the input isolated the useful strongly
  structured subset: a second 1,008-case audit across 9--128 KiB, seven noise
  ratios, eight seeds, and plain/copied-tail variants found 280 qualifying
  cases and zero split winners. Tests pin the 8,607-byte level-9/22 primary
  winner and a 10,842-versus-10,809-byte below-threshold split fallback. Twelve
  alternating fixed-CPU-8 binary level-9 pairs improve mean throughput by
  `3.30x` with 12/12 wins; an eight-run nine-row matrix measures `3.27x`,
  preserves every size/checksum, and keeps controls within about 1.6%.
  The diagnostic double-fast parser now forms the cheap half of a narrow
  block-level consensus proof. On wide level-1--3 and level-9+ blocks, a candidate at 3:1
  compression or better may return early only when the independent repeat-beam
  parser emits identical complete block bytes. A temporary 1,008-case audit
  found 280 threshold matches, 184 parser agreements, and zero differences
  between those agreements and complete arbitration. The agreement is
  necessary: double-fast alone lost on 16 cases by 242 bytes total and up to 32
  bytes. Tests retain both an 8,600-byte consensus winner and a disagreement
  fallback. Twelve fixed-CPU-8 binary level-9 pairs improve mean throughput by
  `2.74x` with 12/12 wins on top of the frame shortcut; an eight-run nine-row
  matrix confirms `2.76x`, identical wires/checksums, and neutral-to-positive
  controls.
  The consensus proof now compares parser tokens and `PlanStats` before a second
  entropy wire is built. The same 1,008-case audit found token consensus and
  wire consensus on exactly the same 184 cases, with zero disagreement. Twelve
  fixed-CPU-8 pairs improve the locked binary level-9 row by another `1.24x`
  over the committed double-wire implementation (12/12 wins); an eight-run
  nine-row matrix measures `1.27x`, preserves every size/checksum, and keeps
  controls within about 2%. The default encode gate now uses three iterations
  and three rounds; later level extensions keep every optimized binary row
  mutually bounded rather than assuming one remains a stable slow control.
  Extended the same token-consensus proof down to level 3's 64-state budget. A
  separate 1,008-case audit found 168 wide blocks meeting the 3:1 threshold and
  89 double-fast/repeat-beam token agreements; all 89 matched complete level-3
  arbitration byte-for-byte. The permanent consensus and disagreement tests now
  cover both 64- and 96-state paths plus the 63-state disabled boundary. Twelve
  fixed-CPU-8 binary level-3 pairs improve by `2.14x` with 12/12 wins; an
  eight-run complete matrix measures `2.38x`, preserves every size/checksum,
  and keeps controls within about 2%. The next level-1 extension replaces this
  temporary cross-level relationship with a symmetric latency bound.
  Extended the consensus trigger through level 1's 16-state and level 2's
  32-state budgets. Separate passes over the same 1,008-case corpus found the
  same 168 threshold matches and 89 token/statistics agreements at each level;
  all 89 matched the corresponding complete arbitration. Permanent tests cover
  16/32/64/96-state success and disagreement fallbacks plus the disabled
  15-state boundary. Twelve fixed-CPU-8 binary level-1 pairs improve by `1.71x`
  with 12/12 wins; an eight-run complete matrix measures `1.64x`, preserves all
  wires/checksums, and leaves levels 3/9 within 0.5%. The encode gate now keeps
  all three binary levels within 25% latency of one another.
  Removed the consensus helper's temporary encoded-block buffer. Double-fast
  now writes directly into the caller's reusable candidate list; a saved entry
  length transactionally restores prior output on threshold misses, parser
  disagreements, and all injected allocation failures. A counting-allocator
  test compares the retained temporary-buffer reference and pins one fewer
  allocation plus 13,028 fewer requested bytes on the locked 32 KiB binary
  block, with identical output. Twelve fixed-CPU-8 timing pairs averaged only
  `1.04x` with 5/12 wins, so no throughput claim is attached to this change.
  Reused the repeat-beam plan when the consensus probe fails after completing
  both parsers. A compile-time-specialized internal selector takes the existing
  scratch and `PlanStats`, while ordinary calls retain their previous branch-free
  shape. The fixed disagreement input remains 1,393 bytes. Twelve fixed-CPU-8
  pairs at levels 1/3/9 improve fallback throughput by `1.25x`/`1.21x`/`1.13x`,
  with 12/12 wins in every group; the existing disagreement test compares each
  reused result byte-for-byte with complete fresh arbitration. A counting
  allocator additionally pins four fewer allocations and 897,583 fewer
  requested bytes on that fallback.
  Reusing the rejected double-fast wire as an additional fallback candidate was
  also audited and rejected. Across 168 wide 3:1 cases at each 16/32/64/96
  budget, 89 were existing consensus hits; among the remaining 79, double-fast
  was smaller 63 times by 186 bytes total, tied once, and lost 15 times by 241
  bytes total. Strict final arbitration could preserve correctness and gain two
  bytes on a pinned 16 KiB case, but fixed-CPU timing regressed levels 1/3/9 to
  about `0.96x`/`0.91x`/`0.94x` with only 3/12, 1/12, and 0/12 wins. The extra
  serialization was removed; fallback retains only the profitable beam reuse.
  Added a deliberately speed-oriented level-1 shortcut at a stricter `4/15`
  double-fast block ratio. A 784-case audit found 136 applicable wide blocks:
  double-fast was smaller in 51 cases by 144 bytes total, equal in 76, and
  larger in nine by 133 bytes total, for an aggregate 11-byte reduction but a
  worst individual cost of 32 bytes. That 6,619-versus-6,587-byte case is pinned
  across block, one-shot, reusable, and decode APIs; level 2 retains exhaustive
  arbitration. Twelve fixed-CPU-8 binary level-1 pairs improve by `2.20x` with
  12/12 wins. An eight-run nine-row matrix measures `2.22x`, preserves the
  locked 8,607-byte wire/checksum, and keeps controls within about 2%.
  Added a narrower level-3 block shortcut for especially strong wide-alphabet
  matches. A temporary 784-case audit spanning 9--63 KiB, seven noise densities,
  eight seeds, and plain/copied-tail shapes compared direct double-fast output
  with complete 64- and 96-state arbitration. At a 1:16 block ratio, eight cases
  qualified: double-fast was smaller three times by eight bytes total, equal four
  times, and larger once by one byte. Level 3 now accepts that explicit one-byte
  worst-case speed tradeoff; level 2 and level 9+ still require parser consensus.
  The fixed counterexample is pinned at 2,038 versus 2,037 frame bytes across
  one-shot/reusable/decode APIs and allocation-failure rollback. Twelve
  alternating fixed-CPU-8 pairs improve the target level-3 encode by about
  `7.06x` with 12/12 wins; an eight-run 12-row matrix measures `7.10x` and keeps
  every control within about 1%.
  Two follow-up attempts to reduce double-fast token allocations were rejected.
  Retaining its token list in `LevelFrameEncoder` removed five allocator growth
  calls on the locked 32 KiB binary block, but even a branch-specialized hot
  path reached only about `0.982x` median throughput with 3/12 wins. Reserving
  one third of the input directly inside the parser reduced the same cold list
  from five allocations and 127,446 requested bytes to one exact 65,532-byte
  allocation, but the isolated double-fast stage measured about `0.978x` with
  4/12 wins and end-to-end levels 1/3/9 remained noise-level. Both code changes
  were removed; Zig's allocator can grow this list efficiently enough that the
  extra branch/reservation work is not justified.
  A follow-up repeat-beam cleanup that accumulated `PlanStats` during token
  backtracking instead of scanning the completed token list was also rejected.
  It preserved every stage counter and encoded byte, but the isolated 32 KiB
  binary repeat-beam stage measured about `0.991x` median throughput with only
  4/12 fixed-CPU wins. The separate linear statistics pass remains clearer and
  was restored; the remaining beam cost is in forward state expansion and match
  discovery rather than final accounting.
  A single-candidate `?Match` specialization that hoisted repeat-beam match
  bounds and removed the generic output-slice/count interface was rejected more
  strongly: the isolated binary stage fell to about `0.914x` median with 0/12
  wins. The compiler optimizes the current one-element array/count path better.
  Compacting each repeat-beam state by reconstructing its token during
  backtracking was likewise rejected. The representation fell from 16 to 12
  bytes per state and retained exact tokens/statistics, but the added recovery
  branches left the isolated binary stage at about `0.996x` median with 5/12
  wins. The explicit token remains in the state until a layout that improves
  both cache traffic and backtracking cost is demonstrated.
  Replacing the compact repeat-beam index's fourth-byte collision check with a
  full four-byte anchor comparison was also rejected. The index already hashes
  all four bytes, so the wider validation only added work: the isolated binary
  stage measured about `0.985x` median throughput with 3/12 wins, despite exact
  token and encoded-byte parity.
  Restored overlapping primary/adaptive frame evaluation for large level-1--3
  inputs after auditing the multi-block path. The larger adaptive split won all
  80 generated 129/192 KiB wide-alphabet cases at both levels 1 and 3, while the
  deferred smaller split never won. This does not prove that primary can be
  dropped on arbitrary inputs, but it showed that serializing primary after the
  split worker was pure latency on the audited shapes.
  Primary now runs on the coordinator while the larger split runs in the worker,
  preserving the exact candidate set, deferred-small rule, and tie order. A
  permanent 129 KiB oracle checks complete serial arbitration, one-shot/reusable
  byte equality, exact 28,328/28,328/27,758-byte level-1/2/3 frames, and decode;
  an injected initial OOM checks joined-worker cleanup. Twelve alternating
  ReleaseFast pairs pinned to separate performance cores improve level 1 by
  `1.038x` median and level 3 by `1.090x`, with identical output. The new
  same-process `run-zstd-level-schedule-bench-gate` compares parallel production
  against a serial reference for all three speed levels and enforces exact
  checksums plus a conservative `1.01x` speedup floor.
  A separate five-file check over 256 KiB prefixes from the local Silesia corpus
  retained identical outputs and measured geometric-mean speedups of `1.109x`
  at level 1 (4/5 wins) and `1.087x` at level 3 (3/5 wins); worst per-file ratios
  were about `0.975x` and `0.970x`, so the claim remains aggregate rather than
  universal.
  Removed the encoder's fixed 512-sequence rejection for wide Zstd blocks. The
  existing stack path remains byte-identical through 512 sequences; larger
  hash-parser plans use allocator-backed linear scratch bounded by the 128 KiB
  block size and minimum match length, and choose exact combinations of
  RLE/predefined/compressed-FSE LL/OF/ML tables. The preceding predefined-only
  slice retained all 20 measured double-fast/greedy/lazy/optimal candidates
  (2,509--19,038 sequences) on five local Silesia 128 KiB blocks, with selected
  frames of 75,660/12,946/26,689/62,228/11,450 bytes for
  ooffice/nci/mozilla/dickens/xml. Vort and system zstd decoded all five exactly.
  Fixed-CPU level-1 A/B records major size wins (roughly 9%--86%) with mixed
  latency: ooffice and dickens are about 0.77x/0.83x baseline, while nci,
  mozilla, and xml are about 1.89x/13.61x/26.54x because useful primary results
  replace expensive fallback work. Boundary tests cover 513 sequences, the
  32,512 three-byte count tier, small/large planner equivalence, and every
  allocation-failure rollback point. A dedicated runtime-libzstd probe and a
  primary/double-fast stage-gate row keep the 128 KiB path externally visible.
  Scratch-backed compressed-FSE planning lowers that deterministic stage block
  from 39,598 to 33,754 bytes and the selected frame from 39,303 to 35,046 bytes;
  its chosen sequence modes are LL=FSE, OF=FSE, and ML=RLE. Cross-block table
  reuse now carries the selected LL/OF/ML tables and repcode ring transactionally
  across all supported sequence counts, preserves tables across zero-sequence
  blocks, and seeds the same planner from standard dictionaries. Wide blocks use
  scratch-backed backward reachability to evaluate Repeat_Mode without greedy
  dead ends. A 513-sequence two-block regression selects LL=Repeat, OF=RLE, and
  ML=Repeat in block two and exhaustively checks allocation-failure rollback. The
  runtime-libzstd probe adds a 69,882-byte public 256 KiB frame whose two blocks
  each contain 2,044 sequences and whose second block selects ML=Repeat. The retained 129 KiB
  benchmark frame falls from 28,328/28,328/27,758 bytes at levels 1/2/3 to
  27,863/27,863/27,517 bytes; level 9 falls from 27,455 to 27,363 bytes. The
  level-1/3 decisive-wide consensus path now consumes the current frame tables
  and repcodes directly, eliminating its decode/re-encode preparation pass while
  leaving strict ratio-level and fallback arbitration unchanged. A 513-sequence
  oracle pins byte identity and measures 16 fewer allocations plus 237,173 fewer
  cumulative requested bytes. The runtime-libzstd probe also exercises this
  production path with a 15,517-byte two-block frame whose disjoint byte
  alphabets exclude cross-block history matches; both 33 KiB blocks have 526
  sequences and the second selects LL/ML=Repeat plus OF=RLE. Repeat reachability
  storage now scales with the largest actual previous table: Vort's normal
  128-state tables need two `u64` words per sequence instead of the fixed eight,
  while 64/128/256/512-state tests retain exact path selection. Future ratio work should broaden
  the real multi-file corpus and remove the remaining fallback preparation pass.
  Frame assembly now reuses one dynamic sequence scratch across hash candidates
  and fallback rewriting; `NativeFrameEncoder` retains that capacity across
  calls without putting allocator-owned data into the generic incremental state.
  On the two-33-KiB fixture, frame-local reuse removes 13 allocations and 76,482
  cumulatively requested bytes, and the next reusable-encoder call removes 18
  allocations while preserving exact output. OOM recovery and final deallocation
  balance are pinned by the same reusable-encoder test.
  Standard full-dictionary training now evaluates corpus-derived starting
  repcodes without adopting upstream zstd's dormant heuristic blindly. Greedy
  and lazy dictionary-aware parses count only explicit offsets among each
  block's first two sequences with weights 3 and 1, retain `1/4/8` priors, and
  deterministically rank by count then ascending offset. Vort retrains OF/ML/LL
  entropy for that candidate and compares complete forced-compressed frames for
  every sample; only a strict total-byte win of at least 1% replaces the
  baseline, filtering one-byte boundary noise on large corpora. A focused
  701/634-distance sample improves 26 to 25 bytes, while a tie corpus remains
  byte-stable at `1/4/8`. Unit coverage includes ranking, zero/oversized metadata,
  adoption, tie fallback, round-trip, and every allocation-failure point; the
  runtime-libzstd differential loads a custom-repcode dictionary and validates
  both Vort-to-libzstd and libzstd-to-Vort frames.
  Audited the next repcode-search step before adding production complexity: all
  six permutations of the selected `701/634/1` set produce the same 25-byte
  focused frame, so there is no retained evidence that permutation search beats
  the deterministic frequency order. The temporary experiment was removed.
  Expanded the libbrotli upstream multi-meta-block differential beyond
  flush-only input. The reference harness now exposes PROCESS and explicit
  FINISH operations, including FINISH carrying the final input, and rejects
  operations after completion. Eight new q0/q5/q11 schedules cover accumulated
  PROCESS input, empty PROCESS, repeated empty FLUSH, PROCESS-to-METADATA
  transitions, and FINISH with pending input. Each stream passes libbrotli
  decode plus Vort's complete 8-by-7 input/output fragmentation matrix; the
  gate now reports 100 format cases, 26 matrix streams, and 1,401 progressive
  runs, plus two rejected operations-after-FINISH schedules. This audit also
  corrected the stale top-level claim that command block
  types were capped at 32: the existing maximum-type oracle already covers all
  256 RFC values.
  Added a strict direct decoder for the common single-uncompressed-block Brotli
  wire shape. It accepts only canonical window/MLEN fields, zero header padding,
  an exact payload boundary, and the byte-aligned `0x03` final-empty terminator;
  compressed, metadata, multi-block, malformed, truncated, and trailing-data
  streams retain the general decoder. Seven fixed-core ReleaseFast samples put
  the 12-byte `hello brotli` control at a 1,139.7 MiB/s median versus 399.6
  MiB/s for the parent (`2.85x` faster), and roughly `23x` the runtime
  libbrotli call path.
  The reference benchmark now follows the other codec gates by enforcing
  throughput floors only under `-Doptimize=ReleaseFast`; Debug runs continue to
  validate all rows, round trips, dictionary transforms, summaries, and
  allocation relationships. A clean-parent A/B reproduced the Debug text/tiny
  floor failures, confirming they predated this fast path rather than relaxing
  the production regression contract.
  The isolated high-tree Brotli payload path now prepares the existing in-table
  eight-bit lookup for command and distance trees as well as literal trees. It
  preflights every declared auxiliary tree before mutating any table, applies
  only when all command/distance trees are in the inline tiers, and dispatches
  through a compile-time-specialized `noinline` loop; ordinary streams retain
  their prior compact decoder and code layout. An atomic sparse-plus-dense
  regression proves failed preparation leaves earlier command trees unchanged,
  while successful command/distance lookups decode identically. Seven
  alternating fixed-core ReleaseFast pairs improve the 1 MiB `clustered_q8`
  median from about 679.8 to 862.7 MiB/s (`1.269x`, 7/7 wins) with identical
  checksums. The complete 13-row ReleaseFast libbrotli gate and the 100-case /
  1,401-run upstream progressive differential remain green.
  A follow-up profile showed the thin `PrefixCode.decodeTailLookup` call
  boundary itself consuming roughly 10% of clustered decode after command and
  distance lookup landed. Inlining that wrapper remains isolated to the
  high-tree path and lets the existing underlying table primitive optimize into
  each literal/command/distance call site. Nine alternating fixed-core
  ReleaseFast pairs improve the clustered median again from about 861.6 to
  1,059.2 MiB/s (`1.229x`, 9/9 wins), with identical checksums; the strict gate
  floor rises from `0.40x` to `0.50x` libbrotli throughput. The one-pass
  allocator-returning decoder now uses the same large-stream dispatcher, rather
  than falling back to the compact small-stream payload loop after resizing its
  final output.
  A high-tree-only follow-up that fused regular-distance extra-bit parsing into
  the tail-lookup helper was rejected: nine fixed-core pairs measured about
  `0.996x` median throughput with mixed wins. The shared, separately tested
  regular-distance implementation remains preferable.
  Switching only the high-tree payload from `BitReader` to the existing
  reservoir-backed `BufferedBitReader` was also rejected. It preserved the
  complete 100-case / 1,401-run upstream differential, but nine fixed-core
  pairs reached only about `1.008x` median with 7/9 wins, below the threshold
  for carrying reader-state conversion and additional generic instantiations.
  Reading adjacent insert/copy extra fields through one combined bit-reader
  operation was rejected as well. An exhaustive 704-command by eight-alignment
  oracle proved exact values and cursor positions, but nine fixed-core
  end-to-end pairs regressed clustered decode to about `0.973x` median.
  Caching the high-tree payload's caller-owned output cursor in a local scalar
  was also neutral: nine fixed-core pairs measured about `0.999x` median. The
  compiler already keeps the pointed value effectively live, so the explicit
  deferred synchronization was removed.
  A ten-bit command/distance tail lookup was rejected despite fitting the
  current tree storage and passing complete-tree, dense-capacity, truncation,
  and upstream differential checks. Nine fixed-core pairs fell from roughly
  1,104.5 to 1,076.8 MiB/s (`0.975x`, 1/9 wins); the doubled lookup footprint
  costs more cache bandwidth than it saves in long-code fallback.
  Allocating Brotli summaries now inspect only the window and first meta-block
  header before choosing history for large final-compressed streams. When a
  16 KiB-or-larger input declares more than the inline 65,520-byte history but
  no more than 2 MiB of output, the summary allocates its exact bounded history
  before the first payload pass instead of decoding until context is lost and
  then restarting from byte zero. Small, stored, metadata-first, multi-block,
  and larger streams retain the allocation-free-first policy. Allocation
  failure reruns that original path so malformed/limit errors keep precedence,
  while genuine history exhaustion returns OOM. The retained 1 MiB clustered
  q8 case now uses exactly one balanced allocation/deallocation; seven
  fixed-core pairs reduce median `size_ns` from about 336.4 to 217.6 ms for 100
  summaries (`1.55x`). The ReleaseFast reference gate caps clustered summary
  time at three times caller-owned decode, versus roughly 2.4x measured.
  Parameterized the in-table tail lookup and widened only high-tree command and
  distance tables from eight to nine bits. The 290 KiB header remains the same
  size because each lookup still occupies unused canonical-entry storage; all
  auxiliary trees are preflighted before any mutation, while literal trees stay
  at their proven eight-bit width. A 320-symbol complete-tree oracle checks all
  decoded values and bit positions, a truncated nine-bit symbol remains strict,
  and a dense 512-symbol table is rejected. Nine alternating fixed-core
  ReleaseFast pairs improve `clustered_q8` from a 1,046.4 to 1,102.6 MiB/s
  median (`1.054x`, 8/9 wins) with identical checksums. The conservative
  libbrotli ratio floor rises again from `0.50x` to `0.54x`.
  Standard Zstd dictionary entropy training now retains a dedicated lazy-parser
  token list and dictionary hash scratch across samples and blocks. The public
  reusable planner resets a compact head-initialization bitmap between unrelated
  dictionaries, preserves the allocating API's token order and statistics, and
  remains usable after allocation failure. On fixed CPU 0, all three benchmark
  checksums remained identical while allocations fell from 494/494/497 to
  401/401/408 and cumulatively requested bytes fell from about 7.76/7.76/8.02
  million to 1.54/1.53/1.76 million for text/JSON/binary; same-run throughput
  improved by 2.7% to 6.9%. The resource gate is tightened accordingly to 420
  allocations, 45 resize events, and 2 MiB per validated Zstd training case.
  Profiling the resulting trainer exposed two accidental copies/searches in the
  Huffman-weight size estimator rather than dictionary matching itself. Passing
  the roughly 1 KiB FSE compression table by pointer removes compiler-generated
  copies at every state transition, and the finalized per-byte Huffman
  `bit_counts` table now supplies serialized weights directly instead of
  linearly searching the sorted symbol list. Five alternating fixed-CPU-8
  ReleaseFast pairs measured the table-pointer change at 2.62x/2.42x/1.55x and
  the indexed-weight follow-up at another 1.12x/1.16x/1.47x for text/JSON/binary,
  all 5/5 wins with unchanged dictionary checksums and allocation totals.
  Reusing an already-emitted literals-section prefix while rewriting a winning
  sequence candidate's FSE tables was rejected. Five fixed-CPU-8 pairs improved
  text by only 1.5%, JSON by 0.2% (3/5 wins), and binary by 0.3%; this does not
  justify threading borrowed wire slices through the state-rewrite API.
  A 128-symbol compact back-reference package-merge specialization was also
  rejected. Although its exact code lengths matched the existing 256-symbol
  planner for every active count from 65 through 128, nine warmed fixed-CPU-30
  pairs regressed aggregate trainer time by about 0.9% and won only 7/27
  corpus runs: the back-reference loops were already bounded by active count,
  so compacting and remapping added work without shrinking the hot iteration.
  The retained follow-up instead passes the Zstd planner's already sorted
  active-byte list to the generic Huffman builder. Its known-active entry point
  now skips the redundant full-alphabet count scan for 65–256 active symbols
  before entering the existing back-reference package merge; the ≤64 compact
  paths remain unchanged. An exhaustive 2–256 active-count oracle matches the
  scanned builder exactly. Nine warmed alternating fixed-CPU-30 ReleaseFast
  pairs improve text/JSON/binary trainer medians by about 5.3%/4.3%/2.8%, with
  27/27 wins and unchanged dictionary checksums. The focused Huffman-length
  gate now covers 32/64/128/256-active Zstd shapes and checks exact code-length
  and weighted-cost checksums plus aggregate known-active throughput.
  Passing that active list through the back-reference builder to skip its leaf
  scan as well was rejected: nine further fixed-CPU-30 pairs reached only a
  0.14% aggregate gain, regressed JSON by about 1.1%, and won 16/27 runs. The
  retained change therefore removes only the measured redundant active-count
  scan and leaves the mature leaf-construction loop intact.
  Leaving the finalized Huffman plan's inactive canonical-code slots
  uninitialized was rejected too. Although all reads are guarded by active
  symbols, nine fixed-CPU-30 pairs regressed text/JSON by about 1.0%/1.5% and
  reached only 0.997x aggregate throughput; the compact zero initialization is
  retained because it generates better surrounding code.
  Moving the 1 KiB frequency table out of the finalized Huffman plan was
  rejected as well. It shrank copied plan state, but nine fixed-CPU-30 pairs
  improved text/JSON by only 1.8%/0.9% while binary regressed consistently by
  about 1.2% (0.45% aggregate gain, 15/27 wins), below the retention bar.
  Replacing short-slice Wyhash calls in dictionary phrase collection with an
  incrementally updated FNV-1a key was rejected. Full byte equality preserved
  collision safety and trainer output, but nine fixed-CPU-30 pairs reached only
  0.994x aggregate throughput with binary regressing about 2.6%; Zig's tuned
  short-input Wyhash remains the better choice for the current 3–32-byte ranges.
  Lowering the phrase-map activation threshold from 128 retained candidates to
  64 was rejected too. Nine fixed-CPU-30 pairs regressed all three trainer
  medians and reached 0.995x aggregate throughput with only 8/27 wins, so the
  existing linear-to-hash crossover remains unchanged.
  Raising the same crossover to 256 was neutral as well: nine fixed-CPU-30
  pairs reached only 1.002x aggregate throughput with 16/27 wins. The measured
  128-entry crossover remains in production.
  Pre-reserving the phrase index from its 128-entry activation point to the
  current 1,024-candidate cap was rejected despite saving 10–12 allocations and
  roughly 77–179 KiB per validated training case. Nine fixed-CPU-30 pairs
  regressed text/JSON medians by about 1.3%/0.6%; eager allocation and the larger
  table footprint outweighed avoided growth, so geometric outliers were not used
  to justify retaining it.
  Precomputing each candidate's ordinary Wyhash for lookup and occasional
  insertion was rejected too. It left allocation counts unchanged but enlarged
  hash-map keys; nine fixed-CPU-30 pairs regressed binary by about 3.2% and
  reached 0.996x aggregate throughput despite small text/JSON gains.
  Replacing slice keys with bare phrase indexes reduced allocated bytes by
  roughly 12–14%, but added an indirection to every stored-key hash. Nine
  fixed-CPU-30 pairs regressed JSON/binary by about 2.1%/1.3% and reached only
  0.988x aggregate throughput, so this smaller but slower table was removed.
  Periodically rebuilding that string map every 1,024 replacements to remove
  tombstones was rejected as well: it preserved allocations and bytes but
  regressed text/JSON by about 0.5%/2.5%; only binary improved (6.8%), leaving
  mixed results and just 13/27 wins.
  Finally, using the hash map's adapted-key API to reuse one Wyhash across a
  miss and insertion preserved the original key layout and allocation totals,
  but nine fixed-CPU-30 pairs produced only 1.002x aggregate throughput with
  16/27 wins. It was removed as noise-level complexity.
  An exact `u128` packed key for phrases up to 15 bytes was rejected in both a
  mixed dual-index form and a form limited to configurations whose maximum
  phrase length fit entirely. The latter still regressed JSON/binary by about
  1.6%/0.9%, reached 0.994x aggregate throughput, and won only 9/27 fixed-core
  pairs; integer-key hashing plus a second table did not beat short Wyhash.
  Storing only one exact Wyhash-to-index representative (with a collision-safe
  linear fallback) also failed: despite a smaller map, nine fixed-CPU-30 pairs
  reached 0.970x aggregate throughput and won only 7/27 runs. The ordinary
  string-key map remains faster, especially on high-uniqueness binary samples.
  The retained phrase-index replacement uses one allocation containing compact
  `{Wyhash, phrase_index+1}` slots, a 75% load cap, and backward-shift deletion
  without tombstones. Hash collisions still compare complete phrase bytes, and
  tests force colliding wrap-around clusters, middle deletion, growth through
  1,024 slots, and every allocation-failure point. Fifteen alternating
  fixed-CPU-30 pairs improved validated/validated-separate/validated-targets
  training by about 1.07–4.45x with 135/135 wins across text, JSON, and binary.
  The full Zstd validated path improved 1.006x/1.007x/1.076x (36/45 wins), and
  its cumulative allocation bytes fell by roughly 10–14 KiB per case without
  changing allocation counts or dictionary checksums. A follow-up that reused
  the lookup hash on insertion was rejected at 0.995x aggregate throughput.
  Replaced the generic phrase StringHashMap with a dedicated single-allocation
  open-addressed index. Each 16-byte slot retains Wyhash plus a stable phrase
  index, full byte equality resolves collisions, and backward-shift deletion
  removes tombstones without periodic rebuilds. Tests force a colliding cluster
  across the table boundary, delete its middle entry, grow through 1,024 slots,
  and exhaust every allocation point; the existing scan-reference trainers
  preserve exact output. Fifteen alternating fixed-CPU-30 ReleaseFast pairs
  improved validated, separate-validated, and multi-target training on all nine
  text/JSON/binary combinations (45/45 wins), by roughly 1.07x–4.45x. The full
  Zstd validated path improves 1.006x/1.007x/1.076x with 36/45 wins, while its
  cumulative allocation bytes fall by about 10–14 KiB per case. Profiling moves
  `collectPhrasesAlloc` from roughly 31% to 11% of the combined benchmark.
  Reusing a precomputed Wyhash across lookup and insertion inside the dedicated
  index was rejected independently: nine fixed-CPU-30 pairs reached 0.995x
  aggregate throughput, with JSON and binary both losing every run. Hashing on
  the uncommon insertion path remains cheaper for surrounding code generation.
  An ordinary unbounded Huffman tree can match package-merge lengths exactly
  whenever its natural depth stays within Zstd's 11-bit limit, and focused
  128/256-symbol benchmarks measured roughly 5.3x/5.5x construction speedups.
  Production selector experiments were nevertheless rejected: active-count
  thresholds from 128 through 256 and frequency-spread filters preserved up to
  a 2.0x binary-training win but repeatedly regressed text or JSON by 0.5–3%.
  Speculative failure cost and classifier/code-layout overhead make this unsafe
  to retain until callers can cheaply prove the depth bound.
  Packing each back-reference package's `(weight, creation_index)` into one
  directly comparable `u64` and shrinking the DAG node to two `u16` children
  was rejected for the same cross-workload reason. Nine fixed-CPU-30 focused
  pairs improved dense literal, 128-active Zstd, and 256-active Zstd package
  merge by about 1.19x/1.38x/1.43x, all 9/9 wins. Trainer tracing then showed
  text and JSON build only two full 256-symbol tables while binary builds 53,638
  mostly partial 65–223-symbol tables. Restricting the packed representation to
  partial Zstd tables retained a 1.17x binary gain, but nine end-to-end pairs
  still regressed text by 1.1% and JSON by 1.9% (JSON 0/9 wins), despite neither
  corpus entering the new path. Branch hints and restoring the original full
  table call shape did not remove the code-layout cost, so the indexed-node
  implementation remains in production.
  A single-implementation structure-of-arrays variant was rejected too. Keeping
  weights contiguous and splitting child pairs and leaf symbols reduced the hot
  comparison footprint without changing indexes or tie order; nine focused
  pairs improved dense literal/128-active/256-active construction by
  1.17x/1.15x/1.10x, all 9/9 wins. Nine trainer pairs were again mixed: binary
  improved 1.055x (9/9), text was neutral at 0.998x, and JSON regressed 1.5%
  with 0/9 wins, leaving only a 1.011x aggregate gain. The interleaved node
  representation remains preferable until the caller or compiler can isolate
  these workload-specific layout effects without penalizing full tables.
  Zstd Huffman plan finalization now replaces its generic comparison sort with
  an 11-bucket stable distribution pass. Active symbols already arrive in byte
  order, so iterating them once preserves the exact symbol tie-break within
  descending code-length buckets. A randomized 1–256-symbol oracle compares the
  complete order with the retained comparison-sort reference. The focused
  Huffman gate now covers 64/128/256-active sort kernels and measures
  3.36x/4.44x/5.38x local ReleaseFast speedups with identical checksums. Nine
  alternating fixed-CPU-30 dictionary pairs improve the full validated Zstd
  path by 1.018x/1.030x/1.038x for text/JSON/binary, with 26/27 wins and
  unchanged dictionary checksums.
  Sorting compact package-merge leaf indexes by `(frequency, symbol)` before
  constructing their 16–40 byte packed records was rejected as too small. It
  preserved exact code lengths and improved the focused 64-active Zstd case by
  about 2.2%, but 18/48/32-active cases moved by only about 0–1.2%. Nine
  fixed-CPU-30 trainer pairs improved text/JSON by roughly 0.8% each, left
  binary effectively unchanged, and reached only 1.0085x aggregate throughput
  with 20/27 wins, below the retention bar.
  Bulk-copying the remainder of compact package-merge lists after either merge
  input was exhausted was rejected despite strong focused results. It preserves
  comparator calls and exact ordering, and nine fixed-CPU-30 pairs improved the
  18/48-active DEFLATE and 32/64-active Zstd kernels by roughly
  1.13x–1.17x, all 36 focused runs winning. End-to-end dictionary training was
  mixed: text/JSON improved 1.050x/1.029x, but binary reached 0.997x with only
  2/9 wins. The scalar tail loop remains because the compiler's existing
  record copies interact better with binary-heavy surrounding code.
  Sharing one Huffman-weight histogram across tableLog 5/6 FSE size estimates
  and emission candidates was rejected as another mixed micro-optimization. It
  preserved both tableLog winners, estimator/wire equality, and invalid-weight
  handling, but nine fixed-CPU-30 trainer pairs improved text/JSON by only
  1.5%/1.1% while binary regressed about 1.0% in all 9 runs. Aggregate
  throughput moved only 1.004x, so each FSE candidate continues to construct
  its own small 16-symbol statistics table.
  Small Huffman plan construction no longer zeroes its 1 KiB frequency table
  immediately before overwriting all 256 entries from the four histogram lanes.
  Code and bit-count lookup tables retain their required zero initialization,
  and the striped-vs-scalar plan oracle compares the complete frequency array,
  including inactive symbols. Nine alternating fixed-CPU-30 dictionary pairs
  improve full validated Zstd training by 1.049x/1.026x/1.024x for
  text/JSON/binary, with 26/27 wins and identical output checksums.
  Narrowing the per-block striped Huffman histogram was rejected. A phase-aware
  five-lane `u16` design is overflow-safe for the 262,143-byte literal-header
  limit, while a four-lane mixed `u32`/`u16` design preserves the original hot
  loop and is safe for the 128 KiB Zstd block limit; the unbounded dictionary
  aggregate remained `u32` in both cases. Fragmented-slice and maximum-length
  oracles matched scalar counts exactly. Nevertheless, the five-lane form fell
  to 0.316x/0.343x/0.665x and the mixed-width form to
  0.443x/0.476x/0.772x for text/JSON/binary, all 0/27 wins. Narrow counter
  updates cost far more than the smaller clear/cache footprint on this CPU.
  Prepacking only the back-reference builder's initial leaves as
  `(u32 frequency, u16 creation_index)` keys was rejected as too narrow. It
  preserved the original node arena, merge, tie order, and exact code lengths;
  nine focused pairs improved dense/128-active/256-active construction by
  1.044x/1.017x/1.043x, all 27 runs winning. Nine trainer pairs improved binary
  by 3.3%, but text/JSON were effectively neutral at 1.002x/0.999x and the
  aggregate reached only 1.012x with 17/27 wins, below the retention bar.
  FSE normalized-count size estimation now runs the fixed-buffer encoder state
  machine in count-only mode instead of filling and discarding a 128-byte
  temporary header. Sequence-table planning and real emission retain byte
  output and capacity checks. A randomized oracle covering tableLog 5–9 and
  sparse zero runs matches the fixed writer's exact length for over 100 valid
  normalized tables. The focused gate measures a 1.33x header-length speedup;
  nine alternating fixed-CPU-30 dictionary pairs improve the full validated
  Zstd path by 1.024x/1.021x/1.006x for text/JSON/binary, with 24/27 wins and
  identical checksums.
  FSE compression tables are now built directly into caller-owned storage
  instead of returning their roughly 1.5 KiB state/transform arrays by value.
  Only the `table_len` state prefix and `max_symbol+1` transform prefix are
  initialized; consumers already enforce those bounds. A poisoned-output oracle
  compares more than 100 randomized tableLog 5–9 tables against the previous
  zero-initialized construction and verifies every reachable field. Nine
  alternating fixed-CPU-30 dictionary pairs improve full validated Zstd
  training by 1.028x/1.033x/1.010x for text/JSON/binary, with 23/27 wins and
  unchanged checksums.
  Removing repeated symbol and state-index checks from the internal
  Huffman-weight FSE size estimator was rejected as too small. A checked
  reference and validated-table fast path matched exactly across more than 300
  randomized tableLog 5/6 streams, but nine fixed-CPU-30 trainer pairs reached
  only 1.0055x aggregate throughput: text was neutral at 0.999x and JSON/binary
  improved about 0.3% each. The checked helpers remain shared with emission.
  Shrinking the Huffman-weight FSE compression table from the generic
  512-state/64-transform maximum to its actual 64-state/16-transform bounds was
  rejected as noise-level. The poisoned-output table oracle remained exact,
  but nine fixed-CPU-30 trainer pairs improved text/JSON/binary by only
  1.0039x/1.0035x/1.0005x. The generic private table layout remains because the
  aggregate change is well below the 1% retention bar.
  The production optimal LZ77 parser now stores its hash-chain head and
  predecessor positions as absolute `u32` indexes, with `0xffffffff` as the
  empty sentinel. Inputs beyond the compact index range retain the existing
  `isize` fallback, while the reference path remains available for exact
  token comparison. This halves both hot index arrays on 64-bit targets: for a
  128 KiB input the combined head/previous capacity falls from about 1.25 MiB
  to 640 KiB. A 64-shape min-match-3/4 oracle compares complete token streams,
  and an independent 70 KiB index oracle checks every initialized head and
  predecessor beyond the 16-bit position boundary. Twelve 128 KiB Silesia
  cases retained identical best-compressed sizes; five alternating fixed-CPU-30
  pairs improved all twelve, with representative medians of about 1.018x for
  `nci`, 1.010x for `mozilla`, 1.043x for `dickens`, 1.047x for
  `reymont`, and 1.057x for `xml`.
  Three related optimal-parser experiments were rejected. Extending the
  existing four-byte prefix-cost bound to the three-byte DEFLATE best path
  improved `mozilla` but regressed `dickens`/`reymont` by roughly 3--4%; a
  long-match-only variant regressed them by about 10%. Packing an exact
  three-byte tag beside each predecessor recovered `nci`/`mozilla` gains
  but remained mixed across Silesia. A `u16` relative-distance chain reduced
  memory further yet added a dependency subtraction to every chain step,
  reaching only about 0.79x/0.83x on `nci`/`mozilla`. Finally, an
  eight-byte-first match-length probe preserved exact lengths but reached only
  about 0.91x on `nci`; the existing 32-byte vector-first comparator remains.
  The native Zstd sequence emitter now reuses the exact serialized literal-section
  length it has already materialized when scoring FSE table plans, instead of
  rebuilding the same Huffman histogram and plan through
  `sequenceLiteralsPayloadSectionLen`. A focused oracle compares the complete
  emitted block against the former rescanned path byte-for-byte. Nine alternating
  fixed-CPU-8 A/B rounds across all 15 encode-benchmark case/level rows retained
  identical output sizes and improved every median (about 1.074x geometric mean):
  the 129 KiB multi-block row improved by about 1.098x/1.071x/1.041x at levels
  1/3/9, while the small text row improved by about 1.21x. The runtime libzstd
  1.5.5 compatibility matrix still accepts all 273 cases. An adjacent experiment
  that passed the large FSE/Huffman decoder state to its specialized loop by
  pointer removed two entry copies and reduced its stack frame, but consistently
  slowed `huffman80k` to about 0.895x across eight fixed-CPU pairs; it was
  reverted because the alias/code-generation penalty outweighed the saved copies.
  A follow-up score-first sequence selector was also rejected. It computed exact
  RLE/predefined/FSE payload sizes and emitted only the winning representation; a
  64-shape oracle matched the former emit-all selector byte-for-byte. Nine
  alternating fixed-CPU-8 rounds improved the 15-row encode matrix by about
  1.013x geometrically, but `multiblock` level 9 regressed to about 0.991x and
  the three text rows were effectively flat/mixed. Production therefore keeps
  the simpler emit-all arbitration while retaining only the broader, consistently
  positive literal-section length reuse above.
  Directly Huffman-encoding discontiguous sequence literal runs without first
  materializing their logical byte stream was also rejected. Single-stream and
  non-divisible four-stream byte oracles matched the existing wire, and the
  wide Repeat_Mode fixture removed one allocation plus 46,203 cumulatively
  requested bytes. However, nine fixed-CPU-8 rounds regressed 12 of 15 encode
  rows; text fell to roughly 0.90--0.91x and the geometric mean was 0.973x. The
  simple contiguous materialization remains faster than repeated run-boundary
  traversal.
  Exact token-stream deduplication across greedy, lazy, rep-beam, and optimal
  candidates was likewise rejected in the shared selector. The 8 KiB text
  oracle proved lazy/optimal/rep-beam stats, tokens, and emitted wire identical,
  and nine fixed-CPU-8 rounds improved the 129 KiB multi-block row by about
  1.112x/1.059x/1.016x at levels 1/3/9. However, text regressed consistently
  to roughly 0.84x and binary/tradeoff rows were mildly negative, leaving the
  15-row geometric mean at only 0.975x. Any future candidate deduplication should
  live in an isolated large-block path instead of perturbing the shared small
  selector's code layout.
  Restricting that deduplication to blocks of at least 33 KiB and moving token
  equality plus optimal parsing out of line still did not produce a robust win.
  Fifteen fixed-CPU-8 rounds left the 15-row matrix at about 0.998x geometrically:
  `multiblock` level 9 improved about 1.013x, but level 1 fell to about 0.987x and
  the text controls remained 0.986--0.993x. The isolated variant was removed.
  Reusing `LargeSequenceScratch.literals_prefix` for the small-sequence emitter
  was rejected as neutral/mixed. Nine fixed-CPU-8 rounds kept all 15 output
  sizes identical but produced a 1.000x geometric mean; `multiblock` level 9
  improved about 1.040x while `level3_tradeoff` level 3 regressed to about
  0.973x. Per-candidate allocation reuse is therefore not a general throughput
  win on the current allocator/code layout.
  Emitting generic table-plan payloads directly into the destination and
  backfilling their three-byte block header was rejected as below threshold. A
  buffered-reference oracle and exhaustive allocation-failure injection proved
  byte identity plus transactional prefix rollback, but fifteen fixed-CPU-8
  medians produced only a 1.004x geometric gain and JSON level 9 regressed to
  about 0.996x. The temporary payload/bitstream buffers remain for their simpler
  ownership behavior.
  Returning the large `SequenceTablePlanAlternatives` union by value was also
  audited after assembly showed a roughly 10.4 KiB clear plus whole-result copy
  per table family. A caller-owned fill API removed both operations and reduced
  the helper stack frame from about 18 KiB to 7.5 KiB. Fifteen fixed-CPU-8 rows
  nevertheless reached only a 0.977x geometric mean: multiblock and most
  structured rows improved, but all three text levels fell consistently to
  about 0.814--0.816x. The original return-by-value layout remains because it
  produces materially better surrounding code on the text path.
  The retained narrower alternative keeps that return ABI but leaves inactive
  `SequenceTablePlanAlternatives` union slots undefined, initializing only
  `len` and every slot exposed through `items[0..len]`. This removes the helper's
  roughly 10.4 KiB entry clear without changing candidate construction or the
  whole-result return. Fifteen alternating fixed-CPU-8 rounds retained every
  encoded size and improved the 15-row geometric mean by about 1.012x; the
  129 KiB multi-block levels 1/3/9 improved about 1.061x/1.046x/1.036x with
  15/15, 14/15, and 13/15 wins. Text/JSON controls stayed within 0.3% of
  baseline at worst. Because the short 100-iteration decode reference gate
  intermittently crossed its `huffman80k` floor, a separate before/after
  ReleaseFast audit used independently built binaries and 15 alternating
  fixed-CPU-8 rounds. Decoder medians were 1.008x/1.001x/0.998x/0.999x/0.999x
  for numbered JSON, `huffman80k`, `ascii64k`, large JSON, and mixed binary
  respectively (1.001x geometric mean), with identical checksums; the gate
  fluctuation is not an encoder-layout decode regression.
  Cross-block history candidates now emit their already-known sequence values
  directly against the current frame's FSE tables and repeated-offset state.
  Previously the history path first built a complete block with initial state,
  parsed that temporary wire back into sequence values, planned the current
  state, emitted a replacement, and copied it over the first block. A focused
  oracle compares the direct result byte-for-byte with that legacy replay path,
  verifies lower allocation count and bytes, and exhaustively checks allocation-
  failure rollback. Nine alternating fixed-CPU-2 runs across all 15 encode rows
  retained every encoded size and checksum while improving the geometric mean
  by about `1.064x`. The 129 KiB multi-block levels 1/3/9 improved by about
  `1.102x`/`1.062x`/`1.048x`, with all 27 target pairs winning; the formal
  encode gate and all 273 bidirectional libzstd 1.5.5 compatibility cases pass.
  Reusing one materialized literal-section prefix inside only that direct
  history path was rejected despite improving the three multi-block rows by
  about `1.018x`/`1.016x`/`1.018x`. Nine alternating fixed-CPU-2 full-matrix
  runs exposed release-layout regressions: binary levels 3/9 fell to about
  `0.937x`, several other controls were negative, and the 15-row geometric mean
  was `0.985x`. The narrower helper was removed; direct history emission retains
  the existing planner/emitter layout.
  Moving the same prefix reuse into a `noinline` history-only helper removed
  those severe layout losses and improved multi-block levels 1/3/9 by about
  `1.023x`/`1.020x`/`1.027x`. It was still rejected: nine full-matrix rounds
  reached only `1.0076x` geometrically, below the 1% retention bar, while binary
  levels 3/9 remained mildly negative at about `0.994x`/`0.996x`.
  The rolling-history matcher now returns immediately when fewer than its
  required eight history bytes exist. This removes a full byte-by-byte scan and
  empty-index lookup pass from every first frame block without changing any
  candidate or wire decision. A focused empty-history test covers the boundary.
  Twelve alternating fixed-CPU-2 full-matrix runs retained all 15 encoded sizes
  and checksums and improved the 180-pair geometric mean by about `1.092x`; text
  levels 1/3/9 improved by about `1.486x`/`1.475x`/`1.406x`, binary by
  `1.052x`/`1.034x`/`1.007x`, and multi-block by
  `1.007x`/`1.013x`/`1.017x`. The weakest row was JSON level 9 at `0.9987x`.
  The formal encode gate and 273-case bidirectional libzstd 1.5.5 probe pass.
  Cross-block history candidates at or below 1/128 of their source block now
  terminate block arbitration before the independent Huffman and local-match
  families. RLE blocks remain excluded, and the threshold is deliberately far
  below the one-bit-per-literal lower bound used by the existing decisive-match
  proof. A retained fast-vs-exhaustive oracle covers 120 multi-block inputs
  across 2/4/8 KiB blocks, levels 1/3/9, eight seeds, exact copies, one-byte
  mutations, rotated quarters, and two low-entropy periodic shapes; at least 24
  cases exercise the shortcut and every frame is byte-identical. Twelve
  alternating fixed-CPU-2 full-matrix runs retained all 15 sizes/checksums and
  improved the 180-pair geometric mean by about `1.086x`; multi-block levels
  1/3/9 improved by `1.064x`/`1.158x`/`1.135x`. The encode gate and all 273
  bidirectional libzstd 1.5.5 compatibility cases pass.
  A wider history shortcut was audited rather than assuming compression ratio
  alone was sufficient. Raising the cutoff to 1/3 immediately found a periodic
  counterexample: local arbitration produced 819 bytes while history-only
  returned 875 bytes. The retained extension therefore requires both the
  existing distributed wide-alphabet classifier and absence of a >=16-byte
  periodic segment, and keeps the original 1/128 path as an independent first
  branch. The fast-vs-exhaustive oracle now covers 192 combinations by adding
  periodic tails, within-block 64-byte repetition, and sparse mutations; all
  outputs are byte-identical. Twelve fixed-CPU-2 full-matrix runs against the
  committed 1/128 baseline retain every size/checksum and improve the 180-pair
  geometric mean by about `1.224x`; the multi-block levels improve by about
  `3.605x`/`2.414x`/`2.310x`, all 36 target pairs win, and the weakest control
  is about `0.995x`. Incremental and dictionary-backed paths retain exhaustive
  arbitration.
  The deferred-smallest frame scheduler now treats the larger adaptive split as
  decisive on wide-alphabet inputs when it beats the completed primary frame by
  at least 12.5%. This skips a final serial 1/2/4 KiB candidate only after the
  primary and larger split are both known, while narrow structured inputs keep
  the complete ladder. A production-vs-exhaustive oracle covers 64 generated
  129/192 KiB inputs across levels 1/2/3/4/5/6/9/22, four seeds, varying noise density, and
  copied/non-copied tails; every selected frame is byte-identical, and every
  triggered larger split is no larger than the explicitly encoded smallest
  split. Twelve alternating fixed-CPU-2 full-matrix runs retained all 15 sizes
  and checksums, improved the 180-pair geometric mean by about `1.079x`, and
  improved multi-block levels 1/3/9 by `2.005x`/`1.289x`/`1.248x` with 36/36
  target wins; the weakest control was about `0.992x`. The level-schedule gate,
  encode gate, and all 273 bidirectional libzstd 1.5.5 cases pass.
  The same larger adaptive candidate is now evaluated as an out-of-line
  preflight before primary/split worker launch on inputs above the 128 KiB
  primary block size. Wide-alphabet frames whose larger split is already at
  most one quarter of the source return it directly; other shapes fall through
  to the unchanged complete scheduler. The 64-case, eight-level oracle now
  explicitly verifies every preflight hit against both primary and smallest
  split as well as comparing the final production/exhaustive bytes. Twelve
  alternating fixed-CPU-2 full-matrix runs retain every size/checksum and
  improve the 180-pair geometric mean by about `1.257x`; multi-block levels
  1/3/9 improve by `1.452x`/`4.359x`/`4.710x` with 36/36 wins, while the
  weakest control remains about `0.993x`. The out-of-line entry placement is
  intentional: placing the same preflight inside the large scheduler regressed
  short text controls by 3--5%.
  The preflight is additionally gated by direct 64-byte evidence that the final
  quarter starts with content already present earlier in the input. Without
  that screen, a 129 KiB wide/no-copy control missed the 1/4 return threshold
  and redundantly rebuilt the larger split, regressing level 1 from about 44 ms
  to 66 ms. Twelve alternating fixed-CPU-2 pairs with the retained evidence
  check keep that miss control near 39.1 ms on both sides, while the copied-tail
  target still improves from about 6.7 ms to 4.6 ms (`~1.46x`). A focused test
  pins copied, random, and short-input classifier behavior.
  For evidence-qualified level-1/2 frames, the preflight now evaluates an 8 KiB
  block size instead of reusing the ordinary 2 KiB larger split. A direct
  1/2/4/8/16/128 KiB sweep found 8 KiB to be the local speed/ratio optimum on
  the retained 129 KiB shape: 27,363 bytes in about 4.1 ms, versus 27,863 bytes
  in 5.2 ms at 2 KiB; 16 KiB reached 27,013 bytes but cost about 11.9 ms. The
  eight-level oracle treats this preflight as an explicit fourth candidate and
  requires every hit to be no larger than primary and both legacy splits; miss
  cases still match exhaustive output byte-for-byte. Twelve fixed-CPU-2
  full-matrix rounds against the 2 KiB preflight improve the geometric mean by
  `1.022x`; level-1 multi-block improves `1.304x` and shrinks from 27,863 to
  27,363 bytes, while the weakest unchanged control remains about `0.993x`.
  Highest ratio levels 19--22 now evaluate a 32 KiB preflight beside the prior
  8 KiB larger split and keep the shorter frame. A 8/12/16/24/32 KiB sweep
  places 32 KiB on a ratio-oriented Pareto point: the level-22 multi-block frame
  shrinks from 27,363 to 26,679 bytes (from `1.0687x` to `1.0420x` libzstd
  1.5.5 size) while encoding in about 16.2 ms versus libzstd's 23.8--26.7 ms on
  the fixed CPU. Twelve level-22 A/B rounds leave text/JSON/binary/tradeoff
  wires unchanged; the multi-block row deliberately trades roughly 4.1x of
  Vort speed for 684 bytes. The formal encode matrix now includes level 22,
  expanding from 15 to 20 rows and locking all five ratio-level outputs.
  Replacing the rolling-history matcher's scalar extension with the shared
  32-byte-vector/8-byte-tail shape was rejected. An exhaustive mismatch and
  maximum-length boundary test preserved exact lengths, but twelve fixed-CPU-2
  target pairs improved multi-block levels 1/3/9 by only
  `1.006x`/`1.002x`/`1.002x`, below the 1% retention bar.
  Breaking the four-way rolling-history bucket scan at its first sentinel was
  exact and improved the isolated multi-block levels by about
  `1.032x`/`1.026x`/`1.029x`, but twelve full-matrix rounds reached only
  `1.003x` geometrically and regressed text level 9 to `0.989x`. The branch was
  removed rather than perturbing the shared single-block layout.
  Raising the bounded rolling-history plan from 128 to 256 matches was rejected
  too. The retained multi-block wire did not shrink, and twelve fixed-CPU-2
  target pairs measured `0.994x`/`1.001x`/`1.000x` at levels 1/3/9 while
  doubling the plan's stack storage. The existing 128-match bound remains.
  Stopping each four-way history bucket after its first full-tail match was also
  rejected. The optimization is exact under the existing newest-first bucket
  order and strict-length tie rule, but twelve fixed-CPU-2 full-matrix rounds
  reached only `1.0008x` geometrically; multi-block levels 3/9 were about
  `0.997x`, so the clearer complete bucket scan remains.
  A single-sequence `Repeat_Mode` specialization was also rejected. It replaced
  the generic viability matrix with a linear lowest-state scan and matched
  predefined/compressed-table state selection exactly, but twelve fixed-CPU-2
  full-matrix rounds reached only `0.9982x` geometrically; binary level 9 fell
  to `0.9896x` and all three multi-block rows were neutral-to-negative. The
  generic planner remains intact.
  Moving the retained-history winner copy after both decisive checks was also
  rejected. It is semantically safe and removes one copy only on early-return
  blocks, but twelve fixed-CPU-2 full-matrix rounds reached just `1.0018x`
  geometrically; multi-block level 1 was `0.998x` and the weakest control was
  `0.991x`. The original candidate ownership order remains.
  Replacing the rolling-history index's 1 MiB sentinel clear with one byte of
  valid length per four-entry bucket was rejected. Focused tests proved that
  reset hides stale entries and reinsertion exposes only initialized positions,
  but the extra length load/store on every history insertion and query outweighed
  the smaller 32 KiB clear: twelve fixed-CPU-2 multi-block pairs regressed all
  three levels by roughly 1--2%. The sentinel layout remains.
  Forcing the large frame-state sequence replacement helper out of line was
  also rejected. Nine fixed-CPU-2 full-matrix rounds were byte-identical and
  had no meaningful control regression, but improved only `1.0029x`
  geometrically; the multi-block levels measured `1.002x`/`0.998x`/`1.002x`.
  The compiler's existing inlining decision remains.
  Caching one finalized sequence-literal Huffman plan in `LargeSequenceScratch`
  by its exact 256-entry frequency vector was rejected as mixed and below the
  retention threshold. A focused oracle covered first-use misses, equal-frequency
  literals in a different byte order, changed-frequency misses, scratch reset,
  complete plan equality, byte-identical emitted frames, and both native/libzstd
  decoding. Fifteen alternating fixed-CPU-8 rounds retained all 15 encoded sizes
  but improved the geometric mean by only 1.0013x: text levels reached about
  0.9944x/0.9945x/0.9953x and multi-block level 1 reached about 0.9941x, while
  the best isolated row was multi-block level 9 at about 1.0244x. The cache and
  its emitter plumbing were removed; future work should avoid perturbing every
  small-sequence emission for such sparse cross-candidate reuse.
  The indexed duplicate scorer's old raw-literal shortcut was audited against
  the now-supported full 256-symbol Huffman/FSE-weight path. A constructed
  127-symbol all-high-byte block proved a real scoring gap (`2012` exact bytes
  versus `7947` from the raw shortcut), but four production corrections were
  rejected after fixed-CPU-8, 15-round end-to-end A/B. Unconditional exact
  scoring fell to `0.955x` geometrically, a cardinality/skew filter reached
  `0.998x`, an all-high-byte split reached `1.004x` but retained a roughly 1%
  level-3 tradeoff regression, and moving that split out of cancellable mixed
  search reached only `1.003x` with a roughly 1.2% ratio-level regression. A
  companion attempt to derive `max_symbol` from the already ascending active
  list reached `0.998x`. All variants were removed rather than slowing common
  data for a narrow scoring correction; this case remains a future ratio-mode
  target once scoring can be isolated without perturbing hot selector layout.
  Reducing `planRepeatSequenceCodes`' fixed 32 KiB viability-mask clear was
  explored in four byte-exact layouts and rejected. Full initialized, poisoned,
  and sparse implementations matched selected states across LL/OF/ML, 1--512
  sequences, predefined tables, and a synthetic 128-state compressed table.
  Clearing each used row improved the multi-block level 1/3 rows by about
  1.044x/1.037x but reached only 1.006x geometrically and regressed binary level
  3 plus ratio-level tradeoff by about 0.9--1.2%. Specializing 1/2/4/8-word row
  widths bloated code and dropped text to roughly 0.82x. One contiguous used-row
  prefix clear and a runtime compact-row stride also remained mixed at only
  1.002x/1.004x geometric means, with important binary/tradeoff regressions.
  The fixed layout remains; future work should isolate table reuse at a broader
  call-site boundary instead of changing this deeply inlined small planner.
  Reusing a freshly computed predefined state path as the equivalent
  `Repeat_Mode` plan when the previous table was predefined was also rejected.
  A 1--512-sequence LL/ML/OF oracle proved every state and emitted symbol
  identical, but the additional large-plan construction/copy changed small-path
  code generation: fifteen fixed-CPU-8 rounds reached only `0.955x` geometrically,
  with all three text levels near `0.80x`. Omitting the dominated repeat
  alternative entirely was byte-exact and improved the multi-block rows by
  about 1.2--1.6%, but still reached only `1.004x` geometrically. The independent
  repeat planner and complete candidate set remain.
  Swapping `ArrayList` backing stores instead of copying each newly selected
  encoded candidate was rejected after splitting both arbitration layers. The
  combined top-level plus RLE/predefined/FSE variant reached `1.010x` across
  fifteen fixed-CPU-8 rounds, but binary level 9 regressed to `0.985x`. Either
  half alone exposed severe code-layout/capacity effects: block-internal-only
  and match-family-only swaps dropped all three text levels to roughly
  `0.81--0.82x`, with geometric means of `0.962x` and `0.959x`. Candidate
  A final variant swapped only candidates of at least 16 KiB. It isolated
  multi-block gains of about 1.025x/1.030x/1.015x at levels 1/3/9, but the
  aggregate remained just `1.009x` and binary level 3 regressed to `0.994x`.
  Candidate buffers therefore retain copy-based winner ownership; a future
  attempt must live in a dedicated large-block selector without adding a
  branch or changing capacity reuse in the shared path.
  A libzstd-inspired stable four-pass radix sort for package-merge's initial
  `(frequency, creation-order)` leaf indexes was rejected at the focused gate.
  Ninety-six randomized DEFLATE shapes and every Zstd active count from 65
  through 256 matched the comparison-sort code lengths exactly. Dense 286-symbol
  DEFLATE construction improved about 1.058x, but the important Zstd 128- and
  256-active kernels fell to roughly 0.955x/0.958x; the larger 4 KiB count/offset
  scratch outweighed avoided comparisons for these bounded alphabets.
  Replacing the same stable block sort with Zig's unstable PDQ sort was worse.
  The comparator already defines a unique `(weight, serial)` order and a
  65--256-active oracle matched every code length, but focused dense/128/256
  throughput fell to roughly `0.79x/0.73x/0.74x`; block sort remains preferable.
  Removing the finalized Huffman stream lookup and reading the plan's compact
  `u16` codes directly was rejected despite eliminating a 2.25 KiB temporary,
  its zero-fill, two compiler copies, and reducing the stream emitter's stack
  frame from roughly 7 KiB to 88 bytes. Fifteen fixed-CPU-8 rounds improved
  binary and multi-block rows by roughly 1--4%, but all three tiny-text rows
  fell to about `0.74--0.75x` (`0.975x` geometric mean). Building one lookup
  for all four Huffman streams while keeping the original `usize` hot loop was
  similarly rejected: multi-block improved up to `1.046x`, but text stayed near
  `0.81--0.84x` (`0.966x` geometric mean). Per-stream lookup construction is
  retained because it produces much better code for the decisive small-text path.
  The retained Huffman stream emitter instead keeps that proven `usize` lookup
  and original byte loop, but reserves the strict
  `ceil((literal_count * max_bit_count + 1) / 8)` output bound once and then
  appends bytes without repeated capacity checks. A checked-append reference
  covers 64/65/1,023/1,024/8,192-byte boundaries byte-for-byte. Fifteen
  alternating fixed-CPU-8 end-to-end rounds retained all 15 encoded sizes and
  improved the geometric mean by `1.039x`: JSON gained roughly 5.8--6.4%,
  binary gained 3.1--9.6%, tradeoff gained 2.5--8.3%, and multi-block levels
  3/9 gained 1.7%/4.4%; text stayed within about 0.1% of baseline at worst.
  Two follow-ups that changed only lookup ownership/layout were rejected. Filling
  the 2.25 KiB lookup in caller-owned storage removed two return-value copies
  and reduced the emitter stack frame to roughly 2.3 KiB, but fifteen fixed-CPU-8
  rounds reached only `1.007x` geometrically and binary level 1 fell to `0.990x`.
  Narrowing its canonical-code table from `usize[256]` to `u16[256]` likewise
  reached only `1.003x`, with binary level 1 at `0.990x`. The existing `usize`
  return shape remains because it generates a better hot byte loop. Leaving
  only the inactive `usize` code slots uninitialized also failed the retention
  bar: a poisoned-reference oracle proved active codes and the complete stream
  identical, but fifteen fixed-CPU-8 rounds reached only `1.001x` geometrically
  and multi-block level 1 fell to `0.993x`.
  Keeping the reserved capacity but writing through a local output pointer/index
  before one final `items.len` commit was rejected too. It removed repeated
  ArrayList length updates in assembly, but fifteen fixed-CPU-8 rounds reached
  only `0.995x` geometrically; text and multi-block levels regressed, so the
  compiler-friendly `appendAssumeCapacity` loop remains.
  Deferring direct Huffman-tree serialization until its exact size beat the FSE
  alternative was also rejected. A complete tree-byte oracle covered direct and
  FSE winners, but fifteen fixed-CPU-8 rounds reached only `0.998x` geometrically;
  all tradeoff levels and multi-block level 9 regressed. Both candidates remain
  materialized before the strict shortest-tree choice.
  Replacing the back-reference node's stored creation serial with its identical
  arena index was rejected. Keeping the node layout unchanged and changing only
  the equal-weight comparator improved dense/128-active focused construction by
  4.2%/1.6%, but the 256-active case reached 0.997x and won only 1/9 fixed-core
  pairs. Removing the now-redundant field improved dense construction further
  but still left the full-table case at 0.996x (2/9 wins). The explicit serial
  remains because its load produces better code for the important dense Zstd
  shape despite being mathematically equivalent to the node index.
  Applying libzstd's 192-entry `HUF_sort` bucket layout to package-merge leaves
  was also rejected after both focused and end-to-end measurement. Exact-count
  buckets below 166 plus logarithmic buckets above it matched comparison-sort
  code lengths on 128 randomized dense DEFLATE histograms and every Zstd active
  count from 65 through 256. Fifteen alternating fixed-CPU-8 focused pairs
  improved the production known-active 128/256-symbol kernels by about
  `1.073x`/`1.106x` (14/15 wins each). Nine end-to-end Zstd encode pairs kept
  all 15 frame sizes identical and improved the 129 KiB multi-block levels
  1/3/9 by about `1.122x`/`1.038x`/`1.070x`, but regressed the tiny text
  levels 3/9 to `0.969x`/`0.981x`. Marking only the bucket helper `noinline`
  retained a `0.975x` text level-3 result, while moving the whole package-merge
  instance out of line or adding an active-count threshold made text fall as
  low as roughly `0.82x`. The implementation, temporary public benchmark API,
  and three extra CSV rows were removed; the established 27-row gate schema and
  comparison sort remain. A future dense-only attempt must isolate codegen at a
  higher Zstd planner boundary without perturbing the shared small-text path.
  A subsequent combined isolation keeps the useful bucket algorithm without
  those code-layout regressions. The existing known-active entry now selects it
  only for the compile-time Zstd shape (`n == 256`, `max_bits == 11`) with at
  least 128 active symbols, and the entire dense package-merge instance is
  `noinline`; DEFLATE and smaller Zstd alphabets retain their exact previous
  call graph. The 65--256-active exact-length oracle covers the dispatch
  boundary. Fifteen alternating fixed-CPU-30 end-to-end pairs retained all 15
  encoded sizes and improved geometric-mean throughput by about `1.033x`;
  binary levels 1/3/9 gained `1.069x`/`1.031x`/`1.029x`, and the 129 KiB
  multi-block rows gained `1.129x`/`1.115x`/`1.064x`. Every control row stayed
  above `0.99x`, including text at `1.006x`/`0.996x`/`0.995x`. The unchanged
  27-row Huffman gate reports dense known-active 128/256 speedups around
  `1.08x`/`1.11x` on the same CPU, while the 273-case libzstd 1.5.5 matrix has
  zero unsupported frames.
- Optimized the shared Zstd Huffman lookup builder for valid complete canonical
  trees. The new caller-owned `buildComplete` path proves that canonical prefix
  ranges are adjacent and cover all 2,048 table entries while writing them, so
  the large literal-only decoder no longer clears its 4 KiB lookup before
  immediately overwriting every slot. The builder remains out of line so the
  large decode loop does not absorb its uncommon validation branches. Nine
  completed alternating fixed-CPU-2 same-process pairs on the 64 KiB
  printable-ASCII frame reduced the median Vort decode time from about 159.1 ms
  to 158.5 ms per 20,000 decodes (about 0.4%; 9/9 wins); hardware counters on
  the final path showed roughly 1.5% fewer instructions, 1.6% fewer branches,
  and 1.6% fewer cycles. Applying the same builder to sequence-interleaved
  literals also removes about 13% of instructions from `numbered_json` and 2%
  from `large_json`, leaving the raw-literal FSE control rows essentially
  unchanged. A final fixed-CPU counter pass after the safety fallback measured
  per-row instruction ratios of `1.152/1.000/1.015/1.021/1.000x`; the
  five-row geometric mean improves by about 3.6%,
  clearing the aggregate retention threshold even though the isolated
  `ascii64k` wall-clock gain is modest. The libzstd 1.5.5 reference floor for `ascii64k` is raised from
  0.50x to 0.60x. If completeness cannot be proven, decoding falls back to the
  original initialized table builder. Focused complete, mixed-width, incomplete,
  and overlapping prefix-table tests accompany the change, and the 273-case
  libzstd matrix plus all six upstream `decodecorpus` campaigns remain
  byte-exact (5,400 frames, all 64 LL/OF/ML mode tuples). An inlined variant
  regressed `huffman80k` by about 14% and was removed. A terminal
  LL=Predefined/OF=FSE/ML=Predefined specialization
  improved `numbered_json` by roughly 40--70%, but every tested placement or
  dispatch form regressed at least one adjacent large FSE path by about 1--7%;
  it was also fully removed rather than trading general throughput for the
  narrow win.
- Rejected replacing Zig std's Zstd Huffman canonical-tree sort with a local
  rank-count/rank-start builder modeled on upstream `HUF_readDTableX1_wksp`.
  The prototype decoded both direct and FSE-compressed weight headers, matched
  Zig std's active nodes field-for-field, and passed all 510 focused Zstd tests.
  Fixed-CPU counters showed the intended reductions (`numbered_json` about
  31% fewer instructions, `ascii64k` about 2%, and `large_json` about 2.7%),
  with wall-clock wins around 25--40%, 1--3%, and 5--8% respectively. However,
  every tested placement (inline, noinline, a dedicated object-format section,
  and 32-byte or 4 KiB alignment of the existing FSE loops) moved the unchanged
  raw-literal `huffman80k` path to a consistently worse front-end layout,
  regressing it by roughly 5--9%; some layouts also regressed `binary_mixed`.
  The parser, module, tests, and alignment changes were fully removed. Future
  tree-build work must preserve the established FSE loop addresses/call graph
  or move the whole decoder into a deliberately laid-out unit before retrying
  the rank-count algorithm.
  That isolated dense path now first builds an ordinary Huffman tree with two
  sorted queues, returning its exact depths when the natural maximum is within
  Zstd's 11-bit limit and falling back to the bucketed package-merge path
  otherwise. A `max_frequency <= 16 * min_frequency` prefilter rejects the
  measured high-spread failure family before sorting/building; the computed
  depth remains the authoritative check for every admitted distribution. Both
  dense helpers live in a dedicated object-format-aware text section, so adding
  the linear builder does not reorder ordinary Zstd/DEFLATE code. The
  65--256-active dispatch oracle, 128 balanced fast-path shapes, the exact 16/17
  spread boundary, and a skewed 128-symbol natural-depth failure all compare
  against package merge. Fifteen alternating fixed-CPU-30 end-to-end pairs
  retained every encoded size and improved geometric-mean throughput by about
  `1.044x`. Binary levels 1/3/9 improved `1.035x`/`1.025x`/`1.024x`, while the
  129 KiB multi-block rows improved `1.302x`/`1.134x`/`1.065x`; every control
  remained above `0.997x`. This supersedes the earlier rejected globally
  visible selector: the prefilter and depth probe are now confined behind the
  already profitable dense Zstd dispatch and cannot perturb the shared
  small-alphabet call graph.
  A matching attempt to isolate caller-owned sequence-table alternatives only
  for 500--512-sequence blocks was rejected as too small. A threshold oracle
  compared 499/500/512-sequence payload lengths, table payloads, and complete
  read-field streams against the established by-value selector. Fifteen
  alternating fixed-CPU-30 end-to-end pairs retained all frame sizes but
  improved only `1.0077x` geometrically; the target multi-block levels gained
  roughly `1.006x`--`1.014x`, while text level 3 reached `0.992x`. The extra
  wide-only section and duplicate fill plumbing were removed rather than
  retaining more than 100 lines for a sub-threshold gain.
  Narrowing the optimal LZ77 dynamic-programming costs and cached per-length
  minima from `usize` to `u32` for inputs through the 128 KiB Zstd block limit
  was likewise rejected. The all-literal upper bound is below 1.2 million bits,
  and 11 focused optimal tests covered min-match 3/4 token identity, the exact
  128 KiB/128 KiB+1 storage boundary, compact-index retention above that
  boundary, OOM recovery, and replay. Fifteen fixed-CPU-30 focused binary
  optimal pairs improved by `1.0107x` with 15/15 wins and identical 508-sequence
  output, but the full 15-row encode matrix improved only `1.0041x`
  geometrically and JSON level 3 reached `0.9884x`. The extra scratch array and
  generic cost-width path were removed because the isolated kernel gain did not
  survive whole-encoder measurement.
  Final sequence bit-field emission now borrows the selected combined table plan
  for 500--512-sequence blocks instead of passing its three embedded fixed-size
  state arrays by value. The complete borrowed emitter and its inlined helpers
  live in a dedicated object-format-aware text section; the ordinary 0--499
  sequence emitter retains its original code layout. A 499/500/512 boundary
  oracle compares every generated read field with the by-value reference, and a
  legal 500-sequence distance-four block is byte-identical and round-trips as a
  complete Zstd frame. Fifteen fixed-CPU-30 focused optimal-stage pairs preserve
  508 sequences, 8,839 encoded bytes, and the checksum while improving by
  `1.084x` with 15/15 wins. Fifteen full encode-matrix pairs retain all frame
  sizes and improve `1.050x` geometrically: binary levels 1/3/9 gain
  `1.523x`/`1.148x`/`1.157x`, multi-block gains `1.010x`/`1.010x`/`1.007x`,
  and every non-target control remains above `0.99x`.
  Lowering that isolated borrowed-emitter boundary from 500 to 450 sequences
  also covers the locked 471-sequence JSON plans while leaving 145-sequence
  text on the original path. The oracle now pins 449/450/512 field boundaries
  and a byte-identical 450-sequence complete block. Fifteen fixed-CPU-30 focused
  JSON-optimal pairs preserve 471 sequences, 774 encoded bytes, and checksum
  while improving `1.126x` with 15/15 wins. Fifteen full-matrix pairs against
  the 500-sequence version keep every wire size and improve JSON levels 1/3/9
  by `1.231x`/`1.325x`/`1.322x`; the incremental geometric mean is `1.050x`,
  with every control at or above `0.991x`.
  A post-change fixed-CPU profile moved the next encoder bottleneck to the
  repeat-aware beam parser: it accounts for about 25% of JSON level-3 cycles
  and 54% of binary level-3 cycles. Hoisting the parser's normalized minimum
  and maximum match bounds out of its position/state loops was nevertheless
  rejected. Focused oracles retained the exact 508-sequence, 8,600-byte binary
  stage result, but fifteen alternating fixed-CPU-30 pairs regressed primary
  text/JSON/binary beam throughput to `0.876x`/`0.960x`/`0.975x`, with 0/15
  wins in every row and a `0.936x` geometric mean. Splitting the bounds into
  additional hot-call arguments increased register pressure enough to outweigh
  the repeated clamping work, so the production parser remains unchanged.
  Forcing only the repeat-beam index's sole candidate `matchLength` call inline
  was also rejected. It removed the sampled call and `vzeroupper` boundary while
  retaining every stage counter and wire byte, but enlarging the beam loop hurt
  instruction-cache/register behavior: fifteen alternating fixed-CPU-30 pairs
  measured primary text/JSON/binary at `0.923x`/`0.968x`/`0.975x`, again with
  0/15 wins in each row and a `0.953x` geometric mean. The shared out-of-line
  vectorized matcher remains the better code layout.
  Repeat-beam initialization now materializes the complete first state instead
  of assigning only its cost into resized, uninitialized storage. This pins the
  intended initial recent offset of one in Debug, ReleaseSafe, and ReleaseFast;
  a four-byte distance-one oracle exposes the former optimized-build distance
  zero and protects the invariant. With every reachable state's distance now
  proven non-zero, the two transition sites pass only already length/distance-
  validated matches and the shared helper retains debug assertions instead of
  repeating runtime guards for both beam slots. A focused reference oracle
  covers minimum lengths three/four and repeat/new-distance costs. Fifteen
  alternating fixed-CPU-30 stage pairs against an initialization-fixed baseline
  preserve all counters and bytes while improving primary text by `1.151x`;
  JSON is neutral at `0.999x`, binary stays within noise at `0.993x`, and the
  three-row geometric mean is `1.045x`. Fifteen full encode-matrix pairs keep
  every frame size/checksum, improve JSON levels 1/3/9 by
  `1.036x`/`1.033x`/`1.033x` and binary by
  `1.013x`/`1.028x`/`1.024x`; the row-median geometric mean is `1.014x` and
  every row is at least `0.999x`.
  Expanding the repeat-beam's 4,096-entry hash head was rejected after a two-
  point sweep. An 8,192-entry table preserved all focused stage counters/wires
  and improved binary by `1.087x` with 15/15 wins, while text/JSON were
  `1.000x`/`1.004x`; however, fifteen complete encode-matrix pairs improved
  only `1.0055x` geometrically and consistently regressed text levels 1/3/9 to
  `0.988x`/`0.986x`/`0.989x`. At 16,384 entries the added zeroing/cache footprint
  was clearer: eleven focused pairs left binary at `1.066x` but text/JSON fell
  to `0.829x`/`0.968x`, for a `0.950x` geometric mean. The compact 4,096-entry
  head remains the general default; any wider follow-up must be isolated behind
  a collision-density classifier rather than taxing every repeat-beam input.
  A first adaptive 8,192-entry follow-up was also rejected. It sampled four
  distributed 256-byte windows and stored the wide head in reusable predecessor
  scratch only for inputs with more than 40 distinct sampled bytes, so the
  intended text/JSON path retained the 4,096-entry table and all stage wires.
  Even so, the added classifier and dynamic-head code layout reduced focused
  text/JSON throughput to `0.836x`/`0.951x`; binary improved only `1.030x`, for
  a `0.936x` geometric mean. Any future adaptive width must isolate the entire
  wide implementation at a higher boundary so ordinary beam codegen is intact.
  Isolating the full wide implementation in a dedicated text section and using
  only a 16-byte high-bit classifier was rejected as well. Fifteen focused
  fixed-CPU-30 pairs preserved all stage counters/wires, but text/JSON/binary
  measured `0.897x`/`0.991x`/`0.987x`; replacing the fixed head with dynamic
  scratch and duplicating the parser still disturbed the profitable narrow
  layout. The 8,192-entry direction is closed unless the index representation
  itself changes. During that audit, the compact four-byte index's final three
  predecessor slots were found to be unwritten. Production Zstd uses minimum
  match four and never reads them, but generic repeat-beam callers may request
  minimum match three. The builder now writes the empty sentinel for every
  anchorless tail slot, with a pre-poisoned Debug/ReleaseSafe/ReleaseFast oracle.
  Profiling the 32 KiB Brotli ratio encoder then attributed about 71% of cycles
  to its exact-wire optimal candidate, including roughly 40% in the DP loop,
  14% in suffix-length minima, and 12% in four-byte prefix validation. Four
  follow-ups were rejected. Reducing the 128 valid-candidate budget to
  112/120/124 grew one to four of five repository-source frames; 126 restored
  the five wires but could remove less than 1.6% of candidate work. A four-byte
  hash chain accelerated the five files by roughly 25--34% but grew the primary
  `src/br.zig` ratio stream by one byte. Hoisting the current prefix improved
  only `1.005x` geometrically, while splitting its validation into a cheap
  fourth-byte check plus deferred three-byte verification regressed to `0.977x`.
  Finally, a bounded `u32` DP cost implementation preserved all measured wires
  and improved five 32 KiB source rows by `1.068x`, but three progressively
  stronger section/module-isolation layouts could not preserve both the target
  and short ratio controls: the fully private module left the target at
  `0.957x`. Production retains the exact 256-chain/128-candidate `usize` DP.
  A fresh Brotli ratio profile on the first 32 KiB of `src/br.zig` attributes
  about 71% of total encode cycles to that exact-wire optimal proposal (roughly
  40% core DP, 14% suffix-length minima, and 12% prefix validation), while wire
  construction is only about 6%. A five-file parameter sweep confirmed that
  reducing 128 valid candidates to 112/120/124 grows real outputs; 126 restores
  those wires but can save less than 1.6% of candidate work. A four-byte chain
  accelerated the five files by roughly 25--34% but grew `src/br.zig` by one
  byte. Caching the current four-byte prefix preserved wires but improved only
  `1.005x`; staged fourth-byte/full-prefix validation regressed to `0.977x`.
  Reusing caller-owned optimal scratch to avoid the final token copy reached
  only `1.006x`. A Brotli-only `u32` DP improved five source rows by `1.068x`
  while embedded in the shared module, but short controls fell below `0.98x`;
  after function and module isolation, either controls still regressed or the
  target itself fell to `0.957x`. All implementations were removed rather than
  weakening ratio output or the established non-target floor.
  Sharing one prebuilt three-byte predecessor graph between the ratio lazy and
  optimal candidates was also rejected. An exact token/stat oracle covered
  random, structured, and repetitive inputs, three parser configurations, and
  lengths 31, 1,024, 4,096, 32,768, and 32,769; it also exposed that the
  existing small lazy parser intentionally uses 4,096 hash buckets while the
  optimal parser normally uses 32,768. The shared 4,096-bucket implementation
  kept the primary 32 KiB `src/br.zig` wire at 6,307 bytes and passed the
  complete eight-row encode gate, but fifteen alternating fixed-CPU-2 pairs of
  30 encodes measured 244.194 ms for the existing path versus 245.169 ms for
  the shared path (`0.9961x`). The read-only generic chain and shared-scratch
  plumbing erased the avoided index build, so all production and experimental
  code was removed.
  An optimal-first ratio shortcut was rejected after exact-wire corpus probing.
  Across 101 generated 4--32 KiB random, periodic, quarter-copy, sparse-copy,
  and structured cases, the lazy wire beat the optimal proposal 61 times. Even
  overwhelmingly compressed proposals were unsafe: valid counterexamples
  measured 78 versus 40 bytes and 44 versus 40 bytes. Appending such a local
  counterexample to an independently repetitive body can drive its whole-input
  ratio arbitrarily low, so no output/input percentage alone proves that lazy
  arbitration is dominated. The temporary probe and candidate split were
  removed.
  Simplifying optimal length-prefix tie selection from a redundant compound
  comparison to `cost <= best_cost` was semantically exact: lengths are visited
  in strictly increasing order, and the existing randomized prefix oracle plus
  full token oracle remained exact. In an address-matched, noinline micro-layout
  it improved the 32 KiB source ratio row by about `1.073x`; 500-iteration
  control medians were geometrically `1.0017x` with a `0.9977x` floor. It was
  nevertheless rejected in production form. Against the real preceding HEAD,
  the smallest noinline implementation improved the target by about `1.178x`
  but consistently reduced the JSON/source controls to roughly `0.93x`, because
  moving the helper out of the approximately 25 KiB inlined ratio function
  changed the surrounding code layout. Dedicated-section and 64-byte alignment
  variants confirmed the same confounder and were removed. A future retry must
  isolate the entire optimal-range dispatcher without changing short-input
  code placement.
  That full-dispatch isolation was then audited and rejected too. A retained
  test-only `.original` instance proved byte-exact output across below-range,
  4 KiB, 32 KiB, 64 KiB, and above-range source inputs. Splitting ordinary and
  optimal instances let the equivalent `cost <= best_cost` loop improve the
  32 KiB source row by `1.1006x` with 15/15 wins in an address-matched A/B.
  However, every production routing shape added a fixed cost to short ratio
  calls: separate ordinary/optimal instances, an ordinary inline plus optimal
  noinline hybrid, and a final unlikely-branch dispatcher all preserved wires
  but regressed the 38-byte incompressible control in repeated high-iteration
  real-HEAD comparisons. The final 200-encode pairs were all slower, ranging
  from roughly `0.90x` to `0.97x`, despite ordinary JSON/source rows returning
  near neutral. The dispatcher, specialized LZ77 API, and oracle were removed;
  future work must optimize or cold-layout the existing dynamic branch without
  adding a new call/branch to every ratio invocation.
  A fresh fixed-CPU profile of the 1 MiB libbrotli quality-8 clustered decoder
  put about 31% of cycles in the high-tree payload loop, 18.5% in distance
  decode, 10.6% in copy/dictionary materialization, and 9.2% in generic bit
  reads. The command distribution contains 11,928 zero-extra commands out of
  16,818 total (70.9%), but a high-tree-only direct-length fast path improved
  the isolated target only `1.021x` and the complete 13-row run only `1.002x`.
  Forcing the full distance helper inline likewise reached only `1.005x`;
  narrowing the two decoded lengths from `usize` to RFC-bounded `u32` reached
  only `1.003x`. All three decoder candidates were removed. Distance profiling
  also shows 14,527/16,818 commands use regular distance codes, dominated by
  9--15 extra bits, confirming that future gains need a different bit-reader
  strategy rather than more small branches around the existing helper.
  The high-tree payload decoder now uses a dedicated 64-bit Brotli reservoir
  modeled on the local upstream decoder's 7/6/4-byte refill policy. Header
  parsing remains on the compact scalar reader; only a fully parsed high-tree
  payload switches readers, and the logical bit cursor is synchronized back on
  both success and error. Unlike the previously rejected generic buffered-reader
  substitution, the dedicated reader makes staged-bit availability authoritative
  after refill and advances lookup hits without repeating whole-stream bounds
  calculations. Random mixed-width tests cover all starting bit alignments,
  exact bit-length truncation, and 1--24-bit short tails. Direct Huffman oracles
  cover eight-bit literal lookups, nine-bit command/distance lookups, ten-bit
  fallback codes, non-byte-aligned starts, and truncated symbols. Twenty
  alternating fixed-CPU-2 ReleaseFast pairs against the clean parent improve the
  1 MiB `clustered_q8` median by `1.0461x` with 20/20 wins and identical
  checksums. Across all 13 reference rows, every non-target median remains at
  or above `0.9948x`; the format/size/checksum fields are unchanged. The formal
  libbrotli 1.1.0 gate remains green, and the upstream differential now includes
  64 systematically truncated high-tree prefixes in addition to its 100 format
  cases, 7,056 broad one-shot cases, 7,056 progressive cases, and 1,401 chunk
  matrix runs.
  Directly indexing `literal_trees[tree_index]` inside that prepared high-tree
  loop was then rejected. The precondition is valid and a boundary oracle
  covered the first/last inline tree plus an out-of-range context index. Twenty
  fixed-CPU-2 focused pairs improved `clustered_q8` by `1.0198x` with 20/20
  wins and identical checksums, but the complete 13-row matrix exposed stable
  code-layout regressions in non-target text/structured/structured-q4 rows
  around `0.979x`--`0.982x`. The generic lookup call and its packed-tree
  fallback therefore remain in production.
  Forcing the dedicated reader's checked `readBits` wrapper inline was rejected
  independently. It improved `clustered_q8` by `1.0167x` with 15/15 wins, but
  expanded the high-tree loop enough to regress ordinary text, structured, and
  repetitive rows to roughly `0.978x`--`0.982x`. The smaller out-of-line checked
  reader retains better whole-decoder code layout.
  Forcing only `fast_bit_reader.Reader.peekBitsPadded` inline was rejected too.
  It improved `clustered_q8` by `1.0277x` with 15/15 wins, but the complete
  13-row matrix put structured and structured-q4 controls near
  `0.977x`--`0.979x`. Keeping refill/peek out of line is therefore the better
  whole-decoder tradeoff despite its visible profile entry.
  Marking the common inline-literal-tree branch as likely was rejected as well.
  It improved `clustered_q8` by `1.0195x` with 15/15 wins, but structured
  control decode fell to `0.9862x`; production keeps the compiler's existing
  branch layout.
  Mirroring upstream's cold hint for non-zero insert-length extra bits was
  neutral here: twenty focused pairs reached only `1.0025x` with 11/20 wins,
  so the hint was removed without spending a full-matrix run.
  The packed-literal-tree expansion and cache path is now isolated behind a
  `noinline` helper. The public lookup still validates every index and returns
  inline trees exactly as before; only indexes 64...255 enter the cold helper.
  A direct oracle pins the last inline tree, first packed tree, repeated packed
  cache hits, and out-of-range rejection. Twenty fixed-CPU-2 complete-matrix
  pairs improve `clustered_q8` by `1.0131x` with 20/20 wins and identical
  checksums; every non-target median remains at or above `0.9949x`. The formal
  13-row libbrotli gate and the 100-case / 7,056-one-shot / 7,056-progressive /
  1,401-chunk-run upstream differential remain green, including all 64 high-tree
  truncation probes.
  Mirroring upstream's precomputed regular-distance offsets was rejected after
  three layouts. A full per-header table improved `clustered_q8` by about
  `1.0167x` but regressed ordinary text/structured rows to `0.9620x`/`0.9726x`;
  a static four-NPOSTFIX table and a compact 48-base table still moved the ELF
  text segment and left ordinary rows around 2% slower, while the target gained
  only about `1.009x`. An exhaustive temporary oracle covered every NPOSTFIX,
  NDIRECT, regular symbol, and maximum extra-bit value. The tables and hot-path
  changes were removed; future distance work must preserve the established text
  layout or win enough to offset it.
  Short-distance resolution now writes its scalar result through a caller-owned
  pointer while retaining the existing 16-way switch and exact invalid-match /
  overflow errors. This avoids the generated 16-byte error-union copy that held
  about 70% of the helper's sampled cycles; the helper shrinks from 652 to 409
  bytes and its thin wrapper disappears into all three callers. Twenty
  fixed-CPU-2 complete-matrix pairs preserve every checksum, improve the
  1 MiB `clustered_q8` row by `1.0236x` with 20/20 wins, and improve the
  row-median geometric mean by `1.0103x`. Every non-tiny row is at or above
  `1.0019x`; the intrinsically noisy 12-byte row is neutral at `0.9992x`.
  Brotli summaries now expose LZ77 copy counts/bytes, the non-overlapping
  subset, and its at-most-16-byte subset without instrumenting the production
  decoder. The reference CSV and gate lock these dimensions for `clustered_q8`:
  the current frame has 12,563 LZ77 copies covering 1,001,486 bytes, including
  12,539 non-overlapping copies and 10,533 short non-overlapping copies covering
  73,221 bytes. A fixed-width 1...16-byte copy helper was then rejected despite
  exhaustive length/distance equivalence tests: twenty fixed-CPU-2 focused pairs
  fell to about `0.920x` with 0/20 wins. Production retains compiler-rt `memcpy`;
  future work should target the longer-copy bulk or surrounding dispatch cost.
  An x86-64 ERMS `rep movsb` follow-up for non-overlapping copies was also
  rejected. Thresholds of 256 and 512 bytes were consistently about `0.996x`
  on the focused row; 1,024 bytes was near neutral with high run noise. The
  compiler-rt vector loop therefore remains preferable for this workload.
  Inlining compiler-rt's own exact less-than-16-byte strategy was neutral too:
  twenty focused pairs split evenly around `1.000x`. This confirms that the
  current short-copy cost is not its standalone memcpy call, so the experiment
  and exhaustive temporary boundary test were removed.
  The high-tree literal loop now loads the two context bytes once per insert run
  and advances them in registers as literals are emitted, matching upstream's
  stateful context shape without changing block-switch or tree-selection rules.
  Existing LSB6/MSB6/UTF-8/signed context tests and the full upstream matrix pin
  behavior across context modes. Twenty fixed-CPU-2 complete-matrix pairs keep
  every checksum, improve `clustered_q8` by `1.0104x` with 20/20 wins, and
  improve the row-median geometric mean by `1.0044x`; every non-target median
  remains at or above `0.9942x`.
  Hoisting literal block state and context-map selection once per block-local
  insert chunk was rejected. It preserved the context-mode tests but added an
  outer chunk loop to predominantly short insert runs; twelve fixed-CPU-2 pairs
  all lost on `clustered_q8`, with a median near `0.987x`. The simpler per-byte
  block-boundary check remains faster.
  Summary instrumentation now also accounts decoded literal bytes by all four
  RFC context modes, and the reference gate checks that literal, LZ77, and
  static-dictionary bytes exactly cover each compressed benchmark payload. The
  locked `clustered_q8` stream has 16,741 literal bytes, all in UTF-8 mode. The
  high-tree decoder therefore preflights whether every declared literal block
  uses UTF-8 mode and, when true, bypasses the per-literal four-way mode switch
  while retaining the same two lookup tables. An exhaustive 65,536-byte-pair
  oracle pins the specialized context value against the generic implementation,
  and a classifier test covers homogeneous and mixed modes. Twenty fixed-CPU-2
  same-layout full-matrix pairs preserve all checksums, improve `clustered_q8`
  by `1.0138x` with 20/20 wins, and improve the row-median geometric mean by
  `1.0040x`; every non-target median remains at or above `0.9975x`.
  A compile-time UTF-8 dispatch was rejected: specializing a third copy of the
  roughly 1.5 KiB high-tree payload loop removed the per-literal mode branch but
  reduced `clustered_q8` to about `0.939x` in twelve same-layout pairs (0/12
  wins). The smaller single-loop runtime dispatch remains the better I-cache
  tradeoff.
  Caching the current literal block type and 64-entry context-map slice inside
  that single loop was rejected too. The existing per-byte block-switch check
  already optimizes well; twenty fixed-CPU-2 focused pairs measured about
  `0.996x` with only 1/20 wins, so the extra live state was removed.
  Building complex inline literal Huffman tables directly into their final
  header slots was rejected despite a real header-only gain. A caller-owned
  `initSparseTrustedInto` prototype preserved dense/sparse table oracles and
  improved twenty clustered header pairs by roughly 5--8%, but twenty complete
  decode-matrix pairs left `clustered_q8` neutral at `0.9987x` and regressed
  structured q4/q11 to `0.9626x`/`0.9388x`. The temporary shared API and
  Brotli routing were removed rather than optimizing a proxy stage at the cost
  of end-to-end decode.
  Returning embedded dictionary bytes directly for identity transforms was
  rejected as well. It removed one short scratch-to-output copy for transform
  zero and passed representative addresses across all word lengths, but twenty
  fixed-CPU-2 `clustered_q8` pairs fell to about `0.990x` with 0/20 wins. The
  extra transform branch/aliasing cost outweighed the avoided copy, so the
  decoder retains one uniform scratch contract for all 121 transforms.
  Writing high-tree static-dictionary transforms directly into the final output
  when at least 64 bytes remained was rejected too. Although it removed the
  subsequent 5--37-byte copy, twenty fixed-CPU-2 focused pairs measured about
  `0.984x` with 0/20 wins; growing the hot payload branch cost more than the
  tiny avoided copy. The stack scratch path remains unchanged.
  A Zstd `LiteralOnlySection` caller-owned return prototype was rejected after
  the `numbered_json` profile attributed roughly 31% of cycles to its 1,152-byte
  return copy. The copy disappeared and twenty five-row profile pairs improved
  geometrically by `1.0034x`, but the 5,161-sequence `huffman80k` control fell
  to `0.9790x` with 0/20 wins while `numbered_json` gained only `1.0076x`.
  The experiment was removed: a future ownership redesign must isolate the FSE
  execution layout instead of shifting every downstream hot function.
  Zstd sequence-table parsing now builds each compressed FSE table directly in
  `parseSequenceModeSpec`'s final local storage. This removes the three possible
  4 KiB builder-return copies while preserving the existing full-spec return and
  sequence-execution layout. A dirty-destination regression compares every
  reachable entry from two independently initialized caller-owned tables for the
  fixed libzstd `numbered_json` offset-FSE frame. Thirty alternating fixed-CPU-8
  five-row ReleaseFast pairs improve median decode time by `1.0301x` for
  `numbered_json`, `1.0083x` for `huffman80k`, `1.0115x` for 512 KiB JSON, and
  `1.0091x` for mixed binary; the zero-sequence ASCII control is neutral at
  `0.9988x`, for a `1.0139x` row-median geometric mean. A separate twenty-pair,
  100,000-decode run confirms `numbered_json` at `1.0251x` and `huffman80k` at
  `1.0079x`. Broader variants that also returned the whole 12 KiB mode spec
  through caller storage or made the generic cursor borrow its tables were
  rejected: despite roughly `1.36x` target gains, they regressed the 5,161-
  sequence `huffman80k` row to `0.944x`--`0.965x`. A dedicated mode-`0x20`
  execution branch was rejected too because unrelated `huffman80k` and mixed-
  binary rows fell to about `0.978x` and `0.991x`.
  Extending the existing linear FSE-table builder from 256/512-state tables to
  the 32/64/128-state tiers was also rejected. Exact table oracles covered all
  added widths and the first twenty-pair matrix looked mildly positive, but the
  longer fixed-CPU rerun was neutral: `numbered_json` had only 10/20 wins with
  a `1.0019x` median (`0.9974x` geometric mean), while `huffman80k` had 6/20
  wins at `0.9984x`. The compact sorted constructor remains preferable for
  small tables; the linear implementation stays limited to 256/512 states.
  Removing the apparently redundant by-value `SequenceModeSpec` argument from
  the two existing large-sequence helpers was rejected after inspecting the
  generated `0x3060`-byte entry copy. Although the candidate reduced both helper
  stack frames by roughly 12 KiB and improved `numbered_json`/large JSON by
  about `1.051x`/`1.026x`, twenty fixed-CPU-8 complete-matrix pairs reduced the
  5,161-sequence `huffman80k` median to `0.9095x` with only 2/20 wins. The local
  by-value copy evidently gives the long FSE loop materially better table
  locality/code generation than repeatedly reaching through the embedded
  cursor state, so the helper contract remains unchanged.
  Compacting only `SequenceModeSpec.offset_fse` from 512 entries to the
  specification's 256-state OF maximum was rejected too. The cross-block table
  state stayed full-width and conversions were bounded to Repeat_Mode restore
  and continuation commit, but twenty fixed-CPU-8 complete-matrix pairs still
  put the all-FSE `huffman80k` row at `0.9749x` with 0/20 wins. The target
  `numbered_json` row improved to `1.0735x` and large JSON to `1.0407x`, but
  those gains do not justify a stable regression in the main sequence-heavy
  control; the uniform decode-table layout remains.
  Shrinking `decodeFseTable`'s normalized-count scratch from 256 entries to the
  53-symbol maximum of sequence alphabets was rejected despite preserving all
  downstream hot-function addresses and sizes. The helper's stack frame fell by
  400 bytes, but thirty fixed-CPU-8 complete-matrix pairs improved the row-
  median geometric mean by only `1.0012x`; a longer 100,000-decode target run
  put `numbered_json` at `0.9956x` with only 7/20 wins. The generic scratch stays
  in place because the change is below the retention threshold.
  Extending `resolveSequenceModeSpec`'s early return from all-predefined tables
  to every mode tuple without Repeat_Mode was rejected. The shortcut is
  semantically valid and a direct mixed-mode test preserved the missing-prior-
  table error for Repeat_Mode, but it grew the inlined decode body by 48 bytes.
  Thirty fixed-CPU-8 complete-matrix pairs left `numbered_json` at only
  `1.0055x` and reduced `binary_mixed` to `0.9887x` with 5/30 wins. The narrower
  all-predefined early return retains the better overall layout.
  Extending unchecked FSE state lookup from the two specialized large-sequence
  loops into the generic sequence dispatcher was rejected. Initial states and
  transitions are already range-proven, but removing the three cold checks
  shortened the inlined decode body by 80 bytes and shifted downstream helpers.
  Thirty fixed-CPU-8 complete-matrix pairs put `huffman80k` at `0.9920x` with
  only 4/30 wins and left `numbered_json` neutral at `0.9992x`; the checked
  generic path remains the better measured layout.
  The compact FSE builder now replaces per-symbol stable sorting with a 32-bit
  state mask for tableLog-5 tables. Spread positions are unique, so clearing
  the least-significant set bit enumerates the exact ascending order without a
  general sort; 64/128-state tables retain the original sorted construction and
  256/512-state tables retain the established linear builder. A deterministic
  oracle compares 3,328 valid randomized 32-state distributions entry-for-entry
  against the independent linear implementation. Thirty alternating fixed-CPU-8
  complete-matrix pairs improve `numbered_json` by a median `1.0206x` with
  21/30 wins; `huffman80k`, 512 KiB JSON, mixed binary, and the zero-sequence
  ASCII control remain neutral to positive at their medians. Twenty longer
  target pairs confirm `numbered_json` at `1.0263x` with 17/20 wins, while the
  `huffman80k` control remains neutral at `0.9996x`. A fixed-counter run also
  reduces target instructions by about 2.0% and cycles by about 1.5%.
  Replacing only the all-FSE/Huffman helper's embedded-table cursor with the
  small streaming cursor was rejected as well. The helper still received its
  by-value local table copy, but changing cursor field offsets and caller layout
  reduced `huffman80k` to `0.9460x` and the unchanged FSE/FSE/RLE
  `binary_mixed` row to `0.9301x`, both with 0/30 wins. The specialized helpers
  therefore keep the established full `SequenceDecodeState` layout.
  Keeping that layout but delaying its embedded-spec assignment until after the
  two specialized sequence branches was rejected too. The specialized helpers
  retained their original local table copy and stack layout, yet the changed
  caller grew by 208 bytes and thirty fixed-CPU-8 complete-matrix pairs reduced
  `huffman80k` to `0.9748x`, `binary_mixed` to `0.9888x`, and `numbered_json`
  to `0.9884x`. Eager cursor construction remains.
  Skipping the otherwise unused Huffman-tree state commit on a terminal block
  was rejected. A retention-aware parser preserved multi-block treeless reuse
  and left the inlined `decodeFrameInto` size unchanged, but thirty fixed-CPU-8
  complete-matrix pairs reduced `huffman80k` to `0.9208x` and `binary_mixed` to
  `0.9426x`, both with 0/30 wins; the additional parser entry disturbed the
  surrounding hot layout more than the roughly 1 KiB saved copy.
  Moving the complete compressed-block decoder behind a `noinline` boundary
  was not worthwhile by itself. It reduced the caller's generated body from
  roughly 14.6 KiB to 2 KiB and improved 512 KiB JSON by `1.0203x`, but thirty
  fixed-CPU-8 complete-matrix pairs left `numbered_json` at `0.9939x` and the
  row-median geometric mean at only `1.0018x`. The standalone boundary was
  removed; it remains useful only as a controlled isolation mechanism for a
  future tree-builder experiment with a substantially larger local gain.
  Combining that full compressed-block isolation with the previously rejected
  rank-count/rank-start Huffman decoder was measured under matched 4 KiB-aligned
  dispatcher and sequence-helper sections. Against an equivalently isolated
  baseline, thirty fixed-CPU-8 pairs improved `numbered_json` by `1.4898x`,
  `ascii64k` by `1.0340x`, and 512 KiB JSON by `1.0269x`, while `huffman80k`
  and mixed binary stayed slightly positive. However, the actual production
  combination versus unisolated `HEAD` still reduced `huffman80k` to `0.8976x`
  and mixed binary to `0.9379x`; the section placement cost dominates those raw-
  literal sequence kernels. The prototype and isolation remain rejected until
  the decoder can be partitioned without changing their cache placement.
  Zstd level-1 large-block arbitration now screens the legacy single-duplicate
  fallback with a conservative Huffman lower bound before rebuilding a complete
  literal tree for every indexed match candidate. When the remaining low-byte
  literals need at least as many one-bit code bytes as the current winner, the
  one-sequence candidate cannot win even before its omitted headers and sequence
  bits. Inputs containing high bytes retain the exact former path because their
  indexed score has a deliberately conservative raw-literal shortcut. A
  64-shape, 8--32 KiB low/mixed/high-entropy oracle compares the production
  selector with the forced complete search byte-for-byte, and a separate score
  oracle checks competitive indexed winners. In a same-binary, alternating
  fixed-CPU-8 30-pair matrix, all 20 case/level rows retained their output sizes
  and checksums; level-1 JSON improved by a median `1.1548x` with 29/30 wins,
  while the weakest non-target row was `0.9964x`. The final ReleaseFast gate
  keeps its 640-byte JSON frame; an isolated fixed-CPU production run reported
  about 24.0 MiB/s versus the prior 20.6 MiB/s baseline. All 20 encode rows,
  91 stage rows, and 273 bidirectional libzstd 1.5.5 cases pass.
  The lower-bound scan now derives the minimum match length needed to beat the
  current winner and stops once later source positions cannot reach it. It
  returns to exact scoring as soon as any predecessor can meet that threshold,
  while high-byte inputs retain the existing conservative fallback. Sixteen
  generated 8 KiB blocks compare the threshold result against the previous
  full maximum-match scan across eight winner limits, and the existing 64-case
  selector oracle remains byte-exact against disabling the bound entirely. A
  same-binary 30-pair 20-row matrix preserves every size/checksum and improves
  level-1 JSON by `1.0773x` with 30/30 wins; non-level-1 rows remain within
  about 0.7% noise.
  Deferring the complete level-1 duplicate index behind a smaller exact-key
  threshold prefilter was rejected. The prefilter retained the bounded index's
  sampled candidates and conservatively fell back on high-byte, capacity,
  or uncertain cases; its oracle proved every prefilter prune was also pruned
  by the complete indexed scan. A production profile removed the former
  `DuplicateMatchIndex.buildBounded` entry (about 12% of sampled cycles), but
  the prefilter plus long-match extension consumed about 14% instead. A
  same-binary 30-pair 20-row matrix preserved every wire/checksum but reduced
  level-1 JSON to `0.9898x` with only 4/30 wins, so eager bounded construction
  remains.
  Expanding repeat-beam's indexed collision guard from its existing fourth-byte
  check to a complete four-byte prefix was rejected. The minimum-three path
  retained the old guard, a mismatch-position oracle covered all four prefix
  bytes, and thirty fixed-CPU-8 primary-stage pairs preserved every counter and
  wire. Text/JSON were neutral at about `0.9994x`, while binary consistently
  fell to `0.9886x` with 0/30 wins: the 4,096-bucket four-byte hash already
  correlates the other prefix bytes, so the wider load did not pay for itself.
  Pruning repeat-beam's second indexed transition when it targeted the same
  `(position, rep0, token)` at an equal-or-higher modeled cost was rejected. A
  16-shape, minimum-match-3/4 oracle showed byte-identical tokens and statistics.
  A runtime-switch 30-pair stage matrix appeared positive (`1.031x` text,
  `1.021x` JSON, `1.015x` binary), but independent final binaries exposed the
  code-layout cost: the best of three cost-comparison formulations reduced JSON
  to `0.987x` with 0/30 wins, while earlier forms fell to about `0.960x`. The
  original duplicate update remains faster once benchmark branching is removed.
  Automatic native-frame arbitration now bounds the delayed raw/RLE shape scan
  by the already-materialized compressed-frame length. Before the first
  qualifying 12-byte run, every consumed byte is irrevocably raw; once the
  frame header, checksum trailer, one raw-block header, and that prefix exceed
  the compressed candidate, the raw/RLE contender cannot win and scanning stops.
  Equal lengths still complete exact inspection and preserve raw-on-equal ties.
  A 24-shape oracle covering random, structured, narrow-alphabet, mixed, RLE,
  four block boundaries, checksum on/off, and nine winner limits verifies that
  every early exit corresponds to a strictly larger exact raw/RLE frame. Thirty
  alternating fixed-CPU-8 pairs against an independent `HEAD` binary preserve
  all 20 frame sizes/checksums and improve text by `4.62x`, level-1 JSON/binary/
  tradeoff/multiblock by `1.029x`/`1.042x`/`1.102x`/`1.019x`; every row median
  is positive.
  Reusing repeat-beam's existing four-byte predecessor chain to replace level
  one's separate single-match index was rejected. A generated oracle proved its
  negative result conservatively implied the complete eight-byte index bound,
  but walking full collision chains and validating long matches cost more than
  the 1.3 MiB bounded-index write it removed: a same-binary 100-encode JSON
  sample fell to `0.743x`. The prototype was stopped before a full matrix.
  Splitting repeat-beam index construction into a branch-free four-byte-anchor
  body plus a three-slot sentinel tail was rejected as compiler-neutral. The
  existing compact-index/reference oracle remained exact, but thirty independent
  `HEAD` stage pairs measured text/JSON/binary at `0.995x`/`0.999x`/`1.000x`.
  LLVM already makes the optional tail check effectively free in this loop.
  Switching only repeat-beam's 4-byte hash from Vort's current middle product
  bits to upstream zstd's high-product-bit formula was rejected. All locked
  stage counters and wires stayed equal, but thirty independent `HEAD` pairs
  measured text/JSON/binary at `0.976x`/`0.994x`/`1.004x`; the upstream hash's
  small binary gain did not offset regressions on narrow structured inputs.
  Packing four lazy match-length validity bits into each duplicate predecessor
  count was rejected. It removed per-candidate sentinel writes without growing
  `DuplicateMatchIndex`, and the bounded/full index oracle preserved all
  predecessors and selected matches. Binary index construction improved
  `1.033x`, but text/JSON builds fell to `0.994x`/`0.993x`; more importantly,
  thirty independent stage pairs reduced actual text/JSON/binary single-match
  evaluation to `0.985x`/`0.980x`/`0.963x`. The simple u16 sentinel stays.
  Moving `max_byte_frequency` from the duplicate-index input loop to a final
  256-counter reduction was rejected despite improving isolated bounded-index
  construction by `1.076x`/`1.053x`/`1.030x` on text/JSON/binary. The actual
  single-match stage was mixed, and thirty independent full-matrix pairs reached
  only `1.0015x` geometrically: level-1 JSON was `1.0039x`, while text and the
  tradeoff corpus fell to `0.9908x`/`0.9979x`. The incremental maximum remains.
  The duplicate index now stores positions with non-empty predecessor buckets
  as one dense ascending array instead of writing a reverse-linked next-position
  entry for every source byte. Suffix queries binary-search their first legal
  position and then read the dense list sequentially, preserving candidate order
  and all match-score ties without increasing `DuplicateMatchIndex`. A 16-shape
  oracle independently reconstructs the dense list, checks lower-bound starts,
  compares full/bounded fields, and preserves selected matches at four suffixes.
  Thirty independent fixed-CPU-8 stage pairs improve bounded-index construction
  by `1.027x`/`1.011x`/`1.026x` on text/JSON/binary. The corresponding 30-pair
  20-row frame matrix preserves every size/checksum, improves level-1 JSON by
  `1.0138x` with 26/30 wins, has a `1.0012x` row-median geometric mean, and
  keeps the weakest control at `0.9956x`.
  The same index now stores each sampled predecessor and lazy match length in
  that dense row, replacing its sparse four-wide per-position tables. This also
  makes the established pair-sampling policy explicit instead of depending on
  a narrow inferred integer in the former packed state: each hash's first
  occurrence is retained, its second emits one row, and the process repeats. A
  16-shape oracle independently reconstructs every pair and keeps full/bounded
  queries equal; a 64-frame public-API audit is byte-identical to the prior
  implementation. `DuplicateMatchIndex` falls from about 1.32 MiB to less than
  384 KiB. Thirty fixed-CPU-8 stage pairs improve index construction by
  `1.428x`/`1.413x`/`1.347x` and single-match evaluation by `1.005x`/`1.049x`/
  `1.080x` on text/JSON/binary. A 30-pair 20-row independent-binary matrix
  preserves every size/checksum, improves level-1 JSON by `1.037x` with 29/30
  wins, and reaches a `1.0182x` row-median geometric mean with the weakest row
  at `0.9962x`. A true
  four-deep repair was not selected as the default: it improved 7/64 generated
  level-1 frames by only nine bytes total but reduced JSON level 1 to `0.892x`
  and levels 3/9/22 to about `0.629x`/`0.628x`/`0.627x`.
  A second attempt to defer level-1's duplicate index used a fixed-length
  64-bit rolling fingerprint rather than extending matches. Equal windows must
  share a fingerprint, while hash collisions, high bytes, and table saturation
  conservatively fell back to the indexed scorer; a generated oracle confirmed
  every negative proof against the complete scan. Even so, a same-binary
  100-encode JSON sample measured only `0.9756x`. Maintaining the rolling hash
  and open-addressed table still cost more than eager bounded-index construction.
  Replacing repeat-beam's one-element `matchesAt` output with a dedicated
  optional-return `firstMatchAt` helper was also rejected. A per-position oracle
  matched the old result, but thirty independent stage pairs reduced text/JSON/
  binary to `0.960x`/`0.941x`/`0.977x`; the generic slice/count form produces
  substantially better optimized code on the current compiler.
  Four-way striped byte-frequency collection inside `DuplicateMatchIndex` was
  rejected too. It preserved the full/bounded index oracle and improved isolated
  text/JSON index construction by only `1.007x`/`1.005x`, while binary fell to
  `0.993x`; actual JSON/binary single-match stages measured `0.991x`/`0.994x`.
  The extra four-lane merge and stack footprint outweigh the shorter dependency
  chains at this scale.
  Expanding repeat-beam's fixed two-state loop into separate slot-zero and
  optional slot-one calls was rejected. A 16-shape token/statistics oracle and
  same-binary stage pairs were positive (`1.014x` text, `1.020x` JSON, `1.031x`
  binary), but an independent-binary 30-pair 20-row matrix reached only
  `0.9995x` geometrically, improved level-1 JSON by just `1.0024x`, and reduced
  multiblock level 22 to `0.9798x`. The compact dynamic slice loop remains.
  Splitting repeat-beam's checked one-candidate lookup into a separate unchecked
  hot-loop helper was rejected. A per-position oracle preserved every returned
  match, but thirty independent primary-stage pairs reduced text/JSON/binary to
  `0.984x`/`0.952x`/`0.986x`; the extra helper boundary outweighed eliminating
  two already-predictable range checks.
  Caching each repeat-beam predecessor's complete four-byte hash key alongside
  its compact `u16` link was rejected. It avoided reloading candidate prefix
  bytes after hash collisions and preserved all locked stage outputs, but doubled
  predecessor-entry traffic; thirty independent stage pairs reduced text/JSON/
  binary to `0.953x`/`0.985x`/`0.967x`. The compact link-only index remains.
  Compacting the repeat-aware beam state was rejected after testing both natural
  layouts. Removing its reconstructible `Token` reduced the state from 16 to 12
  bytes and improved the isolated level-1 JSON beam by `1.026x` with 29/30 wins,
  but a 30-pair 20-row end-to-end matrix regressed the level-1/3 tradeoff corpus
  by about `1.4%`/`1.1%`. Packing the 1--258-byte backtrack length and prior
  two-state slot into one `u16` reduced each state to eight bytes, but the same
  isolated beam fell to `0.962x` with only 1/30 wins. The original 16-byte state
  remains; its power-of-two stride is evidently preferable to the saved traffic
  on the current x86-64 code generation.
  Level-1 duplicate arbitration now builds only the bounded pair-sampled
  predecessor rows consumed by its single-match search and Huffman lower bound.
  The full per-position hash chain is reserved for budgets that can enter mixed
  lookahead; writing it and clearing its 64 KiB latest-position table was dead
  work at level 1. A 16-shape oracle compares every bounded candidate position,
  predecessor, lazy-length field, and selected match against the full builder.
  The stage tool
  now receives the candidate's actual search budget so its `duplicate_index` row
  mirrors this production choice. Thirty alternating fixed-CPU-8 stage pairs
  improve index construction by a median `1.259x` with 30/30 wins. A same-binary
  30-pair 20-row frame matrix preserves every size/checksum, improves level-1
  JSON by `1.0267x` with 26/30 wins, and keeps the other nineteen medians within
  about 0.35% of control.
  Fusing repeat-beam's complete predecessor-index build into its forward DP was
  rejected. Because the DP visits positions monotonically, an online insert/
  lookup produced identical matches at every position across sixteen 32 KiB
  structured/copied inputs and all repeat-beam tests retained exact tokens.
  Nevertheless, thirty fixed-CPU-8 isolated JSON stage pairs measured only
  `0.9991x` with 13/30 wins; interleaving hash-table mutation into the hotter DP
  loop outweighed removing the separate linear prepass. The compact offline
  index remains.
  Reusing optimal's compile-time 32 KiB fixed-distance cost table in the repeat
  beam was rejected as below threshold. It exactly replaces the scalar `log2`
  formula and improved thirty isolated JSON stage pairs by `1.0248x` with 21/30
  wins, but a same-binary 30-pair 20-row frame matrix showed only `1.0033x`
  geometric mean and `1.0022x` on the target level-1 JSON row. All wires were
  identical and the weakest control was `0.9989x`; the marginal result does not
  justify another global lookup in the beam loop.
  Hoisting the indexed match's direct-distance cost out of repeat-beam's two-
  state loop was rejected too. A focused transition oracle matched the existing
  helper for repeat and direct offsets at minimum, typical, and maximum match
  lengths, but thirty fixed-CPU-8 isolated JSON stage pairs fell to `0.9785x`
  with only 12/30 wins. The extra live value/helper path costs more than the
  duplicated small integer `log2` calculation on this target.
  Hoisting repeat-beam's per-position fixed literal cost out of its two-state
  loop was rejected as well. Although the value is identical for both active
  states and all token tests stayed exact, thirty fixed-CPU-8 isolated JSON
  stage pairs fell to `0.9863x` with only 11/30 wins. The existing inlined
  expression gives LLVM the better hot-loop schedule.
  Running the level-1 repeat beam before greedy and skipping greedy for an
  absolute 1/32 beam result was rejected on correctness/ratio evidence before
  benchmarking. A generated 512-block audit found a deterministic 26,626-byte
  low-alphabet case where the 379-byte beam satisfied the threshold but the
  existing greedy-first arbitration emitted 375 bytes. The 1/32 rule therefore
  remains valid only for skipping the more expensive optimal parser after
  greedy has established its candidate; it is not a proof that beam dominates
  every linear parser.
  Replacing repeat-beam's 8 KiB head-table sentinel clear with a 512-byte
  initialized bitmap was rejected. All eight beam tests preserved exact tokens,
  but the extra bitmap load/branch/write at every indexed position reduced the
  isolated JSON stage to `0.9822x` with only 8/30 fixed-CPU-8 wins. The simple
  contiguous head clear remains cheaper than making the hot index-build loop
  conditional.
  Repeat-beam's explicit recent-offset probe now checks its four-byte minimum
  match prefix before entering the shared 32-byte vector extension loop. The
  indexed candidate already has its own hash-chain guard; this change covers
  only the per-state rep0 fallback, and generic three-byte matching retains the
  original path. An exhaustive mismatch-position oracle through the 258-byte
  maximum proves identical accepted lengths at minimum lengths three and four,
  and all repeat-beam token tests remain exact. Thirty fixed-CPU-8 isolated JSON
  stage pairs improve by `1.0630x` with 30/30 wins. A same-binary 30-pair 20-row
  frame matrix retains every size/checksum, improves JSON by `1.0382x`/`1.0244x`/
  `1.0244x`/`1.0236x` at levels 1/3/9/22, and keeps the weakest control at
  `0.9940x`.
  Converting LL/ML values to canonical sequence codes once and sharing those
  codes across RLE, predefined, compressed, and Repeat_Mode alternatives was
  rejected. The existing value-based predefined planner already uses precomputed
  code-to-state masks; after giving the codes path the same masks, all plan
  payloads, bit costs, and per-sequence symbols matched the independent reference.
  Even so, thirty fixed-CPU-8 primary JSON beam-stage pairs fell to `0.8892x`
  with only 1/30 wins. The added shared 512-byte scratch/function shape costs
  more than the currently inlined canonical conversions.
  Compressed sequence transition planning now uses the inverse FSE compression
  table to map each `(symbol, next_state)` directly to its lowest predecessor
  state and emitted bits, replacing the per-symbol linked-state walk. The
  existing decode table still supplies the exact baseline/state width recorded
  in emitted plans. A randomized oracle spanning ten sequence lengths from 12
  through 512, 32/128-state tables, and up to 64 symbols compares initial state,
  every baseline/state width, and every transition value/width against both the
  original chain builder and an independent full-table scan for more than 250
  valid distributions. Thirty fixed-CPU-8 isolated JSON rep-beam pairs improve
  by `1.195x` with 30/30 wins. A same-binary 30-pair 20-row frame matrix keeps
  every output size/checksum and improves JSON by `1.170x`/`1.151x`/`1.159x`/
  `1.160x` at levels 1/3/9/22, binary by `1.265x`/`1.081x`/`1.081x`/`1.082x`,
  and the level-1/3 tradeoff rows by `1.252x`/`1.245x`; the weakest control is
  `0.9979x` and the row-median geometric mean is `1.0925x`.
  Zstd's repeat-aware beam now enters a fixed-parameter hot loop instead of
  repeatedly normalizing the generic LZ77 options. The specialized path keeps
  the established 32 KiB window, 128-link chain, 4--258-byte matches, one
  indexed candidate, and four-bit new-distance penalty; the generic parser
  remains available to other callers. Sixteen generated 8 KiB inputs compare
  every output token and `PlanStats` field with the generic implementation.
  Thirty independent-binary fixed-CPU-8 stage pairs improve text/JSON/binary
  by median `1.0748x`/`1.0552x`/`1.0248x`, with 30/30, 27/30, and 28/30 wins.
  The corresponding 30-pair 20-row frame matrix preserves every size/checksum,
  improves level-1 JSON by `1.1483x` with 30/30 wins, and reaches a `1.0413x`
  row-median geometric mean; the weakest row is `0.9986x`.
  Splitting that specialized loop into a match-capable body and a final three-
  byte literal tail was rejected. The direct version preserved every focused
  token, stage counter, frame size, and checksum and improved primary text/JSON/
  binary beam medians by `1.0293x`/`1.0278x`/`1.0164x`. However, thirty
  independent-binary 20-row frame pairs reduced JSON levels 1/3/9/22 to
  `0.9731x`/`0.9885x`/`0.9861x`/`0.9831x`, with a `0.9937x` row-median
  geometric mean. Moving the at-most-three-byte tail behind a cold non-inlined
  helper also reduced focused JSON/binary beam throughput to `0.9748x`/
  `0.9780x`. The single loop keeps the better complete-encoder layout.
  Replacing the specialized predecessor loop's distance/window checks with an
  upstream-style `candidate >= windowLow` comparison was rejected. The compact
  chain guarantees strictly decreasing positions, so the formulation was
  equivalent and the token/window-boundary oracles remained exact, but thirty
  independent stage pairs reduced text/JSON/binary to `0.9965x`/`0.9962x`/
  `0.9885x`. The existing distance form generates the faster loop here.
  Starting the specialized recent-offset match extension after its already
  verified four-byte prefix, as upstream zstd commonly does, was also rejected
  as neutral. An exhaustive mismatch-position oracle and the complete generic/
  specialized token oracle stayed exact, but thirty independent stage pairs
  measured text/JSON/binary at only `1.0013x`/`0.9984x`/`1.0026x`. Re-entering
  the shared vectorized matcher at byte zero retains the simpler common path.
  Removing the specialized recent-offset `rep0 <= position` check was rejected
  despite a valid reachability proof: position zero cannot probe offset one, and
  every later literal or match transition retains a non-zero offset no greater
  than its destination. Short-input and generated token oracles stayed exact,
  but thirty independent stage pairs reduced text/JSON/binary to `0.9596x`/
  `0.9442x`/`0.9551x`, with zero JSON/binary wins. The explicit state-local
  guard preserves substantially better optimized code.
  Accumulating bounded duplicate-index byte statistics and dense-row count in
  local `u16` scalars before one final object write was rejected in its direct
  form. The field-level full/bounded oracle stayed exact and thirty independent
  index-build pairs improved text/JSON/binary by about `1.40x`, all with 30/30
  wins. Actual single-match evaluation was mixed, however, and the 30-pair
  20-row frame matrix reached only `0.9973x` geometrically: JSON level 1 gained
  `1.0245x`, but binary level 1 and tradeoff levels 1/3 fell to `0.9743x` and
  about `0.988x`. The local arithmetic is worth revisiting only with downstream
  helper layout held constant.
  Isolating the complete local-accumulator builder in its own final text section
  kept the established FSE, dense-Huffman, and wide-sequence section addresses
  byte-for-byte stable. Index construction still improved `1.29x`--`1.34x`, but
  the 30-pair frame matrix remained negative at `0.9946x` geometrically, with
  binary level 1 at `0.9769x`. The direct three-scalar combination therefore
  remains rejected; narrower contributors must be measured independently.
  The retained narrow variant keeps only `candidate_position_count` in a local
  scalar while the bounded pair-sampled index is built, committing it once at
  completion. This removes a load/store dependency from every emitted dense row
  and shrinks the builder by seven bytes without adding another text section.
  The full/bounded field oracle remains exact. Thirty independent
  fixed-CPU-8 stage pairs improve index construction by `1.2005x`/`1.1943x`/
  `1.1630x` on text/JSON/binary; actual single-match evaluation stays within
  about 0.5% of neutral at each median. The corresponding 30-pair 20-row frame
  matrix preserves every size/checksum, improves level-1 JSON by `1.0250x` with
  27/30 wins and binary level 1 by `1.0038x`, reaches a `1.0009x` row-median
  geometric mean, and keeps the weakest control at `0.9952x`.
  Packing each small-Huffman lookup entry as one native-width `(code, bit
  count)` word, following upstream zstd's `HUF_CElt` principle, was rejected.
  The independent plan-backed reference retained byte-identical streams and the
  hot loop used one indexed table load instead of two while keeping the same
  machine-code size. Nevertheless, thirty independent 20-row frame pairs
  reduced binary level 1 to `0.9848x` and reached only `0.9972x` by row-median
  geometric mean. Separate compact width and native-width code tables remain.
  The retained small-Huffman stream loop instead batches four reverse-order
  symbols on 64-bit targets while preserving those separate lookup tables. Its
  maximum live payload is statically bounded to seven residual bits plus four
  11-bit codes (51 bits); 32-bit targets use the analogous safe two-symbol
  batch. The independent scalar writer now covers input lengths modulo four,
  the maximum 11-bit width, invalid symbols, and allocation rollback. Thirty
  independent fixed-CPU-8 frame pairs against the scalar loop preserve every
  size/checksum and improve binary levels 1/3/9/22 by `1.0401x`/`1.0134x`/
  `1.0144x`/`1.0096x`; the row-median geometric mean is `1.0078x` and the
  weakest row is `0.9940x`. A two-symbol precursor reached only `1.0027x`
  geometrically. A direct 30-pair four-versus-two-symbol matrix confirms the
  four-symbol loop adds another `1.0075x` geometrically and `1.0324x` on binary
  level 1 with 30/30 wins, while its weakest row remains `0.9988x`.
  Starting double-fast match extension after its already verified prefix was
  rejected after splitting the two consumers. Applying it to both 4/8-byte hash
  candidates and 4-byte recent offsets improved JSON stage throughput but
  reduced text/binary to about `0.991x`. Restricting it to recent offsets alone
  improved focused JSON/text by `1.0217x`/`1.0067x`, with binary at `0.9968x`,
  but the 30-pair frame matrix reached only `1.0007x` geometrically and reduced
  binary level 1 to `0.9942x`. The existing full extension remains. A new
  mismatch-position oracle covers complete 4/8-byte helper results, and the
  Zstd test root now explicitly includes the double-fast module so its tests
  are executed rather than merely compiled.
  Caching the first complete recent-offset match when it reached the exact
  258-byte limit was rejected too. Reusing that `Match` avoids immediately
  rescanning the same position and distance on long runs, and an old-control-
  flow oracle retained every token and statistic. But the extra live aggregate
  perturbed the ordinary loop: thirty independent stage pairs reduced binary
  to `0.9713x` with 0/30 wins and left JSON at `0.9974x`. The uncommon maximum-
  length continuation keeps its duplicate scan.
  Expanding the retained 64-bit Huffman batch from four to the maximum safe five
  11-bit symbols was rejected. The 62-bit accumulator bound and scalar oracle
  remained exact, but thirty independent four-versus-five-symbol frame pairs
  reached only `0.9979x` geometrically; binary levels were `0.9943x`--`0.9981x`
  and multiblock level 22 fell to `0.9874x`. Four symbols remain the measured
  code-size/throughput optimum for the single-accumulator loop.
  Adding the shared matcher's 32-byte vector front end to double-fast's private
  match extender was rejected at the focused gate. The exhaustive mismatch
  oracle remained exact, but LLVM outlined the formerly inlined helper; thirty
  independent stage pairs improved JSON by `1.0159x` while reducing binary to
  `0.9924x`. The full-width variant was removed before an end-to-end matrix.
  A 16-byte vector retry stayed inline but was substantially worse: thirty
  independent stage pairs reduced JSON to `0.9794x` and binary to `0.7832x`.
  A final two-word scalar unroll was worse again at `0.9519x` JSON and
  `0.7198x` binary. Double-fast therefore keeps its compact single-word loop.
  Grouping the retained four Huffman codes into two temporary pairs before a
  single accumulator merge was rejected as neutral. It preserved the scalar
  oracle on 64/32-bit targets, but thirty independent frame pairs reached only
  `1.0003x` geometrically and reduced text level 3 to `0.9926x`. Directly
  inserting all four codes remains the better dependency/layout balance.
  Initializing the small predefined planner's terminal viable-state mask before
  its reverse DP was rejected. It removed the per-position terminal branch,
  shrank the function by 19 bytes, and the independent LL/OF/ML matrix oracle
  matched every state. Thirty primary-stage pairs improved text/JSON/binary by
  `1.0172x`/`1.0108x`/`1.0160x`, but the 20-row frame matrix moved text levels
  1/9 to `0.9836x`/`0.9841x` and reached only `1.0006x` geometrically. The
  original unified reverse loop remains.
  Removing the small predefined planner's replay-time state range check was
  rejected even though every stored next choice is derived from a symbol-
  bounded viable mask and the independent LL/OF/ML oracle matched all states.
  LLVM grew the planner from 504 to 700 bytes; thirty primary-stage pairs put
  JSON at `0.9901x`, while text/binary were noisy around `1.0063x`/`1.0071x`.
  The seemingly redundant check remains because it enables better codegen.
  Reusing the wide predefined planner's per-position viability masks in the
  small planner was rejected. It reduced temporary stack from roughly 32 KiB
  to 4 KiB and the existing LL/OF/ML oracle matched every chosen state through
  128-value plans, but replay had to recompute transition ranges. Thirty
  independent primary-stage pairs reduced text/JSON/binary to `0.9801x`/
  `0.9265x`/`0.9532x`; the direct u8 next-choice matrix remains much faster.
  Large 64-bit Huffman streams now batch the byte drain as well as symbol
  insertion. Streams of at least 1,024 literals enter a separately placed
  emitter that writes four little-endian bytes whenever its four-symbol batch
  accumulates at least 32 bits, then uses the established byte tail. Shorter
  streams retain the original hot function, and 32-bit targets retain the safe
  two-symbol path. The scalar reference covers 1,023--1,027-byte dispatch and
  modulo-four boundaries plus a 1,027-symbol maximum-11-bit stream. Thirty
  independent fixed-CPU-8 frame pairs preserve every size/checksum, improve
  binary levels 1/3/9/22 by `1.1111x`/`1.0279x`/`1.0279x`/`1.0252x`, and
  improve every JSON level by `1.0045x`--`1.0073x`. Multiblock levels gain
  `1.0024x`--`1.0145x`; the row-median geometric mean is `1.0114x` and the
  weakest row is text level 1 at `0.9923x`. A loop-internal length check was
  rejected because it reduced short text/JSON streams by about 1%--1.5% despite
  an `1.0869x` binary-level-1 gain; the isolated helper raises that target to
  `1.1111x` while restoring JSON to positive medians.
  Compressed offset-table alternatives now reuse their already validated
  repcode-aware codes when computing table-plan bit cost. The alternative
  builder has already replayed every requested raw offset against the caller's
  initial history; the narrow scorer therefore adds the stored code widths and
  transition widths directly, while RLE, predefined, Repeat_Mode, legacy
  selection, and final bit emission retain the authoritative state machine. A
  mixed repeat/direct-offset oracle with default and non-default initial
  histories compares the new compressed cost exactly with the stateful scorer.
  Thirty independent primary double-fast stage pairs improve text/JSON/binary
  by `1.0188x`/`1.0496x`/`1.0136x`, preserving every output field. The matching
  30-pair 20-row frame matrix preserves every size/checksum, reaches a `1.0088x`
  row-median geometric mean, improves binary levels by `1.0029x`--`1.0069x`,
  tradeoff levels by `1.0068x`--`1.0230x`, and keeps the weakest row at
  `0.9950x`.
  Replacing the 32-bucket absolute-offset scan with the equivalent upstream-
  style `floor(log2(offset + 3))` formula was rejected. An exhaustive oracle
  covered all 65,536 u16 distances, every bucket boundary, and overflow, but
  thirty independent primary-stage pairs reduced text/JSON to about `0.987x`
  and left binary neutral at `0.9983x`. The compiler-friendly bucket scan stays.
  Replacing the encoder's code-0/code-1 repcode probes with a direct three-entry
  history state machine was rejected. An exhaustive 273-case oracle matched the
  resolver-driven code, full successor history, and error type, and the compact
  implementation improved primary double-fast stages by `1.0255x`/`1.0536x`/
  `1.0469x` on text/JSON/binary. Yet the 30-pair frame matrix moved all text
  levels to `0.9758x`--`0.9892x`; an earlier branch-expanded form had the same
  layout problem. The smaller decoder-backed selector remains.
  Hoisting that predefined mask table identity check out of the per-value loop
  was rejected too. The once-selected enum path preserved all LL/OF/ML states
  and improved primary text/JSON/binary stages by `1.0180x`/`1.0313x`/
  `1.0190x`, but inlined all three specialized conversions into the planner.
  The 20-row frame matrix reached only `1.0013x` geometrically, with text level
  9 at `0.9944x` and several multiblock rows below one. The smaller out-of-line
  pointer dispatcher remains.
  Restricting the compact encoder-side offset resolver to the already isolated
  450--512-sequence borrowed emitter was rejected as below the retention bar.
  The exhaustive resolver oracle and borrowed-vs-by-value field oracle remained
  exact; thirty independent primary stage pairs improved binary by `1.0559x`
  and JSON by `1.0058x`, with text neutral at `0.9982x`. However, the complete
  20-row matrix reached only `1.0012x` geometrically and reduced binary levels
  3/9 to `0.9917x`/`0.9906x`. The shared resolver remains authoritative.
  Three ways of avoiding the reverse-bitstream field-array copy were rejected.
  Direct reverse traversal plus one exact capacity reservation improved primary
  text/JSON/binary stages by about `1.0145x`/`1.0208x`/`1.0137x`, but rescanning
  field widths reduced the complete 20-row matrix to `0.9795x` geometrically,
  with every tradeoff level at only `0.879x`--`0.947x`. Removing the prepass
  retained `1.0313x`/`1.0272x` JSON/binary stage gains but reached just `0.9744x`
  overall. Finally, routing only the existing 450--512-sequence borrowed emitter
  through an out-of-line direct traversal kept all wire sizes/checksums exact
  and JSON levels positive by `1.0068x`--`1.0133x`, yet reached only `1.0008x`
  geometrically and reduced text level 9 to `0.9876x`. The original copy plus
  compact common writer remains because code placement dominates the saved walk.
  Deriving `SmallHuffmanLiteralPlan.max_symbol` from the last active symbol was
  rejected despite the builder's strict ascending-symbol invariant and all 65
  focused Huffman tests passing. It removes a redundant active-alphabet maximum
  scan, but thirty independent primary-stage pairs reduced JSON to `0.9777x`
  with only 9/30 wins; binary was neutral at `0.9984x`. The explicit scan stays
  because its generated layout is better for the surrounding Huffman planner.
  Skipping the first LL/OF/ML code validation after the RLE payload scorer had
  just derived those three codes was rejected. The exact literal-section scorer
  test and all stage output fields remained identical, and thirty primary-stage
  pairs improved JSON by `1.0470x` and binary by `1.0098x`. The independent-
  binary 20-row matrix instead fell to `0.9943x` geometrically, with JSON levels
  3/9/22 around `0.992x` and text level 9 at `0.9823x`. The shared scorer keeps
  validating index zero to preserve the better complete-encoder layout.
  Calling `literalLengthCode`, `offsetCode`, and `matchLengthCode` directly once
  `predefinedEncodableStateMask` had already identified its canonical table was
  rejected too. The compact predefined oracle and 16 focused tests remained
  exact, and thirty primary-stage pairs improved text/JSON/binary by `1.0070x`/
  `1.0779x`/`1.0362x`. The 20-row matrix improved binary level 1 by `1.0237x`
  and every tradeoff level by `1.0066x`--`1.0178x`, but reached only `1.0012x`
  geometrically while reducing text levels 1/9 to `0.9745x`/`0.9849x` and
  multiblock level 22 to `0.9794x`. The generic dispatch remains for layout.
  Moving the literal-only candidate's existing long-repeat rejection before its
  Huffman plan build was rejected at the focused gate. The selected stage output
  stayed exact, but thirty primary-stage pairs measured text/JSON/binary/wide at
  only `0.9843x`/`0.9969x`/`0.9964x`/`0.9965x`. Even the apparently wasted plan
  build currently gives the surrounding candidate selector better generated
  code, so the established ordering remains.
  Reading finalized `u16` codes and byte-indexed widths directly only inside the
  isolated >=1,024-symbol Huffman emitter was also rejected. Unlike the earlier
  global experiment it left the compact short-stream loop untouched, and the
  checked reference plus 19 focused Huffman tests stayed exact. Thirty primary-
  stage pairs improved binary by `1.0278x`, but text/JSON fell to `0.9880x`/
  `0.9940x`; the established native-width lookup remains worthwhile even for
  long streams on this target.
  Double-fast literal runs now extend the token array once with
  `addManyAsSlice` and initialize that returned slice directly, replacing one
  `appendAssumeCapacity` length update per literal while preserving allocation
  failure and token ordering. All double-fast tests remain exact, and thirty
  independent fixed-CPU-8 primary-stage pairs improve text/JSON/binary/wide by
  `1.0087x`/`1.0160x`/`1.0228x`/`1.0146x`. The matching 30-pair 20-row frame
  matrix preserves every size/checksum, reaches a `1.0060x` row-median geometric
  mean, improves binary level 1 by `1.0184x` and JSON level 1 by `1.0128x`, and
  keeps the weakest row effectively neutral at `0.9993x`.
  Extending each double-fast literal run and following match as one ArrayList
  slice was rejected after the retained literal-only batching change. All 11
  double-fast tests and stage outputs remained exact, and thirty primary-stage
  pairs improved JSON/binary/wide by `1.0093x`/`1.0075x`/`1.0215x`. The 20-row
  matrix reached only `0.9989x` geometrically, however, with JSON level 9 at
  `0.9919x`, tradeoff level 1 at `0.9898x`, and text level 22 at `0.9904x`.
  Match tokens keep their separate append so the common call layout stays small.
  Open-coding match emission inside double-fast's zero-literal immediate-rep
  loop was rejected. Its `anchor == position` invariant makes the omitted empty
  literal append semantically redundant, and all 11 focused tests plus stage
  outputs stayed exact. Thirty primary-stage pairs nevertheless measured only
  `0.9977x`/`1.0004x`/`0.9977x`/`0.9960x` for text/JSON/binary/wide; the shared
  `storeMatch` helper remains better optimized.
  Specializing the double-fast parser around Zstd's fixed four-byte minimum,
  258-byte maximum, and block-bounded 32 KiB window was rejected. A 16-shape
  oracle matched the generic token stream and statistics exactly and all 12
  focused tests passed, but thirty primary-stage pairs put JSON/binary at
  `0.9909x`/`0.9955x`; only the wide input was slightly positive at `1.0025x`.
  The generic options entry remains the better generated implementation.
  Accumulating only `high_byte_count` locally inside the bounded duplicate index
  was rejected independently from the earlier three-scalar experiment. It
  improved index construction by `1.0534x`/`1.0413x`/`1.0370x` on text/JSON/
  binary, and actual single-match stages stayed within about 0.3% of neutral.
  The 30-pair 20-row matrix nevertheless reached only `1.0010x` geometrically;
  binary level 1 was `0.9970x` and JSON level 3 `0.9953x`. Direct field updates
  remain because the isolated builder win did not survive complete encoding.
  Replacing the bounded duplicate index's 32 KiB per-hash pending-byte table
  with a 4 KiB parity bitmap was rejected. The full/bounded field and selected-
  match oracle stayed exact; index construction improved text/JSON/binary by
  `1.0453x`/`1.0440x`/`1.0326x`, and binary single-match by `1.0224x`. But the
  30-pair complete matrix fell to `0.9917x` geometrically, including binary and
  JSON level 1 at `0.9898x`/`0.9907x` and text level 9 at `0.9775x`. The byte
  table's simpler indexed access remains faster end to end.
  Keeping only `max_byte_frequency` in a local bounded-index scalar was also
  rejected. It avoided a field load/store dependency without adding a reduction
  pass, and the full/bounded field oracle stayed exact, but thirty stage pairs
  put binary index construction at `0.9944x` and JSON single-match at `0.9944x`.
  The existing incremental structure-field maximum remains.
  Guarding double-fast's speculative full `max_match` rep0 scan with equality
  of the final candidate byte was rejected. Exhaustive mismatch positions and
  boundary cases proved the condition equivalent before the existing scan, and
  all 12 focused tests passed, but thirty primary-stage pairs left text neutral,
  improved JSON only `1.0090x`, and reduced binary to `0.9962x`. The simpler
  unconditional probe remains.
  Compacting double-fast's short/long position tables from `u32` to `u16` only
  for inputs through 65,536 bytes was rejected. A forced-u32 oracle matched all
  tokens and statistics across 16 generated shapes plus the exact boundary, and
  thirty stage pairs improved text/JSON/binary/wide by `1.0032x`/`1.0078x`/
  `1.0087x`/`1.0077x`. The complete 20-row matrix reached only `1.0020x`
  geometrically, however: every JSON level was slightly negative and multiblock
  level 22 fell to `0.9918x`. The single u32 implementation avoids the extra
  template instance and length dispatch.
  Splitting the bounded duplicate-index loop into a hashable prefix and fixed
  seven-byte statistics tail was rejected despite eliminating the per-byte
  hash-bound check. The field oracle stayed exact and index construction
  improved text/JSON/binary by `1.0141x`/`1.0214x`/`1.1068x`, but the 20-row
  matrix fell broadly to `0.9922x` geometrically, with JSON level 22 at `0.9852x`
  and multiblock level 22 at `0.9766x`. The unified loop remains.
  Reusing the large index's inactive `hash_predecessors` prefix as bounded-build
  paired-position scratch was rejected. It removed a 64 KiB stack array without
  changing persistent layout or the field oracle, and improved index construction
  by `1.0428x`/`1.0406x`/`1.0286x` on text/JSON/binary. The complete 20-row
  matrix was exactly neutral at `1.0000x` geometrically, though, and every binary
  level was slightly negative (`0.9939x`--`0.9989x`). The explicit local array
  remains to avoid aliasing the later exact-search state.
  Three attempts to isolate direct finalized-plan reads for full-alphabet long
  Huffman streams were rejected. A shared lookup-builder branch improved binary
  stage by `1.0262x` but reduced JSON to `0.9800x`; a separate long emitter kept
  the binary gain around `1.024x`--`1.035x` but shifted the existing wide helper
  section and reduced JSON. Moving the decision to the literal-only block caller,
  placing both new helpers in a dedicated section, and marking the branch cold
  kept all original stage-helper addresses stable and improved binary level 1 by
  `1.0378x` (30/30 wins), yet the 20-row matrix reached only `1.0022x` while
  JSON levels stayed at `0.9921x`--`0.9970x` and text level 3 at `0.9917x`. The
  common native-width lookup remains; a larger gain is required before adding a
  second four-stream assembly path.
  Collapsing repeat-beam's two-part near-cost replacement predicate into the
  equivalent bounded comparison `candidate <= replacement + 2` was rejected.
  The path-cost bound and a 1,048,576-pair predicate oracle covered overflow and
  tie behavior; all 20 beam tests and output fields stayed exact. Thirty primary
  beam-stage pairs were only `0.9964x`/`1.0044x`/`1.0067x` on text/JSON/binary,
  and the 20-row matrix reached `0.9998x` geometrically with text level 22 at
  `0.9881x`. The explicit comparison plus guarded subtraction remains.
  Prefetching the repeat-beam indexed match's future state and occupancy targets
  was rejected. The target is known before expanding the two current states and
  all 19 beam tests plus output fields remained exact, but thirty primary-stage
  pairs reduced text/JSON/binary to `0.9808x`/`0.9608x`/`0.9787x`. The target
  state is already cache-resident often enough that the extra prefetch traffic is
  pure overhead on this CPU.
  Removing only repeat-beam's impossible zero-distance check in place was also
  rejected, separately from the earlier unchecked-helper experiment. The compact
  index oracle and all 19 beam tests remained exact, and thirty beam-stage pairs
  improved text/JSON/binary by `1.0084x`/`1.0070x`/`1.0118x`. The 20-row matrix
  fell to `0.9987x` geometrically, however, with text level 1 and JSON level 3 at
  `0.9920x`/`0.9919x`. The explicit defensive condition remains for better
  whole-encoder layout.
  Combining a full four-byte repeat-beam collision check with match extension
  starting after that verified prefix was rejected. This avoids rereading the
  prefix on true matches while filtering collisions earlier; a 259-boundary
  mismatch oracle, compact-index oracle, and all 20 beam tests stayed exact.
  Thirty primary-stage pairs nevertheless reduced text/JSON/binary to
  `0.9248x`/`0.9825x`/`0.9799x`. The cheap fourth-byte filter plus shared
  full-range matcher remains substantially better on current code generation.
  A fixed-parameter Zstd-only double-fast instance was rejected too. It folded
  the constant four-byte minimum and 258-byte maximum while retaining only the
  block-dependent 32 KiB window; a 16-shape oracle matched generic tokens and
  statistics exactly, and all 12 focused tests passed. Thirty primary-stage
  pairs nevertheless measured JSON/binary at `0.9909x`/`0.9955x`, with text
  neutral and only wide input at `1.0025x`. The generic options path remains.
