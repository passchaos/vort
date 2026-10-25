# Final SOURCE_READY review update — 2026-10-25 09:23 UTC

The three frozen implementation files were inspected after the writer's
SOURCE_READY. Static source checks confirm the reviewed safety conditions are
implemented. **No new codec-correctness blocker was found in the cache/chooser
changes.** This is a static finding; parent compilation, tests and timing retain
their separate status.

| Final implementation file | SHA-256 at review |
| --- | --- |
| literal_tree_score_cache.zig | f2b16b331850d6bebcce486a75327648aafd8513b47cdffc7313ad42fa6497b6 |
| literal_context_split.zig | 5e0f139d1a30601e5824bdaade4c23fad1af4de0632fdfe6ed31e79f68a8c458 |
| literal_context_profile.zig | b6292a1e6427e65a7aeed3433821384cbf57c7400cb89e3ee1a9195b68f770d3 |

The final helper module stores only hash, complete histogram, bit cost and
optional diagnostic origin. It stores no pointer to input/support/allocator or
plan. `get` checks occupancy before reading undefined entries, then compares
hash **and all256 frequency values**. `treeBitCostCached` calls the unchanged
scorer on a miss, propagates `try` errors, and calls put only after successful
completion. Publication is call-local; no concurrency or reentrant sharing is
introduced.

Production `chooseProposals` selects `chooseProposalsCore(false,true)`, observed
chooser selects `(true,true)`, and the explicit old reference selects
`(false,false)`. In the shared specialization, the outer local cache exists and
the inner per-mode local is `void`; in reference the outer cache is `void` and
inner cache exists. Thus the source does not retain two active cache instances
for normal search. Single-mode/prefix-aware entrypoints also create a separate
call-local cache tied to their own fixed support, without widening quality
acceptance or changing prefix semantics.

`suffixPayloadBitCostCached` explicitly initializes all256 right frequencies
to zero before filling active support. The original support-only reference
function remains byte-identical and is called only by the reference branch.
The shared baseline/suffix/cluster requests use the same Analysis support;
`ScoredMapCache` is still a local variable inside each mode. The unchanged
function checks are saved in `final-static-review.json`: collectAnalysis,
scoring/alphabet/weightedBits, retainBetter, sparse reference suffix,
assignment preparation/costs, histogram moves and sparse/support construction
all match baseline4098 byte-for-byte. command_plan, small_huffman,
complex_prefix, context_map, code_length_rle and code_length_huffman dependencies
are unchanged too. No duplicated alternative scoring algorithm was added.

Diagnostic origin storage starts undefined, but its read is inside
`if(profiled)` after a hit in the same profiled-only cache. Every profiled put is
immediately followed by setOrigin. Normal and reference specializations never
read origins. This satisfies the current call-local contract; public Cache API
users mixing unprofiled put with origin queries would violate its documented
precondition. Fixed origin storage adds ABI bytes even when normal accesses are
dead; measure final @sizeOf/stack use separately rather than claiming zero memory
impact or RSS. There is no new heap allocation in the cache/profile route.

Final profiling counters correctly attribute baseline/suffix/cluster requests,
with no mode assigned to the global baseline. A hit's cross-scope/cross-mode
classification describes the stored originating miss; it does not mutate
candidate scoring. `mode_ns` is explicitly inclusive and excluded from stageNs.
The old tree-time subset assertion now allows baseline+suffix+cluster-score,
which matches the expanded scoring set.

**QA issue found and acknowledged by parent:** the hook
`literal context shared tree cache reference and profiling contracts` calls
`context_cache_tests.contracts(@This())`. Its inspected allocationFailures helper
asserted baseline.alloc_index>2 and required fail1/fail2 even though this chooser
has only the actual Analysis request; score and map operations are fixed-stack.
Parent reports the first Debug run's sole failure is this assumption. QA owner has now corrected the helper: reference/default/profiled routes each
measure their actual baseline request count (>0) and replay only existing
indices0..count, with leak checks. This review read those fixed bytes at SHA
060042e1a5fed6c351a3827fdfc79f01e7dfd37c10a5c9eb8a371f244950b178.
The earlier discovery bytes had SHA
f43d0721e1eb5671290978151d3372e88463a9cdab3985d6d29fc97688f5e897.
Parent reports the corrected Debug rerun passed75/75. The first Debug failure
evidence remains in the earlier records and is not erased by that result.
x86 and full ReleaseFast validation were still compiling at this update. This
audit does not independently run or certify those pending suites.

No source/Git edits, compilation or timing were performed in this review.
The following original design review remains as invariant rationale and boundary
notes; references to pending migration there are superseded by this final section.

---

# Exact tree-score cache audit

