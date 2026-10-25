# Persistent incremental XZ parallel functional baseline

Date: 2026-10-26. Persistent owner/queue, independent QA/reference and real Wasm
fallback validation have completed. Native/x86 campaigns observe real encoder
worker activity, input reuse and movement with jobs. No throughput or RSS
result is assigned.

The [public contract](../formats/xz-incremental-parallel.md) adds optional
`XzIncrementalEncoder.Options.parallel` with null preserving the serial path.
Explicit options keep a stable budget-owned worker queue across steps, own each
accepted input prefix and release credits only after complete Block delivery.
The public `XzIncrementalParallelSnapshot` separates accepted, encoded, ordered
Index-published and caller-delivered blocks. Model/search/level settings and
optional Block Header size behavior remain shared with the serial writer.

## Ownership and failure scope

The owner/control/queue and allocator slots have stable heap addresses even
when the public encoder value moves. Workers capture job/codec storage and
private counters/work, without retaining the public Encoder or caller profile
destinations. I/O/backing/filter storage remains valid until join; caller profile
storage remains valid through deinit and is synchronized only at public
touchpoints. Profiles may be read between steps without worker writes to them.

Header startup requires delivering all 12 bytes before accepting input/starting
workers. Credit includes partial, queued, active, completed and delivering
blocks. A partially delivered oldest block does not prevent accepting later
input up to credit limits, and completed internal output is not caller delivery.
Accepted input is copied into owned job buffers for next-step caller reuse;
same-call input/output overlap is outside this new contract.

Admission errors for input/pledge/block count, a small partial-block byte cap and
complete-front pending limits are recoverable. In particular, raising pending
limits retries publication of completed work without re-encoding it. Worker,
spawn and heap failures are sticky, stop/join workers and expose precise
`failedProgress()`/`last_step_progress`; subsequent failures add zero progress.
Reset is infallible with retained capacities and clears sticky state. Done does
not mean heap zero; deinit joins/frees and publishes final live requested heap
zero. ZIP's parallel-XZ failure bridge must account accepted CRC/input and
encryption/output bytes exactly once before propagating the error.

The explicit requested-heap ledger owns control metadata, plaintext/output
capacities, codecs/filters/sized-payload scratch, front bytes and Index records.
Mode transitions admit every retained allocation before adopting/rebinding it;
lower-cap rejection preserves the previous completed configuration. Free slots
still consume real heap. Caller buffers, OS stacks and allocator/Io private
overhead are excluded. Index growth is constrained by block count and heap,
without constant overall memory for unbounded streams. No RSS/throughput claim
follows from these counters.

## Completed validation

| Gate | Completed result | Scope |
| --- | --- | --- |
| Native Debug, native ReleaseFast and actual x86 Linux GNU ReleaseFast | Each 129/129 executions | 36 codec/core plus 93 root/consumer executions, including imports |
| Native Debug single-thread target | 35 passed, 1 skipped out of 36 | Real partial-spawn test needs OS workers; other fallback contracts execute |
| Native/x86 final external campaigns | Each 84/84 | 71 incremental encode scenarios plus 13 upstream-to-target decode cases |
| Actual encoder concurrency | Peak active workers 3 in each campaign | Whole-campaign observation; fast individual rows may complete serially before return |
| Input overwrites with queued/active jobs | Native 539, x86 528 | Accepted caller staging is overwritten before independent full-content checks |
| Actual encoder moves with queued/active jobs | Two on each target | Both actual move scenarios carry jobs; moved owner remains valid |
| Real Wasm fallback | 3/3 build/run steps | Stored/reset, compressed move/final-byte credit, partial flush and zero-heap rejection |
| Complete native Debug XZ/consumer family | 302/302 | 199 XZ plus 103 consumer executions |
| Combined Debug family/check/help | 208/208 build steps | Executes the XZ suites and CLI help; global check targets compile |
| Separate final Debug check | 200/200 build steps | Compilation check; does not execute the full unfiltered root suite |

The Debug combined parallel/single-thread invocation totals 164 passed and one
skipped out of 165 executions. That sum and imported root tests are not counts
of independent new codec cases. `check` compilation of the unfiltered root
test binary is distinct from execution of the selected consumer filters. No
post-rebase result is assigned by these pre-rebase logs.

Contracts cover Header startup/null retry, next-step owned input reuse, active
value movement, public-only profile publication, front/input pipeline credit,
final-byte delivery release, partial flush under a cap below block size,
recoverable input/pledge/block/pending limits, sticky worker/heap errors,
partial spawn and joined cleanup, exact failed-step progress, reset, retained
capacities and transactional serial/parallel mode changes. Shared settings and
complete wires cover stored/compressed payloads, checks, filters, parser/preset
controls, size flags and stream transitions. ZIP consumers validate content and
failed input/CRC/encryption/output accounting. No incremental CLI worker flag
is introduced.

## Actual external ownership and worker scope

