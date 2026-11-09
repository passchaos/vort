# Zstd raw sequence executors, 2026-11-09

Third decode increment on top of
[zstd-decode-field-groups-20261109.md](zstd-decode-field-groups-20261109.md).
The field-group treatment covered the split Huffman executors; the raw all-FSE
and Huffman-sequence executors still used the per-field optional chain and three
separate transition reads. Five of the 48 matrix rows contain raw literal blocks
(`mozilla.1m` L19 6/8, `sao.1m` L19 2/8, `samba.1m` L19 1/8, `mozilla.1m` L3
4/7, `samba.1m` L3 1/8), and `mozilla.1m` L19 was the second weakest row.

## Changes

- `decodeAllFseRawSequences`: read the extra bits and the three FSE transitions
  inside one grouped/ungrouped branch, use `sequence_transition_group.read` for
  the combined transition extraction, and move the ungrouped fallback into the
  shared `readUngroupedSequenceFields` helper.
- `decodeAllFseHuffmanSequencesImpl`: same single-branch field and transition
  read plus the out-of-line fallback.

The offset resolver does not touch the bit reader, so reading transitions before
resolving the offset preserves the exact bit-stream order.

## Validation

The direct test binary exits 0 with `All 1397 tests passed`. The `zig build`
wrapper again reports a failed command for the same passing binary; the direct
exit status is the gate, as recorded in the two earlier decode docs.

Paired A/B: previous binary vs this binary, 48 rows, 4 alternating rounds, CPU 15
pinned, per-row medians, Zig 0.16.0 `ReleaseFast`.

| Group | new/old time geomean |
| --- | ---: |
| level 3, 64 KiB | 1.0039 (+0.39%) |
| level 3, 1 MiB | 0.9996 (-0.04%) |
| level 19, 64 KiB | 1.0002 (+0.02%) |
| level 19, 1 MiB | 0.9865 (-1.35%) |
| all 48 rows | 0.9975 (-0.25%) |

Bootstrap 95% interval over rows: `[-0.81%, +0.19%]`. The overall matrix is
neutral because only five rows contain raw literal blocks, but those rows move
clearly: `mozilla.1m` L19 -9.47%, `sao.1m` L19 -5.04%, `mozilla.1m` L3 -2.03%.

Several short 64 KiB rows first appeared 1--3% slower. A dedicated recheck with
8 alternating rounds and 2--4x iterations per row found every one of them within
+/-0.46%, so those readings were short-run noise:

| Row | 4-round screen | 8-round recheck |
| --- | ---: | ---: |
| `nci.64k` L3 | +3.02% | +0.21% |
| `mr.64k` L3 | +1.37% | +0.08% |
| `ooffice.64k` L19 | +1.29% | +0.46% |
| `sao.64k` L19 | +1.26% | -0.13% |
| `samba.64k` L3 | +1.18% | -0.46% |

This is a target-row increment below the default 3% geometric-mean bar; it is
kept because it removes a verified 5--9% gap on the raw-literal rows with no
confirmed control regression.

Absolute matrix after this increment:

| Group | reference/Vort before | after |
| --- | ---: | ---: |
| level 3, 64 KiB | 0.7792 | 0.7786 |
| level 3, 1 MiB | 0.7648 | 0.7658 |
| level 19, 64 KiB | 0.7308 | 0.7354 |
| level 19, 1 MiB | 0.7348 | 0.7458 |
| all 48 rows | 0.7521 | **0.7562** |

The weakest rows are now `xml.64k` L19 (0.6678), `nci.64k` L19 (0.6934),
`xml.64k` L3 (0.7016), and `x-ray.64k` L19 (0.7107).

Raw rows:
[paired-ab-48rows.csv](data/zstd-decode-raw-field-groups-20261109/paired-ab-48rows.csv),
[control-recheck.csv](data/zstd-decode-raw-field-groups-20261109/control-recheck.csv),
and
[matrix-final.csv](data/zstd-decode-raw-field-groups-20261109/matrix-final.csv).

## Next

`xml.64k` L19 and `xml.64k` L3 are now the weakest rows. Profile their block
shapes and executor selection next; the remaining sequence-loop cost is the
per-sequence bit-reservoir address computation and the FSE table build for small
single-block frames.
