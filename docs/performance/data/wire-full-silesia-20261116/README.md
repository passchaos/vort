# Full-Silesia decode baseline (12 files), Deflate and zstd, 2026-11-16

## Why a second sweep

The earlier three-file package
([wire-reference-baseline-20261116](../wire-reference-baseline-20261116/README.md))
over-represented the two historically weak rows (`nci`, `mozilla`) plus `xml`,
and happened to include the files where Vort's Deflate decoder is fastest.
This sweep runs all twelve Silesia files so the directional result is not an
artifact of file choice. Brotli is excluded here: the earlier package already
showed it tightly clustered around ~0.93x with no file dependence, and its
benchmark is much slower per byte.

## Method

`run-deflate-reference-bench` and `run-zstd-reference-bench`, 20 iterations,
one round, one-shot single-thread decode, ReleaseFast on the i7-10700K. Each
per-file CSV is retained alongside the normalized `full-silesia.csv`;
`vort_over_reference_throughput = vort_mib_s / reference_mib_s` (>1 = Vort
faster). References: libdeflate **1.10** (recent), libzstd **1.4.8** (old).

## Summary

| codec | files | min | median | max | Vort slower | Vort ≥ ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Deflate | 12 | 0.891 | **0.940** | 1.151 | 9 | 3 |
| zstd | 12 | 0.550 | **0.799** | 0.909 | 12 | 0 |

Per-file ratios are in `full-silesia.csv`.

## Findings, including the correction to the 3-file read

- **Deflate is not net-competitive against libdeflate 1.10.** The 3-file
  sample (nci 1.15, xml 1.02, mozilla 0.94) looked near parity, but across all
  twelve files Vort is slower on 9/12 with a median 0.940 (~6% behind). The
  wins cluster on highly-compressible inputs (`nci`, `xml`, `osdb` at
  9.5-13% encoded size); on the bulk of files at 25-74% encoded size Vort is
  6-11% behind. The prior "file-dependent near parity" framing was an artifact
  of which three files were picked; the corpus-level picture is a modest
  systematic deficit with a few favorable outliers.
- **zstd is behind on every file (12/12).** The ~0.8x from the small sample
  generalizes: median 0.799 (~20% slower), and one severe weak row, `x-ray`
  at **0.550** (incompressible-heavy, 80% encoded size). `sao` (86% encoded)
  is the best case at 0.909 and still behind. There is no file where Vort
  reaches parity with even the old libzstd 1.4.8.

## Scope limits

- Single host, one round per file at 20 iterations, no CPU pinning or paired
  interleave: a broad directional sweep, not the section-8 adoption gate. The
  companion stability package showed CV under 0.7%, so these medians are
  repeatable.
- **The zstd reference is old (2020).** Against current libzstd the gap may be
  larger; treat 0.799 as a lower bound on the distance.
- Decode one-shot only; no encode, RSS, streaming, or cold/warm split.
- Compressed-size percentages are each codec's own wire output and are not
  cross-compared between formats.
- Measurement only; no production code changed.

## Direction

The data sharpens the target list: zstd decode is uniformly behind (and
`x-ray` is a concrete worst case worth profiling), while Deflate has a
compression-ratio-dependent crossover rather than uniform parity. Both remain
bounded by the documented FSE/Huffman serial walls within their wire formats,
so improvements are structural, not local micro-edits.
