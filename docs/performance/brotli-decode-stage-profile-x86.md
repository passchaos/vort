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

## Post-LUT RLE, canonical, and context-map follow-ups

After the fixed-prefix LUT and direct 18-symbol root builder landed, the same
fixed-CPU-2 process-pair method evaluated the remaining header stages. Every
candidate below preserved output sizes and checksums; none met the complete
matrix retention rule, so production source was restored.

- Packing pending repeat state into `(count, length)` and reusing the Kraft
  contribution check reduced the complex parser by 10--36 bytes, but 15 long
  `clustered_q8` pairs measured `0.9987x` median/geometric throughput with only
  3/15 wins.
- A caller-supplied code-length histogram removed the canonical builder's
  second active-symbol scan. Global use improved `clustered_q8` by `1.0091x`
  median / `1.0088x` geometric mean with 15/15 wins, but a long
  `structured_q4` control regressed to `0.9957x` median / `0.9946x` geometric
  mean with 2/15 wins. Restricting it to 16--64 literal trees still changed
  shared generated layout: the target improved `1.0057x`, while the short
  matrix put `structured_q4` at `0.9929x`. A fully duplicated clustered parser
  restored ordinary hot-function sizes but enlarged read-only/unwind metadata;
  the long q4 control remained `0.9958x` with 1/15 wins.
- Merging the canonical next-code and bit-width-offset loops shrank the two
  target complex-tree instances by 81/62 bytes without moving their addresses,
  but complete decode was neutral-negative at `0.9992x` median / `0.9994x`
  geometric mean with 5/15 wins.
- An eight-bit context-map tail root reduced the isolated context-map stage
  from roughly 5.83 to 3.45 microseconds. The first compile-time hot/fallback
  split improved the long target by `1.0058x` median / `1.0056x` geometric
  mean with 15/15 wins, but enlarged `readContextMap` from `0x239e` to
  `0x2671`; the 13-row matrix fell to `0.9950x` across row medians, with q11
  rows as low as `0.9724x`. Runtime dispatch, an external packed root, and
  outlined preparation/fallback variants all grew the parser further and were
  removed after focused size and smoke checks.

The remaining credible direction is not another wrapper around the compact
canonical parser. A context-map-specific decoder must replace existing work
while reducing generated code/read-only state, or a future header
representation must construct the final decode root without retaining a
second canonical form. Isolated stage wins alone are explicitly insufficient.

## Compact final context-map root follow-up

A subsequent candidate replaced the temporary generic 272-symbol Huffman table
entirely with a five-bit final root and a canonical-indexed long-code tail. It
therefore tested the replacement direction above rather than adding another
lookup wrapper. `readContextMap` shrank from `0x239e` to `0x1b8e` bytes and the
ReleaseFast ELF `.text` section fell by 960 bytes. In a 2,000-frame stage run,
header time improved by `1.0376x`; fifteen independent-binary, fixed-CPU-2
`clustered_q8` pairs improved by `1.0042x` median / `1.0047x` geometric
throughput with 14/15 wins.

The full controls still rejected it. A seven-pair matrix put `structured_q4`
at `0.9926x` median / `0.9922x` geometric throughput and ordinary `repetitive`
at `0.9955x` / `0.9950x`. Four- and six-bit roots did not repair the problem.
Long 100,000-decode controls for the six-bit layout reproduced the regressions:
`structured_q4` measured `0.9949x` median / `0.9955x` geometric with 4/15 wins,
and `repetitive` measured `0.9967x` / `0.9966x` with 2/15 wins. The production
implementation was fully restored. Exact binaries, observations, commands,
stage counters, and the complete short-matrix summary are retained in
`data/brotli-context-map-compact-root-x86-20261013.json`.

This closes the obvious compact-root width sweep: even a smaller final
representation can perturb or slow ordinary streams enough to fail the matrix.
Future context-map work needs an end-to-end representation shared with later
literal/distance tree selection, or should yield to reductions in actual
distance/copy execution rather than revisiting standalone root widths.

## Packed 32-bit prepared-distance root follow-up

The next experiment moved to actual distance execution. The flat multi-tree
path's 16-bit distance slots were replaced by 32-bit entries containing the
Huffman width, prepared extra-bit width, and a 23-bit distance base. Two
reserved widths represented short symbols and regular symbols whose base did
not fit, preserving the canonical fallback. The candidate was narrower than
the older rejected 64-bit metadata root and changed only the selected
`clustered_q8` payload instance.

Focused canonical/RFC/truncation tests passed. A 2,000-frame diagnostic looked
promising: payload time improved from 982.3 to 957.6 ms and complete staged
time improved by `1.0135x`, although distance-root setup grew from 21.5 to
30.4 ms. The authoritative independent-binary complete-frame comparison
reversed that result. Fifteen alternating fixed-CPU-2 pairs, each using five
2,000-decode rounds over one frozen frame, measured `0.99558x` median /
`0.99572x` geometric throughput with 0/15 wins and a `0.99314x--0.99982x`
range. Median throughput fell from 1747.14 to 1738.48 MiB/s.

The fixed distance-root scratch doubled from 64 to 128 KiB, the selected
payload grew `0x10d5 -> 0x1158`, and ELF `.text` grew by 624 bytes. The
candidate was fully removed without running broader controls because its only
target already lost every pair. Exact fixture/binary hashes, stage counters,
focused coverage, and all paired nanoseconds are retained in
`data/brotli-prepared-distance-root32-x86-20261013.json`. Together with the
earlier 64-bit result, this rules out embedding prepared distance metadata in
a root wider than the existing 16-bit slots for the current flat executor.
