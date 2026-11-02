# Fixed-price optimal prefix bound, 2026-11-03

The fixed-price LZ77 parser no longer loads and adds a prefix-choice cost just
to confirm an inequality already guaranteed by prior candidates. The existing
byte mismatch, candidate/chain limits, length choices, strict ties and parser
output remain unchanged. Modeled parsing keeps its original policy. The
representable-cost guard is a cohesive helper; the old bound-enabled cost
comparison remains available to the independent test specialization.

## Proof and applicable range

At position i, let B[k] be the minimum of `length_price + suffix_cost` over
lengths 4…k. The suffix DP is already final. Examining a candidate that first
establishes the longest frontier k guarantees `current <= B[k] + D_old`,
whether that candidate updates the chosen DP step or merely loses to it.
Predecessors are nearest-first, so each later distance is greater. Fixed
distance prices are nondecreasing over 1…32768, hence
`B[k] + D_new >= current`. A mismatch at byte k bounds the new match length
by k, so that candidate cannot strictly improve the cost. Its old cost check
is redundant; all quota accounting remains in the same branch.

This proof requires non-overflowing costs. With minimum match four, B[k]
includes the four-byte edge priced at seven bits. A literal-only suffix is
at most nine bits per byte and the maximum fixed distance price is eighteen:

```text
B[k] + Dmax <= 7 + 9*(n-i-4) + 18 = 9*(n-i)-11 <= 9*n-11
```

The packed 64-bit path already validates a stronger length bound. On 32-bit
targets the simplification is enabled only for `n <= maxusize/9`; larger
inputs retain the original comparison, with no new API rejection. The pure
range helper is tested using u32/u64 neighbors without huge allocations.

The distance-price load remains in the profile rejection branch for its
histograms and slack, and occurs after the rejection branch for ordinary
accepted candidates. Fixed allocating/reusable/profiled and prepared-fixed
entries use the simplification. All modeled entries still disable the prefix
bound. No match frontier or cache is stored, and no allocation is added.

## Workload evidence

An isolated diagnostic invokes the actual q8 fixed optimal caller on MR,
Mozilla and Dickens 64 KiB plans: window 32768, chain 128, candidates 64,
nice length 192, minimum 4 and maximum 258. Profiled/unprofiled tokens and
stats agree, and the complete q8 wires match the frozen public encoder.

| Input | Chain nodes | Bound rejections | Match-length calls |
| --- | ---: | ---: | ---: |
| MR | 4,503,294 | 2,021,048 | 212,705 |
| Mozilla | 1,604,806 | 934,124 | 74,293 |
| Dickens | 2,059,669 | 619,412 | 93,129 |

Those rejected candidates formerly loaded B[k], added the distance price and
compared with current cost. Diagnostic clocks identify the parser workload,
not an ordinary throughput gain.

## Ordinary public q8 comparison

Baseline source: `17ecc612`, including the preceding score-order increment.
Independent binaries use `tools/br/planned_encode_bench.zig` with quality 8,
generic mode and actual wire window 16 on both Vort and Brotli 1.2.0.
Twelve Silesia sources at 4/16/64 KiB give 36 rows and 216 verified processes
in three alternating outer sweeps. Each report retains all five timing rounds
at three encodes per round; each row uses the median paired time ratio.
Every input and both complete wire identities remain identical.

Host: Intel Core i7-10700K, logical CPU2, one codec thread. Vort uses Zig
0.16.0 ReleaseFast, GNU x86-64, `skylake+pku+sgx`. Reference Brotli 1.2.0 is
clean source `558fc647cdaf391228d614ca85f711e02e4e583b`, CMake Release,
`-O3 -march=skylake`, using the pinned encoder/decoder/common closure recorded
in [interval-cost evidence](interval-cost.md).

| Scope | Geometric paired time ratio | Faster row medians |
| --- | ---: | ---: |
| 4 KiB | 0.99516 | 6/12 |
| 16 KiB | 0.99649 | 8/12 |
| 64 KiB | 0.98522 | 11/12 |
| All 36 | 0.99228 | 25/36 |

The overall gain is about 0.77%, concentrated in larger inputs. Individual
small rows remain within about 0.3% median regression; the largest is Dickens
16 KiB at 1.00289. [All row results](fixed-prefix-bound-20261103.csv) retain
independent medians and paired ratios, which need not equal their quotient.