Read-only review of `/home/passchaos/project-z/vort-brotli-context-cache`, baseline
`4098b386269dd9a6e3c9364e89666e84d0ea09d5`. The cache writer's migration was
still being implemented while this review ran. This is a proof of the required
invariants and risks, not approval of uncompiled final edits. No source, Git,
compilation or timing was changed/run.

## Findings and required conditions

**One Analysis plus full 256-frequency equality is sufficient for exact tree
bit-cost reuse across modes**, under the current implementation and the
conditions below. The mode selects which literal enters each histogram; once
the complete histogram is fixed, mode itself is not consumed by tree scoring.

**The migration must zero the suffix right histogram before full-key access.**
At the inspected baseline, `suffixPayloadBitCost:561` declares
`right: [256]u32 = undefined` and writes only active symbols. This is safe for
the old support-only scorer, which never reads the other slots. It is unsafe
for `treeHistogramHash`, complete equality or the cache's value copy, all of
which read 256 entries. Use `@splat(0)` before filling active entries; do not
claim sparse semantic equivalence makes undefined bytes hashable. The writer
has acknowledged this condition. A stale inactive slot test should verify that
all nonactive frequencies reaching the shared key are zero.

**Keep ScoredMapCache per mode.** Its key is only context_map plus tree_count.
Different modes can aggregate different histograms through the same map, so a
shared cross-mode map cache would return a wrong total. TreeScoreCache keys the
exact histogram and is a different cache. This distinction is essential.

## Why the tree value is deterministic

The inspected scoring chain is:

`treeBitCostWithSupport` → `buildTreeAlphabet` →
`PrefixAlphabetFor(256).codeLengths` → weighted payload plus
`complex_prefix.bitCostSparse` for nonsimple trees.

1. Analysis is created once and zero-initialized. `collectAnalysis` records
   all four context-mode histograms and their common total. `buildActiveSymbols`
   supplies a unique symbol-ascending list that covers every nonzero entry of
   every derived tree. The shared memo must not escape this Analysis/input/
   command-plan lifetime or be reused with a narrower/different support.
2. `buildTreeAlphabet` filters zero frequencies from that support. Insertion
   is descending frequency; the ascending support order preserves symbol order
   for ties. The live `tree_symbols` list remains symbol-ascending for sparse
   prefix RLE. Identical histograms and fixed support therefore yield identical
   live symbols, alphabet order and stop index.
3. `PrefixAlphabetFor.codeLengthsInternal` handles 1…4 live entries with fixed
   patterns. Larger trees use the same small-Huffman builder or package merge,
   with a fixed 15-bit maximum. Small-Huffman queues preserve `(weight,serial)`
   ties; fallback scatters the same compact order. No mode, quality, mutable
   entropy model or candidate incumbent participates in this decision.
4. Weighted payload cost is exactly `sum(u64(freq[s]) * lengths[s])`. Simple
   trees add the same fixed byte-alphabet representation cost. Complex trees
   use the ascending live symbols and dense-zero lengths to derive the same
   sparse code-length RLE summary. Its 18-symbol Huffman limit is fixed to5;
   code-length order, zero-run policy, header bits and extra bits are constants.
   `BitCounter` adds bit counts; it does not depend on output addresses.
5. Profiled variants change clocks/counters, not the value. Their extra dense
   shape summary is checked against the same sparse RLE summary. A hit may omit
   that observation, so profile counters must describe actual misses/hits rather
   than pretend all reference scoring was executed.

The memo key should compare hash **and all 256 u32 frequencies**. A hash match,
equal total, equal support, equal mode or equal context map alone is not enough.
Put only after the original score returns successfully. Errors must propagate;
never cache a partial score, substitute a proxy or skip a candidate on OOM.

This value excludes context-map cost. Total clustered candidate bits add the
independently selected map plan after summing tree bits. Cache that combined
value only under the existing safe per-mode map scope.

## Integer and empty-histogram boundaries

In the current q8 scope, total literals ≤65536 and tree lengths ≤15, so weighted
payload ≤983040 bits. Full-alphabet u32 frequencies also have an absolute upper
bound `256 * maxInt(u32) * 15 < 2^44`; u64 is sufficient even for the module's
larger standalone tests. The prefix bit counter processes at most256 code
length positions and18 code-length symbols; its local counts fit 32-bit usize.
This is not a reason to narrow the returned tree cost or widen accepted input.

Suffix scoring avoids left_count0/full, and cluster finalization removes zero
total trees. Therefore successful cached trees have at least one live symbol;
`buildTreeAlphabet` deliberately returns InvalidBlockPlan for empty support.
Do not prepopulate a zero-histogram cache entry with an invented cost. Preserve
the original error/null-proposal timing for invalid inputs.

