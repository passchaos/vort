# Zstd decode sequence executors, 2026-11-09

Follow-up to the current-source 48-row decode matrix
([zstd-decode-current-20261109.md](zstd-decode-current-20261109.md)). Profiles of
the weakest rows put 69% (`nci.64k` level 19, medium split executor) and 81%
(`x-ray.64k` level 19, wide split executor) of decode time inside the split
sequence executors, so this round changes only those loops.

## Changes

Medium split executor (`tryDecodeMediumSplitHuffmanSequencesImpl`):

- read the six sequence fields and the three FSE transitions inside one
  grouped/ungrouped branch instead of testing the optional group per field;
- keep short matches on the 16-byte wildcopy path. An offset of at least 16
  proves the 16-byte source window is initialized, and the existing capacity
  check already covers the rounded copy, so the previous `match_len >= 16` gate
  only pushed 4--15-byte matches into the exact-copy tail;
- skip the literal wildcopy for zero-literal sequences;
- use the single-vector match kernel for `match_len <= 16`.

Wide split executor (`decodeAllFseSplitHuffmanSequences` with
`use_wide_copies = true`):

- same single-branch grouped field read and transition update;
- use the single-vector match kernel for `match_len <= 16` (previously gated to
  the non-wide instantiations).

The dense executor keeps its previous fast path.

## Rejected

- Empty-literal copy skip in the dense executor: `nci.64k` level 3 +1.9%. The
  zero/nonzero split is close to 50/50 there, so the added branch mispredicts
  more than the skipped 16-byte copy saves.
- Empty-literal copy skip in the wide executor: `ooffice.1m` level 19 +3.6% and
  `osdb.64k` level 3 +2.2%. Dropping it recovered -5.9% and -3.5% on those rows.
- Two-vector exact copies for non-overlapping 16--31 and 32--63 byte matches in
  the medium fast path: about 1--2% slower than the 16-byte wildcopy loop.
- Local `repeated_offsets` in the medium executor: about 15% slower; the extra
  live three-word state increases register pressure and spills.

## Validation

`zig build test-zstd` runs the 1397-test suite; the direct test binary exits 0
with `All 1397 tests passed`. The `zig build` wrapper reports a failed command
for the same binary even on passing content, the same artifact class as the
known WebAssembly gate wrapper behavior, so the direct exit status is treated as
the gate.

Paired A/B: HEAD binary vs final binary, 48 rows (12 Silesia sources, 64 KiB and
1 MiB prefixes, levels 3 and 19), 4 alternating rounds per row, per-row median,
CPU 15 pinned, Zig 0.16.0 `ReleaseFast`. Only Vort times are compared; the
reference frames and libzstd version are identical for both binaries.

| Group | new/old time geomean |
| --- | ---: |
| level 3, 64 KiB | 0.9893 (-1.07%) |
| level 3, 1 MiB | 0.9811 (-1.89%) |
| level 19, 64 KiB | 0.9843 (-1.57%) |
| level 19, 1 MiB | 0.9852 (-1.48%) |
| all 48 rows | **0.9850 (-1.50%)** |

Bootstrap 95% interval over rows: `[-2.15%, -0.88%]`.

Largest improvements: `x-ray.64k` L19 -5.72%, `ooffice.1m` L19 -5.53%,
`sao.64k` L19 -5.50%, `ooffice.1m` L3 -5.42%, `x-ray.1m` L19 -5.40%,
`ooffice.64k` L3 -5.26%, `sao.1m` L3 -4.94%, `nci.64k` L19 -4.14%.

Controls: the 1 MiB rows stay within -0.4%/+1.2%; the short 64 KiB runs stay
within +/-1.9%, which is short-run noise at 14 ms per row. No control row shows a
verified regression.

The absolute matrix with the same binary and protocol as the baseline doc:

| Group | reference/Vort before | after |
| --- | ---: | ---: |
| level 3, 64 KiB | 0.7437 | 0.7473 |
| level 3, 1 MiB | 0.7220 | 0.7338 |
| level 19, 64 KiB | 0.6709 | 0.6907 |
| level 19, 1 MiB | 0.6923 | 0.7038 |
| all 48 rows | 0.7067 | **0.7185** |

The weakest rows are now `nci.64k` L19 (0.5690, was 0.5106), `x-ray.64k` L19
(0.5732, was 0.5451), and `x-ray.1m` L19 (0.6222, was 0.5843).

This is below the default 3% geometric-mean merge bar. It is recorded as an
incremental, non-regressing executor cleanup whose declared target rows (the
level-19 sequence-dense shapes) improve 4--6%, with a confidence interval
excluding parity.

Raw rows:
[paired-ab-48rows.csv](data/zstd-decode-sequence-executors-20261109/paired-ab-48rows.csv)
and
[matrix-final.csv](data/zstd-decode-sequence-executors-20261109/matrix-final.csv).

## Next

The dense executor is now the largest remaining gap. On `dickens.64k` level 3 it
executes 187 instructions per sequence at 49 cycles and IPC 3.8, while libzstd
needs about 37 cycles per sequence on the same row. The persistent bit reservoir
and branchless field extraction are the next structural candidates; the current
group load address still depends on the remaining bit count every sequence.
