# x86-64 Zstd FSE/RLE/RLE sequence pairs

The 2026-10-01 change adds a compact two-sequence executor for the three
repeat-table blocks in the `binary_mixed` fixture. Those blocks contain 2,048
sequences each and use raw literals, a compressed LL table, an RLE rep0 offset,
and an RLE match symbol. Their steady state is a 16-byte literal followed by a
48-byte non-overlapping match at distance 64.

## Implementation and safety

The block wrapper first proves OF base/bits `0/0` and ML base/bits `47/2`.
The pair core then borrows one 64-bit reverse-bit group and validates both LL
symbols, both ML extra values, both LL extra values, both LL transitions, the
current rep0, literal capacity, exact output capacity, and match history before
committing any reader, state, or output progress. A successful iteration emits
two exact 16-byte literal copies and two existing suffix-preserving 48-byte
match copies. It never handles the final two sequences, a short reservoir, an
irregular literal, a non-rep0 offset, a different match, or a short/invalid
destination; every such case retains the original single-sequence decoder.

The pair loop lives in its own object-format text section and processes a
complete consecutive run per call. The original FSE/RLE/RLE helper grows only
from `0xa10` (2,576) to `0xaad` (2,733) bytes; the separate pair core is
`0x290` (656) bytes.

The direct oracle now contains 1,024 sequences plus a deliberately irregular
17-byte literal that forces a mid-stream fallback. It compares the complete
output, reader position, remaining count, LL/ML/OF states, repeated offsets,
and retained modes with the generic decoder. Separate short-output and invalid
rep0 cases compare the exact partial output and all progress state after the
error, not only the error tag.

## Performance evidence

Measurements use frozen ReleaseFast executables pinned to CPU 2 on an Intel
Core i7-10700K. Each process alternates five Vort/libzstd samples and keeps the
fastest sample for each codec. Fifteen outer pairs alternate baseline and
candidate process order. The baseline is commit `df5d2b84`; the reference is
the local `~/Work/zstd` checkout at commit
`01b7154f1172432f8abe9b3bb9909e14a1176b7d` (libzstd 1.6.0-dev).

Across 15 pairs of 3,000 complete `binary_mixed` decodes, the candidate
improves by **1.4299x median / 1.4290x geometric mean**, wins **15/15**, and
has a **1.4117x minimum**. Median Vort throughput rises from 7,161.33 to
10,241.45 MiB/s.

The candidate reaches **1.2831x median / 1.2829x geometric mean** of local
libzstd throughput, wins all 15 pairs, and has a **1.2745x minimum**. This
establishes a stable lead for this exact raw-literal FSE/RLE/RLE-heavy frame;
it is not a broad Zstd decoder leadership claim.

A separate seven-pair, 500-iteration complete 13-row matrix measures the
target at 1.4307x median / 1.4315x geometric with 7/7 wins. Its row-median
floor is 0.9941x. Longer 15-pair controls measure:

- `large_json`: 0.9982x median / 0.9972x geometric;
- `large_text`: 0.9992x median / 0.9969x geometric;
- `huffman80k`: 1.0003x median / 1.0008x geometric.

These controls do not execute the new pair core and remain within the accepted
host-noise band. Exact observations, hashes, matrix rows, controls, and
reproduction commands are in
[zstd-fse-rle-rle-pair-x86-20261001.json](data/zstd-fse-rle-rle-pair-x86-20261001.json).

## Rejected variants and validation

A single-sequence grouped-field variant reached only 1.0062x median / 1.0088x
geometric in seven target pairs. Localizing the entire reader/state/output
cursor expanded the helper to 6,895 bytes and regressed to 0.8291x geometric
with 0/7 wins. Both were removed. An inline pair implementation was already
fast, but its larger parent helper produced less stable downstream layout;
the retained separate run executor is both faster and easier to isolate.

- All 678 direct ReleaseFast Zstd tests pass.
- The five-row decode-profile gate and 13-row one-shot reference gate pass.
- All 276 local libzstd 1.6.0-dev compatibility cases pass with zero
  unsupported cases.
- All nine decodecorpus campaigns and 9,900 frames pass with all 64 sequence
  mode tuples, incremental decoding, reusable decoding, and dictionaries.
- Generic x86-64 and AArch64 ReleaseFast compile-only checks pass.
- `zig build check -j1` passes in 13:47.75 at 1,003,148 KiB peak RSS.

The next `binary_mixed` work should isolate the first FSE/FSE/RLE block from
frame/table setup, while broader Zstd work continues on real compressed files
that still trail libzstd.