Both final reports cover 71 incremental scenarios: 70 successful/recoverable
scenarios produce complete streams checked against serial wires, independent
Header/LZMA2/Index/Footer extents and full reference plaintext. The sticky-worker
negative case validates `WorkingMemoryLimitExceeded`, exact failure progress and
a 12-byte Header prefix; it is not a complete plaintext/stream result. Another
13 cases decode original-reference streams with Vort. Eight sized queue-cycle outputs per
campaign also undergo original liblzma MT decoding. That additional verification
is not added to the 84-case count. Vort probes are actually built/run as native
x86-64 and x86-linux-gnu 32-bit; both use the same 64-bit host liblzma/ABI adapter
for reference decoding. These are not 32-bit liblzma reference builds.

Real owned-input observations span partial, queued, active, completed and
delivering states. The full campaign requires both natural encoder concurrency
above one and caller overwrites while queued/active jobs exist, as well as a
real move carrying jobs. Native/x86 achieve peak three, 539/528 such overwrites
and two moves with jobs respectively. These scheduling-sensitive totals need not
match across targets. The two 32768-byte-block repeated-input rows need not
expose unfinished jobs at an observed return: each has two staging overwrites,
owned partial input, no overwrite with queued/active jobs and peak one. Those
valid rows do not dilute the separate whole-campaign asynchronous witnesses.
No artificial delay/barrier or timing condition creates the activity evidence.

The real Wasm runtime uses Node v26.10.0, an import-free wasm32-wasi executable,
4 MiB FixedBufferAllocator and `std.Io.failing`, with synchronous target fallback
and zero started/live workers. Stored 8192-byte input produces 8480 wire bytes,
eight delivered blocks and 119 staging overwrites; requested peak is 8884 bytes
and done retains 7213 bytes, with allocation-free same-setting reset. Compressed
2048-byte input produces 200 wire bytes, moves with two owned jobs, checks two
final-Block-byte credit releases and retains 5084 bytes at done; requested peak
is 811738 bytes. Both deinit to live zero. A 65-byte input under a 64-byte cap and
128-byte block size records one recoverable refusal, explicit 64-byte flush and
a final one-byte block, matching serial explicit-flush wire without automatic
shrinking. Zero-heap init refuses before advancing backing allocator position.
All emitted wires are publicly decoded. These are requested-allocation/functional
observations, not RSS or Wasm OS-worker performance.

## Corrections and evidence epochs

Raw logs preserve the initial family compile's two nested-if assignments and
Owner error-union signature error. After those production compile fixes, the
first contract invocation records 126/129 passed, two failures and one crash:
the moved-handle test cleanup dereferenced an already freed owner; a retry
assumed reset replaced the captured zero matcher budget; and a consumer assumed
every started worker had entered by a scheduling-sensitive snapshot. Corrections
retain the stable control for cleanup, test same-setting reset/repeated failure
and use started count with a live-worker bound. The later split Queue test
initially lacked public visibility on its injected spawner's method; the corrected
Debug/structured runs retain their separate logs.

The first Python campaigns abort while treating an already serialized SHA string
as bytes. The corrected tool's native/x86 reports each reach 82/84, with two
overstrict per-row queued/active assertions failing after full-content checks.
Final tooling accepts completed-before-return rows, records their actual states
and adds strict campaign-level concurrency/overwrite/move-with-jobs gates. The
final reports each pass 84/84. Failed logs/reports remain historical; no earlier
failure is relabeled as a new production runtime fix or deleted from the record.
Failure-source captures were taken late, and three old QA files are explicitly
reconstructed by reversing documented corrections to match the agents' reported
hashes. They are not raw sources captured by those earlier compilers. Complete
initial failed-compiler source snapshots are unavailable and are not fabricated.

Both final reports retain source epoch
`xz-persistent-incremental-epoch4-final-tool-20261026`, a stable 133-file closure
SHA-256 `c703a9e7b17019c50daa2f1ef72e60fb485c625fc20fb831a5fd3705150ccd0b`
before/after their run, native probe
`5ec9937d79f239b15dcd1525013f1fe0b638cf7412ccb13dfd6e300dbf4b082c` and x86
probe `2cd6af0f3038c7f8b0735701970472584b0d6f85f265f52ed0db89e9fafe0f5c`.
The earlier fixed-tool reports retain closure
`c391703dd5d16d57cfe28593e4f493eec70f87381a6c05035335011bac80d0c1` and those
same frozen probe binaries; the final tool/report change is not a probe rebuild.
Code/tests/tools are saved as feature commit `8f4ae62f`.

The selected original host liblzma 5.8.4 remains SHA-256
`03a333e8fd35e4c771c04ce93ab08dc0b8bbfa7615900179c53e1dd92a4d9ec0`.
Optional MT provenance metadata retains its prior reference build identity;
earlier counter-reference decoder activity is not rewritten as new persistent
encoder evidence. Wasm executable SHA-256 is
`736ded5ffa0c582021dc4e421b460351036a05fae10a54f371701b3e044774b7`, with its
recorded consumer/gate source identities. Compiler/test MaxRSS and CLI runtimes
remain outside encoder performance evidence.

