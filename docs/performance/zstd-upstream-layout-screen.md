# Zstd upstream-layout and reuse screens

Several performance ideas were screened after studying upstream Zstd
`01b7154f` and Vort's measured HQ transition profile. All prototypes preserved
wire bytes and settings, but none passed the pre-registered primary and
secondary throughput gates. They were therefore removed completely rather
than retained behind an option.

## Results

| Prototype | Primary ordinary time ratio | Secondary result | Decision |
| --- | ---: | ---: | --- |
| source-dominance pruning | weighted transition suppression `5.46%`; Mozilla btultra2 `2.89%` | below the `20%` / `10%` screen | reject before hot-path integration |
| packed 40-byte DP node | `1.061297` | Mozilla about `1.13x` | reject |
| padded 48-byte DP node | `1.081464` | worst `1.152958` | reject |
| open-address rep-length cache | `0.979634` | worst `1.007138` | below `0.97` gate |
| direct-map rep-length cache | `0.986175` | worst `0.993784` | below gate |
| seeded open-address cache | `0.980917` | worst `1.003894` | below gate |
| intra-call scratch reuse | `0.992692` | worst `1.003415` | too small |
| match frontier, 16-byte entries | `0.984025` | worst `0.998700` | below gate |
| match frontier plus rep cache | `0.971563` | worst `0.996506` | secondary required |
| compact 8-byte frontier plus cache | `0.975727` | worst `0.998874` | secondary required |
| 16 KiB plus trained-dictionary secondary | `0.995468` | worst `1.011483` | reject |

Ratios are candidate time divided by baseline time. The timing campaigns use
separate ReleaseFast executables, fixed CPU affinity, alternating order and
exact wire/settings checks. Mechanism counters are diagnostic; only ordinary
uninstrumented A/B timing determines retention.

## What the upstream study changed

The useful lesson is not that Vort should copy a smaller C struct. Upstream
Zstd's node layout is coupled to its single-state optimal parser, match store,
repcode representation and surrounding cache locality. Vort's richer state and
different traversal made a mechanically packed node slower even though it
reduced peak requested memory.

Likewise, reducing byte comparisons or rep probes is insufficient if the new
frontier has to be constructed, converted and replayed for only one or two
passes. The combined frontier/cache prototype approached the primary gate, but
the larger/dictionary workloads showed that its fixed setup cost did not
amortize. The next Zstd attempt should therefore change a larger invariant at
once: a native shared match store feeding all passes, or a structure-of-arrays
DP specialized to Vort's state, with the secondary corpus included from the
first experiment.

The archived evidence is in
[`data/zstd-upstream-layout-screen-20261029/`](data/zstd-upstream-layout-screen-20261029/).
No rejected Zstd source change remains in the working tree.
