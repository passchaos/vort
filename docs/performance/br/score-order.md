# Brotli partial-tree scoring order, 2026-11-03

Converged literal-context maps now request exact tree scores in stable
descending-total order. Large trees often contribute most of the payload
cost, so the existing strict partial-sum threshold can reject a losing map
before requesting its remaining trees. This order is an estimate of useful
work, never a lower bound or a new quality gate.

Tree IDs, histogram compaction, context maps and wire order remain unchanged.
Equal totals retain tree-ID order. The exhaustive reference specialization
still scores in the original order. Both proposal slots retain their original
thresholds and strict tie rules; complete sums alone enter the map cache.
The fixed sorting helper is a cohesive module with 64 bytes of declared
index storage and no allocator calls. This is not total encoder stack or RSS.

## Actual work and correctness

An independent source copy records every compact total and full exact tree
cost at 456 real map misses in MR, Mozilla and Dickens 64 KiB q8 plans. It
leaves the original map/tree caches untouched. Replaying original requests
and map-cache publication gives:

| Order | Exact-tree requests, including cache hits | Reduction |
| --- | ---: | ---: |
| Original tree-ID order | 4,996 | — |
| Stable total descending | 4,127 | 17.39% |
| Only the largest total first | 4,981 | 0.30% |
| Actual exact-cost descending upper bound | 4,101 | 17.91% |

There are 92 complete-to-partial conversions and no partial-to-complete
conversion or individual-map request increase in this diagnostic sample.
Both prior map-cache hits remain. These are actual-work counts, not timing.

The retained candidate confirms the 4,996 to 4,127 request reduction and
reduces cache misses from 3,253 to 2,815, or 13.46%. Across the six searches,
trials remain 528, rounds 1,344 and assignment comparisons 862,851. All
proposal shape/savings fields and all candidate event configurations/results
match the baseline in nine profiled calls. Final wires and round trips match.
The reordered tree cache has a different replacement history; its complete
frequency equality and successful-publication rules are unchanged.

For any full cost at or below threshold, nonnegative exact costs keep every
partial sum at or below threshold regardless of order. Above-threshold maps
can change complete/partial outcome. A complete losing result that only
improves a mode-local slot cannot beat the existing cross-mode incumbent or
tighten its effective threshold, so it cannot alter final public proposals.
Errors in reached scores still propagate; skipped scores may contain an
allocation failure. Failure occurrence need not match the original request
index, but cleanup and final successful proposals must remain correct.

## Ordinary encoding evidence

Baseline source is `acdf7814` (codec-identical to `98c8a77e`). Independent
baseline/candidate binaries call the public q8 quality API through
`tools/br/planned_encode_bench.zig`: generic mode, actual wire window 16,
reference quality 8/generic/window 16. Twelve Silesia sources at 4/16/64 KiB
give 36 rows. Three outer sweeps alternate process order, producing 216
verified processes. Each report retains all five alternating Vort/reference
timing rounds, with three encodes per round. Row ratios use the median paired
candidate/baseline ratios; complete input and both wire identities must match.

Host: Intel Core i7-10700K, logical CPU2, one codec thread. Vort builds use
Zig 0.16.0 ReleaseFast, GNU x86-64, `skylake+pku+sgx`. Reference Brotli 1.2.0
is clean source `558fc647cdaf391228d614ca85f711e02e4e583b`, CMake Release,
`-O3 -march=skylake`. The retained encoder/decoder/common libraries are the
same pinned loader-verified build used in the [interval-cost evidence](interval-cost.md).

| Scope | Geometric paired time ratio | Faster row medians |
| --- | ---: | ---: |
| 4 KiB | 0.98682 | 12/12 |
| 16 KiB | 0.99061 | 12/12 |
| 64 KiB | 1.00034 | 7/12 |
| All 36 | 0.99257 | 31/36 |

The overall gain is about 0.74%; the large-input group is neutral. Individual
64 KiB points include NCI 1.02453 and XML 1.00881. Eleven longer alternating
pairs at seven encodes per round check the target and the weak controls:

| 64 KiB input | Median paired ratio | Geometric paired ratio | Wins |
| --- | ---: | ---: | ---: |
| Mozilla | 0.99271 | 1.00130 | 10/11 |
| NCI | 1.00256 | 1.00907 | 3/11 |
| XML | 1.00162 | 0.98755 | 5/11 |
| Reymont | 1.00082 | 0.99859 | 5/11 |
| X-ray | 0.99736 | 0.98666 | 7/11 |

The large original NCI/XML points shrink in the longer median comparison;
NCI still has a small median regression and a noisier geometric regression.
The full 64 KiB group and the individual controls are not claimed as wins.
[All row results](score-order-20261103.csv) retain the matrix medians and
paired wins. This modest request-order improvement leaves the much larger
q8 reference latency gap open.

## Validation and reproduction

An independent selection oracle compares 651 stable permutations over
0…64 entries, u32-max totals, ties, monotone and random distributions.
Another 28,214 comparisons verify complete sums, strict thresholds, zero
costs, last-tree threshold crossing, reached/skipped errors, poisoned
unused prefixes, immutable inputs and mode/global slot selection. Compile-time
cases and selected Debug/ReleaseSafe/ReleaseFast runs all pass.

The 33-test context regression passes in ReleaseSafe, including full-field
ordinary/profiled/exhaustive proposals and allocation-failure cleanup.
The complete build-integrated ReleaseSafe Brotli suite passes 1,506 tests
with one skip and exit zero. The default `check check-wasm` build completes
212/212 steps. The older extra ReleaseSafe whole-library build later completed
with exit zero on 2026-11-03. It is a separate build epoch, rather than a
current-source verification of later increments.

Artifacts live in `zig-out/br-q8-score-order-20261102`: `order-evidence.json`,
original/full-cost diagnostics, frozen source/binaries, `score-screen.py`,
`score-matrix.py`, `score-long.py`, every JSON timing round, candidate-event
equality, mechanism counts and validation logs. Driver commands are:

```sh
python3 zig-out/br-q8-score-order-20261102/score-matrix.py
python3 zig-out/br-q8-score-order-20261102/score-long.py
taskset -c 4,5,6,7 zig build -j4 test-br -Doptimize=ReleaseSafe --summary all -- --test-timeout 900s
taskset -c 4,5,6,7 zig build -j4 check check-wasm --summary all
```

An independent packed/sentinel Huffman queue prototype passed its correctness
oracles, but its five-input ordinary screen was neutral at 1.00168 geometric
latency. It remains isolated under `zig-out/br-huffman-queues-20261102` and is
not adopted. The next larger target is the fixed-price optimal parser's
redundant prefix-bound cost comparison, followed by broader search/model work.
The full Deflate/Zstd/Brotli industry-best goal stays active.
