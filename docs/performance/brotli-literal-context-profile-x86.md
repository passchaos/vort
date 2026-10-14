# x86-64 Brotli literal-context proposal stages

Date: 2026-10-14. Baseline: `bed69936`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU affinity 2, one codec thread.

## Purpose

Linux performance counters are unavailable on this host
(`perf_event_paranoid=4`). Earlier fixed-CPU A/B work reduced the `source32k`
ratio path from 130.426 ms to roughly 61 ms, but the remaining literal-context
cost was not attributed below the complete encoder. Several plausible
assignment-loop changes failed paired end-to-end tests, so further tuning
needed an explicit measurement surface rather than another inferred hotspot.

`run-br-literal-context-profile` builds the same bounded optimal command plan
used by ratio diagnostics once, then profiles only the deterministic context
proposal search. The normal encoder calls a `comptime profiled=false`
specialization and therefore carries no clock reads or counters. The profiled
specialization records:

- fused four-mode histogram analysis and the shared one-tree baseline;
- suffix exact Huffman scoring and empty-context payload reuse;
- sparse-view construction and all 88 target/seed cluster trials;
- cluster initialization, assignment-price preparation, reassignment,
  compaction, and final exact tree/context-map scoring;
- proposal shapes, cache hits/misses, rounds, contexts, and tree comparisons.

The CSV gate validates three source sizes, ReleaseFast provenance, candidate
ranges, deterministic counters, nested timing totals, and the dominant
`source32k` cluster stage. A thirteen-case negative smoke rejects missing rows,
counter drift, timing drift, invalid modes, false stage dominance, and
non-ReleaseFast provenance.

## Fixed-CPU result

Command:

```sh
taskset -c 2 zig build run-br-literal-context-profile -- \
  --iterations 10 --csv /tmp/vort-br-literal-context-profile-fixed.csv
```

Times below are totals for ten searches. They include diagnostic clock reads,
so stage shares and counters—not absolute latency—are the primary evidence.

| case | retained suffix/≤16/full trees | total | suffix share | cluster share | exact score within cluster | assignment within cluster |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| source4k | 0 / 0 / 0 | 20.735 ms | 20.9% | 72.1% | 65.0% | 18.0% |
| source16k | 0 / 3 / 3 | 55.138 ms | 43.9% | 52.9% | 68.3% | 19.1% |
| source32k | 2 / 10 / 10 | 61.029 ms | 43.4% | 53.4% | 70.9% | 18.1% |

For `source32k`, the profile records 2,426 literals, 85 active symbols, 880
cluster trials, 1,960 reassignment rounds, 879,560 tree comparisons, 40 exact
score-cache hits, and 620 misses across ten iterations. Exact final tree plus
context-map scoring is the largest cluster substage by a wide margin. Combined
with suffix Huffman scoring, exact entropy-wire evaluation accounts for about
81% of attributed search time. Assignment-loop micro-optimizations are no
longer the first target; the next work should reuse or incrementally update
exact tree scores while retaining full-map equality, exact wire arbitration,
and the current candidate family.

## Production-path control

The new public diagnostic and counters change source bytes, so the previous
and current benchmark binaries were run alternately against the same current
`src/br.zig`. Seven fixed-CPU-2 pairs at 20 iterations favored the profiled-code
build in four pairs; medians were 243.970 ms before and 242.437 ms after
(`1.006x`). This is not claimed as an encoder speedup, but rules out a measurable
production regression from the compile-time instrumentation split.

## Exact single-tree score cache follow-up

The first optimization driven by this profile added a 128-slot direct-mapped
cache per RFC mode for final single-tree Huffman wire costs. Each entry stores
the complete 256-bin histogram. A 64-bit hash selects one slot, but reuse is
accepted only after both hash and full histogram equality; collisions simply
overwrite or miss and cannot change selection. The bounded table occupies
roughly 130 KiB while its mode is being evaluated.

On the same fixed-CPU-2 ten-iteration profile, `source32k` produced 1,750 tree
hits and 2,900 misses, a 37.6% hit rate. The exact-score stage fell from
23.103 ms to 20.046 ms (`1.153x`), cluster time fell from 32.591 ms to
29.142 ms (`1.118x`), and complete profiled search measured 58.747 ms versus
the 61.029 ms baseline (`1.039x`).

The authoritative uninstrumented control alternated the pre-cache and cached
binaries for eleven fixed-CPU-2 pairs at 20 iterations. The cache won 11/11
pairs and reduced the median from 243.309 ms to 240.427 ms (`1.012x`) with
identical 6,475-byte output and checksum 134,745. Focused tests require a true
hit after insertion and inject a matching hash with a different histogram that
must miss, preserving the same collision-safety rule as the complete-map cache.

