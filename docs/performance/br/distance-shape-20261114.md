# Brotli distance plane shape evidence, 2026-11-14

Status: diagnostic increment only. Production decode paths are unchanged;
the new code is an opt-in field on the existing meta-block diagnostic plus a
standalone probe (`vort-br-distance-shape`). The evidence decides which
structural distance-decode candidates remain credible after the rejected
cached-tree and 9-bit-plane screens.

## Why this measurement exists

The mozilla full q11 profile attributes 10.19% self weight to
`distancePrefixForDecode` and 8.01% to `readMinimalDistance`. Two prior
candidates failed:

- 2026-11-12: stable nine-bit lookup planes for all command/distance trees
  (524 KiB of lookup storage) gave only ~1.05x on the cliff row and was not
  adopted;
- 2026-11-14: caching four resolved distance tree pointers gave parity with
  control rows below the 0.98x floor.

Before another structural attempt, the actual distance header shape on the
matrix corpora had to be quantified: how many context slots reach packed-tier
trees, how many distinct trees each block type selects, and what code widths
the referenced trees actually have.

## Method

`src/br/diagnostics/distance_shape.zig` captures, per compressed meta-block,
the four-context row of every distance block type plus per-referenced-tree
tier (inline index < 64 versus packed), single-symbol flag and maximum code
width. Capture runs through the public `diagnoseMetaBlocksAlloc` API with a
new opt-in `capture_distance_shape` option, after the ordinary production
execute and replay validation have already passed. The probe validates full
output against the plain bytes and emits JSON; no timers are involved.

The same diagnostic replay also fills a new
`MetaBlockStats.distance_context_histogram` (applied copies per context) so
the per-block JSON carries both header shape and decoded context frequency.
Schema v3 additionally reports, per referenced inline tree, whether its
entry array has room for an internal nine-bit tail lookup
(`canBuildTailLookup9`); packed-tier trees are excluded so the two space
counts reconcile exactly with the referenced inline tree count.

Fixtures are the frozen 64 KiB, 1 MiB and full-file producer wires from the
current decode matrix (twelve corpora, qualities 6 and 11, plus the mozilla
1 MiB q11 row; 49 frame runs). Raw per-block JSON and `aggregate.csv` are
retained beside this note. Every 64 KiB frame has a single compressed block
with zero packed context slots, while >9-bit trees still appear in 17 of the
24 small frames (up to 75% of referenced trees), so the width limitation is
not a large-frame artifact.

## Findings

### 1. Quality 11 never needs packed-tier distance expansion

Every q11 fixture has zero packed context slots: all referenced distance
trees fit the 64-entry inline tier. On the mozilla full q11 cliff row the
packed tier appears only inside wide10 generic blocks (146 of 1,924 context
slots, 7.6%; 72 of 481 block-type rows resolve context three to a packed
tree). Packed expansion is therefore a q6 phenomenon on this corpus
(mozilla 66%, samba 69%, mr 59% of context slots), not a q11 hot path.

Consequence: on the cliff row, `distancePrefixForDecode` always takes its
inline branch — one bounds check, one index multiply and one pointer store.
The expensive packed `expand()` seen in the disassembly is cold there, so
removing per-match dispatch cannot recover expansion cost on q11.

### 2. Most q11 distance trees are wider than nine bits

Share of referenced trees whose maximum code width exceeds nine bits:

| Fixture q11 | >9-bit trees | Fixture q6 | >9-bit trees |
| --- | ---: | --- | ---: |
| mr | 97.8% | x-ray | 100.0% |
| x-ray | 97.1% | webster | 95.0% |
| webster | 96.1% | reymont | 95.0% |
| reymont | 68.8% | mr | 87.1% |
| mozilla full | 67.6% | mozilla | 34.8% |
| samba | 64.4% | samba | 45.4% |

Mozilla full q11 references 534 distance trees, 361 of them (67.6%) with
max code width 10-15. A fixed nine-bit packed lookup plane returns null and
falls back to the canonical long-code scan for every symbol in those trees.
This is the structural reason the 2026-11-12 nine-bit-plane candidate could
not deliver: two thirds of the cliff row's trees cannot be covered by a
9-bit root, and widening to 15 bits would cost 256 KiB per tree plane, which
is infeasible for 534 trees.

### 3. q11 context maps genuinely use two to four trees per row

