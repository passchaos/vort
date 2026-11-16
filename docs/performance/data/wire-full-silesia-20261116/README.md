# Full-Silesia decode baseline (12 files), all three wire codecs, 2026-11-16

## Why this sweep

The earlier three-file package
([wire-reference-baseline-20261116](../wire-reference-baseline-20261116/README.md))
over-represented the two historically weak rows (`nci`, `mozilla`) plus `xml`,
and happened to include favorable files. Small samples mis-led twice: they made
Deflate look near-parity and Brotli look like a steady ~0.93x. This sweep runs
all twelve Silesia files for all three codecs so the directional result is not
an artifact of file choice.

## Method

`run-deflate/zstd/br-reference-bench`, 20 iterations, one round, one-shot
single-thread decode, ReleaseFast on the i7-10700K. Each per-file CSV is
retained alongside the normalized `full-silesia.csv`;
`vort_over_reference_throughput = vort_mib_s / reference_mib_s` (>1 = Vort
faster). References: libdeflate **1.10**, libzstd **1.4.8**, libbrotli
**1.0.9**.

## Summary

| codec | files | min | median | max | Vort slower | Vort ≥ ref |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Deflate | 12 | 0.891 | **0.940** | 1.151 | 9 | 3 |
| zstd | 12 | 0.550 | **0.799** | 0.909 | 12 | 0 |
| Brotli | 12 | 0.747 | **0.957** | 1.466 | 7 | 5 |

Per-file ratios are in `full-silesia.csv`.

## Findings: both small-sample reads were wrong

- **Deflate is not net-competitive against libdeflate 1.10.** The 3-file view
  looked near parity, but across twelve files Vort is slower on 9/12 (median
  0.940). Wins cluster on highly compressible inputs; typical 25-74%-ratio
  files run 6-11% behind.
- **zstd is behind on every file (12/12)**, median 0.799, worst `x-ray` 0.550.
- **Brotli is strongly file-dependent, not a steady ~0.93x.** It spans
  0.747 (`mr`) to 1.466 (`sao`); Vort is faster on 5/12 and slower on 7/12.
  The two largest Vort wins are near-incompressible files: `sao` (83% encoded
  size) at 1.466 and `x-ray` (78%) at 1.324. The 3-file sample (xml/nci/mozilla,
  all 0.93ish) simply never included these high-ratio files or the `mr` low.

## Cross-codec contrast on near-incompressible data

The same files expose opposite behavior, which is a useful architectural
signal rather than noise:

| file | encoded size | zstd V/R | Brotli V/R |
| --- | ---: | ---: | ---: |
| sao | 83-86% | 0.909 (behind) | **1.466 (ahead)** |
| x-ray | 78-80% | 0.550 (worst zstd row) | **1.324 (ahead)** |

zstd's X2 Huffman gate deliberately excludes these shapes (the
[X2 gate analysis](../zstd-xray-huffman-gate-20261116.md) shows the scalar
fallback is already the faster option there), whereas Vort's Brotli decoder
handles long literal runs more efficiently than libbrotli 1.0.9. There is no
single "best on all inputs" decoder; the relative strength flips with the
data's compressibility and with the codec.

## Scope limits

- Single host, one round per file at 20 iterations, no CPU pinning or paired
  interleave: a broad directional sweep, not the section-8 adoption gate. The
  companion stability package showed CV under 0.7%, so medians are repeatable.
- **The zstd (2020) and Brotli (2016) references are old.** Against current
  upstream the gaps may be larger; treat the ratios as lower bounds on the
  competitive distance, especially for Brotli where Vort currently leads some
  rows — those leads could shrink against a modern libbrotli.
- Decode one-shot only; no encode, RSS, streaming, or cold/warm split.
- Compressed-size percentages are each codec's own wire output and are not
  cross-compared between formats.
- Measurement only; no production code changed.

## Direction

The corrected picture: zstd is uniformly behind and structurally bounded by
the FSE serial wall; Deflate has a compressibility-dependent crossover; Brotli
is bimodal, with a real Vort advantage on near-incompressible literal-heavy
data that should be re-checked against a current libbrotli before any claim.
