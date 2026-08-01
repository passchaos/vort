# Native LZ4/Zstd implementation status

This document is a focused status audit for the active objective: implement
native LZ4 and Zstd support in Zig, with library-call APIs prioritized over CLI
surfaces. It records concrete deliverables, current artifact evidence, and the
remaining gaps. It is **not** a completion declaration.

## Objective as deliverables

Native LZ4/Zstd support means the repository should provide, through Zig library
APIs:

1. Native LZ4 frame/block encode and decode without requiring callers to shell
   out to a CLI, including skippable and concatenated stream handling.
2. Native Zstd-compatible frame/block encode and decode for the supported subset,
   including raw/RLE blocks, Huffman literals, sequence blocks, dictionaries, and
   sequence table modes.
3. Public, caller-owned APIs for one-shot, append/into, reusable decoder/encoder,
   chunked split-input, dictionary, dictionary-set, and incremental decode use
   cases.
4. Bounded memory behavior and useful diagnostics for hostile/truncated/corrupt
   inputs.
5. Validation evidence that maps public API behavior to tests/probes/gates rather
   than only internal implementation effort.
6. Documentation that distinguishes implemented capability from remaining
   compatibility, ratio, speed, and format gaps.

## Prompt-to-artifact checklist

| Requirement | Current artifact evidence | Status |
| --- | --- | --- |
| Library-first native LZ4 APIs | `src/root.zig` exports LZ4 native encode/decode, inspect, skippable, dictionary, dictionary-set, chunked, reusable, and incremental decoder APIs; `tools/lz4_native_probe.zig` exercises generated/file cases, skippable streams, chunk joins, dictionary-set APIs, missing dictionaries, split/truncated inputs, and direct-output boundaries. | Implemented for current native LZ4 subset; still needs broader corpus/perf coverage. |
| Library-first native Zstd APIs | `src/root.zig` exports Zstd native encode/decode, inspect, dictionary, dictionary-set, chunked/reusable APIs, incremental decoder, and sequence-mode inspect; `tools/zstd_native_frame_probe.zig` and `tools/zstd_native_dictionary_probe.zig` cover public frame/dictionary surfaces. | Implemented for supported native subset; not full zstd format parity. |
| Incremental decode with caller-owned output | Root tests cover split skippable headers, truncated skippable finish, compressed-buffer limits, no-content-size expected sizes, dictionary-set missing dictionaries, exact frame output boundaries, split block boundaries, checksum diagnostics, and direct-output fallback. Codec tests cover additional direct-output and scratch fallback paths. | Strong coverage for current facade/direct paths; true byte-by-byte streaming decompression remains future work. |
| Zstd Huffman literals | Zstd native frame probe covers direct Huffman limits, high-byte FSE-Huffman weights, system-zstd high-byte fixture, and treeless repeat-Huffman literal reuse through public inspect/decode. | Supported for covered forms; broader real-corpus tuning remains. |
| Zstd sequence tables | Dictionary probe covers public inspection/decode for LL/OF/ML compressed-FSE modes, repeated table reuse, and LL/OF/ML compressed-FSE-to-Repeat_Mode transitions; frame probe covers RLE repeated-table reuse, repeat-offset additional bits, zero-literal selector transitions including rep1/rep2 and invalid `rep0 - 1 == 0`, positive-literal rep2 selection, treeless literal state reuse, and malformed sequence bitstreams with missing, zero, or trailing end-marker bytes plus short/corrupt LL/OF/ML compressed-FSE state streams; focused unit tests still cover writer-side compressed-table construction. | Supported for current sequence execution subset; more fixtures for broader mixed-table transitions are useful. |
| Dictionaries and dictionary sets | Root tests and dictionary probes cover LZ4/Zstd Dictionary_ID metadata, explicit dictionaries, dictionary sets, no-content-size direct output, chunked APIs, missing dictionary diagnostics, and exact-size mismatches. | Implemented for current native APIs; training/stable dictionary workflows remain future work. |
| Skippable/concatenated streams | LZ4/Zstd probes and root tests cover skippable-only streams, mixed streams, consecutive split skippable headers, truncated skippable metadata, chunked split inputs, concatenated direct-output frame boundaries, and skippable streams adjacent to malformed, truncated, checksum-mismatched, and trailing-data frames. | Implemented for current stream iterators/decoders. |
| Bounded memory and hostile inputs | Incremental options expose `max_compressed_buffer_len`, `max_decoded_buffer_len`, and `expected_output_len`; root/probe tests cover OutputLimitExceeded, TruncatedFrame, SizeMismatch, ChecksumMismatch, NeedDictionary, malformed Repeat_Mode state, malformed compressed-FSE table diagnostics, and short/corrupt LL/OF/ML compressed-FSE state streams. | Good coverage for current whole-frame validation plus direct-output paths; fuzz/corpus expansion remains. |
| Bench/gate evidence | `zig build run-native-library-bench-gate` validates public native LZ4/Zstd rows and now runs lightweight smoke checks without adding CSV rows: Zstd sequence inspect, no-content-size multi-compressed frames with checksum/truncation precedence, LZ4 skippable malformed/truncated/checksum/trailing streams, linked direct-output after skippable metadata, and LZ4/Zstd dictionary-set skippable direct-output plus fallback. README documents heavier coverage in probes. | Smoke-level public API gate exists; not a complete performance benchmark. |
| Documentation | `README.md`, `docs/zstd-gap.md`, and this status document describe implemented surfaces and gaps. | Current but should evolve with behavior changes. |