Distinct-tree histogram across all distance block-type rows (mozilla full
q11, 481 rows): 8 rows use one tree, 168 use two, 182 use three and 123 use
all four. Every other q11 corpus shows the same 2-4 tree spread; only q6
collapses to one tree per row uniformly. A single-tree fast path therefore
cannot cover q11 payloads, while it would cover q6 — but q6 is not the cliff
row and the cached-pointer screen already showed parity there.

### 4. Applied copies concentrate in context three, but not exclusively

The probe now also replays every applied copy through the summary path and
counts the four RFC 7932 contexts (copy length 2, 3, 4, 5+). Context-three
share across full-file fixtures:

| Fixture | q11 ctx3 | q6 ctx3 | Fixture | q11 ctx3 | q6 ctx3 |
| --- | ---: | ---: | --- | ---: | ---: |
| dickens | 99.1% | 99.8% | samba | 92.0% | 98.6% |
| mozilla | 70.7% | 87.8% | sao | 49.8% | 81.7% |
| mr | 95.7% | 98.8% | webster | 97.6% | 99.6% |
| nci | 92.3% | 98.4% | x-ray | 84.5% | 96.6% |
| ooffice | 63.9% | 85.6% | xml | 95.6% | 99.4% |
| osdb | 74.7% | 81.9% | | | |

On the mozilla full q11 cliff row the four contexts split 6.10% / 10.76% /
12.39% / 70.74% over 3,770,833 applied copies; the mozilla 1 MiB q11 row is
9.06% / 7.55% / 6.96% / 76.43%. On 64 KiB frames context three ranges from
31.9% (x-ray q11) to 93.5% (reymont q11). Context three is the dominant
single case, but a context-three-only fast kernel would still leave 30-50%
of copies on the generic path for the slowest rows (mozilla, sao, ooffice);
the existing auxiliary-tier optimization already special-cases this case
where it exceeds 99%. A structural kernel must therefore keep all four
contexts cheap rather than bet everything on context three.

### 5. What the hot inline dispatch actually costs

With packed expansion ruled out on q11, the surviving per-match sequence in
`readMinimalDistance` is: block-switch check, copy-length context
computation, context-map byte load, index bounds check, inline tree pointer
resolve, prepared-lookup decode, remaining decrement, then short/regular
distance staging and ring bookkeeping. The tree resolve itself is ~5
instructions. Caching the pointer (2026-11-14 screen) removed one load and
moved nothing else, producing parity with floor breaks; the measured 18%
combined surface lives in the surrounding state work, not the indirection.

## Design implications

1. A four-context fused nine-bit lookup plane is rejected on structural
   evidence: 67.6% of cliff-row trees exceed nine bits and q11 rows select
   2-4 distinct trees, so neither wider roots nor a single pinned tree can
   cover the work without multi-hundred-KiB planes.
2. The credible remaining direction must reduce the whole distance
   resolution sequence's carried state (block remaining, context map base,
   reader staging, ring update) rather than replace one pointer load. Any
   such candidate needs its own live-state/codegen audit and must keep
   packed-tier q6 frames on their existing fallback.
3. Context three is dominant (50-99%) but never exclusive on the slow rows
   (mozilla q11 leaves 29% on contexts 0-2). The next kernel must make all
   four contexts cheap; a context-three-only specialization cannot meet the
   0.98x control floor on mozilla/sao/ooffice where the other three contexts
   carry 30-50% of copies.

## Validation

- `zig build build-br-distance-shape test-br-distance-shape` passes, including
  option-parsing tests.
- `zig build test-br` passes (full Brotli suite, record-optimal object linked).
- The distance-shape unit test covers inline/packed tier split, distinct-tree
  histograms, single-symbol and width accounting; a separate summary test
  covers the new distance-context histogram and its null-stats no-op.
- The context histogram is populated only on summary/diagnostic replay;
  production payload decoders pass `stats = null` and pay no per-copy cost.
- Every probe run validated complete decoded output against the plain bytes.
- Raw JSON (schema `vort.brotli.distance-shape.v3`) for 49 frame runs
  (24 full-file, 24 64 KiB, one mozilla 1 MiB q11) and `aggregate.csv` are
  retained in `docs/performance/br/distance-shape-20261114/`. Every
  referenced inline tree across all runs has tail-nine table space; the
  binding lookup limitation is code width, not table space.
