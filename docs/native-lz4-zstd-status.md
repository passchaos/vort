# Native LZ4/Zstd implementation status

This document is a focused status audit for the active objective: implement
native LZ4 and Zstd support in Zig, with library-call APIs prioritized over CLI
surfaces. It records concrete deliverables, current artifact evidence, and the
remaining gaps. It is **not** a completion declaration.

Zstd encoding now also supports signed levels -131072...22 and explicit
fast/double-fast/greedy/lazy/bounded-optimal match strategies with real
dictionary/history use and caller-owned work profiles. The current
[encoding-controls contract](formats/zstd-encode-controls.md) and
[functional baseline](performance/zstd-encode-controls-functional-baseline.md)
record exact option conflicts, parser limits, legacy-wire comparisons and
independent validation. This increment does not establish complete libzstd
strategy, ratio or throughput parity.

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

Native LZ4 also exposes
[acceleration and independent chain-depth controls](formats/lz4-fast-controls.md)
with caller-owned attempted-work profiles across raw/prefix, reusable, frame
and incremental encoding. Default bytes remain fixed. The native hash-chain
parser and liblz4's single-hash fast parser have different search behavior;
functional control coverage does not establish competitor performance parity.

| Requirement | Current artifact evidence | Status |
| --- | --- | --- |
| Library-first native LZ4 APIs | `src/root.zig` exports LZ4 native encode/decode, inspect, skippable, dictionary, dictionary-set, top-level chunked, reusable single-frame chunked, concatenated chunked, incremental decoder, and incremental fast/HC encoder APIs with optional pledged content size, resumable flush, linked history, preset dictionary, and dictionary-set resolution. It also exposes byte-exact liblz4-1.9.3-compatible LZ4HC raw-block allocating/caller-buffer/reusable APIs, prefix-aware raw blocks, independent/linked frame writing, and preset-dictionary/dictionary-set HC frames for levels 1...12. Incremental data frames default to `Options.input_policy = .block_stream` immediately after a valid header. Raw and compressed-token payloads without block checksums consume caller input directly without decoded-block scratch; linked, independent, preset-dictionary, and blocks larger than the 64 KiB history window use the same resumable output path. Both raw and compressed blocks with block checksums retain one encoded payload until its checksum succeeds, then emit caller output. Explicit `.prevalidated_frame` retains the existing complete-frame preflight/direct path and its cursor fallback. Incremental skippable frames retain only the eight-byte header and stream arbitrary-size metadata directly into discard/caller capture. `tools/lz4_native_probe.zig` dynamically calls liblz4's block, HC, frame, CDict, and dictionary-decode APIs for ordinary and HC levels spanning hash-chain and optimal parsing, all four block-size IDs, linked/independent modes, content/block checksums, omitted content sizes, empty/small/generated payloads, and a 300 KiB multi-block payload. Every liblz4 frame crosses Vort's one-shot, caller-buffer, reusable, chunked, and incremental decoders; matching one-shot and incremental Vort HC frames are decoded through `LZ4F_decompress`/`LZ4F_decompress_usingDict`; and HC blocks plus independent, linked, and dictionary frames are required to match liblz4 byte-for-byte. The probe also covers compressed-block cursor/buffer metrics, dictionaries, skippable streams, malformed/truncated inputs, and direct-output boundaries. | Implemented for the current native LZ4 subset; broader corpus/performance evidence remains a follow-up. |
| Library-first native Zstd APIs | `src/root.zig` exports Zstd native encode/decode, inspect, dictionary, dictionary-set, top-level chunked, reusable single-frame chunked, concatenated chunked, incremental decoder, incremental raw/RLE or entropy-coded encoder with optional pledged content size, resumable non-final flush, indexed bounded rolling cross-block history with multi-match blocks, Dictionary_ID metadata, preset-history borrowing, and dictionary-set resolution, plus plain and dictionary-aware sequence-mode inspect. Seekable encoding also exposes deterministic caller-selected parallel frame APIs for plain, explicit-dictionary, and dictionary-set streams; worker creation may degrade concurrency but never changes the serialized frame order or wire bytes. `tools/zstd_native_frame_probe.zig` and `tools/zstd_native_dictionary_probe.zig` cover public frame/dictionary surfaces, including libzstd-generated frames decoded through Vort native public APIs plus incremental and chunked drains without CLI routing. Frame probes also cover non-single-segment two-, four-, and eight-byte content-size header parsing, single-segment two-, four-, and eight-byte content-size fixtures, Dictionary_ID one-, two-, and four-byte header fields, explicit zero-valued one-, two-, and four-byte Dictionary_ID handling, no-content-size non-default window descriptors, truncated missing-window diagnostics, descriptor unused-bit acceptance, handcrafted checksum success/mismatch/truncation diagnostics including no-content-size multi-block checksums, extended zero-sequence compressed blocks, Predefined-to-Repeat sequence-table state replay in the public inspector, and public encoded-bound sizing for shortest single-segment content-size fields. | Implemented for supported native subset; not full zstd format parity. |
| Explicit Zstd encode windows | `zstd.FrameOptions.window_log` and `zstd.NativeFrameOptions.window_log` (exported as `ZstdFrameOptions` and `ZstdNativeFrameOptions`) accept `10...41`; `null` preserves the previous wire byte-for-byte. For known content at or below the selected window, the writer retains the single-segment header. Known content above it uses a non-single-segment header with `Window_Descriptor` and the shortest legal two-, four-, or eight-byte FCS; unknown-size encoding writes the selected descriptor without an FCS. One-shot, reusable, exact-size and unknown-size incremental, explicit-dictionary, dictionary-set, and seekable encoders feed the same option/header/block path. Block size, rolling history, match offsets, and dictionary visibility respect the selected window. Null `window_log` retains the established 8 MiB history; explicit windows use a 16 MiB default history budget and accept `max_match_history_len` through 64 MiB, capped by the advertised window. Windows of at least 24 bits use the sparse long-distance index. The frame probe pins a libzstd 1.6.0 2,050-byte fixture with descriptor `0x44`, a 1 KiB window and two-byte FCS, decodes it through Vort allocating/caller-buffer/chunked/incremental APIs, and has libzstd decode Vort output. Its raw-content-dictionary cases prove the in-window suffix remains visible and the expired prefix is not referenced. | Implemented for the current encoder surfaces and explicitly bounded internal match capability; this is not full Zstd parity. |
| Incremental decode with caller-owned output | LZ4 and Zstd default to the shared `core.CompressedInputPolicy.block_stream`, entering bounded block decoding after the frame header without first collecting a complete frame. In default mode, each `step` accepts only input needed for the current state; callers retain the suffix after `progress.input_read` and advance output by `progress.output_written`. LZ4 raw and token payloads without block checksums consume input directly; checksummed raw/compressed blocks wait for block-checksum validation before output and retain at most one encoded block plus a 64 KiB history window. Zstd raw payloads stream directly, RLE retains one byte, and compressed literals/sequences retain one encoded block plus bounded window/dictionary history, Huffman/FSE state, repeated offsets, and resumable literal/match cursors. The default supports every previously accepted sequence-table mode, dictionary form, dictionary-set route, frame window, omitted content size, and skippable/concatenated stream. Compressed output in both codecs uses caller buffers without decoded-block scratch. Explicit `.prevalidated_frame` keeps existing whole-frame preflight/direct output and bounded cursor fallback. Frame content checksums can still fail after earlier decoded bytes were emitted, including existing Zstd prevalidated direct paths. Skippable payloads consume caller input directly, retain only their eight-byte header, and commit capture/event statistics after the full payload. Public buffer metrics and streamed-block counters expose retention and cursor use; codec tests, runtime probes, and upstream corpus campaigns cover default and explicit policies, split boundaries, output backpressure, dictionary/history continuity, corruption, truncation, and exact progress accounting. | Default input is bounded by codec block/history state rather than complete frame size. Zstd compressed input and checksummed LZ4 input retain one encoded block; unchecked LZ4 input is progressive. |
| Zstd Huffman literals | Zstd native frame probe covers direct Huffman limits, high-byte FSE-Huffman weights, system-zstd high-byte fixture, and treeless repeat-Huffman literal reuse through public inspect/decode. | Supported for covered forms; broader real-corpus tuning remains. |
| Zstd sequence tables | Dictionary probe covers public inspection/decode for LL/OF/ML compressed-FSE modes, repeated table reuse, and LL/OF/ML compressed-FSE-to-Repeat_Mode transitions; frame probe covers RLE repeated-table reuse, repeat-offset additional bits, zero-literal selector transitions including rep1/rep2, positive-literal rep0/rep1/rep2 selection plus Repeat_Mode replay of positive-literal rep0/rep1/rep2 selectors, compressed offset-table repeat selector emission, mixed OF+ML compressed-FSE tables with predefined LL plus malformed mixed-table reserved-bit/truncated/short-bitstream paths, all-LL/OF/ML compressed-FSE table-plan output and Repeat_Mode replay, invalid `rep0 - 1 == 0`, valid cross-block `rep0 - 1` after direct-offset updates including the minimum valid `rep0 - 1 == 1` boundary and Repeat_Mode replay, multi-sequence predefined-table state transitions, mixed RLE/predefined sequence modes, repeated mixed-table modes across blocks, non-dictionary LL/ML/OF=FSE Repeat_Mode replay (reported as `fse-repeat` in the native codec probe dashboard), library-level libzstd-generated frame differentials, treeless literal state reuse, and malformed sequence bitstreams with missing, zero, or trailing end-marker bytes plus short/corrupt LL/OF/ML compressed-FSE state streams, including all-LL/OF/ML compressed-FSE table/state/end-marker corruptions, all-FSE Repeat_Mode replay corruptions, and non-dictionary repeated-table replay truncation. The writer carries sequence tables and repcodes transactionally across blocks at all supported sequence counts, exactly arbitrates Repeat_Mode against fresh RLE/predefined/compressed-FSE tables, preserves table state across zero-sequence blocks, resets it at frame boundaries, and can start from standard-dictionary entropy tables. Wide blocks can emit more than the former 512-sequence implementation limit with bounded dynamic scratch and exact table arbitration; backward reachability prevents greedy dead ends when encoding wide Repeat_Mode state paths, and its viability buffer scales with the actual prior-table size (75% smaller for the normal 128-state tables). Frame assembly reuses the remaining dynamic sequence scratch across candidates and block rewrites, removing 13 allocations/76,482 requested bytes from the two-33-KiB fixture; `NativeFrameEncoder` retains it across calls and removes another 18 allocations after warmup, with OOM recovery and balanced teardown covered. A 513-sequence two-block regression covers mixed LL=Repeat/OF=RLE/ML=Repeat output and allocation rollback. The speed-level decisive-wide consensus path emits against current state directly and avoids 16 allocations/237,173 requested bytes on that fixture; strict and fallback candidate arbitration remains unchanged. The runtime-libzstd probe covers deterministic 128 KiB single-block, 256 KiB two-wide-block Repeat_Mode, 33 KiB speed-path Repeat_Mode, and 129 KiB small-block Repeat_Mode frames. The opt-in `run-zstd-decodecorpus-gate` regenerates nine fixed upstream campaigns (9,900 frames, with and without standard dictionaries plus forced block-type stress) and requires the corpus-only cumulative LL/OF/ML mode mask to cover all 64 tuples. | Supported for current sequence execution subset; removing fallback re-encoding, more upstream versions, and persistent fuzz coverage remain useful. |
| Dictionaries and dictionary sets | Root tests and dictionary probes cover LZ4/Zstd Dictionary_ID metadata, content-derived stable Dictionary_ID convenience constructors, deterministic owned dictionary training helpers with `metadata()` catalog summaries, fixed-size versioned `DictionaryMetadata` encode/decode records, versioned metadata-catalog encode/decode records, metadata-vs-bytes validation before constructing borrowed dictionaries or full dictionary-set catalogs, checked in-memory dictionary catalogs, explicit dictionaries, dictionary sets, no-content-size direct output, top-level chunked APIs, reusable single-frame chunked decoder APIs, pure-Zig standard Zstd entropy-dictionary training, COVER history selection with bounded held-out parameter search, and dictionary-aware Zstd sequence-mode inspection that seeds Huffman/FSE/repcodes from a standard full dictionary. Zstd also supports explicitly supplied raw-content dictionaries whose frames carry no Dictionary_ID; these remain intentionally unavailable through dictionary-set routing because an ID-less frame cannot select one entry. Seekable encoding exposes conservative output bounds plus caller-owned output variants for plain, explicit-dictionary, and dictionary-set streams; `NativeSeekableStreamEncoder` additionally retains frame, output, and seek-entry scratch across repeated calls. Scan/index range APIs have matching explicit-single-dictionary variants, so ID-less streams can be randomly read without weakening dictionary-set ID validation. A fixed libzstd-trained Repeat_Mode fixture, runtime-trained 256/1024/4096-byte dictionary frames, and a runtime libzstd ID-less raw-dictionary frame cover size, alloc, caller-buffer, chunked, incremental, single-block, and multi-block decode plus Vort-to-libzstd encode interoperability. Missing dictionary diagnostics, wrong-dictionary diagnostics, exact-size mismatches, and priority cases remain covered across malformed/checksum paths. | Implemented for current native APIs; broader training-corpus evaluation and long-term dictionary compatibility policy remain future work. |
| Skippable/concatenated streams | LZ4/Zstd probes and root tests cover skippable-only streams, public LZ4/Zstd skippable bound/append/into-slice helpers, mixed streams, consecutive split skippable headers, multiple metadata frames between data frames, truncated payloads, chunked split inputs, concatenated direct-output frame boundaries, and stream summaries that expose checksum-bearing, Dictionary_ID-bearing, and content-size-bearing frame counts plus declared content bytes. Both incremental decoders retain only an eight-byte skippable header, stream the payload into discard/caller capture, and commit event statistics only after the full payload arrives. | Implemented for current stream iterators/decoders. |
| Bounded memory and hostile inputs | Incremental options expose the input policy, retained-input cap `max_compressed_buffer_len`, per-data-frame decoded-output cap `max_decoded_buffer_len`, cumulative `max_output_len`, live requested-allocation budget `max_working_memory`, and logical-stream exact byte count `expected_output_len`; root/probe tests cover OutputLimitExceeded, TruncatedFrame, SizeMismatch, ChecksumMismatch, NeedDictionary, invalid-magic, reserved-header, and window/block-size diagnostics including skippable-adjacent invalid streams, malformed Repeat_Mode state, malformed compressed-FSE table diagnostics, short/corrupt LL/OF/ML compressed-FSE state streams, including non-dictionary repeated-table replay truncation, and Dictionary_ID-vs-corruption error precedence across one-shot, reusable, chunked, dictionary-set, and incremental paths. | Default bounded and explicit preflight/direct paths are covered; fuzz/corpus expansion remains. |
| Bench/gate evidence | `zig build run-native-library-bench-gate` validates public native LZ4/Zstd rows and now runs lightweight smoke checks without adding CSV rows: Zstd sequence inspect including all-LL/OF/ML compressed-FSE and all-FSE Repeat_Mode one-shot/incremental/chunked/reusable chunked drains, no-content-size multi-compressed frames with checksum/truncation precedence, LZ4 skippable malformed/truncated/checksum/trailing streams, linked direct-output after skippable metadata, LZ4 dictionary-set direct-to-cursor switching plus Zstd dictionary-set scratch-free small-output switching, and reusable single-frame chunked decoder helpers. The LZ4 linked/dictionary-set smokes require the compressed cursor to become observable under caller backpressure, decoded scratch length and capacity to remain zero, the streamed-block counter to commit only after block completion, and the final split output to remain exact. `run-lz4-hc-reference-bench-gate` adds byte-identical independent/linked/CDict one-shot encode throughput and ratio rows; `run-zstd-seekable-parallel-bench-gate` additionally records ReleaseFast 1/2/4/8-worker throughput with provenance and rejects wire/checksum drift. `run-native-codec-probes-dashboard` reports reusable single-frame chunked decoder coverage as a distinct capability. README documents heavier coverage in probes. | Smoke-level public API and focused HC/frame-parallel benchmark gates exist; they are not complete standard-corpus performance evidence. |
| Documentation | `README.md`, `docs/zstd-gap.md`, and this status document describe implemented surfaces and gaps. | Current but should evolve with behavior changes. |

