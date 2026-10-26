# Mainstream codec and industry gap audit

Date: 2026-10-26. The window/resource increment starts at `fa35a843`; the
subsequent [stream-count increment](stream-counts-functional-baseline.md) starts
at `dacd500a`. Their functional evidence is separate from the dated performance
rows and competitor provenance below.

Vort has broad Zig-native format coverage and some measured performance wins.
The objective of exceeding the best competing libraries in both functionality
and performance remains incomplete. Format interoperability, API coverage,
encoder quality and throughput are separate claims.

For the five core user-facing families—gzip, ZIP, XZ, Brotli and Zstd—the
evidence below supports specific compatibility and optimization slices, not an
overall best-library ranking. None of gzip, ZIP, XZ, Brotli or Zstd has established
both functionality and performance above the best competing libraries. Current
priorities are Brotli/Zstd encoder throughput, a symmetric five-family
ratio/encode/decode/requested-heap/RSS matrix, broader gzip level/corpus/reference
coverage, and ZIP archive-wide interoperability and performance. New XZ streaming
ownership gates close a functional gap without supplying a competitor speed or
memory ranking. ZIP is a container whose codec and encryption
coverage must be assessed alongside archive throughput and resource behavior.

## Current functionality

| Family | Implemented public functionality | Remaining gap |
| --- | --- | --- |
| DEFLATE / zlib / gzip | Stored/fixed/dynamic/best encoding, full block decoding, dictionaries, incremental I/O, block/partial flush, runtime parameter changes and full-flush recovery | Full zlib API equivalence is not established. The project does not offer a `z_stream`/`gzFile` drop-in C ABI; that ABI is outside the active roadmap. Broader ratio/throughput evidence is still needed. |
| [ZIP container](../formats/zip.md) | ZIP32/ZIP64, local/central metadata and descriptors; Stored, Shrink, Reduce, Implode, Deflate/Deflate64, DCL Implode, Bzip2, LZMA, legacy/current Zstandard, XZ and PPMd methods; borrowed/owned and incremental I/O, match-producing adaptive Deflate64, split-volume adapters, ZipCrypto, WinZip AES and password-based PKWARE AES Strong Encryption | Certificate recipients, other Strong Encryption ciphers and encrypted central directories remain unsupported. Broad archive interoperability and a current cross-library archive ratio/throughput/memory matrix are not established. |
| Zstandard | Raw/RLE/Huffman/FSE frames, dictionary sets/recovery, incremental encoding/decoding, signed levels -131072...22, all nine canonical strategy families plus legacy optimal, full-prefix BT and conditional two-pass costs, exact offset emission, work/resource profiles and canonical parameter queries, windows 10...41, explicit history up to the checked 4,294,836,222-byte coordinate ceiling, shared whole-encoder requested-heap quotas, COVER/FastCover training and seekable streams; explicit native one-shot and persistent incremental single-frame job MT, including ZIP composition | Reference algorithm, quality and throughput parity remains unproven. Persistent owned-prefix/history/sealing/delivery/retry and ZIP contracts now have native, synchronous, Wasm32, saved-wire and fixed-libzstd functional evidence; existing candidate and seekable-frame MT remain separate capabilities. Native HQ uses bounded 8/16-state searches and its own priors; canonical hash/chain logs are query metadata. Actual distance 64 MiB+8 is verified, while a maximum legal configuration is not a maximum-size matching benchmark. Wide cumulative stream coordinates and a full-length XXH64 state are implemented on 32-bit targets; physical allocation/one-shot boundaries remain. Standard dictionary finalization latency and broad encoder ratio/speed/memory parity remain open. |
| LZ4 | Block/frame/legacy formats, linked blocks, dictionaries, incremental fast/HC encoding and bounded decoding; signed native acceleration, independent chain depth and actual work profiles; HC levels 1...12 with byte-exact liblz4 1.9.3 reference gates | Native chain/lazy defaults and accelerated search differ from liblz4's single-hash fast parser. Empty raw input retains the legacy API-only empty-slice convention. Full corpus/platform fast/HC ratio, throughput and memory leadership is unproven. |
| Snappy | Raw/native framed/Xerial/Hadoop encoding and decoding, CRC32C, incremental I/O, COPY4, validated replay, work/output budgets and exact failed-call progress | Raw decoder benchmark wins do not establish framed/incremental encoder and decoder leadership across real corpora. |
| Brotli | RFC decoding, all 256 entropy block types, static/shared dictionaries, opt-in Large Window through window30 across q0...q11, legacy and stored/chunked/reusable/incremental encoding, incremental I/O, persistent BT/exact commands, optional whole-meta-block positions and complete copy lengths, per-plan command-price limits, growable commands and a whole-encoder requested-heap cap | Full reference HQ/Zopfli algorithm and quality parity remain open. q0/q1 matching remains fragment-local. Explicit Large Window q2+ and legacy non-fragment history grows to the advertised bound, while shared near matching retains its 65535-byte suffix. Far matching still uses bounded chain/stride candidates. Complete lengths remove sampling gaps within each admitted match candidate; finite beam, matcher candidates and entropy models can still miss globally lower costs. Lowering complete-stream comparison peaks and current ratio/speed/memory leadership remain work. |
| Bzip2 | BZh1...BZh9, legacy randomized blocks, concatenated streams, CRC validation, incremental encode/decode and bounded checked plaintext replay | Broad competitor throughput, ratio and RSS comparisons are missing. |
| XZ / LZMA | LZMA-Alone/MicroLZMA/ZIP-LZMA and raw LZMA2; XZ checks, Index/Footer, Delta and all eight BCJ filters; presets 0...9/extreme, five real HC/BT matchers, fast/normal and legacy modes, explicit nice/depth and budgets across public/incremental APIs; 4 KiB...1.5 GiB custom dictionaries, full 2 MiB compressed plaintext chunks with bounded 64 KiB payload and stored packets; progressive and bounded checked decoding; bounded one-shot and persistent incremental workers with owned input, delivery credits and ZIP failed-progress accounting; explicit Block Header sizes/CLI flag | Preset parameter parity does not establish full liblzma parsing, quality or throughput parity. Normal search retains eight state/rep paths per position. Default XZ blocks remain independent 1 MiB groups and incremental is serial unless enabled. Default unsized blocks make liblzma 5.8.4 MT decoding use serial direct mode. Native/x86 ownership and real fallback validation are functional evidence; all-preset/corpus/platform speed, ratio and memory leadership remain unproven. |

