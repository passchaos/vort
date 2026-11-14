# Decode optimization direction review, 2026-11-14

Status: planning/evidence synthesis, no source change. After seven rejected
Brotli structural variants and the completed FSE reuse/content measurements,
this note selects the next work item from the actual gap and hotspot
evidence rather than starting another local layout edit.

## Current measured gap (2026-11-12 committed matrix)

Cold throughput Vort/reference by size, all 72 rows:

| Codec | 64 KiB | 1 MiB | Full | Weakest rows |
| --- | ---: | ---: | ---: | --- |
| deflate | 68.87% | 76.58% | 81.93% | mr 64K L9 60.35% |
| zstd | (same matrix) | 75-77% band | | mozilla 1M L3 59.91% |
| brotli | | 86.4% (1.157x) | 79-82% | full mozilla q11 48.46% |

## Exhausted and open surfaces by codec

### Brotli — local layout levers exhausted

Seven measured variants failed the 0.98x control floor or produced parity:
primary-only flag, cached tree dispatch, no-low builder fill, mapped memset,
semantic lookup planes, distance hot/cold call split, dictionary scratch
relocation. The unifying finding: payload stack frames hold genuinely live
state (reader reservoir, ring, output cursors); moving cold state out changes
layout and perturbs unrelated rows without helping the 95%-common steady
path. Remaining Brotli work would have to alter the reader/staging contract
itself, which is cross-cutting and higher risk.

### Zstd — table retention closed, copy kernel contested

- FSE block-reuse probe: level-3 frames have 0% wire-level repeat tables;
  the slowest row (mozilla 1M L3) rebuilds every sequence table.
- Content-addressed cache probe: 0% normalized-array hits on all L3 fixtures.
  Retention cannot remove the 14% combined memset/memcpy setup weight on the
  slow row, and hashing the normalized arrays would add cost to that path.
- The wider-wildcopy trials were already rejected, so the memcpy 7.24%
  surface has no accepted lever either.
- Net: zstd's two profiled hotspots both lack an evidence-backed candidate;
  starting work here means profiling a new sub-surface first.

### Deflate — largest relative gap, least-explored setup surface

Deflate has the worst 64 KiB ratio (68.87%) and the weakest single row
(mr 64K L9, 60.35%). Prior deflate work concentrated on the hot copy loop
(five rejected prototypes) and rolling-window state, but per-block
Huffman/inflate setup has not been audited at the depth just applied to
Brotli distance tables. Unlike zstd, no reuse measurement has ruled a
retention or setup-amortization design in or out yet, so there is still
unknown terrain rather than exhausted terrain.

## Decision

Pivot the next investigation to **deflate decode setup cost**:

1. Profile the mr/mozilla 64 KiB L9/L6 rows to attribute time between
   per-block Huffman table construction, bit-reader refill and the match
   copy loop, using the same pinned-CPU `perf record` workflow as the Brotli
   hotspot audit.
2. Measure whether Huffman code/table state recurs across blocks or inputs
   (the deflate analogue of the FSE reuse probe) before proposing any cache.
3. Only then decide between a setup-amortization prototype and accepting
   that the gap is copy-bound; do not edit the hot loop without fresh
   attribution.

This keeps work on the codec with the largest measured gap and an
unaudited surface, and avoids an eighth speculative Brotli layout change.
Brotli and zstd diagnostic instrumentation stays in place for later
cross-codec reader-staging work if the deflate audit points back to shared
bit-reader mechanics.
