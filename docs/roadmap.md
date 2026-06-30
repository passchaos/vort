# Vort roadmap

This roadmap is a living checklist toward the larger goal: outperform and
out-feature `zlib`, `zlib-ng`, `zlib-rs`, and `zstd` without copying their
architecture blindly.

## Milestone 0: repository and validation spine

- [x] Zig 0.16 package scaffold.
- [x] Public root module and library artifact.
- [x] Unit-test build step.
- [x] Compile-only `check` step for tests, CLI, and benchmark entrypoints.
- [x] CLI smoke surface for library APIs.
- [x] Initial benchmark entrypoint.

## Milestone 1: compatibility primitives

- [x] Adler-32 with streaming state and zlib-known vectors.
- [x] IEEE CRC-32 with streaming state and known vectors.
- [x] CRC-32C for modern storage/network workloads.
- [ ] Faster checksum variants and CPU dispatch with scalar reference checks.
- [x] Differential checksum smoke against Zig std reference implementations.
- [ ] Differential checksum tests against local/system zlib-family tools.

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
- [x] Extensible hex-sample fuzz corpus harness for headers and malformed frames.
- [x] Coverage-guided fuzz integration plan and reusable corpus entrypoint.
- [ ] libFuzzer/AFL runner wiring.

## Milestone 3: deflate/zlib/gzip compatibility

- [x] LSB-first bit reader primitive.
- [x] Canonical Huffman decode table foundation for fixed-Huffman inflate.
- [x] LSB-first bit writer primitive.
- [x] Stored deflate blocks.
- [x] Fixed-Huffman inflate for literals and back-references.
- [x] Dynamic-Huffman header and code-length parser foundation.
- [x] Dynamic-Huffman inflate for single final blocks.
- [x] Multi-block raw/zlib/gzip inflate across stored/fixed/dynamic block types.
- [x] zlib wrapper and Adler verification for stored blocks.
- [x] zlib wrapper integration for fixed-Huffman blocks.
- [x] zlib wrapper integration for single final dynamic-Huffman blocks.
- [x] zlib wrapper integration for multi-block dynamic streams.
- [x] gzip wrapper and CRC/ISIZE verification for stored blocks.
- [x] gzip optional header fields: FEXTRA, FNAME, FCOMMENT, FHCRC skip/parse support.
- [x] gzip wrapper integration for fixed-Huffman blocks.
- [x] gzip wrapper integration for single final dynamic-Huffman blocks.
- [x] gzip wrapper integration for multi-block dynamic streams.
- [x] Stored-block vectors checked against Python/zlib level-0 output.
- [x] Black-box differential smoke against Python zlib.
- [x] Black-box differential smoke against system gzip CLI.
- [x] Local external implementation/tool availability probe.
- [ ] Differential tests against zlib-ng and zlib-rs.
- [ ] Compatibility benchmark suite.

## Milestone 4: compression performance foundation

- [x] Match finder interfaces and scalar reference matchers.
- [x] Greedy LZ77 parser experiment with deterministic options and replay tests.
- [x] Lazy greedy LZ77 parser experiment with deterministic options.
- [x] Optimal LZ77 parser prototype with deterministic options.
- [ ] Production optimal parser with level/strategy configs.
- [x] Huffman code generation and canonical-code validation.
- [x] Decompression hot-path smoke benchmarks for raw/zlib/gzip fixed and dynamic samples.
- [ ] Larger decompression hot-path benchmarks across real corpora.
- [x] Fixed-Huffman raw deflate encoder backed by greedy LZ77 tokens.
- [x] zlib/gzip fixed-Huffman encoder wrappers.
- [x] Built-in small-corpus compression ratio report.
- [x] File-path compression ratio report for ad-hoc corpora.
- [x] zstd CLI compressed-size comparison smoke for sample files.
- [ ] Compression throughput dashboards across real corpora.

## Milestone 5: native Vort format research

- [x] Initial design note for native block/frame layout.
- [x] Dictionary IDs and training-plan metadata.
- [x] Deterministic n-gram dictionary training prototype.
- [ ] Production dictionary training with ratio/throughput validation.
- [ ] Splittable/seekable frame index design.
- [x] Long-distance matching scanner experiment.
- [ ] Long-distance matching integration into native/block encoder.
- [x] Deterministic block planning metadata for future multi-threaded encoding.
- [ ] Multi-threaded encoder execution with deterministic output mode.
