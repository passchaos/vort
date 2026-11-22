# Window-local s16 hash4 matchfinder, 2026-11-22

## Decision

Levels 6 and 7 route their classified blocks through a window-local s16
matchfinder instead of the whole-input absolute `u32 prev[]` chain. The
tables mirror libdeflate's HC layout: 64 KiB `head3`, 128 KiB `head4` and a
64 KiB predecessor ring, all s16 and relative to a 32 KiB slide base. Once
per 32 KiB the three tables are rebased with saturating `i16` vector
subtraction; entries older than the new window saturate to the sentinel.
The candidate order and match rules are otherwise unchanged.

Positions exactly 32768 bytes back saturate to the sentinel and are not
searched; a candidate at that distance also shares its ring slot with the
current position, so rejecting it avoids reading an already overwritten
link. All 24 benchmark wires are byte-identical, so no measured row used
such a match.

## Results

Twelve 128 KiB prefixes, `--iterations 100 --rounds 5`, before/after binaries
alternating per file. Before is the committed absolute-chain source; after is
this change.

| level | geometric-mean speed | total bytes | zlib 1.2.11 | libdeflate 1.10 |
| --- | ---: | ---: | ---: | ---: |
| 6 | **1.0506x** | 570,615 -> 570,615 (+0.000%) | 570,123 | 565,588 |
| 7 | **1.0445x** | 568,400 -> 568,400 (+0.000%) | 568,214 | 562,828 |

Level 6 routed rows: dickens 1.1699x, ooffice 1.1488x, osdb 1.2497x,
webster 1.1360x, reymont 0.9570x. Level 7 routed rows: dickens 1.0941x,
ooffice 1.1209x, osdb 1.2915x, webster 1.1383x, reymont 0.9812x. The
non-routed rows run identical code in both binaries; their level-6 ratios
span 0.9820--1.0307x and their level-7 ratios 0.9721--1.0094x, which bounds
the run noise.

Because `reymont` was the only routed row without a clear win, it was
re-measured with three independent 200-iteration x 5-round pairs. Medians:
level 6 reymont **0.9836x** (runs 0.9836/0.9818/1.0107), dickens 1.1326x,
xml control 1.0064x; level 7 reymont **1.0106x**
(1.0233/1.0106/0.9579), dickens 1.0977x, xml control 1.0105x. The single
0.9570x level-6 sample was run noise; the focused median stays above the
0.98 control floor.

## Correctness

A test-only absolute-position walk with the same 32768 cutoff is compared
against the windowed tables at every position of a 100 KiB mixed input that
slides the window three times: lengths and distances match exactly. The
one-shot benchmark verifies every wire with both Vort and libdeflate before
timing, and all 24 output sizes are unchanged.

## Measurement

- Host Intel i7-10700K, Linux 6.8, Zig 0.16.0 ReleaseFast, `skylake+pku+sgx`,
  single thread; zlib 1.2.11 and libdeflate 1.10 references in every row.
- `run-deflate-encode-bench`, 128 KiB prefixes, one-shot, old/new binaries
  alternating per file in one session.

## Raw data

`level6-128k-before.csv` / `level6-128k-after.csv`,
`level7-128k-before.csv` / `level7-128k-after.csv` (100 x 5), and the
`focus-L{6,7}-{reymont,dickens,xml}-r{1,2,3}-{B,V}.csv` re-measurement files
(200 x 5). Each CSV carries the executable SHA and command.