A bounded capacity sweep rejected both neighboring sizes. At 32 slots, the
`source32k` hit count fell to 1,170/4,650 and exact scoring rose to 22.413 ms.
At 64 slots, hits rose to 1,460 and exact scoring fell to 20.654 ms. Moving to
128 slots yielded the figures above and won 8/11 direct 64-versus-128 process
pairs, reducing their median from 241.014 ms to 239.949 ms (`1.004x`). The
extra roughly 65 KiB therefore clears both stage and complete-encoder evidence;
larger capacities remain unjustified until another measured sweep.

## Associativity and miss classification follow-up

The profile schema now separates empty-slot and occupied-slot misses while the
ordinary encoder retains only its established hit/miss counters. On the
fixed-CPU-2 ten-iteration `source32k` run, direct-mapped 128 slots reported
1,870 empty-slot misses and 1,030 conflicts. Conflicts were therefore 35.5% of
misses, enough to justify one equal-memory associativity experiment.

A 64-set, two-way cache raised hits from 1,750 to 1,900 and reduced the staged
exact-score sample from roughly 19.912 to 19.791 ms. The complete encoder
rejected it: two-way won only 2/11 alternating 20-iteration pairs and regressed
the median from 240.427 ms to 241.644 ms. The extra second-way probe and
replacement path cost more than the 150 additional hits saved. The candidate
was removed and direct mapping retained.

A second control removed all cache counters from the production specialization.
It won only 4/11 pairs and moved the median from 240.107 ms to 240.421 ms, so it
was also removed. Only cold/conflict classification is compile-time profile-only;
the previously validated production hit/miss update and code shape remain.

## Tree-score miss substage breakdown

The profiled specialization now decomposes every real tree-cache miss into
active-alphabet construction, Huffman length generation, weighted payload
cost, and simple/complex prefix wire cost. The production specialization has
no added clocks or substage counters. The CSV gate requires call counts to
equal cache misses, simple plus complex trees to equal calls, nested timing
totals to close, and Huffman length generation to dominate `source32k`.

The fixed-CPU-2 ten-iteration run scored 2,900 cache misses containing 110
simple and 2,790 complex trees with 121,250 aggregate active entries. Of the
12.800 ms attributed inside `treeBitCost`, alphabet construction used 18.1%,
Huffman length generation 57.4%, weighted payload accumulation 2.3%, and
prefix wire costing 22.2%. `source16k` independently placed length generation
at 56.4%. The next optimization target is therefore the <=64-active-symbol
length builder or a proven reuse surface around it; another dense payload loop
rewrite cannot materially move the complete search.

Active-size buckets for `source32k` were 110/540/500/1,050/700 calls for
1–4, 5–16, 17–32, 33–64, and 65–256 symbols respectively. An adaptive
`small_huffman` candidate therefore instantiated capacities 16/32/64 for the
2,090 calls eligible for the fast builder. Despite covering 1,040 calls with
smaller scratch, it increased the fixed profile's length stage from 7.069 to
7.525 ms and won only 4/7 complete-encoder pairs; their median regressed from
242.188 to 242.715 ms. The extra code instances and dispatch were removed.

The first length-builder candidate narrowed `small_huffman` node weights from
`u64` to `u32` after an exact total-frequency guard, retaining package-merge
fallback for wider inputs. It improved the fixed profile's `source32k` length
stage from roughly 7.350 to 7.049 ms (`1.043x`), but the authoritative complete
encoder rejected it: only 4/11 alternating 20-iteration pairs won and the
median regressed from 241.440 to 242.398 ms. The candidate and its extra guard
were removed. Future length work must improve generated layout and complete
encoding, not merely shrink the isolated queue scratch.

## 65–128-symbol two-queue extension

The active-size evidence showed all 700 former package-merge calls in
`source32k` fell in the 65–128 bucket. The retained implementation extends the
same stable two-queue algorithm to 128 symbols: node indexes remain `u8`, while
the parent array uses `u8` only for the wider instance and keeps the existing
`i8` layout for <=64. Any tree deeper than Brotli's 15-bit limit still returns
false and uses the unchanged 256-slot package-merge fallback. A randomized
65–128-symbol oracle compares success and every length against the heap
reference.

