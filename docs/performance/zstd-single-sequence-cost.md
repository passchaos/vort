# Zstd scalar single-sequence cost

Date: 2026-10-25. Baseline production: `5928518f`, following the
[wide frequency reduction](zstd-wide-frequency-reduction.md). The long-term
industry-best objective remains incomplete.

The winner-aware cost bound still calls general sequence cost helpers on each
successful bound check. With exactly one sequence, no FSE state transition is
emitted. This increment adds a small scalar calculator for that case, using
the same canonical value classifiers, extra-bit tables and predefined state
availability. The winner bound can use it through an optional internal Codec
hook; the full exact literal/sequence price and general emitters keep their
existing algorithms.

## Exact size and errors

Let `E` be the sum of LL, OF and ML extra-bit widths. One count byte, one mode
byte, three RLE codes and a terminated reverse bitstream give
`5 + ceil((E+1)/8)` RLE bytes. A predefined sequence has two count/mode bytes,
fixed initial-state widths 6/5/6 and no transitions, giving
`2 + ceil((E+18)/8)` bytes. Predefined is available only when all three original
state masks are nonzero.

Offsets use the min-two-additional-bits masks, excluding the repeat-code
states. Values 1...4 select canonical code2 and the predefined base1/extra2
state. OF codes0/1 and 29...31 have no admitted predefined states. Mask
construction matches both canonical base and width, so a decoded state's
transition-bit width must not be used as its initial-state width.

RLE and predefined costs are equal for `E % 8 == 7`; otherwise an available
predefined mode is one byte smaller. The calculator classifies each of the
three values once and still checks the RLE section addition before considering
predefined. Thus a smaller predefined result cannot erase an earlier RLE
overflow. Invalid values, unavailable modes and integer errors remain distinct
as in the original helpers. No heap, global or retained state is introduced.

The general offset classifier also gains a checked admission before adding
its numeric bias of three. Values above `usize.max-3` now return
`CorruptFrame` instead of overflowing the addition. A table-scan oracle checks
that boundary on native and 32-bit targets; valid offset codes and wires do
not change. This safety correction is separate from the scalar price formula.

## Independent validation

The scalar filter passes 11/11 in native Debug, native ReleaseFast and 32-bit
x86 ReleaseFast. Counts include imported helper tests. The production contract
compares RLE, predefined and base results against both the old general helpers
and separate canonical/table-state scans with bit-by-bit packing. It covers
every code's base/end neighbors, LL/ML/OF maxima, exceptional offsets, all
eight extra-bit residues, unavailable mask holes, section overflow order and
512 generated inputs. A mock checks single classifier calls, mode ties and
RLE-first errors. A test-only usize conversion error found during initial
native compilation is corrected; failed runs are preserved separately.

The winner compatibility test delegates its optional hook to this calculator,
so existing shadow/prune candidate oracle checks exercise the optimized bound
cost. Native Debug and x86 ReleaseFast winner filters pass 11/11, and the
complete native ReleaseFast Zstd family passes 1096/1096. Additional candidate
and public-output evidence follows after those runs finish.

## Same-process cost benchmark

`zig build run-zstd-single-sequence-cost-bench -- 250000` records five
alternating general/scalar rounds. Every tuple first passes exact success/error
equality, and runtime tuple selection/noinline calls retain measured work.
The loop also includes selection, call/error handling and checksum work; it
does not isolate a CPU-time sample of one source function.

On i7-10700K, ReleaseFast, target `skylake+pku+sgx`, CPU8, Zig 0.16.0:

| Tuple pool | General median ns/query | Scalar median ns/query | Point throughput ratio |
| --- | ---: | ---: | ---: |
| Small values | 50.616 | 14.719 | 3.4389x |
| 64 KiB block values | 41.903 | 7.758 | 5.4015x |
| Large offsets | 82.922 | 10.566 | 7.8481x |
| Invalid lengths | 131.600 | 6.718 | 19.5884x |

The run retains executable/source identities and compiler-presence observations
(zero compiler processes). Its invalid tuple pool exercises old helpers before
their final combined error, while the scalar classifies once. Warm input pools
and one process do not establish repeated-process stability or whole-encoder
speed. The old general path does not build FSE tables per call: masks are
comptime constants, and undefined planning/read-field arrays are not evidence
of runtime clearing or allocation.

Independent disassembly confirms scalar tuple pricing classifies each of the
three values once and checks the admitted masks before the predefined formula.
Its extra-bit sum is at most 63. The general microbenchmark successful path
classifies nine times through its initial codes, RLE code rechecks and three
single-sequence planners. The public encoder invokes the winner's sequence
base wrapper, which contains the scalar calculator; full exact pricing still
calls the original helpers. The zero-section microbenchmark elides dynamic
section overflow checks, whose behavior is instead verified by real tests.
No 32 KiB planning-array clearing claim is made from source declarations.

## Public API and verification

A fresh fourteen-input five-round old-production baseline is already captured
using frozen 64 KiB prefixes, unchanged full level-3 policy and the explicit
local libzstd 1.6.0 file from checkout `01b7154f`. Source/input/reference/executable
identities are fixed and no compiler process is observed. The accepted new
fourteen-row five-round run follows complete builds and resource probes; it
also observes no compiler process. An earlier successful encode overlapping
resource compilation is retained but excluded from timing claims.

| Input | Old public median | Accepted new median | Version point speedup |
| --- | ---: | ---: | ---: |
| XML | 1005.939 ms | 817.419 ms | 1.23063x |
| MR | 786.031 ms | 656.416 ms | 1.19746x |
| Source code | 394.327 ms | 315.072 ms | 1.25154x |

The fourteen-row version throughput geometric speedup is 1.08205x. Ten
median point estimates improve and four decline, with the weakest point ratio
0.97742x on Ooffice. These small differences have no assigned statistical
significance. All fourteen Vort/reference sizes and hashes remain unchanged,
retaining 310,437/328,241 total bytes and thirteen smaller Vort frames. The
new throughput/reference geometric ratio is 0.00354679x, with zero competitor
throughput wins. This is one process per executable with five alternating
Vort/reference rounds, rather than an all-level/platform or repeated-process
ranking. Requested reference-file identity does not establish complete loader
dependency closure.

XML/MR diagnostics preserve every candidate work field and exact block hash,
including certificate publications and refusal decisions. Their elapsed
fields are excluded because those work checks run during unrelated builds.
The complete build check passes 171/171. Independent untimed old/candidate
XML resource probes retain the same 2,561,185-byte requested-heap peak and all
282 allocation/free events; both return the same caller-owned output, have
zero live bytes after caller release and pass tiny backing-OOM cleanup. Old
resource revision `5928518f` and the complete transitive source manifests are
recorded explicitly. No RSS or resource-probe time is used for ranking.

Broader levels, streaming, 1 MiB, ARM64 and competitor memory comparisons
remain separate work. The
[evidence package](data/zstd-single-price-20261025/artifact-manifest.json)
retains exact input identities, all raw rounds, excluded-run decisions,
source/executable/reference identities, proof/ELF reviews and validation.
