# Deflate common-path hotspot location (mozilla), 2026-11-16

## Question

The full-Silesia sweep
([wire-full-silesia-20261116](wire-full-silesia-20261116/README.md)) showed the
deflate deficit is a flat ratio-independent ~6% band on ten typical files
(median V/R 0.937), plus two high-compressibility wins. Is that ~6% a
concentrated, possibly removable hotspot, or dispersed intrinsic work?

## Method

`perf record -F 999 --call-graph dwarf` on the ReleaseFast
`vort-deflate-reference-bench` decoding Silesia `mozilla` (a typical-band row,
V/R 0.936) for 200 iterations; `perf report --no-children --sort=symbol`.
Single host, diagnostic only, no code change.

## Named-symbol self-time

| symbol | self % |
| --- | ---: |
| `deflate.semantic.linear_entry.aligned` | **45.92%** |
| `deflate.decodeRawAutoWithDictionaryFromReaderFromReader…` | 1.90% |
| `SemanticDynamicDecoder.buildLiteralTable` | 1.00% |
| `…NonOverlapInline` | 0.64% |

The remaining ~50% are unnamed inlined addresses (799 such buckets) whose
callchains resolve into the same `linear_entry.aligned` ->
`decodeDynamicBlockIntoLinearMode` region, so the effective concentration in
the semantic Huffman/match loop is well over half of all samples. Table
construction is negligible (~1%), so the cost is per-symbol decode, not setup.

## Interpretation: concentrated, but the local levers are already exhausted

The ~6% common-path gap maps to the serial prefix-decode loop
(`linear_entry.aligned` is only a 64-byte-aligned wrapper around
`decodeDynamicBlockIntoLinearMode`). That is the same class of intrinsic
load-use serial work documented for the zstd FSE wall, not a removable
dispatch or table-build cost.

The ledger's rejected-directions list already covers every local lever on this
exact path, each failed under paired A/B:

- table shape (8-12 bit primaries, single-literal entries, pair caps, distance
  widening, prepared-lookup widening);
- speculation (chain depth 2/3/5, deferred fourth load, recomputed bit sums);
- cursors/checks (pointer cursors, precomputed/hoisted limits, check removal,
  outputEnd inlining, branch hints, distance==1 reorder);
- storage (16-bit pair store, 32/64-byte copy tiers);
- layout (dedicated sections, wrapper alignment).

So this profile locates the deficit but does not reopen a local edit: the loop
is hot because it is the irreducible per-symbol critical path, and the prior
exhaustive screen found no within-format change that moves it. Closing the gap
is structural (a different decode representation / wider SIMD-friendly
primitive), matching the conclusion for zstd and Brotli.

## Scope limits

Single host, one file (`mozilla`), one perf run without dedicated-host
pinning: hotspot *location* evidence, not an adoption-gate measurement. No
production code changed; the perf.data was a temporary artifact and removed.