The [Brotli metadata increment](brotli-metadata-functional-baseline.md) implements
the complete RFC single-block range 0...16 MiB, shared exact header bounds and
unchanged plaintext/history behavior across stored/planned/static/HQ and
incremental APIs. The root and codec expose the same maximum constant. A real
static reusable alias bug is fixed by capturing metadata, input and descriptors
before output clear; pre-snapshot OOM preserves old output/state, while later
errors keep their existing contract. Temporary metadata pointers are cleared
after use. Native Debug/ReleaseFast and x86 ReleaseFast each pass 130/130
executions (30 metadata plus 100 public-root tests). Each native/x86 reference
campaign verifies 194 target encodes, 18 reference streams, 84 pre-allocation
rejects and 10 malformed cases with 307 commands; target wires/headers/progress
agree across architectures. The known system 1.0.9 defect observation retains
its actual loaded common-library provenance and is not an isolated reference
ranking. A legacy gate matches 384/384 complete old/new wires, 192 per target,
within the old supported range, with 768 independent full-content checks. Its
representative quality/API coverage is not an exhaustive output guarantee.
Codec `e49fce24` and the subsequent test-only `b502fc50` source epochs remain
separate; the latter corrects an obsolete length-65,537 rejection fixture.
The complete native ReleaseFast family reports 1430 passed and one skipped out
of 1431; the skipped 32-bit host-overflow gate is outside the metadata/root
filter. Its separate actual x86 ReleaseFast run passes 20/20 executions including
imports. Final build verification passes 180/180 on the test-only revision,
while the codec and external runtime reports retain their `e49fce24` identity.
Event emission still borrows caller bytes and retains metadata-sized pending
output; no constant-memory or performance-lead claim follows. General
long-window match history and broader encoder quality remain separate work,
and dated performance results are not refreshed by this increment. Subsequent
functional candidates are retained Large Window history, core Zstd magicless
APIs and bounded XZ worker encoding, each with separate validation requirements.

The [non-HQ Large Window history increment](brotli-large-history-functional-baseline.md)
grows q2+ and legacy non-fragment retained
history with accepted data up to the advertised window, keeping q0/q1 fragment
history and the standard-format policy unchanged. A dedicated sampled augmenter
uses three-byte anchors, 512-candidate chains and bounded strides, while near
matching retains its 65,535-byte suffix. Baseline/literal proposals and strict
full-wire selection remain in place. Actual growth and branch rollback buffers
use the existing allocator authority, without a complete-search guarantee or
memory/throughput lead. Final filtered contracts pass 27/27 on three configurations,
and native/x86 matrices each pass 450/450: 423 stream and 27 one-shot cases.
The reported far subset is 324, with window-boundary cases classified separately;
300 new frames per target are independently decoded. Initial nine legacy-fast
64 KiB failures were fixed by selecting the full planner, without reducing
budgets or changing sampling. Wires/progress/history tails agree across targets;
geometric capacity and memory-profile fields remain distinct. Final narrow and
reference results bind `2f421462`, which retains both the original ratio and new
history alternatives. On two same-input examples, q2
incremental output shrinks 70,270 to 70,039 bytes but requested peak increases;
q8 chunked output changes 70,051 to 70,050 bytes with the same requested peak.
The earlier `18a7fc6d` q8 candidate's 70,053-byte result remains recorded,
alongside the correction. These do not establish universal ratio/memory gains.
Final legacy
refresh matches 216 main and 120 reset cases against old saved wires, with
336 new streams independently decoded and no old rerun. CLI help passes 7/7;
the host-overflow gate passes separately on x86. The complete final ReleaseFast
family at corrected codec `2f421462` reports 1432 passed and one skipped out of
1433; build checks pass 182/182. Later test-only `2adbe60b` adaptive coverage
passes in all three 27/27 filtered scopes, adding real long history, split/grid
snapshots, exact/below budgets and targeted growth-OOM retry. That 1,902-file
test manifest is separate from the unchanged 1,901-file codec/runtime manifest;
the external/full reports are not rewritten as new test-only executions.
Earlier metadata and Large Window
results retain their own source epochs. The encoder also covers physical far
copies inside non-fragment one-shot input; those are distinct from retained
old-block matches. Geometric capacities may exceed logical history/window
lengths, with all real allocations charged. Ordinary no-shared-dictionary
q11/q10 inheritance remains scoped separately from prepared dictionary routes.

The [Zstd magicless core increment](zstd-magicless-functional-baseline.md) adds
explicit data-frame format selection,
options-aware decoding/inspection and incremental/reusable support, preserving
standard defaults. Magicless data concatenation retains ordinary frame fields;
skippable, seekable and ZIP/TAR/CPIO special formats remain standard-only.
ZFS directly borrows its declared magicless payload, removing compressed staging
without removing decoded-output allocation. Final three-target checks pass
130/130 (19 core/layout plus 111 public-consumer/root), two reference matrices
each pass 609/609 and the complete ReleaseFast Zstd family passes 1104/1104.
Focused ZIP checks pass 44/44 and CLI help 7/7. Final source is `eb6cb40d`;
cross-target outputs/headers/progress agree, while working peaks and target paths
retain their own scopes. A malformed
u18-shift raw fixture and an incorrect one-shot dictionary-error expectation
were repaired without changing production semantics. A bounded old-public-API
standard parity harness matches 96/96 wires and 192 independent full-content
decodes without format backport. Final build checks pass 185/185 on stable
feature source. No throughput/RSS gain is assigned, and earlier Zstd/ZFS
evidence keeps its epoch. The subsequent bounded XZ parallel increment has
separate ownership and compatibility evidence below.

