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
- [ ] Skippable frames and frame indexes.
- [ ] Coverage-guided fuzz harness for headers and malformed frames.

## Milestone 3: deflate/zlib/gzip compatibility

- [x] LSB-first bit reader primitive.
- [x] Canonical Huffman decode table foundation for fixed-Huffman inflate.
- [ ] Bit writer primitives.
- [x] Stored deflate blocks.
- [x] Fixed-Huffman literal-only inflate.
- [ ] Fixed-Huffman back-reference inflate.
- [ ] Dynamic-Huffman inflate.
- [x] zlib wrapper and Adler verification for stored blocks.
- [ ] zlib wrapper integration for fixed/dynamic Huffman blocks.
- [x] gzip wrapper and CRC/ISIZE verification for stored blocks.
- [ ] gzip wrapper integration for fixed/dynamic Huffman blocks.
- [x] Stored-block vectors checked against Python/zlib level-0 output.
- [ ] Differential tests against zlib, zlib-ng, and zlib-rs.
- [ ] Compatibility benchmark suite.

## Milestone 4: compression performance foundation

- [ ] Match finder interfaces and scalar reference matchers.
- [ ] LZ77 parser experiments with deterministic level/strategy configs.
- [ ] Huffman code generation and canonical-code validation.
- [ ] Decompression hot-path benchmarks.
- [ ] Compression ratio/throughput dashboards across real corpora.

## Milestone 5: native Vort format research

- [ ] Design note for native block/frame layout.
- [ ] Dictionary IDs and dictionary training plan.
- [ ] Splittable/seekable frame index design.
- [ ] Long-distance matching experiments.
- [ ] Multi-threaded block planning with deterministic output mode.
