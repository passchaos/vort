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

## Level policy audit (2026-11-23)

Source inspection of `applySpeedFirstLevelPolicy` (src/zstd.zig:10587) shows
the nominal levels are already aligned to the industry ladder: level 1 is
`fast_compressed` with the single-table fast parser, level 2 is `double_fast`
with budget 512, and level 3 is `greedy` with a 24-candidate budget. Level 3's
measured 7.7x gap therefore cannot be attributed to an optimal parse; the
remaining cost is the level-3 adaptive split ladder (full-frame candidates at
2/4 KiB format blocks) and/or the greedy parser itself. Profile level 3 before
changing the level-9 lookahead budget: the level-3 row is the larger practical
gap (7--15x at the most common default level) and its candidates are supposed
to be cheap.

## Level-3 profile (2026-11-23)

`perf record -F 8000` over `dickens.64k` level 3, twenty iterations (829
samples): after excluding the 26.92% harness SHA-256, the encode is dominated
by the controlled-search match finder — `zstd.match.controlled_search.findBest`
18.17%, `matchAt` 13.08% and `planReuse` 8.47% (about 54% of encoder samples
together). `emitLargeSequenceCompressedBlockWithStatePolicy` is 3.03%,
memset 3.16%, `emitLongHuffmanStream` 2.07%, and the reference's
`ZSTD_compressBlock_doubleFast` is 6.09%. The adaptive split ladder does not
appear as a separate hotspot; the cost is per-position candidate search with
the level-3 budget of 24 against the reference's two-hash double-fast matcher.
That matches the 7.7x gap without implicating emission or section sizing.

## Rejected: level-3 budget 24 to 12

Halving the level-3 controlled-search budget measured, over the same four
64 KiB files: dickens 6.18 -> 5.34 ms (1.16x) at +2.51% size, mozilla
3.25 -> 3.07 ms (1.06x) at +0.73%, x-ray 7.12 -> 6.63 ms (1.07x) at +0.16%,
nci 2.15 -> 2.13 ms (1.01x) at +4.87%. Roughly 7% geometric-mean speed for 2%
geometric-mean size is a bad trade against a 7.7x gap and repeats the existing
knee sweep's conclusion that lower budgets cost more size per unit of speed.
Reverted. The level-3 gap is per-candidate cost inside `findBest`/`matchAt`/
`planReuse`, not the number of candidates.

A follow-up micro-screen forced `matchAt` inline (the annotation showed about
15% of its self time in prologue, `ret` and `vzeroupper`). Level-3
`dickens.64k` measured 6.16 ms versus 6.18 ms with identical 27,477-byte
output, i.e. no effect, so call overhead is not the lever either. Reverted.

## Level-3 selection split (2026-11-23)

Forcing the fast primary with `--native-selection fast_compressed` at level 3
measures `dickens.64k` at 1.65 ms and 31,694 bytes versus 6.18 ms and 27,477
bytes for the default greedy ladder. The default therefore spends 3.7x time
for 13.3% smaller output, and the fast primary itself is still about 2.1x
slower than libzstd's double-fast level 3 (0.78 ms) at +15.3% size. The
level-3 gap is two separate targets: the ladder/greedy ratio spend, and a fast
primary that is roughly twice the reference's per-position cost.

## Next

1. Reduce the level-3 per-candidate cost in `controlled_search` (candidate
   generation, reuse planning, or duplicate checks) rather than the budget or
   call overhead. The flat annotation (top instruction 8.65% inside
   `findBest`, 10.19% inside `matchAt`) points at the candidate loop itself.
   Keep frame SHA/size checks and the full paired matrix. In parallel, the
   fast primary (`fast_compressed`) is 2.1x slower than double-fast and is the
   cheaper surface to optimize first because it has no ratio-ladder coupling.
2. Compare at matched strategies or equal ratio before claiming a speed gap:
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
   so they are a dedicated experiment rather than a refactor. The candidate
   budget is explicit: `mixed_match_path_search_budget = 512` (public
   `native_max_match_search_budget`), `mixed_match_min_search_budget = 96` and
   `adaptive_split_match_search_budget_max = 64` (src/zstd.zig:1579-1644), with
   the per-call value carried in `options.match_search_budget`. The first
   experiment should lower the level-9 budget (for example 512 to 256) and
   check frame sizes/SHA across the twelve 128 KiB Silesia files before a full
   paired campaign; the 128-to-2 multi-duplicate cap is the precedent for a
   budget cut with byte-identical output.
3. Re-run the full paired matrix (twelve files, 64 KiB and 1 MiB, alternating
   pairs, confidence intervals) before and after any change, with wire
   checksum and size checks, per the adoption bar in the performance
   architecture.

The 2026-10-25 note should not be used for current rankings; this package
replaces its level-3 rows for the measured slice.