The [parallel XZ increment](xz-parallel-functional-baseline.md) adds persistent
bounded block workers through existing one-shot APIs, with caller I/O that safely
coordinates OS workers, logical in-flight limits and a shared operation heap
quota. Native Debug and ReleaseFast each pass 138/138 executions (27 core plus
111 root/consumer), while single-thread ReleaseFast passes 25 with two genuine
thread-dependent skips out of 27. The earlier x86 full run passes 137/137;
a separate later preset subset passes 11/11 including imports and exercises all
20 presets. Each native/x86 liblzma 5.8.4 matrix passes 121/121, and 109/109
cross-target artifacts agree, including 13 upstream-generated streams. The old
public-API default/null gate matches 72/72 old/new wires with 144 independent
full-content and exact-consumption checks. A real Wasm runtime gate verifies two
multi-block fallback calls and two quota rejections with `std.Io.failing` and no
coordination imports. Complete XZ/consumer suites pass 264/264 executions
(161 plus 103), and the combined family/check/help command succeeds with
197/197 build steps and actual CLI help execution. A separate final check
passes 190/190 cached steps including the later Wasm hook; its unfiltered root
test binary is compiled, not executed by `check`. Output/Index staging remains
complete until caller publication; Into
uses that budget-owned staging directly. Worker stacks, caller output and Io
runtime private overhead are outside the heap ledger. Target/small-call serial
fallbacks obey the same quotas, and spawned workers join on failures. At that
epoch headers omit declared block sizes, so liblzma 5.8.4's MT decoder uses
serial direct mode for those valid streams; full MT feature parity is not established.
Incremental XZ remains serial; no encoder timing, RSS or throughput/memory-lead
result is assigned, and past performance epochs
remain unchanged.

The subsequent [XZ Block Header size increment](xz-block-sizes-functional-baseline.md)
adds explicit `include_block_sizes = false`
to one-shot and incremental options, independent of parallel encoding. True
declares exact LZMA2 payload/original plaintext sizes and stages a complete block
payload through the supplied allocator, charged to the parallel quota when
enabled. It shares header/Index framing across destination and incremental
routes. Direct block
append now captures overlapping input before relocation in both modes, while
default non-aliasing writes keep their prior allocation path. Both size fields
remove a necessary liblzma MT header condition. Native Debug/ReleaseFast and
actual x86 ReleaseFast each pass 134/134 executions; native/x86 reference
matrices each pass 129/129, with 124 matching artifacts including 13 upstream
MT-encoder inputs. For a specific 262177-byte/nine-block stream, a separately
compiled counter reference completes nine jobs on three worker identities with
peak active calls three; unsized and low-threading-memory controls each complete
nine direct blocks with zero worker calls. Default preservation matches 72 new
wires to saved bytes with 72 new full-content/exact-consumption checks and no
old rerun. Real Wasm checks two sized successes, two quota rejections and a
default control. Final Debug XZ/consumer suites pass 276/276, while CLI contracts
pass 10/10 and actual CLI-module cases 32/32. The pre-CLI family/check/help command
passes 202 steps; final flag help/check passes 201, and final compile-only check
passes 195 cached steps. Global root tests are not executed by check. Final
feature `63a7dfa2` and its 2011-file manifest remain separate from the 118-file
probe campaign. Only parallel options provide a whole-operation heap cap;
incremental pending bytes and inner matcher limits do not cap complete payload
storage. No throughput, RSS or full MT feature-parity result is assigned, and
earlier evidence stays historical. The subsequent persistent incremental slice
has separate completed evidence below; broader performance remains open.

The [persistent incremental XZ parallel increment](xz-incremental-parallel-functional-baseline.md)
has independent functional validation. Explicit parallel options retain a stable
budget-owned worker queue, own accepted plaintext and keep partial/queued/active/
completed/delivering credits until final Block delivery. Header startup,
recoverable admission/publication errors, sticky worker/spawn/heap errors and
exact failed-step progress are distinct contracts. Profiles are published only
at public touchpoints, snapshots separate Index publication from delivery, and
done/reset retain charged storage. Serial/parallel mode changes account all
retained capacities transactionally, while Index growth remains block-count/
heap bounded. ZIP's parallel-XZ bridge accounts failed input/CRC/encryption/output
progress once. Native Debug/ReleaseFast and actual x86 ReleaseFast each pass
129/129 executions; single-thread Debug passes 35 with one genuine partial-spawn
skip. Native/x86 final external matrices each pass 84/84 (71 incremental plus
13 upstream decode), observe peak three active encoder workers, 539/528 input
overwrites with queued/active jobs and two actual moves carrying jobs per target.
Per-row completion before return remains valid. Real Wasm fallback passes its
three-step runtime gate. Complete Debug XZ/consumers pass 302/302 (199+103),
family/check/help 208 steps and final compilation check 200 steps. Initial
compile/QA/tool failures and corrected assertions retain their logs and distinct
epochs. Feature `8f4ae62f` does not rewrite the final 133-file tool closure or
frozen probe identities; post-rebase evidence is separate. No CLI thread options,
throughput/RSS or industry-best claim is assigned. Earlier one-shot/header/MT
reference and performance epochs stay historical.

