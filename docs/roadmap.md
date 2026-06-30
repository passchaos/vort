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
- [ ] CRC-32C for modern storage/network workloads.
- [ ] Faster checksum variants and CPU dispatch with scalar reference checks.
- [ ] Differential checksum tests against local/system zlib-family tools.

## Milestone 2: native frame plumbing

- [x] Native `VORT` store frame for uncompressed payloads.
- [x] Header parsing with explicit version, size, checksum, and corruption errors.
- [x] One-shot encode/decode APIs.
- [x] Allocator-returning convenience APIs.
- [x] Bounded-output streaming encoder/decoder smoke coverage.
- [ ] Fully incremental input streaming decoder.
- [ ] Concatenated frames, skippable frames, and frame indexes.
- [ ] Fuzz/corpus harness for headers and malformed frames.

## Milestone 3: deflate/zlib/gzip compatibility

- [ ] Bit reader/writer primitives.
- [ ] Stored deflate blocks.
- [ ] Fixed-Huffman inflate.
- [ ] Dynamic-Huffman inflate.
- [ ] zlib wrapper and Adler verification.
- [ ] gzip wrapper and CRC/ISIZE verification.
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
