# Zstd per-position repeat match reuse: exploratory screens

Four diagnostic HQ encodes confirm substantial repeated match-length work
between beam states at the same position. Every original comparison still ran
in this diagnostic; the reported fractions attribute comparison counters,
not elapsed time. Exact outputs and complete profiles agree with pristine
`26d9eb062da7dedded4aa1e3b639d76a53192d4f` and the retained known wires.

| Input / strategy | Original rep probes | Distinct / repeated calls | Repeated fraction | Repeated bytes / full comparison bytes |
| --- | ---: | ---: | ---: | ---: |
| Dickens btopt | 96,324 | 29,476 / 66,848 | 69.40% | 65.38% |
| Dickens btultra2 | 382,551 | 76,074 / 306,477 | 80.11% | 77.72% |
| Mozilla btopt | 93,435 | 32,076 / 61,359 | 65.67% | 47.07% |
| Mozilla btultra2 | 376,295 | 94,590 / 281,705 | 74.86% | 57.14% |

Dickens's repeated calls return zero length about 92% of the time. Even those
calls can perform the original 32-byte vector comparison, so a cache must
retain zero-length results as valid values. Per-position distinct-distance
maxima are 11/15 for Dickens and 13/21 for Mozilla. The diagnostic did not
retain the full ordered distance stream and therefore does not predict a
particular direct-mapped cache's collision rate.

## Exact fixed-capacity cache experiments

Two private prototypes retain an immutable source and a 64-entry direct-mapped
array, initialized once per DP plan. Each 16-byte entry stores a nonzero
position tag, distance, maximum and exact length: 1024 bytes of fixed storage
without heap allocation. A full key match returns the recorded result; a miss
performs the original match-length routine. Collisions replace one entry and
only reduce reuse. Source, dictionary/history, parser pass and root call
lifetimes are isolated by constructing a new cache.

Each node still processes its original repeat choices and admitted lengths
in the original order. Price admission, insertion, spill continuation and
output are unchanged. Instrumentation explicitly changes work accounting:
`rep_probes` counts actual match-length calls, `rep_match_reuses` counts exact
reuse, and `byte_comparisons` counts only the work that runs. Old comparison
counts are never replayed. All other profile fields remain identical.

The first shape keeps a separate lookup call; the second inlines that small
lookup while retaining the match-length function on misses. Their separate
two-round CPU-2 AB/BA screens use the same current baseline binary, three
Silesia 4 KiB prefixes, btopt/btultra2, window log 15, checksum and ordinary
allocating API. Zig 0.16.0 LLVM ReleaseFast/Skylake is recorded. Input setup,
caller output release, decode and separate diagnostic encode are outside the
ordinary timer.

| Input / strategy | Outlined time ratio | Inline time ratio |
| --- | ---: | ---: |
| Dickens btopt | 1.0030 | 0.9974 |
| Dickens btultra2 | 1.3521 | 0.9763 |
| Mozilla btopt | 1.3199 | 0.9888 |
| Mozilla btultra2 | 0.9699 | 1.0245 |
| MR btopt | 1.0132 | 0.9936 |
| MR btultra2 | 1.0053 | 0.9439 |

Ratios divide median candidate time by median baseline time; raw per-round
times remain frozen. Outlined Dickens btultra2 and Mozilla btopt have large
first-round delays; their second rounds are much closer. Inline Mozilla
btultra2 is also mixed (1.0755/0.9735). The other inline changes are small,
and MR btultra2's larger aggregate gain includes a slower baseline first
round. These observations do not establish a general speedup. Neither shape
is adopted into production from these screens, and no favorable extra round
was added.

Each screen completes 24 ordinary encodes and 48 native decodes. Full wires
agree; profile fields outside actual probe/comparison/reuse work agree.
Independent libzstd 1.6.0 also decodes all 48 archived wire artifacts exactly.
For each pair, old `rep_probes` equals new probes plus reuses. The cache
reduces comparison counters substantially but the remaining state insertion
and transition work dominate ordinary throughput. Reducing counted bytes
alone is not evidence of improved encoder performance.

The [evidence package](data/zstd-rep-match-cache-screen-20261028/) preserves
the shared source, both exact prototypes, all inputs/wires/profiles, original
commands, identities and diagnostics. Its audit recomputes wire/profile
invariants, exact timing summaries and the diagnostic fractions. Continue
measuring state-key scanning and transition work before expanding caches;
the full ten-format functionality/performance objective remains active.

A frozen-DP and exact match-length contract suite is retained for later reuse.
Native Debug, ReleaseFast and actual x86 Debug each pass 22/22 checks. It
compares complete plans, states and all profile fields outside actual reuse
work; exercises cache collisions, maximum/position changes, zero matches,
fresh sources, null profiles and saturation; checks finite admission prefixes,
heap limits, dictionaries/history, both parsing layouts and complete modes;
and verifies four public known wires. The target-specific resource expectation
uses the frozen DP with the same target layout. The suite remains an archived
prototype validation and is not registered in the production source.
