# Brotli literal-context proposal pruning and shared tree memo

Date: 2026-10-27/28. Initial baseline: `ba275bb6`; fused-pass
follow-up baseline: `71855833`. CPU: Intel i7-10700K, 16 threads,
Zig 0.16.0 ReleaseFast. The objective of industry-best functionality and
performance remains incomplete.

The q8 literal-context search evaluates all four RFC 7932 context modes, 63
suffix cutoffs, and 88 clustering trials (11 tree counts, two seeds). Every
surviving candidate used to require its own exact Huffman tree scoring; the
128-entry exact-score memo was direct-mapped and lived only inside one mode.
This increment (1) shares one set-associative memo across the four modes and
(2) prunes suffix cutoffs and clustered maps through provable lower bounds
before exact tree scores are built. Selected proposals stay byte-identical to
the exhaustive reference policy (`chooseProposalsReference`), which is kept as
the differential oracle.

## Shared set-associative tree memo

`literal_tree_score_cache.zig` replaces the direct-mapped 128-slot table with
32 sets of four ways (still 128 entries) and one cache per complete proposal
search, shared by all four RFC modes. A tree score is a pure function of its
256 frequency entries under the immutable shared parent support, so a vector
match in any mode reuses the score. Hits still require the complete vector to
compare equal; hash equality alone never returns a score. Replacement is
least-recently-used inside a set, tracked by wrapping ticks. Each hit reports
the publishing mode, so the profile records real cross-mode reuse; requests,
hits/misses and cold/conflict classifications keep their existing identities.

The earlier shared-cache experiment recorded in
`brotli-context-score-experiment.md` shared a *direct-mapped* memo and was
withdrawn at 0.995x. Set associativity is what makes sharing a net win on the
same workload.

## Provable lower bounds

Two bounds are available for one tree:

- The integer bound sums `frequency * floor(log2(total / frequency))` using
  two bit scans and one shift per symbol. Per symbol it never exceeds the
  Shannon contribution. The declared-prefix allowance is exact for <=4-symbol
  simple prefixes (`4 + 8*n + (n == 4)`) and a two-bit HSKIP floor otherwise.
- The entropy bound uses the weighted Shannon sum
  `total*log2(total) - sum frequency*log2(frequency)` in f64, rounded down
  after a fixed 1.0-bit/tree safety margin. Each term is below 2^37 and the
  strict f64 error over at most 256 symbols is far below one bit when
  `log2` has a few-ulp error. This is the numeric assumption behind the margin;
  the Zig builtin does not document a universal ULP contract. `frequency*log2(frequency)`
  is lazily tabulated once per distinct frequency (`WeightTable`), so the
  fused per-symbol work is one table lookup plus f64 add. The table is a direct
  indexed allocation up to 131072 frequencies (1 MiB) and a fixed
  4096-slot open-addressing memo above that, so peak added memory stays
  bounded at the 2^24-byte meta-block limit.

Huffman's weighted code cost is at least the entropy, so neither bound can
exceed the exact `treeBitCostWithSupport`. Pruning rejects a candidate only
when its bound strictly exceeds the tightest cost that could still clear the
128-bit gate and beat every eligible incumbent. Bound equality is kept, never
pruned, so exact tie behavior is unchanged. The bounded up-to-16 slot uses
separate <=16-tree incumbents: a >16-tree full winner cannot reject a
bounded candidate, which was caught by the differential suite during
development.

Suffix cutoffs compute both bounds for the two cumulative trees in a single
pass over the shared support (`suffixPayloadBounds`): the per-symbol floor
log2 term and the `frequency*log2(frequency)` accumulation interleave, so the
tighter entropy bound costs table lookups and f64 adds instead of a second
256-entry scan. A cutoff is pruned when either bound strictly exceeds the
threshold. An earlier revision gated the entropy pass behind a strong
incumbent and a within-one-literal proximity test, but its second support
scan added work on mr 16 KiB despite zero successful prunes. The fused pass
reduces that work without relaxing any rejection threshold. A pruned cutoff
invalidates the payload memo because its histogram changed even when the
newly merged context was empty.

