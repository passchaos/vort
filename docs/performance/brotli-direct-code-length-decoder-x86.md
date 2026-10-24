# x86-64 direct Brotli code-length decoder construction

Date: 2026-10-12. Baseline: `c3ea0ce2`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
libbrotli 1.1.0 (`0x1000009`).

## Change

Every complex Brotli prefix tree first describes an 18-symbol code-length
alphabet whose maximum width is five bits. Vort previously built a generic
`HuffmanTable(18)`, then scanned that table again to build
`FastDecoder(18, 5)`. The new format-local builder validates the 1--5 bit
histogram, assigns canonical codes, reverses them for Brotli's LSB-first wire,
and fills the final 32 one-byte decode slots directly in one pass.

The single-symbol case remains on its existing zero-bit path. Multi-symbol
descriptions must cover the complete five-bit code space, matching the parser's
already-validated Kraft-space invariant. Decode still performs one padded
five-bit peek, checks the exact selected width against real input, and advances
only after that check, preserving malformed and truncated-stream behavior.

The two ReleaseFast complex-tree instances shrink from roughly
`0x14d2`/`0x159f` to `0x10cb`/`0x118d`; the outer
`readMinimalCompressedHeaderInto` instance stays `0xde5` bytes.

## Oracle coverage

The focused ReleaseSafe oracle compares the direct builder against the generic
canonical `HuffmanTable` plus `FastDecoder` for all 32 root slots and exact bit
progress. It covers hand-selected balanced, skewed, maximum-width, and sparse
trees, then exhausts every complete 1--5 bit length histogram that fits the
18-symbol alphabet. Three coprime symbol placements per histogram exercise
sparse holes and different canonical tie orders. Each hand-selected active
symbol is also truncated one bit before completion; oversubscribed and
incomplete descriptions retain `InvalidHuffmanCode`.

## Performance evidence

The ReleaseFast compressed-header profile moved uninstrumented isolated header
parse time from about 66.0 to 64.1 microseconds per frame. Its nested
code-length-header attribution fell from about 11.7 to 10.2 microseconds. These
numbers identify the mechanism; retention uses complete-frame pairs.

Independent baseline and candidate binaries alternated on CPU 2.
`clustered_q8` requested 10,000 iterations, yielding 1,000 timed decodes per
process after the established divisor. Across 15 pairs:

| metric | result |
| --- | ---: |
| baseline median | 1725.49 MiB/s |
| candidate median | 1746.54 MiB/s |
| paired median | 1.0105x |
| paired geometric mean | 1.0110x |
| wins | 15/15 |
| range | 1.0055x--1.0186x |

A seven-pair 13-row control matrix reaches `1.0267x` geometric mean across row
medians, with every row at or above `1.0003x`. All compressed rows win 7/7:

| row | paired median |
| --- | ---: |
| text | 1.0680x |
| structured | 1.0745x |
| repetitive | 1.0633x |
| text_q3 | 1.0137x |
| structured_q3 | 1.0192x |
| repetitive_q3 | 1.0205x |
| structured_q4 | 1.0269x |
| text_q11 | 1.0145x |
| structured_q11 | 1.0249x |
| repetitive_q11 | 1.0116x |
| clustered_q8 | 1.0081x |

Tiny and already-compressed random controls remain neutral-positive at their
medians. The post-change libbrotli gate snapshot records `clustered_q8` at
1737.71 MiB/s versus 2062.76 MiB/s (`0.8424x`); parity remains open.

## Validation

- Exhaustive direct-versus-generic lookup oracle passes in ReleaseSafe.
- The high-tree-count stage-profile gate and 13-row libbrotli reference gate
  pass with the locked 52/3/17 tree shape and identical checksums.
- The ReleaseSafe upstream differential passes 98 core cases, 7,056 broad
  one-shot cases, 7,056 progressive cases, 1,401 fragmentation runs, 64
  high-tree truncations, and seven Large Window decode cases.
