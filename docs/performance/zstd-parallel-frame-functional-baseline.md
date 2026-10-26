# Native parallel single-frame Zstandard functional baseline

Date: 2026-10-26. V1.B public codec/root, independent reference, actual worker,
Wasm fallback and final build validation have completed. This is functional
evidence; no throughput, ratio or RSS leadership measurement is assigned.

The [public contract](../formats/zstd-parallel-frame.md) adds explicit Alloc,
transactional Append, Into, dictionary/set and checked-bound surfaces using
`NativeFrameOptions` plus required `ParallelOptions`. Defaults are two workers,
1 MiB job size rounded to effective blocks, four slots, 4 MiB logical in-flight
input and 256 MiB requested heap. A native whole-heap cap further limits this
operation by their minimum.

## Wire and ownership scope

Each call emits one standard/magicless frame, one selected header/content size/
window/dictionary ID, one global last Block and one optional checksum. Stable
heap queue/worker state borrows immutable input/dictionaries until all work joins.
There is no whole-input descriptor list. Actual job-span credits remain charged
through ordered coordinator re-emission; ceiling slots permit a short tail only
when the strict actual byte sum fits. An over-cap first actual job rejects before
allocation without changing its boundary.

Workers keep independently dictionary-initialized job state and use the existing
native candidates/strategies/settings/search budgets with full global-window
history. The coordinator decodes original-job physical distances, then re-emits
against actual preceding global recent offsets/Huffman/FSE state. Native job
priors are explicit-mode policy, not a mechanical libzstd MT implementation or
legacy serial-wire guarantee. Raw/RLE/literal-Huffman and actual multiple wire
Blocks must remain correct, with the raw upper bound preserved.

Requested heap covers control metadata, slots/workers, codec/job results,
coordinator scratch, complete frame/output replacement staging and all operation
allocations. Caller buffers, stack mappings and Io/backing private overhead are
excluded. Alloc/Append/Into publish after complete staging and joined workers;
aliases and every prepublication failure keep caller bytes/ownership safe.
One-shot output memory grows with frame size, independently of bounded jobs.
The wrapper validates/re-emits each original job's literals/sequences/plaintext
and extents, builds the complete frame/checksum and joins before publication; it
does not add a full-frame decode/preflight pass on every call.

Profiles separate actual OS worker activity, encoded job wire, ordered internally
staged jobs/Blocks, job-output capacities, in-flight plaintext and requested heap.
Worker work stays private and its original emitted counts do not double-count
coordinator output. Synchronous fallback preserves job geometry and wire while
reporting zero OS worker startup/live/peak; partial spawn failures join and return
the error. `ParallelProfile.published_jobs`/`published_blocks` may be nonzero on
`OutputTooSmall` after complete internal staging. Separate caller control-profile
emitted counters merge actual coordinator output only after destination success.
Work counters and pipeline diagnostics remain observable on failure; function
success is the caller-publication proof. Public profile destinations synchronize
at final/failure touchpoints. The job-output capacity peak observes visible
completed/free slots, excluding active worker-local outputs; the requested-heap
peak covers all tracked allocations and is a separate metric.

## Completed validation

| Gate | Completed result | Scope |
| --- | --- | --- |
| Native Debug, native ReleaseFast and actual x86 Linux GNU ReleaseFast | Each 122/122 executions | 35 filtered core/queue plus 87 root/consumer executions, including imports |
| Native Debug single-thread | 34 passed, 1 skipped out of 35 | Real partial-spawn gate requires OS workers |
| Combined native Debug invocation | 156 passed, 1 skipped out of 157; 15 build steps | Parallel/root plus single-thread totals, not 157 independent codec cases |
| Native/x86 final external campaigns | Each 111/111 | 92 complete target encodes, 9 expected encoder rejects, 6 upstream MT-configured streams decoded by Vort and 4 dictionary rejects |
| Actual target worker activity | Peak active workers 3 per campaign | Natural observed target activity, not configured thread count or reference worker instrumentation |
| Independent large-sequence evidence | Maximum Block Sequence_Count 1248 on each target | Physically parsed without the production adapter; cross-job emitted history sequences are checked |
| Real Wasm runtime | Four groups; 5/5 build/run steps | Raw/RLE, controlled fast, magicless dictionary and publication/quota fallback contracts |
| Full native ReleaseFast Zstd family | 1128/1128 | Complete family execution at the final heap-workspace source |
| Final Debug check/actual CLI help | 207/207 build steps | Compiles global targets and executes help; no CLI worker flag or full-root runtime claim |

Generic queue 6/6, prior shared-XZ 36/36, legacy single-state 11/11 including
imports, atomic helper 2/2 and its single-thread one-pass/one-skip controls are
separate regression scopes. The three named geometry contracts are covered by
the private queue check and full family, but their prefix is outside the filtered
35-core invocation. Aggregate/import totals are not independent new codec-case
counts. Shared-heap extraction is `a0a3eb0e`, helper/single-beam correction is
`d948c9da`, and completed feature code/tests/tools are saved as `fb441359`.

