# Brotli contiguous auxiliary lookups

Date: 2026-09-29

## Motivation

The 1 MiB `clustered_q8` reference row is the only row in the 13-case Brotli
matrix that remains slower than local libbrotli 1.2.0. It contains 52 literal
context trees, three command block types, 17 distance context trees, 4,255
static-dictionary copies, and 12,563 LZ77 copies. A five-second Apple M1 Pro
sample placed most time in the high-tree payload executor and showed repeated
command/distance table access spread across the much larger canonical
`PrefixCode` objects.

The existing in-table tail lookups are compact individually, but consecutive
trees remain separated by the full canonical table stride. The high-tree
executor now prepares contiguous external root planes for the eligible command
and distance trees:

- command roots retain the proven 10-bit width and fused zero-extra command
  entries;
- distance roots retain the proven 9-bit width;
- root misses continue through the original canonical tree, preserving the
  malformed/truncated-input oracle;
- the route remains bounded by the existing inline command/distance tiers and
  falls back atomically when the command tables cannot support the 10-bit
  policy.

Mapped lookup construction applies command metadata fusion while filling each
root slot instead of scanning all 1,024 slots a second time. This keeps setup
cost proportional to the decoded tree entries and their replicated prefixes.

The same workload produces 30,349 bytes through static-dictionary commands.
The high-tree executor now sends each already materialized dictionary result
through a focused copy helper: lengths 4--31 use exact first/last 4-, 8-, or
16-byte loads and stores, while shorter and longer results retain `@memcpy`.
The helper neither reads nor writes beyond the supplied slices and has direct
coverage for every length from zero through 64 bytes.

## Performance evidence

The baseline is the clean pre-change `ef85a56d` checkout (whose latest Brotli
change is `f011dd5f`). Separate ReleaseFast binaries were alternated for 15
pairs on Apple M1 Pro. Each invocation encoded the deterministic q8 fixture,
verified both decoders, and measured 100 caller-buffer decodes in each of five
best-of rounds.

| metric | baseline | candidate |
| --- | ---: | ---: |
| paired median speedup | 1.0000x | 1.0563x |
| paired geometric-mean speedup | 1.0000x | 1.0584x |
| paired wins | - | 15 / 15 |
| paired range | - | 1.0439x--1.0796x |

A separate 13-row gate run measured `clustered_q8` at 1,608.99 MiB/s versus
1,868.02 MiB/s for libbrotli, or 0.8613x. The row is materially faster but is
still below parity, so broad Brotli decode leadership remains open.

The short default matrix is sensitive to macOS core placement at its current
iteration count. Longer isolated controls show the unchanged `text` route at
0.9994x median over 15 pairs, the tiny stored route at 1.0000x median over 15
pairs, and `structured_q11` at 1.0104x median over 21 pairs. All compared
checksums are identical.

## Correctness evidence

Focused tests cover mapped packed slots, fixed 9-bit external distance lookup,
external fused command decoding, and every short dictionary-copy length. The
13-row libbrotli reference gate passes. The upstream differential passes 99
core cases, 7,056 one-shot cases, 7,056 progressive cases, 1,401 fragmentation
runs, seven Large Window decode cases, and 64 high-tree truncation cases. The
seven-test real-corpus driver smoke also passes.

The repository-wide ReleaseFast `test` and `check` graphs were each observed
for five minutes without a failure, but neither reached a terminal result on
the loaded host, so they are not counted as passing evidence.

## Rejected follow-ups

The following independent-binary experiments were removed:

- replacing the existing fixed short match copy with an explicit vector move:
  0.9988x median, 0.9987x geometric mean, 6/15 wins;
- using a circular recent-distance ring: 0.9970x median, 0.9977x geometric
  mean, 6/15 wins;
- outlining static-dictionary address resolution: 0.9834x median, 0/15 wins;
- skipping countdown writes for single block types: 0.9981x median, 5/15 wins;
- widening literal roots from eight to nine bits: 0.9985x median, 6/15 wins;
- forcing 128-byte lookup alignment: 0.9998x median, 7/15 wins.

An error-branch layout experiment improved the target by less than one percent
but caused a repeatable tiny-input regression, so it was also removed. These
results leave the next useful target in the core command/distance execution
work rather than copy width, lookup alignment, or recent-distance layout.
