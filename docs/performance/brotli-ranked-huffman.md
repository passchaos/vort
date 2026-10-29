# Brotli ranked Huffman construction

`PrefixAlphabet` already ranks active symbols by descending frequency with
ascending-symbol ties. Complex trees with at most 256 active symbols now feed
that rank directly into the bounded two-queue Huffman builder. The prior path
copied ranked frequencies into a compact array, rebuilt a second leaf-order
array, wrote compact depths, and scattered them back to original symbols.

The direct path keeps compact rank as the creation serial. It walks the
lightest equal-frequency group directly from the ranked symbol list, merges it
with the naturally ordered parent queue, and writes validated depths directly
to original symbol positions. Equal leaf/parent weight still chooses the leaf;
parent ties still follow creation order. A depth above 15 publishes no output
and retains the existing length-limited package-merge fallback. The simple
1–4 symbol path, `>256` path, profile counters, errors, allocation behavior and
wire policy are unchanged.

Tests independently compare the direct API with the old compact builder across
64/128/256 scratch capacities, 256/704 symbol capacities, sparse/permuted
supports, equal-frequency groups, random distributions and Fibonacci
over-depth failures. Poisoned output verifies that failures publish nothing
and successes touch only active symbols; profiled and ordinary complete arrays
must agree.

## Upstream implementation study

The pinned Brotli 1.2.0 development source at commit `558fc647` uses the same
high-value structural invariant in `c/enc/entropy_encode.c`: sort active leaves
once, then linearly merge an ordered leaf queue with naturally ordered parents.
Vort adopts that invariant, not the implementation wholesale. In particular:

- upstream equal-weight leaf ordering differs, so Vort retains its established
  rank serial and byte-exact wire;
- Vort retains `u64` weights rather than relying on Brotli meta-block bounds;
- Vort retains exact length-limited package merge instead of upstream's
  repeated pseudo-count floor;
- Vort keeps explicit stack/resource and reference-comparison contracts.

The broader study also confirms that upstream q8 is a relatively light greedy
plus bounded-lazy preset, while q11 discovers matches once and reuses them for
two differently priced DP passes. Vort q8 deliberately performs heavier
context/optimal work, explaining why this tree-layout improvement helps but
does not close the encode gap. The next high-value upstream-derived direction
is optional, budgeted reuse of model-independent match frontiers across Vort's
q10/q11 refinement passes, not more Huffman micro-tuning.

## Ordinary A/B

Baseline `761da0dd` and the three-file candidate were built as separate
ReleaseFast executables. All measurements ran on logical CPU 2 of an Intel
Core i7-10700K with q8/generic/lgwin16. Each of 36 Silesia 4/16/64 KiB cases has
three AB/BA/AB process sweeps and 15 ordinary Vort samples per side.

| Quantity | Result |
| --- | ---: |
| Candidate / baseline time geometric ratio | `0.978982` |
| Sweep ratios | `0.978602 / 0.978809 / 0.978565` |
| 4 / 16 / 64 KiB bucket ratios | `0.973118 / 0.975669 / 0.988224` |
| Worst case | `0.998303` |
| Non-regressing cases | `36 / 36` |
| Candidate / Brotli 1.2.0 time | `33.441601` |
| Vort / reference size geometric ratio | `0.995561` |

The candidate is about 2.15% faster than its Vort baseline, but still consumes
roughly 33.4 times the reference encoder time in this matrix. This is a useful
hot-kernel improvement, not broad Brotli leadership.

The paired mechanism profile keeps every non-time field and all 4,739
`small_huffman` calls identical. `tree_lengths_ns` falls from 6.100 ms to
5.025 ms (`0.823868`). The `leaf_order_ns` field falls from 1.669 ms to
0.385 ms, but it is not independently comparable: ranked equal-weight group
advancement now occurs inside the merge loop and is charged to `merge_ns`.
Only the complete tree-length phase is used as the mechanism result. Profile
time explains the mechanism and is not used as ordinary throughput evidence.

Complete raw reports, input and wire identities, reference library hashes,
source overlay, profile gates, replay commands and a machine-checkable audit
are retained in
[`data/brotli-ranked-huffman-20261029/`](data/brotli-ranked-huffman-20261029/).
