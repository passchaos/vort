# x86-64 Brotli high-tree-count decode stages

Date: 2026-10-12. Baseline: `8c7b1f34`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, one codec thread. Reference encoder:
libbrotli 1.1.0 (`0x1000009`).

## Purpose

The existing compressed-header profiler attributes parsing and Huffman-table
construction, while the reference benchmark measures complete caller-owned
decode. Neither separated lookup preparation from payload execution. That left
two very different hypotheses—more header/setup work versus more command/copy
loop work—sharing one end-to-end number.

`run-br-decode-stage-profile` now freezes the deterministic 1 MiB
`clustered_q8` shape and times four stages independently:

1. compressed-header parsing and canonical tree construction;
2. 52 external eight-bit literal roots;
3. three fused ten-bit command roots plus 17 external nine-bit distance roots;
4. the selected flat multi-tree payload executor.

The diagnostic explicitly requires 52 literal trees, three command block
types, 17 distance trees, `NPOSTFIX=0`, and `NDIRECT=0`. It decodes through the
same production payload executor, verifies the complete output, and reports
the residual clock/accounting overhead. The gate locks the wire shape, stage
totals, shares, checksum, and libbrotli version without imposing unstable
timing floors.

## Initial result

A 1,000-iteration ReleaseFast run produced the following per-frame values:

| stage | time | share |
| --- | ---: | ---: |
| header parse / canonical tables | 87.7 us | 14.5% |
| literal-root setup | 10.3 us | 1.7% |
| command-root setup | 5.9 us | 1.0% |
| distance-root setup | 10.7 us | 1.8% |
| payload execution | 488.9 us | 81.0% |
| total | 603.7 us | 100% |

The prior 13-row reference gate measured `clustered_q8` at 1708.89 MiB/s and
`0.8279x` libbrotli throughput. At that ratio, libbrotli's entire frame costs
roughly the same order as Vort's isolated payload executor. The remaining
parity gap is therefore principally setup/header overhead; local branches in
the already optimized command/copy executor must clear a much higher evidence
bar.

## Rejected candidates

Three production candidates were measured during this investigation and
removed:

- A compile-time zero-postfix distance instance improved 15 long
  `clustered_q8` pairs by `1.0034x` median / `1.0035x` geometric mean with
  14/15 wins, but a seven-pair 13-row matrix regressed ordinary `text` and
  `structured` medians to `0.9954x` and `0.9976x`; the target itself was only
  `1.0003x` in that control matrix.
- Direct caller-owned construction for the six small block-switch trees shrank
  `readMinimalCompressedHeaderInto` from `0xde5` to `0xbf6` bytes, but 15 long
  target pairs measured `0.9974x` median / `0.9979x` geometric mean with only
  4/15 wins.
- Skipping the initial clear for complete external roots reduced one isolated
  lookup sample by roughly 2--3 microseconds, but complete decode measured
  `0.9973x` median / `0.9982x` geometric mean with only 4/15 wins.

These results reinforce the project rule that isolated setup improvements are
not retained without stable complete-frame evidence. All three implementations
were removed; only the measurement surface and gate remain.