## Incremental input policy and limits

`Lz4NativeIncrementalFrameDecoder.Options.input_policy` and
`ZstdNativeIncrementalFrameDecoder.Options.input_policy` use
`core.CompressedInputPolicy`: `.block_stream` is the default, while
`.prevalidated_frame` selects the existing complete-frame structural preflight
and direct-output paths when the frame fits the retained-input cap. It keeps
their established fallback behavior and checksum timing: frame content-checksum
validation may occur after decoded output has been delivered.

A blocked `step(input, output)` may accept only a prefix of `input`, even when
all remaining frame bytes are available. Preserve
`input[result.progress.input_read..]` for the next call and use only
`output[0..result.progress.output_written]` as newly produced bytes. Default
buffers follow block, entropy, and history state rather than frame length.
`stop_after_first_frame` returns at the first validated data-frame boundary;
`trailingInput()` exposes only already-accepted suffix bytes, so an outer
member dispatcher must also preserve the unaccepted caller-input suffix.

`max_compressed_buffer_len` limits retained encoded bytes. Zstd compressed
blocks and LZ4 blocks carrying a block checksum must fit that cap. Unchecked
LZ4 payloads, Zstd raw/RLE payloads, and skippable metadata do not need a
payload-sized buffer.
`max_decoded_buffer_len` caps total decoded bytes in each data frame, including
bytes already emitted, and is not a scratch-capacity limit.
`expected_output_len` is an optional exact count across the whole logical
incremental stream, including concatenated frames: surplus output is rejected,
and `finish()` checks the final byte count and incomplete input/output state.
`max_output_len` separately caps cumulative output across data frames and
stopped-member continuation. `max_working_memory` bounds decoder-owned live
requested heap bytes, including retained input/output/history capacities and
temporary entropy scratch. Caller-owned input/output, dictionary and metadata
capture buffers, fixed state, stack tables and allocator bookkeeping are
excluded. Budget rejection is `WorkingMemoryLimitExceeded`; a backing allocator
failure remains `OutOfMemory`.

