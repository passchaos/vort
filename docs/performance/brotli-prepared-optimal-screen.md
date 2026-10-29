# Brotli PreparedOptimal reuse screen

Vort's quality-10/11 encoder runs a fixed-cost seed parse, builds an entropy
model from its commands, and then runs a modeled refinement. Upstream Brotli
1.2.0 commit `558fc647cdaf391228d614ca85f711e02e4e583b` discovers H10 matches once
and reuses them for both Zopfli iterations. This screen tested whether Vort's
existing `lz77.PreparedOptimal` predecessor owner could provide the same class
of benefit without changing its Zig-native parser or complete-wire arbitration.

The answer is no for the current implementation. Four implementations retained
exact input, settings and wire identity, but none improved ordinary q10/q11
time relative to clean baseline `235779e4`. All production prototypes were
therefore removed.

## Three-way method

Each epoch used three independent ReleaseFast executables:

- `H`: clean `235779e4`, with two independently allocating parses.
- `L`: the candidate's helper and code layout, but reuse disabled.
- `R`: the same layout with real predecessor reuse enabled.

The screen covered Dickens, MR and NCI at 16 and 32 KiB for q10 and q11. Three
rotating process sweeps produced fifteen timed samples per side and case. The
reducer compared complete input, wire and settings signatures before accepting
timings. Ratios below one are faster.

| Variant | Resource lifetime | q10 R/H | q11 R/H | Combined R/H | R/L |
| --- | --- | ---: | ---: | ---: | ---: |
| Compact, retain all workspace | predecessor + DP + steps + tokens | `1.020850` | `1.010654` | `1.015739` | `1.009399` |
| Compact, release solve workspace | predecessor only between passes | `1.009024` | `1.001298` | `1.005154` | `1.003744` |
| Compact modeled path | both independent and reused modeled scans use `u32` links | `1.002785` | `1.001752` | `1.002269` | `0.973923` |
| Native, release solve workspace | shared `isize` predecessor only | `1.006238` | `1.015625` | `1.010920` | `1.011262` |

The third result is especially important. Reuse is 2.61% faster than its
matched compact-index layout control, but the layout control itself is 2.91%
slower than HEAD. Reuse merely recovers most of a regression and is still
0.23% slower overall. The native representation preserves baseline modeled
code shape more closely, but sharing it remains 1.09% slower than HEAD.

## Why the upstream principle did not transfer directly

`PreparedOptimal` only preserves the predecessor chain. Each solve still walks
the chains, repeats prefix checks and recomputes match lengths. Upstream Brotli
instead stores the bounded match list itself and feeds that evidence to both
DP iterations.

The lifetime also differs. Vort performs seed command construction, complete
wire encoding and entropy-model construction between its two solves. Retaining
the first solve's DP, step and token capacity across those stages caused clear
cache pressure. Releasing that storage reduced the regression, but saving one
index build was still insufficient to offset the reused traversal's code and
representation costs.

This is a useful negative boundary rather than evidence against reusable match
discovery. The next credible Brotli candidate is a bounded, exact match-evidence
cache that avoids the second chain walk and `matchLength` work. It must preserve
the existing candidate budgets, fixed prefix-bound semantics, ties and full
wire arbitration; a predecessor-only owner should not be retried.

Raw reductions, executable identities, the final native overlays and replay
script are retained in
[`data/brotli-prepared-optimal-screen-20261030/`](data/brotli-prepared-optimal-screen-20261030/).
