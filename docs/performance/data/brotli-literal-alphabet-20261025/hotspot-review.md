# Remaining q8 literal-context hotspot review

Read-only review of main `d689a411c03208d242e8775e34e7c4c006b07e80` and the
completed `/tmp/vort-br-tree-cost-20261025/profile14/samples.json`. No source/Git
changes, compilation, timing or new profile run were performed. Raw five-round
medians and source hash checks are saved in `detail-median-audit.json`.

## What remains after the dense-tree increment

All four studied inputs have five rounds and unchanged complete wire identities.
The archived huffman, command_plan, small_huffman and literal_context_split
source hashes match the inspected main files. These are **instrumented profile**
times, not ordinary-code throughput or exact cycle accounting.

| Input | Outer median | Actual context-proposals median | Recent scan median |
| --- | ---: | ---: | ---: |
| Mozilla64KiB | 63.707ms | 34.748ms | 0.109ms |
| Office64KiB | 86.347ms | 44.360ms | 0.183ms |
| SAO64KiB | 100.398ms | 63.253ms | 0.154ms |
| source64KiB | 38.266ms | 8.271ms | 0.109ms |

Each value is a separately computed median. Their sums need not equal an outer
median. The following detailed tables also have nested inclusive relationships;
do not add suffix+cluster+tree scoring into one artificial exclusive total.

### Proposal search phase medians (ms)

| Input/plan | Analysis | Baseline | Suffix | Sparse | Cluster | Context total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Mozilla lazy | .216 | .014 | 5.140 | .079 | 11.084 | 16.676 |
| Mozilla optimal | .261 | .014 | 5.309 | .084 | 12.257 | 18.070 |
| Office lazy | .367 | .014 | 5.534 | .108 | 15.431 | 21.645 |
| Office optimal | .417 | .014 | 5.695 | .113 | 16.337 | 22.721 |
| SAO lazy | .619 | .015 | 6.135 | .165 | 24.475 | 31.544 |
| SAO optimal | .634 | .015 | 6.271 | .164 | 24.686 | 31.879 |
| source lazy | .151 | .007 | 1.010 | .034 | 2.655 | 3.997 |
| source optimal | .171 | .007 | 1.088 | .035 | 2.833 | 4.260 |

### Cluster child phase medians (ms)

| Input/plan | Init | Prepare | Assignment | Finalize | Score |
| --- | ---: | ---: | ---: | ---: | ---: |
| Mozilla lazy | .542 | .411 | 3.098 | .020 | 7.001 |
| Mozilla optimal | .552 | .430 | 3.518 | .020 | 7.708 |
| Office lazy | .600 | .436 | 5.156 | .017 | 9.205 |
| Office optimal | .651 | .436 | 5.608 | .018 | 9.573 |
| SAO lazy | .822 | .366 | 9.540 | .013 | 13.717 |
| SAO optimal | .818 | .376 | 9.750 | .014 | 13.712 |
| source lazy | .232 | .093 | .610 | .017 | 1.690 |
| source optimal | .236 | .096 | .680 | .017 | 1.791 |

### Tree scoring child medians (ms), across direct and cached-miss scores

| Input/plan | Alphabet | Lengths | Weighted | Prefix |
| --- | ---: | ---: | ---: | ---: |
| Mozilla lazy | 4.984 | 2.193 | .126 | 2.034 |
| Mozilla optimal | 5.292 | 2.416 | .128 | 2.308 |
| Office lazy | 6.450 | 2.727 | .140 | 2.390 |
| Office optimal | 6.647 | 2.936 | .142 | 2.570 |
| SAO lazy | 11.365 | 2.892 | .176 | 2.347 |
| SAO optimal | 11.285 | 2.931 | .173 | 2.407 |
| source lazy | .585 | .529 | .030 | .470 |
| source optimal | .630 | .576 | .030 | .532 |

Package-merge calls are **zero** in all these plan profiles after the dense
natural-tree change. The alphabet build is now the largest reported tree-score
component on Mozilla/Office/SAO, while cluster assignment is also substantial,
especially on SAO. Analysis collection, baseline, sparse construction and
finalization are comparatively small. Weighted payload is particularly small.
This evidence favors a bounded alphabet-sort investigation before another
Huffman builder rewrite or generic cache-lifetime proposal.

Source64KiB is an essential control: it has no>128-symbol tree scores. Its
ordinary coarse profile instead spends13.759ms in wire and10.863ms in optimal
parse. A dense-only alphabet improvement should not be extrapolated to source's
whole pipeline or to the reference throughput gap.

## Actual alphabet algorithm

`src/br/encoder/literal_context_split.zig:1002`, `buildTreeAlphabet`, receives the
already unique **symbol-ascending fixed parent support**. It visits each
support symbol, ignores zero frequencies, appends live symbols to tree_symbols,
and simultaneously insertion-sorts the PrefixAlphabet symbols by descending
frequency. Equal frequency never shifts, so initial ascending symbol order
provides the required tie order.

