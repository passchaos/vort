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
| Library-first native LZ4 APIs | `src/root.zig` exports LZ4 native encode/decode, inspect, skippable, dictionary, dictionary-set, top-level chunked, reusable single-frame chunked, concatenated chunked, and incremental decoder APIs; `tools/lz4_native_probe.zig` exercises generated/file cases, pure library-level liblz4-generated frame differentials with incremental and chunked drains, skippable streams, chunk joins, dictionary-set APIs, missing dictionaries, split/truncated inputs, and direct-output boundaries. | Implemented for current native LZ4 subset; still needs broader corpus/perf coverage. |
| Library-first native Zstd APIs | `src/root.zig` exports Zstd native encode/decode, inspect, dictionary, dictionary-set, top-level chunked, reusable single-frame chunked, concatenated chunked, incremental decoder, and sequence-mode inspect; `tools/zstd_native_frame_probe.zig` and `tools/zstd_native_dictionary_probe.zig` cover public frame/dictionary surfaces, including libzstd-generated frames decoded through Vort native public APIs plus incremental and chunked drains without CLI routing. Frame probes also cover non-single-segment two-, four-, and eight-byte content-size header parsing, single-segment two-, four-, and eight-byte content-size fixtures, Dictionary_ID one-, two-, and four-byte header fields, explicit zero-valued one-, two-, and four-byte Dictionary_ID handling, no-content-size non-default window descriptors, truncated missing-window diagnostics, descriptor unused-bit acceptance, handcrafted checksum success/mismatch/truncation diagnostics, and public encoded-bound sizing for shortest single-segment content-size fields. | Implemented for supported native subset; not full zstd format parity. |
| Incremental decode with caller-owned output | Root tests cover split skippable headers, truncated skippable finish, compressed-buffer limits, no-content-size expected sizes, dictionary-set missing dictionaries, exact frame output boundaries, split block boundaries, checksum diagnostics, and direct-output fallback. Codec/probe tests cover additional direct-output and scratch fallback paths, single-frame, chunked, and concatenated `decodeIntoExactSize` helpers for caller-owned buffers including dictionary/dictionary-set variants, plus Dictionary_ID priority diagnostics for checksum, content-size, malformed-block, and dictionary-set conflicts. | Strong coverage for current facade/direct paths; true byte-by-byte streaming decompression remains future work. |
| Zstd Huffman literals | Zstd native frame probe covers direct Huffman limits, high-byte FSE-Huffman weights, system-zstd high-byte fixture, and treeless repeat-Huffman literal reuse through public inspect/decode. | Supported for covered forms; broader real-corpus tuning remains. |
| Zstd sequence tables | Dictionary probe covers public inspection/decode for LL/OF/ML compressed-FSE modes, repeated table reuse, and LL/OF/ML compressed-FSE-to-Repeat_Mode transitions; frame probe covers RLE repeated-table reuse, repeat-offset additional bits, zero-literal selector transitions including rep1/rep2, positive-literal rep0/rep1/rep2 selection plus Repeat_Mode replay of positive-literal rep0/rep1/rep2 selectors, compressed offset-table repeat selector emission, mixed OF+ML compressed-FSE tables with predefined LL plus malformed mixed-table reserved-bit/truncated/short-bitstream paths, all-LL/OF/ML compressed-FSE table-plan output and Repeat_Mode replay, invalid `rep0 - 1 == 0`, valid cross-block `rep0 - 1` after direct-offset updates including the minimum valid `rep0 - 1 == 1` boundary and Repeat_Mode replay, multi-sequence predefined-table state transitions, mixed RLE/predefined sequence modes, repeated mixed-table modes across blocks, non-dictionary LL/ML/OF=FSE Repeat_Mode replay (reported as `fse-repeat` in the native codec probe dashboard), library-level libzstd-generated frame differentials, treeless literal state reuse, and malformed sequence bitstreams with missing, zero, or trailing end-marker bytes plus short/corrupt LL/OF/ML compressed-FSE state streams, including all-LL/OF/ML compressed-FSE table/state/end-marker corruptions, all-FSE Repeat_Mode replay corruptions, and non-dictionary repeated-table replay truncation; focused unit tests cover writer-side compressed-table construction, including compressed offset-table repeat selector planning and all-LL/OF/ML compressed-FSE table-plan selection. | Supported for current sequence execution subset; more fixtures for broader mixed-table transitions are useful. |
| Dictionaries and dictionary sets | Root tests and dictionary probes cover LZ4/Zstd Dictionary_ID metadata, content-derived stable Dictionary_ID convenience constructors, deterministic owned dictionary training helpers with `metadata()` catalog summaries, fixed-size versioned `DictionaryMetadata` encode/decode records, versioned metadata-catalog encode/decode records, metadata-vs-bytes validation before constructing borrowed dictionaries or full dictionary-set catalogs, checked dictionary-set catalogs that reject zero or duplicate IDs, explicit dictionaries, dictionary sets, no-content-size direct output, top-level chunked APIs, reusable single-frame chunked decoder APIs, missing dictionary diagnostics, wrong-dictionary diagnostics, exact-size mismatches, and priority cases where missing or mismatched Dictionary_ID is reported before checksum, content-size, block-checksum, malformed raw/RLE block, malformed compressed sequence-table, or invalid-match errors. Dictionary-set probes cover the same precedence across top-level, chunked, reusable, and incremental paths for skippable streams with later missing IDs, including LZ4 block/content checksum, content-size, and invalid-match conflicts plus Zstd compressed sequence-table conflicts. | Implemented for current native APIs; richer training algorithms and long-term dictionary compatibility policy remain future work. |
| Skippable/concatenated streams | LZ4/Zstd probes and root tests cover skippable-only streams, public LZ4/Zstd skippable bound/append/into-slice helpers, mixed streams, consecutive split skippable headers, multiple skippable frames between Zstd data frames, truncated skippable metadata, chunked split inputs, concatenated direct-output frame boundaries, and skippable streams adjacent to malformed, truncated, checksum-mismatched, and trailing-data frames. | Implemented for current stream iterators/decoders. |
| Bounded memory and hostile inputs | Incremental options expose `max_compressed_buffer_len`, `max_decoded_buffer_len`, and `expected_output_len`; root/probe tests cover OutputLimitExceeded, TruncatedFrame, SizeMismatch, ChecksumMismatch, NeedDictionary, invalid-magic, reserved-header, and window/block-size diagnostics including skippable-adjacent invalid streams, malformed Repeat_Mode state, malformed compressed-FSE table diagnostics, short/corrupt LL/OF/ML compressed-FSE state streams, including non-dictionary repeated-table replay truncation, and Dictionary_ID-vs-corruption error precedence across one-shot, reusable, chunked, dictionary-set, and incremental paths. | Good coverage for current whole-frame validation plus direct-output paths; fuzz/corpus expansion remains. |
| Bench/gate evidence | `zig build run-native-library-bench-gate` validates public native LZ4/Zstd rows and now runs lightweight smoke checks without adding CSV rows: Zstd sequence inspect including all-LL/OF/ML compressed-FSE and all-FSE Repeat_Mode one-shot/incremental/chunked/reusable chunked drains, no-content-size multi-compressed frames with checksum/truncation precedence, LZ4 skippable malformed/truncated/checksum/trailing streams, linked direct-output after skippable metadata, LZ4/Zstd dictionary-set skippable direct-output plus fallback, and reusable single-frame chunked decoder helpers. `run-native-codec-probes-dashboard` reports reusable single-frame chunked decoder coverage as a distinct capability. README documents heavier coverage in probes. | Smoke-level public API gate exists; not a complete performance benchmark. |
| Documentation | `README.md`, `docs/zstd-gap.md`, and this status document describe implemented surfaces and gaps. | Current but should evolve with behavior changes. |

