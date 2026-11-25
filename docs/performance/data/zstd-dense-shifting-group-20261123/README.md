# Zstd dense decoder shifting field group, 2026-11-23

## Change

The dense split-Huffman sequence executor now reads the grouped extra bits and
FSE transitions with `sequence_field_group.ShiftingGroup.initProven` instead of
the `Group`/`consumed` variant. The shifting group extracts each field with a
constant shift and advances the word, removing the running consumed-position
dependency from every extraction. The whole group is committed
(`reader.remaining_bits -= total_bits`) before the literal and match copies; the
ungrouped fallback is unchanged. Decode output and size are unchanged.

## Method

- Host Intel i7-10700K, Linux 6.8, Zig 0.16.0 ReleaseFast, single thread;
  system libzstd 1.4.8 reference in every row.
- `run-zstd-reference-bench`, level-9 wires, 64 KiB and 1 MiB prefixes,
  300 iterations per run, five alternating before/after pairs per row (240
  runs). The reported value is the within-run Vort/reference time ratio of the
  candidate divided by the baseline's; per-row medians feed the geometric mean
  and a row-resampled bootstrap (10,000 resamples, seed 0x5A17).

## Result

| row | median | row | median |
| --- | ---: | --- | ---: |
| dickens.64k | 1.0489 | dickens.1m | 1.0251 |
| mozilla.64k | 1.0415 | mozilla.1m | 1.0058 |
| mr.64k | 1.0211 | mr.1m | 1.0285 |
| nci.64k | 1.0432 | nci.1m | 1.0087 |
| ooffice.64k | 0.9984 | ooffice.1m | 0.9965 |
| osdb.64k | 1.0132 | osdb.1m | 0.9919 |
| reymont.64k | 1.0459 | reymont.1m | 1.0358 |
| samba.64k | 1.0040 | samba.1m | 1.0119 |
| sao.64k | 1.0101 | sao.1m | 0.9985 |
| webster.64k | 1.0408 | webster.1m | 1.0362 |
| xml.64k | 1.0212 | xml.1m | 1.0180 |
| x-ray.64k | 0.9998 | x-ray.1m | 1.0044 |

Geometric mean **1.0186x**, bootstrap 95% CI **[1.0119, 1.0254]**; the weakest
row is `osdb.1m` 0.9919, above the 0.98 control floor. The gain concentrates
on command-dense text (`dickens`, `reymont`, `nci`, `webster` 1.04--1.05), which
is where the grouped field reads dominate.

## Validation

The complete Debug suite passes 5,745/5,747 tests with two skipped, and
`zig build check-wasm` exits zero.

## Raw data

`r{1..5}-<case>-<size>-{B,V}.csv` for the 24 rows and five rounds (schema of
`run-zstd-reference-bench`); `pass1-*` and `pass2-*` retain the earlier
order-reversed screens.
