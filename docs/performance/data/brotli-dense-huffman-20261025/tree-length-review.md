# Brotli q8 tree-length hotspot review

Read-only source review at main `f642d0d892658a11062832a7db41fe893adba3d6`.
No source/Git mutation, compilation or timing was performed. Measurements cited
below are existing archived profile runs, not a new CPU profile.

## Update: parent's 256-symbol natural-tree experiment

Parent is separately testing an extension of small_huffman to256 active
symbols on the **existing ranked compact frequencies**. This avoids the
original-symbol KnownActive trap described below: its leaf serial remains
alphabet rank. Its successful path must preserve leaf-before-generated-parent
ties and generated-parent creation order; max-natural-depth>15 must immediately
retain the current package-merge fallback, without changing weights or quality.

A bounded independent integer-recurrence check found no differing length arrays
between stable natural Huffman and creation-serial package merge at maxbits15
for exhaustive small ordered distributions (2…11 symbols, weights1…6) and506
larger natural≤15 cases across65/127/128/129/166/192/255/256 symbols. Six larger
cases exceeded15 and were excluded from that successful-fast-path comparison.
This check did not call a project codec or compile/run its implementation and
is not an exhaustive/general proof. The large-case record is
`natural-package-math-check.json`.

An unconstrained minimum fitting15 has the same minimum weighted cost as the
length-limited solution. That observation alone does not establish the same
per-symbol lengths when several optima exist; implementation tests must still
compare the complete new256 builder arrays against **current backref max15**,
not merely small_huffman's heap reference or weighted-cost package reference.
Tie-rich repeated sums and exact captured Mozilla rank mappings are especially
useful. A real array mismatch should keep the old package route for that policy
until its tie behavior is resolved.

Extending to256 also requires a wider node index: the largest index is510, so
the existingu8 parent/leaves interfaces cannot merely have capacity checks
relaxed. Use an explicit u16 node domain (or equivalent safe specialization) and
preserve the existing≤64/≤128 layout routes unless separately verified. Depth
handling must be wide enough or reject>15 during propagation; a concrete
descending34-symbol Fibonacci fixture has maxweight5702887 and natural depth33,
withinu32 weights but outside existingu5 depth storage. Parent has already
required early-safe rejection/wider depth storage.

This fast natural-tree route and the SoA package-workspace proposal below are
separate optimization choices. The profile identifies the>128 package branch;
it does not decide which exact implementation wins. No new timing or adoption
conclusion is made here.

## Actual expensive branch

The restored-policy profile file is
`/tmp/vort-brotli-context-cache-20261025/restored-profile14/samples.json`.
Mozilla64KiB has:

| Plan | Active symbol buckets ≤4 / ≤16 / ≤32 / ≤64 / ≤128 / >128 | Package-merge calls | Small-Huffman failures | Tree-length median |
| --- | --- | ---: | ---: | ---: |
| lazy | 21 / 81 / 135 / 268 / 292 / 796 | 796 | 0 | 20.440211 ms |
| optimal | 8 / 51 / 125 / 236 / 341 / 830 | 830 | 0 | 22.243927 ms |

The first raw round is19.631075/21.835070ms; those single-round values are not
the five-round medians. Source64KiB has zero >128 bucket entries and zero
package-merge calls, with tree-length medians0.505578/0.549230ms.

The earlier shared-cache profile has Mozilla >128 counts792/827, package calls
792/827, small-Huffman failures0, and length medians19.930872/21.921746ms.
It is a different policy/profile run and should not be merged with restored data.

These counts establish that Mozilla repeatedly selects the **direct >128-symbol
package-merge branch**, rather than an adversarial failure of the small builder.
The tree-length timer surrounds `PrefixAlphabet.codeLengthsProfiled`, including
compact-frequency gather, dispatch, actual builder and scatter; it does not
independently time only package merge. The profile is instrumented and its
timer values are nonadditive medians. It still provides a clear first algorithm
target: `fillTreeLengths(...,256)` → `huffman.treeCodeLengths(256,...,15)`.

The parent has inspected ordinary helper lowering and reports the memo helper
is inlined. No memo function-call-overhead claim follows from this review.

## Current dispatch and tie invariants

`src/br/encoder/command_plan.zig:134` preserves simple1…4 symbol patterns.
For5…64 and65…128 it runs `small_huffman.build` using already frequency-descending
compact frequencies. Successful lengths are scattered to original symbols.
Small failure keeps the existing bounded package-merge fallback. For129…256 it
directly calls `fillTreeLengths` with compact_size256 and maxbits15.

At current `src/huffman.zig:1243`, that case hasactive>64 andn>64, so it runs
**back-reference package merge**, not the packed-count small-width implementation.
The back-reference node comparator is `(weight, creation serial)`. At every leaf
and generated package, serial equals its arena index. Each level pairs the same
sorted list, merges leaves with packages by that comparator, and selects
`2*active-2` final entries. Recovery is already linear multiplicity propagation
from reverse node order. The old per-root DAG traversal is retained only as a
reference; proposing linear recovery again would duplicate completed work.

PrefixAlphabet builds `compact_frequencies[i] = frequencies[symbols[i]]`.
Thus a leaf's serial/order is its **frequency-descending alphabet rank**, with
original-symbol tie order inherited from that alphabet. It is not generally the
original byte-symbol index. This matters even when two algorithms produce the
same weighted Huffman cost: equal-cost alternative lengths can change prefix
RLE, context selection and final wire.

### Existing specialized APIs are not drop-in replacements

