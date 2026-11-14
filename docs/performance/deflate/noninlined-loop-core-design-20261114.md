# Deflate non-inlined loop core redesign: design review, 2026-11-14

Status: design only, no source change. The 2026-11-14 hotspot and bit-reader
audits leave one untried structural lever for the deflate 64K gap: the
3,659-byte inlined semantic loop. This note defines the redesign's scope,
acceptance criteria and kill criteria before any code is written, so the
project can be rejected cheaply if its premises fail.

## Current structure

`decodeDynamicBlockIntoLinearMode` is a `pub inline fn` with five comptime
flags. Production instantiates:

- ordinary linear (`false,false,false,false,false`) via
  `linear_entry.aligned/portable`;
- non-overlap (`false,false,true,false,false`) for PNG-style blocks;
- windowed (`...,true`) for the resumable API;
- test-only rle1/rle258/single-distance variants.

Each inlining duplicates the full state machine into its caller. The
measured ordinary path (`linear_entry.aligned`) is 3,659 bytes of text with
a 296-byte frame and 273 memory operands; 60-64% of branch misses land in
this one symbol on both slow 64K corpora.

## Premise check result (2026-11-14)

`perf record -e branch-misses` plus `perf annotate` on mr 64K L9 attributes
the misses within `linear_entry.aligned` across many instructions; the
largest single local share is 17.75% (a `shrx` in the bit-staging region),
followed by 10.23% and 9.44%, with the remainder below 4%. No conditional
jump carries a dominant fraction, and no individual branch exceeds ~18%.
This confirms the premise: misses are diffuse, so no localized branch fix
can absorb them. The redesign's first go/no-go gate is satisfied; the
remaining gates are the standalone prototype codegen targets and the A/B
floor.

## Proposed shape

1. Keep the existing `linear_entry` entry points and their block/tail
   orchestration, but call a smaller `noinline` ordinary-token core for the
   steady-state window (`out_pos + 16 <= output.len` and eight safe input
   bytes). The core handles only: four-literal quad decode, standard match
   length/distance decode, and the already-specialized copy kernels.
2. Move block-boundary handling, output-tail, malformed-token recovery and
   PNG non-overlap policy into the existing callers/tail window; the core
   returns a status enum (continued, end-of-block, need-tail, error) instead
   of branching on those conditions internally.
3. Preserve every current specialization as a separate decision outside the
   core; do not merge rle1/rle258/non-overlap into it. The ordinary core must
   be expressible without comptime flags so it compiles to one physical
   function.
4. Reader state stays in the callee's locals exactly as today; the
   `BufferedBitReader` is synced through the existing
   `storeReaderStateDelta` boundary, which already defines the ABI between
   fast and tail phases.

## Hard acceptance criteria (all required)

Codegen, measured on the rebuilt `vort-decode-compare` before any timing
claim:

- ordinary core text below 2 KB (versus 3,659 bytes today);
- core stack frame below 128 bytes (versus 296);
- no new standalone reader symbol above 1% in the instruction profile;
- zero behavior changes: full `zig build test-br` plus the 72 frozen-wire
  decode smokes must pass unchanged.

Performance, via the standard paired A/B harness (CPU 15, 40 iterations,
four rounds, two warmup pairs):

- geomean base/candidate >= 1.03 on the 24-row 64K/1M brotli-style matrix
  adapted to deflate rows, meeting the project's 3% minimum improvement
  bar;
- no control row below 0.98x in any of three independent rounds;
- the two profiled slow rows (mr 64K L9, mozilla 64K L9) must improve in
  every round, since the design targets them specifically.

## Kill criteria

Stop and revert if any of these hold at the first measurable milestone:

- the core cannot reach the text/frame targets without re-inlining the
  token specializations (then the footprint is intrinsic, not structural);
- branch-miss rate on mr/mozilla does not fall by at least one percentage
  point despite the size reduction (front-end saturation was not the
  cause);
- any A/B round produces a sub-0.98 control row, matching the seven prior
  failed layout screens;
- the windowed/PNG paths require duplicating the core, recreating the
  current code-size multiplication.

## Regression scope

The rewrite touches the highest-throughput deflate path. Required validation
beyond `test-br`: all deflate/deflate64 incremental and one-shot tests, the
frozen matrix round-trip smokes, malformed/truncated frame suites and the
PNG non-overlap contract tests. The semantic token probe must report
identical literal/match histograms before and after, proving the wire walk
is unchanged.

## Recommendation

Do not start implementation in the same workstream that produced the
diagnostic audits. The design is viable only if the branch-miss address
profile confirms diffuse misses and the core can hit the 2 KB / 128 B
codegen targets in a standalone prototype. Treat those two checks as
go/no-go gates; if either fails, accept the current deflate loop as locally
optimal and shift remaining effort to functional coverage rather than a
rewrite.