Evidence is archived in [the repository bundle](data/xz-incremental-parallel-20261026/):

| Evidence | Archived record |
| --- | --- |
| First, fixed and final native/x86 reports and raw inputs/results | [campaigns.tar.xz](data/xz-incremental-parallel-20261026/campaigns.tar.xz) |
| Actual compiler/test/runtime logs | [logs.tar.xz](data/xz-incremental-parallel-20261026/logs.tar.xz) |
| Explicitly late/reconstructed failure-source records | [failure-sources.tar.xz](data/xz-incremental-parallel-20261026/failure-sources.tar.xz) |
| Frozen native/x86 probes and actual Wasm executable | [probes-wasm.tar.xz](data/xz-incremental-parallel-20261026/probes-wasm.tar.xz) |
| Executed module scope and integration entrypoint sources | [final-sources.tar.xz](data/xz-incremental-parallel-20261026/final-sources.tar.xz) |
| Broad source scan and scope/late-capture verification | [final-source-manifest.json](data/xz-incremental-parallel-20261026/final-source-manifest.json), [source-verification.json](data/xz-incremental-parallel-20261026/source-verification.json) |
| Compiler/build/probe/reference identities and capture limits | [build-provenance.json](data/xz-incremental-parallel-20261026/build-provenance.json) |
| Completed counts and correction history | [validation-summary.json](data/xz-incremental-parallel-20261026/validation-summary.json) |
| Cross-target comparisons and exclusions | [cross-target.json](data/xz-incremental-parallel-20261026/cross-target.json) |
| Actual fallback runtime report | [wasm-report.json](data/xz-incremental-parallel-20261026/wasm-report.json) |
| Host/compiler/runtime scope | [environment.json](data/xz-incremental-parallel-20261026/environment.json) |
| Archive/member hashes and reused-reference dependency | [archive-verification.json](data/xz-incremental-parallel-20261026/archive-verification.json), [evidence-manifest.json](data/xz-incremental-parallel-20261026/evidence-manifest.json) |
| Artifact hashes and checksums | [artifact-manifest.json](data/xz-incremental-parallel-20261026/artifact-manifest.json), [SHA256SUMS](data/xz-incremental-parallel-20261026/SHA256SUMS) |

Five archives preserve 1762 raw files. Member verification covers 1738 campaign
members, 16 logs, six failure-source records, three executables and 140 final
source archive members. The broader src/build/tools scan has 1958 files and
digest `0f8e5a18fb244d6eae89549cbc1ec8841dd06e8e966b55480c3f2d208a7064f0`;
its 133-file executed campaign scope matches current files with zero mismatches.
The broader scan does not replace the frozen probe/runtime or early-failure
identities. Successful build summaries retain compiler/mode/target/build-graph
and ELF hashes, with no complete successful compiler argv capture; failed
commands remain verbatim in their logs.

The original reference is reused from the committed
[Block Header size reference archive](data/xz-block-sizes-20261026/reference.tar.xz)
and retains its earlier identity, without rebuilding or refreshing it. Cross-target
comparison covers 84 rows including the negative Header prefix; all output pairs
and successful deterministic progress agree. Scheduling, intermediate snapshots,
worker overlap, requested heap and fatal-worker discovery progress are excluded
from equality. Raw final reports remain under `/tmp/vort-xz-incremental-parallel-20261026/`
in `native-final`/`x86-final`, separated from first/fixed attempts. Post-rebase
validation and publishing retain separate integration records.

The [post-rebase record](data/xz-incremental-parallel-20261026/post-rebase.json)
binds `79a54571`: `git pull --rebase origin main` completed without incoming
changes or conflicts. Native/x86 ReleaseFast each re-execute 129/129; Debug plus
single-thread re-executes 164 passed and one genuine thread-dependent skip out
of 165, with actual Node fallback and CLI help execution and 209/209 combined
build steps. Distinct explicit test seeds force new test-run cache keys while
reusing compiled artifacts. Verbose invocation paths and executable hashes are
preserved in the separate post-rebase archive. All 1,958 source-scan files and
the fifteen pre-rebase archive checksums still match. Global unfiltered root
tests remain compile-only in `check`; no new performance campaign is assigned.

The earlier [one-shot parallel baseline](xz-parallel-functional-baseline.md) and
[Block Header size baseline](xz-block-sizes-functional-baseline.md) stay frozen
to their historical evidence epochs. Their passed counts, alias contracts and
host reference-worker observations do not prove this persistent state machine.
These completed functional gates do not establish full liblzma feature/performance
parity or industry-best status. Broader corpus/platform ratio, throughput and
memory comparisons require a separate reproducible benchmark scope.
