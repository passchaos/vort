# x86-64 borrowed small Zstd literal metadata

The 2026-10-01 change removes an owned Huffman-tree-sized field from the
one-shot `numbered_json` fast path. The fixture has 1,290 decoded bytes, 183
encoded bytes, 39 sequences, a complete seven-bit Huffman tree, and
predefined-LL/compressed-OF/predefined-ML sequence modes.

## Implementation and safety

The specialized parser already built its Huffman tree and complete seven-bit
lookup separately, but it then constructed the general `LiteralOnlySection`.
That structure contains an optional owned `StdZstdHuffmanTree`; optimized x86
code consequently cleared another `0x404` bytes on every frame even though the
specialized executor only borrowed the separately prepared tree.

The one-shot path now constructs a `BorrowedHuffmanSection` containing only
stream slices, byte offsets, sizes, and the sequence count. The shared cursor
initializers and small executor accept either metadata representation, while
the existing generic/reusable callers retain the owned-tree section. Tree
selection remains explicit: the borrowed representation is valid only when a
prepared tree is supplied, otherwise decoding returns `CorruptFrame`.

Disassembly of the frozen binaries shows the specialized entry stack frame
falling from `0xad8` to `0x6c8` bytes, a reduction of 1,040 bytes, and the
`0x404`-byte section clear disappearing. Parsing, tree validation, stream
boundary checks, sequence decoding, output progress, and error propagation are
otherwise unchanged.

## Performance evidence

Measurements use frozen ReleaseFast executables pinned to CPU 2 on an Intel
Core i7-10700K. Each process alternates five Vort/libzstd samples and reports
the fastest; 15 outer pairs alternate baseline/candidate process order. The
baseline is commit `e9cad21b`; the reference is the user-provided
`~/Work/zstd` checkout at commit
`01b7154f1172432f8abe9b3bb9909e14a1176b7d` (libzstd 1.6.0-dev).

Across 15 pairs of 100,000 one-shot decodes, the final candidate improves the
target by **1.1419x median / 1.1410x geometric mean**, wins **15/15**, and has
a **1.1317x minimum**. Normalizing each process by its simultaneous libzstd
measurement gives 1.1418x median / 1.1406x geometric mean, also with 15/15
wins.

The final one-shot path reaches **0.9203x median / 0.9215x geometric mean
versus libzstd 1.6.0-dev**, with a 0.9145x--0.9288x range. This substantially
narrows the target gap but does not establish parity or broad leadership.

A separate seven-pair, 500-iteration full matrix measures the target at
1.1275x normalized geometric improvement. Large non-target rows remain close
to neutral: `huffman80k` 1.0001x, `large_text` 1.0035x, `large_json` 1.0091x,
and `binary_mixed` 1.0007x. Short rows remain scheduler-sensitive and are not
used to attribute gains.

Exact target observations, hashes, controls, and commands are retained in
[zstd-small-borrowed-section-x86-20261001.json](data/zstd-small-borrowed-section-x86-20261001.json).

## Validation and next work

- All 676 direct ReleaseFast Zstd tests pass, including the specialized versus
  generic mutation differential.
- The 276-case libzstd compatibility matrix passes with zero unsupported cases.
- All 9,900 upstream decodecorpus frames pass with all 64 sequence-mode
  combinations and real reusable-table hits.
- Generic x86-64 and generic AArch64 ReleaseFast compile-only checks pass.
- The complete 13-row one-shot reference gate passes against the same local
  libzstd 1.6.0-dev build.

The remaining target gap is now small enough to focus on direct construction
of the complete narrow Huffman lookup and lookup-only checked stream tails.
Large compressed `large_json` and `binary_mixed` execution remains a separate
priority after this small-frame work.
