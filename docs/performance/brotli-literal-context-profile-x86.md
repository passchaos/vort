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
`source32k` cluster stage. A seven-case negative smoke rejects missing rows,
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

The first length-builder candidate narrowed `small_huffman` node weights from
`u64` to `u32` after an exact total-frequency guard, retaining package-merge
fallback for wider inputs. It improved the fixed profile's `source32k` length
stage from roughly 7.350 to 7.049 ms (`1.043x`), but the authoritative complete
encoder rejected it: only 4/11 alternating 20-iteration pairs won and the
median regressed from 241.440 to 242.398 ms. The candidate and its extra guard
were removed. Future length work must improve generated layout and complete
encoding, not merely shrink the isolated queue scratch.
