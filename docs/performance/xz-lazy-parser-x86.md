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

The wide planner now preserves that length-gain rule and adds a gated static
LZMA price. The approximation counts literal-tree, length-tree, distance-slot,
and direct-distance bits over a common covered horizon; it deliberately does
not claim to model adaptive probabilities or repeat-distance state. Static
pricing is consulted only when the current distance exceeds 4 KiB and is at
least nine times the next distance. This short circuit avoids adding price work
to ordinary binary matches.

## Original same-layout evidence

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

This established that lazy parsing should remain an explicit ratio mode rather
than replace greedy. It also supplied the frozen length-only baseline for the
price follow-up.

## Static-price follow-up

The final candidate and the frozen length-only baseline are separate
executables. Fifteen alternating CPU-2 pairs compare them directly; every
executable also routes the same lazy row through greedy, so the normalized
column divides out each binary's own layout-sensitive control. Every
observation again contains three rounds of five complete allocating encodes.

| case | length-only → priced size | priced / old direct speed | normalized speed change | priced / greedy speed |
| --- | ---: | ---: | ---: | ---: |
| text256k | 268 → 268 | 1.0123x | 1.0325x | 0.9501x |
| json256k | 2,740 → 1,268 | 1.0276x | 1.0362x | 0.8880x |
| binary256k | 70,632 → 70,628 | 0.9991x | 1.0004x | 0.6968x |
| wide128k | 131,188 → 131,188 | 1.0019x | 1.0050x | 0.9996x |

The priced JSON result is 53.72% smaller than length-only lazy, 56.99%
smaller than greedy, and 10.70% smaller than liblzma 5.2.5 preset 1 on this
deterministic synthetic row. It runs at 0.812x liblzma throughput in the same
samples, so this is a ratio win rather than a blanket performance claim.
Binary is effectively neutral: four bytes smaller, 0.9991x direct speed, and
1.0004x after control normalization. Text and wide output remain unchanged.

Ungated static pricing was rejected despite producing 1,548 JSON bytes and
70,616 binary bytes: direct fixed-core comparison measured only 0.9720x and
0.9891x of the old lazy throughput. Requiring a current distance above 4 KiB
produced the best 1,268-byte JSON shape. Distance ratios eight and nine retained
that wire; ratio ten missed the useful cascade and regressed JSON to 2,876
bytes, so the stricter wire-equivalent ratio nine was selected.

Two lookahead caps were screened and removed. Limiting next-position searches
to current matches of at most 16 or 32 bytes improved JSON lazy/greedy speed to
`0.936x`/`0.930x` and binary to roughly `0.996x`, but both produced 2,888 JSON
bytes and 70,740 binary bytes. They lose 148 bytes of JSON savings versus full
lookahead; cap 32 is slower than cap 16 with identical output. The important
JSON decisions therefore begin above 32-byte current matches. The retained
distance gate supplies the required price-based pruning; a deeper
adaptive/optimal parser remains future ratio work.

## Validation

- Follow-up LZMA focused suite: 102/102.
- Follow-up XZ focused suite: 81/81.
- AArch64 Linux ReleaseFast static-price compile passes.
- Python/system-XZ differential includes a CLI lazy stream.
- The nine-row benchmark gate requires every lazy row not to exceed its greedy
  output size.
- The full repository test graph was not run.

Original lazy evidence remains in
[`xz-lazy-parser-x86-20261013.json`](data/xz-lazy-parser-x86-20261013.json).
The final baseline/candidate/control nanoseconds and price screens are retained
in
[`xz-static-price-x86-20261013.json`](data/xz-static-price-x86-20261013.json).