On fixed CPU 2 for ten iterations, small-builder calls rose 2,090→2,790 and
package-merge calls fell 700→0. Length generation dropped 7.479→2.096 ms
(`3.567x`), complete `treeBitCost` substages dropped 12.759→7.424 ms
(`1.719x`), cluster exact scoring dropped 20.986→15.740 ms (`1.333x`), and
the full diagnostic dropped 59.882→36.330 ms (`1.648x`). The tree-score
bottleneck consequently shifted to prefix costing (37.1%), followed by
alphabet construction (30.8%), length generation (28.2%), and weighted
payload (3.8%); the gate now locks prefix dominance.

The uninstrumented encoder won all 11 alternating fixed-CPU-2 pairs at 20
iterations, reducing the median from 240.515 to 196.121 ms (`1.226x`) with
identical 6,475-byte output and checksum 134,745.

## Complex-prefix scoring substages

After the 128-symbol length win shifted tree-score dominance, the profile was
extended through `complex_prefix.bitCost`: code-length RLE planning, the
18-symbol code-length tree, header declaration, encoder construction, and RLE
payload costing. The fixed-CPU-2 ten-iteration `source32k` run covered 2,790
complex trees, 172,920 RLE tokens, and 21,510 live code-length symbols. Of the
2.687 ms attributed inside complex-prefix scoring, RLE planning used 40.5%,
the code-length tree 31.6%, encoder construction 11.2%, payload costing 9.7%,
and header declaration 7.0%. The gate now locks RLE as the nested dominant
stage and verifies all call/token/active-symbol and timing relationships.

An eight-byte scan for repeated non-zero code lengths was then tested against
the scalar loop. The isolated RLE sample slightly regressed (about
1.089→1.096 ms), and eleven complete-encoder pairs were neutral-negative:
the candidate won 6/11 but moved the median from 195.103 to 195.138 ms. It was
removed. The next RLE candidate must reduce token/frequency work rather than
add another scan path.

A seven-pair control of the compile-time profile refactor itself won 3/7 pairs
but moved the median from 195.662 to 195.270 ms (`1.002x`). This is treated only
as no-regression evidence; the unprofiled specialization contains no clocks or
prefix-substage counters.

A packed one-byte RLE token then halved the token workspace and improved the
isolated RLE sample from roughly 1.089 to 1.009 ms (`1.078x`). Complete encoding
again rejected the local win: only 4/11 pairs won and the median regressed from
195.591 to 195.922 ms. The packed layout was removed; the ordinary two-byte
field layout remains because its simpler symbol/extra accesses win end to end.

A 64-slot exact cache for the 18-symbol code-length tree was also evaluated.
Each hit required full `[18]u32` frequency equality. It reused 340/2,790 trees
(12.2%) and reduced the isolated code-length-tree sample by roughly 6%, but the
lookup/hash/copy work lost in the complete encoder: only 2/11 pairs won and the
median regressed from 194.908 to 195.910 ms. The cache and its profile schema
were removed.

## Code-length RLE shape

Profile-only shape accounting now runs after the timed RLE stage. For ten
`source32k` searches it observed 337,000 input code lengths: 41,370 zero runs
covering 215,990 lengths and 101,420 non-zero runs covering 121,010 lengths.
The encoder emitted 151,860 literal-length tokens, 530 symbol-16 tokens, and
20,530 symbol-17 tokens. Repeat chains were especially shallow: 11,300 had one
token, 4,880 had two, and none had three or more.

A direct one-/two-token repeat fast path removed the general loop and temporary
array for every observed chain. It improved the isolated RLE stage from roughly
1.089 to 1.017 ms (`1.07x`), but won only 3/7 complete-encoder pairs and moved
the median from 195.410 to 195.469 ms. The candidate was removed. Even a fully
covered branch specialization does not clear the complete-code-layout bar;
future RLE work must remove broader bookkeeping rather than specialize chain
depth.

## Score-only RLE summary

The retained RLE optimization changes only `complex_prefix.bitCost`; the real
writer still emits the original token stream. A score-only summary walks the
same runs but accumulates the 18 frequencies and repeat-token counts without
materializing tokens. Exact payload cost is then
`sum(freq[s] * code_length_bits[s]) + 2*freq[16] + 3*freq[17]`, so scoring no
longer constructs a canonical encoder or replays the token stream. Randomized
256/520/704-alphabet tests compare the summary bit count with the real writer,
and the summary's frequencies/token categories match the existing bounded RLE
encoder exactly.

