# Incremental single-frame Zstandard parallel functional baseline

Date: 2026-10-26. The explicit owning class, shared job view, ZIP integration,
native/synchronous/Wasm execution and fixed-libzstd interoperability gates are
implemented and executed. This is a functional baseline only; it does not assign
a throughput, ratio, RSS or industry-best result.

The [public contract](../formats/zstd-incremental-parallel.md) adds a separate
`NativeIncrementalParallelFrameEncoder`, with native frame settings and required
persistent parallel options. It owns accepted prefix/plaintext, retains rolling
global-window history, encodes jobs independently and re-emits against actual
global entropy/repcodes state. Full filling jobs wait for a valid following
offer/flush/finish seal; they are not automatically encoded nonfinal on filling.

## Behavior and ownership scope

Header delivery precedes input acceptance/worker startup. Accepted input can be
overwritten before the next step, and a moved encoder keeps stable worker state.
Prefix history includes accepted queued/active predecessors, with O(H+J) owned
input per bounded slot and separate plaintext credit versus real heap accounting.
The final coordinated job-output byte releases its credit. One front job replaces
whole-frame output staging. Partial credit below job size needs explicit flush/
finish; it never implicitly splits the caller's boundary.

Checked wide frame Count, local prefix, finality and actual header window are
separate job-view inputs. Original-job dictionary entropy/FSE/reps and actual
frame state remain distinct, with byte-checked seam/overlap and transactional
re-emission. Owned scratch capacities are retained without copying owner pointers.
All original native strategy/HQ/search budgets and mixed heap workspace remain
in use. Real wide-arithmetic gates do not stand in for giant-input execution.

Flush acknowledges only after accepted nonfinal jobs drain, and keeps history/
hash/state. Finish seals final full/partial data or an empty final after flush,
emits one checksum and advances data-frame count at complete terminal delivery.
Underfilled exact pledge on finish is sticky; scalar extra-input/admission-cap prechecks are
recoverable before sealing/output. Pending and cumulative output caps can be
raised for retry without re-encoding/re-emitting a completed unit; an output-cap
error may already have delivered a prefix, with exact retry progress. Sticky worker/
spawn/heap failures stop/join and expose precise most-recent failed-step progress.

Profiles distinguish internal publication and full-job delivery; native emitted
counts advance only for fully delivered jobs. Reset retains capacities without
allocation, clears logical/poison state, uses captured configuration and preserves
the four runtime caps. Transactional next-frame changes preserve stream totals/
frame count, while a rejected change retains the old done state. Standard-only
skippables contribute output without incrementing data-frame count. Dictionary
ID derivation/conflict and direct raw-zero history routes are explicit contracts.
ZIP null mode keeps its old policy; explicit mode bridges exact failed input/
CRC/encryption/output progress once. No new CLI worker flags are provided.

## Executed verification

| Gate | Result |
| --- | --- |
| Native Debug and ReleaseFast | Each passes 63 codec plus 93 root/ZIP executions (156/156). The explicit-window geometry case uses one byte above a 1 MiB window; the external campaign separately executes 4 MiB long streams. |
| Header/sealing/history/ownership | Covered by the 63 codec executions: zero-output startup, full-job lookahead, partial/full/empty final jobs, caller overwrite, queued-prefix history, seam/overlap and active value movement. |
| Wire/model settings | Standard and magicless, unknown/exact FCS, all ten exposed strategies, HQ controls, dictionary/set/raw-ID-zero and global entropy/repcodes pass. |
| Limits/failure/lifecycle | Scalar and whole-unit caps, exact failed progress, sticky worker/HQ failures, recoverable retries, final-byte credit, allocation-free reset and transactional next-frame pass. Runtime `max_job_count = 0` is explicitly rejected with zero progress; reset retains the prior legal value. |
| One-shot regression | The current public one-shot probe reproduces all 92 saved complete wires byte-for-byte; the gate also rechecks full reference decode and does not rerun or rewrite the historical executable. |
| ZIP integration | The 93 public-root executions cover null-mode wire parity, known/unknown entries, ownership/deinit and error accounting through unencrypted, ZipCrypto, WinZip AES and PKWARE Strong routes. Failure injection distinguishes direct encrypted output from retained Strong-encryption bridge bytes. |
| Skippable/concatenated/reset | Standard skippables, magicless rejection, cumulative counters, new settings/dictionaries and retained capacity pass. |
| Fixed libzstd 1.6.0 differential | 171/171 cases pass with exact input consumption and full plaintext checks. All ten strategies are observed, maximum independent Block sequence count is 1248, and actual peak active workers is 2. |
| Long-input requested heap | Standard and magicless 256 KiB/1 MiB/4 MiB rows retain stable capacities; the observed requested-heap peak is 269,835 bytes for the locked 32 KiB-history/8 KiB-job configuration. This is not RSS. |
| Synchronous fallback | ReleaseFast passes 62 and skips only the inapplicable partial-OS-spawn case; no OS worker starts. |
| Wasm32 execution | Four exported operations pass under Node with no imports, zero OS workers, 8 MiB fixed backing, 4 MiB requested cap, owned-input overwrite, partial credit, dictionaries/reset and quota refusals. |

The existing [one-shot functional baseline](zstd-parallel-frame-functional-baseline.md)
and its source/ELF/GDB/counter corrections remain historical. The new runtime
ownership/history/sealing results above are independent evidence; one-shot passed
counts alone do not validate the class. The original libzstd 1.6.0 reference ELF
`c76f4c4457df67a5e0c7bb6bb4f58b9857cf4f2cdd7925bfb9345daac4e6b83e` and
header `17d279cd45a6881e87eb1801e08d2d29be200ff47811a1ff3168947cad2029bd`
can be reused from the [committed reference archive](data/zstd-parallel-frame-20261026/reference.tar.xz)
without refreshing historical
build flags or older Brotli/Zstd timing reports.

Future evidence must retain actual source/QA/tool/executable/reference epochs and
every initial failure/correction. Prefix/history/job/control/codec/front heap,
logical credits and retained capacities remain distinct; caller buffers/stacks/
private overhead are excluded. No full plaintext/frame staging or constant-RSS
claim is inferred from bounded state.

The reference identity is the pinned libzstd/header pair above. The executed
campaign preserved its source set before and after all 171 cases, and the saved
one-shot report hash was
`46a2e35261f4f6bc573d7faecd4d97f9c08446ead2de89f91f37f6e6ab5802da`.
Post-rebase verification remains a separate integration record. This functional
slice does not establish libzstd MT algorithm/ratio/speed equivalence or
industry-best status. Broader reproducible public streaming/one-shot corpus,
platform and competitor-memory comparisons remain necessary.
