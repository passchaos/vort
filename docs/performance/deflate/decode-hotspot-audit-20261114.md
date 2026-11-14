# Deflate 64 KiB slow-row hotspot audit, 2026-11-14

Status: diagnostic audit, no production source changed. Answers the direction
review's question: is the deflate 64 KiB gap (68.87% of libdeflate, weakest
row mr 64K L9 at 60.35%) driven by per-block setup or by the payload loop?

## Method

Pinned CPU 15, `perf record -F 997 -e cycles:u` and `instructions:u`, plus
`perf stat` PMU groups, against the current `vort-decode-compare` probe
(source `6f197a3a`, ReleaseFast skylake) with 2,000 iterations per side on
the frozen mr and mozilla 64 KiB level-9 wires. Reference is libdeflate
1.26 loaded dynamically; its samples appear in the same profile and are
excluded from Vort attribution.

## Symbol attribution (instruction-event profile, mr 64K L9)

| Symbol | Self weight | Role |
| --- | ---: | --- |
| `deflate.semantic.linear_entry.aligned` | 52.30% | semantic payload hot loop |
| `decodeRawAutoWithDictionaryFromReader` | 3.32% | block orchestration/tail |
| `SemanticDynamicDecoder.buildLiteralTable` | 2.41% | per-block Huffman setup |
| `buildDistanceTable` + `HuffmanTable.init` + memset/memcpy | ~1.0% | remaining setup |
| `Sha2x32.round` | 3.41% | probe provenance hashing, not decode |
| libdeflate `deflate_decompress_bmi2` | 36.74% | reference process samples |

Mozilla 64K L9 confirms the same shape: 51.78% in the linear loop, 1.43%
memset, 1.10% literal table build, 2.14% provenance SHA.

### Setup is not the bottleneck

All Huffman table construction plus table-init memset/memcpy totals roughly
3-4% of Vort samples on both corpora. The hypothesized setup-amortization or
table-retention design can address at most this share, and the existing
token probe shows each 64 KiB wire carries only a handful of dynamic blocks,
so reuse opportunities are limited even before measuring them. This closes
the deflate analogue of the zstd FSE-retention question without a prototype:
there is no large setup surface to remove.

## PMU characterization (2,000 iterations, both sides included)

| Metric | mr 64K L9 | mozilla 64K L9 |
| --- | ---: | ---: |
| IPC | 2.64 | 2.27 |
| Branch miss rate | 3.05% | 4.23% |
| L1 load miss rate | 2.68% | 1.90% |

Mozilla's lower IPC and higher branch-miss rate point at front-end/branch
pressure inside the semantic loop rather than memory stalls: L1 misses stay
under 3%. The loop function is 3,659 bytes of text with a 296-byte frame
(`sub $0x128`) and 273 memory-operand accesses, consistent with a large
inlined state machine whose branch layout dominates.

## Payload shape (existing token probe)

- mr 64K L9: 4,769 literals / 5,696 matches (45.6% literals); short lengths
  dominate (length 3-11 fill the top histogram), distances mostly <= 28.
- mozilla 64K L9: 7,446 literals / 4,671 matches (61.5% literals); similar
  short-length concentration with a longer-distance tail (24, 16, 100).

The hot loop already speculatively decodes four literal entries per
iteration and has dedicated rle1/rle258/non-overlap specializations, which
is why five earlier copy-loop prototypes could not move the aggregate: the
easy token shapes are handled.

## Conclusion and next decision

The deflate gap is **payload-loop bound, not setup bound**. A retention or
setup-amortization prototype is ruled out by the 3-4% ceiling. The remaining
lever is the semantic loop's branch/front-end behavior (mozilla 4.23%
branch misses, 2.27 IPC), but five prior loop-local prototypes already
failed the 0.98x floor, and this audit shows no new sub-surface inside the
loop that prior screens missed.

## Branch-miss localization

`perf record -e branch-misses:u` (2,000 iterations) attributes the misses by
symbol rather than by token class:

| Fixture | linear_entry.aligned | Next Vort symbol |
| --- | ---: | --- |
| mr 64K L9 | 63.94% | buildLiteralTable 0.94% |
| mozilla 64K L9 | 60.54% | decodeTailSymbol 0.24% |

Over 60% of all branch misses concentrate in the single 3.6 KB linear loop
on both corpora; no individual table-build or tail helper exceeds 1%. The
misses are spread across the loop's internal token-class branches rather
than pointing at one literal/match/distance tier, because no callee or
helper absorbs a meaningful share. This rules out a localized branch
specialization: there is no single mispredicting branch to remove.

## Decision

1. Do not open a deflate setup prototype (3-4% ceiling).
2. Do not open another token-class specialization: branch misses are
   diffuse inside the inlined loop, matching the five prior failed
   loop-local screens.
3. The only structurally different lever is a smaller, non-inlined loop
   core that reduces the front-end footprint (current text 3,659 bytes,
   296-byte frame). That is a high-risk rewrite with no precedent in the
   rejected screens, so it needs an explicit design and codegen-size
   evidence package before any A/B. It is recorded as a candidate, not
   started.

With the setup hypothesis closed and no localized loop hotspot available,
the deflate 64K gap is currently bounded by front-end saturation of the
existing inlined design. Further safe progress on decode throughput more
likely comes from the shared bit-reader mechanics (used by all three
codecs) than from another deflate-specific edit.
