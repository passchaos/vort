# x86-64 reusable small Zstd table cache

The 2026-09-30 change removes repeated table preparation from the reusable
decoder's small single-block path. The target is the `numbered_json` fixture:
1,290 decoded bytes, 183 encoded bytes, 39 sequences, a complete seven-bit
Huffman tree, and predefined-LL/compressed-OF/predefined-ML sequence modes.

## Implementation and safety

The reusable Huffman cache now owns the parsed tree and its optional complete
seven-bit lookup together. A cache miss builds the lookup alongside the tree;
a hit can borrow both immutable tables. A narrow terminal-block recognizer then
validates the literal header, stream boundaries, sequence count and mode byte,
matches both self-delimiting cache descriptions exactly, and enters the shared
small-sequence executor without materializing another roughly 1 KiB tree or
rebuilding the lookup. The cached FSE offset table is borrowed in the same call.

Only explicit compressed-literal blocks of at most 4 KiB, with 2--256
sequences, no dictionary, terminal continuation, a complete at-most-seven-bit
tree, and the exact predefined/compressed/predefined mode byte are eligible.
All misses return to the established parser. The reusable specialization keeps
its output cursor local and commits it on both success and error; the one-shot
instantiation retains direct progress writes.

The existing mutation oracle flips every bit following the sequence-table
start and compares the specialized and generic decoder's output or exact error.
It now also proves that the second reusable decode takes the fully cached block
route. Cache keys contain the complete self-delimiting Huffman and sequence
descriptions rather than relying on source addresses.

## Performance evidence

Measurements use frozen ReleaseFast executables pinned to CPU 2 on an Intel
Core i7-10700K. The reference is the user-provided `~/Work/zstd` checkout at
commit `01b7154f1172432f8abe9b3bb9909e14a1176b7d` (libzstd 1.6.0-dev), built as
a Release shared library. Each process alternates five Vort/libzstd samples and
reports the fastest; outer pairs alternate baseline/candidate process order.

Across 15 pairs of 100,000 warmed reusable decodes, the candidate improves over
commit `fc59ccaf` by **1.1829x median / 1.1853x geometric mean**, wins 15/15,
and never falls below 1.1401x. After simultaneous libzstd normalization the
gain remains 1.1889x median / 1.1773x geometric mean. The candidate reaches
**1.0064x median / 1.0109x geometric mean versus libzstd 1.6.0-dev**; individual
ratios range from 0.9887x to 1.0338x, so this is a median/geometric lead rather
than an every-run floor.

The separate one-shot control improves by 1.0197x median / 1.0198x geometric
mean with 8/9 wins, but remains 0.7830x of libzstd by median because it must
parse and build the tables on every call. Seven-pair 13-row controls leave
non-target reusable rows between 0.9907x and 1.0271x by geometric mean before
normalization; the target improves 1.2038x in that shorter matrix. This bounds
the retained optimization to reusable small compressed frames and does not
claim broad compressed-data leadership.

Exact target observations, hashes, and commands are retained in
[zstd-small-reusable-cache-x86-20260930.json](data/zstd-small-reusable-cache-x86-20260930.json).

## Validation

- All 676 direct ReleaseFast Zstd tests pass, including the cached-route counter
  and the sequence-bit mutation differential.
- The 276-case compatibility matrix passes with zero unsupported cases.
- All 9,900 upstream decodecorpus frames pass, including all 64 sequence-mode
  combinations and real reusable table hits.
- Generic x86-64 and generic AArch64 ReleaseFast compile-only checks pass.
- The complete 13-row one-shot reference gate passes against the local libzstd
  1.6.0-dev build. A 500-iteration reusable matrix also completes and measures
  the target at 1.0280x libzstd; its repository-wide gate is not reported as a
  pass because the pre-existing 1.20x `numbered_json` floor is stricter than
  this measured result.

## Rejected variants and next work

A two-sequence unrolled decoder passed the differential oracle but reduced the
target to about 0.89x libzstd because its extra branches and code footprint
outweighed fewer loop iterations. Predecoding all 102 literals into a 256-byte
stack buffer reduced the target to about 0.94x. A 64-byte loop-alignment probe
and a 64-byte wildcopy for the common 56-byte match also regressed and were
removed.

The next work should improve one-shot table construction and the large
`large_json`/`binary_mixed` sequence executors. This result establishes a
bounded reusable small-frame lead only.
