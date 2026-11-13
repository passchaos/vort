# Brotli decode hotspot assessment, 2026-11-14

Status: diagnostic profile only; no production source changed. The evidence
selects the next optimization surface and records why the current Brotli
gap is the most tractable of the three codecs.

## Method

Fresh `perf record -F 199 -g -e cycles:u` on the slowest current matrix row,
mozilla full-file Brotli quality 11, using the pinned
`vort-decode-compare` probe (SHA
`66bc992521fba3c03c7444fa59f2bcedeed1e5da5ece6f20a4f1f04919447e6b`) and
libbrotli 1.2.0. 30 iterations, two warmup and two measured paired batches,
CPU 15 on the i7-10700K. The 2026-11-14 cold matrix puts this row at about
2.03x Vort/reference time.

## Symbol attribution (whole process, self weight)

| Symbol | Self % | Role |
| --- | ---: | --- |
| libbrotli `ProcessCommands` | 30.73 | reference kernel, not actionable |
| `processWideExternalLiteralLookupCompressedPayloadNative` | 23.25 | Vort literal lookup + command loop |
| `distancePrefixForDecode` | 10.19 | distance tree index/expand dispatch |
| `readMinimalDistance` | 8.01 | per-match distance context and decode |
| `readCommandSymbolAny` | 5.26 | command symbol decode |
| `commandPrefixForDecode` | 4.16 | command tree dispatch |
| `processExternalLiteralLookupCompressedPayload` | 2.98 | non-wide literal tier |
| compiler-rt memcpy | 2.35 | match copy tails |
| fast bit reader | 2.06 | reservoir fill/peek |

Vort-attributed hot work concentrates in three functions inside the wide
external-lookup payload path; the literal loop alone is 23% and the two
distance functions add another 18%.

## Structural observations

1. `processWideExternalLiteralLookupCompressedPayloadNative` already uses
   10-bit packed literal roots and fixed 9-bit auxiliary peeks. Its hottest
   instructions are the packed-entry decode and reader state writes, not a
   bit-at-a-time fallback, so widening the literal table again is unlikely to
   help and would repeat a previously rejected direction.
2. `distancePrefixForDecode` still performs an index bounds check, inline/
   packed tier selection and a possible `expand()` on every match. The
   auxiliary cached path (`readCachedTail9DistanceInto`) pins the four
   context trees for frames whose distance trees all fit the inline tier,
   but the generic mozilla q11 frame enters through `readMinimalDistance`
   and pays the dispatch cost each time.
3. The token shape from the Deflate study does not transfer directly, but
   the Brotli profile shows the same pattern: per-symbol dispatch and reader
   state bookkeeping dominate over the actual copy kernel (memcpy is only
   2.35%).
4. A viable Brotli candidate should extend the existing cached-distance
   mechanism to the generic wide payload path when all distance trees are
   inline and block types are stable, removing the per-match
   `distancePrefixForDecode` indirection without changing packed-tier
   frames or the literal lookup layout. That targets 18% of self samples
   while leaving the already-optimized 23% literal loop untouched.

## Current ranking context

The 2026-11-14 full cold matrix gives Vort/reference throughput of about
79%/86%/79% for Brotli at 64 KiB/1 MiB/full, versus 66%/70%/70% for Deflate
and 77%/75%/76% for Zstd. Brotli's 1 MiB gap (1.157x) is the smallest single
cell, and its hot functions are concentrated enough for a focused cached
dispatch experiment with clear pre/post perf symbols. Deflate's semantic
loop has already rejected descriptor, refill, owner-handoff and
primary-only-flag prototypes, so Brotli is the lower-risk next target.

No A/B was run in this step; the perf.data and run output remain under
`/tmp/vort-perf-20261114/brotli/`.