The [ZIP contract](../formats/zip.md) lists its entry methods and encryption
limits. Split incremental writing already removes
the owned split writer's whole-archive staging requirement. These container
features do not establish archive-wide competitor performance leadership.

The [native Zstd parallel-frame increment](zstd-parallel-frame-functional-baseline.md)
has independent functional validation. Explicit one-shot jobs build one standard/
magicless frame through stable bounded queue state, with actual-span admission
and independently initialized job priors. Coordinator interpretation/re-emission
preserves global physical distances, recent offsets and Huffman/FSE dependencies,
one header/last Block/checksum and a checked raw upper bound. Complete output and
replacement staging use a shared heap cap, intersected with the native total cap;
caller publication waits for joined work and retains alias/failure contracts.
Actual wire Block counts and private worker work are distinct from planned spans.
Existing candidate threads and independent seekable frames are separate APIs.
Native Debug/ReleaseFast and actual x86 ReleaseFast each pass 122/122 filtered
executions (35 core plus 87 root/consumer); single-thread passes 34 with one
partial-spawn skip. Native/x86 external campaigns each pass 111/111: 92 complete
target frames, nine expected encoder rejects, six MT-configured reference inputs
decoded by Vort and four dictionary rejects. Actual target worker peak is three;
an independent parser observes a 1248-sequence Block. Real Wasm covers four
fallback/resource groups in five build/run steps; complete native Zstd ReleaseFast
passes 1128/1128 and final check/actual help 207 steps. Initial stack crashes are
reproduced against the original ELF and corrected with opt-in heap workspace,
in-place initialization and unchanged planner/default serial behavior. Fixture,
test-counter, semantic and raw-ID-zero probe corrections retain separate failed
epochs. Internal published-job diagnostics remain distinct from successful
caller emitted counts; observed retained job-output capacity is not total active
output peak. Feature `fb441359`, shared heap `a0a3eb0e` and helper `d948c9da`
retain separate scopes, and no earlier Brotli/Zstd performance data is refreshed.
Persistent incremental single-frame jobs, CLI controls and industry-best
speed/ratio/memory remain open.

The [incremental single-frame Zstd parallel class](zstd-incremental-parallel-functional-baseline.md)
owns accepted plaintext plus immutable
history prefixes, preserves global Count/window and original native job settings,
and defers a full job's finality until valid lookahead/flush/finish. Ordered
transactional re-emission keeps actual frame entropy/repcodes, while job-final
caller delivery releases credit and commits native emitted statistics. The owner
retains bounded rolling history/jobs and one front output unit, with cumulative
input/output, current-frame job and requested-heap limits. Reset/next-frame,
skippable/dictionary and exact sticky/recoverable progress are distinct contracts.
ZIP null mode retains old policy; explicit mode forwards the new owning class
and failed CRC/encryption/output bridge. Native Debug/ReleaseFast pass 156/156
executions each, synchronous fallback passes 62 with one inapplicable skip,
Wasm32 runs four real operations, the fixed-libzstd matrix passes 171/171 and
all 92 saved one-shot wires remain byte-identical. Old one-shot reference and
performance epochs remain unchanged; no industry-best speed, ratio or RSS
result is assigned.

The earlier [Deflate64 streaming increment](deflate64-stream-functional-baseline.md)
closes ZIP method 9's stored-only incremental encoding gap. Its public raw
`IncrementalEncoder` and ZIP adapter default to adaptive fixed/stored output,
128 KiB planning blocks, 65,536-byte history and matches through 65,538 bytes.
Explicit stored mode disables matching; total input and pending-output limits
remain caller controls. Failed calls preserve actual committed progress through
ZIP encryption accounting before the writer becomes poisoned.
At that revision, dynamic-Huffman Deflate64 encoding and preset dictionaries
remained open. Its recorded core contracts
pass 183/183 in native Debug, native ReleaseFast and x86, including 4 MiB across
1024 blocks and warmed reuse without further heap growth. Native Debug/x86 ZIP
contracts each pass 41/41 on stable source. Native and x86 independent Info-ZIP
UnZip 6.00 campaigns each check 28 raw/ZIP artifacts and 42 members with
58 commands, verifying actual length 65,538 and distance 65,536 plus identical
wires across two chunk
patterns. The complete ZIP suite passes 1988/1988 on stable source after an
existing stored-only fixture explicitly selects stored mode; this corrects its
old-default assumption without changing production code. The final build check
passes 176/176 on the source snapshot after that test fix. These results
do not establish complete interoperability, measured peak-memory leadership or
competitor throughput parity.

The subsequent [Deflate64 one-shot reuse](../formats/deflate64.md) closes the
former 258-byte match and 65,535-byte distance boundaries for allocating,
caller-buffer and append encoding. It borrows 128 KiB input chunks and preceding
64 KiB history, reusing the streaming matcher/block primitives through distance
65,536 and length 65,538 without complete-input or token staging. Private checked
u128 whole-candidate sizing and strict admission against the original global
stored representation preserve the established encoded bound. Only a winning
candidate narrows to physical usize allocation size; an oversized losing fixed
candidate cannot prevent a representable stored result. `nice_length` widens to
u32 with default 128 and preserves the 0...2 first-match stop behavior. Output
atomicity and stored-only APIs remain intact, while adaptive encoded bytes may
change. That increment did not change incremental policy; dynamic encoding and
preset dictionaries remained open at its revision. The
[one-shot baseline](deflate64-one-shot-functional-baseline.md)
records final codec contracts at 99/99 on native Debug, native ReleaseFast and
x86, complete ZIP tests at 1992/1992, build checks at 176/176 and CLI help at
7/7 on stable final source. Native/x86 external campaigns each verify
48 artifacts, 64 member plaintexts and 90 commands; full input/wire/progress
manifests agree across targets and with the pre-widening candidate. The
preceding streaming milestone's 183-test aggregate is a different import/test
scope, not this increment's count. Same-default encoded sizes improve from
576 to 6 bytes on repeated 65,539-byte input and from 131,087 to 69,098 on a
random 64 KiB prefix plus its duplicate. Tiny16/Pattern12079 total allocation
requests instead rise from 131,379/205,181 to 393,234/393,269 bytes. These
archived cumulative requests are not a final-revision retrace, peak or RSS
measurement; smaller wires do not establish broad memory or performance
leadership.

