# Parallel XZ one-shot functional baseline

Date: 2026-10-26. Persistent bounded worker encoding is implemented. Functional,
complete XZ family/consumer and final build/help gates below have completed.
No throughput, encoder RSS or memory-lead result is assigned.

The [public contract](../formats/xz-parallel.md) adds optional bounded parallel
block encoding through existing XZ Alloc/Append/Into surfaces, including stored
and lazy entrypoints. `parallel = null` preserves serial defaults. Explicit
options require caller `std.Io` and separately bound workers, logical in-flight
plaintext and operation-requested heap. Blocks remain independent and publish
in input order with the normal Index/Footer.

## Resource and ownership boundaries

The in-flight byte sum includes queued, active and completed waiting blocks.
It does not count a borrowed slice as an owned heap allocation. A block larger
than that byte cap rejects without changing block size. Shared heap admission
covers real staging, records, filters, job/worker slots and codecs; final caller
output, OS stack mappings, OS/Io runtime private overhead and backing bookkeeping
remain outside the ledger. Io runtime allocations not made through the supplied
operation allocator are excluded. Per-worker stack reservation is 2 MiB, not an
observed peak or RSS measurement.

All one-shot output is staged before final publication. Into checks length and
copies directly from the single budget-owned complete staging buffer. Therefore
worker/ring bounds do not mean constant total memory as input grows. The serial
fallback uses the same configuration and quota for unsupported targets, empty
input or one effective worker, including a one-worker request, one block or
in-flight caps admitting one job. Started workers always join; a spawn failure
propagates instead of silently selecting serial encoding. A genuine partial
spawn test starts two OS threads, rejects the third and observes both exits,
zero live requested heap and preserved output/Index state.

Caller Io must safely support mutex/condition/futex coordination from the OS
workers. Its context, allocator context, input, filters and profile destinations
must remain valid until return without external concurrent mutation. Defined
serial fallback makes no coordination Io calls. Profiles distinguish active/
completed/in-flight blocks from ordered internally published blocks and actual
requested heap. Per-worker matcher work merges in input order by saturating
sums/maxima; synchronized parallel activity counters are distinct. Internal
publication counters may be nonzero when final caller publication fails.

## Completed validation

| Gate | Completed result | Scope |
| --- | --- | --- |
| Native Debug parallel target | 138/138 executions | 27 core plus 111 public root/consumer/import executions |
| Native ReleaseFast parallel target | 138/138 executions | Same final core/root count |
| Native ReleaseFast single-thread target | 25 passed, 2 skipped out of 27 | Only real-worker OOM and partial-spawn tests require genuine OS workers |
| Actual x86 Linux GNU ReleaseFast, earlier full run | 137/137 executions | 26 core plus 111 root/consumer; predates the added preset contract |
| Actual x86 later preset subset | 11/11 executions | One named contract covers all 20 presets, plus 10 imports; not a rerun of a final 138-case aggregate |
| Native and x86 liblzma 5.8.4 differential campaigns | Each 121/121 | 106 encode-path cases, 2 exact-memory boundary cases and 13 upstream-to-target decode cases |
| Cross-target artifact comparison | 109/109 matching artifacts | Includes 13 upstream-generated streams; not 109 target encode cases |
| Old-public-API default/null serial parity | 72/72 byte-equal old/new wires | 144 independent full-plaintext/exact-input-consumption checks |
| Wasm library check | 6/6 build steps | Compilation only |
| Real Wasm fallback gate | 3/3 build/run steps | Two successful multi-block calls plus two quota rejections |
| Complete native ReleaseFast XZ/consumer suites | 264/264 executions | 161 XZ plus 103 consumer executions |
| Combined family/check/help command | 197/197 build steps | Executes the two suites and actual CLI help; other global check targets compile |
| Separate final native ReleaseFast check | 190/190 cached build steps | Includes the later XZ Wasm hook; compilation only, no full-root test execution |

The ReleaseFast invocation combines the parallel and single-thread targets into
163 passed and two skipped out of 165 executions. That sum is not a count of
independent codec cases. Root/consumer totals include imports and a named public
consumer contract with five scenes. Compiler/test-runner MaxRSS entries are not
encoder resource evidence. Earlier native ReleaseFast core26 and single-thread
24 passed/two skipped logs predate the final preset contract and remain earlier
executions.

The combined `test-xz test-xz-consumers check run -- --help` command completed
with exit code zero. Its 264 tests are the two executed XZ suites; `check` also
compiles the unfiltered `src/root.zig` test binary and other check targets, but
does not execute all root tests. CLI help ran successfully; its logged 2 ms is a
smoke-check runtime, not an encoder throughput observation. The combined command
started before the Wasm check hook was added, so a separate final `check` closes
that build graph at feature source `cbef5071`, with all 190 steps cached and the
XZ Wasm target present. It is not a repeat of the test/reference campaigns.