## Current validation commands

Relevant smoke commands for this status slice are:

```sh
zig build test --summary all
zig build run-lz4-native-probe --summary all
zig build run-zstd-native-frame-probe --summary all
zig build run-zstd-native-dictionary-probe --summary all
zig build run-native-library-bench-gate --summary all
zig build check --summary all
```

Recent work in this thread has repeatedly run the narrower probes plus `test` and
`check`. `run-native-library-bench-gate` is the lightweight public API benchmark
CSV gate; it now also runs bounded pre-row smoke checks for no-content-size
multi-compressed Zstd, skippable/malformed LZ4 streams, and dictionary-set
skippable direct-output plus fallback without increasing the 67-row CSV. Heavier sequence-table
fixtures intentionally live in the frame and dictionary probes so the Debug
bench gate stays fast.

## Remaining gaps before the objective can be considered complete

The current implementation is substantial but the objective is not complete.
Open items include:

- Full Zstd compatibility: arbitrary zstd frames, all sequence-table edge cases,
  repeat-offset corner cases, skippable/concatenated compatibility behavior, and
  malformed-frame parity need broader differential evidence.
- Compression ratio and speed: the native encoders are still bootstrap/selected
  paths, not proven zstd-class or LZ4-class across large corpora and modes.
- True streaming internals: incremental decoders expose caller-owned input/output
  state and direct-output paths, but some validation still buffers whole frames
  before output; more byte-progressive decompression is needed for very large or
  hostile streams.
- Dictionary workflows: dictionary IDs and preset-history decode are present, but
  training, stable dictionary IDs, distribution metadata, and long-term dictionary
  compatibility policy are not complete.
- Long-distance matching and advanced native format work: LDM prototypes and
  indexed/seekable native concepts exist elsewhere in the repo, but they are not
  yet an integrated LZ4/Zstd replacement story.
- Fuzz/corpus breadth: generated probes and focused fixtures cover many bug
  classes, but broad persistent fuzzing/corpus dashboards against zlib/lz4/zstd
  references remain necessary.
- Platform/performance matrix: architecture-specific acceleration, memory-use
  dashboards, and ReleaseFast library-level benchmark evidence remain incomplete.

## Next recommended work

1. Add more public Zstd sequence fixtures for broader mixed-table transitions
   and repeat-offset selector combinations.
2. Expand public API benchmarks cautiously, keeping Debug gate time bounded.
3. Add differential/corpus dashboards that compare native LZ4/Zstd APIs against
   local reference tools/libraries without routing through CLI-only code paths.
4. Continue moving incremental decoders from whole-frame validation toward
   byte-progressive decompression while preserving the current diagnostics.
