# Deflate hash4-chain parser with a block classifier, 2026-11-20

## Decision

Level 6 (raw/zlib/gzip `.default`) now enables the lazy parser's
chainless 3-byte slot plus 4-byte hash chain through
`GreedyOptions.hash4_chain`, gated per plan call by a cheap content
classifier. Brotli and every default-option caller stay on the historical
3-byte chain.

## Parser and classifier

- Parser: `head3` (chainless 3-byte slot) plus `head4` (4-byte hash chain),
  mirroring libdeflate's HC matchfinder. It keeps 3-byte matches through the
  slot and prunes 4-byte-mismatched candidates out of the chain.
- Classifier: a direct-mapped 14-bit 4-byte hash over the middle 4 KiB of the
  input, probing every 8th position against the most recent occurrence with a
  64-byte match cap. Average best length in **3.5...10.5 bytes** selects the
  hash4 parser; longer or near-zero values keep the historical chain, where
  the extra table load is pure overhead. The classifier costs well under 1%
  of a block encode.

## Results

Twelve 128 KiB level-6 prefixes, `--iterations 50 --rounds 3`, old/new
binaries alternating per file:

| case | before MiB/s | after MiB/s | speed | bytes |
| --- | ---: | ---: | ---: | ---: |
| dickens | 22.18 | 26.71 | 1.204 | 50,996 -> 50,665 (-0.65%) |
| mozilla | 87.04 | 85.75 | 0.985 | 23,159 (unchanged) |
| mr | 22.01 | 22.46 | 1.020 | 33,563 (unchanged) |
| nci | 99.68 | 99.82 | 1.001 | 11,174 (unchanged) |
| ooffice | 28.73 | 30.42 | 1.059 | 68,263 -> 68,185 (-0.11%) |
| osdb | 44.24 | 43.64 | 0.986 | 51,770 -> 51,249 (-1.01%) |
| reymont | 23.73 | 25.62 | 1.080 | 37,453 -> 37,011 (-1.18%) |
| samba | 36.49 | 36.03 | 0.987 | 49,546 (unchanged) |
| sao | 25.78 | 26.11 | 1.013 | 99,460 (unchanged) |
| webster | 32.21 | 34.82 | 1.081 | 42,288 -> 42,124 (-0.39%) |
| xml | 129.60 | 126.97 | 0.980 | 10,233 (unchanged) |
| x-ray | 32.99 | 32.97 | 0.999 | 94,246 (unchanged) |

Geometric mean **1.0313x** speed, **-0.28%** size; worst row xml 0.980x,
which is the control floor.

Six 1 MiB prefixes (`--iterations 10 --rounds 3`) confirm the routing on
larger inputs: geometric mean **1.0716x** speed, **-0.45%** size.

| case | before MiB/s | after MiB/s | speed | bytes |
| --- | ---: | ---: | ---: | ---: |
| dickens | 21.69 | 28.17 | 1.299 | 393,959 -> 390,423 (-0.90%) |
| xml | 64.31 | 64.83 | 1.008 | 155,748 (unchanged) |
| mozilla | 46.58 | 46.75 | 1.004 | 672,602 (unchanged) |
| nci | 84.10 | 84.37 | 1.003 | 106,657 (unchanged) |
| webster | 34.24 | 38.43 | 1.122 | 306,222 -> 304,853 (-0.45%) |
| reymont | 24.30 | 24.87 | 1.023 | 294,146 -> 290,243 (-1.33%) |

## Golden surface

An always-on experiment (before scoping through the option) changed wires for
every heap-lazy caller and failed exactly three tests: two Brotli ratio-planner
tests (Brotli shares `lz77.lazyGreedyPlanAlloc`) and the lz77 u32-versus-isize
differential. No deflate wire golden failed in either configuration. The
option keeps Brotli and default-option callers on the historical parser, and
the full `test check check-wasm` matrix passes (389/389 steps,
5775/5777 tests, 2 skipped).

## Measurement

- Host Intel i7-10700K, Linux 6.8, Zig 0.16.0 ReleaseFast, `skylake+pku+sgx`,
  single thread; zlib 1.2.11 and libdeflate 1.10 references in every row.
- `run-deflate-encode-bench`, level 6, one-shot, old/new binaries alternating
  per file in one session.

## Raw data

`prefix-128k-before.csv` / `prefix-128k-after.csv` and
`prefix-1m-before.csv` / `prefix-1m-after.csv` (schema of
`run-deflate-encode-bench`).

## Follow-up classifier screen (2026-11-22)

A variant required at least 70% distinct sampled 4-grams and widened the
average-best window to 3.5...16 bytes, aiming to route moderately repetitive
text (11...16-byte best matches) to the 4-byte chain while excluding RLE-like
blocks. An offline replication of both classifiers over the same middle 4 KiB
samples selected identical rows for all twelve 128 KiB and six 1 MiB prefixes:
`mr`/`nci`/`samba`/`xml` fail the distinctness bound (0.10/0.31/0.61/0.38) and
also exceed 16 bytes on average, while `sao`/`x-ray` stay below 3.5 bytes.
Since no measured row changes routing, the variant only adds an 8 KiB clear and
per-sample bit bookkeeping, so it was not adopted.

## Follow-up chain representation screen (2026-11-22)

Replacing the absolute `u32 prev[]` with a `u16` distance-delta ring (at most
65,536 slots, capped one past the window) preserves every reachable chain node
and all wires: a position-level differential over a 70 KiB mixed input
including ring wraparound matches the absolute walk exactly, and all 24
level-6/7 benchmark rows keep byte-identical output. It is not a win. Twelve
128 KiB prefixes at 50 iterations x 3 rounds measure **0.9753x** geometric-mean
speed at level 6 and **0.9593x** at level 7 (`reymont` 0.81x/0.81x,
`ooffice` 0.91x/0.87x, `webster` 0.96x/0.91x). The walk is bound by the
dependent next-node load, so inserting a subtract before that load costs more
latency than the quarter-size predecessor array saves. The absolute `u32`
chain stays.
