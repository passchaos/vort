# Zstd level-1 fast-parser redesign screen, 2026-11-17

## Purpose

The level-1 double-fast parser is the largest encode cost (33.7% of the
standalone profile). This screen measures isolated parser variants on the
twelve 128 KiB Silesia prefixes at level 1 (ReleaseFast, one iteration,
three rounds) to find the speed/ratio frontier before any product change.

## Variants

| variant | parser change | speed geomean | total size delta |
| --- | --- | ---: | ---: |
| production | two hash tables, rep probes, lazy | 1.000x | 0 |
| drop lazy | no short-match lookahead | **0.964x** | +0.31% |
| drop short table | 8-byte hash only, keeps lazy/rep | **1.52x** | +4.35% |
| single table | 8-byte hash only, no lazy/rep | **1.86x** | +7.6% |
| single table + rep0 | adds a rep0 probe | **1.57x** | +6.2% |

Per-file sizes are in the raw CSVs. Notable rows: dropping the short table
grows ooffice +8.4%, reymont +12.3%, mozilla +10.3%, while nci/xml/mr are
neutral or better. Dropping lazy grows size only 0.31% but slows the parser
because the lookahead saves loop iterations.

## Conclusion

- Lazy lookahead is both a ratio and a speed win; keep it.
- The 4-byte short table is the ratio backbone: removing it is the main
  speed lever (1.52x) but costs 4.35% size.
- The pure single-table design reaches 1.86x but costs 7.6% size; rep0
  recovers only 1.4% of that for a 15% speed loss.
- Level 1 keeps its current balance. A product-level "fastest" variant could
  use the drop-short or single-table parser, but that is a policy decision,
  not an automatic replacement.

## Raw files

- `production-baseline.csv`
- `drop-lazy.csv`
- `drop-short-table.csv`
- `single-table.csv`
- `single-table-rep0.csv`
