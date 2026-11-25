# Zstd controlled-parser record reservation, 2026-11-20

## Decision

The greedy/lazy/optimal parse now reserves `block.len / 5 + 8` records before
`planReuse`. Twelve 128 KiB level-3 prefixes measure **1.0388x** geometric-mean
encode speed with **byte-identical wires**; every row is at least 1.011x except
dickens at 0.998x, which is run noise.

## Motivation

A flat profile of the level-3 dickens encode attributed 1.36% self to
`array_list.Record.append` and 1.45% to the `memmove` performed by its growth
path. One-shot encodes start with an empty persistent record list, and the
controlled parsers emit about one 40-byte record per five to six input bytes on
text, so the list repeatedly copied its whole prefix. The reservation is the
measured density plus a small slack; denser blocks still grow once.

## Measurement

- Host Intel i7-10700K, Linux 6.8, Zig 0.16.0 ReleaseFast, `skylake+pku+sgx`,
  single thread.
- `run-zstd-encode-bench`, level 3 (policy path), one-shot, twelve 128 KiB
  Silesia prefixes, `--iterations 50 --rounds 3`, interleaved with libzstd
  1.6.0, old/new binaries alternating per file.

| case | before MiB/s | after MiB/s | speed | bytes |
| --- | ---: | ---: | ---: | ---: |
| dickens | 20.12 | 20.09 | 0.998 | 53,193 |
| mozilla | 52.25 | 53.04 | 1.015 | 20,168 |
| mr | 27.20 | 29.05 | 1.068 | 33,168 |
| nci | 57.97 | 59.17 | 1.021 | 11,488 |
| ooffice | 21.82 | 23.07 | 1.057 | 68,792 |
| osdb | 27.15 | 28.81 | 1.061 | 51,344 |
| reymont | 24.23 | 25.98 | 1.072 | 40,534 |
| samba | 30.10 | 30.48 | 1.013 | 48,991 |
| sao | 18.03 | 19.14 | 1.062 | 99,611 |
| webster | 24.84 | 26.70 | 1.075 | 43,865 |
| xml | 70.03 | 70.78 | 1.011 | 11,075 |
| x-ray | 16.38 | 16.67 | 1.018 | 93,189 |

Geometric mean **1.0388x**; all twelve output sizes are byte-identical to the
pre-change policy path (total 575,418 bytes).

## Raw data

`before.csv` and `after.csv` (schema of `run-zstd-encode-bench`).