All cluster histograms are initialized for their selected tree prefix before
aggregation; incremental moves touch only the same immutable sparse contexts.
The full key is valid only for the initialized `[256]u32` of each actual tree,
not unused elements outside the selected tree count. Suffix left starts zero;
suffix right requires the explicit new zero fill discussed above.

## Memory and lifetime

The existing128-entry cache stores `hash:u64`, `[256]u32` and `bit_cost:u64`.
Its entry payload is exactly `128 * (8 + 1024 + 8) = 133120` bytes; occupancy
is another16 bytes and old hit/miss counters add four target-sized integers.
The final type's ABI padding and new diagnostic fields must be recorded with
actual `@sizeOf` in later verification, not guessed as RSS. Current review did
not compile a layout probe.

The cache is stack storage, not requested heap. Moving it from a per-mode
function to the enclosing chooser should keep **one active cache**, not an
outer shared instance plus an unnecessary inner local cache in the production
specialization. Keep old per-mode storage only in the explicit reference
specialization. The proposed chooser uses one call-local memo and borrows no
caller-owned mutable state, so no globals, cross-call contamination or thread
synchronization are required.

The large Analysis allocation is separate: four64×256×u32 histograms plus the
total/literal count. Cache presence must not move its ownership to a different
allocator or silently bypass total requested-heap admission. Profile details
should remain fixed caller-owned data and must not create another heap buffer.

## Eviction, allocation and errors: specific code versus general rule

More cross-mode entries can evict an earlier useful score and cause more CPU
work. A direct-map miss always recomputes the same exact value, so eviction
order cannot change proposals, seeds, rounds, tie comparisons or wire bytes.
It can reduce hit rate and make a supposed optimization slower; per-mode and
scoring-origin hit/conflict data are needed to measure that.

Crucially, **the current exact tree-score closure makes no heap requests**:
small-Huffman, `huffman.treeCodeLengths`, code-length RLE summary and the
complex-prefix BitCounter all use bounded stack arrays. The allocator passed
through those APIs is unused by counting writers. `context_map.choose/build`
also constructs a fixed Plan/tokens/frequency/alphabet workspace; it does not
allocate. The chooser's actual heap request is Analysis create/destroy.
Earlier shorthand suggesting tree/map cache misses allocate was corrected by
following these concrete bodies. Do not report allocation savings from hits
without a real allocator observation.

Thus this specific lifecycle change, if it adds no other buffers, should retain
the allocator-request graph; new evictions do not introduce OOM on their own.
Independent current allocation-count equality is a useful regression check.
It is not the mathematical contract of caching for arbitrary future scorers:
if a scorer later gains heap allocation, legitimate hits could remove requests
and misses/replacement could add them. In that case **do not require identical
FailingAllocator index outcomes as correctness**. Require that actual failed
requests propagate the proper error, no candidate/output is published, all
owned allocations clean up, budget refusal remains distinct from backing OOM,
and every successful sufficient-resource result equals the reference. Report
changed request counts explicitly rather than hiding them behind skipped errors.

## Order and reporting invariants

- Preserve cutoff1…63 order and strict savings comparison.
- Preserve the11 requested tree-count values and ordered/interleaved seed order.
- Preserve4/2/1 iteration budgets and fixed costs for the full assignment round.
- Preserve incremental histogram migration only as preparation for the next round.
- Preserve final empty-tree compaction and ascending remapping.
- Preserve `retainBetter`: higher savings, then fewer trees; equal savings/count
  retains the earlier candidate/mode. Caching must not change that recurrence.
- Preserve context-map plan selection and its strict lower-bit tie rule.

Adding baseline/suffix misses to treeScoreCache means tree score timing/calls
are no longer a subset only of cluster scoring. Update old
`treeScoreStageNs() <= cluster_score_ns` expectations to scoring-origin totals;
do not compare an expanded counter set against the old narrower denominator.
Per-mode times and cluster/tree child times are inclusive. Parent reports must
retain their hierarchy and sum exclusive coarse scopes only. A cache hit records
its source/mode as actual reuse, not a phantom miss with zero timer.

## Independent tests worth preserving

Use the old chooser retaining per-mode caches and suffix bypass as a reference,
without imposing new quality gates. Compare all suffix/up_to_16/full fields,
including savings, mode, tree_count and all64 map bytes. Cover sparse inactive
symbols, full byte support, identical histograms across distinct modes, equal
weights, forced hash collision, direct-map eviction, zero/fewer-than-two populated
contexts, maximum legal tree count, empty/tiny handling and repeated independent
calls. Compare final public q8 frozen14 wires separately.

This audit supports the exact-key design **under these checked conditions**;
it does not certify the writer's pending final source, performance, stack
high-water use or new deep-profile results. Final SOURCE_READY and actual tests
remain with their owners.
