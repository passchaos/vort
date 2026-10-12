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
| Library-first native LZ4 APIs | `src/root.zig` exports LZ4 native encode/decode, inspect, skippable, dictionary, dictionary-set, top-level chunked, reusable single-frame chunked, concatenated chunked, incremental decoder, and incremental fast/HC encoder APIs with optional pledged content size, resumable flush, linked history, preset dictionary, and dictionary-set resolution. It also exposes byte-exact liblz4-1.9.3-compatible LZ4HC raw-block allocating/caller-buffer/reusable APIs, prefix-aware raw blocks, independent/linked frame writing, and preset-dictionary/dictionary-set HC frames for levels 1...12. Incremental data frames release raw payload directly and use a resumable compressed-token cursor without decoded-block scratch, including block-checksummed, linked-block, preset-dictionary, blocks larger than the 64 KiB history window, and complete prevalidated frames whose compressed block exceeds caller output. Blocks without a block checksum can also consume compressed input incrementally under a header-sized buffer cap; checksummed blocks remain buffered until their compressed-payload checksum succeeds. Incremental skippable frames retain only the eight-byte header and stream arbitrary-size metadata directly into discard/caller capture. `tools/lz4_native_probe.zig` dynamically calls liblz4's block, HC, frame, CDict, and dictionary-decode APIs for ordinary and HC levels spanning hash-chain and optimal parsing, all four block-size IDs, linked/independent modes, content/block checksums, omitted content sizes, empty/small/generated payloads, and a 300 KiB multi-block payload. Every liblz4 frame crosses Vort's one-shot, caller-buffer, reusable, chunked, and incremental decoders; matching one-shot and incremental Vort HC frames are decoded through `LZ4F_decompress`/`LZ4F_decompress_usingDict`; and HC blocks plus independent, linked, and dictionary frames are required to match liblz4 byte-for-byte. The probe also covers compressed-block cursor/buffer metrics, dictionaries, skippable streams, malformed/truncated inputs, and direct-output boundaries. | Implemented for the current native LZ4 subset; broader corpus/performance evidence remains a follow-up. |
| Library-first native Zstd APIs | `src/root.zig` exports Zstd native encode/decode, inspect, dictionary, dictionary-set, top-level chunked, reusable single-frame chunked, concatenated chunked, incremental decoder, incremental raw/RLE or entropy-coded encoder with optional pledged content size, resumable non-final flush, indexed bounded rolling cross-block history with multi-match blocks, Dictionary_ID metadata, preset-history borrowing, and dictionary-set resolution, plus plain and dictionary-aware sequence-mode inspect. Seekable encoding also exposes deterministic caller-selected parallel frame APIs for plain, explicit-dictionary, and dictionary-set streams; worker creation may degrade concurrency but never changes the serialized frame order or wire bytes. `tools/zstd_native_frame_probe.zig` and `tools/zstd_native_dictionary_probe.zig` cover public frame/dictionary surfaces, including libzstd-generated frames decoded through Vort native public APIs plus incremental and chunked drains without CLI routing. Frame probes also cover non-single-segment two-, four-, and eight-byte content-size header parsing, single-segment two-, four-, and eight-byte content-size fixtures, Dictionary_ID one-, two-, and four-byte header fields, explicit zero-valued one-, two-, and four-byte Dictionary_ID handling, no-content-size non-default window descriptors, truncated missing-window diagnostics, descriptor unused-bit acceptance, handcrafted checksum success/mismatch/truncation diagnostics including no-content-size multi-block checksums, extended zero-sequence compressed blocks, Predefined-to-Repeat sequence-table state replay in the public inspector, and public encoded-bound sizing for shortest single-segment content-size fields. | Implemented for supported native subset; not full zstd format parity. |
| Incremental decode with caller-owned output | Root tests cover split skippable headers, truncated skippable finish, compressed-buffer limits, no-content-size expected sizes, dictionary-set missing dictionaries, exact frame output boundaries, split block boundaries, checksum diagnostics, zero-output multi-compressed-block frames, and direct-output switching. Zstd data frames larger than `max_compressed_buffer_len` release raw payload incrementally, retain one byte for RLE blocks, and retain at most one compressed block while preserving Huffman/FSE/repeated-offset state and bounded history across blocks. Both sequence-free literals and sequence-bearing compressed blocks retain resumable Huffman/FSE cursors plus pending literal/match progress, writing directly into arbitrarily small caller output without decoded-block scratch. A complete frame selected for direct output switches in place to that sequence cursor when its next compressed block does not fit caller output, preserving prior-block history, entropy state, and checksum progress; zero-output compressed blocks are still parsed through every non-final block before checksum acceptance. LZ4 now also switches oversized data frames to block streaming: raw blocks drain directly, while compressed blocks retain a token/literal/match cursor and write through arbitrarily small caller buffers without decoded scratch. The cursor combines caller-visible output with a bounded 64 KiB rolling history, so independent, linked, preset-dictionary, checksummed, and larger frame-block sizes share the same resumable output path. Unchecked compressed payloads are consumed incrementally across arbitrary input boundaries; checksummed blocks remain fully buffered until their compressed-payload checksum succeeds, preserving checksum-before-output. The exact compressed-payload-size cap and corrupt-checksum-before-output boundaries remain pinned. Both codecs' skippable frames retain only their eight-byte header; arbitrary-size metadata is discarded or copied into caller-owned capture storage incrementally, and event counters commit only after the complete payload arrives. Public buffer metrics expose compressed and decoded retention; LZ4 exposes `isCompressedBlockStreaming()`/`streamedCompressedBlockCount()`, while Zstd exposes `streamedLiteralBlockCount()` and `streamedSequenceBlockCount()`. The fixed upstream Zstd corpus suite incrementally re-decodes 9,900 frames: the established 5,400 broad/dictionary frames plus 4,500 forced RLE-content-size, 8-byte raw-block, and 16-byte compressed-block stress frames. The broad suite exercises the block-stream state on 2,699 frames after direct-path switching, zero-scratch sequence-free literal output on 197 blocks, and zero-scratch resumable execution on 76,578 sequence-bearing blocks; decoded scratch length and capacity remain zero throughout those runs. Codec/probe tests cover additional direct-output paths, single-frame, chunked, and concatenated `decodeIntoExactSize` helpers for caller-owned buffers including dictionary/dictionary-set variants, plus Dictionary_ID priority diagnostics for checksum, content-size, malformed-block, and dictionary-set conflicts. | Block-bounded input and header-bounded skippable metadata are implemented for both codecs. Zstd and LZ4 compressed output are resumable without decoded-block scratch; unchecked LZ4 compressed input is progressive, while Zstd and checksummed LZ4 compressed input remain block-atomic. |
| Zstd Huffman literals | Zstd native frame probe covers direct Huffman limits, high-byte FSE-Huffman weights, system-zstd high-byte fixture, and treeless repeat-Huffman literal reuse through public inspect/decode. | Supported for covered forms; broader real-corpus tuning remains. |
| Zstd sequence tables | Dictionary probe covers public inspection/decode for LL/OF/ML compressed-FSE modes, repeated table reuse, and LL/OF/ML compressed-FSE-to-Repeat_Mode transitions; frame probe covers RLE repeated-table reuse, repeat-offset additional bits, zero-literal selector transitions including rep1/rep2, positive-literal rep0/rep1/rep2 selection plus Repeat_Mode replay of positive-literal rep0/rep1/rep2 selectors, compressed offset-table repeat selector emission, mixed OF+ML compressed-FSE tables with predefined LL plus malformed mixed-table reserved-bit/truncated/short-bitstream paths, all-LL/OF/ML compressed-FSE table-plan output and Repeat_Mode replay, invalid `rep0 - 1 == 0`, valid cross-block `rep0 - 1` after direct-offset updates including the minimum valid `rep0 - 1 == 1` boundary and Repeat_Mode replay, multi-sequence predefined-table state transitions, mixed RLE/predefined sequence modes, repeated mixed-table modes across blocks, non-dictionary LL/ML/OF=FSE Repeat_Mode replay (reported as `fse-repeat` in the native codec probe dashboard), library-level libzstd-generated frame differentials, treeless literal state reuse, and malformed sequence bitstreams with missing, zero, or trailing end-marker bytes plus short/corrupt LL/OF/ML compressed-FSE state streams, including all-LL/OF/ML compressed-FSE table/state/end-marker corruptions, all-FSE Repeat_Mode replay corruptions, and non-dictionary repeated-table replay truncation. The writer carries sequence tables and repcodes transactionally across blocks at all supported sequence counts, exactly arbitrates Repeat_Mode against fresh RLE/predefined/compressed-FSE tables, preserves table state across zero-sequence blocks, resets it at frame boundaries, and can start from standard-dictionary entropy tables. Wide blocks can emit more than the former 512-sequence implementation limit with bounded dynamic scratch and exact table arbitration; backward reachability prevents greedy dead ends when encoding wide Repeat_Mode state paths, and its viability buffer scales with the actual prior-table size (75% smaller for the normal 128-state tables). Frame assembly reuses the remaining dynamic sequence scratch across candidates and block rewrites, removing 13 allocations/76,482 requested bytes from the two-33-KiB fixture; `NativeFrameEncoder` retains it across calls and removes another 18 allocations after warmup, with OOM recovery and balanced teardown covered. A 513-sequence two-block regression covers mixed LL=Repeat/OF=RLE/ML=Repeat output and allocation rollback. The speed-level decisive-wide consensus path emits against current state directly and avoids 16 allocations/237,173 requested bytes on that fixture; strict and fallback candidate arbitration remains unchanged. The runtime-libzstd probe covers deterministic 128 KiB single-block, 256 KiB two-wide-block Repeat_Mode, 33 KiB speed-path Repeat_Mode, and 129 KiB small-block Repeat_Mode frames. The opt-in `run-zstd-decodecorpus-gate` regenerates nine fixed upstream campaigns (9,900 frames, with and without standard dictionaries plus forced block-type stress) and requires the corpus-only cumulative LL/OF/ML mode mask to cover all 64 tuples. | Supported for current sequence execution subset; removing fallback re-encoding, more upstream versions, and persistent fuzz coverage remain useful. |
| Dictionaries and dictionary sets | Root tests and dictionary probes cover LZ4/Zstd Dictionary_ID metadata, content-derived stable Dictionary_ID convenience constructors, deterministic owned dictionary training helpers with `metadata()` catalog summaries, fixed-size versioned `DictionaryMetadata` encode/decode records, versioned metadata-catalog encode/decode records, metadata-vs-bytes validation before constructing borrowed dictionaries or full dictionary-set catalogs, checked in-memory dictionary catalogs, explicit dictionaries, dictionary sets, no-content-size direct output, top-level chunked APIs, reusable single-frame chunked decoder APIs, and dictionary-aware Zstd sequence-mode inspection that seeds Huffman/FSE/repcodes from a standard full dictionary. Zstd also supports explicitly supplied raw-content dictionaries whose frames carry no Dictionary_ID; these remain intentionally unavailable through dictionary-set routing because an ID-less frame cannot select one entry. Seekable encoding exposes conservative output bounds plus caller-owned output variants for plain, explicit-dictionary, and dictionary-set streams; `NativeSeekableStreamEncoder` additionally retains frame, output, and seek-entry scratch across repeated calls. Scan/index range APIs have matching explicit-single-dictionary variants, so ID-less streams can be randomly read without weakening dictionary-set ID validation. A fixed libzstd-trained Repeat_Mode fixture, runtime-trained 256/1024/4096-byte dictionary frames, and a runtime libzstd ID-less raw-dictionary frame cover size, alloc, caller-buffer, chunked, incremental, single-block, and multi-block decode plus Vort-to-libzstd encode interoperability. Missing dictionary diagnostics, wrong-dictionary diagnostics, exact-size mismatches, and priority cases remain covered across malformed/checksum paths. | Implemented for current native APIs; richer training algorithms and long-term dictionary compatibility policy remain future work. |
| Skippable/concatenated streams | LZ4/Zstd probes and root tests cover skippable-only streams, public LZ4/Zstd skippable bound/append/into-slice helpers, mixed streams, consecutive split skippable headers, multiple metadata frames between data frames, truncated payloads, chunked split inputs, concatenated direct-output frame boundaries, and stream summaries that expose checksum-bearing, Dictionary_ID-bearing, and content-size-bearing frame counts plus declared content bytes. Both incremental decoders retain only an eight-byte skippable header, stream the payload into discard/caller capture, and commit event statistics only after the full payload arrives. | Implemented for current stream iterators/decoders. |
| Bounded memory and hostile inputs | Incremental options expose `max_compressed_buffer_len`, `max_decoded_buffer_len`, and `expected_output_len`; root/probe tests cover OutputLimitExceeded, TruncatedFrame, SizeMismatch, ChecksumMismatch, NeedDictionary, invalid-magic, reserved-header, and window/block-size diagnostics including skippable-adjacent invalid streams, malformed Repeat_Mode state, malformed compressed-FSE table diagnostics, short/corrupt LL/OF/ML compressed-FSE state streams, including non-dictionary repeated-table replay truncation, and Dictionary_ID-vs-corruption error precedence across one-shot, reusable, chunked, dictionary-set, and incremental paths. | Good coverage for current whole-frame validation plus direct-output paths; fuzz/corpus expansion remains. |
| Bench/gate evidence | `zig build run-native-library-bench-gate` validates public native LZ4/Zstd rows and now runs lightweight smoke checks without adding CSV rows: Zstd sequence inspect including all-LL/OF/ML compressed-FSE and all-FSE Repeat_Mode one-shot/incremental/chunked/reusable chunked drains, no-content-size multi-compressed frames with checksum/truncation precedence, LZ4 skippable malformed/truncated/checksum/trailing streams, linked direct-output after skippable metadata, LZ4 dictionary-set direct-to-cursor switching plus Zstd dictionary-set scratch-free small-output switching, and reusable single-frame chunked decoder helpers. The LZ4 linked/dictionary-set smokes require the compressed cursor to become observable under caller backpressure, decoded scratch length and capacity to remain zero, the streamed-block counter to commit only after block completion, and the final split output to remain exact. `run-zstd-seekable-parallel-bench-gate` additionally records ReleaseFast 1/2/4/8-worker throughput with provenance and rejects wire/checksum drift. `run-native-codec-probes-dashboard` reports reusable single-frame chunked decoder coverage as a distinct capability. README documents heavier coverage in probes. | Smoke-level public API and frame-parallel benchmark gates exist; they are not complete standard-corpus performance evidence. |
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
zig build run-zstd-large-sequence-probe --summary all
zig build run-zstd-native-encode-stage-bench-gate --summary all
zig build run-zstd-seekable-parallel-bench-gate -j1 --summary all
zig build run-zstd-decodecorpus-gate-smoke --summary all
zig build -Doptimize=ReleaseFast run-zstd-decodecorpus-gate -j1
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
`ci-smoke` also runs the self-contained `run-zstd-decodecorpus-gate-smoke`,
which uses fake generator/probe executables to validate campaign selection,
dictionary argument forwarding, cumulative mode-mask parsing, failure
propagation, and temporary-directory cleanup. The full 9,900-frame command is
kept opt-in because it needs an upstream `tests/decodecorpus` executable and
generates hundreds of MiB of transient data; it discovers
`~/Work/zstd/tests/decodecorpus`, accepts an explicit override, records the
upstream git version, and removes one campaign before generating the next.
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
through a ReleaseFast build for library-path smoke evidence. `run-native-codec-probes-dashboard` records reusable single-frame
chunked decoder coverage as a distinct `reusable-chunked` capability and the
decoded-scratch-free LZ4 path as `compressed-block-cursor`. The bench
gates also run bounded pre-row smoke checks for no-content-size
multi-compressed Zstd, skippable/malformed LZ4 streams, and dictionary-set
skippable direct output plus LZ4 fallback/Zstd scratch-free small-output switching,
and reusable single-frame chunked decoder helpers with and without dictionary
sets. The CSV now has 93 rows, including LZ4/Zstd lib/native lib-decode rows plus LZ4/Zstd lib-generated compatibility-frame/no-size/checksum/no-size+checksum/independent/full-independent and trained-dictionary encode/decode rows backed by the same public training APIs exposed to library callers. Heavier sequence-table
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
- True streaming internals: Zstd data frames release encoded input one block at
  a time, compressed literals and sequence execution are resumable without
  decoded-block scratch in both bounded block-stream and prevalidated direct
  paths, and skippable payloads retain only their eight-byte header. LZ4 data
  frames now also release input block by block. Compressed blocks are
  byte-progressive after whole-block validation and use no decoded scratch,
  including block-checksummed, linked, preset-dictionary, and >64 KiB paths. A
  checksummed block remains encoded-buffered until checksum validation succeeds;
  without a block checksum, LZ4 compressed input can also be consumed
  progressively under a header-sized compressed-buffer cap. Zstd compressed
  input and checksummed LZ4 compressed input remain block-atomic.
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

