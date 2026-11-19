# Zstd level ladder after the level 1/2 parser alignment, 2026-11-20

## Purpose

Level 1 now uses the single-table compact parser and level 2 the compact
double-fast parser, both selected by `applySpeedFirstLevelPolicy`. This note
records the resulting L1/L2/L3 ladder against libzstd 1.6.0 on the twelve
128 KiB Silesia prefixes, so the next parser work targets the real remaining
gap.

## Method

- Host Intel i7-10700K, Linux 6.8, Zig 0.16.0 ReleaseFast, `skylake+pku+sgx`,
  single thread.
- `run-zstd-encode-bench`, one-shot, `--limit 131072 --iterations 200
  --rounds 3 --libzstd ~/Work/zstd/lib/libzstd.so.1.6.0`, levels 1/2/3.
- Ratios are geometric means over the twelve rows; total bytes are the corpus
  sums. Every wire is verified by both libzstd and Vort before timing.

## Results

| level | size vs libzstd | speed vs libzstd | total bytes (Vort / ref) | weak rows |
| --- | ---: | ---: | ---: | --- |
| 1 | 1.0709x | 0.3057x | 672,871 / 632,131 | x-ray 150.6/1195.7 MiB/s, mozilla 227.3/919.5 |
| 2 | 1.0632x | 0.2757x | 650,603 / 608,084 | mr 83.0/431.5 MiB/s, mozilla 185.0/850.5 |
| 3 | 0.9580x | 0.0727x | 569,639 / 597,138 | nci 48.7/879.0 MiB/s, mr 17.3/294.0 |

The ladder is monotone on both axes: speed L1 > L2 > L3 and size L1 > L2 > L3.
Level 1 improved from about 4.2x slower than libzstd to **3.27x**; level 2 from
about 7.5x to **3.63x**. Level 3 is unchanged at **13.75x** slower while
staying 4.2% smaller, and is now the dominant speed gap.

## Interpretation

- Levels 1-2 are parser-bound by the compact double-fast/single-table family,
  which already dominates the controlled-fast alternatives on both axes.
  Further gains there are emitter-side or require a different parser kernel.
- Level 3 is ratio-first (smaller than libzstd) and pays 13.75x for it. A
  faster lazy/greedy parser or a level-3 policy that trades a little size for
  speed is the next structural decision.
- The size ladder has little headroom between L1 and L2 (1.0709 vs 1.0632);
  both are ~6-7% larger than libzstd, while L3 is smaller.

## Raw data

`data/zstd-level-ladder-20261120/ladder.csv` (36 rows, schema of
`run-zstd-encode-bench`).