## External and fallback evidence

The 101 target encode attempts comprise 92 complete single-frame artifacts and
nine deliberate quota/options/short-output rejections. Refusal cases validate
errors/diagnostics/publication rather than complete plaintext. Six additional inputs
are actually generated with versioned libzstd MT settings and decoded by Vort;
four missing/wrong dictionary cases validate refusal. Complete artifacts verify
same-job-geometry worker-one parity, bounds, frame/header/dictionary/checksum,
full reference plaintext and exact input consumption. The complete wire count
must not be described as 101 frames.

Both campaigns observe peak three active Vort workers. Independently parsed
large-sequence Block counts are `[0, 1, 1248]`, with 1249 emitted cross-history
sequences. This exercises physical distance interpretation and large-sequence
re-emission beyond the small path. Raw/RLE/Huffman-only controls assert their
actual block types and zero Sequence_Count rather than inferring them from a
requested selection name.

Native x86-64 and x86-linux-gnu 32-bit probes are actually built/run. Both campaigns
use the same 64-bit host libzstd 1.6.0 for reference calls. MT generation checks
real API success and retrieved nbWorkers/jobSize/overlap settings; this dataset
does not count actual reference worker execution or benchmark either library.

The import-free wasm32-wasi runtime uses Node v26.10.0 and `std.Io.failing`,
requesting two workers but selecting synchronous fallback with one effective
codec lane and zero started/live/peak-active OS workers. Raw/RLE 2048-byte input
produces 1063 bytes/four jobs/eight internal published Blocks; controlled-fast
2048 produces 326 bytes/four jobs/eight Blocks; magicless dictionary 1024 produces
43 bytes/two jobs/four Blocks. Requested heap peaks are 4076/4670/3737 bytes,
with live zero after each operation. Fast history has seven sequences/max distance
256; dictionary ID77/set output and standard-minus-magic equivalence are checked.
Append prefix/count and overlapping Into input remain correct. Zero heap,
measured peak minus one and a 511-byte cap below the first 512-byte job refuse
with caller bytes unchanged. Same-geometry serial wire, full public decode,
one terminal Block and whole-content checksum are verified. These are real
fallback/resource observations, not Wasm OS parallelism or RSS measurements.

## Failure corrections and source epochs

The first Queue compile rejects a parameter shadowing `start`. Early codec
semantic checks also reject ambiguous Error/Dictionary references and an unmapped
`rawLengthOverflow` error. The initial ambiguity-source snapshots were not
captured and remain null; a later snapshot is labeled after the second attempt.
The corrected third `-fno-emit-bin` pass has stable 1373-source hashes but produces
no ELF and runs no test, so it is not a runtime pass.

The initial native Debug runtime records 29 core passes/four SEGV crashes;
single-thread records 31 passes/one skip/one fixture failure, while root consumers
pass 87. Its combined result is 147/153 with one failed and four crashed tests
plus one skip, at the earlier 33-core scope. GDB runs the exact failed ELF three
times without rebuilding and reproduces the first SEGV in compiler stack probing.
Two nested reservations, 1454384 and 897168 bytes, total 2351552 bytes before other
callers and exceed the fixed 2097152-byte worker stack; the computed fault matches
the guard page. This is demonstrated stack exhaustion, not queue deadlock or a
decoded-buffer overrun. The failed ELF SHA-256 is
`b35ab5aa0f3ee78a8829cf7ae32aa5a8d00a44d6b538cd4f5d7e327294f12346`.

The explicit job path now lazily allocates mixed workspace through its worker
heap budget and initializes large arrays in place with `initInto`, reusing the
same planner body. Original serial defaults add no new allocation, and the 2 MiB
worker stack is unchanged. Stack-reference plan/wire equality and allocation-
failure tests preserve candidate/search behavior; later native/x86 and Wasm
runtime gates pass. Test-only hit updates (83 changes in the codec root and the
single-beam hook) become atomic to remove real shared-counter UB. Their production
`builtin.is_test == false` paths remain absent; this does not serialize the codec
behind a whole-codec lock.

The original literal-only whole-job fixture selected a compressed block with one
sequence, so it did not prove the claimed Huffman/raw/RLE/Huffman sequence. The
corrected fixture uses auto selection and a 128-byte job while retaining strict
type/zero-sequence assertions; original observations are preserved. Wasm's two
shadowed parameter names were compile errors corrected before its successful
runtime. The first external native/x86 reports each pass 103/111: all eight raw-
dictionary failures originate from eager probe `initChecked` catalog setup on
raw Dictionary_ID zero. A sole probe conditional fix leaves production/catalog
semantics unchanged; new ReleaseFast probes and new final directories then each
pass 111/111. Original reports and failed probe hashes remain unchanged.