The shared support already removes a complete dense256-symbol scan and yields
the ascending sparse list needed by prefix RLE. That optimization exists; the
remaining work is the per-tree frequency ranking. Simply copying the ascending
list without frequency sort changes the compact leaf rank/ties and therefore
may change code lengths, prefix cost, context proposal choice and final wire.

Each accepted late symbol may shift many earlier entries and reread their
frequencies by index. Worst-case insertion moves at256 live symbols are32640
per tree. The profile does not measure actual comparisons/shifts, so that is
only an upper bound. Actual>128-score counts are:

| Input | Lazy >128 / all scores | Optimal >128 / all scores |
| --- | ---: | ---: |
| Mozilla | 796 / 1593 | 830 / 1591 |
| Office | 1068 / 1608 | 1097 / 1636 |
| SAO | 1492 / 1680 | 1479 / 1658 |
| source | 0 / 639 | 0 / 644 |

Thus dense ranking repeatedly matters on the three expensive controls. Existing
`command_plan.alphabetFromFrequenciesInto` and `sortByFrequencies` also use
insertion order, so routing to those functions does not solve the algorithmic
cost. The existing Huffman frequency buckets target distinct leaf-order
contracts; they cannot be copied without adapting direction/tie and preserving
full u32 weights. No new approximate bucket cost or clamped frequency is needed.

## One recommended exact-output increment

For **actual live count>128 only**, collect the same live ascending symbols and
sort an exact numeric ranking key instead of shifting symbols during insertion.
Keep the old insertion path for≤128 as the reference/control initially.

One concrete key for byte symbols is:

`key = (u64(maxInt(u32) - frequency) << 8) | u64(symbol)`.

Ascending key order is exactly descending frequency, then ascending symbol.
The key uses at most40 bits even atu32max, fitsu64 on actual32-bit targets, and
does not multiply or clamp the frequency. Each symbol is unique, so keys are
unique: a total-order numeric sort has no unresolved equal-key tie. It is safe
to test `std.mem.sortUnstable(u64,...,std.sort.asc(u64))` because the complete
symbol tie-break is encoded in the key; unstable algorithm order cannot change
the resulting array. Decode the low byte back into PrefixAlphabet symbols,
retaining the separate original ascending tree_symbols list unchanged.

Use a bounded `[256]u64` call-local buffer (2048 bytes), no allocator, global
state or cross-plan cache. Preserve output len, zero skipping, all candidates,
cutoff/seed/round order, complete frequency values, exact code lengths and
strict candidate comparisons. No quality policy changes are part of this slice.

Alternatively a stable exact radix pass over fullu32 frequencies could preserve
the ascending initial order. That adds four histogram/scatter passes for8-bit
digits; do not assume it beats numeric PDQ at256 symbols or optimize both routes
without a focused comparison. The simplest first experiment is one dense
numeric-sort specialization plus untouched insertion reference. If parent
chooses radix, test every digit/pass and full high-byte values, not a range
limited by this corpus's small frequencies.

The new sort may add a collection/key-construction pass and stack bytes, so a
speedup is not guaranteed. Actual live count, not just parent support size,
must select the dense route: source parent support88 versus Mozilla256 is
informative, but each tree can omit most symbols under a256-symbol parent.

## Fine measurement and validation

Split alphabet diagnostics into live collection, key/rank construction,
ranking and output extraction. Keep original reference counters for insertion
comparisons/shifts outside ordinary code. Record actual live-count and exact
frequency spread buckets, then compare ordinary-code whole q8 separately.
Avoid a timestamp per insertion, comparison or symbol. Nested phase timing must
be subtracted or retained as detail, not added to tree_alphabet total.

An isolated module such as `src/br/encoder/literal_tree_alphabet.zig` can own
the bounded orderer, while `buildTreeAlphabet` remains the original validation
and result adapter. First scope touches only this constructor and its tests,
not generic Huffman, command-plan writer, q8 schedule or other codecs.

Exact tests should compare all alphabet entries and tree_symbols against the
original insertion path for every active count0…256, arbitrary support holes,
stationary/equal frequencies, ascending/descending/alternating frequency
patterns, ties across numeric digit boundaries, high/u32max weights, and
actual32-bit execution. Empty input retains InvalidBlockPlan; singleton/simple
cases retain original behavior and tails remain unobserved.

Then compare complete code-length arrays, tree bit costs, all suffix/up-to-16/
full proposals and their context maps/savings, and frozen14 complete q8 wire
SHA. Preserve backing OOM/total-budget behavior and caller data. Because the
orderer has no new heap, allocator request graph should remain unchanged.
Use old reference and independent composite-key ordering/dense oracle; don't
make default-versus-wrapper equality the sole proof.

For later quiet measurement, use Mozilla/Office/SAO as dense cases and source
as control, alternating version order and checking every frozen wire. A lower
alphabet-stage timer alone is insufficient; whole public aggregate results,
per-input regressions and actual stack size must be stated. No current speedup
or acceptance decision is made by this read-only review.