An initial five-input screen had an OSDB 16 KiB median regression of 2.84%.
Eleven longer alternating pairs at seven encodes per round resolve MR 64 KiB
to 0.98481 median / 0.98357 geometric latency, all eleven wins, and OSDB
16 KiB to 1.00197 median / 1.00476 geometric latency, three wins. The matrix
OSDB row is 0.99583. These separate observations retain the small control
movement rather than claiming universal gains. A variant restoring the
original early distance-price load was mixed across five rows and remains
isolated; its result is not combined with the retained variant.

The matrix candidate still takes 31.69 times Brotli 1.2.0 encoding latency
geometrically, at size 0.99556 times reference. This is a separate reference
epoch; gains from previous commits are not multiplied into that ratio.

## Independent validation

The oracle compares old bound-enabled and optimized ordinary/profiled paths
over 110 input/settings cases, including empty/tiny, random/repetitive and
structured inputs, 4…258-byte words, distance/window and chain/candidate
boundaries. It checks every token, stats field, DP cost/step and non-time
profile field. Token replay is independent; caller input stays immutable.
Poisoned DP reuse and 220 warm calls require no new allocator request.
Cold failure/retry cases clean up every reached allocation.

The concrete witnesses retain a nearer distance on the 33/49 price plateau,
and build a longer frontier from a losing distance-16385 match before another
far candidate is rejected. Their exact edges are checked against completed
suffix costs. The latter near-distance-16 expectation was corrected from
eight distance bits to seven, leaving all paths and witness checks intact.

There are 22 u32/u64 range-neighbor checks and eighteen checked sum/slack
assertions near max/9, plus compile-time range cases. Native Debug,
ReleaseSafe and ReleaseFast oracles pass. Actual x86 ReleaseSafe additionally
executes the existing bound-disabled oracle and fixed-price monotonicity test,
passing 5/5 tests. The selected optimal suite passes 25 tests and the complete
Deflate ReleaseSafe suite passes 591 tests. The full build-integrated Brotli
and Zstd suites pass 1,507 plus one skip and 1,262 tests, respectively, with
combined exit zero. The default `check check-wasm` build completes 212/212
steps with exit zero. The public prepared-command Wasm gate preserves the
complete frozen wire and passes Zig/Node decoding, including adaptive-distance
coverage. All ten executable ELF sections in the final production benchmark
match the measured candidate. The older extra ReleaseSafe whole-library build
later completed with exit zero on 2026-11-03. This separate build epoch does
not replace the current-source gates recorded above.

## Reproduction and bindings

`zig-out/br-optimal-prefix-bound-20261103` retains both source variants,
frozen binaries, every round report, `prefix-matrix.py`, `prefix-long.py`,
`prefix-evidence.json`, oracle logs, whole-codec checks and ELF comparison.
The initial diagnostic proof/counters remain in
`zig-out/br-q8-next-20261102/optimal-*`.

```sh
python3 zig-out/br-optimal-prefix-bound-20261103/prefix-matrix.py
python3 zig-out/br-optimal-prefix-bound-20261103/prefix-long.py
zig test src/lz77.zig -OReleaseSafe --test-filter 'optimal prefix bound'
zig test src/deflate.zig -OReleaseSafe
zig build -j2 test-br test-zstd -Doptimize=ReleaseSafe --summary all -- --test-timeout 900s
zig build -j4 check check-wasm --summary all
```

| Binding | SHA-256 |
| --- | --- |
| Baseline binary | `0622816d4c9fcee9fad020d5288606eb377d20a9991c87f3090930e89b0cf9ea` |
| Measured candidate binary | `4b279120ee4efe1217951a8317391aa689727045229ce901698ade393c33082d` |
| Matrix report | `bd25b24912856c02d479e14ea111a1593be5e69065081c837613b7ac1e9f9fe2` |
| Long control report | `4bf1d86f87efba99bb98472a7f434a7a1e1caa18445bf41411d22820681509c6` |

Larger Brotli search/model and repeated candidate emission costs remain open.
The Deflate/Zstd/Brotli industry-best objective stays active.