`workingMemoryBytes()` and `peakWorkingMemoryBytes()` report live/peak requested
allocation counts. `reset()` keeps reusable capacity and starts new cumulative
counts; its fresh peak includes still-live retained capacity.
`resetWithOptions()` validates new options before releasing owned storage.
`nextStream()` resumes a stopped data-frame boundary without resetting accepted
suffixes, cumulative output, allocation peak or the exact-size pledge. The
pledge may span several stopped members and is checked at final `finish()`.
While stopped, `step()` returns `.done` with zero input/output progress until
`nextStream()` explicitly continues.
Failed `step` calls expose actual input/output progress and error offsets in
snapshot/diagnostics; subsequent calls after parser/allocation failure have
zero progress until reset. Incomplete `finish()` retains the existing ability
to supply more input/output.

## Dictionary requests and continuation

Both native incremental decoders expose `requiredDictionaryId()`,
`provideDictionary(dictionary)` and `provideDictionarySet(set)`. A complete
validated frame header with a nonzero unresolved ID reports `NeedDictionary`
and preserves accepted input, prior-member output, cumulative limits and
working memory. Waiting `step` and `finish` calls repeat `NeedDictionary`
without accepting new bytes. A single dictionary with a different ID reports
`DictionaryMismatch`; a supplied set without that ID reports `NeedDictionary`.
Both preserve the request. Zstd also validates supplied full dictionary
metadata before installing the override.

