# Brotli incremental short-span copy threshold

## Hypothesis

A call-graph profile of the incremental Brotli decoder on `samba.64k.q6`
attributes 15.39% of samples to `copySpan`, and the annotated hot instructions
are the byte-by-byte loop in `copySpanScalar`: a load, two stores, two ring
index increments with wrap checks. That loop was used for every copy shorter
than 16 bytes.

`libbrotli` never runs a scalar loop for these short copies. Its decoder owns a
ring buffer with 32+ bytes of slack and unconditionally issues one 16-byte
`memmove16` first, even when the match length is one byte (`decode.c`,
`CommandPostWrapCopy` is only for wrapping or intersecting regions).

`vort`'s incremental decoder writes into a caller-owned output slice with no
slack, so a 16-byte overcopy is not legal. The vectorized path is still
available for spans that fit: it seeds from history with `@memcpy`, doubles the
output period, then commits the newest history-sized suffix once. The only
reason short spans were excluded was the fixed cost of that seed/commit pair
plus the ring index math, which was assumed to exceed a three-iteration byte
loop.

## Experiment

The threshold in `copySpan` was swept over the 48-row incremental screen
(12 Brotli files at q6/q11 and 64 KiB/1 MiB, four sweeps, 4096-byte output
chunks). Lower is faster, baseline is the committed `< 16` decoder
(`stream-current`, SHA-256
`d842e7611f5d4e65eb2d9e639b2cf009b6ff55d653dff1c552f6874af1d87bf3`).

| Threshold | q6 64 KiB | q6 1 MiB | q11 64 KiB | q11 1 MiB |
| --- | ---: | ---: | ---: | ---: |
| `< 16` (baseline) | 1.0000 | 1.0000 | 1.0000 | 1.0000 |
| `< 8` | 0.9810 | 0.9760 | 0.9905 | 0.9785 |
| `< 6` | 0.9714 | 0.9575 | 0.9707 | 0.9661 |
| `< 4` | 0.9530 | 0.9483 | 0.9604 | 0.9566 |
| `< 2` | 0.9581 | 0.9532 | 0.9760 | 0.9648 |

`< 4` is the optimum: four- and five-byte matches already amortize the
seed/commit pair, while one-to-three-byte spans (the Brotli minimum copy length
is two) still favor the single-pass scalar loop. The `< 2` variant sends
two-byte spans through the vectorized path and loses about 0.5–1.6% against
`< 4`.

The scalar loop was also reduced to one pass: it no longer updates the
two-byte `previous` window per byte and instead derives it from the final two
output bytes through the existing `updatePreviousFromSpan` helper. The adopted
candidate (`stream-span4b`, SHA-256
`b09f2b046e5f6b92a5bc724818c27a972ed6f47d15aa6955dd2195f7aa117bea`) measures
`0.9477/0.9490/0.9639/0.9549`.

Per-case medians for the adopted candidate span `0.8913` (`dickens.1m.q6`) to
`1.0136` (`x-ray.64k.q11`); text corpora gain 9–11% while the mostly binary
`x-ray` rows are within 1.4% of the baseline. The geometric mean of all 48
rows is about 0.954.

## Result

The threshold is `< 4` and the scalar loop is single-pass. A second four-sweep
screen of the final binary reproduces the gain
(`0.9477/0.9490/0.9639/0.9549`). The complete ReleaseFast Brotli suite passes
1504/1505 with one platform skip, and `zig build -j2 check` exits zero.

## Conclusion

Brotli's copy lengths are short often enough that the scalar byte loop was a
measurable cost. The vectorized seed/double/commit path is now used from four
bytes up, and the remaining one-to-three-byte spans keep the cheapest
single-pass loop. A `libbrotli`-style unconditional 16-byte overcopy remains
impossible for this API because the output slice is caller-owned.

Raw comparison files, records and binaries stay local under
`/tmp/vort-br-lookup-20261101/` (`stream-span4b-comparison.json`,
`stream-span4b-raw.json`, `stream-span8-comparison.json`,
`stream-span6-comparison.json`, `stream-span4-comparison.json`,
`stream-span2-comparison.json`).
