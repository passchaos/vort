# Brotli partial cluster scoring

Converged literal-context maps now stop exact tree scoring when their known
bit cost exceeds the threshold for every proposal slot they may enter. The
known cost includes the complete context-map declaration and all trees already
scored. Remaining costs are nonnegative, so they cannot make that map win.
Equality continues scoring to preserve the existing savings and tree-count
tie rules. The exhaustive reference specialization still scores every tree.

The scorer publishes a map-cache entry only after a complete successful sum.
An over-threshold sum reached on the last tree remains complete and may be
cached. Partial sums never enter the map cache; completed individual tree
scores remain reusable. Reached scorer errors propagate. No cache storage or
heap allocation is added to the ordinary encoder. The internal helper requires a
representable u64 total, which the bounded byte-histogram caller guarantees.

`cluster_tree_scores_pruned` counts maps abandoned after at least one exact
tree request, with other trees remaining. Profile timing includes these early
returns. The CSV producer emits 98 columns; its gate also accepts the previous
97-column schema with a zero partial-map count. The accounting gate checks the
combined minimum of two requests per complete map and one per partial map.
Native reference/profile tests exercise the same accounting and require a
deterministic random fixture to actually take the new cutoff.

## Ordinary encoding evidence

The [evidence package](data/brotli-partial-cluster-scoring-20261028/) records
three clean sweeps of twelve Silesia files at 4/16/64 KiB, q8, generic mode and
actual 16-bit windows. Baseline production is `85aa84bf` (the benchmark snapshot
was `620efa74`; the intervening commit adds tests/docs only). Measured source
hashes and both benchmark executable hashes reconcile with the archived
reports. Final caller follow-up adds only cache-revisit assertions and a
threshold comment correction; the exact measured files remain in the overlay.

| Scope | Candidate/baseline encoding time |
| --- | ---: |
| All 36 prefixes | **0.987021** |
| 4 KiB | 0.976770 |
| 16 KiB | 0.989506 |
| 64 KiB | 0.994874 |
| Sweep 1 / 2 / 3 | 0.983720 / 0.988876 / 0.986386 |

Per-case medians combine fifteen samples per variant: five alternating
Vort/reference rounds per report, each timing three encoding calls. Variant
order reverses in the middle sweep. Input hashes, all wire hashes and settings
agree across the eighteen reports. Three individual points regress: Dickens
16 KiB (1.005487), X-ray 64 KiB (1.000128) and Mozilla 64 KiB (1.000120).
The aggregate observation is about 1.3% lower time; it does not establish
statistical significance or a gain for other qualities, platforms or corpora.
Discovery and compilation-overlap runs are retained separately and excluded.

Runs use Zig 0.16.0 ReleaseFast native `skylake+pku+sgx`, Intel i7-10700K,
one thread pinned to CPU 2. Allocation and free are timed. Vort has one untimed
warmup before each primary round; the reference has no explicit warmup. The
requested reference is the same local Brotli 1.2.0/`558fc647` GCC build with
`-O3 -DNDEBUG -march=native`. Requested encoder/decoder/common files are hashed
in the reports; this runner epoch leaves loaded-object identity and dependency
verification unset. This limits the reference comparison.

The candidate/reference geometric time ratio is 36.7268 with an encoded-size
ratio of 0.995560. This improvement leaves a substantial throughput gap to
the reference. The ten-format goal remains active.

The next concrete target is adaptive-distance split candidate preparation.
The three candidate-only 64 KiB profiles each build six adaptive-distance
wires. Four rejected literal-context alternatives account for 3.946/6.165/
4.093 ms on Mozilla/Dickens/MR, or 8.11/12.40/6.93% of their profiled calls.
The existing prepared command/distance path excludes split plans; the existing
count-before-emission candidate group covers the unsplit path. Extend exact
counting and immutable command/distance preparation to this split family,
then emit the final winner once. Preserve split planning, candidate order and
complete wire equality; these diagnostic costs identify a target rather than
prove its prospective ordinary-call benefit.

A second probe is `literal_block_split.chooseProposals`: its pair/triple
search rebuilds Huffman lengths for repeated contiguous intervals. For MR's
recorded 4277/4308-literal plans, counting eligible source-code branches gives
204 length-builder calls per search, including 136 interval requests for only
27 distinct intervals. A bounded memo over the existing split endpoints could
avoid 109 builds per search while retaining costs and candidate order. MR's
10.115 ms split-planning exclusive time includes other splitters, so first
attribute actual calls and time to this scorer before making a benefit claim.

The staged profile has three baseline rounds and one candidate round. After
normalizing by rounds, exact cluster tree-cache misses change from 1994 to
1837 for Mozilla, 620 to 611 for Dickens and 913 to 805 for MR. The candidate
abandons 71/22/86 maps respectively. Profile clock totals are diagnostic;
ordinary encoding reports above are the performance evidence.

## Reproduction and validation

Extract a baseline snapshot at `85aa84bf` and a candidate snapshot with the
measured `source-overlay.tar.xz`. Build the ordinary runner using the module
arguments in `compile-reference.json`, substituting local output paths and a
ReleaseFast object from unchanged `src/br/encoder/record_optimal_object.zig`.
`matched_measure.py` in the overlay records all corpus and reference arguments;
adjust its root/corpus paths before rerunning. Preserve both variants' raw
reports and recompute medians from rounds, rather than their minimum CSV times.
A rerun is a new measurement epoch.

The original focused archive records the three scorer tests on native
ReleaseFast, actual 32-bit x86 Linux and Node-executed wasm32-wasi. Current
validation and command outcomes are recorded in `final-validation.json` and
`final-validation.tar.xz`. Proposal tests compare exhaustive, ordinary and
profiled searches over threshold neighbors, every RFC mode, 128 randomized
distributions, scattered inserts, high bytes, input ownership and allocation
failures. The public q8 Wasm gate compares complete output with its frozen
baseline and verifies decoding in Zig and Node. Standalone and focused tests
are distinguished from the separate whole-build gates in the validation
record.