Provided bytes are borrowed for the current frame, through successful
completion, terminal failure, reset or deinit. They override the configured
dictionary/set only for that frame and do not replace the original catalog.
Frame completion and terminal failure clear the override and borrowed history
views. LZ4 dictionary IDs are application-assigned values, so matching an ID
does not authenticate dictionary content. Standard Zstd metadata must agree
with its declared ID and content view.

On the first `NeedDictionary`, advance caller input/output by
`snapshot().last_step_progress`, obtain the required ID and provide the
matching dictionary. Continue with the unconsumed caller-input suffix; the
decoder reuses its retained header. Dictionary errors carry the
`retry_with_dictionary` diagnostic hint; unrelated parser, checksum, budget
and allocation errors remain sticky.

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

Zstd encoding now exposes `window_log: ?u6` on both frame option layers. Values
10...41 produce standard window declarations, while `null` keeps established
output byte-identical. Known content that fits the selected window remains a
single segment; known content beyond it switches to a non-single-segment header
with `Window_Descriptor` and two-, four-, or eight-byte FCS, and unknown-size
incremental output always carries the selected descriptor. All one-shot,
reusable, incremental, dictionary, dictionary-set, and seekable paths share
this policy. Their block, history, and dictionary-reference reach is bounded by
the selected window and the encode history budget: 8 MiB for null windows,
16 MiB by default for explicit windows, or an explicit budget up to 64 MiB.
Explicit windows of at least 24 bits use a separate sparse long-distance index.
The public probe retains the libzstd 1.6.0 2,050-byte fixture with frame descriptor
`0x44` and window descriptor `0x00` (1 KiB), and checks
both interoperability directions, including visible and expired portions of a
larger raw-content dictionary.

