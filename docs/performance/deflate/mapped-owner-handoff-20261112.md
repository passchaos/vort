# Deflate mapped owner and normalized handoff screen, 2026-11-12

Both isolated prototypes are rejected. Building canonical and semantic tables
in an address-stable owner, then using a normalized match word, gives a
12-row whole-operation geometric-mean speed ratio of **1.000209x**. Its 95%
sampling interval includes parity, and the reymont 64 KiB L6 target improves
only **2.40%**, below the predeclared 20% cliff-repair gate. The owner-only
scalar control regresses overall and fails the 0.98x control floor.

The mainline remains on the accepted `7aaa9361` distance-hole correction and
original executor. No prototype codec source is adopted, and this screen does
not refresh the complete modern-reference ranking.

The owner constructs the canonical LL and distance tables directly in their
final storage, derives ascending active symbol lists from validated lengths,
and prepares semantic tables once. Only successful preparation mints an opaque
borrow; failure retains compact tables for checked fallback. Empty, single,
complete and incomplete distance trees remain supported, including real valid
long codes and defined invalid suffix holes. The borrowed storage cannot move,
be copied, mutated or reinitialized during execution. Arbitrary private
`SemanticDynamicDecoder` tables do not acquire the mapped capability.

The typed ordinary executor represents a completed legal match as
`(length - 3) | ((distance - 1) << 8)` in a u32. Canonical construction proves
length 3..258 and distance 1..32768; no extra full-array scan, mutable trust
flag or per-token optional range check is introduced. Existing generic and
window entries retain full-width `usize` behavior for private outliers. The
RLE258 and deep-distance non-overlap entries retain their scalar executors.

The owner-only control uses exactly the same owner branch and preparation;
its ordinary call selects the full-width scalar entry instead of the typed
mapped entry. These two isolated source trees differ at that call only. This
control separates the combined proposal from the owner/scalar variant. It
does not prove that scalar payload machine code matches the baseline, and
its result does not identify the cause of the regression.

| Whole public raw decode speed, baseline / candidate time | Owner + word | Owner + scalar |
| --- | ---: | ---: |
| All 12 rows | 1.000209x | 0.969613x |
| 95% fixed-row sampling CI | 0.996069–1.004467x | 0.967351–0.972016x |
| Six 64 KiB rows | 1.004292x | 0.945488x |
| Six 1 MiB rows | 0.996143x | 0.994354x |
| Target reymont 64 KiB L6 | 1.023978x | 1.042355x |
| Weakest row | reymont 1 MiB L9: 0.985289x | nci 64 KiB L9: 0.891105x |

Each variant uses four balanced AB/BA process pairs per row, with two measured
and two warmup Vort/reference batches in each child. Batches use 500 decodes
for 64 KiB and 100 for 1 MiB. All 192 child events, 96 process pairs
and 384 measured Vort/reference pairs are retained. The screen uses reymont,
nci and XML, 64 KiB/1 MiB, and Python zlib 1.2.11-produced L6/L9 frozen raw
Deflate wires (`compressobj`, `window_bits=-15`). The
public `decodeRawDeflate` call includes preparation and execution; caller
buffers, process startup, loading and verification are outside timing. No
prepared-executor microbenchmark is substituted for the public operation.
The cold reference includes libdeflate allocate/decompress/free. The CI uses
2,000 fixed-row process-order bootstrap resamples of paired baseline/candidate
batch medians; it includes every measured batch rather than selected minima.

The host is Intel i7-10700K, logical CPU15, Zig 0.16.0 ReleaseFast,
`x86_64-linux-gnu`, `skylake+pku+sgx`, one thread. The exact libdeflate 1.26
library, loaded closure, source/header provenance, wire/plain hashes, byte
counts and per-batch validation use the existing modern comparison protocol.
Compiler observations at all 384 child boundaries are empty; load1 ranges
0.8721–1.2158. This remains a development-host screen. Process ticks and
last-seen CPU tags cannot establish timed-batch background overlap, and the
CI describes sampling uncertainty on these fixed rows rather than a
dedicated-host acceptance result.

Static inspection confirms a physically materialized mapped word, but still
two carried copy values: `%edx` holds the word and `%ecx` holds `length - 3`
across next-entry loading and refill. Length is recovered from `%cl`; distance
is recovered from the word afterwards. The opaque accessor is inlined and
does not add a getter call or optional tag check. This is not a successful
single-value handoff.

| Frozen ordinary aligned executor | Baseline | Owner + word |
| --- | ---: | ---: |
| Symbol bytes | 3,659 | 3,729 |
| Local stack reservation | 296 | 312 |
| Static instruction lines, including padding | 897 | 894 |
| Negative-rbp operand references | 131 | 129 |

The +70 symbol bytes and +16 local stack bytes are static scope measurements.
Whole-symbol operand/call counts include cold and tail code and do not prove
runtime spill or call-frequency changes. The timing candidate does not emit
the old aligned full-width symbol; private behavior comes from separate
test executables. No compiler barrier, inline assembly or forced
materialization is used.

Validation passes native Debug/ReleaseSafe and 32-bit x86 ReleaseSafe, each
**105 aggregate/import tests**: 8 owner declarations, 6 mapped comparison
declarations, 3 private full-width declarations and imported existing tests.
The mapped comparisons use canonical wire construction and an independent
byte-at-a-time LZ oracle, checking complete reader, input, output/scratch and
guard equivalence. Private tests retain length 259/512/65535, distance
32769/65535, zero-distance error priority and window/output boundaries.
Complete `src/deflate.zig` ReleaseSafe passes **738/738**, without importing
these new shim modules. WASI compiles the shim successfully; it was not run
in this round. Formatting and patch whitespace checks pass.

The first Debug/Safe shim epoch passed 103/105. Two missing-code fixtures
incorrectly expected `InvalidHuffmanCode` from short unpadded input. Both old
and new entries returned `TruncatedFrame`, because the compact fallback scans
missing codes through 15 bits. The corrected epoch changes only those test
expectations, preserves the short and padded fixtures, and reaches the full
reader/scratch comparison. Production sources and the original timing binary
retain their frozen bytes across that correction.

Both variants independently pass all **72 frozen Deflate wires**, with full
output, exact consumption, immutable input and guards. These 144 smoke events
are correctness evidence; their one-call timings are not performance claims.

The [evidence packet](mapped-owner-handoff-20261112/README.md) retains separate
original timing, failed-test, corrected-test and owner-only source epochs,
executables, raw logs, raw process output, static inspection, protocol and
offline verification. The matched baseline executable is `65b75eee...`,
including the distance-hole fix; the original mapped timing executable is
`2d2d1822...`. Earlier pre-fix baselines are not used.

The next structural experiment should retain the constructor proof and
private full-width boundary while addressing measured public-operation
costs. This result gives no basis to adopt normalized packing alone or to
attribute a gain to eliminating distance fast8 preparation.

Reprofile the three frozen versions on reymont64K L6, nci64K L9, XML64K L6
and nci1M L9. Separate preparation work, payload instruction cost and stalls
with cycles/instructions/branches/branch-misses per Vort public call, counting
only its batches and keeping verification outside that scope. Small-block
regressions could reflect fixed preparation cost; live-state and code-layout
changes could affect payload cost. These are hypotheses to distinguish, not
causes established by the current timings or static counts.
