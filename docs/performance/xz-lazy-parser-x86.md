# x86-64 XZ lazy ratio mode

Date: 2026-10-13. Host: Intel Core i7-10700K, Linux x86-64, Zig 0.16.0,
ReleaseFast, CPU 2, one codec thread. Reference: runtime liblzma 5.2.5 easy
preset 1.

## Scope

XZ now exposes `encodeXzLazyAlloc`, `encodeXzLazyInto`, and
`encodeXzLazyAppend`. The default greedy APIs and `XzEncodeOptions` layout
remain unchanged. Incremental XZ uses an explicit `.parser = .lazy`, while
symbol-progressive LZMA-Alone incremental encoding rejects lazy mode because
it cannot safely decide one-byte lookahead without changing its streaming
contract.

Narrow dictionaries reuse the established dictionary-aware lazy planner.
Wide dictionaries add one-byte lookahead to the block-local streaming hash
state. Lazy code lives in dedicated LZMA/XZ text sections. A gain threshold of
one was selected: threshold two produced 2,868 JSON bytes, while threshold one
produced 2,740 and was slightly faster in the fixed-core screen.

## Same-layout evidence

The benchmark's `--lazy-control` option routes lazy rows through greedy inside
the same executable. Fifteen alternating CPU-2 pairs therefore measure parser
work rather than linker layout. Every observation contains three rounds of five
complete allocating encodes.

| case | greedy → lazy size | lazy / greedy median speed | geometric speed |
| --- | ---: | ---: | ---: |
| text256k | 268 → 268 | 0.9155x | 0.9133x |
| json256k | 2,948 → 2,740 | 0.8530x | 0.8560x |
| binary256k | 70,764 → 70,632 | 0.7034x | 0.7026x |
| wide128k | 131,188 → 131,188 | 0.9952x | 0.9947x |

This is an explicit ratio mode, not a default replacement. The JSON row cuts
size by 7.06% and still reaches 1.095x liblzma preset-1 throughput, but remains
1.930x its size. Binary gains only 0.19% size for a much larger speed cost;
text and the far-distance control do not shrink. Future ratio work needs
LZMA-aware price modeling or a deeper optimal parser rather than more
unconditional lookahead.

Two lookahead caps were screened and removed. Limiting next-position searches
to current matches of at most 16 or 32 bytes improved JSON lazy/greedy speed to
`0.936x`/`0.930x` and binary to roughly `0.996x`, but both produced 2,888 JSON
bytes and 70,740 binary bytes. They lose 148 bytes of JSON savings versus full
lookahead; cap 32 is slower than cap 16 with identical output. The important
JSON decisions therefore begin above 32-byte current matches, so a future speed
optimization needs price-based pruning rather than a length ceiling.

## Validation

- LZMA focused suite: 105/105.
- XZ focused suite: 115/115.
- AArch64 Linux ReleaseFast compile passes.
- Python/system-XZ differential includes a CLI lazy stream.
- The nine-row benchmark gate requires every lazy row not to exceed its greedy
  output size.
- The full repository test graph was not run.

Raw paired nanoseconds and the parameter screen are retained in
[`xz-lazy-parser-x86-20261013.json`](data/xz-lazy-parser-x86-20261013.json).
