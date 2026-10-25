# Restored context policy: final read-only review

The review started only after the writer's restored SOURCE_READY and verified
these frozen implementation hashes:

| File | SHA-256 |
| --- | --- |
| literal_context_split.zig | 72cb7349697453c172686b8acba87484f99a4b4a9da775d93fc77383d21fa79b |
| literal_context_profile.zig | fc19a207d99db5ed5118ce5153968b8cf7c246d4dc8af43ac46c3075d8d7ae83 |
| literal_tree_score_cache.zig | a14ea8a7d6e5cf047e0c3d46c1dbf17f4df7ec64b143ef1e751c4f8b666138b7 |

No source/Git edit, compilation or timing was performed. QA detail additions
were still pending with their owner; this report reviews the frozen core and
existing oracle surface, not that partially edited QA or pending executions.

## Restored algorithm policy

The default chooser now calls `chooseProposalsCore(false,...)`. There is no
outer tree cache or shared-cache switch in that core. Baseline scoring calls
the original `treeBitCostWithSupport`. Normal suffix scoring calls the original
support-only `suffixPayloadBitCost`. Only after suffix search and sparse-context
construction does each mode create its own ScoredMapCache and TreeScoreCache.
Cluster scoring is the sole memo consumer, with the original per-mode lifetime.

Mode order, cutoff1…63, requested counts2/3/4/6/8/12/16/24/32/48/64,
ordered/interleaved seeds,4/2/1 round budgets, fixed assignment costs, histogram
migration, final compaction and retainBetter tie recurrence remain unchanged.
The cache is no longer seeded by baseline or suffix, so their entries cannot
alter cluster eviction/hit behavior or introduce cross-mode reuse.

The single-mode/prefix-aware and arbitrary max-tree routes were separately
checked against baseline4098, not inferred from the main q8 route. The public
`choose`, `chooseUpTo`, `chooseSuffix`, `chooseProposalsForMode`,
`chooseProposalsForModeWithPrefix`, `chooseWithClusters`, `chooseMode` and
`chooseModeProposals` definitions are byte-identical to that baseline. They
retain original invalid max-tree admission, special16/64 result selection,
prefix initialization and max-tree constraints. No new quality/input gate was
inserted into the restoration.

## Pure scorer and original-source proof

Read-only 4098 Git blobs were archived under `restored-baseline/`. Static exact
comparison confirms byte-identical collectAnalysis, treeBitCostProfiled,
buildTreeAlphabet, weightedBitsSparse, original suffixPayloadBitCost,
retainBetter, assignment preparation/sparse cost, sparse construction, active
support and histogram movement. command_plan, complex_prefix, context_map,
small_huffman, code_length_rle and code_length_huffman dependency files also
remain byte-identical. The comparison is recorded in
`restored-static-verification.json`.

Consequently the tree-score value still depends only on the exact histogram
and fixed support, with deterministic alphabet ordering, max15 lengths,
weighted payload and original sparse prefix/RLE cost. Cache lookup still checks
occupancy, hash and all256 frequencies; a miss calls the unchanged scorer and
publishes only after success. These bodies retain bounded stack storage and
make no scorer/map heap requests. Analysis create/destroy remains the real
chooser allocation.

The original suffix right histogram still uses uninitialized inactive slots,
but that restored function is support-only and is never passed to the full
cache key. This is the original safe sparse-read contract. Both production
and profiled suffix paths retain that support-only access. Cluster histograms
are initialized for their active tree prefix before any full-key lookup.

## Cache ABI and pointer lifetime

The extracted Cache has the same stored fields and order as the old local
memo:128 entries of hash/full histogram/bit cost, two occupancy words and four
target-sized counters. Diagnostic origins storage, setOrigin and origin APIs
are gone. No input, support, allocator or plan pointer is retained.

This structure restores the legacy layout in source. Prior actual legacy
measurements were133168 bytes on native64 and133152 on x86; this review did not
compile a new @sizeOf query, so those are expected restored sizes pending the
parent's layout evidence. It is stack storage, not requested heap or RSS.
The refactored module boundary itself does not prove identical emitted stack
frames or performance; parent ordinary-wire and quiet-code validation are
separate evidence.

Each chooser/mode owns one local cache and support for the duration of its
call. There is no cache sharing between workers, calls, inputs, baseline,
suffix or modes. Thus removal of origins also removes its profiled-publication
initialization precondition, and a normal cache hit cannot read undefined
diagnostic metadata.

## Diagnostic counts remain truthful under old policy

Profiled chooser now shares this same old policy. Baseline and suffix call
`treeBitCostUncached`: the original scorer completes successfully before
`recordUncachedTree` increments total/scope/mode direct-call counters. Direct
scores are not labelled cache requests or misses. The baseline has no RFC mode.

`treeBitCostCached` records actual cluster get requests, hits and misses;
successful misses compute and publish the original value. Scope is always
cluster and its cache is mode-local. Existing cross-scope/cross-mode fields are
left at zero instead of reporting invented provenance. The successful-run
accounting relation is total scoring calls = cluster misses + completed
uncached calls. A failed scorer can leave request/attempt diagnostics incomplete;
do not apply successful-run equality or successful-output claims to an error
report. Errors still propagate without becoming a no-benefit proposal.

Inclusive mode and nested tree/Huffman/prefix times are retained for detail.
They must not be summed with enclosing durations. Parent reports should use
the existing coarse exclusive scopes and keep unaccounted time, not claim
profiling overhead disappeared with cache origins.

## Reference independence and tests

`chooseProposalsReference` and default `chooseProposals` now return the same
`chooseProposalsCore(false,...)`. Their equality is a routing/consistency test,
**not an independent algorithm oracle**. It must not be promoted into a proof
that the restored chooser equals the archived implementation by itself.

The independent static archived-source comparisons above supply the additional
restoration evidence. Existing tests retain independently derived dense tree
scores, suffix payload/map cost, sparse/dense aggregation, incremental moves,
assignment costs, histogram/hash collision handling, predictive/stationary
contexts and2/4/8/16/64-tree fixtures. The chooser hook can still compare default
and observed result semantics and allocator cleanup, but its Reference arm now
tests the same implementation. Parent's old frozen14 complete-wire comparisons
remain necessary for the public encoding result.

No QA additions or pending test outcome are certified here. This review finds
no new restoration blocker in the frozen core: the inspected strategy is the
old direct-baseline/direct-suffix/per-mode-cluster policy, with retained deeper
diagnostics that clearly separate uncached work from true memo traffic.