`treeCodeLengthsKnownActive` promises a strictly symbol-ascending active list.
Passing original histograms plus a naturally sorted active list instead of the
current ranked compact histogram changes leaf creation order. Passing the
PrefixAlphabet's frequency-ranked symbols violates the existing API precondition.
Its genericmax15 path still scans the supplied dense histogram in the backref
builder, so invoking it after the same compact gather only removes one small
active-count scan, not the repeated package workload.

Known-active medium/dense specializations currently select `n=256,max_bits=11`
for Zstd shapes. Dense additionally attempts an unbounded builder/bucket-leaf
policy. Their tests protect that contract, not q8'sranked max15 contract.
Do not change the q8 bit limit, use the unbounded fast path merely because
small-Huffman succeeded elsewhere, or replace serial ties with a packed-count
tie policy. Existing source explicitly says packed-count package merge has a
different tie policy.

## One executable exact-output optimization proposal

Optimize the existing **back-reference workspace layout**, keeping the same
package-merge algorithm and rank order. Split the current padded16-byte Node
array into parallel arrays:

- weights: u64 for every arena node, hot in pairing/merge comparisons;
- left/right: u16 per node, read during recovery;
- leaf_symbols: u16 for leaves only;
- creation serial: use the u16 arena index itself, since current serial=index
  for every initialization/publication.

The comparator becomes `weights[lhs] < weights[rhs]` or equal weight with
`lhs < rhs`. That is exactly the old `(weight,serial)` relation; it does not
prefer a different leaf/package on ties. Preserve the original arrays/lists,
node creation sequence, pairs, merged-list order, selected-count and existing
linear recovery. Keep u64 weights and checked u16 arena bounds. The leaf symbol
mapping must stay identical to the existing rank-compaction/scatter path.

Initially use a comptime layout choice inside the same shared backref algorithm,
with AoS retained as an independent exact reference. Do not duplicate another
package-merge recurrence. Limit first comparison to `n=256,maxbits15` q8
compact-ranked histograms; broader Huffman/Deflate/Zstd entrypoints can retain
their prior route until relevant tests and evidence support widening the change.

Forworkspace256/max_code_bits15, current node payload is
`16*3840 = 61440` bytes. Proposed node/leaf payload is
`(8+2+2)*3840 + 2*256 = 46592` bytes, an arithmetic reduction14848 bytes before
actual ABI/codegen verification. This is stack workspace, not requested heap
or RSS. More contiguous weight loads and no repeated hot serial/symbol fields
are plausible benefits, **not measured speed claims**. A SoA layout can also
increase instruction/address-generation cost; only exact artifact and quiet
measurement can settle it.

After the layout is proved, a separate ranked-active internal entry could skip
the redundant compact gather/count/scatter while passing a trusted rank-order
list into the same workspace. It must define creation serial by list rank,
not original symbol number. That is optional later work, not an excuse to call
the current symbol-ascending known-active API incorrectly.

## Required fine measurement

Add builder-specific counts and coarse timestamps within one diagnostic
specialization, not clock-per-node:

1. PrefixAlphabet gather/dispatch/scatter versus builder time.
2. Backref leaf construction/sort, package pair+list merges, multiplicity
   zero/selected marking/recovery.
3. active count, nodes_created, list entries merged, selected roots and recovery
   nodes, plus the actual chosen algorithm. Existing generic
   `package_merge_calls` alone does not distinguish packed versus backref.

Capture the **actual histograms and alphabet rank mappings** for Mozilla lazy
and optimal miss scores outside ordinary timing, with SHA and plan/source
identity. Replay those histograms to compare both layouts' complete dense
length arrays. Then measure ordinary public q8 separately; new deep timers
and observer writes must not be treated as pure optimization timings.

The archived profile's huffman/command_plan/small_huffman hashes currently
match main, so the branch interpretation is source-bound. New split phase
numbers have not been measured here.

## Exact tests and safety boundaries

- Compare **all code lengths**, not only weighted cost, between AoS/SoA,
  current backref, linear-recovery reference and per-root traversal where valid.
  Packed-count full-width reference is useful for optimal cost/Kraft checks,
  but can be a different tie oracle.
- Exerciseactive0/1/2/3/4/5,31/32/33,63/64/65,127/128/129/255/256; preserve
  simple patterns and inactive output zeroing. Use sparse byte symbols and
  distinctrank mappings so rank-versus-symbol mistakes are visible.
- Equal frequencies, repeatedweight groups and leaf/package equal-weight ties;
  u32max and skewed distributions; maxbits1…15 where representable. Require
  validKraftsum and exactly unchanged fallback/admission behavior.
- Keep compact workspace128/256 and u16 bounds valid on actual32-bit targets;
  no unchecked physical narrowing or u8 extension to a511-node256-symbol tree.
- Revalidate complete q8 frozen14 wires, default profilefalse behavior,
  caller ownership, exact total-budget/refusal and backing OOM. The layout
  should add no heap allocation.

One separate **small-Huffman safety risk merits a targeted test**: depths are
stored inu5, all depths are computed before the output loop checks>15. A natural
Huffman tree can exceed31 levels for a descending u32 Fibonacci-like distribution
(e.g. roughly34 live frequencies). Then depth addition may overflow before
the intended false-return/package-merge fallback in safety builds. This is a
static risk, not a reproduced failure in this review and not Mozilla's observed
slow branch (small failures were0). An explicit skew fixture should confirm
fallback, and depth propagation should either use a sufficiently wide type or
return false before exceeding15. Preserve successful≤15 lengths and tie rules;
do not assert arbitrary huge depths fit the currentu5 merely because profiled
corpus trees did.

No hash-cache capacity change, candidate-budget reduction, quality retraction,
or wire-changing approximate code-length algorithm is proposed here. The
next bounded experiment should target the evidenced max15 backref tree builder
with exact-length differential tests before any performance or adoption claim.
