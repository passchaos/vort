# Exact tiled assignment round, 2026-11-27

Status: rejected after the fixed whole-operation diagnostic pilot. Arithmetic
Native/WASI, production price-bound and public wire/profile/resource gates
pass, but all twelve pilot rows are slower. The uncommitted production overlay
and its dedicated tests have been removed from main's worktree; the exact
candidate source and patch remain frozen in the evidence package.
Formal, control, historical/reference and final whole-library merge gates
were not released or run for this rejected candidate.
Baseline is committed main `46d340ac`.

The existing clustered literal-context chooser freezes its symbol prices for
one complete round. Moving a context only prepares next-round histograms.
This slice computes all choices first, then keeps the original populated
context order for histogram moves, stop conditions, remapping and scoring.
It does not change prices, seeds, iteration limits, candidate policy or ties.

The cohesive `assignment/phase.zig` kernel handles four contexts and eight
adjacent trees. It derives each real u64 frequency sum from the sparse entries;
it never trusts `sparse.total`. The producer returns the maximum price while
filling every active symbol/tree cell. A context uses u32 vectors only when
its sum fits u32 and `sum * maximum_price <= maxInt(u32)`. Duplicate symbols
cannot overflow a packed bucket under this same bound. Comparison is unsigned
and strictly less, so equal costs retain the earliest tree across groups.

The kernel uses a fixed 4 KiB per-tile frequency area and a small symbol union,
without a full 64 KiB frequency plane or new heap allocations. Unsafe contexts
retain the original u64 chooser; small tree/context groups retain its light
path. A valid zero maximum-price certificate selects tree0 at cost0 without
packing. Tree tails only copy active initialized prices. The old chooser is
also hardened to skip zero-frequency entries before reading a price row;
production sparse construction already omits these entries.

The fixed scratch and 64 output choices are not a measured codec stack figure.
Requested-heap, generated code and full-operation controls still require their
own observations before adoption. The scalar/grouped route remains a test
oracle behind a test-only flag; production dispatch does not check CPU features
or global state in the symbol loop.

## Current-source routing evidence

The pinned GNU x86-64 / `skylake+pku+sgx` / ReleaseFast profile runs ordinary
and instrumented public q8/generic/explicit-window16 calls on Mozilla, NCI and
Xray 64 KiB inputs. Every instrumented wire equals the ordinary byte oracle.
The tool's diagnostic clocks finish before output release; they are not the
continuous owning lifecycle used in performance acceptance.

| Case, three instrumented rounds | Outer ns | Complete context-proposal ns | Recorded assignment ns | Detail coverage |
| --- | ---: | ---: | ---: | --- |
| Mozilla | 435,469,085 | 224,421,475 | 21,835,681 | 24 of 30 details; truncated |
| NCI | 253,390,273 | 34,803,166 | 3,603,708 | 24 of 24, complete |
| Xray | 387,541,373 | 66,153,462 | 15,949,282 | 24 of 24, complete |

Recorded assignment is about 5.0%, 1.4% and 4.1% of the respective instrumented
outer times. Mozilla is a saved-prefix sum, not a full assignment share.
Cluster scoring is larger in these records. A separate ordinary-operation
perf diagnostic also identifies clustered chooser/optimal parser/writer work.
That process profile includes untimed SHA and JSON/provenance work; its flat
function percentages cannot be called codec-exclusive fractions. These facts
route this experiment and do not predict its recoverable throughput.

Profiling evidence is frozen under
`/tmp/vort-q8-assignment-profile-h8akp9ex`. The first attempted ELF copy had no
executable permission and returned126 before any codec call; that original
receipt is retained separately. The corrected executable bytes are unchanged.

## Verification and acceptance

The final kernel/common dependency epoch passes Native11/11 and actual WASI
11/11, including independent scalar costs, all tree/context counts, unsigned
32-bit boundaries and fallback, duplicate/zero frequencies, wrong totals,
inactive-price poisoning, conservative maximum-price certificates and tails.
An earlier9/9 epoch predates the zero-frequency fallback hardening and remains
separate. Production assignment price preparation passes its current22/22
test filter, including exact maximum-price agreement.

Public Native ReleaseSafe and actual WASI each pass35/35. Full original gold
wires, decoded bytes, proposal shape/scoring counters and new assignment class
counts agree with the grouped oracle. Mozilla/Xray execute real narrow-vector
contexts; proposal reuse retains zero scoring work. Moving allocator observations
preserve every request length, allocation count, cumulative bytes and peak.
Exact quota, peak-minus-one refusal/recovery and six observed backing OOM sites
per target plus active retries pass. These are selected actual allocation sites,
not a repeated exhaustive681/688 sweep or inferred header/transfer coverage.

