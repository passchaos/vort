# Brotli literal-context proposal pruning and shared tree memo

Date: 2026-10-27. Baseline: `ba275bb6`. CPU: Intel i7-10700K, 16 threads,
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
  f64 error over at most 256 symbols is far below 0.1 bit, so the one-bit
  margin is a strict, platform-independent floor. `frequency*log2(frequency)`
  is lazily tabulated once per distinct frequency (`WeightTable`), making
  each bound evaluation a pass of f64 multiplies. The table is a direct
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

Suffix cutoffs use both tiers: the integer bound runs first (it is free
besides symbol work already in scope), then the entropy bound only once a
suffix incumbent worth at least two gates exists and only when the integer
bound is within one literal-count of the threshold — a proven necessary
condition, since the entropy bound tightens the integer bound by less than
one bit per literal. A pruned cutoff invalidates the payload memo because its
histogram changed even when the newly merged context was empty.

Clustered maps use only the zero-extra-work check
`context_map.bit_cost > threshold`: the map is planned for every scored-cache
miss anyway. Per-tree lower-bound scans over clustered maps were measured as
a net regression on text (see below) and are not shipped.

## Validation

`context_cache_tests.zig` runs the exhaustive reference, pruned production
and profiled searches with exact proposal equality, input/command
immutability, balanced failing-allocator ledgers, and per-allocation failure
injection. New coverage:

- 128 randomized cases (four distributions x eight lengths x three command
  layouts) with byte-exact proposal equality.
- 400 randomized frequency vectors asserting the Shannon floor never exceeds
  the exact tree cost, including uniform, power-of-two, skewed and noisy
  weights.
- Four-way memo unit coverage: cold/conflict classification, LRU eviction,
  owner-mode reporting and same-set vector-collision rejection.

The focused Brotli filter passes 76/76 in Debug, and the profile CSV/gate
exposes `suffix_lb_pruned`, `cluster_lb_checks` and `cluster_maps_pruned`
with counter-conservation assertions.

## Point measurements

Twelve Silesia files (`/home/passchaos/Work/corpora/silesia-20261025`),
4/16/64 KiB prefixes, one insert command, min of nine single-threaded
ReleaseFast iterations per row; baseline is `ba275bb6`. All selected
proposals match exactly. Geometric mean of the 36 total-search ratios:

| Configuration | total_ns geometric ratio |
| --- | ---: |
| Set-associative shared memo only (pruning off) | 0.983 |
| Final: memo + gated suffix lower bounds | 0.976 |
| Withdrawn: dense global-support per-tree cluster bounds | 1.00 |
| Withdrawn: sparse-marker per-tree cluster bounds | 1.044 |
| Withdrawn: f64 entropy bounds on every map/cutoff | 1.090 |

Representative final ratios (total search): dickens 16/64 KiB 0.918/0.923,
samba 16/64 KiB 0.968/0.929, osdb 64 KiB 0.932, sao 64 KiB 0.930, and the
already-context-separated `x-ray` medical image 0.902/0.874/0.896 with
179/217/221 of 252 suffix evaluations pruned. Most 4 KiB rows are flat (no
strong incumbent, no bound work). One measured row, mr 16 KiB, regresses
~7% with zero successful prunes; the entropy pass there costs more than it
saves, and a follow-up should target a cheaper fixed-point entropy pass
rather than loosen the provable gates. These are point measurements without a
statistical-significance claim; system noise affects the 4 KiB rows most.