The core gates cover serial/parallel complete wires for checks, filters, parser
modes and all presets; shared Alloc/Append/Into/stored/lazy paths; ordered ring
reuse and logical admission; empty/one-worker/single-block fallback; exact and
below heap/byte quotas; aliases and short caller buffers; real worker allocation
failure, codec budget failure, partial spawn and cleanup; backing refusal versus
quota error classification; concurrent ledger admission and work profiles.
Initial compile failures remain visible: the direct leaf test used an
insufficient module root; initial probe/Wasm builds preceded the independently
authored QA files; and the initial Debug budget test discarded an error-set
value. The first is a JSON transcription of tool output, explicitly not a raw
log; later logs were captured directly. The fixes used the codec module root,
completed the QA files and replaced the discarded test expression with an
`expectEqual` assertion. These were harness/source-assembly corrections without
production semantics changes. The successful earlier Debug retry26 and final
Debug138 logs are retained separately from the failed attempts.

The independent campaigns use empty/tiny, repeated, deterministic random,
source and binary inputs, plus 4095/4096/4097-byte block boundaries. They check
full serial wire parity, real block/Index order, full plaintext in both
directions, filters, checks, aliases and limits. Both reports observe
`peak_active_workers = 3`. Encode-path cases include expected rejections, so the
106 encode count is not a count of successful output wires. The upstream stream
artifacts retain their own direction rather than becoming target-encode counts.

The old-public-API gate uses the same helper and only old option fields against
revision `0b07b716772d41d04d1bdd694435df5759faa61f` and the current encoder. It
uses no parallel bridge. Its 72 rows cover the nine old alloc/Into/append
entrypoints across five inputs, checks, all five parsers, Delta/eight BCJ filters,
HC/BT controls and properties, chunk/block geometry and caller aliases. The
largest input is 1872 bytes; this is bounded default-wire preservation evidence,
not an exhaustive old/new or large-input guarantee.

The real Wasm gate runs a 32-bit `wasm32-wasi` artifact in Node v26.10.0 without
imports or a WASI host, using a 4 MiB FixedBufferAllocator and `std.Io.failing`.
With three requested workers, two in-flight slots and 2048 in-flight bytes,
stored 8192-byte input produces eight 1024-byte blocks and 8448 wire bytes;
fast-compressed 2048-byte input produces two blocks and 212 wire bytes. Both
match serial wire and public decode, set `serial_fallback`, start zero workers
and return requested heap live to zero. The compressed case also verifies
caller Into/input aliasing. Recorded requested heap peaks are 19288 and 807294
bytes respectively; these are scoped allocator counters, not RSS. Zero heap
quota and a 1023-byte cap below the actual 1024-byte block reject while preserving
caller bytes and fixed-allocator position. This proves real small-call target
fallback without coordination I/O, not parallel execution or performance on
Wasm.

## Evidence identity and remaining scope

After documentation commit `9654817f`, `git pull --rebase origin main` reports
the branch up to date. The [post-rebase record](data/xz-parallel-20261026/post-rebase.json)
and [raw logs](data/xz-parallel-20261026/post-rebase.tar.xz) preserve a fresh
ReleaseFast run of 27 core and 111 root/consumer tests, actual Wasm fallback and
CLI help, with 197/197 combined build steps. Global checks use cached compilation;
the complete root test binary is not executed. All 1998 source hashes remain
unchanged. The final evidence manifest covers 18 artifacts, including these two
post-rebase files; earlier campaign and executable identities are preserved.

The [repository evidence directory](data/xz-parallel-20261026/) preserves the
campaigns and their raw artifacts:

| Evidence | Repository artifact |
| --- | --- |
| Native differential and generated inputs/wires | [native.tar.xz](data/xz-parallel-20261026/native.tar.xz) |
| Actual x86 differential and generated inputs/wires | [x86.tar.xz](data/xz-parallel-20261026/x86.tar.xz) |
| Frozen native/x86 probe executables | [probes.tar.xz](data/xz-parallel-20261026/probes.tar.xz) |
| Exact loaded liblzma 5.8.4, API headers and license files | [liblzma-reference.tar.xz](data/xz-parallel-20261026/liblzma-reference.tar.xz), [reference-archive-manifest.json](data/xz-parallel-20261026/reference-archive-manifest.json) |
| Old-public-API parity, source snapshots and compiler/reference bindings | [legacy-parity.tar.xz](data/xz-parallel-20261026/legacy-parity.tar.xz) |
| Real Wasm fallback report and saved artifact | [wasm-report.json](data/xz-parallel-20261026/wasm-report.json), [wasm.tar.xz](data/xz-parallel-20261026/wasm.tar.xz) |
| Cross-target artifact counts and source digest | [cross-target.json](data/xz-parallel-20261026/cross-target.json) |
| CPU, host, Zig/Python/Node versions and measurement scope | [environment.json](data/xz-parallel-20261026/environment.json) |
| Broader final source snapshot | [final-source-manifest.json](data/xz-parallel-20261026/final-source-manifest.json) |
| Final source/feature-commit hash verification | [final-source-verification.json](data/xz-parallel-20261026/final-source-verification.json) |
| Archive content verification | [archive-verification.json](data/xz-parallel-20261026/archive-verification.json) |
| Exact build/run command arguments | [verification-commands.json](data/xz-parallel-20261026/verification-commands.json) |
| Captured success/failure logs and compiler command evidence | [logs.tar.xz](data/xz-parallel-20261026/logs.tar.xz) |
| Final terminal validation counts and log/report hashes | [validation-summary.json](data/xz-parallel-20261026/validation-summary.json) |
| Sixteen archived evidence artifact hashes | [evidence-manifest.json](data/xz-parallel-20261026/evidence-manifest.json) |

