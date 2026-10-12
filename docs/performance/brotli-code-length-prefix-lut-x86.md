# x86-64 Brotli code-length static prefix lookup

Date: 2026-10-12. Baseline: `fd7c61a3`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
libbrotli 1.1.0 (`0x1000009`).

## Change

Brotli encodes the 18 code-length-code lengths with a fixed 2--4 bit prefix.
Vort previously read that prefix one bit at a time, performing two to four
availability checks and cursor updates per value. The decoder now mirrors the
reference implementation's static 16-entry nibble table: one padded four-bit
peek returns the value and exact width, one explicit availability check keeps
strict truncation semantics, and one staged cursor advance consumes the code.

An exhaustive focused test checks all 16 padded nibble values, exact bit
positions, and truncation one bit before every 2-, 3-, or 4-bit code. The
high-tree-count `clustered_q8` stream contains 63 complex prefix trees, so this
removes hundreds of checked one-bit operations per frame without altering
canonical table layout or the payload executor. The ReleaseFast
`readMinimalCompressedHeaderInto` instance remains `0xde5` bytes.

## Performance evidence

Independent baseline and candidate reference-benchmark executables alternated
on CPU 2. `clustered_q8` requested 10,000 iterations, whose established 10x
divisor gives 1,000 timed decodes per process. Across 15 pairs:

| metric | result |
| --- | ---: |
| baseline median | 1709.94 MiB/s |
| candidate median | 1732.63 MiB/s |
| paired median | 1.0109x |
| paired geometric mean | 1.0115x |
| wins | 15/15 |
| range | 1.0086x--1.0153x |

A seven-pair 13-row matrix has a `1.0089x` geometric mean across row medians.
The `text`, `structured`, and `repetitive` medians improve by
`1.0183x`/`1.0168x`/`1.0155x`; `clustered_q8` improves `1.0075x` with 7/7
wins. Tiny input remains neutral. The only sub-1 matrix median,
`repetitive_q11` at `0.9994x`, recovers to `1.0003x` over 15 longer
10,000-iteration pairs and is treated as neutral.

The ReleaseFast decode-stage profiler moved header time from roughly 87.7 to
80.2 microseconds per frame in its initial 1,000-iteration observation. That
isolated number is attribution only; retention is based on the complete-frame
paired evidence above.

## Correctness

- The exhaustive fixed-prefix oracle passes in ReleaseSafe.
- The 13-row libbrotli reference gate passes with identical decoded sizes and
  checksums.
- The ReleaseSafe upstream differential passes 98 core cases, 7,056 broad
  one-shot cases, 7,056 progressive cases, 1,401 fragmentation runs, and 64
  systematically truncated high-tree prefixes.

Four setup-fusion predecessors were measured and removed before this retained
change: all-family fusion (`0.9893x`), literal-only fusion (`1.0014x`, too
small/noisy), table-tail prebuild-and-copy (`0.9971x`), plus the three rejected
candidates already recorded by the stage-profile milestone. The static prefix
lookup succeeds because it reduces actual parser instructions without merging
large stack frames or expanding the hot payload executor.
