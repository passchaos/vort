# Zstd decode field groups and out-of-line fallback, 2026-11-09

Second decode increment on top of
[zstd-decode-sequence-executors-20261109.md](zstd-decode-sequence-executors-20261109.md).
The previous round left the three FSE transition reads as separate `Group.read`
calls in the medium and wide split executors, and kept the ungrouped fallback
inline in all three split executors. Both choices lengthen the hot loop.

## Changes

- Read the three FSE transitions through `sequence_transition_group.read`: one
  combined group extraction plus three shifts instead of three dependent
  `Group.read` calls, each of which carried its own running `consumed` update.
- Move the rare ungrouped fallback into `readUngroupedSequenceFields`, a
  `noinline` helper shared by the medium, dense, and wide split executors. The
  fallback only runs when the 64-bit field group cannot cover a sequence (large
  extras or the physical stream tail), so keeping it out of line leaves the
  grouped hot loop free of its branches and register pressure.
- Fold the transition read into the same grouped/ungrouped branch as the extra
  bits in the medium and wide executors. The offset resolver does not touch the
  bit reader, so reading transitions before resolving the offset preserves the
  exact bit-stream order.

## Validation

`zig build test-zstd` runs the 1397-test suite. As in the previous round, the
`zig build` wrapper reports a failed command for the test binary while the
direct binary exits 0 with `All 1397 tests passed`; the direct exit status is
the gate.

Paired A/B: HEAD binary (previous increment) vs this binary, 48 rows (12 Silesia
sources, 64 KiB and 1 MiB prefixes, levels 3 and 19), 4 alternating rounds per
row, per-row median, CPU 15 pinned, Zig 0.16.0 `ReleaseFast`. Only Vort times
are compared; both binaries use the same reference frames and libzstd 1.4.8.

| Group | new/old time geomean | bootstrap 95% CI |
| --- | ---: | ---: |
| level 3, 64 KiB | 0.9539 (-4.61%) | [0.9351, 0.9721] |
| level 3, 1 MiB | 0.9426 (-5.74%) | [0.9180, 0.9659] |
| level 19, 64 KiB | 0.9214 (-7.86%) | [0.8734, 0.9630] |
| level 19, 1 MiB | 0.9409 (-5.91%) | [0.9025, 0.9748] |
| all 48 rows | **0.9396 (-6.04%)** | [0.9221, 0.9557] |

Largest improvements: `x-ray.64k` L19 -24.11%, `nci.64k` L19 -21.05%,
`x-ray.1m` L19 -20.66%, `x-ray.1m` L3 -13.61%, `ooffice.1m` L19 -12.11%,
`sao.64k` L19 -11.85%, `osdb.64k` L19 -10.90%, `ooffice.64k` L3 -10.70%.

Controls: the only non-improving rows are `dickens.64k` L3 +0.47% and
`webster.1m` L19 +0.03%, both inside short-run noise. Every group confidence
interval excludes parity, and the overall improvement clears the default 3%
merge bar.

The absolute matrix with the same binary and protocol as the earlier docs:

| Group | reference/Vort before | after |
| --- | ---: | ---: |
| level 3, 64 KiB | 0.7473 | 0.7792 |
| level 3, 1 MiB | 0.7338 | 0.7648 |
| level 19, 64 KiB | 0.6907 | 0.7308 |
| level 19, 1 MiB | 0.7038 | 0.7348 |
| all 48 rows | 0.7185 | **0.7521** |

The weakest rows are now `xml.64k` L19 (0.6488), `mozilla.1m` L19 (0.6626),
`nci.64k` L19 (0.6806), and `x-ray.64k` L19 (0.7103).

Raw rows:
[paired-ab-48rows.csv](data/zstd-decode-field-groups-20261109/paired-ab-48rows.csv)
and
[matrix-final.csv](data/zstd-decode-field-groups-20261109/matrix-final.csv).

## Next

- Apply the same grouped-transition and out-of-line fallback treatment to the
  raw all-FSE executors (`decodeAllFseRawSequences` and its adaptive variants),
  which still use the per-field optional pattern and three separate transition
  reads.
- Re-profile the dense executor; the out-of-line fallback removed code from its
  hot loop, and the remaining gap is the per-sequence bit-reservoir address
  computation.
