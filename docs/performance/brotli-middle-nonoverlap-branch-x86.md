# x86-64 Brotli middle-tier non-overlap branch layout

Date: 2026-10-02. Baseline: `a55145f8`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
local libbrotli 1.2.0-dev (`558fc647`), CMake Release (`-O3 -DNDEBUG`).

## Scope and evidence

The 65--128 literal-tree executor is the selected path for the frozen source
q9/q5 frames. Their public summaries report 48,751/52,136 LZ77 copies, of
which 48,689/52,021 are logically non-overlapping. After the existing fixed
short-copy routes, the remaining `len <= distance` branch is therefore still
overwhelmingly taken.

The retained change adds a likely hint to that branch in the middle-tier-only
`appendNonZero` entry point. It does not add a condition, alter a copy width,
change error ordering, or touch the generic and full-tier copy policies.
Generated code changes are confined to the three 9-bit middle-tier executor
instances. The selected source instance shrinks from `0x10a4` to `0x109e`
bytes; the complete `.vort_br_wide_lookup9` section shrinks from `0x42a6` to
`0x4269` bytes. Large Window, paired-literal, and 10-bit full-tier sections are
byte-identical.

## Performance

The frozen 1,726,567-byte source input has SHA-256
`b75cf6294797c217c0e4a17054a65c5e2d6a355529eccd65c7fd94c24f26fff0`.
Its q9/q5 frames are 141,001/147,580 bytes. Each decoder-only process uses 500
iterations; each reference process uses 100 iterations and measures Vort and
libbrotli in the same process. Both protocols reverse baseline/candidate
launch order across 15 pairs.

| Input | Decoder-only median / geometric | Wins | Reference-normalized geometric | Candidate/libbrotli median |
| --- | ---: | ---: | ---: | ---: |
| source q9 | 1.0042x / 1.0038x | 12/15 | 1.0035x | 0.7579x |
| source q5 | 1.0013x / 1.0022x | 11/15 | 1.0025x | 0.7505x |

The candidate remains substantially slower than libbrotli; this is a bounded
middle-tier improvement, not a claim of Brotli decode parity or leadership.

Long decoder-only controls keep the non-target tiers near neutral: roadmap q9
is 1.0045x geometric, roadmap q5 is 0.9988x, and clustered q8 is 1.0021x. A
15-pair complete 13-row reference matrix has a 0.9959x geometric mean across
raw row medians and 1.0013x after simultaneous libbrotli normalization. The
short rows remain scheduler-sensitive; their target executors are unchanged.

## Rejected adjacent candidates

- Replacing dynamic non-overlapping copies of 33--64 bytes with two exact
  32-byte vector moves regressed source q9/q5 to 0.9544x/0.9541x geometric
  throughput, both with 0/7 wins. The system memcpy lowering remains faster.
- Combining distance-zero and out-of-window detection into one unsigned range
  check regressed the middle tier to 0.9954x/0.9918x on source q9/q5. Applying
  the same change only to the full tier was inconclusive at 1.0012x roadmap q9
  and 0.9992x roadmap q5. Both variants were removed.

Exact executable hashes, timings, controls, and validation results are in
[brotli-middle-nonoverlap-branch-x86-20261002.json](data/brotli-middle-nonoverlap-branch-x86-20261002.json).

## Validation

- All five direct match-copy tests and all 549 ReleaseFast Brotli tests pass.
- The 13-row reference gate and path smoke pass against local libbrotli.
- The upstream differential passes 7,056 generated one-shot, 7,056
  progressive, 1,401 fragmentation, 64 high-tree truncation, and seven Large
  Window cases.
- The real-corpus differential passes 16/16 one-shot and 16/16 progressive
  cases.
- AArch64 ReleaseFast compilation, the full project test suite, the build
  check, and the CLI help smoke test pass.
