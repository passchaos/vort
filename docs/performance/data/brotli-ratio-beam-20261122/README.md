# Brotli ratio-planner candidate beam, 2026-11-22

## Decision

`selectOptimalRatioCandidates` now uses a 32-entry candidate beam instead of
128 for the `.ratio` planned level. The public q0--q11 quality presets use the
quality-scheduled path and are unchanged; this affects callers of
`encodePlannedStreamWithOptionsAlloc` with `.level = .ratio`.

## Method

- Host Intel i7-10700K, Linux 6.8, Zig 0.16.0 ReleaseFast, single thread;
  system libbrotli 1.0.9 as the q9 reference.
- `run-br-planned-encode-bench`, twelve 64 KiB Silesia prefixes, three
  iterations per point; the adopted 32 point was re-run at ten iterations.
- The bench's `ratio` mode is `encodePlannedStreamWithOptionsAlloc` with
  `.level = .ratio`; the optimal proposal stage consumes `max_candidates`.

## Sweep

| beam | geometric speed | geometric size | worst rows |
| ---: | ---: | ---: | --- |
| 128 (before) | 1.0000x | 1.0000x | -- |
| 64 | 1.0703x | 1.0024x | nci 1.3153x / +1.19%, xml 1.1119x / +0.93% |
| **32 (adopted)** | **1.1683x** | **1.0054x** | xml 1.3827x / +2.28%, nci 1.7537x / +2.10% |
| 16 | 1.2597x | 1.0087x | nci 2.2069x / +3.75%, reymont 1.3008x / +2.45% |
| 8 | 1.3457x | 1.0117x | nci 2.9064x / +5.12%, reymont 1.3906x / +2.45% |

The ten-iteration confirmation of 32 measures **1.1668x** speed and **+0.54%**
size with the same per-row sizes, so the gain is stable. Structured text is
where the beam matters: `nci` gains 1.72--1.75x for +2.10% and `xml` 1.38x for
+2.28%; six rows are byte-identical (`ooffice`, `sao`, `mr`, `osdb`, `x-ray`,
`mozilla`).

The 8 point is rejected because `nci` grows 5.12%, beyond the repository's 5%
text-growth block. The 32 point keeps every row under 2.3% growth while
recovering most of the speed, and the ratio level previously matched libbrotli
q9 size at one third of its throughput.

## Raw data

`base-q9-*.csv` (128 beam, 3 iterations), `64-`, `32-`, `16-`, `8-` sweeps
(3 iterations) and `32b-q9-*.csv` (32 beam, 10 iterations), schema of
`run-br-planned-encode-bench`.
