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
- [x] Portable CRC32 slice-by-8 fast variant selected by dispatch.
- [x] Portable CRC32C slice-by-8 fallback selected when hardware CRC32C is unavailable.
- [x] Runtime checksum dispatch API selecting portable fast path.
- [x] CPU feature/dispatch report tool.
- [x] x86 checksum CPU feature reporting with IEEE-vs-CRC32C safety distinction.
- [x] x86 SSE4.2 CRC32C hardware path selected by dispatch.
- [x] Architecture-specific IEEE CRC32 dispatch plan and safety gates.
- [ ] Architecture-specific IEEE CRC32 implementation / dispatch.
- [x] Differential checksum smoke against Zig std reference implementations.
- [x] Differential checksum tests against Python zlib and local/system gzip wrapper trailers.

## Milestone 2: native frame plumbing

- [x] Native `VORT` store frame for uncompressed payloads.
- [x] Header parsing with explicit version, size, checksum, and corruption errors.
- [x] One-shot encode/decode APIs.
- [x] Allocator-returning convenience APIs.
- [x] Bounded-output streaming encoder/decoder smoke coverage.
- [x] Fully incremental input/output store-frame decoder.
- [x] Concatenated store-frame iterator and decode helper.
- [x] Deterministic malformed-header/frame smoke corpus.
- [x] Skippable native frames.
- [x] In-memory frame indexes for concatenated native store streams.
- [x] Serialized/sidecar frame indexes.
- [x] Serialized frame indexes carry per-frame checksums validated by range decode.
- [x] Extensible hex-sample fuzz corpus harness for headers and malformed frames.
- [x] Coverage-guided fuzz integration plan and reusable corpus entrypoint.
- [x] Raw-byte fuzz target function and smoke executable.
- [x] libFuzzer-compatible exported entrypoint smoke.
- [x] AFL-style file-input fuzz driver smoke.
- [x] Local CI smoke runner wiring for fuzz entrypoints.
- [x] Hosted CI fuzz runner wiring.

## Milestone 3: deflate/zlib/gzip compatibility

- [x] LSB-first bit reader primitive.
- [x] Canonical Huffman decode table foundation for fixed-Huffman inflate.
- [x] LSB-first bit writer primitive.
- [x] Stored deflate blocks.
- [x] Fixed-Huffman inflate for literals and back-references.
- [x] Fixed-Huffman fast lookup decode path for literals and distances.
- [x] Dynamic-Huffman header and code-length parser foundation.
- [x] Dynamic-Huffman inflate for single final blocks.
- [x] Multi-block raw/zlib/gzip inflate across stored/fixed/dynamic block types.
- [x] zlib wrapper and Adler verification for stored blocks.
- [x] zlib wrapper integration for fixed-Huffman blocks.
- [x] zlib wrapper integration for single final dynamic-Huffman blocks.
- [x] zlib wrapper integration for multi-block dynamic streams.
- [x] gzip wrapper and CRC/ISIZE verification for stored blocks.
- [x] gzip optional header fields: FEXTRA, FNAME, FCOMMENT, FHCRC validation.
- [x] gzip wrapper integration for fixed-Huffman blocks.
- [x] gzip wrapper integration for single final dynamic-Huffman blocks.
- [x] gzip wrapper integration for multi-block dynamic streams.
- [x] gzip concatenated member decode support.
- [x] Stored-block vectors checked against Python/zlib level-0 output.
- [x] Black-box differential smoke against Python zlib.
- [x] Black-box differential smoke against system gzip CLI.
- [x] Match-heavy dynamic/split/adaptive differential vectors.
- [x] Local external implementation/tool availability probe.
- [x] Optional zlib-ng/zlib-rs differential harness with explicit skip reporting.
- [x] Built zlib-ng minigzip differential test running in local validation.
- [x] zlib-rs gzip corpus differential decode coverage.
- [x] Built zlib-rs compress example differential test running in local validation.
- [x] CI zlib-rs binary differential test.
- [x] Minimal literal-only dynamic Huffman encoder for raw/zlib/gzip, verified by Python zlib.
- [x] Dynamic Huffman encoder with LZ77 match support, verified by Python zlib.
- [x] Dynamic Huffman encoder code-length RLE using symbols 16/17/18.
- [x] Frequency-weighted tree Huffman length builder used by dynamic encoder.
- [x] Block cost selection across stored/fixed/dynamic encoders.
- [x] Raw fixed multi-block encoder with final/non-final block splitting.
- [x] Raw dynamic multi-block encoder with final/non-final block splitting.
- [x] Raw split-best encoder selecting stored/fixed/dynamic per bounded block.
- [x] zlib/gzip split-best wrappers verified by Python zlib.
- [x] Adaptive split-best raw/zlib/gzip wrappers verified by Python zlib.
- [x] Fixed-Huffman bit-cost selector for stored-vs-fixed block decisions.
- [x] Dynamic-Huffman bit-cost selector avoiding materialized dynamic candidates for block decisions.
- [x] Adaptive split search using stored/fixed/dynamic bit-cost candidates.
- [x] Level-specific adaptive split policy config and report coverage.
- [x] Adaptive split policy size-delta report across built-in corpora.
- [x] Adaptive split policy report accepts ad-hoc file corpora.
- [x] Adaptive split policy report across bounded Silesia files.
- [x] Adaptive split encoder falls back to one-shot best output when smaller.
- [ ] Production dynamic Huffman encoder with optimized block splitting and block-type decisions.
- [x] Compatibility benchmark smoke suite comparing Vort/gzip/zstd on sample files.
- [x] Standard-corpus smoke benchmark comparing Vort/gzip/zlib-ng/zlib-rs/zstd.
- [x] Full local Silesia corpus benchmark mode.
- [x] Per-file Silesia suite automation against gzip/zlib-ng/zlib-rs/zstd.
- [x] External path/directory benchmark suite mode for additional corpora.
- [x] External tar-archive benchmark suite mode for packed standard corpora.
- [ ] Full compatibility benchmark suite automation across multiple standard corpora.

