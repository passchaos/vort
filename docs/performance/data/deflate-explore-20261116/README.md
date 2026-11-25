# Deflate decode baseline and hotspot check, 2026-11-16

The Silesia corpus makes the deflate reference bench runnable
(`run-deflate-reference-bench --input <file>`; it zlib-encodes internally and
compares Vort raw deflate against libdeflate 1.10).

## Baseline (nci 64K, zlib level 6, 3000 iterations)

reference/Vort = 0.9263, i.e. Vort is 1.080x slower. Reaching parity needs
~8% throughput, well beyond a single 3%-bar micro-edit even if one existed;
a 3% win would only narrow the gap to ~5%. CSV: `baseline-nci.csv`.

## Hotspot annotation

perf attributes 37.72% to `deflate.semantic.linear_entry.aligned`, but that is
a 64-byte-aligned entry thunk; the work is `decodeDynamicBlockIntoLinearMode`.
Annotation of the core loop shows flat dispersed instructions (top 6.48%):
pointer arithmetic, table loads, and `vmovdqu` copies, with no single
bottleneck. A secondary 4.19% is `buildLiteralTable` (per-block setup) and
2.83% memset.

This matches the Zstd and Brotli findings: the hot decode loop is bound by
intrinsic per-symbol work spread across many instructions, not a removable
local inefficiency. The ledger's prior analysis (fastloop rewrite and
literal/match loop split offer no safe gain) still holds; no new positive-EV
micro-change appears on the current profile. The ~8% gap would require
structural work comparable to the other codecs, not an isolated edit.
