# Brotli adaptive command-block splitting

Date: 2026-10-14. Host: Intel Core i7-10700K, Linux x86-64, Zig 0.16.0,
ReleaseFast, CPU affinity 2, one codec thread.

## Functional result

The command entropy splitter now has a general allocator-backed representation
beside the retained fixed-grid proposals:

- an integer-Q8 histogram model with no target-dependent floating point;
- an owned plan with arbitrary non-empty block lengths, up to 256 declared
  types, validation, and a linear payload cursor;
- a deterministic `O(symbols * types)` Viterbi assignment with bounded scratch,
  iterative histogram rebuilding, empty-type removal, and first-use type
  normalization;
- general Brotli block-type transitions using previous (`0`), cyclic successor
  (`1`), or direct (`type + 2`) symbols;
- dynamically allocated command histograms, code lengths, and encoders, so the
  normal command writer keeps its established stack footprint.

The focused production fixture places four boundaries at commands
901/2305/5179/7001 and reuses three trees as `A-B-A-C-A`. This shape is neither
the old sixth-grid search nor a cyclic type sequence. Exact complete-wire
arbitration selects the adaptive result. Vort, Node, runtime libbrotli 1.0.9,
and Vort's 17-byte-input/31-byte-output progressive decoder all reproduce the
405,509-byte payload; the encoded fixture is 191,508 bytes. The upstream
differential now reports nine planned command-split cases.

Core tests include exhaustive small Viterbi cost comparison, off-grid and
non-cyclic assignments, deterministic output, stationary rejection, all nine
scratch allocation failures, complete 256-type plan/switch boundaries, invalid
plans, and adaptive writer allocation cleanup.

## Default-path isolation

An unconditional 3-iteration/16-type production search was rejected. Eleven
alternating fixed-CPU-2 `source32k` pairs all lost, with a paired geometric
ratio of about `0.944x` despite identical wire and checksum. A one-iteration,
eight-type budget still measured about `0.942x`; allocation/model setup rather
than only DP state count dominated the added cost.

The retained public feature is therefore ratio-only and opt-in through
`PlannedEncodeOptions.adaptive_command_split`. The command writer uses
compile-time adaptive/non-adaptive instances, with the opt-in implementation
placed in a separate text section. Eleven default-path pairs retained identical
wire/checksum, won 6/11, and measured a `1.004x` paired geometric ratio
(`189.773 -> 188.390 ms` independent medians), which is treated as no-regression
layout evidence rather than a speed claim.

With the option enabled, the current nine built-in rows and six 110--131 KiB
repository source/Markdown paths retained their default sizes. The six source
paths paid roughly 20--35% more ratio time, so automatic enablement would be
unsupported by evidence. The next step is a cheap heterogeneity/predicted-wire
screen trained on broader real corpora; the complete-wire comparison remains
the final size authority.
