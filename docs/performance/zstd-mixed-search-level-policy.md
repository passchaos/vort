# Zstd mixed-search level policy

Date: 2026-11-10.

## Problem

The public auto level policy enabled the recursive mixed-family lookahead
search for every level whose `match_search_budget` reached 96:

```zig
if (match_search_budget >= mixed_match_min_search_budget) { ... }
```

At levels 4-8 the level policy used budgets 96/128/96, so every 64 KiB and
128 KiB block paid for the recursive search. A call-graph profile of a 64 KiB
dickens level-4 encode attributed about 93% of the work to
`searchMixedCandidateLookaheadPlans`; the top self-time was
`sequenceLiteralsPayloadSectionLen` at 83%, which rebuilds the exact Huffman
literal plan for each candidate path. The same shape dominated a 1 MiB input.

## Change

Levels 4-8 now resolve to `match_search_budget = 95`, one state below the mixed
search threshold. This skips the recursive mixed candidate while retaining
nearly the complete non-mixed beam budget. The mixed planner itself is
unchanged and remains available whenever a caller explicitly requests a budget
at or above 96. Levels 9+ keep their existing 96 budget and mixed-search
behavior; extending the policy there is a separate HQ-path decision.

The policy tests now assert that levels 1-4 defer the mixed search and level 9
still enables it. The HQ controls test records the new 95 budgets for levels
4-8.

## Evidence

All measurements use `run-zstd-encode-bench` with libzstd 1.4.8, ReleaseFast,
one iteration and one round, 64 KiB Silesia prefixes, and the default auto
level policy. Times are whole-encode nanoseconds from the benchmark; they are
trend evidence, not a dedicated performance-host ranking.

### 64 KiB Silesia, level 4

| Source | Size (budget 96) | Size (budget 95) | Time 96 | Time 95 | Speedup |
| --- | ---: | ---: | ---: | ---: | ---: |
| dickens | 25,513 | 25,513 | 659.6 ms | 32.5 ms | 20.3x |
| samba | 18,890 | 18,890 | 167.2 ms | 29.6 ms | 5.6x |
| mozilla | 9,946 | 9,946 | 1,259.6 ms | 1,044.1 ms | 1.2x |
| mr | 16,070 | 16,070 | 51.3 ms | 51.2 ms | 1.0x |
| nci | 5,248 | 5,248 | 59.0 ms | 59.0 ms | 1.0x |
| ooffice | 37,144 | 37,144 | 37.7 ms | 34.7 ms | 1.1x |
| osdb | 27,053 | 27,053 | 27.0 ms | 26.3 ms | 1.0x |
| reymont | 19,078 | 19,078 | 35.0 ms | 34.0 ms | 1.0x |
| sao | 48,874 | 48,874 | 31.7 ms | 30.3 ms | 1.0x |
| webster | 20,187 | 20,187 | 32.7 ms | 32.7 ms | 1.0x |
| x-ray | 50,671 | 50,671 | 18.8 ms | 18.6 ms | 1.0x |
| xml | 4,940 | 4,940 | 14.3 ms | 14.2 ms | 1.0x |

Sizes are byte-identical on all twelve rows. The two largest cliffs are
dickens and samba; the remaining rows are unchanged or within noise.

### 1 MiB Silesia, level 4

| Source | Size (budget 96) | Size (budget 95) | Time 96 | Time 95 | Speedup |
| --- | ---: | ---: | ---: | ---: | ---: |
| dickens | 398,015 | 398,015 | 28.28 s | 0.59 s | 47.9x |
| xml | 153,437 | 153,437 | 1.85 s | 0.46 s | 4.0x |

Level 3 produces the same two sizes at 0.33 s and 0.27 s, confirming that the
mixed search did not improve the selected wire on these inputs.

### Levels 5 and 6, 64 KiB

| Level / source | Size (old) | Size (95) | Time (old) | Time (95) | Speedup |
| --- | ---: | ---: | ---: | ---: | ---: |
| 5 dickens | 25,513 | 25,513 | 679.0 ms | 32.9 ms | 20.6x |
| 5 samba | 18,890 | 18,890 | 174.7 ms | 30.1 ms | 5.8x |
| 6 dickens | 25,513 | 25,513 | 665.6 ms | 26.2 ms | 25.4x |
| 6 samba | 18,890 | 18,890 | 241.5 ms | 100.7 ms | 2.4x |

The built-in 32 KiB text, JSON, binary, level3-tradeoff and multiblock cases
also produced identical sizes with and without the mixed search.

## Follow-up

Level 9+ auto still runs the mixed search and shows the same redundancy on the
same inputs: dickens 64 KiB level 9 and level 19 take about 1.98 s with the
mixed search versus 28.5 ms with a 64-state budget, at the identical 25,513
byte wire. Extending the skip to the auto HQ levels needs separate evidence
because explicit HQ strategies and their price/search schedules are a different
path.

This change is a level-policy performance fix, not a wire-format change or a
current competitor parity claim. Broader corpora and explicit-HQ levels still
need matched ratio/throughput validation.

## Validation

- `zig test src/zstd.zig --test-filter "level"`: 68/68 tests.
- `zig build test-zstd`: exit 0 over the complete 1,399-test suite.
- Policy tests updated: levels 1-4 defer the mixed search, level 9 keeps the
  96-state budget, and the HQ controls test records the new 95 budgets for
  levels 4-8.
- `run-zstd-encode-bench` matrices above.
