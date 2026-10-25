# Final 256-symbol Huffman kernel review

Read-only review of the frozen producer files in
`/home/passchaos/project-z/vort-brotli-context-cache`. No source/Git write,
compilation, test execution or timing was performed by this audit.

| File | Frozen SHA-256 |
| --- | --- |
| small_huffman.zig | b23a30082ccce63b785051b61831ab4a297e09c152db6825bd76eed787c99bf7 |
| command_plan.zig | 173cf7e6bc7e784fab80201f5cb696b0f870f4843de35e5999179439e6d9d9f9 |

## Producer conclusion

No new producer safety blocker was found in the frozen256 path. The code
preserves ranked inputs and natural-tree tie ordering, widens only the required
node domain, rejects deep trees before unsafe depth propagation/output
publication, and retains the original package-merge fallback unchanged. This
is a static result; exact natural-tree versus max15 backref length equivalence
also relies on the independent complete-array tests and parent's frozen-wire
validation, not weighted-cost equality alone.

## Rank and tie behavior

`PrefixAlphabetFor` retains frequency-descending symbols with deterministic
symbol ties. New129…256 code copies frequencies by **that alphabet rank**, then
passes only its actual live prefix to `small_huffman.build(256,...)`. Successful
lengths scatter through exactly the same symbol/rank mapping as the old
fallback. It does not pass a differently ordered original-symbol KnownActive
list or change the15-bit limit.

The natural builder visits weight groups from lightest to heaviest while
keeping original compact rank order inside equal-weight groups. Leaves precede
generated parents. `queuePop` selects a leaf at equal leaf/parent weight;
parents are consumed in creation order. These decisions preserve the original
natural heap's `(weight,creation serial)` order, with compact rank as leaf serial.
Neither quality, mutable context model, current incumbent nor clocks affect
those choices.

The old backref package merge also orders equal weights by creation serial,
but uses repeated package lists and multiplicity selection. Same minimum
weighted cost is not a source-only proof of identical per-symbol lengths across
all multiple-optimum distributions. The independent test helper compares the
new successful arrays with `huffman.treeCodeLengths(256,ranked_compact,15)`;
that is the correct tie oracle for this integration. Its natural reference uses
repeated minimum scans and parent walks, rather than the new queues/reverse
propagation. Existing≤128 heap tests and cost-only comparisons alone would not
establish the new dense route's exactness.

## Index, weight and depth bounds

- capacity64 retains Index=u8 and Parent=i8; largest node index126 fits signed
  parent bytes. capacity128 retains Index/Parent=u8 with largest index254.
- capacity256 uses u16 for both leaf/node indexes and parents, covering511
  nodes and largest index510. It does not merely relax the oldu8 capacity assert.
- The builder admits capacities1…256 and checks actual frequency-prefix length
  against capacity. Empty input returns false before reading its last entry.
  The newdense path rejects a zero-weight last entry before publication; valid
  ordered active PrefixAlphabet inputs contain only positive weights, while old
  ≤128 zero handling remains unchanged.
- weights remainu64. Even256*u32max is below2^40, so no parent merge overflows
  that type. Queue indexes stay in the initialized active/node prefix.
- Every nonroot receives a parent; parent index is greater than its child.
  Reverse traversal starts with root depth0. Every written depth has already
  passed≤15, so `parent_depth+1` is at most16 and fitsu5. The first depth16
  returnsfalse before storing that depth or traversing its descendants.
  This resolves the old depth>31 overflow risk without clamping depths.

On a deep-tree failure no output lengths have yet been written by the main
depth/output path. Profile failure count and depth timing are recorded before
return. Single-symbol success preserves its existing early return and writes
length1 only. The completed output loop writes just the active prefix;
unwritten scratch tails remain outside publication. PrefixAlphabet zeroes its
full output first and publishes either successful scatter or the bounded
fallback, so inactive symbols remainzero.

## Fallback/reference routes

The producer's `fillTreeLengths` body is byte-identical to main baseline
`f642d0d8`: zeroed compact buffer, same ranked gather, the same
`huffman.treeCodeLengths(compact_size,...,15)` call, same scatter. Source checks
are saved in `final-kernel-static-check.json`.

PrefixAlphabet5…64 and65…128 branch bodies also match baseline byte-for-byte;
their underlying small builder only gains safe early depth rejection. On
successful≤15 trees their merge/leaf order and output remain unchanged. The
≤128 index widths and array element types remain their previous widths.

`codeLengthsReference` calls the same dispatch with `dense_fast=false`. This
switch bypasses only the new129…256 natural attempt and retains its original
package branch. It does not disable/reinterpret the old≤128 simple/small routes.
Ordinary and profiled codeLengths use dense_fast=true. Faileddense attempts
increment `package_merge_calls` once and immediately invoke the unchanged
fallback; successful attempts do not count a package call. Unsupported larger
alphabets retain the previous max-prefix fallback and are not forced through
the256 primitive.

## QA outcome boundaries

Parent reports corechecks and newPrefix integration have passed. This audit did
not rerun them. Initial outer QA assumptions that every random distribution
must have natural success, and that a dense Fibonacci-plus-many-ones fixture
must exceed31 depth, are separate test assumptions. Many weight-one leaves can
reduce maximum depth; random/skewed legal inputs may correctly returnfalse and
require package merge. Those conditions do not make a producer fallback a
producer error.

The inspected QA now uses `_ = try check(...)` for general random cases and
contains an explicit34-leaf Fibonacci fixture with known natural depth33 for
the old≤128 risk. At this review point a dense outer `rejected_deep`>31 aggregate
expectation remained in the evolving helper. The parent/QA owner must confirm
its final correction and capture that QA hash/results separately. This report
does not authenticate half-edited QA or infer full-suite success from the
producer hashes.

The meaningful acceptance rules are: natural depth≤15 yields exact expected
arrays; depth>15 returnsfalse safely and complete PrefixAlphabet output equals
the original package route; no caller input mutation; scratch tails remain
unpublished; profile agrees with ordinary output; rank/equal-weight and
leaf-package ties stay exact. Complete frozen14 q8 wires and actual32-bit
validation are required separately before public performance/adoption claims.

No approximation, tree-limit change, candidate-budget reduction or frequency
smoothing is present in the frozen producer. A performance gain remains a
matter for parent's later quiet ordinary-code measurements, not this audit.
