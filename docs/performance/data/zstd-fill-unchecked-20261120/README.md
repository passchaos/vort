# Zstd unchecked FSE transition fill screen, 2026-11-20

## Decision

The production fill kernel keeps its checked form. The unchecked variant was
byte-identical but neutral on level 1 and slower on level 3, so it was
reverted. The kernel is bound by the dependent `state_table[state_index]`
chain, not by the per-symbol range checks.

## Change

`src/zstd/sequence/large/transition.zig` gained a `fillAssumeValid` variant
with debug assertions in place of the six per-symbol range checks, used only
by the production direct-transition path. The checked `fill` remains the
oracle. The checks are provably redundant for tables built by
`buildFseCompressionTable` from planner-validated codes: codes never exceed
`max_symbol`, the table length is a power of two, and the transition low bits
are `next_state & (2^bits - 1)` with `2^bits <= table_size`.

## Measurement

Twelve 128 KiB Silesia prefixes, one-shot ReleaseFast, `--iterations 50
--rounds 3`, interleaved with libzstd 1.6.0, old/new binaries alternating per
file:

- Level 1: geometric-mean **1.0086x**, every wire byte-identical; worst rows
  sao 0.964x, x-ray 0.991x, nci 0.991x.
- Level 3: geometric-mean **0.9891x**, every wire byte-identical; worst rows
  nci 0.971x, mr 0.979x, xml 0.981x.

The fill kernel is about 5.1% of level-1 encode cycles. Removing its checks
does not move that cost, so the dependent FSE state load dominates. The next
lever is overlapping the literal/offset/match fills in one pass rather than
removing checks.

## Raw data

`l1-before.csv` / `l1-after.csv` and `l3-before.csv` / `l3-after.csv`
(schema of `run-zstd-encode-bench`).
