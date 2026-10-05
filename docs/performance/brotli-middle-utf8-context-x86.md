# x86-64 Brotli middle-tier UTF-8 context specialization

Date: 2026-10-06. Baseline: `d0ef2dc2`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
local libbrotli 1.2.0-dev (`558fc647`).

## Scope and safety

The frozen source q9/q5 streams decode 20,459/23,048 literal bytes, and every
one uses RFC UTF-8 literal context mode. The middle-tier executor nevertheless
carried a runtime `utf8_context_only` predicate through every literal and kept
the dynamic context mode live across literal block switches.

The meta-block wrapper now selects a compile-time UTF-8 instance only after
proving that every declared literal block type uses UTF-8 mode. That instance
calls the dedicated two-table UTF-8 classifier directly and lets LLVM remove
the dynamic mode branch and unused mode state. Mixed LSB6, MSB6, signed, and
UTF-8 streams retain the existing dynamic instance. The route is further
bounded by the established 65--128-tree auxiliary-lookup and zero-postfix
requirements, so compact, full-tier, and Large Window decoders keep their
previous behavior.

The selected payload shrinks from `0x1479` (5,241) to `0x12db` (4,827) bytes.
Retaining the generic fallback grows `.vort_br_wide_lookup9` from `0x58b9`
(22,713) to `0x6c1b` (27,675) bytes. The added instance shifts the Large
Window, paired-literal, 10-bit auxiliary, and 9-bit section addresses by 64
bytes while preserving the first three section sizes. Dedicated controls are
therefore required even though they do not execute the new instance.

## Performance

The source-q9/q5 frames remain 141,001/147,580 bytes for the 1,726,567-byte
source fixture. Decoder-only processes use 500 iterations and same-process
Vort/libbrotli comparisons use 100. Launch order alternates on CPU 2. Each
pair has a 0.2-second continuous Zig-process monitor; contaminated attempts
are discarded and repeated.

| Input | Decoder-only median / geometric | Wins | Range | libbrotli-normalized median / geometric | Candidate / libbrotli median / geometric |
| --- | ---: | ---: | ---: | ---: | ---: |
| source q9 | 1.0068x / 1.0073x | 15/15 | 1.0024x--1.0147x | 1.0066x / 1.0072x | 0.7793x / 0.7798x |
| source q5 | 1.0075x / 1.0081x | 15/15 | 1.0014x--1.0139x | 1.0075x / 1.0082x | 0.7727x / 0.7729x |

The independent protocols agree, and all 30 longer target pairs win. The
candidate still trails libbrotli by roughly 22%, so this remains a bounded
middle-tier gain rather than broad Brotli leadership.

Three seven-pair non-target controls cover the shifted code layout:

| Input | Median / geometric | Wins | Range |
| --- | ---: | ---: | ---: |
| roadmap q9 | 1.0017x / 1.0008x | 4/7 | 0.9958x--1.0045x |
| roadmap q5 | 0.9990x / 0.9994x | 3/7 | 0.9933x--1.0055x |
| clustered q8 | 0.9964x / 1.0015x | 3/7 | 0.9922x--1.0185x |

Their combined 21-pair geometric mean is `1.0006x`, and every row median
remains above the 0.99 control floor.

Exact executable hashes, raw nanosecond pairs, discarded attempts, code
shape, controls, and validation totals are in
[brotli-middle-utf8-context-x86-20261006.json](data/brotli-middle-utf8-context-x86-20261006.json).

## Validation

- All 551 direct ReleaseFast Brotli tests pass, including exhaustive clustered
  UTF-8 classifier equivalence across every byte pair.
- The upstream differential passes 7,056 generated one-shot cases, 7,056
  progressive cases, 1,401 fragmentation schedules, 64 high-tree truncations,
  and seven Large Window cases.
- The real-corpus differential passes 16/16 one-shot and 16/16 progressive
  cases across four required categories.
- The 13-row libbrotli reference gate and three-row path smoke pass.
- The full project test suite, `zig build check -j2`, CLI help smoke, and
  AArch64 Linux ReleaseFast compilation pass.