The [Deflate64 index-capacity increment](deflate64-index-capacity-x86.md) keeps
the 32,768-entry hash-head table and sizes the previous-link ring to the required
local span, growing through the full 65,536-entry ring. All seven one-shot wire
identities and the 4 MiB stream remain unchanged. Untimed measurements of codec
peak requested live bytes, including returned output, change Tiny16 from
393,234 to 131,154, Pattern12079 from 393,262 to 196,654, Random4097 from
397,318 to 167,942 and Random16387 from 409,608 to 278,536. Empty and large
inputs retain their previous peaks. An earlier allocate-before-free candidate
raised the stream peak from 462,909 to 593,981 bytes; the final remap path
records two successful remaps and restores that stream peak to 462,909, with
stable warmed capacity. Refused remaps still use safe allocate-before-free
growth. These values describe logical allocator requests, excluding backing
allocator physical transients, input generation, collectors and decoding;
they are not RSS or a cross-library memory lead. Final codec contracts pass
100/100 in native Debug, native ReleaseFast and x86; the matcher reference
contracts pass on all three targets. Focused ZIP contracts pass 44/44, the
complete ZIP suite passes 1993/1993, build checks pass 177/177 and CLI help
passes 7/7 on stable final source. Native/x86 independent campaigns verify
96 artifacts and 128 member plaintexts in total, with unchanged full wire/input/
progress manifests against the prior revision.

Three alternating process pairs time one-shot encode, full-output checksum and
free through the plain allocator. Per-case geometric point ratios are 1.054839x
for Tiny16 and 1.086759x for Random4097, but 0.980039x/0.991585x/0.990310x/
0.968085x/0.975022x for empty/Pattern12079/Random16387/Repeat65539/Distance131072.
The aggregate is 1.005803x without statistical significance or a broad throughput
claim. A separate fixed-slot specialization was withdrawn after unfavorable
repeat points; the retained resource implementation is the simpler variable-mask
version, and its source/executable evidence remains separate from that experiment.
Dynamic encoding and preset dictionaries were still future work for that
index-capacity revision; its timing is not a rerun of the subsequent encoder.

The [Deflate64 dynamic-Huffman increment](deflate64-dynamic-functional-baseline.md)
adds explicit dynamic streaming blocks,
exact stored/fixed/dynamic adaptive arbitration, a dynamic-block snapshot count
and fixed/dynamic one-shot chunk selection under the unchanged global stored
bound. It shares full-range match decisions and bounded histogram/RLE plans
without token staging, at the cost of two streaming and three one-shot match
traversals. Final native Debug/ReleaseFast/x86 codec checks each pass 108/108,
RLE checks 4/4 and focused ZIP checks 44/44. The final ReleaseFast complete
ZIP/codec suite passes 2000/2000, checks 177/177 and CLI help 7/7. The earlier
full Debug oracle aggregate reports 1998 passed and one skipped; its
ReleaseFast-only LZMA-distance fixture is covered by the final suite.
Final native/x86 independent campaigns each verify 80 artifacts, 112 member
plaintexts and 154 commands, including 35 dynamic blocks and 4,600,430 parsed
dynamic bits; full manifests/results agree across targets and with initial
campaigns. Source/report identities retain their correct revisions.
An untimed resource comparison retains six
one-shot wires and all 4 MiB stream ledger values, while the distant fixture's
wire changes from 69,098 to 65,633 bytes. Its requested peak changes from
462,314 to 458,849 by the same output reduction, with non-output allocation
payload unchanged at 393,216 bytes. This is not dynamic-tree stack/RSS or
throughput evidence. Preset dictionaries and broad quality/platform/performance
comparisons remain open; the preceding index-capacity timing keeps its own epoch.
ZIP method 9 has no preset-dictionary ID, so future dictionary support needs an
explicit compatibility contract. The dynamic slice is complete, while the
industry-best objective and Brotli/Zstd throughput priorities remain open.

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

The [scalar single-sequence cost increment](zstd-single-sequence-cost.md)
replaces only the bound's one-sequence table price with exact closed-form bit
sizes and original mask availability. Candidate decisions and all fourteen
frame identities remain unchanged. A matched accepted five-round public
control gives a 1.08205x geometric version speedup: XML/source/MR medians are
817.419/315.072/656.416ms. Four rows have small negative point differences,
without a significance claim. Throughput still loses on all fourteen reference
rows (geometric ratio 0.00354679x). The first compiler-overlap run is retained
but excluded. Complete Zstd tests pass 1096/1096 and build checks 171/171;
independent XML requested heap and all 282 allocator events remain unchanged.
This increment also safely rejects extreme offsets before numeric bias overflow.

The [frequency-merge increment](zstd-frequency-merge.md) combines four-stream
frequency output and active-symbol counting in one traversal. A matched
fourteen-row five-round production control preserves all frame identities
and gives a 1.15165x geometric version speedup: XML/source/MR medians become
586.070/224.770/499.548ms. Samba/SAO point ratios are 0.97209x/0.97323x, with
no statistical-significance claim. Throughput still loses on every reference
row (geometric ratio 0.00396409x). All XML/MR candidate work fields remain
unchanged. Complete native Zstd tests pass 1098/1098 and build checks 172/172.

