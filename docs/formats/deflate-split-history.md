# Deflate split history

Fixed-Huffman, dynamic-Huffman and best-block split encoders use the same
bounded history planner, including the adaptive best-block encoder. At an
input offset `offset`, the available history is the suffix of the preset
dictionary followed by `input[0..offset]`, limited to the strategy's effective
LZ77 window. New DEFLATE block boundaries do not reset that window.

The planner first takes `min(offset, window_len)` bytes of previous input,
then fills the remaining history capacity from the dictionary's suffix. Once
previous input fills the window, the dictionary is completely evicted. This
calculation avoids adding the full dictionary length to a potentially large
input offset. Wrapper DICTID still identifies the caller's complete dictionary.

History and the current chunk form one parser view. When the history is
entirely in the input, that view borrows a contiguous slice. A residual
dictionary requires a temporary allocation of at most `window_len + chunk_len`
bytes. Only tokens covering the current chunk are emitted; the history prefix
is removed, and a match crossing that boundary retains its original distance.
A remaining match of one or two bytes becomes literals.

This preserves the selected hash, lazy or optimal parser and makes candidates
crossing the dictionary/input seam available. Strategy normalization still
applies: RLE uses a distance-one window and Huffman-only emits literals.
Adaptive candidate scoring and emission use this same view. Output bytes and
block choices can change as previously unavailable matches become eligible.

The independent interoperability entrypoint is:

```sh
zig build -j2 run-deflate-split-history-interop -Doptimize=ReleaseFast
```

It checks raw and zlib wrappers through fixed, dynamic, best and adaptive split
APIs, plus gzip on fixtures without preset dictionary bytes. Fixtures cover
previous input, a residual dictionary larger than the
window, dictionary eviction, a 1 KiB matching window, empty dictionaries and
empty input. System libz decodes each wire with five-byte input fragments and
thirteen-byte output fragments, verifies dictionary requests, complete input
consumption, exact content and the output guard. Vort independently decodes
the same wires. `-Dzlib-ng-root=<path>` selects a zlib-compatible zlib-ng build
for the same checks.

The best-block entrypoints also restrict the whole-input sampled stored
shortcut to a single block without preset dictionary bytes. A random prefix
cannot rule out a later cross-block copy or a match in the preset dictionary.
Each emitted block can still independently select stored coding. One-shot raw
and zlib best-block encoders likewise search when a nonempty dictionary is
present.

## Functional comparison, 2026-11-06

The same `.default` options, 32 KiB window and 1 KiB split blocks were used
before and after the change. The before source is `d1507178`. These byte sizes
come from the deterministic fixtures in the interoperability tool, rather
than a general-purpose ratio benchmark.

| Raw DEFLATE fixture | Mode | Before | After |
| --- | --- | ---: | ---: |
| 4 KiB random data repeated twice | Fixed | 8,665 | 4,395 |
| Same | Dynamic | 8,576 | 4,384 |
| Same | Best | 8,232 | 4,179 |
| Same | Adaptive best | 8,197 | 4,159 |
| 1 KiB random data + 3 KiB from a 40,000-byte dictionary suffix | Fixed | 4,328 | 1,125 |
| Same | Dynamic | 4,298 | 1,151 |
| Same | Best | 4,116 | 1,075 |
| Same | Adaptive best | 1,114 | 1,071 |

System zlib 1.2.11 and Vort both decode all 56 generated streams, including
20 zlib dictionary requests. Size ceilings on the two fixtures above ensure
the interoperability gate verifies that the history is used, in addition to
verifying output correctness.

The full Deflate test module additionally checks token distances, seam and
straddling matches, parser/strategy behavior and allocation failure cleanup.
These are functional and interoperability checks; they do not establish
throughput or overall codec leadership.

Validation with Zig 0.16.0: `zig test src/deflate.zig -lc` passes all 626
tests in Debug. `zig build -j8 check` passes 213 build steps, including the
complete wasm32-wasi library. The Python zlib differential smoke passes 265
successful CLI calls and 60 expected failures; the CLI help smoke also passes.