## Remaining gaps before the objective can be considered complete

The current implementation is substantial but the objective is not complete.
Open items include:

- Full Zstd compatibility: explicit encode windows are now covered across the
  public encoder families, but arbitrary zstd frames, all sequence-table edge
  cases, repeat-offset corner cases, skippable/concatenated compatibility
  behavior, and malformed-frame parity still need broader differential
  evidence. Explicit-window encoding already expands match history beyond
  8 MiB through its sparse long-distance index, with a 16 MiB default and
  caller-selected budgets up to 64 MiB; wider-window ratio and memory behavior
  still need broader corpus evidence.
- Compression ratio and speed: the native encoders are still bootstrap/selected
  paths, not proven zstd-class or LZ4-class across large corpora and modes.
- Streaming validation breadth: default block streaming is implemented for
  both codecs, with caller backpressure, resumable compressed output, and
  direct raw/skippable input. Zstd compressed input and checksummed LZ4 raw or
  compressed input intentionally retain one encoded block. Continue differential
  and hostile-input testing across the default and explicit preflight policies,
  and expand allocation/RSS and real-file throughput comparisons beyond the
  current requested-allocation and cumulative-output limits.
- Dictionary workflows: dictionary IDs, content-derived stable IDs,
  deterministic training helpers with versioned catalog metadata records and
  byte validation, checked in-memory dictionary catalogs, and preset-history
  decode, standard entropy-dictionary training, pure-Zig COVER history
  selection, and bounded held-out parameter search are present. Broader corpus
  evaluation and long-term dictionary compatibility policy remain follow-ups.