The following [paired-anchor cache experiment](zstd-paired-anchor-experiment.md)
preserves the original suffix pairing and all candidate pricing traces. Its
five-round candidate-stage controls, including allocation/preparation, give
only 1.01385x...1.01885x with counted diagnostics and 1.01892x...1.02380x in a
temporary build that does not export Work. Each 64 KiB input needs 393,174
bytes of additional storage. It is retained as an explicit diagnostic;
default encoding remains uncached and all fourteen default frame identities
stay unchanged. Complete native Zstd tests pass 1101/1101 and build checks
172/172. This experiment does not establish a new production throughput lead.

The following [work-accounting separation](zstd-work-accounting.md) gives
normal internal pricing a comptime untracked type while preserving all
histogram checked admission and public diagnostic fields. Native/x86 cost
objects shrink by 464 bytes. The fourteen-row five-round version speedup point
is 1.01083x, including an initial MR slowdown of 0.96985x. Three supplemental
alternating process pairs give MR/XML/source point ratios of
1.01230x/1.02875x/1.02236x; no significance or broad ranking is assigned.
All fourteen frame identities and every tracked XML/MR work field remain
unchanged. Throughput still loses on every reference row (geometric ratio
0.00393447x). Independent requested-heap/event sequences are unchanged;
complete Zstd tests pass 1102/1102 and build checks pass 172/172.

The subsequent [incremental total-frequency experiment](zstd-aggregate-totals-experiment.md)
passed its native/x86 candidate correctness checks and preserved all fourteen
frame identities, but its public throughput geometric version ratio was
0.988277x while cache objects grew by 1040/1032 bytes. Its approximately 1%
tracked-stage improvements did not establish a public speed benefit. The
candidate has been withdrawn and runtime source restored to `6b262754`;
the recorded experiment is not a new production throughput improvement.

The [native Brotli q8 candidate profile](brotli-q8-candidate-profile.md) now
records the actual public lazy/optimal/context/split chain. Fourteen frozen
64 KiB inputs, each with five normal/profile pairs, retain all previous output
identities and pass independent event/exclusive-time validation. Mozilla's
instrumented preferred/context preparation is 69.792ms of a 100.994ms outer
call, whereas the source control is 7.258ms of 37.488ms. Each materializes
eighteen common wire candidates, with different winning plan families. These
stage medians are non-additive and do not attribute all preferred time to one
subroutine. Separate ordinary q8 measurements still lose all fourteen
reference throughput rows (geometric ratio 0.0282557x); 9/14 outputs are
smaller and total bytes remain 288,091/296,445. This is a diagnostic milestone,
not an encoder performance lead. Three-target contracts pass 25/25; the full
Brotli family reports 1420/1421 with one skip, and build checks pass 173/173.

The following [shared context-score experiment](brotli-context-score-experiment.md)
tested a 128-entry full-frequency tree memo shared across one immutable
analysis. Its fourteen-row public screen gives a version throughput point ratio
of 0.992884x; three alternating old/new process pairs give 0.995366x. These
observations do not establish a public speed benefit, statistical significance
or a stable regression. All fourteen candidate output identities/settings and
all seventy profiles' common wire candidates and selection outcomes remain
unchanged. The shared cache has been withdrawn from default entrypoints,
restoring the original mode-local cluster memo and uncached baseline/suffix
policy. Restored-default Debug and x86 context/q8 contracts pass 76/76; complete native
Brotli tests pass 1421 with one skip, and final build checks pass 173/173.
Fourteen restored ordinary wires/settings and seventy profiled wires/candidate
decisions retain their previous identities with zero compiler observations.
Candidate measurements and earlier published reference results retain their
own revisions; they are not refreshed performance evidence for the restored
runtime. The restored ordinary screen is 0.988794x versus the old executable,
and three supplemental alternating pairs aggregate to 0.986497x. The negative
point differences are retained without statistical-significance claims or a
claim of acceleration; compiler overhead from the extracted normal helper
remains a bounded follow-up. Its first-screen throughput/reference geometric
ratio is 0.0271625x with zero wins. The industry-best functionality/performance
objective remains open.

Actual recent-distance and context-proposal diagnostics are retained. In the
experiment's instrumented Mozilla run, their separate medians are 0.109829ms
and 73.876ms, respectively, within a 105.606ms outer call. The lazy/optimal
proposal searches record baseline medians of 0.074856/0.075876ms, suffix
medians of 17.061/18.228ms and cluster medians of 17.856/19.835ms. These are
independently computed stage medians with nested tree/Huffman/prefix scopes;
they must not be summed or interpreted as ordinary-code speed improvements.
The finer profile adds clock reads and shape/count observations, so its
overhead and the ordinary public comparison remain separate evidence.

The [dense Brotli Huffman increment](brotli-dense-huffman-x86.md) extends exact
two-queue length construction to 129...256 active symbols, preserving the old
package-merge result and falling back when the natural tree exceeds fifteen
bits. Its fourteen frozen 64 KiB ordinary q8/generic rows retain every wire
identity and setting against `f642d0d8`. The first-screen version throughput
geometric point ratio is 1.230502x: Mozilla's median changes from 100.170 to
59.873ms and SAO's from 158.804 to 92.543ms. Three subsequent alternating
old/new process pairs aggregate to 1.214583x, with stable inputs, reference
files and source, and zero observed compiler processes. Webster's three point
ratios are 0.982081x/0.991895x/1.028495x; the evidence does not imply every
repeat wins or statistical significance. Reference throughput still wins all
fourteen first-screen rows, with a Vort/reference geometric ratio of 0.032977x.

