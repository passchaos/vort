# Zstd mixed-search level policy

Date: 2026-11-10.

Status: **rejected default policy**. The 95-state shortcut was removed after
the full repository gate found a default CHD wire regression: the frozen
level-6 image grew from 312 to 313 bytes. `controls.resolve` again uses the
original budgets (4: 96, 5: 128, 6-22: 96). The measurements below describe
the rejected screen, not the current default or a supported performance win.

## Problem

The public auto level policy enabled the recursive mixed-family lookahead
search for every level whose `match_search_budget` reached 96:

```zig
if (match_search_budget >= mixed_match_min_search_budget) { ... }
```

At levels 4-22 the auto level policy used budgets 96/128/96, so every 64 KiB
and 128 KiB block paid for the recursive search. A call-graph profile of a
64 KiB dickens level-4 encode attributed about 93% of the work to
`searchMixedCandidateLookaheadPlans`; the top self-time was
`sequenceLiteralsPayloadSectionLen` at 83%, which rebuilds the exact Huffman
literal plan for each candidate path. The same shape dominated 1 MiB inputs
and levels 9/19.

## Rejected change

The screened auto levels 4 through 22 resolved to `match_search_budget = 95`,
one state below the mixed search threshold. This skips the recursive mixed
candidate while retaining nearly the complete non-mixed beam budget. The mixed
planner itself is unchanged and remains available whenever a caller explicitly
requests a budget at or above 96. Explicit HQ strategies replace this budget
with the legacy sentinel and still enable the mixed planner when requested.

The screen's policy tests asserted that auto levels defer the mixed search.
Those expectations have been restored to the legacy schedule, together with
the existing CHD positive-level golden and additional core wire regressions.

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

Emitted sizes are equal on all twelve reported rows. The two largest cliffs are
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

### Levels 9 and 19, 64 KiB Silesia

| Level / source | Size (budget 96) | Size (budget 95) | Time 96 | Time 95 | Speedup |
| --- | ---: | ---: | ---: | ---: | ---: |
| 9 dickens | 25,513 | 25,513 | 660.5 ms | 28.2 ms | 23.4x |
| 9 mozilla | 9,946 | 9,946 | 279.9 ms | 77.7 ms | 3.6x |
| 9 samba | 18,890 | 18,890 | 153.9 ms | 10.4 ms | 14.7x |
| 19 dickens | 25,513 | 25,513 | 668.4 ms | 28.6 ms | 23.4x |
| 19 mozilla | 9,946 | 9,946 | 284.7 ms | 78.2 ms | 3.6x |
| 19 samba | 18,890 | 18,890 | 151.5 ms | 10.4 ms | 14.6x |

All twelve reported Silesia sources keep equal emitted sizes at both levels. The
remaining rows are unchanged or within noise. Level 9 and level 19 auto also
produce the same Vort size on every row, confirming that the auto path is not
selecting an HQ strategy at level 19.

## Follow-up

The auto level 19 wire is still larger than libzstd 1.4.8 on several rows
(dickens 25,513 versus 24,214; nci 5,248 versus 4,164). Explicit HQ strategies
close much of that gap on the same 12-file 64 KiB matrix:

| Strategy at level 19 | Smaller rows | Size range vs auto | Time range |
| --- | ---: | ---: | ---: |
| `btopt` | 12/12 | -0.5% to -13.1% | 9.4-65.3 ms |
| `btultra2` | 12/12 | -0.4% to -16.0% | 18.1-142.3 ms |

`btultra2` matches or beats libzstd on mozilla (8,351 vs 8,503), x-ray (44,624
vs 45,366), xml (4,329 vs 4,348) and sao (47,760 vs 47,760).

A silent default mapping of levels 19-22 onto `btultra2` was evaluated and
rejected: it breaks the frozen legacy level wires in
`controls_tests.expectLegacy` and the HQ search "unchanged default level paths"
contract, and `ratio levels accept decisive wide primary frame` fails with
`InvalidBlockPlan` under the HQ validation path. The legacy auto level wires are
a compatibility contract; offering HQ by default needs a versioned or explicit
opt-in policy, not a silent default switch. The explicit `strategy`/`hq`
controls remain the supported HQ route.

mozilla 1 MiB remains slow at levels 3/4 (about 1.0-1.9 s) after the mixed
search is skipped, so its non-mixed match/search path needs its own profile.
Removing the redundant `frequencies` zero-initialization in
`sequenceLiteralsPayloadSectionLenFromHistogram` was measured and reverted:
mozilla 1 MiB level 4 stayed at 1.87 s and dickens 64 KiB moved 32.5 -> 31.5 ms
(noise). The remaining hotspot is the repeated Huffman code-length build
(`treeCodeLengthsDenseKnownActive`), not that memset.

The screen proposed a level-policy performance change. Broader corpora and
explicit-HQ levels still need matched ratio/throughput validation.

That proposed acceptance was contradicted by the CHD consumer. Its fixture is
7,296 bytes of 57-byte periodic text, split into two 4,096-byte hunks; the tail
contains 3,200 data bytes and 896 zero-padding bytes. At budget 96 the mixed
candidate participates in actual wire-length arbitration. Budget 95 omits it
and produces the larger image. The historical golden was introduced in
`250d4d01`, and `docs/formats/chd.md` explicitly promises to retain default
level 6's old wire. Its 312-byte SHA-256 remains
`83a22f50cd79ece1478d23c96ef5fade3d6917d4a4285356de73cb9f54e4dabf`.

Future removal of mixed search needs an input-level dominance proof, together
with positive and negative controls across small/padded hunks and the public
adaptive boundaries. Equal sizes on a finite corpus do not justify deleting a
winning default candidate. Explicit native budgets below 96 remain available
for callers choosing that separate search policy.

## Validation

Historical screen validation (insufficient for acceptance):

- `zig test src/zstd.zig --test-filter "level"`: 68/68 tests.
- `zig build test-zstd`: exit 0 over the complete 1,399-test suite.
- Policy tests updated: auto levels defer the mixed search, explicit budgets
  still enable it, and the HQ controls test records the new 95 budgets.
- `run-zstd-encode-bench` matrices above.

The subsequent full Debug gate on `28bbbe51` returned exit 1: root tests were
5,497 passed, two skipped and one failed out of 5,500. The sole failure was
`CHD signed Zstd levels preserve default positive wire` (312 expected,
313 actual). This negative whole-repository evidence supersedes the earlier
focused green checks.