- Long-distance and native-format evaluation: explicit-window Zstd encoding
  already integrates sparse long-distance matching. Measure its ratio, memory,
  and throughput across larger corpora; advanced native-format design remains
  separate from the compatibility codecs and their existing indexed/seekable
  APIs.
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

`BrotliIncrementalStreamDecoder` now owns only a caller-bounded history ring
and delegates directly to that symbol-progressive core. It no longer retains a
complete compressed frame, performs a decoded-size preflight, or allocates a
complete decoded frame before publishing output. Pledged compressed sizes,
output limits, concatenated `nextFrame` accounting, Large Window opt-in,
metadata capture, external header scratch, snapshots, and diagnostics remain
on the public facade; `max_history_len` makes its only material owned codec
state explicit.
The wrapper consumes at most the two-byte Brotli window prefix before creating
that ring. Ordinary unknown-size WBITS=16 streams therefore allocate 65,520
history bytes instead of the standard-format 16 MiB maximum; pledged small
outputs allocate only their reachable output size. A smaller caller cap remains
valid for streams whose actual distances fit, while the first match beyond that
cap is reported as `OutputLimitExceeded` instead of being misclassified as a
corrupt distance.

## Next recommended work

1. Add more public Zstd sequence fixtures for broader mixed-table transitions
   and repeat-offset selector combinations.
2. Expand public API benchmarks cautiously, keeping Debug gate time bounded.
3. Add differential/corpus dashboards that compare native LZ4/Zstd APIs against
   local reference tools/libraries without routing through CLI-only code paths.
4. Continue moving the remaining whole-block incremental codecs toward
   byte-progressive decompression while preserving verification boundaries.
