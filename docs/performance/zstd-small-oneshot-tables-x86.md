# x86-64 small Zstd one-shot table construction

The 2026-09-30 change reduces table-construction and parser state for the
one-shot `numbered_json` frame. The fixture has 1,290 decoded bytes, 183
encoded bytes, 39 sequences, a complete seven-bit Huffman tree, and
predefined-LL/compressed-OF/predefined-ML sequence modes.

## Implementation and safety

The small terminal-frame recognizer now parses the compressed literal header,
Huffman tree, literal stream boundaries, and sequence count directly. It passes
the already prepared tree and seven-bit lookup to the existing small-sequence
executor instead of materializing the generic previous-tree parsing state.
Frames outside the established at-most-4-KiB, single-block, compressed-literal,
2--256-sequence shape still fall back to the general decoder.

The bounded format limits now also determine scratch capacity:

- Huffman-weight FSE construction uses at most 64 states and 12 normalized
  weights, matching Zstandard's maximum table log and weight alphabet.
- A compressed offset table whose encoded table log is five uses a dedicated
  32-state table, 32-value normalized-count parser, and 32-slot mapped builder.
  Other table logs retain the general 512-state-capable path.
- The sorted FSE helper keeps 128 temporary states because tables of 256 or
  more states are already dispatched to the independent linear builder.

All capacity checks, normalized-probability validation, byte-consumption
accounting, and generic fallback behavior remain in place. The focused route
test asserts that the 32-state table is selected, and its existing mutation
oracle compares every post-table bit mutation against the generic decoder's
bytes or exact error.

## Performance evidence

Measurements use frozen ReleaseFast executables pinned to CPU 2 on an Intel
Core i7-10700K. Each process alternates five Vort/libzstd samples and reports
the fastest; 15 outer pairs alternate baseline/candidate process order. The
baseline is commit `9b6bdf76`; the reference is the user-provided
`~/Work/zstd` checkout at commit
`01b7154f1172432f8abe9b3bb9909e14a1176b7d` (libzstd 1.6.0-dev).

Across 15 pairs of 100,000 one-shot decodes, the final candidate improves the
target by **1.0278x median / 1.0269x geometric mean**, wins **15/15**, and has
a **1.0022x minimum**. Normalizing each process by its simultaneous libzstd
measurement gives 1.0329x median / 1.0287x geometric mean with 14/15 wins.

The final one-shot path reaches **0.8069x median / 0.8057x geometric mean
versus libzstd 1.6.0-dev**. This is an independent improvement over the
preceding reusable-cache commit, not a one-shot leadership result.

A separate seven-pair, 500-iteration full matrix keeps the large non-target
rows close to neutral after libzstd normalization: `huffman80k` 1.0018x,
`large_text` 1.0019x, `large_json` 1.0016x, and `binary_mixed` 0.9987x by
geometric mean. The target measures 1.0283x in that shorter matrix. Very short
raw/RLE rows have visibly wider scheduler noise and are retained as controls,
not attributed gains.

Exact target observations, executable and input hashes, control summaries,
and reproduction commands are retained in
[zstd-small-oneshot-tables-x86-20260930.json](data/zstd-small-oneshot-tables-x86-20260930.json).

## Validation

- All 676 direct ReleaseFast Zstd tests pass, including the normalized-count
  bit oracles, mapped-table equivalence test, route counter, and mutation
  differential.
- The 276-case libzstd compatibility matrix passes with zero unsupported cases.
- All 9,900 upstream decodecorpus frames pass with all 64 sequence-mode
  combinations and real reusable-table hits.
- Generic x86-64 and generic AArch64 ReleaseFast compile-only checks pass.
- The complete 13-row one-shot reference gate passes against the same local
  libzstd 1.6.0-dev build.

## Rejected variants and next work

Skipping a terminal-block tree copy without the complete parser restructuring
measured 0.9863x geometrically and was removed. Moving borrowed tree/lookup
state into the general literal-section representation also regressed the
target. A 64-state bitset builder measured 0.9957x with only 2/11 wins, and a
53-value generic sequence-count buffer measured 0.9975x; both were removed.

The next decoder priority is one-shot Huffman table construction beyond this
narrow shape, followed by the large compressed `large_json` and
`binary_mixed` sequence paths. Broader corpus and platform leadership remain
open.
