# x86-64 Zstd 71-byte overlap-tail copy

The 2026-10-01 change reduces the exact-copy cost in the compact split-Huffman
executor selected by the synthetic `large_json` benchmark. Its four full
blocks each contain about 1,834 sequences and 2 KiB of literals; most output is
formed by non-overlapping 68--71-byte matches.

## Implementation and safety

The existing 71-byte helper used two 32-byte moves followed by an eight-byte
tail load, shift, destination-suffix load, merge, and eight-byte store. The new
pair-path helper loads all source bytes before writing, stores the same first
64 bytes, then writes an exact eight-byte tail at destination offsets 63--70.
The final store overlaps the preceding store by one byte but never writes past
the logical match.

The helper is selected only inside the already validated paired
one-literal/rep0 path and only when `match_len == 71` and
`match_offset >= 71`. Existing combined pair bounds prove output capacity, and
the non-overlap condition proves every source load is initialized before any
destination store. All other matches retain their established kernels.

## Performance evidence

Measurements use frozen ReleaseFast executables pinned to CPU 2 on an Intel
Core i7-10700K. Each process alternates five Vort/libzstd samples and reports
the fastest; 15 outer pairs alternate baseline/candidate process order. The
baseline is commit `89ce6618`; the reference is the user-provided
`~/Work/zstd` checkout at commit
`01b7154f1172432f8abe9b3bb9909e14a1176b7d` (libzstd 1.6.0-dev).

Across 15 pairs of 3,000 complete `large_json` decodes, the candidate improves
by **1.0096x median / 1.0105x geometric mean**, wins **14/15**, and ranges from
0.9981x to 1.0255x. After simultaneous libzstd normalization the geometric
gain is 1.0144x with 15/15 wins. Vort remains at 0.7940x libzstd by median, so
this is a bounded executor improvement rather than a leadership result.

A seven-pair 13-row control matrix measures `large_json` at 1.0065x median /
1.0114x geometric mean with 7/7 wins. `huffman80k`, `large_text`, and
`binary_mixed` remain within 0.45% of neutral geometrically. Short rows retain
wider scheduler noise and are not attributed to this path.

The nearest prepared-stage shape generated from the fixed 128 KiB payload at
libzstd level 2 contains 1,835 sequences and 2,117 literals. Across 15 paired
5,000-decode runs its executor improves by 1.0030x median / 1.0032x geometric
mean with 10/15 wins. The exact repository fixture has a different 2,874-byte
wire shape, so complete-frame results remain the primary evidence.

Exact observations and hashes are retained in
[zstd-large-json-overlap-tail-x86-20261001.json](data/zstd-large-json-overlap-tail-x86-20261001.json).

## Validation and remaining work

- The copy helper is compared with the generic LZ match copy across lengths,
  minimum-distance boundaries, full output bytes, and untouched suffix bytes
  in ReleaseFast and ReleaseSafe.
- The existing split-Huffman oracle proves byte equality against the generic
  executor, short-output behavior, 64 sequence-bit mutations, 64 literal-bit
  mutations, and production route selection.
- All 677 direct ReleaseFast Zstd tests pass.
- The 276-case compatibility matrix, 9,900-frame/64-mode decodecorpus, generic
  x86-64/AArch64 compile checks, 13-row one-shot reference gate, and repository
  build check pass.

A combined 68--71-byte tail kernel regressed the target, and a pair-first
one-byte-overwrite variant had zero hits in the fixed fixture; both were
removed. Remaining work should reduce the compact loop's FSE state-update and
branch cost, then address the wider `binary_mixed` path.
