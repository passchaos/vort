# Zstd encode current baseline, 2026-11-23

The archived 2026-10-25 encode matrix
(`docs/performance/current-codec-encode-x86-20261025.md`) contains
multi-second level-3 rows that no longer reproduce, so it cannot rank current
source. This refresh measures the committed encoder (`13db3afb`) against the
runtime libzstd 1.4.8 on a small, reproducible slice and profiles the worst
row to name the next target.

## Protocol

- Intel i7-10700K, Linux, Zig 0.16.0 `ReleaseFast`, one codec thread, no
  affinity pinning; libzstd 1.4.8 loaded from the system runtime.
- `run-zstd-encode-bench --path <file> --limit 65536 --level N
  --iterations 2 --rounds 3 --csv ...`; the default `internal-auto` selection
  is the public level policy, not a single forced strategy.
- Four Silesia 64 KiB prefixes (`dickens`, `mozilla`, `nci`, `x-ray`) at
  levels 1, 3 and 9. `matrix.csv` merges the twelve rows; the per-row files
  are the unmodified bench output.
- `vort_over_reference` is reference time divided by Vort time, so lower is
  slower Vort; `size_over_reference` is Vort bytes divided by reference bytes.

## Result

| case | level | Vort ms | libzstd ms | ref/Vort | size ratio |
| --- | ---: | ---: | ---: | ---: | ---: |
| dickens | 1 | 1.66 | 0.47 | 0.283 | 1.1014 |
| dickens | 3 | 6.18 | 0.80 | 0.130 | 1.0119 |
| dickens | 9 | 39.87 | 3.53 | 0.088 | 1.0069 |
| mozilla | 1 | 1.19 | 0.27 | 0.228 | 1.1077 |
| mozilla | 3 | 3.25 | 0.36 | 0.109 | 0.9349 |
| mozilla | 9 | 21.36 | 1.29 | 0.061 | 1.1533 |
| nci | 1 | 0.57 | 0.12 | 0.210 | 1.0370 |
| nci | 3 | 2.15 | 0.14 | 0.065 | 0.9777 |
| nci | 9 | 59.42 | 0.92 | 0.015 | 1.1008 |
| x-ray | 1 | 1.36 | 0.14 | 0.105 | 0.9927 |
| x-ray | 3 | 7.12 | 1.00 | 0.141 | 0.8949 |
| x-ray | 9 | 35.62 | 1.72 | 0.048 | 1.0037 |

Every row is far off the speed/ratio frontier: level 1 is 3.5--9.5x slower
with 1--11% larger output; level 3 is 7--15x slower with size mixed from
-10.5% (`x-ray`) to +1.2% (`dickens`); level 9 is 11--67x slower with size
from +0.4% (`x-ray`) to +15.3% (`mozilla`). The `nci` level-9 row (59.4 ms
versus 0.92 ms) is pathological on both axes.

## Profile of the worst row

`perf record -F 8000` over `nci.64k` level 9, five iterations (1752 samples),
top self-time symbols:

| symbol | share | note |
| --- | ---: | --- |
| `emitOptimalHashMatchCompressedBlockReuseWithSequenceScratch` | 25.43% | optimal-parse emission |
| `crypto.sha2.Sha2x32.round` | 12.82% | harness provenance, not encoder |
| `sequenceLiteralsPayloadSectionLen` | 10.93% | literal-section size estimate |
| `compiler_rt.memset` | 5.27% | table/plan clears |
| `memcpyFast` | 4.46% | copies |
| `huffman.packageMergeCodeLengths` | 3.65% | tree construction |
| `planRepeatSequenceCodes` | 3.53% | repeat-code planning |
| `lz77.matchLength` | 3.03% | match length extension |
| `findBestDuplicateMatchIn` | 2.69% | duplicate-match search |
| `MixedMatchCandidateCache.candidatesAt` | 1.77% | candidate lookup |
| `ZSTD_compressBlock_lazy2` | 1.21% | reference level-9 block loop |

After excluding the harness hash, the encoder is dominated by the optimal-parse
emitter plus repeated literal-section sizing. `sequenceLiteralsPayloadSectionLen`
builds a Huffman plan and serialized stream length for each candidate plan
(seven call sites in the encoder); losing candidates pay that construction and
the winner pays it again. The reference profile shows `lazy2` at level 9, so
the nominal level semantics already differ: Vort level 9 runs an optimal parse
while libzstd level 9 does not.

## Relation to prior work

This matrix is not a fresh regression report. The ledger already records that
levels 1--2 resolve to a `fast_compressed` primary (77 MiB/s at 128 KiB
`dickens`, 13--18% larger than libzstd 1.6.0), that the level-9 mixed search
was removed (25.6 s to about 0.25 s per 128 KiB encode), and that the optimal
DP's 16 ms is required for its winning block. Vort levels 3 and 9 therefore run
a quality ladder / optimal DP while libzstd 1.4.8 level 9 runs `lazy2`, so the
nominal-level table above cannot separate level-semantics differences from
implementation cost. Its value is the current, reproducible anchor and the new
profile below.

The new profile signal is that, after the mixed-search removal,
`sequenceLiteralsPayloadSectionLen` is now 10.93% of level-9 encode (excluding
the harness hash) because candidate plans rebuild the Huffman literal-section
length. That is candidate-cost waste, not required DP work, and it is the
concrete next target.

## Next

1. Compare at matched strategies or equal ratio before claiming a speed gap:
   run the reference with `--strategy`/HQ controls and Vort with the same
   search effort, then rank on the ratio/speed frontier rather than nominal
   level numbers.
2. Remove repeated candidate costing. A follow-up call-graph audit shows the
   intra-candidate threading is already implemented: the estimators
   `bestSequencePayloadLenWithLiteralEnds` (src/zstd.zig:28649),
   `bestTablePlanSequenceWithPreviousTables` (29375),
   `sequencePayloadLenWithTablePlans` (30698),
   `multiSequencePayloadLenInternal` (31472) and
   `rleSequencePayloadLenForValuesWithLiteralEnds` (31616) each compute
   `sequenceLiteralsPayloadSectionLen` once and pass the value into the
   existing `...WithLiteralsLen` variants for every table family. The 10.93%
   share is therefore the intrinsic exact Huffman-plan build for each of the
   hundreds of mixed-lookahead candidate parses, not a duplicated call. The
   real lever is a cheaper arbitration estimate (entropy/plan bound) with the
   exact section built only for the winning candidate, or fewer lookahead
   candidates; both change candidate selection and need wire-diff evidence,
   so they are a dedicated experiment rather than a refactor.
3. Re-run the full paired matrix (twelve files, 64 KiB and 1 MiB, alternating
   pairs, confidence intervals) before and after any change, with wire
   checksum and size checks, per the adoption bar in the performance
   architecture.

The 2026-10-25 note should not be used for current rankings; this package
replaces its level-3 rows for the measured slice.
