# x86-64 caller-owned Brotli prefix construction

Date: 2026-10-12

## Motivation

The ReleaseFast compressed-header profile for the deterministic 1 MiB
`clustered_q8` stream measured about 80 microseconds per header, with complex
code-length RLE and canonical table construction as its largest substages.
Disassembly exposed a separate avoidable cost: every inline literal, command,
and distance prefix code returned a max-alphabet-sized table through an error
union before copying it into `MinimalCompressedHeader`. Complex trees then
returned another large temporary from `HuffmanTable.initSparseTrusted`.

The decoder now parses inline prefix codes directly into their final header
slots. `HuffmanTable.initSparseTrustedInto` likewise builds complex canonical
tables in caller-owned storage while the returning API remains available for
other users and packed overflow trees. The canonical code assignment, table
layout, validation, and error set are unchanged. On this target the
ReleaseFast `readMinimalCompressedHeaderInto` text shrinks from `0x684c` to
`0xde5` bytes because the large return/copy paths no longer remain in its hot
loop.

## Fixed-CPU results

Measurements used Zig 0.16.0 on an Intel Core i7-10700K, ReleaseFast binaries,
and `taskset -c 2`. Baseline was clean commit `b74ceedc`; process order reversed
on alternating pairs. All encoded sizes, iteration counts, and checksums were
identical.

The isolated header benchmark used 5,000 parses per process. Across seven
pairs, median time fell from 402,945,811 ns to 363,198,751 ns, a `1.1113x`
paired median speedup (`1.1090x` geometric mean, 7/7 wins, `1.0961x` minimum).

The end-to-end `clustered_q8` benchmark requested 10,000 iterations, whose
established divisor produces 1,000 timed decodes per process. Across eleven
pairs:

| metric | result |
| --- | ---: |
| baseline median | 1694.20 MiB/s |
| candidate median | 1715.08 MiB/s |
| paired median | 1.0122x |
| paired geometric mean | 1.0118x |
| wins | 11/11 |
| range | 1.0061x--1.0180x |

A seven-pair, 13-row control matrix requested 2,000 iterations per process.
The geometric mean across row medians was `1.0630x`; every ordinary compressed
row won all seven pairs, while the tiny and already-compressed random controls
remained neutral at their medians.

| row | paired median | wins |
| --- | ---: | ---: |
| text | 1.1246x | 7/7 |
| structured | 1.1256x | 7/7 |
| repetitive | 1.0888x | 7/7 |
| text_q3 | 1.0591x | 7/7 |
| structured_q3 | 1.0573x | 7/7 |
| repetitive_q3 | 1.0555x | 7/7 |
| structured_q4 | 1.0855x | 7/7 |
| text_q11 | 1.0570x | 7/7 |
| structured_q11 | 1.0968x | 7/7 |
| repetitive_q11 | 1.0661x | 7/7 |
| clustered_q8 | 1.0126x | 7/7 |
| tiny | 1.0000x | 3/7 |
| random4k | 0.9999x | 3/7 |

The post-change 13-row libbrotli 1.1.0 gate passed. Its single snapshot placed
`clustered_q8` at 1708.89 MiB/s and `0.8279x` reference throughput; that
reference ratio is recorded as a gate result, not a paired improvement claim.

## Correctness and rejected variants

The focused sparse-table tests compare dense, returning sparse, and
caller-owned sparse construction, including randomized tables and malformed
active sets. The libbrotli reference gate passed all 13 rows. The ReleaseSafe
upstream multi-block differential passed 98 format cases, 7,056 broad one-shot
decodes, 7,056 progressive decodes, 1,401 chunk-matrix runs, and 64 truncated
high-tree prefixes.

Two adjacent experiments were removed:

- A high-tree-only buffered literal-header reader was neutral end to end
  (`0.9991x` median, 5/11 wins). Its apparent header-only benefit came from a
  Debug profile and disappeared under the required ReleaseFast comparison.
- Extending caller-owned construction to simple two-to-four-symbol tables was
  also neutral (`0.9998x` median, `0.9997x` geometric mean, 4/11 wins), so the
  simpler established helper remains.
