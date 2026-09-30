# x86-64 raw-literal Zstd FSE/FSE/RLE sequence decode

The 2026-10-01 change narrows the existing large-sequence FSE/FSE/RLE helper
to the raw-literal shape that its dispatch already requires. The motivating
`binary_mixed` frame contains 8,188 sequences over four compressed blocks;
the first block uses compressed LL and OF tables with an RLE ML symbol, while
the remaining blocks use the separately specialized FSE/RLE/RLE path.

## Implementation and safety

Both call sites select this helper only for raw literals, compressed LL/OF,
an RLE ML symbol, and at least 1,024 sequences. The helper now asserts that
contract, borrows the raw literal payload once, and no longer carries an
optional Huffman decode state or enters the generic literal-kind switch for
every sequence. The measured 16-byte literal run is copied with a fixed
`@Vector(16, u8)` load/store; other lengths and the final literal tail retain
exact bounded copies.

The change preserves the existing literal-consumption and output-capacity
checks, repeated-offset updates, dictionary fallback, match-history checks,
retained sequence tables, and exact caller-output boundaries. A new 256-
sequence oracle compares the specialized loop with `readModeSequence()` plus
the generic copy helpers. It also checks `OutputTooSmall`, an invalid initial
repeat offset, final output, repeated offsets, and retained LL/OF/ML modes.

In the frozen ReleaseFast binaries, `decodeFseFseRleSequences` shrinks from
`0xfe8` (4,072) to `0xc68` (3,176) bytes, a reduction of 896 bytes.

## Performance evidence

Measurements use frozen ReleaseFast executables pinned to CPU 2 on an Intel
Core i7-10700K. Each executable alternates five Vort/libzstd samples and keeps
the fastest sample for each codec. Fifteen outer pairs alternate
baseline/candidate process order. The baseline is commit `f7e95936`; the
reference is the local `~/Work/zstd` checkout at commit
`01b7154f1172432f8abe9b3bb9909e14a1176b7d` (libzstd 1.6.0-dev).

Across 15 pairs of 3,000 complete `binary_mixed` decodes, the candidate
improves by **1.0968x median / 1.0954x geometric mean**, wins **15/15**, and
has a **1.0874x minimum**. Median Vort throughput rises from 6,515.33 to
7,138.61 MiB/s. The candidate remains at only **0.8946x** median libzstd
throughput, so this is a bounded hot-path improvement rather than an overall
leadership claim.

The libzstd-normalized result is 1.0949x median / 1.1129x geometric mean.
Pairs 1 and 3 contain isolated candidate-process reference times near 215 ms
instead of the otherwise stable 187--188 ms band; they inflate the normalized
geometric mean and produce the only two apparent reference wins. The direct
frozen Vort/Vort ratios are therefore the primary attribution evidence.

A separate seven-pair, 500-iteration, complete 13-row matrix improves
`binary_mixed` by 1.0990x median / 1.0985x geometric mean with 7/7 wins.
`large_json` and `huffman80k` remain neutral-positive at 1.0040x and 1.0059x
geometrically. The geometric mean across row medians is 1.0092x, and the
lowest row median is 0.9941x (`text`). The short `incompressible` row has a
noisy 0.9835x pair-geometric result but a neutral 1.0010x median, including
opposing 0.8027x and 1.2051x outliers; it does not exercise the changed path.

Exact observations, hashes, all matrix rows, and reproduction commands are
in [zstd-fse-fse-rle-raw-x86-20261001.json](data/zstd-fse-fse-rle-raw-x86-20261001.json).

## Validation

- The new direct specialized-versus-generic oracle passes, including output
  exhaustion and invalid-history behavior.
- All 678 direct ReleaseFast Zstd tests pass.
- The five-row decode-profile gate and 13-row one-shot reference gate pass.
- The local libzstd 1.6.0-dev compatibility matrix passes all 276 cases with
  zero unsupported cases.
- All nine decodecorpus campaigns and 9,900 frames pass, including incremental
  and reusable decode, with all 64 sequence-mode tuples covered.
- Generic x86-64 and AArch64 ReleaseFast compile-only checks pass.
- `zig build check -j1` passes in 10:15.11 at 1,028,772 KiB peak RSS.

The next useful slice is to separate the remaining FSE state-update cost from
the fixed 16-byte literal and 48-byte non-overlapping match copies, then audit
the three FSE/RLE/RLE blocks without weakening malformed-input behavior.
