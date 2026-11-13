# Deflate distance primary-only flag screen, 2026-11-14

Status: rejected before full-matrix adoption. No production source changed;
the prototype lived on a temporary branch and was removed after the screen.

## Hypothesis

The token-distribution package (`token-distribution-20261114`) shows reymont,
mr and mozilla keep almost all distances within the eight-bit semantic primary
table. A `distance_primary_only` bool on `SemanticDynamicDecoder`, set while
building the distance table, could let the hot linear loop skip the
distance-secondary branch and its suffix staging for that common shape
without changing any descriptor layout or copy kernel.

## Prototype

- add `distance_primary_only: bool` to `SemanticDynamicDecoder`;
- set it true in `buildDistanceTable` when `table.max_bits <= 8`, false on
  the secondary-capable path;
- guard the existing secondary block with
  `if (!single_distance and !decoder.distance_primary_only)`.

Struct size stays 19,496 bytes before and after (the bool absorbs existing
tail padding), and the complete `zig test src/deflate.zig` suite passes.

## Twelve-row paired screen

Each row runs 200 iterations, four rounds and two warmup pairs on CPU 15
with the pinned libdeflate 1.26 reference, baseline/candidate medians from
the same probe invocation pattern as the decode matrix.

| Row | baseline/candidate |
| --- | ---: |
| reymont 64K L6 | 1.06256 |
| reymont 64K L9 | 1.01316 |
| nci 64K L6 | 0.92221 |
| nci 64K L9 | 0.87321 |
| mozilla 64K L6 | 1.04946 |
| mozilla 64K L9 | 1.05914 |
| mr 64K L6 | 1.04891 |
| mr 64K L9 | 1.04242 |
| xml 64K L6 | 0.88627 |
| xml 64K L9 | 0.85144 |
| samba 64K L6 | 1.00750 |
| samba 64K L9 | 1.02885 |

Geometric mean 0.984011 with four controls below the 0.98x floor (nci L6/L9
and xml L6/L9). A second run reproduces the nci/xml regressions, so they are
not sampling noise.

## Why it fails

The short-distance fixtures gain 1..6%, but the extra conditional load and
the wrapped secondary block shift code layout enough to regress nci and xml
by 8..15%. nci uses long distances that always take the secondary path, so
its regression is pure layout/cost with no compensating skip; xml has short
distances but its loop balance also moves the wrong way. The flag trades one
branch for another without removing carried state, which the 2026-11-12
reader screens already identified as the actual requirement.

The evidence supports the token-package conclusion: a viable candidate must
remove state from the short match path unconditionally rather than add a
per-match discriminator. No A/B artifacts are committed; the archived
baseline binary SHA is
`66bc992521fba3c03c7444fa59f2bcedeed1e5da5ece6f20a4f1f04919447e6b`.
