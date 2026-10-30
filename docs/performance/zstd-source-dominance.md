# Zstd cold btultra2 source dominance

Cold `btultra2` retains a width-16 repeat-history beam across two optimal
passes. Multiple live source nodes can have the same three repeat distances and
a positive literal length. For any fixed match edge, those nodes differ only by
their accumulated cost plus the literal-length symbol cost. The new selector
therefore materializes match/repeat edges from only the lowest-ranked source in
each exact repeat group, while preserving every node's literal transition.

The exact rank is:

```text
node.cost
+ ll_price[literal_symbol(node.literal_len)]
+ literal_extra_bits * 256
```

Zero-literal nodes remain independent because repeat selector semantics differ.
Equal rank keeps the lower original slot, matching the final DP tie-break.
Invalid literal lengths, rank overflow, or a source close enough to `u64.max`
that a later common sequence cost could overflow conservatively materialize the
whole group.

## Routing and density gate

This increment only changes `dp_reuse`, which is used by cold, prefix-free,
predefined-entropy `btultra2`. Ordinary `btopt`, `btultra`, dictionary/history,
initialized entropy, and finite `max_price_evaluations` retain their previous
paths and admission order.

Grouping has a fixed per-position cost. The first 256 already-produced matcher
frontiers are sampled without pruning. Dominance is enabled only when their
longest matches total at least 512 bytes, an average of two bytes per position.
This leaves low-density Dickens unchanged while enabling Mozilla/MR. The gate
is deterministic and does not inspect timing or allocator state.

Literal insertion, matcher search/record/replay, position order, and final wire
arbitration remain unchanged. The optimization allocates no heap memory and
does not increase requested peak.

## Correctness evidence

The selector tests cover `Node` and `WholeNode`, widths 1/8/16, exact/different
repeat histories, zero literals, rank ordering and ties, invalid LL symbols,
both overflow boundaries, sentinel truncation, and a small exhaustive `u128`
oracle.

Integration tests compare unpruned `dp.plan` against search, record, and replay
reuse plans by records, offset values, statistics, estimated cost, and final
repeats. They also prove:

- active dominance strictly reduces priced edges without changing the plan;
- a sparse first-256-position sample retains all previous work;
- finite price budget `N` succeeds with the old plan and `N-1` still returns
  `SearchLimitExceeded`.

The public HQ search differential passes 41 cases plus eight frozen wire rows.

## Ordinary A/B

Baseline is clean `88eebd7f`. Independent ReleaseFast executables ran on CPU 2
with eight alternating process sweeps and sixteen samples per side. Every row
preserves input, requested settings, complete Vort wire, and reference wire.

| Scope | Candidate / baseline | Paired wins | Price evaluations |
| --- | ---: | ---: | ---: |
| 4 KiB cold btultra2 geomean | `0.955568` | `16/24` | active rows decrease |
| 16 KiB cold btultra2 geomean | `0.991086` | `21/24` | active rows decrease |
| 4 KiB btopt control | `0.995348` | `16/24` | unchanged |
| trained dictionary control | `1.003633` | `2/8` | unchanged |

The strongest row is 4 KiB MR at `0.880413`, with price evaluations falling
from `1,207,314` to `908,899`. Low-density Dickens is gated off and remains
`0.997300 / 0.999423` at 4/16 KiB. Requested working-memory peaks are identical
on every row.

Evidence, exact inputs, runner, source overlay, differential report, commands,
and checksums are retained in
[`data/zstd-source-dominance-20261030/`](data/zstd-source-dominance-20261030/).