Clustered maps use only the zero-extra-work check
`context_map.bit_cost > threshold`: the map is planned for every scored-cache
miss anyway. Per-tree lower-bound scans over clustered maps were measured as
a net regression on text (see below) and are not shipped.

The follow-up removes the 128-entry histogram entropy cache and its heap
allocation. Exact score replacement stays in `literal_tree_score_cache.zig`;
frequency memoization and strict floating arithmetic now live in
`literal_entropy.zig`, and the fused suffix floors in
`literal_context_bounds.zig`. The zero/one-count entropy case returns zero
without taking `log2(0)`.

## Validation

`context_cache_tests.zig` runs the exhaustive reference, pruned production
and profiled searches with exact proposal equality, input/command
immutability, balanced failing-allocator ledgers, and per-allocation failure
injection. New coverage:

- 128 randomized cases (four distributions x eight lengths x three command
  layouts) with byte-exact proposal equality.
- 400 randomized frequency vectors asserting the Shannon floor never exceeds
  the exact tree cost, including uniform, power-of-two, skewed and noisy
  weights. Both backends now receive the same randomized vectors, and the
  comparison uses exact weighted payload **without tree headers**.
- 96 direct fused suffix-bound comparisons with independent exact tree costs,
  including totals of 2^24, separate left/right supports, and poisoned entries
  outside the parent support.
- Cross-mode cost 55 rejects a cost-56 cutoff, including following empty
  contexts; later cheaper map costs recover the exact scorer. Cost equality
  retains the first score and never prunes it.
- Dense/fallback weight equality under collision pressure, singleton payload
  zero through `maxInt(u32)`, and exact balanced two-code entropy near 2^24.
- Four-way memo unit coverage: cold/conflict classification, LRU eviction,
  owner-mode reporting and same-set vector-collision rejection.

The final focused filter passes 79/79 in Debug, and the profile CSV/gate
exposes `suffix_lb_pruned`, `cluster_lb_checks` and `cluster_maps_pruned`
with counter-conservation assertions.

## Retained ordinary-call measurements

The follow-up compares current frozen candidate code with `71855833` on the
Intel i7-10700K in Zig 0.16.0 ReleaseFast, single-threaded and pinned to CPU 2.
Other validation jobs exclude CPU 2 and its sibling 10. Twelve Silesia files
(`/home/passchaos/Work/corpora/silesia-20261025/files`), 4/16/64 KiB prefixes,
produce 36 cases. The component benchmark uses one insert command, warms up
outside timing, and checks every result against exhaustive and profiled
searches outside the ordinary-call timer. Five interleaved version blocks,
nine samples each, are reduced to the median of each block's minimum.

| Surface | Candidate/baseline geometric time ratio | Output check |
| --- | ---: | --- |
| Ordinary literal-context proposal search | 0.9451 | All 36 complete proposals equal |
| Public q8 one-shot encoding | 0.9908 | All 36 wire SHA-256 values, sizes and settings equal |

The encoding surface uses the existing public `planned_encode_bench` with
q8/generic, ten ordinary samples per version and case, interleaved with
libbrotli q8 and reversed version order in the second sweep. The reference
files are explicitly named and hashed (libbrotli 1.0.9). Vort's default
lgwin16 and libbrotli's lgwin22 are recorded; these measurements establish the
Vort before/after effect, without assigning a matched-window competitor
ranking. Native and libbrotli round-trip checks run outside timed calls.

The search improvement is about 5.5%; the complete encoding improvement is
about 0.9% in this point measurement. Most encoder cost remains elsewhere.
These samples do not establish statistical significance, an all-corpus gain,
or industry-best ratio/speed/memory. The retained intermediate fused code
runs at 0.9392 on the component surface; the final module split and strict
numeric helpers run at 0.9451. The previous committed gated-bound measurement
of 0.976 versus `ba275bb6` is a separate earlier epoch.

[Raw samples, per-row results and reproduction commands](data/brotli-fused-suffix-20261027/README.md)
retain input/executable/library identities, exact commands and source files.
