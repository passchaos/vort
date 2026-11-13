# Zstd no-low FSE builder fill screen, 2026-11-14

Status: rejected before full-matrix adoption. No production source changed;
the prototype lived on a temporary branch and was removed after the screen.

## Hypothesis

The compact no-low builder (`sequence/small/compact_no_low.zig`) handles the
64/128-state sequence tables used by most compressed blocks. It declares a
53-slot `next` array without zeroing it in the current code, then writes only
the symbols whose probability is non-zero. The prototype tracked active
symbols in a separate list and kept the same spread/ascending logic, aiming
to make the array footprint explicit and reduce any redundant fill work.

## Prototype

- add `active_symbols[53]` and `active_count` alongside `next[53]`;
- record each symbol when its probability is first written;
- retain the exact spread loop and ascending entry construction;
- assert the active count in Debug only so ReleaseFast removes the list.

The complete `zig test src/zstd.zig` suite passes.

## Sixteen-row paired screen

Eight fixtures at 64 KiB and 1 MiB, levels 3 and 19, 40 iterations with four
rounds and two warmup pairs on CPU 15 against libzstd 1.6.0.

- geometric mean baseline/candidate: 1.003334 (parity)
- one row below the 0.98x floor: mozilla 64K L3 at 0.97844
- gains and losses alternate by fixture and size without a consistent
  direction (best mozilla 1MiB L3 +4.0%, worst mozilla 64K L3 -2.2%)

The original code already avoided the memset; the added `active_symbols`
array simply increases stack state and perturbs code layout, matching the
pattern seen in the Deflate primary-only and Brotli cached-distance
screens. A rerun-style parity result with one control below the floor cannot
be adopted.

## Decision

Do not change the no-low builder's fill structure. The memset weight in the
mozilla profile comes primarily from the generic mapped builder's
`symbol_next` zeroing and the normalized-count workspaces, not from this
compact path. The next builder experiment must target
`fse_builder.buildMapped` directly or reduce the normalized-count parser
workspace, and must show a consistent direction across fixtures before a
full matrix. No A/B artifacts are committed.
