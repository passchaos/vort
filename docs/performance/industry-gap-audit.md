# Mainstream codec and industry gap audit

Date: 2026-10-25. The window/resource increment starts at `fa35a843`; the
subsequent [stream-count increment](stream-counts-functional-baseline.md) starts
at `dacd500a`. Their functional evidence is separate from the dated performance
rows and competitor provenance below.

Vort has broad Zig-native format coverage and some measured performance wins.
The objective of exceeding the best competing libraries in both functionality
and performance remains incomplete. Format interoperability, API coverage,
encoder quality and throughput are separate claims.

## Current functionality

| Family | Implemented public functionality | Remaining gap |
| --- | --- | --- |
| DEFLATE / zlib / gzip | Stored/fixed/dynamic/best encoding, full block decoding, dictionaries, incremental I/O, block/partial flush, runtime parameter changes and full-flush recovery | Full zlib API equivalence is not established. The project does not offer a `z_stream`/`gzFile` drop-in C ABI; that ABI is outside the active roadmap. Broader ratio/throughput evidence is still needed. |
| Zstandard | Raw/RLE/Huffman/FSE frames, dictionary sets/recovery, incremental encoding/decoding, signed levels -131072...22, all nine canonical strategy families plus legacy optimal, full-prefix BT and conditional two-pass costs, exact offset emission, work/resource profiles and canonical parameter queries, windows 10...41, explicit history up to the checked 4,294,836,222-byte coordinate ceiling, shared whole-encoder requested-heap quotas, COVER/FastCover training and seekable streams | Reference algorithm, quality and throughput parity remains unproven. Native HQ uses bounded 8/16-state searches and its own priors; canonical hash/chain logs are query metadata. Actual distance 64 MiB+8 is verified, while a maximum legal configuration is not a maximum-size matching benchmark. Wide cumulative stream coordinates and a full-length XXH64 state are implemented on 32-bit targets; physical allocation/one-shot boundaries remain. Standard dictionary finalization latency and broad encoder ratio/speed/memory parity remain open. |
| LZ4 | Block/frame/legacy formats, linked blocks, dictionaries, incremental fast/HC encoding and bounded decoding; signed native acceleration, independent chain depth and actual work profiles; HC levels 1...12 with byte-exact liblz4 1.9.3 reference gates | Native chain/lazy defaults and accelerated search differ from liblz4's single-hash fast parser. Empty raw input retains the legacy API-only empty-slice convention. Full corpus/platform fast/HC ratio, throughput and memory leadership is unproven. |
| Snappy | Raw/native framed/Xerial/Hadoop encoding and decoding, CRC32C, incremental I/O, COPY4, validated replay, work/output budgets and exact failed-call progress | Raw decoder benchmark wins do not establish framed/incremental encoder and decoder leadership across real corpora. |
| Brotli | RFC decoding, all 256 entropy block types, static/shared dictionaries, opt-in Large Window through window30 across q0...q11, legacy and stored/chunked/reusable/incremental encoding, incremental I/O, persistent BT/exact commands, optional whole-meta-block positions and complete copy lengths, per-plan command-price limits, growable commands and a whole-encoder requested-heap cap | Full reference HQ/Zopfli algorithm and quality parity remain open. q0/q1 matching is fragment-local; general non-HQ retained history is at most 65535 bytes, with separate input/history-bounded ratio candidates. Complete lengths remove sampling gaps within each admitted match candidate; finite beam, matcher candidates and entropy models can still miss globally lower costs. Lowering complete-stream comparison peaks and current ratio/speed/memory leadership remain work. |
| Bzip2 | BZh1...BZh9, legacy randomized blocks, concatenated streams, CRC validation, incremental encode/decode and bounded checked plaintext replay | Broad competitor throughput, ratio and RSS comparisons are missing. |
| XZ / LZMA | LZMA-Alone/MicroLZMA/ZIP-LZMA and raw LZMA2; XZ checks, Index/Footer, Delta and all eight BCJ filters; presets 0...9/extreme, five real HC/BT matchers, fast/normal and legacy modes, explicit nice/depth and budgets across public/incremental APIs; 4 KiB...1.5 GiB custom dictionaries, full 2 MiB compressed plaintext chunks with bounded 64 KiB payload and stored packets; progressive and bounded checked decoding | Preset parameter parity does not establish full liblzma parsing, quality or throughput parity. Normal search retains eight state/rep paths per position. Default XZ blocks remain independent 1 MiB groups, and broad encoder speed/ratio/memory parity remains unproven. |

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
| [Brotli q8 encode smoke, 2026-10-14](brotli-quality-presets.md#local-q8-smoke-evidence) | JSON/source32k throughput is 0.0491x/0.0347x reference; compressed size is 0.9661x/1.0042x reference | Intel i7-10700K, ReleaseFast, reported libbrotli version `1000009`, two fixed small inputs, best of five interleaved rounds. This historical smoke identifies an encoding cost to remeasure; later source changes prevent presenting it as the current encoder ranking. |
| [Zstd JSON decode reference audit, 2026-10-13](data/zstd-reference-audit-x86-20261013.json) | Large JSON is 0.9188x reference throughput; the longer small-JSON control is 1.0139x | Intel i7-10700K, ReleaseFast, pinned libzstd 1.6.0-dev (`01b7154f`). A small-input lead does not close the large-input gap. |
| [XZ lazy encoding, 2026-10-13](xz-lazy-parser-x86.md) | Synthetic JSON is 10.70% smaller than reference at 0.812x reference throughput | Intel i7-10700K, ReleaseFast, liblzma 5.2.5 preset 1. This demonstrates a size/speed tradeoff, not all-preset superiority. |
| [LZ4HC frame encoding, 2026-10-12/13](lz4-hc-frame-baseline-x86.md) | Frames match reference bytes. Initial six-row throughput was 0.2502x...0.7408x; subsequent dictionary preparation improved its target by 1.6641x versus Vort baseline | Intel i7-10700K, ReleaseFast, liblz4 1.9.3. The initial ratios must not be presented as current results after the follow-up. |
| [FastCover complete training/output, 2026-10-24](fast-cover-training-x86.md) | All seven matched-serialized-capacity rows have higher charged Vort output. At a shared 1024-byte ceiling, JSON/small improve 6.25%/23.11%, while five families lose. Repetitive complete training is 8868.699661 ms versus 0.253797 ms | Intel i7-10700K, Zig 0.16.0 ReleaseFast, libzstd 1.4.8, seven synthetic families, quiet runs with all duration samples retained. Charged output couples each dictionary to its own library encoder; raw/prepared selection is not comparable to upstream full training. |
| [Current Brotli q8 encode first screen, 2026-10-25](current-codec-encode-x86-20261025.md) | 9/14 smaller outputs, total bytes 2.818% lower; all fourteen throughput rows lose, geometric median-throughput ratio 0.028210x | `d4297483`, i7-10700K, ReleaseFast, CPU8, libbrotli 1.2.0-dev `558fc647` experimental Release build, fourteen frozen 64KiB prefixes, five alternating rounds in one process. Default-policy comparison uses Vort window16/reference lgwin22; no memory or all-tier claim. |
| [Current Zstd level3 encode first screen, 2026-10-25](current-codec-encode-x86-20261025.md) | 13/14 smaller outputs, total bytes 5.424% lower; all throughput rows lose. XML median is 63448.243ms versus 0.093473ms reference | Same revision/CPU/build/frozen input set, libzstd 1.6.0 `01b7154f`, five alternating rounds in one process. The full public level policy is measured; resolved primary settings are not every internal candidate. Repetition and internal profiling are needed before stable rankings or a hotspot claim. |

The subsequent [exact literal-cost increment](zstd-exact-literal-cost.md)
retains all fourteen frame hashes while reducing the measured median on every
row in one follow-up screen. XML improves from 63972.941ms to 12017.307ms in a
matched private-module comparison (5.3234x); the fourteen-row version comparison
has a 1.7946x geometric speedup. Small changes are not assigned statistical
significance, and the slowest rows remain seconds long. Independent XML
requested-heap event sequences and peak bytes are unchanged. Current throughput
leadership, broader repeated runs and competitor memory parity remain open.

The subsequent [multi-duplicate work profile](zstd-medium-huffman-profile.md)
records 1,473,017 XML and 1,039,932 MR Huffman plans despite very high
tree-serialization cache hit rates. An exact-frequency reuse experiment was
withdrawn after it avoided only 65 and 665 plans. Its passing functional tests
and instrumented timings are retained as experimental evidence, rather than
presenting that cache as a production speed improvement.
The production medium-alphabet increment instead retains the original
back-reference tie order and halves the declared core workspace capacity.
Independent ReleaseFast ELF inspection reduces the named local Huffman call
chain's static stack allocation from 75,112 to 39,240 bytes. Five-round public
controls give modest version throughput point improvements of 1.01379x XML
and 1.02820x source, while all fourteen frozen frames retain their old hashes.
XML is still 11838.393ms versus 0.142591ms reference in its new control.
This is a bounded workspace improvement, not current industry-best throughput
or whole-process memory evidence. Final tests pass 1088/1088 and build checks
169/169; the fourteen-row one-round screen is retained as a wire check.

The subsequent [winner cost bound](zstd-winner-cost-bound.md) uses a trusted
eleven-bit optimum certificate to avoid exact pricing of candidates that
cannot update the existing finder winner. Source-bound shadow evidence has
zero bound violations or false refusals, and actual pruning reproduces its
1,443,518 XML / 1,023,531 MR refusals with unchanged block hashes. Current
five-round public measurements retain all fourteen frame identities, reducing
XML/source medians to 1292.707/500.746ms (9.1578x/10.0755x versus the preceding
production controls). MR measures 971.941ms without a matched five-round
production control. The new fourteen-row throughput geometric ratio is
0.00294786x reference, with zero throughput wins. Complete native Zstd tests
pass 1092/1092. Independent old/new XML requested-heap peaks and all 282
allocator events remain identical. This advances performance while preserving
the old choices; it does not establish industry-best throughput or RSS.
The final build check passes 169/169; post-rebase winner tests and CLI help
also pass with unchanged source manifests.

The following [wide-frequency reduction](zstd-wide-frequency-reduction.md)
preserves complete frequency validation and specializes certificate analysis
with numeric u32-to-u64 widening. Focused native/x86 checks compare complete
analysis errors/fields against the old scalar path and an independent u128
oracle. A same-process microbenchmark measures approximately 4.6x faster
analysis on its two valid pools, while its immediately-invalid pool is slower
because the wide path completes all 256 entries before reporting the cap
error. That kernel measurement is separate from whole-encoder throughput.
The subsequent matched fourteen-row five-round public control preserves all
frame hashes and gives a 1.11958x geometric version speedup. XML/source/MR
medians are 993.477/385.181/780.514ms; NCI/schema-JSON point ratios are
0.99845x/0.98851x and no significance is assigned. Throughput still loses on
all fourteen reference rows (geometric ratio 0.00330414x). All recorded XML/MR
candidate work fields remain identical. Complete Zstd tests pass 1093/1093
and build checks pass 170/170. The remaining performance gap is substantial.

Zstd still needs a comprehensive current-reference matrix for both compression
and decompression; [the comparison gap](../zstd-gap.md) records historical
competitor results and subsequent internal improvements separately. DEFLATE
has locked incremental source/JSON wins against a local zlib-ng level-6
comparison, but those fixtures do not establish all-level, all-corpus parity
against zlib, zlib-ng and zlib-rs. Bzip2 has current compatibility/resource
evidence without a current cross-library throughput claim.

The benchmark aggregation's earlier eight-source/274-metric count is an
archived report observation, not a rerun of this revision. Current row counts
must come from a newly generated report. A common cross-library RSS/requested-
memory comparison harness remains missing; existing work-budget proofs and
internal memory improvements do not fill that gap.

The [encoder sample tools](codec-encode-samples.md) now retain raw alternating
Brotli/Zstd encoding rounds, input/wire identities and requested reference-file
hashes beside the existing minimum-based CSVs. Actual small-input reports and
independent validation close that recording gap. They do not provide a current
real-corpus ranking, a symmetric streaming benchmark or separate competitor
requested-heap/RSS measurements.

The latest Bzip2 replay probe decodes 40 MiB of RLE plaintext with a 4,112,120-byte
requested work peak and no complete plaintext staging. This is within its
5 MiB decoder-owned budget. Caller buffers, fixed state, stack and allocator
bookkeeping are excluded; this measurement is not process RSS or a competitor
memory comparison.

## Next work, functionality first

The latest read-only audit did not identify another reproducible gap in the
common general decoders after these increments. This is not a proof of complete
format parity. It does mean that more configuration fields are not a substitute
for the missing current competitor measurements.

1. Measure current public APIs against versioned competitors on shared
   text/JSON/source/log/binary/small/already-compressed corpora, beginning with
   x86-64 one-shot and incremental calls at 64 KiB and 1 MiB, then ARM64.
   Record compression ratio, encode/decode throughput, requested peak memory
   and RSS, cold/warm behavior, build/CPU provenance and weakest cases. Finish
   builds before timed runs. Implementation and independent verification can
   proceed in parallel; timed measurements must run without competing builds.
2. Profile and improve standard Zstd dictionary finalization, then use the
   weakest measured encoder/decoder rows to prioritize quality and throughput
   work. FastCover selection and full dictionaries are implemented, but its
   historical post-selection latency and charged-output losses need current
   confirmation. Finite HQ beams and entropy models remain quality constraints;
   API numbering alone does not imply equivalent competitor ratio or speed.
3. Continue compatibility and physical-boundary audits using reproducible
   independent fixtures. A low-priority legacy LZMA1 case is `lc + lp > 4`:
   the common property parser rejects it, while the liblzma documentation
   acknowledges old LZMA1 streams outside its own supported range. Tiny SDK
   fixtures must establish the actual wire case before implementation; XZ/LZMA2
   property limits must remain distinct. This legacy case should not delay the
   current performance matrix.

Recent functional baselines preserve actual ownership and default output:
[stored resources](../formats/brotli-stored-memory.md),
[HQ search controls](../formats/zstd-hq-search-controls.md),
[wide stream counts](../formats/stream-counts.md), and
[wide bit addresses](wide-bit-addressing-functional-baseline.md). LZMA/XZ
custom dictionaries, match-finder controls, larger chunks and FastCover training
also have separate functional evidence above. Physical allocation boundaries,
finite search states and full current competitor rankings remain unresolved.

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
The large-dictionary/chunk increment closes the previous custom-range gap:
Debug/ReleaseFast large-block gates each pass 67, the XZ family passes 143,
the versioned reference campaign passes 26 chunk/control and six dictionary
rows with fifty frozen legacy wires, and all 140 build checks pass. Actual
67,108,865-byte matching and bounded maximum-dictionary small-input behavior
are recorded separately in the [large-block baseline](lzma2-large-blocks-functional-baseline.md).
The [Zstd HQ increment](zstd-hq-functional-baseline.md) adds the remaining
canonical strategy names with real BT/cost/two-pass engines. Final Debug and
ReleaseFast HQ gates each pass 78 executions (68 named), full Zstd/consumer
checks pass 1300, the CLI passes 898/728/85/168 checks, versioned references
pass 52 functional groups and 56 old wires, and all 142 build-check steps
pass. These close the explicit-strategy slice while preserving the original
auto/default output; complete optimal-model and performance leadership remain
unproven. Fuller Brotli HQ planning and current-reference performance
measurements remain priorities.

The subsequent [Brotli complete-length increment](brotli-complete-copy-lengths-functional-baseline.md)
passes final 41/41 contracts in Debug, ReleaseFast and 32-bit x86, the complete
1253-test Brotli family, 28 public reference rows with six legacy wires, final
CLI product checks, real WebAssembly execution and 149 build checks. Initial
test/tool changes and their validation windows are retained separately.
These close the optional length-enumeration and per-plan pricing-control slice;
finite search states, broader quality planning and current competitor
performance comparisons remain open.

The subsequent [LZ4 acceleration increment](lz4-fast-controls-functional-baseline.md)
adds real miss-scan controls across raw/prefix/reusable/frame/incremental
encoding, independent candidate depth, attempted-work profiles and safe
overlapping input/output ownership. It passes 26 contracts in each of Debug,
ReleaseFast and 32-bit x86, the complete 242-test family, 37 versioned reference
rows, final CLI and real WebAssembly gates, and all 152 build checks. Native fast algorithms and
all-corpus/platform performance leadership remain unproven.

The [Brotli general Large Window increment](brotli-general-large-window-functional-baseline.md)
closes the former HQ-only format-selection restriction. The
[Zstd history/resource increment](zstd-large-history-functional-baseline.md)
removes the fixed 64 MiB history ceiling, proves an actual 64 MiB+8-byte copy
and applies a shared requested-heap quota across encoder entrypoints. Defaults
and independent old wires are retained. These are functional and resource
milestones; wider headers, legal configuration maxima and functional execution
times do not establish industry-best compression quality or throughput.
The [final verification record](br-zstd-window-verification-20261024.md) includes
156 standard Debug build checks, actual complete CLI help and post-rebase
native/x86/WebAssembly runtime gates. The cancelled extra whole-project
ReleaseFast optimization attempt is preserved separately from passing checks.
