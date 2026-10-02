# x86-64 Zstd pair-head 70-byte wild tail

The 2026-10-02 change reduces copy instructions in the compact split-Huffman
sequence-pair path used by the synthetic `large_json` row. A dedicated x86-64
helper copies the first 70-byte match of a proven two-sequence pair with two
32-byte vectors and one eight-byte tail, replacing the previous four-byte plus
two-byte exact tail.

## Safety contract

The specialization is limited to the first match in the existing bounded
pair path. Before entry, that path proves the full output capacity for two
one-byte literals and both matches, and it selects the helper only when the
first match length is exactly 70 and its offset is at least 70.

The helper writes 72 bytes while advancing the logical cursor by 70. It stores
the first 64 bytes before loading the eight-byte source tail at offset 64. At
distance 70 or 71, the final one or two source bytes therefore come from the
just-initialized destination prefix; at larger distances the entire tail is
old history. Only the first 70 result bytes are semantically relevant. The
second sequence immediately overwrites byte 70 with its literal and byte 71
with the first match byte. The second match retains the exact-copy path, so no
speculative bytes survive the pair and no write crosses the frame boundary.

The dedicated oracle covers all 16 destination alignments modulo 16,
distances 70--74, and second-match lengths 3, 4, 16, and 68--71. It compares
the whole guarded buffer with scalar LZ replay, including the overwritten pair
boundary and untouched suffix.

## Performance evidence

Measurements use frozen ReleaseFast executables pinned to CPU 2 on an Intel
Core i7-10700K. The baseline is commit `6a1e3d9e`; the reference is the local
Zstd checkout at `01b7154f1172432f8abe9b3bb9909e14a1176b7d`
(libzstd 1.6.0-dev). Odd pairs run baseline then candidate, and even pairs
reverse the order.

| Measurement | Median | Geometric mean | Minimum | Wins |
| --- | ---: | ---: | ---: | ---: |
| 512 KiB complete `large_json` frame | 1.0063x | 1.0068x | 1.0008x | 15/15 |
| Complete frame, libzstd-normalized | 1.0069x | 1.0069x | 0.9924x | 12/15 |
| Four-block prepared stage | 1.0008x | 1.0016x | 0.9855x | 8/15 |
| Fixed 128 KiB one-block oracle frame | 0.9990x | 1.0024x | 0.9904x | 7/15 |

The four-block frame accumulates the small per-block saving and is the primary
result. Candidate throughput reaches 0.8170x median / 0.8176x geometric local
libzstd throughput, so the broad Zstd decode leadership goal remains open.
Baseline and candidate ELF `.text` sizes are both 637,193 bytes.

A seven-pair 13-row one-shot matrix has a 1.0056x geometric mean across row
medians and 1.0053x after simultaneous libzstd normalization. Longer
3,000-iteration controls measure:

| Control | Median | Geometric mean | Wins | Normalized geometric mean |
| --- | ---: | ---: | ---: | ---: |
| `binary_mixed` | 1.0018x | 1.0009x | 9/15 | 1.0020x |
| `huffman80k` | 1.0003x | 1.0005x | 8/15 | 1.0009x |
| `large_text` | 0.9978x | 0.9977x | 5/15 | 0.9973x |

`large_text` does not select this pair path; its approximately 0.23% movement
is retained as layout/noise evidence rather than attributed to the helper.

Two nearby candidates were rejected before this result. Reordering the
existing 70-byte branch ahead of the 71-byte branch reduced stage and frame
geometric throughput to 0.9758x and 0.9889x, both with 0/7 wins. An exact
eight-byte tail at destination offset 62, used for both pair matches, measured
0.9966x stage and 0.9996x frame geometry, with only 1/7 and 2/7 wins. The
retained helper changes neither branch order nor the second match.

Exact executable hashes, commands, observations, controls, and validation
counts are retained in
[zstd-pair-70-wild-tail-x86-20261002.json](data/zstd-pair-70-wild-tail-x86-20261002.json).

## Validation

- The new copy oracle and the split-Huffman specialized-versus-generic oracle
  pass in ReleaseSafe; the latter also passes in ReleaseFast.
- All 680 direct ReleaseFast Zstd tests pass.
- The 276-case libzstd compatibility matrix reports zero unsupported cases.
- Nine upstream decodecorpus campaigns pass all 9,900 frames, all 64 sequence
  mode combinations, incremental and reusable decoding, and 2,699 block-stream
  cases.
- Generic x86-64 and AArch64 Linux ReleaseFast compilation, the full project
  test suite, `zig build check -j1`, and the CLI help smoke test pass.
