# DEFLATE compact predecessor and two-hop screen

This screen tested two wire-transparent physical layouts for the prepared
level-8/9 optimal predecessor chain. Both preserved exact candidate order,
budgets, tokens and output sizes, but both regressed ordinary execution and
were removed.

## Candidates

The production refinement boundary ends at 65,535 bytes, so positions
`0...65,534` fit in `u16` with `65,535` reserved as the empty sentinel.

1. The narrow candidate stored both hash heads and predecessor links as
   `u16`. This halves the predecessor array and reduces the temporary 32K-entry
   head from 128 to 64 KiB.
2. The two-hop candidate kept four bytes per position, packing the next two
   `u16` predecessors into one `u32`. It preserves the exact chain while
   loading one link word for every two candidates. Inputs of 65,536 bytes and
   above continued to use the established `u32` path.

Direct tests compared every packed iterator result with the established chain,
covered odd/even chain tails and the 65,535/65,536 boundary, and retained the
existing fixed/modeled token, statistics and OOM contracts.

## Ordinary A/B

The baseline is clean `f7750905`. Separate ReleaseFast executables ran on CPU
2 over all twelve Silesia 4/16/64 KiB prefixes; every output size tied.

| Candidate | All 36 | 4 KiB | 16 KiB | 64 KiB control | Worst |
| --- | ---: | ---: | ---: | ---: | ---: |
| `u16` head and predecessor | `1.033185` | `1.064616` | `1.041682` | `0.994502` | `1.110038` |
| `u16` head and packed two-hop `u32` predecessor | `1.020648` | `1.053227` | `1.012207` | `0.997324` | `1.076639` |

The packed candidate recovered part of the narrow-index loss, confirming that
pointer-load count matters, but not enough to offset narrow-coordinate
extension and iterator slot control. The strongest regressions remain on 4 KiB
inputs, where the predecessor table already fits comfortably in cache.

## Decision

No narrow index, packed link, iterator branch or dual-layout state remains in
`src/lz77.zig`. The result indicates that this parser is currently dominated
by candidate checks, match extension and DP updates rather than raw predecessor
bandwidth. Further transparent work should target those operations with
profiled batch/prefix or match-extension kernels, not another predecessor
packing variant.

Raw results and the packed-two-hop source overlay are retained in
[`data/deflate-compact-predecessor-screen-20261030/`](data/deflate-compact-predecessor-screen-20261030/).