Complete prefix-length microbenchmarks include frequency copies and scatter,
with all 32 inputs per family checked against exact reference arrays before
timing. Dense ties/mixed point ratios are 16.340x/8.518x, while depth-fallback
and medium controls are 0.959412x/0.983286x; the slower controls remain part of
the evidence. Seventy real q8 profiles preserve candidate/selection outcomes
and tree/search work counts; only the construction dispatch changes. Mozilla's
lazy/optimal tree-length medians change from 20.440/22.244 to 2.193/2.416ms,
and their 796/830 dense package-merge calls become zero. The source control's
length medians instead change from 0.505578/0.549230 to 0.529187/0.575979ms.
These instrumented, independently computed nested medians are non-additive
and cannot substitute for ordinary throughput measurements. Focused dense
contracts pass 21/21 on native Debug, native ReleaseFast and x86; the complete
Brotli family passes 1423 with one skip, and build checks pass 174/174 on stable
source. This is a bounded encoder improvement, while all-quality, all-platform
ratio/speed/memory leadership and the industry-best objective remain open.

The [literal-alphabet increment](brotli-literal-alphabet-x86.md) replaces large
supported-symbol insertion ordering with stable byte radix passes at a threshold
of 64, preserving complete unsigned frequencies and ascending-symbol ties. An
earlier PDQ candidate was rejected before public measurement: its 64/96/128
random-family point ratios were 0.401656x/0.476636x/0.527122x. On the same frozen
micro input pools, radix gives 2.259250x/3.382456x/4.332092x on those families,
7.600826x on dense mixed input and 2.676835x on sparse dense support. The small
16-symbol control remains slower at 0.932553x; these complete collection/rank
and checksum timings do not replace public encoding measurements. The declared
key/count scratch totals 5 KiB, without a measured RSS or full-stack peak claim.

Fourteen ordinary 64 KiB q8/generic rows against `d689a411` retain all settings
and wire identities. The first-screen version throughput geometric point ratio
is 1.060756x, with 11/14 positive rows; Dickens/Reymont/NCI retain point ratios
of 0.999098x/0.998364x/0.981048x. Reference throughput still wins all fourteen
rows, with a Vort/reference geometric ratio of 0.034437x. Three alternating
old/new process pairs aggregate to 1.062096x; their corpus point ratios are
1.064995x/1.052964x/1.068392x. Individual repeats remain mixed: Dickens,
Reymont, XML and schema retain sub-1 points, including 0.979612x/0.999681x/
0.982929x/0.980425x. All settings/wires, inputs and reference files remain
identical on stable source with zero observed compiler processes. No
statistical-significance or every-repeat-win claim is assigned. Seventy profiled
calls retain every non-time proposal/detail count and wire/selection outcome.
Mozilla's lazy/optimal alphabet-stage medians change from 4.984463/5.291635 to
1.360870/1.691083ms, SAO's from 11.365281/11.284848 to 1.718895/1.759234ms,
and the source control's from 0.584796/0.629856 to 0.295514/0.331832ms. These
nested, separately computed instrumented medians are non-additive. Three
platform module contracts pass their complete internal matrices, Debug/x86
context contracts each pass 76/76, the full Brotli family passes 1424 with one
skip, build checks pass 175/175, and legacy profile/CLI checks pass 10/10 and
7/7 on stable source. This remains a bounded q8 encoder result; all-quality,
all-platform performance and the industry-best functionality/performance
objective remain open.

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

### Zstd level-3 XML hotspot dissection, 2026-10-26 (uncommitted investigation)

A read-only profiling pass on the frozen silesia-xml 64 KiB prefix
(`e32aff2b...`, i7-10700K fixed CPU 8, Zig 0.16.0 ReleaseFast, libzstd 1.6.0
`01b7154f`) pinned the level-3 one-shot encode at a stable 553-558 ms median
(11 alternating pairs each, reference 0.13 ms; output/checksum unchanged at
5,078 bytes / checksum 11177). The entire cost sits in one candidate family,
`zstd.emitMultiDuplicateMatchCompressedBlockWithFirst`: 28.6% of cycles in
`huffman.treeCodeLengthsMediumKnownActive` (29,499 exact length-limited
package-merge plans per block, 1,085 distinct trees, 28,413 repeated
bit-count keys), ~4% package-merge sorting, ~2.5% plan finalization, ~51%
finder/pricing self time; the frame is 1,473,017 winner-cost queries of
which 1,443,518 are rejected by the weighted certificate (0 violations).

Two output-preserving experiments were evaluated and withdrawn without
committing: (1) maintaining cut-histogram totals and witness deltas
incrementally instead of two 256-entry AVX scans gave 0.96-1.14x across
variants and a clean 0.985x median - the vectorized scans are not the
bottleneck and per-byte stamp bookkeeping costs more than it saves; (2) a
heap-backed u32 wide `DuplicateMatchIndex` extending the paired index from
65,535 to the 128 KiB block maximum eliminated 128 suffix hash rescans but
was a 1.00x wash on XML (553 ms), needs ~1.3 MiB retained scratch, and the
global alternating pairing changes multi-duplicate wire bytes on
64-128 KiB blocks versus the fresh-pairing rescan. An intermediate variant
without winner-bound pricing on indexed rows regressed catastrophically
(indexed rows each ran an exact Huffman plan); the prune-bound cache is
required for any indexed wide finder.

The next evidence-aligned target is the exact package-merge count, not
hash rescanning: 96.3% of plans reproduce the previous bit-count vector, and
508,945 bound checks already hit the same-support zero-negative-delta tight
case. A tie-safe reuse certificate that proves the prior length vector
(not merely its weighted cost) remains optimal for the new frequencies
could remove most of the ~36% tree-construction share; it must reproduce
package-merge tie-breaking byte-for-byte.