Raw work paths remain under `/tmp/vort-xz-parallel-20261026`: filtered logs in
`logs/`, `native/differential.json`, `x86-diff/differential.json`, legacy
`report.json`/`summary.json` and source-binding manifests in `legacy-parity/`,
and `wasm-report.json` with `wasm-artifact.wasm`. Failed initial builds remain
part of the logging history. Functional runs use Zig 0.16.0 on an Intel Core
i7-10700K/Linux host; target/build scopes remain those listed in the gate table.
Archive verification records 605 files each for native and x86 and 749
manifest-listed legacy files matched by hash. Legacy cache directories are
excluded from the archive; manifest-listed bytecode retained as original
evidence is distinct from the final source manifest's bytecode exclusion.

Both native/x86 differential reports retain source epoch
`xz-parallel-codec-epoch3-20261026` and the same 112-file closure digest
`9d78df7b6ad89ff93fc129b00430aa30f76921b7ecb3e9b2661ea9336be5573a`, unchanged
before/after each campaign. Native probe SHA-256 is
`9bf82dc1eec4cba43f2c531980fce8119e9ef1f9a4f1fbac5c1ed93dbf81f76c`; x86
probe SHA-256 is
`c110f4b8d3b1c1adb2b93c86d0e2ed6fdd8ae90d317652f4a0d47b74342bcabc`. The
selected liblzma 5.8.4 library SHA-256 is
`03a333e8fd35e4c771c04ce93ab08dc0b8bbfa7615900179c53e1dd92a4d9ec0`; reports
also retain its public-header manifests and ABI scope. The 22-file reference
archive preserves that exact loaded library, API headers and bundled licenses
without recompilation, retaining its original identity. Later Wasm consumer,
gate and build edits are a separate evidence scope and do not rewrite the
earlier probes as executions of those files. Saved Wasm SHA-256 is
`6b93ae5a7f7c4f7a8c24bb31b92ff62d769c3f018fbb0486fb3bad417dbf7208`.

The legacy gate separately records 98 old and 106 current source hashes,
compiler/command/helper/executable manifests and independent old Git-blob
binding. Two current QA files changed during compilation; production codec
closure remained stable, and all recorded current hashes were stable during
the functional matrix. No direct build-exe `.h` cache-to-artifact mapping is
claimed. Its scope must not be collapsed into the 112-file differential epoch.

The production/API/tests/tools increment is saved as
`cbef5071fe7209cd412be983e87603150f1bc75f`. The broader final source manifest
records 1998 source/tool/example and build files, excluding Python bytecode
caches; its SHA-256 is
`945b711f37a33d2a8d6900678e98e9ee10d3ae3f2d617649897f81ad3c4a9e67`.
That snapshot is wider than the differential closure and does not refresh the
earlier executable identities or turn earlier gates into final-source reruns.
The final source verification records all 1998 files matching the feature
commit with zero mismatches. Frozen native/x86 ELF files retain the probe
digests above; command manifests distinguish build/run commands from compiler
internal commands retained in the logs.

Final archived evidence contains 16 hashed artifact files, excluding the
evidence manifest itself. These final aggregation files preserve the earlier
report/probe epochs and raw failed-build history. This document freeze is
the 2026-10-26 final feature validation scope; subsequent rebase/reverification
results must retain their own scope rather than rewriting the existing runtime
identities.

The encoder still emits standard block headers
without declared compressed and uncompressed sizes. In the selected liblzma
5.8.4 reference, `api/lzma/container.h:750` requires both header fields and
`common/stream_decoder_mt.c:1235` selects serial direct mode when either size is
unknown. Index sizes at the end do not meet that header requirement. These
streams remain valid XZ; preserving their default serial wire leaves liblzma MT
decoding in serial mode. Both size fields and multiple blocks are necessary,
with thread/memory limits, filter work and I/O also controlling activity; adding
two fields alone would not prove multiple decoder workers. Incremental XZ
remains serial. No new throughput, ratio, full liblzma algorithm/MT feature
parity, constant-memory or all-platform
claim follows from these functional results. Earlier serial preset/resource and
performance baselines retain their own epochs. The next bounded functional
candidate is opt-in declared Block Header sizes while preserving default wires;
it needs its own liblzma MT eligibility and actual activity validation. A bounded
parallel incremental API or specific XZ parse/matcher quality gaps need another
independent scope review.
