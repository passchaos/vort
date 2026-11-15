# Zstd FSE build optimization exploration, 2026-11-16

## Measurable baseline established

The Silesia corpus is present at
`/home/passchaos/Work/corpora/silesia-20261025`, so the zstd reference bench
is runnable. 64 KiB prefixes of the documented weak rows (`nci`, `xml`) at
level 19 give fast, profile-matched baselines (3000 iterations each):

| row | ref/Vort | Vort slower |
| --- | ---: | ---: |
| nci 64K L19 | 0.7056 | 1.417x |
| xml 64K L19 | 0.6816 | 1.467x |

CSVs: `baseline-nci.csv`, `baseline-xml.csv`. Re-run with
`zig build run-zstd-reference-bench -- --input <64K file> --level 19
--iterations 3000 --csv <out>`.

## FSE dense-run threshold: assessed, not changed

`fse_table.buildNoLowProbabilityAssumeValid` already has a packed dense-run
fast path gated at `probability >= 192` (src/zstd/sequence/large/fse_table.zig
208). Lowering that threshold to widen the fast path is the documented idea,
but:

- the FSE table build is only 9.53% of the weak-row profile, so even a large
  relative improvement there moves the whole decode by a low single-digit
  percent, unlikely to clear the 3% geomean adoption bar on its own;
- the dense path relies on contiguous mapped-state layout; extending it below
  192 requires proving the gap-scan/run layout holds for sparser probability
  distributions, a correctness-sensitive algorithm change with portable/WASM
  parity obligations.

Decision: leave the threshold at 192 rather than land a risky sub-bar change.
The dominant 43% sequence-executor cost remains the higher-leverage target, but
it too is structural (executor fusion), matching the prior rejection of cursor
promotion, branch-first, and wider wildcopy micro-edits. This package makes any
future zstd candidate immediately A/B-testable against the saved baselines.