**Resolution, same day.** The iterative multi-duplicate family is now gated
behind the richer 96-state mixed-search budget when no precomputed paired
index exists (`multi_duplicate_unindexed_required_search_budget`). Blocks up
to 65,535 bytes still use the cheap bounded u16 index at level 2+, preserving
crafted inputs whose winner is the multi-sequence block (a two-segment
8+8 KiB duplicate fixture stays byte-identical at 8,486 bytes). On the
fourteen frozen 64 KiB prefixes (i7-10700K CPU 8, ReleaseFast, libzstd
1.6.0, three alternating rounds), every level 1/2/3 frame hash and byte
size is unchanged, while aggregate level-2 encode time drops 3.16x and
level-3 7.41x: the XML row goes 554.7 ms to 10.3 ms (53.8x), silesia-mr
484.3 to 31.6 ms (15.3x), webster 230.4 to 16.1 ms (14.3x),
brotli-source 217.5 to 13.5 ms (16.1x), dickens 102.5 to 19.9 ms (5.2x).
Level 4/5 spot checks (XML, MR, brotli-source) are byte-identical, since the
family still runs at budgets >= 96; five synthetic copy-heavy shapes
(eightfold segment copies, mutated copies, duplicated halves, JSON lines,
tight repeats) are identical across levels 1-22. The complete 1,174-test
zstd module passes in both Debug and ReleaseFast. Remaining level-3 gap on
XML is roughly 80x (10.3 ms vs 0.13 ms), now dominated by the independent
greedy/lazy/optimal candidate arbitrations rather than repeated exact
Huffman pricing.

**Post-fix residual, 2026-10-26.** After the unindexed multi-duplicate gate,
the level-3 XML encode is 10.3 ms; perf attribution of the frozen silesia-xml
64 KiB block shows 35% of process cycles in the fixed-cost optimal parser
(`emitOptimalHashMatchCompressedBlockReuseWithSequenceScratch` ->
`lz77.optimalPlanReuse`; isolated optimal stage: 7.43 ms search, 0.14 ms
index, 127,477 priced match candidates, 1.78 M length-choice updates,
850,728 chain nodes, 333,177 prefix-bound rejections). A counterfactual
gate of the optimal DP below the 96-state mixed budget keeps the five
XML-like rows byte-identical but regresses eleven of the other thirteen
frozen inputs at level 3 (dickens 25,898 -> 26,255, webster 22,669 ->
22,905, brotli-source 12,111 -> 12,168, etc.) and eleven of fourteen at
level 1 (nci -16%); it was withdrawn. The DP is the source of Vort's
current level-3 ratio lead over libzstd 1.6.0 (XML 5,078 vs 6,099), so
the residual ~80x gap is a speed/ratio policy point: Vort runs an
O(positions x chain) integer optimal parser where libzstd levels 2-3 run
one lazy2 hash-chain pass (DP begins at btopt). Further wire-identical
gains must come from DP internals or sharing one hash index across
candidate families; dropping the DP trades measured ratio for speed.

A second candidate-family gate (skipping the periodic-pattern emitter at
level 2/3 budgets) showed identical wires on the fourteen frozen 64 KiB
prefixes and generated copy shapes (level-2 aggregate 3.36x, level-3
7.58x in the combined counterfactual) but was withdrawn: the reusable
seekable encoder emits 1,024-byte frames of a 34-byte periodic payload at
those budgets, and that test (`reusable seekable encoder retains frame
and table scratch`) regressed - the repeated-pattern family genuinely
wins small periodic frames, where its scan is cheap anyway. Its encoder
share on 64 KiB blocks is only ~2% (findRepeatedPatternSegmentIn);
gating it was not worth the regression risk. The greedy family likewise
must stay: it is the sole winner on silesia-mr (16,806 vs 17,225 bytes
without it). These counterfactuals narrow the residual work to: (1)
making the fixed-cost optimal parser cheaper while byte-identical, and
(2) sharing hash-chain indexes across the candidate families.

Isolated candidate-family stage timings (silesia-xml 64 KiB, level-3
budget 64, ReleaseFast, five-round medians, benchmark excludes index
setup): double_fast 1.74 ms (1,695 seqs), greedy 2.10 ms, lazy 3.12 ms
(1,214 seqs, 5,071-byte block), optimal 7.31 ms search per encode
(127,477 match-length calls, 850,728 chain nodes, 333,177 prefix-bound
rejections, 0.13 ms index build). The frame-level output stays 5,078
bytes (lazy-equivalent plan after arbitration). Conclusion for the next
wire-identical target: time lives inside the DP inner loop
(match-length extension + per-length prefix minima), not in index
construction (0.13 ms) or candidate count selection alone; hash-index
sharing saves at most the single 0.13 ms build and is not the lever.

**Level-3 chain-depth counterfactual, 2026-10-26.** libzstd's per-level
table (`clevels.h`) uses dfast (a single direct-hash pass, no chains) at
level 3 for srcSize <=128 KiB; Vort instead runs five hash-chain
candidate families with max_chain=128. Sweeping that depth across 4/8/
16/32 (shared by all native matchers) gives level-3 aggregate speedups
of 8.64x/8.69x/8.72x/8.67x on the fourteen frozen 64 KiB inputs, but
changes wires on eleven inputs at every depth (dickens 25,898->26,255,
reymont 18,720->18,790, samba 22,048->22,389, sao 49,140->49,311,
brotli-source 12,111->12,168, etc.); the XML, MR and nci rows stay
byte-identical even at chain=4 (XML 72x). The depth reduction is
therefore a speed/ratio policy knob, not a wire-identical optimization,
and was not adopted. Combined with the earlier candidate-family
counterfactuals, the evidence shows the level-1..3 over-search is the
ratio advantage measured against libzstd 1.6.0 (frozen XML 5,078 vs
6,099 bytes); moving materially closer to reference throughput means
either exposing faster public selections or accepting measured ratio
loss, not removing redundant work - the redundant-work slice was
captured by the committed multi-duplicate gate (36f50c96).
