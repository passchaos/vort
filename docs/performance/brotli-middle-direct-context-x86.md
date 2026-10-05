# x86-64 Brotli middle-tier direct distance context

Date: 2026-10-06. Baseline: `23f8a9f2`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
local libbrotli 1.2.0-dev (`558fc647`).

## Scope and safety

The 65--128 literal-tree executor already caches the distance tree selected by
RFC distance context three. Its source-q9 profile has 47,701 context-three
symbols among 48,113 explicit distances (99.14%), but every explicit command
still computed `min(copy_len, 5) - 2` and compared that result with three.

The retained middle-only instance selects the cached tree directly when
`copy_len >= 5`; copy lengths two, three, and four index context-map entries
zero, one, and two. The common arm is marked likely. A compile-time option
keeps the canonical `distanceContext()` calculation in the single-tree,
paired full-tier, and 10-bit auxiliary executors, so this target optimization
does not add state or alter their machine code.

Brotli command copy lengths are at least two, and context three begins exactly
at length five. A direct oracle assigns a different tree to every context and
compares the canonical and direct policies for copy lengths 2...9, including
decoded distance, recent-distance ring, bit position, and countdown. Existing
tests also cover implicit distances, short-distance errors, long-code fallback,
and every truncated prepared-distance suffix.

The zero-postfix middle instance grows from `0x1472` to `0x1479` bytes and the
generic middle instance from `0x1482` to `0x1489`; the whole nine-bit section
grows from `0x58b2` to `0x58b9`. The ordinary `.text`, Large Window, paired
literal, and 10-bit auxiliary sections retain their addresses, sizes, and
bytes. The final source rebuild reproduces every measured hot section.

## Performance

The source-q9/q5 frames are the unchanged 141,001/147,580-byte libbrotli
outputs for the 1,726,567-byte source fixture. Decoder-only processes use 500
iterations; same-process Vort/libbrotli runs use 100. Launch order alternates
on CPU 2. Each pair has a 0.2-second continuous Zig-process monitor;
contaminated attempts are discarded and repeated.

| Input | Decoder-only median / geometric | Wins | Reference-normalized median / geometric | Candidate / libbrotli median / geometric |
| --- | ---: | ---: | ---: | ---: |
| source q9 | 1.0031x / 1.0028x | 10/15 | 1.0024x / 1.0061x | 0.7755x / 0.7774x |
| source q5 | 1.0024x / 1.0024x | 12/15 | 1.0044x / 1.0049x | 0.7695x / 0.7688x |

The gain is small but independently positive in both the longer decoder-only
campaign and the same-process reference normalization. It raises the exact
source rows slightly while leaving a roughly 22%--23% gap to libbrotli; this
is not broad Brotli decode leadership.

Three seven-pair non-target controls remain neutral as a group:

| Input | Median / geometric | Wins | Range |
| --- | ---: | ---: | ---: |
| roadmap q9 | 1.0002x / 1.0016x | 5/7 | 0.9985x--1.0074x |
| roadmap q5 | 0.9986x / 1.0009x | 3/7 | 0.9979x--1.0070x |
| clustered q8 | 0.9983x / 0.9997x | 3/7 | 0.9934x--1.0110x |

Their combined 21-pair geometric mean is `1.0007x`. The paired and full-tier
control sections are byte-identical, so these small mixed movements are the
measured host-noise band rather than changed-path regressions.

## Rejected adjacent candidates

- Testing command countdown before command block-type count grew the selected
  instance by 42 bytes and measured q9 at `0.9950x` median / `0.9967x`
  geometric (1/7 wins), and q5 at `0.9940x` / `0.9947x` (0/7). It was removed.
- Reordering the equivalent distance countdown checks shrank both middle
  instances by 16 bytes, but q9 measured `0.9977x` / `0.9978x` and q5
  `0.9968x` / `0.9977x`. Smaller code was still slower and was removed.
- Direct context selection without the likely layout shrank both middle
  instances by 16 bytes. Fifteen q9 pairs reached `1.0020x` geometrically,
  but q5 regressed to `0.9984x` with only 4/15 wins. The retained likely form
  trades 23 bytes per instance for consistent q9/q5 gains.

Exact hashes, raw timing observations, discarded-attempt counts, controls,
and validation totals are in
[brotli-middle-direct-context-x86-20261006.json](data/brotli-middle-direct-context-x86-20261006.json).

## Validation

- All 551 direct ReleaseFast Brotli tests pass, including direct-versus-
  canonical context selection across every copy-length context.
- The upstream differential passes 7,056 generated one-shot cases, 7,056
  progressive cases, 1,401 fragmentation schedules, 64 high-tree truncations,
  and seven Large Window cases.
- The real-corpus differential passes 16/16 one-shot and 16/16 progressive
  cases across four required categories.
- The 13-row libbrotli reference gate and three-row path smoke pass.
- The full project test suite, `zig build check -j2`, CLI help smoke, and
  AArch64 Linux ReleaseFast compilation pass.