## Current validation commands

Relevant smoke commands for this status slice are:

```sh
zig build test --summary all
zig build run-native-codec-probes --summary all
zig build run-native-codec-probes-dashboard --summary all
zig build run-lz4-native-probe --summary all
zig build run-lz4-native-dictionary-probe --summary all
zig build run-zstd-native-frame-probe --summary all
zig build run-zstd-native-dictionary-probe --summary all
zig build run-native-library-bench-gate --summary all
zig build run-native-library-bench-releasefast-gate --summary all
zig build run-native-library-bench-path-gate --summary all
zig build run-native-library-bench-releasefast-path-gate --summary all
zig build check --summary all
```

Recent work in this thread has repeatedly run the narrower probes plus `test` and
`check`; `ci-smoke` now depends on `run-native-codec-probes-dashboard` so all
four library-level LZ4/Zstd probes run through the regular smoke target and
retain `zig-out/vort-native-codec-probes.json` / `.md` artifacts.
The native codec dashboard probes are intentionally bounded for Debug CI:
Zstd's generated frame matrix uses raw/RLE compatibility frames for the broad
decode/API cross-product, while hand-authored frame fixtures retain compressed
Huffman, FSE sequence-table, repeat-mode, truncation, and checksum coverage.
The Zstd dictionary probe similarly keeps the expensive dictionary
Huffman/sequence-table writer outputs as fixed fixtures and validates them
through public inspect/decode APIs, preserving coverage without rerunning the
bootstrap planner on every dashboard smoke. The dashboard runner enforces a
per-probe timeout and records timeout status in retained artifacts, so runtime
regressions produce actionable probe-level failures rather than unbounded CI
hangs. Dashboard validation also surfaces the timed-out probe count plus Zstd
frame and dictionary probe case counts directly, making timeout regressions and
loss of public Zstd sequence-table/repeat-offset coverage visible instead of
relying only on aggregate capability totals.
The retained Zstd native stream summary artifact also participates in aggregate
dashboard validation health, with strict-mode fixtures for missing and
undercovered summary outputs.
`run-native-library-bench` now accepts repeated `--path` arguments plus `--limit` for focused
project-file payloads, and `run-native-library-bench-path-gate` and `run-native-library-bench-releasefast-path-gate` keep that code path covered with a small fixture in Debug and ReleaseFast builds. `run-native-library-bench-gate` is the lightweight Debug public API benchmark
CSV gate; `run-native-library-bench-releasefast-gate` runs the same 93-row matrix
through a ReleaseFast build for library-path smoke evidence. `run-native-codec-probes-dashboard` now records reusable single-frame
chunked decoder coverage as a distinct `reusable-chunked` capability. The bench
gates also run bounded pre-row smoke checks for no-content-size
multi-compressed Zstd, skippable/malformed LZ4 streams, and dictionary-set
skippable direct-output plus fallback, and reusable single-frame chunked decoder helpers with and without dictionary sets. The CSV now has 93 rows, including LZ4/Zstd lib/native lib-decode rows plus LZ4/Zstd lib-generated compatibility-frame/no-size/checksum/no-size+checksum/independent/full-independent and trained-dictionary encode/decode rows backed by the same public training APIs exposed to library callers. Heavier sequence-table
fixtures intentionally live in the frame and dictionary probes so the Debug
bench gate stays fast.

