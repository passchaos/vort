# x86-64 dense Zstd FSE table construction

The 2026-10-01 change enables the existing dense 256-state FSE table builder
on x86-64. The `large_json` fixture constructs 12 compressed LL/OF/ML tables
per frame; each has no low-probability (`-1`) symbols, and several contain one
symbol occupying at least 192 of 256 states.

## Implementation and safety

For a probability of at least 192, the builder enumerates the at most 64 gap
states rather than all states belonging to the dominant symbol. It then emits
each contiguous dominant-symbol run four packed 64-bit entries at a time. The
existing bitset/`ctz` path remains in use for lower-density distributions.

The algorithm was already enabled on AArch64. The change extends the same Zig
implementation to x86-64 without adding target intrinsics or changing table
layout. The generic mapped builder remains the oracle: 256 deterministic
random distributions and three locked high-density distributions compare every
generated entry, including 209/256, 227/256, and 256/256 dominant symbols.

## Performance evidence

Measurements use frozen ReleaseFast executables pinned to CPU 2 on an Intel
Core i7-10700K. Each process alternates five Vort/libzstd samples and reports
the fastest; 15 outer pairs alternate baseline/candidate process order. The
baseline is commit `4c7c3db0`; the reference is the user-provided
`~/Work/zstd` checkout at commit
`01b7154f1172432f8abe9b3bb9909e14a1176b7d` (libzstd 1.6.0-dev).

Across 15 pairs of 3,000 complete `large_json` decodes, the candidate improves
by **1.0175x median / 1.0183x geometric mean**, wins **15/15**, and has a
**1.0051x minimum**. After simultaneous libzstd normalization the result is
1.0162x median / 1.0153x geometric mean with 13/15 wins. The final candidate
reaches 0.8026x libzstd by median; substantial sequence-execution work remains.

A seven-pair 13-row control matrix measures `large_json` at 1.0149x median /
1.0127x geometric mean with 7/7 wins. `binary_mixed`, which also builds dense
compressed sequence tables, improves by 1.0165x median / 1.0178x geometric
mean with 7/7 wins. The large `huffman80k` and `large_text` controls remain
near neutral at 1.0008x and 1.0046x geometrically.

Exact target observations, hashes, controls, and reproduction commands are in
[zstd-dense-fse-x86-20261001.json](data/zstd-dense-fse-x86-20261001.json).

## Validation and rejected variants

- The mapped-table oracle compares every entry against the generic builder for
  256 randomized distributions and three locked dense distributions.
- The split-Huffman target test continues to compare output and error behavior
  with the generic executor across sequence and literal mutations.
- All 677 direct ReleaseFast Zstd tests pass.
- The 276-case compatibility matrix, 9,900-frame/64-mode decodecorpus, generic
  x86-64/AArch64 compile checks, 13-row one-shot reference gate, and repository
  build check pass.

Lowering the dense threshold to 160 measured 0.9988x geometric with 4/11 wins.
Raising it to 224 measured 0.9970x with 2/11 wins, proving the middle range is
useful for this corpus. Expanding each write batch from four to eight entries
measured 0.9943x with 1/11 wins. All three variants were removed; the shared
threshold remains 192.

The next x86 target is the compact split executor's state-update and branch
schedule. Wider `binary_mixed` blocks should be measured alongside it because
they also benefit from this table-construction change.
