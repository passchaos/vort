# Mainstream codec and industry gap audit

Date: 2026-10-24. Source and tools revision: `37dee0fc`.

Vort has broad Zig-native format coverage and some measured performance wins.
The objective of exceeding the best competing libraries in both functionality
and performance remains incomplete. Format interoperability, API coverage,
encoder quality and throughput are separate claims.

## Current functionality

| Family | Implemented public functionality | Remaining gap |
| --- | --- | --- |
| DEFLATE / zlib / gzip | Stored/fixed/dynamic/best encoding, full block decoding, dictionaries, incremental I/O, block/partial flush, runtime parameter changes and full-flush recovery | Full zlib API equivalence is not established. The project does not offer a `z_stream`/`gzFile` drop-in C ABI; that ABI is outside the active roadmap. Broader ratio/throughput evidence is still needed. |
| Zstandard | Raw/RLE/Huffman/FSE sequence frames, dictionary sets and recovery, incremental encoding/decoding, signed levels -131072...22, five explicit dictionary/history-aware match strategies, work profiles, window logs 10...41, COVER-class and complete FastCover training/optimization, and seekable streams | Full libzstd binary-tree/HQ models and strategy/quality parity remain open. Internal match history is bounded through 64 MiB. Standard dictionary finalization latency and broad encoder quality/speed parity remain open. |
| LZ4 | Block/frame/legacy formats, linked blocks, dictionaries, incremental fast/HC encoding and bounded decoding; HC levels 1...12 with byte-exact liblz4 1.9.3 reference gates | No equivalent public fast-acceleration knob. Full corpus/platform performance leadership is unproven. |
| Snappy | Raw/native framed/Xerial/Hadoop encoding and decoding, CRC32C, incremental I/O, COPY4, validated replay, work/output budgets and exact failed-call progress | Raw decoder benchmark wins do not establish framed/incremental encoder and decoder leadership across real corpora. |
| Brotli | RFC decoding, all 256 entropy block types, static/shared dictionaries, opt-in Large Window extension, incremental I/O and Vort-native q0...q11 generic/text/font presets | q10/q11 remain bounded Vort search rather than complete libbrotli HQ/Zopfli parity. Quality numbers do not imply matching libbrotli ratio or speed. Global/HQ cost planning across large streams and worst-case decode performance remain open; bounded arbitrary-size multi-meta-block encoding is already implemented. |
| Bzip2 | BZh1...BZh9, legacy randomized blocks, concatenated streams, CRC validation, incremental encode/decode and bounded checked plaintext replay | Broad competitor throughput, ratio and RSS comparisons are missing. |
| XZ / LZMA | LZMA-Alone/MicroLZMA/ZIP-LZMA and raw LZMA2; XZ checks, Index/Footer, Delta and all eight BCJ filters; presets 0...9/extreme with concrete liblzma 5.8.4 parameters, five real HC/BT matchers, fast/normal and legacy modes, explicit nice/depth and matcher/parser budgets across public and incremental APIs; progressive and bounded checked decoding | Preset parameter parity does not establish full liblzma parsing, quality or throughput parity. Normal search retains eight state/rep paths per position. Custom encoding dictionaries stop at 64 MiB versus liblzma's 1.5 GiB; compressed LZMA2 plaintext chunks remain 64 KiB versus the format's 2 MiB maximum. Broad encoder speed/ratio/memory parity remains unproven. |

The former LZMA/XZ complete plaintext staging gap is now closed in
caller-buffer decoding and size queries, while preserving caller output on
failure and legacy overlap behavior. Strict XZ inspection uses the same bounded
workspace. The [one-shot allocation baseline](lzma-xz-one-shot-functional-baseline.md)
records the current contracts and independent evidence; allocating APIs still
return caller-owned complete output as their API requires.

The [native status](../native-lz4-zstd-status.md),
[Brotli quality matrix](brotli-quality-presets.md),
[XZ progressive baseline](xz-progressive-functional-baseline.md),
[dictionary/resource baseline](dictionary-memory-contracts-functional-baseline.md)
and [Bzip2/Snappy baseline](bzip2-snappy-streaming-functional-baseline.md)
describe the supported behavior and validation boundaries in more detail.
The [FastCover contract](../formats/fast-cover-training.md) and
[functional/measurement baseline](fast-cover-training-x86.md) cover the newly
completed selector, preparation, bounded optimizer, full standard dictionaries,
training-only finalization and CLI. This closes the earlier FastCover functional
gap while preserving explicit differences from libzstd dictionary bytes.

## Performance evidence and its limits

The following are dated competitor measurements. They are not a complete
benchmark rerun of the current production revision. A speedup over an earlier
Vort executable is not a speedup over a competing library.

