# Zstd FSE normalized-array content hit rate, 2026-11-14

Status: measurement only; production decode behavior unchanged. The new
`inspectNativeFrameNormalizedTableReuse` diagnostic and an extended
`fse_reuse_probe` are committed as test/diagnostic code, not hot-path logic.

## Method

Each compressed-mode LL/OF/ML sequence table is parsed with the production
`decodeFseNormalizedCounts` reader through a diagnostic-only frame walk. The
normalized-count array is hashed with XXH64, seeded with the table kind, and
compared against every earlier table in the same frame. A content hit means
the exact normalized distribution already appeared, which is the necessary
and sufficient precondition for reusing a built FSE table without its
memset/spread construction.

Inputs are the eight full-file Silesia frames (mozilla, sao, nci, xml at
levels 3 and 19) from the pinned 2026-11-14 decode matrix. Raw outputs in
this directory retain both the earlier mode counts and the new content
statistics.

## Results

| Fixture | Compressed tables | Unique signatures | Content hits | Hit rate |
| --- | ---: | ---: | ---: | ---: |
| mozilla L3 | 3502 | 3502 | 0 | 0.0000 |
| mozilla L19 | 5928 | 5848 | 80 | 0.0135 |
| sao L3 | 918 | 918 | 0 | 0.0000 |
| sao L19 | 336 | 336 | 0 | 0.0000 |
| nci L3 | 768 | 768 | 0 | 0.0000 |
| nci L19 | 677 | 677 | 0 | 0.0000 |
| xml L3 | 139 | 139 | 0 | 0.0000 |
| xml L19 | 168 | 168 | 0 | 0.0000 |

The only non-zero result is mozilla L19 at 1.35%, and even there 5,848 of
5,928 tables remain unique. Every level-3 fixture has a zero hit rate across
all three table kinds.

## Decision

A content-addressed retained FSE table cache is rejected as a performance
project for these workloads. The required lookup would execute on 100% of
the 6,508 compressed tables measured here, while eliminating at most 80
builds (1.35% of one fixture) and none on the level-3 rows that dominate the
current decode matrix. Cache bookkeeping would add cost to the exact
memset/memcpy setup region it intends to remove.

The observed memset/memcpy must instead be reduced inside the FSE builders
(`buildAssumeValid`, `buildMapped`, normalized-count parse workspaces) by
shrinking or reusing their local arrays, or by avoiding redundant fills that
the final entry construction overwrites. Any such change still needs the
paired 0.98x control floor and a full decode matrix before adoption.
