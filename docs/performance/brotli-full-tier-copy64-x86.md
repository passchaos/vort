# Brotli full-tier ordered match copies

Date: 2026-10-02. Baseline: `69629c66`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
local libbrotli 1.2.0-dev (`558fc647`), CMake Release (`-O3 -DNDEBUG`).

## Implementation boundary

The 129--256-literal-tree decoder now calls a dedicated match-copy policy on
x86-64. It preserves the established ordered 16-byte moves for lengths 1--32
and extends the fixed path through 64 bytes with at most four ordered 16-byte
moves. The generic decoder, the single-tree and 9-bit middle tiers, incremental
decoding, and every non-x86 target retain the previous helper.

The order is part of correctness. At distances 16--63, an earlier move may
initialize history consumed by a later move, while each individual 16-byte
`@memcpy` remains non-overlapping. Speculative tail stores are allowed only
when the complete 32- or 64-byte range is inside the current meta-block. Exact
tail copies, zero-length copies, and shorter writable suffixes use the old
paths.

The dedicated production payload grows from `0x1733` to `0x1767` bytes (52
bytes). The complete reference-benchmark executable grows by 176 bytes. A new
scalar replay oracle covers distances 1--64, lengths 0--64, and writable slack
at 0, 1, 15, 16, 31, 32, 47, 48, 63, and 64 bytes. It compares the complete
logical prefix, untouched caller suffix, progress count, and zero-length
behavior.

## Scope experiment

The first candidate changed the shared helper for every Brotli decoder. Seven
decoder-only pairs improved roadmap q5 by `1.0116x` median, but source q9 fell
to `0.9947x` median with 0/7 wins. That global route was removed. Restricting
the wider policy to the full literal-tree executor makes source q9/q5 and
clustered q8 neutral-positive:

| Control | Pairs won | Median | Geometric mean | Minimum |
| --- | ---: | ---: | ---: | ---: |
| source q9 | 4/7 | 1.0022x | 1.0029x | 0.9951x |
| source q5 | 5/7 | 1.0012x | 1.0049x | 0.9946x |
| clustered q8 | 4/7 | 1.0007x | 1.0022x | 0.9952x |

## Whole-frame measurements

The frozen 1,251,399-byte roadmap input is from commit `488c5415` and has
SHA-256 `f1da3a855bd2c0370e3cc1e3ac6894cd6de62243e8273e0278b7d8c8973f6ba9`.
Each process uses five warmed alternating Vort/libbrotli rounds. Baseline and
candidate process order reverses for each pair; every pair checks equal input,
encoded size, iteration count, and decoded checksum.

| Input | Pairs won | Median | Geometric mean | Reference-normalized geometric | Candidate/libbrotli median |
| --- | ---: | ---: | ---: | ---: | ---: |
| roadmap q9 | 9/15 | 1.0033x | 1.0029x | 1.0054x | 0.7498x |
| roadmap q5 | 6/7 | 1.0085x | 1.0075x | 1.0012x | 0.7627x |

This is a bounded, workload-specific gain. In particular, the q9 raw result
is small and noisy, and both target rows remain well below libbrotli. It does
not establish general Brotli decode parity or leadership.

## Validation

- `zig test src/br/match_copy.zig -OReleaseFast -mcpu=skylake`: 5/5 tests.
- `zig build test -j2`: passed.
- `zig build run-br-reference-bench-gate run-br-reference-bench-path-smoke -j2 -Dcpu=native`: 13 reference rows plus 3 valid and 5 rejected path cases passed.
- `zig build run-br-upstream-multiblock-diff run-br-real-corpus-diff -j2 -Doptimize=ReleaseFast`: 7,056 generated one-shot, 7,056 progressive, 1,401 fragmentation, 64 high-tree truncation, seven Large Window, and 16/16 real-corpus cases passed.
- `zig test src/br.zig -OReleaseFast -target aarch64-linux-gnu -fno-emit-bin`: passed.
- `zig build check -j2` and `zig build run -j2 -- --help`: passed.

Raw paired samples and executable hashes are retained in
[brotli-full-tier-copy64-x86-20261002.json](data/brotli-full-tier-copy64-x86-20261002.json).