## Milestone 4: compression performance foundation

- [x] Match finder interfaces, scalar reference matcher, and hash-chain matcher.
- [x] Greedy LZ77 parser experiment with deterministic options and replay tests.
- [x] Lazy greedy LZ77 parser experiment with deterministic options.
- [x] Optimal LZ77 parser prototype with deterministic options.
- [x] Fixed-Huffman bit-cost model for optimal LZ77 parser decisions.
- [x] Optimal LZ77 parser evaluates multiple match-distance candidates.
- [x] Fixed encoder parser strategy config selecting greedy/lazy/optimal prototypes.
- [x] Compression strategy config selecting default, Huffman-only, and RLE plans.
- [x] Compression level presets for fast/default/best strategy configs.
- [x] Fast preset skips dynamic block candidate generation.
- [x] Fastest preset with shallow hash-chain search for speed.
- [x] Compression-level report validating parser/cost-model settings and round trips.
- [x] Compression-level report accepts ad-hoc file corpora.
- [x] Level-specific optimal parser match-candidate limits.
- [x] Level-specific lazy parser gain thresholds.
- [x] Level-specific minimum match length parser setting.
- [x] Level-specific minimum match savings parser setting.
- [x] Level-specific maximum match length parser setting.
- [ ] Production optimal parser with full level/strategy configs.
- [x] Huffman code generation, simple length building, and canonical-code validation.
- [x] Decompression hot-path smoke benchmarks for raw/zlib/gzip fixed and dynamic samples.
- [x] Larger decompression hot-path benchmarks across built-in text/structured/binary corpora.
- [x] Fixed-Huffman raw deflate encoder backed by greedy LZ77 tokens.
- [x] zlib/gzip fixed-Huffman encoder wrappers.
- [x] Built-in small-corpus compression ratio report.
- [x] File-path compression ratio report for ad-hoc corpora.
- [x] zstd CLI compressed-size comparison smoke for sample files.
- [x] File-path compression/decompression throughput report for ad-hoc corpora.
- [x] Silesia-sample standard corpus benchmark smoke.
- [x] Automated per-file Silesia throughput report.
- [x] Markdown benchmark dashboard export for Silesia suite.
- [x] Standard corpus Markdown dashboard per-codec summary totals.
- [x] External file/directory throughput dashboard input mode.
- [x] External tar-archive throughput dashboard input mode.
- [x] Full-size Silesia Markdown dashboard export.
- [ ] Automated throughput dashboards across multiple full standard real corpora.

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
- [x] Dictionary training and patch report accepts ad-hoc file corpora.
- [x] Dictionary training and patch report across bounded Silesia files.
- [x] Per-file dictionary training and patch report for bounded Silesia files.
- [x] Markdown dictionary corpus dashboard for bounded Silesia files.
- [x] Dictionary report supports target-size tuning.
- [x] Dictionary corpus dashboard supports target-size sweeps.
- [ ] Production dictionary training integrated into encoder with ratio/throughput gains.
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
- [x] Native range report covers self-contained dictionary streams.
- [x] Blocked native deflate stream with embedded index and range decode.
- [x] Blocked native best-mode stream with embedded index and range decode.
- [ ] Production seekable native format integration with native block modes.
- [x] Long-distance matching scanner experiment.
- [x] Long-distance matching summary integrated into compression reports.
- [x] Long-distance-match-aware block planner annotations.
- [x] Skippable long-distance summary metadata embedded in native blocked streams.
- [x] Native blocked stream planning aligns blocks to long-distance match starts.
- [x] Prototype native LDM reference frame with opt-in best-frame selection.
- [x] Native LDM frame size and selection metrics in compression report.
- [ ] Production long-distance matching integration into native/block encoder.
- [x] Deterministic block planning metadata for future multi-threaded encoding.
- [x] Deterministic block-planned encoder execution API.
- [x] Parallel multi-threaded encoder execution with deterministic output order.
- [x] Fixed worker-count thread-pool encoder scheduling.
- [x] Work-queue encoder scheduling with deterministic output order.
- [x] Native parallel/thread-pool/work-queue encoder benchmark smoke.
- [x] Native parallel/thread-pool/work-queue benchmark accepts real file corpora.
- [x] Native parallel/thread-pool/work-queue benchmark accepts configurable worker counts.
- [x] Native parallel/thread-pool/work-queue benchmark across bounded Silesia files.
- [x] Native parallel/thread-pool/work-queue Markdown dashboards for bounded/full Silesia.
- [x] Native parallel/thread-pool/work-queue dashboard accepts external path/tar corpora.
- [x] Native parallel/thread-pool/work-queue full dashboard accepts external path/tar corpora.
- [x] Native parallel/thread-pool/work-queue dashboard per-mode throughput summaries.
- [ ] Production thread-pool encoder benchmarking across full standard real corpora.