Final reports retain source epoch
`heap-workspace-raw-dictionary-probe-fix-20261026` and stable captured 191-file
campaign source set,
SHA-256 `6d6de048492b01722ca27c4cc4a08f69e5f8e2e01526ebbaecc21a18ed8a2c6a`
before/after each run. Native final probe SHA-256 is
`ee17de555e1f9d8d6b6507ff1f42773080ecccebd922006a8013b422e918618f`; x86 is
`6a1beaa4c13e35ab72810873e1e2a10c461d15d349085f456915eaf8315eb629`.
Final codec `src/zstd.zig` is
`df0ab8ffd7e89083a63dfed4e319ce06e91177fa1f9999df75490d21255044ba`, and
`mixed_workspace.zig` is
`1835998375132f776df464bf53b9d01b31f026835ad7fbd90e754e1b860d21f4`.
The earlier 103/111 probe ELFs retain their own identities; successful final
code/source manifests do not rewrite their epoch or the failed stack ELF.

Reference ELF SHA-256 is
`c76f4c4457df67a5e0c7bb6bb4f58b9857cf4f2cdd7925bfb9345daac4e6b83e`, from
libzstd 1.6.0 checkout `01b7154f1172432f8abe9b3bb9909e14a1176b7d`. Its 132-file
relevant source scan is clean/stable and actual symbol owners, header, retrieved
MT parameters and full-content calls are recorded. Historical compiler/link
flags/version/build logs are unavailable; package/dependency files do not prove
those missing flags. The reference is not rebuilt for archival work, and no
reference-worker-count or timing claim is made.

Evidence is archived in [the repository bundle](data/zstd-parallel-frame-20261026/):

| Evidence | Archived record |
| --- | --- |
| Original 103/111 and final 111/111 native/x86 campaigns | [campaigns.tar.xz](data/zstd-parallel-frame-20261026/campaigns.tar.xz) |
| Semantic/runtime/GDB/heap-fix history and local source records | [history-and-local.tar.xz](data/zstd-parallel-frame-20261026/history-and-local.tar.xz) |
| Frozen probes and actual failed/debug ELF files | [probes-and-failed-elfs.tar.xz](data/zstd-parallel-frame-20261026/probes-and-failed-elfs.tar.xz) |
| Exact reference ELF/source/header/MT checks and build-capture limits | [reference.tar.xz](data/zstd-parallel-frame-20261026/reference.tar.xz) |
| Actual Wasm executable and report | [wasm.tar.xz](data/zstd-parallel-frame-20261026/wasm.tar.xz), [wasm-report.json](data/zstd-parallel-frame-20261026/wasm-report.json) |
| Final codec/root/dependency source archive | [final-sources.tar.xz](data/zstd-parallel-frame-20261026/final-sources.tar.xz) |
| Broad source scan, compiled campaign scope and external dependency verification | [source-manifest.json](data/zstd-parallel-frame-20261026/source-manifest.json), [source-verification.json](data/zstd-parallel-frame-20261026/source-verification.json) |
| Compiler/build/probe identities and environment | [build-provenance.json](data/zstd-parallel-frame-20261026/build-provenance.json), [environment.json](data/zstd-parallel-frame-20261026/environment.json) |
| Final classifications, gate counts and correction history | [validation-summary.json](data/zstd-parallel-frame-20261026/validation-summary.json) |
| Cross-target settings/complete-wire comparisons | [cross-target.json](data/zstd-parallel-frame-20261026/cross-target.json) |
| Archive members, capture scope and artifact hashes | [archive-verification.json](data/zstd-parallel-frame-20261026/archive-verification.json), [evidence-manifest.json](data/zstd-parallel-frame-20261026/evidence-manifest.json), [artifact-manifest.json](data/zstd-parallel-frame-20261026/artifact-manifest.json), [SHA256SUMS](data/zstd-parallel-frame-20261026/SHA256SUMS) |

Six archives preserve all logical raw/local evidence members, including repeated
hardlinked content with verified size/hash: 2164 campaign members, 173 history/
local records, nine ELF files, 31 reference records, one Wasm executable and 216
final source members. The broader source scan has 1980 files and digest
`8f330935d30b165642d2fba14df00b7cbcaec46b27a70ef9967c4ec88166ee84`; its
191-file campaign scope and 18 recorded external Vail files match their recorded
identities. These source sets are explicit scans, not compiler dependency
extractions or refreshes of earlier runtime identities. Early null/late source labels remain
explicit. Initial semantic stderr was exported verbatim from tool output, while
runtime/GDB logs retain their actual executable/command scope.

Cross-target comparison covers the 111 classified rows, with semantic settings
and complete wire pairs equal. OS scheduling/overlap, intermediate counters,
heap sizes and fatal allocation discovery progress are excluded from equality.
Raw work remains under `/tmp/vort-zstd-singleframe-parallel-20261026`. Post-rebase
checks/publishing remain separate later integration records.

Earlier XZ, Zstd/Brotli performance, candidate-MT and seekable reports retain
their source/measurement scopes. This completes the bounded functional slice,
not libzstd MT feature/algorithm/performance equivalence or industry-best status.
Persistent incremental single-frame jobs, CLI worker flags and broader
ratio/throughput/memory comparisons remain separate follow-up work.