| Measurement | Recorded result | Scope |
| --- | --- | --- |
| [Snappy raw decode, 2026-10-13](snappy-copy2-unroll-x86.md) | Exact-length-60 candidate/reference medians: text 1.0907x, structured 1.1014x, repetitive 1.0176x | Intel i7-10700K, ReleaseFast, libsnappy 1.1.8, fixed generated block rows. This is a local raw decoder lead. |
| [Brotli decode, 2026-10-08](brotli-head-clean-matrix-x86.md) | 12/13 rows lead; clustered q8 is 0.8632x reference throughput | Intel i7-10700K, ReleaseFast, pinned libbrotli 1.2.0-dev and executable, seven runs. The weakest workload prevents a blanket lead. |
| [Zstd JSON decode reference audit, 2026-10-13](data/zstd-reference-audit-x86-20261013.json) | Large JSON is 0.9188x reference throughput; the longer small-JSON control is 1.0139x | Intel i7-10700K, ReleaseFast, pinned libzstd 1.6.0-dev (`01b7154f`). A small-input lead does not close the large-input gap. |
| [XZ lazy encoding, 2026-10-13](xz-lazy-parser-x86.md) | Synthetic JSON is 10.70% smaller than reference at 0.812x reference throughput | Intel i7-10700K, ReleaseFast, liblzma 5.2.5 preset 1. This demonstrates a size/speed tradeoff, not all-preset superiority. |
| [LZ4HC frame encoding, 2026-10-12/13](lz4-hc-frame-baseline-x86.md) | Frames match reference bytes. Initial six-row throughput was 0.2502x...0.7408x; subsequent dictionary preparation improved its target by 1.6641x versus Vort baseline | Intel i7-10700K, ReleaseFast, liblz4 1.9.3. The initial ratios must not be presented as current results after the follow-up. |
| [FastCover complete training/output, 2026-10-24](fast-cover-training-x86.md) | All seven matched-serialized-capacity rows have higher charged Vort output. At a shared 1024-byte ceiling, JSON/small improve 6.25%/23.11%, while five families lose. Repetitive complete training is 8868.699661 ms versus 0.253797 ms | Intel i7-10700K, Zig 0.16.0 ReleaseFast, libzstd 1.4.8, seven synthetic families, quiet runs with all duration samples retained. Charged output couples each dictionary to its own library encoder; raw/prepared selection is not comparable to upstream full training. |

Zstd still needs a comprehensive current-reference matrix for both compression
and decompression; [the comparison gap](../zstd-gap.md) records historical
competitor results and subsequent internal improvements separately. DEFLATE
has locked incremental source/JSON wins against a local zlib-ng level-6
comparison, but those fixtures do not establish all-level, all-corpus parity
against zlib, zlib-ng and zlib-rs. Bzip2 has current compatibility/resource
evidence without a current cross-library throughput claim.

The latest Bzip2 replay probe decodes 40 MiB of RLE plaintext with a 4,112,120-byte
requested work peak and no complete plaintext staging. This is within its
5 MiB decoder-owned budget. Caller buffers, fixed state, stack and allocator
bookkeeping are excluded; this measurement is not process RSS or a competitor
memory comparison.

## Next work, functionality first

1. Extend the remaining HQ/quality models and LZMA custom dictionary/chunk
   range. [XZ/LZMA preset and match-finder controls](lzma-xz-encode-controls-functional-baseline.md)
   are implemented with actual mode decisions and public/streaming propagation.
   FastCover selection, optimization and full standard dictionaries are now
   implemented; the large post-selection finalization cost remains a subsequent
   profiling and performance target. Zstd signed levels and five explicit strategy controls
   are now implemented and recorded in the
   [encoding-control baseline](zstd-encode-controls-functional-baseline.md).
   Improving Brotli HQ models and global cost planning across large streams
   is subsequent quality/performance work. API numbering alone must not imply
   equivalent competitor ratio or speed.
2. Rebenchmark current public APIs against versioned competitors on shared
   text/JSON/source/log/binary/small/already-compressed corpora. Record ratio,
   encode/decode throughput, requested peak memory and RSS, cold/warm behavior,
   build/CPU provenance and weakest cases on x86-64 and ARM64. Use independent
   parallel work for implementation and verification; keep timed measurements
   free of competing build load.

The preceding Bzip2/Snappy increment passed the 46-test contract aggregate in
Debug and ReleaseFast, independent Bzip2 92-case and Snappy 255-run reference
campaigns, consumer checks, and all 134 build-check steps including wasm32-wasi.
These complete that functional increment; they do not complete this objective.
The current LZMA/XZ one-shot increment separately passes 29 contracts in Debug
and ReleaseFast, complete family and consumer suites, LZMA 316-run and XZ
75-case independent campaigns, and all 136 build-check steps.
The subsequent Zstd controls increment separately passes 431 independent
cases, exact legacy wire comparisons, 1146 ReleaseFast test executions, final
CLI and control contracts, and all 137 build-check steps. These are functional
and parameter-effect milestones, not a broad competitor throughput ranking.
The subsequent FastCover increment separately passes 45 contracts in Debug
and ReleaseFast, 822 complete Zstd ReleaseFast tests, 402 independent functional
groups, final CLI checks and all 138 build-check steps. It includes separate
quiet measurements rather than treating instrumented validation times as a
performance ranking. The long-term objective remains incomplete.
The subsequent LZMA/XZ encoding-control increment passes 100 Debug and
ReleaseFast control executions (87 named tests), 443 family/consumer executions,
the final 99/97/5/20 CLI gate, 1277 independent liblzma 5.8.4 groups and all
140 build-check steps. All twenty preset
parameter rows match the versioned liblzma 5.8.4 reference table. These are
functional, parameter-effect and resource/retry milestones; the library still
does not claim a comprehensive industry-best result.
