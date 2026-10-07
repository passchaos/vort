# x86-64 Brotli full-tier distance-ring commit fusion

Date: 2026-10-07. Baseline: `8af08866`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
local libbrotli 1.2.0-dev (`558fc647`).

## Scope and safety

The selected 129--256-literal-tree executor already decodes more than 99% of
explicit distances through its cached RFC context-three root. The helper used
to return both a distance and `update_ring`; the payload then handled static
dictionary selection before conditionally pushing the distance into the recent
ring. This left a hot returned flag and branch on every command even though
almost every in-window explicit distance updates the ring.

The new selected-full-tier helper takes the already required maximum history
distance and commits the ring itself. Implicit distance-zero commands still
reuse the newest entry without advancing it. Explicit short symbol zero also
keeps the ring unchanged. Nonzero short and regular distances advance the ring
only when they are at most the current maximum history distance; larger static
dictionary references deliberately do not. This matches upstream
`ProcessCommandsInternal`, which rolls the ring during distance decode and
compensates dictionary references before copying.

The specialization is compile-time selected only for the retained
UTF-8/direct-context full tier. Its mixed-context sibling remains byte-size
identical at `0x1698`, and the middle-tier function sizes are unchanged. The
selected instance grows from `0x14e6` to `0x1557`, while the paired section
grows from `0x3b2b` to `0x3b9b`; following custom sections move by 128 bytes,
so their source and clustered controls are measured explicitly.

## Performance

All processes use frozen frames and alternating baseline/candidate launch
order on CPU 2. Each process retains the best of five internal rounds. A
20-millisecond continuous `ps -C zig` monitor rejects a whole campaign if any
external Zig process appears; one initial 15-pair q9 campaign was discarded.

| Input | Pairs | Median | Geometric mean | Wins | Range |
| --- | ---: | ---: | ---: | ---: | ---: |
| roadmap q9 | 15 | 1.0036x | 1.0030x | 15/15 | 1.0003x--1.0058x |
| roadmap q5 | 15 | 1.0027x | 1.0027x | 13/15 | 0.9989x--1.0105x |

Same-process libbrotli comparisons provide an independent drift control. q9
improves by 1.0041x median / 1.0058x geometric after normalization, with 6/7
wins; candidate throughput reaches 0.7842x libbrotli at the median. q5 remains
positive raw at 1.0030x / 1.0035x but normalizes to a neutral 0.9997x median /
1.0001x geometric. Candidate q5 reaches 0.8023x libbrotli at the median. The
change narrows both exact rows but does not establish Brotli decode leadership.

Three non-target paths cover the shifted middle sections and the flat decoder:

| Control | Median | Geometric mean | Wins |
| --- | ---: | ---: | ---: |
| source q9 | 1.0043x | 1.0040x | 7/7 |
| source q5 | 1.0040x | 1.0037x | 7/7 |
| clustered q8 | 1.0005x | 1.0009x | 10/15 |

Their combined 29-pair geometric mean is 1.0023x. Because middle function
sizes are unchanged, their movement is attributed to the paired section's
128-byte downstream layout shift rather than to executed helper logic; the
claim here is therefore the measured production-binary result, not an isolated
instruction attribution.

Exact executable/section hashes, input/frame hashes, raw nanosecond samples,
monitoring metadata, and validation totals are in
[brotli-full-ring-commit-x86-20261007.json](data/brotli-full-ring-commit-x86-20261007.json).
The final documented source rebuild changes only the complete executable hash;
its ordinary text, read-only data, paired, wide10-auxiliary, and wide9 sections
are byte-identical to the measured candidate.

## Validation

- The direct oracle compares canonical, direct-context, and committed distance
  selection for copy lengths 2...9, exact bit progress, countdown state,
  recent-ring updates, and dictionary-distance non-updates.
- All 555 direct ReleaseFast Brotli tests pass.
- The upstream differential passes 7,056 generated one-shot cases, 7,056
  progressive cases, 1,401 fragmentation schedules, 64 high-tree truncations,
  and seven Large Window cases.
- The real-corpus differential passes 16/16 one-shot and 16/16 progressive
  cases across four required categories.
- Generic x86-64/AArch64 compilation, the 13-row reference gate, path smoke,
  all 1,701 project ReleaseFast tests, all 104 build-check steps, and CLI help
  pass.