Recent progress: LZ4/Zstd `NativeDictionary` now expose `derivedId` and
`initFromContent` helpers that compute stable non-zero frame `Dictionary_ID`
values from dictionary bytes using the shared IEEE CRC-32 checksum, and
`trainNativeDictionaryAlloc` returns allocator-owned trained dictionary bytes
with the same ID policy, and the owned dictionary values now expose
`metadata()` plus `encodeDictionaryMetadata*` / `decodeDictionaryMetadata*`
helpers so callers can persist 32-byte versioned `DictionaryMetadata` records or
counted metadata catalogs next to dictionary bytes. Catalog decoders support both
strict and prefix modes, so container formats can read the metadata table before
continuing to dictionary bytes or other sections. `initFromMetadata` validates
received bytes against those catalog entries before deriving frame-level
Dictionary_ID values, and dictionary sets can now build a full borrowed catalog
from parallel metadata and content slices while preserving duplicate-ID
validation, accepting an explicitly empty catalog but rejecting metadata/content
length mismatches. Allocating helpers also own the small catalog array for
callers that want a reusable set without managing scratch storage at every
decode site. Library callers no longer need to hand-roll IDs or route basic
deterministic training through a CLI for simple dictionary catalogs.
Dictionary sets now also expose `initChecked`/`validate` helpers so dynamic
catalogs can reject zero IDs and duplicate Dictionary_ID collisions before they
reach encode/decode paths.
Single-frame dictionary-set `decodeChunks*` helpers on `NativeFrameDecoder`
plus root-level `decodeNativeFrameChunks*` aliases also avoid requiring callers
to route split single frames through concatenated-stream helpers. The native
library bench gate smoke path now exercises those single-frame reusable chunk
helpers alongside the older concatenated chunk helpers.

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
- Dictionary workflows: dictionary IDs, content-derived stable IDs,
  deterministic training helpers with versioned catalog metadata records and
  byte validation, checked in-memory dictionary catalogs, and preset-history
  decode are present, but richer training algorithms and long-term dictionary
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
