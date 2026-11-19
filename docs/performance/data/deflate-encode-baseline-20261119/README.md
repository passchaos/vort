# Deflate encode baseline and level-6 search-depth sweep, 2026-11-19

## Purpose

The repository had matched decode evidence for Deflate but no encode
comparison. `run-deflate-encode-bench` closes that gap: it encodes the same
prefix with Vort `encodeRawLevelAlloc`, zlib 1.2.11 and libdeflate 1.10,
verifies every wire with both Vort and libdeflate before timing, and then times
the ordinary allocating one-shot APIs in rotating order (`--iterations 3
--rounds 5`, min-of-rounds per encoder).

## Baseline (level 6, twelve 128 KiB Silesia prefixes)

Host Intel i7-10700K, Linux 6.8, Zig 0.16.0 ReleaseFast, `skylake+pku+sgx`,
single thread. libdeflate reports `LIBDEFLATE_VERSION_STRING=1.10`; zlib is the
system 1.2.11.

| case | vort bytes | zlib bytes | libdeflate bytes | vort MiB/s | zlib MiB/s | libdeflate MiB/s | vort/libdeflate |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| dickens | 50,649 | 50,675 | 50,679 | 16.18 | 25.32 | 68.45 | 0.236 |
| mozilla | 23,057 | 23,212 | 22,873 | 65.59 | 68.53 | 182.46 | 0.359 |
| mr | 33,433 | 33,291 | 32,101 | 11.74 | 21.88 | 73.13 | 0.161 |
| nci | 11,001 | 11,337 | 11,047 | 72.31 | 114.93 | 221.29 | 0.327 |
| ooffice | 68,136 | 68,303 | 68,034 | 23.13 | 27.28 | 77.60 | 0.298 |
| osdb | 51,361 | 51,674 | 51,265 | 34.97 | 43.13 | 111.21 | 0.314 |
| reymont | 36,834 | 37,101 | 37,163 | 14.28 | 27.06 | 76.79 | 0.186 |
| samba | 49,453 | 48,034 | 46,159 | 28.24 | 42.59 | 98.26 | 0.287 |
| sao | 99,220 | 98,991 | 99,568 | 19.61 | 24.81 | 71.89 | 0.273 |
| webster | 42,045 | 42,218 | 41,835 | 25.08 | 36.04 | 91.46 | 0.274 |
| xml | 10,035 | 10,466 | 10,411 | 99.27 | 148.31 | 228.28 | 0.435 |
| x-ray | 94,246 | 94,821 | 94,453 | 32.56 | 37.16 | 91.40 | 0.356 |

Geometric-mean speed: Vort is **0.2825x** libdeflate and **0.7086x** zlib.
Sizes are mixed: Vort is smaller than libdeflate on six rows (dickens, nci,
reymont, sao, xml, x-ray) and larger on six (mozilla +0.8%, mr +4.1%,
ooffice +0.15%, osdb +0.19%, samba +7.1%, webster +0.5%).

## Hot spot

Flat `perf` on the dickens level-6 encode attributes **42.67%** to
`lz77.findBestHashMatchWithLayout` (hash-chain match finder), 4.47% to
`lazyGreedyPlanAlloc`, and 2.01% to `lz77.matchLength`. The default preset
(`optionsForLevel(.default)`, also used by zlib level 6 and the archive
defaults) searches `max_chain = 160`, deeper than zlib's 128 and far deeper
than libdeflate level 6's `max_search_depth = 35`.

## Search-depth sweep (level 6, Vort only)

Only `max_chain` was changed; `nice_len` stayed at 80. Speed and size ratios
are against the current chain-160 preset, geometric mean over the twelve
prefixes.

| max_chain | speed vs 160 | size vs 160 | worst size | min speed row |
| ---: | ---: | ---: | ---: | ---: |
| 35 | 1.5393x | 1.0141x | +3.6% | 0.970x |
| 64 | 1.2985x | 1.0073x | +2.0% | 1.015x |
| 96 | 1.1547x | 1.0034x | +1.2% | 0.974x |
| 160 (current) | 1.0000x | 1.0000x | 0 | 1.000x |

Chain 64 is the cleanest knee: +29.85% speed for +0.73% geometric-mean size
with no row slower than 1.015x. Chain 35 reaches +53.9% speed but costs 1.41%
size and has a 0.970x row. Adopting either is a **level-preset policy
decision** (it also changes the archive defaults), so this commit only adds
the benchmark and the evidence; the production preset is unchanged.

## Raw data

- `level6-chain160.csv`: baseline matrix.
- `level6-chain35.csv`, `level6-chain64.csv`, `level6-chain96.csv`: sweep.
- CSV rows use the `run-deflate-encode-bench` schema; provenance columns are
  appended by `benchmark_provenance`.

## Scope limits

One host, one 128 KiB prefix per file, one-shot raw Deflate, min-of-five
interleaved rounds, single thread. libdeflate 1.10 and zlib 1.2.11 are the
system libraries; a libdeflate 1.26 comparison is a follow-up once the encode
tool grows an explicit reference-path option. libdeflate's compressor is
allocated once per measurement round and reused across iterations, while Vort
and zlib pay their allocating one-shot API per iteration, so the reported
Vort/libdeflate ratio is conservative; a per-call compressor lifecycle is a
follow-up measurement. Levels 1 and 9 were spot-checked
(dickens level 1: Vort 89.72 MiB/s vs libdeflate 191.34, sizes 54,008 vs
54,677; level 9: Vort 1.14 MiB/s vs libdeflate 31.32, sizes 48,229 vs 50,040)
but not swept across the corpus.