On fixed CPU 2 for ten `source32k` searches, RLE scoring fell 1.089→0.882 ms
(`1.234x`), encoder construction was eliminated, payload costing fell
0.260→0.048 ms (`5.39x`), and complete complex-prefix scoring fell
2.687→1.964 ms (`1.369x`). Profile-only shape accounting is measured
separately at 0.923 ms and subtracted from the parent tree-prefix stage, so it
cannot distort dominance. RLE remains narrowly largest at 44.9%, followed by
the 18-symbol tree at 43.1%, header declaration at 9.5%, and payload arithmetic
at 2.5%.

Eleven alternating fixed-CPU-2 complete-encoder pairs all won, reducing the
median from 195.119 to 192.659 ms (`1.013x`) with unchanged 6,475-byte output
and checksum 134,745.

## Direct 18-symbol Huffman builder

Complex-prefix scoring now uses a dedicated builder for its fixed 18-symbol
code-length alphabet. It orders live leaves once by `(frequency, symbol)`,
merges them through stable leaf/parent queues, and writes depths directly to
the original symbols. This removes the previous descending compact order,
second leaf ordering inside `small_huffman`, and final scatter. Leaf/parent
weight ties prefer the leaf, generated parents retain creation order, and an
unbounded depth above five still falls back to the unchanged package-merge
builder. Empty and singleton alphabets plus targeted ties, full trees, and
over-depth shapes have focused coverage; 16,384 mixed random/extreme
histograms match the previous implementation's complete `[18]u4` result.

On fixed CPU 2 for ten `source32k` searches, the 18-symbol tree stage fell
0.885→0.685 ms (`1.292x`), complete complex-prefix scoring fell
2.034→1.797 ms (`1.132x`), and complete profiled search fell
35.347→33.956 ms (`1.041x`). Prefix scoring remains the largest tree-score
sibling, but its share is now close enough to one third that the gate compares
it directly with every sibling instead of imposing a fragile aggregate-share
threshold; a new negative smoke mutation locks that dominance check.

The initial 20-iteration complete-encoder control was narrowly positive at
7/11 wins and a `1.0015x` paired geometric mean, so a longer fixed-CPU-2
control used 21 alternating pairs at 50 iterations. It won 13/21 pairs,
reduced independent medians from 480.934 to 478.503 ms (`1.0051x`), and
improved the paired geometric mean by `1.0046x`. All pairs retained the same
6,475-byte ratio output, input SHA-256, auxiliary output sizes, and checksum.

## Sparse literal-tree support

Literal-context scoring now carries the 85-symbol support of the complete
literal histogram into every baseline, suffix, and clustered tree score. Each
local tree walks that shared symbol-ascending support once, appending its live
symbols to a second ascending view while preserving the existing
frequency-descending/symbol-ascending `PrefixAlphabet` order. The local view
then drives weighted payload costing, supplies the highest symbol without a
rescan, and reconstructs complex-prefix zero gaps for score-only RLE. The real
complex-prefix writer and the dense tree-score cache key/equality check remain
unchanged.

The sparse RLE summary shares the dense summary's run accumulators. Directed
tests cover symbols 0/255, zero gaps of 1/2/3/10/11, adjacent equal lengths,
all 256 non-zero symbols, invalid sparse metadata, and 8,192 randomized byte
alphabets. A second 1,024-case tree oracle spans the 1–4, 5–16, 17–32,
33–64, 65–128, and 256-symbol buckets, comparing exact alphabet order, all 256
code lengths, and complete prefix bit cost against the old dense scorer. The
profiled sparse path still performs the old dense shape summary outside the
timed RLE stage and asserts exact frequency, token, and repeat-count equality.

Across seven fixed-CPU-2 ten-search profiles, `source32k` medians improved:
alphabet construction 2.232→2.059 ms (`1.084x`), weighted payload
0.278→0.122 ms (`2.284x`), score-only RLE 0.883→0.793 ms (`1.113x`), complete
tree scoring 6.842→6.320 ms (`1.083x`), and the full diagnostic
34.573→33.586 ms (`1.029x`). All proposal, cache, alphabet-bucket, RLE-token,
and shape counters remained exact. Alphabet construction, length generation,
and prefix scoring are now co-dominant; the gate requires those three stages
to stay within 20% and each to exceed weighted payload by more than `8x`,
instead of choosing a noise-sensitive single winner.

Eleven alternating fixed-CPU-2 complete-encoder pairs at 20 iterations won
10/11, reducing independent medians from 191.643 to 189.366 ms (`1.0120x`)
with a `1.0108x` paired geometric mean. Every pair retained the same input
SHA-256, 7,259/6,732/6,475/6,483-byte fast/balanced/ratio/reference outputs,
and checksum.
