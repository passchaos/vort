# Codec boundary check, 2026-11-24

This is a functional screen, not a performance result or a full conformance
claim. It covers raw Deflate, zlib, gzip, standard Zstd and Brotli on the
source after correcting incremental zlib tail completion.

A valid nine-byte zlib member decodes `A`; the following `78 00` is not a
member header. Libz 1.2.11 returned `A` and preserved both trailing bytes.
With concatenation and trailing data enabled, Vort previously returned
`.done` from `step` even when the cumulative exact output pledge was two bytes.
The regression test first failed with `.done` and one byte written, then
passed after the zlib tail branch checked the pledge before completion.
It covers direct gzip/zlib and auto detection, whole and split tails, both a
fulfilled and a short pledge, and exact committed progress.

```sh
zig build -j5 test-zlib-or-gzip-auto test-zlib-or-gzip-auto-x86 \
  test-zlib-or-gzip-auto-wasm test-deflate-incremental-relaxed \
  check-gzip-header-events run-zlib-or-gzip-auto-diff \
  run-codec-differential-fuzz --summary all -- --max-size=256
```

The bounded generated-wire screen used seed `8534165662193842810` and system
libz 1.2.11, libzstd 1.4.8 and libbrotli 1.0.9:

| Check | Count | Result |
| --- | ---: | --- |
| Valid generated wires | 2,584 | All round-trip, exact-size and external reference checks passed |
| Truncation comparisons | 62,432 | 61,888 both reject, 544 accept with equal output, no one-sided verdicts |
| Mutation comparisons | 97,894 | 20,817 both accept with equal output, 74,403 both reject, 2,674 one-sided |

Of the mutation observations, 2,660 were reference-only accepts and 14 were
Vort-only accepts in the Brotli bucket. They were not adjudicated in this
screen. No compared pair that both accepted disagreed on plaintext.

- Generated wire digest: `a0aa0970e844f2039eff114f41b9773612410da8b622b9a72e21d081cedfffe4`
- Mutation sequence digest: `c7298bf5b0693261144eeabf3f35b2f08629355051a8fd252de0de9ce2afdc4f`
