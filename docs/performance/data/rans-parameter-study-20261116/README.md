# rANS parameter study (N and L), 2026-11-16

## What this is and is not

A deterministic, fixed-seed measurement of the two open native-entropy
parameters in `docs/formats/native-entropy-design.md` section 9:

- **N** — number of interleaved rANS lanes (`1, 2, 4, 8`);
- **L** — model normalization constant (`256, 1024, 4096, 16384, 65536`).

It measures **compressed size and framing overhead only**. It does **not**
measure decode throughput or instruction-level parallelism: the current
decoder runs lanes scalarly, so the ILP benefit that motivates interleaving
cannot appear until a parallel/SIMD executor exists. Any N-vs-throughput claim
must wait for that executor and the section-8 adoption gates.

Reproduce with:

```sh
zig build run-rans-parameter-study > parameter-study.csv
```

The tool (`tools/rans/parameter_study.zig`) asserts every one of the 300
configurations decodes back to the exact input, so it also serves as a
configuration-matrix smoke test. Distributions are synthetic and deterministic
(uniform, geometric-skew, binary-dominant, single-symbol, seeded mixed) over a
32-symbol alphabet at message lengths 16 / 256 / 4096. No external corpus is
used, so this is a parameter-behavior probe, not a competitive ratio claim.

## Findings

### 1. Precision L plateaus at 4096 for these alphabets

Renormalization bytes as L grows (4096 symbols, one lane):

| distribution | L=256 | L=1024 | L=4096 | L=16384 | L=65536 |
| --- | ---: | ---: | ---: | ---: | ---: |
| skewed  | 1841 | 1831 | 1830 | 1830 | 1830 |
| mixed   | 2361 | 2352 | 2351 | 2350 | 2350 |
| uniform | 2560 | 2560 | 2560 | 2560 | 2560 |

Widening L past 4096 gives no further ratio gain here, while enlarging the
lookup table (L entries). For a uniform distribution L is entirely neutral
because normalized frequencies are identical at every precision. This
empirically supports the design's tentative default L = 4096 as the knee.
Scope limit: only a 32-symbol alphabet was exercised; larger alphabets could
shift the knee and must be re-measured before freezing.

### 2. Interleaving N is nearly free for entropy, costs only fixed framing

Renorm bytes are essentially invariant across N (uniform 4096 stays exactly
2560 at every lane count), so splitting one rANS stream into N independent
lanes does not materially reduce coding efficiency. The price is a fixed
per-block frame section — N 4-byte states plus N+1 4-byte offsets:

| lanes N | frame bytes (states+offsets) |
| ---: | ---: |
| 1 | 12 |
| 2 | 20 |
| 4 | 36 |
| 8 | 68 |

This is a constant per block, independent of message length, so it is
negligible on large inputs but dominates tiny ones.

### 3. Small blocks are framing-bound, not entropy-bound

For a 16-symbol mixed block at L=4096, total size is 171-226 bytes while the
renorm payload is only 8-9 bytes: the 22-byte header and 128-byte 32-symbol
model table are the cost. A single-symbol block emits zero renorm bytes
(identity coding) and carries only framing, growing 38 -> 94 bytes as N goes
1 -> 8. This is evidence for the design's planned specialized small-payload
mode and model reuse across blocks, rather than paying full framing per small
block.

## Decision implications (for the later framing milestone, not a commitment)

- Keep **L = 4096** as the working default; do not widen to 16/64K without
  evidence from larger alphabets.
- Treat **N = 4** as a reasonable default whose cost is a constant 36-byte
  frame section; the choice should ultimately be justified by a measured ILP /
  throughput result from a parallel executor, not by ratio (ratio is flat).
- Plan a **small-payload path** so short blocks avoid the full header + model
  table cost.

All numbers here are ratio/overhead evidence under synthetic inputs. They do
not establish industry-best ratio or speed and must not be cited as such.
