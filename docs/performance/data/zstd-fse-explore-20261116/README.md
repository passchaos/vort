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

## Frame-state memcpy candidate already resolved (2026-11-16)

The 2026-11-10 note flagged a 1.71% `memcpyFast` from materializing a 13,440-byte
`SequenceFrameState` after `initialSequenceFrameState`. Re-checking current
source shows this no longer exists as an open issue:

- `initialSequenceFrameState` returns `.{}` directly when there is no dictionary
  (`dictionary orelse return .{}`, src/zstd.zig 12205), so the no-dictionary path
  never copies the large state.
- The reusable workspace entry point
  `decodeRawOrRleZstandardFrameIntoBufferWithSequenceWorkspace` already declares
  `var frame_state: SequenceFrameState = .{}` (12413) and is hard-wired to the
  no-dictionary validation path.
- Default `SequenceFrameState = .{}` initialization is now used at 67 sites.

So the only previously-open local memcpy candidate is already resolved, and the
remaining 1.32x weak-row gap stays gated on the structural executor/
table-representation fusion, which is an architecture-level project (a table
representation the executor consumes directly), not an isolated edit. No new
micro-change with positive expected value remains on the current profile.

## Medium executor hotspot annotated (2026-11-16)

A fresh perf run on nci 64K L19 attributes 45.97% to
`tryDecodeMediumSplitHuffmanSequencesNative` (this frame takes the medium, not
dense, path). Annotation shows the cost is flat and dispersed like Brotli: top
instruction 4.63%, dominated by `vmovups` literal/match SIMD copies plus
condition branches, with no single bottleneck.

Two candidate ideas were checked against source and found already implemented:

- the medium executor already has the same wildcopy fast path as dense
  (the `match_offset >= 16` + capacity-guarded `appendUpTo16Wildcopy16` /
  `appendForwardWildcopy` block at src/zstd.zig 15986+), so there is no missing
  short-match vectorization to port;
- the FSE `SequenceSymbol` table is already an executor-shaped 8-byte word read
  once per state via `symbolWordUnchecked` with inline bit unpacking, i.e. the
  table representation is already fused to the consumer.

This confirms at instruction granularity that the executor is bound by
intrinsic per-sequence work (three FSE state transitions, field reads, two
copies), not a removable local inefficiency. A real gain requires reducing the
operation count per sequence (wider/batched state transitions), which is the
architecture-level fusion and cannot be introduced as an isolated edit without
a new representation and full portable/WASM parity.