The Brotli progressive decoder accepts the complete 256-entry literal, command,
and distance block-type count range plus all 256 literal/distance context trees. A real libbrotli quality-11
Graphviz stream exercises more than 32 literal types; handcrafted maximum-width
literal and command streams are cross-decoded by libbrotli plus Vort's one-shot
and byte-progressive paths. Command trees beyond the common first 32 use packed
4-bit code lengths and one lazily expanded active-tree cache, keeping the public
decoder state below its existing 1.5 MiB budget. Literal and distance trees use
the same representation beyond their first 64 hot entries, reducing
`BrotliIncrementalCopyStreamDecoder` from 1,499,168 to 652,288 bytes while the
real 247-literal-tree and 68-distance-tree upstream cases continue to decode.
The progressive path keeps a 16 KiB built-in compressed-header buffer but now
accepts larger caller-owned `compressed_header_scratch`; a 17,261-byte legal
header is rejected explicitly at the default bound and decodes through the
external scratch path. The one-shot decoder continues to parse directly from
input.

## Next recommended work

1. Add more public Zstd sequence fixtures for broader mixed-table transitions
   and repeat-offset selector combinations.
2. Expand public API benchmarks cautiously, keeping Debug gate time bounded.
3. Add differential/corpus dashboards that compare native LZ4/Zstd APIs against
   local reference tools/libraries without routing through CLI-only code paths.
4. Continue moving incremental decoders from whole-frame validation toward
   byte-progressive decompression while preserving the current diagnostics.