| Target | Mozilla peak / allocations / cumulative B | Xray peak / allocations / cumulative B |
| --- | ---: | ---: |
| Native, both old/new | 5,115,910 / 681 / 30,505,144 | 8,168,439 / 978 / 55,586,279 |
| Actual WASI, both old/new | 4,430,770 / 688 / 26,033,300 | 7,398,019 / 993 / 48,103,594 |

The initial public test compilation exceeds its test-harness comptime branch
quota before codec execution. The corrected test adds only an evaluation-quota
setting; its fresh source epoch and the original failed source/logs remain
separate. Production algorithms and runtime budgets are unchanged.

Performance acceptance remains full public operations, unchanged wires/ratio,
GM>=1.03, confidence interval excluding parity and every applicable row/control
>=0.98. This epoch predeclares the twelve-row six-common-round matrix as its
primary estimator; weak-row extra samples are retained and reported separately.
The preceding split-planning epoch's predeclared all-sample estimator remains
valid historical evidence and is not retroactively relabeled an error.

## Fixed diagnostic pilot: rejected

The new epoch is `/tmp/vort-br-round4ctx-u32safe-ab.209oijha`. Its four build
stages complete with actual exit0. All84 warm-only preflight processes pass
baseline/candidate full-byte comparison and pinned libbrotli decoding:
24 primary,36 public and24 small. Public q10/q11 retain the actual default
255 KiB command-state setting on both sides; q11-cap8 is a separate explicit
8 KiB control. An erroneous32 KiB assertion in the static sealing helper is
preserved separately and corrected without changing source, options, raw
records or rerunning a codec/build.

After all build/codec/hash/archive work stops, Root issues a fresh diagnostic
release at2026-11-27T01:42:25.994270+00:00. The fixed pilot completes with
actual exit0:12 corpus rows, two alternating AB/BA pairs per row,24 pairs and
48 processes. Every process uses one owning warmup and one timed public
encode/mix/free call. All initial-wire hashes, input/ELF/source identities and
timed length/mix checks pass. Every original sample is retained.

| 64 KiB input | Candidate / baseline throughput |
| --- | ---: |
| Dickens | 0.927079x |
| Mozilla | 0.779307x |
| MR | 0.918458x |
| NCI | 0.947695x |
| Ooffice | 0.809236x |
| OSDB | 0.751193x |
| Reymont | 0.935392x |
| Samba | 0.931386x |
| SAO | 0.810043x |
| Webster | 0.889996x |
| Xray | 0.939066x |
| XML | 0.932681x |

The equal-row geometric mean is **0.878150548070644x**, about12.18% lower
throughput in this diagnostic screen. Both fixed point gates fail: GM is below
1.03, and all twelve rows are below0.98. CI remains null; two pairs per row
are a rejection screen, not a formal estimate or an industry ranking.
Root rejects the candidate without another sampling attempt or gate change.
Independent pure-data replay of every pair and original nanosecond reproduces
the same GM and all twelve failed row floors. It also checks actual exits,
AB/BA chronology, frozen source/ELF/probe and option identities,24 initial
wire byte comparisons and the timed length/mix scope without importing the
producer or running a codec, build or sampling process.
The dedicated tests prove exactness/resource behavior and do not imply a
performance benefit. No full-library gate or new direct historical/reference
result is claimed. `full_gate_passed=false` and `merge_eligible=false` remain
explicit in the original records.

The source manifest SHA256 is
`11ad3e9985241911513dd94089d1b8f4c8cf2cde3e5dd311caabdacb2e120e1c`;
candidate ELF SHA256 is
`da2f250642f96491e575be34b2c9f07233392050248f78e127606b5e9cae5667`.
Before restoring the four tracked production files and deleting the three
new phase files, Root independently checks their bytes against the frozen
candidate and saves an applyable patch. This documentation does not enable
the kernel. The zero-frequency fallback adjustment is retained with the
rejected patch, rather than silently carried into the production baseline.

The [portable evidence package](assignment-round-20261127/README.md) preserves
the source, contracts, failed screen and independent replay. Future work should
measure structural reductions in repeated model/search/planning and physical
losing-wire work before another assignment microkernel. The current candidate
has no measured stage attribution explaining its slowdown.

The full Deflate/Zstd/Brotli industry-best goal remains active. The earlier
direct q8 historical regression remains unresolved; even a future3% gain
against recent main will not constitute historical recovery.
