# Grouped Brotli literal-context assignment

Literal-context clustering now stores assignment costs as `[symbol][tree]u16`
and evaluates four adjacent trees together with exact `u64` integer lanes.
Each sparse frequency is loaded once per four-tree group, and adjacent tree
costs are contiguous. The fixed workspace remains 32 KiB and adds no heap
allocation. The kernel lives in `src/br/encoder/assignment_costs.zig`.

Only active symbols and requested trees are initialized or read. The scalar
remainder handles tree counts outside full four-tree groups. Widening occurs
before multiplication; even 256 maximum u32 frequencies times maximum u16
costs sum below `2^56`. Ascending tree order and strict `<` preserve ties.
Costs remain frozen during an assignment round, while moves update histograms
for the next round. The exhaustive `prune=false` oracle retains its original
tree-major layout and scalar algorithm. Candidate search order, code lengths,
wire selection, context-cache state and allocator behavior remain unchanged.

## Ordinary-call result

Baseline is `c507a5c1d10dabfb4cbe9f933b9b486677c8cd04`. Final measurement uses
4/16/64 KiB prefixes from all twelve Silesia files. Three process sweeps reverse
version order on the middle sweep. Each report has five interleaved Vort/reference
rounds of three ordinary calls, yielding fifteen samples per version/case.
Per-case medians are followed by a geometric mean across cases.

Both versions use Zig 0.16.0 ReleaseFast native `skylake+pku+sgx`, one thread
pinned to CPU 2 on an Intel i7-10700K. Formal measurement ran after compilation
completed. Timed work includes allocation/free. Vort has an untimed warmup
before each primary round; the reference has no explicit warmup.

| Prefixes | Candidate/baseline encoding time |
| --- | ---: |
| 4 KiB, 12 cases | 0.946594 |
| 16 KiB, 12 cases | 0.938800 |
| 64 KiB, 12 cases | 0.955362 |
| All 36 cases | **0.946894** |

The combined point is about **5.31% less encoding time**. All 36 point ratios
are below one. All input hashes, wire hashes/lengths and settings agree across
versions, sweeps and the earlier exploratory epoch. The ordinary runner cross
decodes both implementations outside timing.

Reference settings match q8, generic mode and actual wire lgwin16. The local
clean Brotli 1.2.0 checkout is commit
`558fc647cdaf391228d614ca85f711e02e4e583b`, built with GCC
`-O3 -DNDEBUG -march=native`. Current candidate/reference encoding-time ratio
is **37.3951**, and encoded-size ratio is **0.995560**. Canonical requested
library files and API versions are recorded; actual loaded objects and
transitive dependencies remain explicitly unverified in this tool epoch.
The competitor gap remains substantial. Points from different measurement
epochs do not form a controlled estimate of changes in that gap.

The earlier single-sweep ratio 0.942530 is retained separately and excluded
from the final result. These measurements do not establish statistical
significance, general maximum stack use, performance on other architectures
or industry-best results.

## Validation and evidence

Independent integer contracts cover every tree count 1–64, empty/sparse/dense
supports, maximum frequencies and costs, cross-group/tail ties and inactive
cells left undefined. Native Debug and ReleaseFast tests pass. The preparation
oracle also checks transposed costs against the old scalar Q8 model. Focused
literal-context gates pass 82/82 in Debug and ReleaseFast, including proposal
and profiling contracts. Public q8 profile/resource contracts pass 25/25.

Three public q8 profile rounds each for Mozilla, Dickens and MR retain complete
non-time-field equality: context counters, proposal configurations, selection
events and returned-wire linkage. Their diagnostic timings have different
affinities and are excluded from performance comparison. Normal calls add no
clock reads.

Native/Wasm compile and CLI help checks pass 212/212 with exit 0. The new
`test-br-assignment-wasm` executes the same independent integer contracts on
generic and SIMD128 Wasm targets and participates in CI. Combined with the
public frozen-baseline q8 gate, nine build steps pass. The actual public
64 KiB fixture emits the same 14,362-byte stream, verified by Zig and Node
decoding. [Wasm correctness evidence](brotli-assignment-wasm.md) preserves
modules, emitted target features, source overlays and replay commands.

[The ordinary evidence package](data/brotli-assignment-20261028/) preserves
both raw epochs, per-case rows, exact commands, source/tool/executable/library
identities, profile equality, terminal completion records and a verifier.
Other compression dependencies are referenced by the baseline commit.

After `pull --rebase origin main`, Debug/ReleaseFast context tests each pass
82/82 and public profile/resource tests pass 25/25. Combined compile, both
Wasm gates and CLI help checks pass 219/219 with terminal exit 0. Tested source
hashes match the formal measurement. Only documentation/evidence was amended
after verification; the package retains the final logs and completion metadata.

Next, prepare candidates, count exact wire bytes, select in the original order
and emit the winner. Eliminating loser buffers changes observable allocation
failure points and actual peaks; verify the resulting real peak/peak-minus-one
limits, sticky budget refusal and normal/profile parity. Evaluation events
need real IDs and length comparisons while final emission retains real wire
linkage. The full ten-format optimization objective remains active.
