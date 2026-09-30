# x86-64 direct small Zstd Huffman lookup

The 2026-10-01 change removes the owned Huffman tree from the one-shot
`numbered_json` fast path. The fixture has 1,290 decoded bytes, 183 encoded
bytes, 39 sequences, a complete seven-bit Huffman code, and
predefined-LL/compressed-OF/predefined-ML sequence modes.

## Implementation and safety

The bounded parser now decodes direct or FSE-compressed Huffman weights and
constructs the complete seven-bit lookup without first materializing a
`StdZstdHuffmanTree`. Canonical ranges must start at the next uninitialized
lookup entry and cover all 128 entries exactly. Wider, overlapping,
under-subscribed, truncated, or otherwise unsupported descriptions return to
the established generic parser before output is modified.

The corresponding literal decoder uses the complete lookup for both bulk and
tail symbols. A tail entry is consumed only when its actual code length fits in
the remaining stream bits; four-stream transitions occur only after exact
exhaustion of the current stream. The general and reusable paths retain their
tree-based cold fallback. The common target's Huffman-weight description also
uses a noinline 32-state FSE table when its encoded table log is five, while
table-log-six descriptions retain the 64-state implementation.

The specialized frame entry's x86-64 stack frame falls from `0x6c8` to `0x2a8`
bytes, a further reduction of 1,056 bytes. Its lookup storage is left
uninitialized before construction because the path is entered only after the
builder proves that every entry was overwritten.

## Performance evidence

Measurements use frozen ReleaseFast executables pinned to CPU 2 on an Intel
Core i7-10700K. Each process alternates five Vort/libzstd samples and reports
the fastest; 15 outer pairs alternate baseline/candidate process order. The
baseline is commit `6e287126`; the reference is the user-provided
`~/Work/zstd` checkout at commit
`01b7154f1172432f8abe9b3bb9909e14a1176b7d` (libzstd 1.6.0-dev).

Across 15 pairs of 100,000 one-shot decodes, the final candidate improves the
target by **1.0805x median / 1.0797x geometric mean**, wins **15/15**, and has
a **1.0654x minimum**. Normalizing each process by its simultaneous libzstd
measurement gives 1.0810x median / 1.0847x geometric mean. One reference sample
was a visible high outlier; the unnormalized Vort/Vort result is therefore the
primary attribution evidence.

The final one-shot path reaches **0.9911x median versus libzstd 1.6.0-dev**;
one of 15 pairs is ahead, but the median remains below parity. A separate
13-row gate passes and measures 0.9952x for this row.

A seven-pair, 500-iteration full matrix measures the target at 1.0725x direct
and 1.0758x normalized geometric improvement. The large non-target rows, which
cannot enter the at-most-4-KiB specialization, measure 0.9998x (`huffman80k`),
0.9987x (`large_text`), 0.9990x (`large_json`), and 0.9962x (`binary_mixed`)
direct geometric ratios.

Exact target observations, hashes, component screens, controls, and commands
are retained in
[zstd-small-direct-lookup-x86-20261001.json](data/zstd-small-direct-lookup-x86-20261001.json).

## Validation and rejected variants

- The direct parser is compared with the standard tree parser across 512
  deterministic random descriptions and generated direct/FSE trees; every
  eligible lookup entry is compared exactly.
- Every bit in the target literal payload is mutated and the public fast path
  is compared with the forced generic path for identical output or error.
- Explicit one-stream short-code rejection and four-stream exact-boundary
  transition cases cover the lookup-only tail reader.
- All 676 direct ReleaseFast Zstd tests pass.
- The 276-case libzstd compatibility matrix, 9,900-frame/64-mode upstream
  decodecorpus, generic x86-64/AArch64 compile checks, and 13-row one-shot
  reference gate pass.

A 128-entry symbol-order scratch regressed to 0.9944x geometric with 0/11 wins.
Returning weight counts through caller-owned storage was noise-level at
1.0010x normalized geometric with 5/11 wins, and inlining the mode-dispatch
wrapper regressed to 0.9895x with 2/11 wins. All three were removed.

The small target is now effectively at parity but not yet consistently ahead.
The next useful work should measure the remaining normalized-count and
canonical-fill cost, then return to the materially larger `large_json` and
`binary_mixed` gaps.
