# Zstd mapped FSE builder memset removal screen, 2026-11-14

Status: rejected before full-matrix adoption. No production source changed;
the prototype lived on a temporary branch and was removed after two screens.

## Hypothesis

The mozilla profile attributes 7.03% self weight to compiler-rt memset whose
parent is `parseSequenceModeSpecInto` / FSE table construction. Inside
`buildMappedBounded`, `symbol_next[0..values.len]` is zeroed even though the
ascending entry pass only reads slots after the spread loop writes them.
Removing the memset should cut setup work without changing any computed
table entry.

## Prototype

Delete the `@memset(symbol_next[0..values.len], 0)` in
`buildMappedBounded` and leave the array undefined. Correctness argument:
- value == 0 symbols are handled by the separate low-entry loop and never
  read from `symbol_next`;
- value == 1 symbols have probability zero and are skipped by the spread
  loop, so their slot is never read;
- value > 1 symbols write `symbol_next[symbol] = value - 1` before the
  ascending pass reads it.

The complete `zig test src/zstd.zig` suite passes.

## Two paired screens

First screen (40 iterations, four rounds, two warmup pairs, 16 rows):
geomean 1.008052 with zero controls below 0.98, but individual rows moved
both ways and a rerun produced an outlier (nci 64K L3 0.57), indicating
host noise rather than a stable effect.

Confirmation screen (60 iterations, same shape):
geomean 0.997227 with two controls below 0.98 (sao 64K L19 0.97977,
nci 64K L19 0.95506). The apparent 5% mozilla 1MiB L3 gain in the first
screen did not reproduce.

## Why it fails

The memset is small relative to the full block decode and its removal
changes stack layout/code placement enough to move unrelated rows by
several percent. Results do not separate a real setup saving from
measurement noise: the two screens disagree on both geomean sign and the
specific controls that fail. Adopting a change that cannot clear the 0.98x
floor on a confirmation run would weaken the gate rather than improve
throughput.

## Position after four rejected micro-optimizations

Together with the Deflate primary-only flag, Brotli cached distance and
no-low builder fill screens, this confirms that isolated setup/branch edits
inside the existing hot functions cannot produce a stable whole-operation
gain on this host. The next credible performance work needs a larger
structural change with its own static codegen audit (for example fusing the
FSE normalized parse, spread and entry construction into one pass, or the
Brotli full distance-resolution fusion), not another single-instruction or
single-memset edit. No A/B artifacts are committed.
