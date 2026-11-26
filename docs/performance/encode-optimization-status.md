# Encoder optimization status

## 2026-11-26 compact modeled DP and adjacent lanes: rejected pilot

The [complete pilot package](br/modeled-lanes-20261126/README.md) uses unchanged
main `f60685e5` public Brotli code as baseline and a frozen combined candidate:
compact u32 single-model costs/steps, adjacent paired DP lanes, one paired
length-choice loop, and a per-position prefix load. Both retain the original
q8/generic/window16 policy, candidate order, budgets and complete initial wires.

Two AB/BA rounds over twelve original 64 KiB inputs retain 24 pairs/48 timed
operations. Throughput geometric mean is **1.009892x**, NCI **1.051026x**, and
Mozilla **0.909809x**. The unchanged 1.03x/1.20x/0.98x point gates fail; this
combined candidate is **rejected and unmerged**. No sample is removed or
repeated, and no vector/layout/component cause is inferred from this epoch.
Native ReleaseSafe and actual WASI each pass 12 runner tests, including real
scalar token/stats comparison, high unsigned-cost dictionary selection and
single-model allocation-failure sweeps. All initial wires are byte-equal and
decode with pinned Brotli 1.2.0. Full six-round CI, controls and requested-heap
acceptance are not run after the failed screen.

A fresh existing-ELF public q8 profile retains 3502 samples. Leaf symbol cycles
are outer inlined-model planning **39.75%**, initial optimal parsing **19.83%**,
and external `matchLength` **4.38%**, including provenance/SHA/IO/kernel work.
Positive readelf line coverage is **47.5349%**; compiler line zero remains
unattributed. This directs structural work without treating sample percentages
as clean encoder stage time. A functionality audit also confirms ordinary
Deflate reusable facades still lack a prepared matcher/workspace capability;
close that gap with explicit ownership, warm allocation checks and unchanged
wire/error/resource contracts before further isolated codec tuning.

The next prepared fixed owner must retain typed matcher/token capacities and
a stable shared Lease. Current arena-operation cap/profile scopes allocate a
fresh control state, so retained arena backing alone does not meet zero-heap
warm acceptance. Preserve the existing scan/tiny/full hash dispatch and table
geometry; do not replace the full matcher with tiny tables. Validate different
inputs inside the declared capacity with alloc/resize/remap denied after
prepare, including profile, exact cap and inherited sticky-budget cases.

## 2026-11-26 controlled Zstd index: full L3 gain, rejected by level controls

The [complete controlled-index screen](zstd/controlled-index-20261126/README.md)
compares frozen `2d798695` public L3 with exact contiguous three-byte hashes,
block-local matching with history, compact prefix positions and reduced index
initialization. The scalar Source oracle, global sampling stride, extra-edge
seed order and duplicates, search budget 24 and complete output remain fixed.
Earlier hash/local and incumbent-bound variants remain separate pilot epochs;
their differences do not identify individual component contributions.

Six AB/BA rounds retain all twelve original full Silesia inputs: 72 pairs and
144 timed Vort operations. Candidate/baseline throughput is **1.177268x**, with
paired round-block 95% CI **1.167228–1.188514x**. NCI reaches **1.275295x** and
the weakest primary row, x-ray, **1.084735x**. All primary gates pass. Fifteen
64 KiB public L3/level1/2/8/19 controls retain 90 pairs; **NCI L8 is 0.975321x**
and **Mozilla L2 is 0.979686x**, below the unchanged **0.98x** floor. The complete
candidate is **rejected and unmerged**. No samples are removed or repeated.

NCI L8's paired CI is **0.936610–0.999424x**; Mozilla L2's is
**0.945163–1.002156x**. The latter includes parity and does not establish a
causal source regression. Both point estimates still fail the declared floor;
the slow samples remain evidence, rather than grounds to waive the controls.
The independent reducer validates input/ELF/reference identity, raw samples,
chronology, settings, length mixes and initial complete wires. Its exit 1 is
the expected acceptance failure with evidence integrity passing.

Native Zstd passes 1491 tests, encoder controls 62, scalar/planner native and
actual WASI 23 each, and untouched-baseline large-prefix record equivalence one.
The public requested-heap adapter passes 170 resource operations and two
allocator self-tests. Seven multi-block inputs save **524288 bytes** of peak;
full NCI peak remains **10762377 bytes**, while cumulative allocation falls
**492794119 → 359100679 bytes**. Request counts are unchanged. Backing OOM
injection covers ordinals 0/1, not all ordinals or actual host exhaustion.
These requested-heap figures are separate from RSS and throughput acceptance.

Secondary full-input default-preset observations give main/candidate throughput
**0.077467x/0.090284x** libzstd 1.6.0 at **1.066077x** reference size. Window
policies differ; this reserved development-host window is neither a matched
quality frontier nor industry leadership. Only the main column is merged.
Next isolate the failing level paths and remove whole-operation waste without
changing quality, budget, original inputs or the control gates.

## 2026-11-26 public Zstd L3 evidence correction and actual search profile

The allocating Zstd benchmark now captures the effective public primary from
`nativeEncodeLevelDiagnostics`, matching `Pair.encodeVort`. Default L3 reports
controlled greedy, search budget 24 and rep-beam disabled; previous raw samples
reported the nominal resolver's auto/64/true. Explicit native options retain
their exact settings, and `fast_parser` is now recorded for level 1/2 policy.
This changes evidence metadata, not compression policy or throughput.

The [actual public L3 profile](zstd/public-l3-profile-20261126/README.md) uses the
original full NCI bytes and libzstd 1.6.0 with the default level entry point.
Its function-symbol leaf cycles are controlled `matchAt` **21.84%**, `planReuse`
**20.43%**, `findBest` **17.09%**, and `Index.seed` **13.26%**. Their non-overlapping
sum is **72.62%** of all sampled cycles, including reference, checksum and
validation work. `planReuse` self cost includes inlined helpers; inclusive
percentages overlap and the root call chain is partially unresolved. These
are diagnostic observations, not a clean-host throughput or pure-stage matrix.

Prioritize the current controlled-search/index lifecycle before assuming
winner-only fallback planning is the dominant L3 cost. The current L3 path
does not run the historical legacy five-parser sweep or per-call candidate
threads. Historical Zstd source is unchanged, but the original nonquiet
throughput epoch and incorrect nominal metadata stay historical and unmodified.

## 2026-11-26 adjacent extents and frontier caps: pilot screens not accepted

Both isolated follow-ups retain the accepted V7 output bytes and original
public q8/generic/window16 settings. Each two-round screen covers all twelve
fixed 64 KiB inputs, with one AB and one BA pair per row: 24 pairs/48 timed
calls. The [4 KiB exact adjacent-match cache](br/match-extents-20261126/README.md)
gives throughput **0.992589x**, NCI **0.983570x**. The
[known-frontier comparison cap](br/frontier-caps-20261126/README.md) gives
**0.998768x**, NCI **0.986424x**. Both also close the lazy proposal cache before
optimal scratch; these combined variants do not isolate any single cause.

All initial complete wires pass full-byte comparison and pinned Brotli 1.2.0
decode. Extent fixtures and actual scalar parser comparisons pass; frontier
fixtures prove that a result equal to the comparison cap still examines later
cheaper distances. Correctness did not produce the required ROI. The routes
remain unmerged, all raw samples/negative rows remain, and the pilot does not
claim a confidence interval or completion of the full acceptance matrix.

## 2026-11-26 paired search and exact histogram proposals: accepted increment

The [complete V7 gate](br/histogram-proposals-20261126/README.md) combines the
frozen compact paired-model search with one operation-owned complete-histogram
proposal workspace. Every call still collects and validates its own Analysis;
exact full fields permit complete proposal reuse across changed commands.
Successful misses transfer the actual allocated counts, and scope cleanup
uses the original codec allocator. Reference/mode/prefix choosers remain
independent. Actual public profile prefixes observe all 29 reused slots across
103 context calls, each with zero scorer work.

The reserved development-host A/B retains 90 pairs/180 timed calls and all
complete current wires. Candidate/baseline elapsed is **0.847995x**, round-block
95% CI **0.846121–0.849327x**, or throughput **1.179252x**. NCI is
**1.217277x** over twelve pairs (**1.214241x** primary-six); the weakest primary
row is x-ray **1.078964x**. The unchanged 1.03x/1.20x/0.98x gates pass.
Separate public q4/q11/legacy-ratio controls pass **1.010035x/1.030885x/1.012216x**
on the declared Mozilla 64 KiB input, retaining 18 pairs and 1224 timed calls.
Independent raw/CI recomputation confirms all gates without removing samples.

Fourteen inputs pass all 42 requested-heap cap operations plus six
backing/ownership/handoff tests. Silesia peak/allocated/acquisition attempts
are **0.794524x/0.839044x/0.932828x** baseline. **Opaque peak grows 4.33%**;
the accepted scope retains this negative control, below the architecture's
5% bound. These force-moving requested-heap figures are not RSS or isolated
cache contributions. Final native Brotli passes 1721 tests with one platform
skip; x86/actual WASI real-chooser gates and narrow Deflate/Zstd controls pass.

The 72-pair null-workspace plumbing control gives elapsed **1.004252x** relative
to frozen paired-only, CI **0.998935–1.009597x**. It neither isolates pointer
layout nor proves a layout regression. Earlier v4/v5/v6 remain rejected as
standalone candidates; their different timing epochs do not identify V7's
component contributions. This accepted internal increment does not establish
historical-regression repair, reference parity or industry leadership. Continue
removing repeated search/emission and unnecessary retained phase lifetimes.

## 2026-11-26 complete context histograms: larger sharing boundary observed

The [isolated untimed diagnostic](br/context-histograms-20261126/README.md)
captures all 103 context analyses across the twelve original 64 KiB rows.
Twenty-nine full histograms repeat; all complete proposal fields also match.
Twelve repeats have different full-command field digests, one in every row.
The other seventeen have the same digest, which does not prove exact command
equality. No snapshot or context event is truncated. These observations show
why one immutable command-slice owner misses real sharing opportunities; the
earlier zero full-model/command-result hits did not establish zero histograms.

The repeated records execute 20,379 tree scorer calls. All original analysis,
scoring and allocation/cleanup still execute. Sixteen preallocated diagnostic
slots request 4,218,496 bytes outside codec heap. Direct observer time is
outside the original context stage timers, but outer wall times and cache
effects remain instrumented. This is neither a throughput sample nor a
measured codec heap/RSS improvement. Twelve focused runner tests and all
twelve public wire/round-trip checks pass; initial wire hashes match c2.

Preserve the complete canonical bytes, command digests, fixed chooser policy,
source closure, events, proposals and independent reduction. Prototype a
charged owner that shares complete proposals after actual collection and
threshold handling with full histogram equality. Keep current wire bytes and
the original whole-operation, NCI and public-control gates. There is no accepted
optimization or preset change in this evidence publication; v4/v5/v6 remain
rejected. The controlled historical q8 regression below remains unresolved.

## 2026-11-26 parameter-family context reuse gate: not accepted

The isolated v6 parameter-family owner shares complete literal/context
proposals only for one immutable input and commands slice. Changed slices
retain independent analysis. Fixture, real analysis and full Brotli checks
pass (full ReleaseSafe 1715 passed, one skipped); all twelve primary initial
wires and three public controls remain byte-identical to c2.

Actual public q8 diagnostics show Mozilla proposal builds **10 to 9**. The
observed same-commands parameter branch slots perform **2 to 1** analyses;
NCI remains **8 to 8**. Mozilla details cover only the first eight builds in
each run, while the complete event sequence remains available. Do not compare
their different detail prefixes as full-row totals or invent a cache-hit ID.
Fourteen-case resource checks pass 42 caps and six budget-layer tests. Whole
requested-heap peaks are unchanged; twelve-row allocated bytes are
**0.995316x** baseline under the existing forced-moving policy.

The completed reserved-host primary A/B retains 90 pairs/180 timed calls.
Candidate/baseline elapsed is **0.982508x**, paired round-block 95% CI
**0.975227–0.990389x**, or throughput **1.017804x**. It misses the unchanged
1.03x aggregate target. NCI is **0.986537x**, below its 1.20x repair target;
ooffice **0.974209x** and samba **0.969958x** miss the 0.98x control floor.
Separate q4/q11/legacy-ratio controls pass at **1.002646x/1.046321x/0.998576x**,
but do not override the primary failures. All observations and outliers stay
in the evidence. **The candidate remains rejected and unmerged.**

The result does not prove the new borrowed pointer or option layout caused
the losses. A follow-up must isolate the parameter-family boundary while
retaining actual analysis reuse and measure any layout-only control before
attributing the regression. Smaller scoped work still needs the declared
whole-operation and control gates; correctness alone does not justify adoption.

## 2026-11-26 compact single-DP gate: not accepted

The isolated v5 candidate compacts the first modeled parser as well as the
paired feedback solve. Native, x86 and actual WASI focused checks pass 22/22
each; full Brotli ReleaseSafe passes 1710 tests with one skip. All twelve
primary initial wires and three public-control initial wires remain identical
to the c2 baseline. Separate resource checks pass fourteen inputs with three
caps each, plus six budget-layer backing/ownership tests.

Its completed reserved-window primary A/B retains 90 pairs/180 timed calls.
Candidate/baseline time is **0.936338x**, paired round-block 95% CI
**0.931581–0.941412x**, or **6.80%** whole-matrix throughput improvement.
NCI throughput is **1.164719x**, below the unchanged **1.20x** target.
The separate public controls retain eighteen balanced process pairs and
1224 timed calls: q4 reaches **1.000125x**, q11 with the explicit 8 KiB
command-state cap **1.031473x**, and legacy ratio **0.976641x**.
Ratio therefore misses the unchanged **0.98x** floor. Its broad interval
does not justify removing observations or calling the control passed.

The candidate **fails the merge gate** and stays unmerged. Compared with the
original baseline, twelve-row requested-heap peak is **0.737182x**, cumulative
allocated bytes **0.806787x**, and acquisition requests **0.909190x**.
Compared with v4, those resource ratios are **0.973771x**, **0.947674x** and
**0.969000x**. Forced-moving requested heap is not native RSS; unchanged
Dickens/opaque peaks show why static DP savings cannot predict whole-operation
peak. The v4/v5 timing epochs are separate and do not establish their causal
source delta. Preserve both rejected experiments before choosing the next
measured context/entropy-planning boundary.

## 2026-11-26 original allocating-preset matrix complete

The original fixed-source `4a9796b0` collector completed **216/216** conditions,
set its manifest complete flag and exited zero on its original session. An
independent full verifier also exited zero and checked all raw samples.
The eighteen codec/size/preset groups each contain twelve corpus rows, with
1224 primary-reference measured pairs and 432 Deflate warmup rounds retained.

Full-file Vort/reference throughput is **0.368214x/0.147514x** for Deflate
L6/L9 (L9 reference libdeflate L12), **0.077671x/0.378423x** for public Zstd
L3/L19, and **0.064354x/0.918724x** for Brotli q8/q11. Compressed sizes remain
separate tradeoffs in the complete archive. These numbers are observations
from the original development-host epoch with recorded concurrent validation;
they are not quiet-host acceptance or current-main performance claims.
In particular, `4a9796b0` predates the subsequently merged complex fixed
block-length Huffman repair. Keep the old checkpoints and their CI identities
alongside the full results, without replacing them or restarting the collector.

## 2026-11-26 reserved-window paired-search result: not accepted

The [completed reserved-window run](br/modeled-search-20261125/README.md)
retains all 90 balanced pairs and 180 timed calls on the same frozen v4
candidate. The original full-file q11 child finished naturally; its parent
collector stayed stopped throughout the measurement window and resumed
automatically afterwards. The original fixed-source matrix reached 193/216
completed conditions after resumption.

Candidate/baseline time is **0.925487x**, with paired round-block 95% CI
**0.922318–0.928477x**: whole-matrix throughput improves **8.05%**. Every
initial complete wire remains identical, and the weakest control reaches
**1.013705x** throughput, above the 0.98x floor. However, NCI reaches only
**1.181598x** throughput, below the predeclared **1.20x** repair target.
The candidate therefore **fails the merge gate**. Overall improvement and
resource savings do not lower or replace that weak-row threshold.

This was a temporarily reserved development-host window, not an industry
ranking. Its original copied analysis metadata still calls the statistics
nonquiet; the separate reservation and process interval records establish
the actual run boundary without silently rewriting the raw report.

Keep v4 unmerged and preserve its complete positive and negative evidence.
The next isolated candidate compacts the first modeled parser's costs/steps
and avoids its final token duplication while retaining the existing wider
bounded branch for unsupported inputs or prices. Static DP storage can be
8 bytes per position; actual full-encoder speed, peak, quota refusal and
allocation cleanup still require fresh validation and a fixed-source A/B.

## 2026-11-25 bounded paired modeled-search screening

The [four-stage evidence package](br/modeled-search-20261125/README.md)
preserves the paired-search prototype, exact both-model cost pruning,
first-modeled-pass pruning and compact four-anchor index as separate frozen
experiments. Each stage retains 90 AB/BA pairs and 180 timed calls across the
same twelve 64 KiB inputs. These compare current-policy baseline `c2c8f250`
against the candidate; the inherited `old_exact` slot is not the historical
`0a673757` source used by the regression audit.

The final screen gives candidate/baseline elapsed **0.924485x**, a descriptive
paired round-block 95% CI of **0.922207–0.926429x**, and throughput **1.08168x**.
All initial complete wires match the baseline byte for byte; timed outputs
are checked by length/mix rather than complete hashes. The pair-only stage
gains only 2.92%, below the default 3% gate. Final NCI throughput is **1.19040x**,
still below the declared 20% weak-row repair target. These nonquiet
development-host screens do not establish acceptance or competitor parity.

Separate untimed requested-heap measurements cover fourteen cases with
unlimited, exact-peak and peak-minus-one caps. Final/baseline geometric peak
is **0.757038x**. Exact caps preserve the same wires, peak-minus-one returns
`WorkingMemoryLimitExceeded`, and caller-freed outputs leave zero live
requests. This uses forced-moving growth in the existing tracking allocator;
it is not a native RSS, stack or in-place-remap measurement.

The reviewed source passes the native, 32-bit x86 and WASI focused gates
(14 tests each) and the full Brotli ReleaseSafe suite (1710 passed, one
platform-specific skip). The optimization remains unmerged while the existing
driver waits for the original full-file q11 sample to finish naturally, then
runs the frozen candidate in a reserved measurement window and resumes the
original 216-condition collector. Preserve the source, corpus and predeclared
gates when making the acceptance decision.

## 2026-11-25 q8 feedback cost and repeated search work

The [single-flag control](br/q8-feedback-control-20261125/README.md) changes
only q8 entropy feedback in an isolated source overlay. Across the fixed
twelve 64 KiB rows, feedback-on requires **2.08130x** time (descriptive paired
CI **2.07622–2.08690x**) for size **0.984679x**. Mozilla, ooffice, sao and x-ray
return identical complete wires in both controls. This does not authorize
dropping the other eight rows' real compression gains from the default.

The same bundle rejects the initial exact-result cache idea: all twelve rows
have distinct modeled prices and distinct command sequences. It also records
four-pass search profiles with current wire identity. Every row's three
modeled passes repeat the same chain/match/choice work counts; NCI makes
9,754,161 match-length calls across those passes. Its modeled index cost is
only 1.10%, so merely retaining the index is insufficient. The next candidate
shares one bounded match scan between two independently priced DPs and avoids
materializing the worst-case 16 MiB frontier. It remains an unmerged experiment
until complete wire, resource and whole-operation performance gates pass.

## 2026-11-25 controlled q8 source regression

The [same-probe source A/B](br/q8-source-regression-20261125/README.md)
compares exact historical source `0a673757` with `c2c8f250`. Both use public
allocating q8/generic/window16, Zig 0.16.0 ReleaseFast, identical target
features and CPU2, with encode and free inside one uninterrupted timer.
Across twelve 64 KiB Silesia inputs the current/old paired time ratio is
**3.8338x** (fixed-row round-block 95% CI **3.8176–3.8523x**), for encoded
size **0.956581x**. All twelve rows are slower. The 90 pairs include six
primary rounds per row and six extra rounds on three weak rows; the aggregate
uses only the primary rounds. Pinned cross-library decoding passes every
initial complete wire, and the old source reproduces the three historical
weak-row goldens with explicit window16.

This confirms a substantial q8 latency regression on the declared source A/B,
not merely a change in benchmark reporting. The development-host run overlaps
the original CPU15 collector, so it remains observational and does not rank
competitors or isolate one commit's contribution. Default q8/q9 feedback
expansion is an identified mechanism, but intermediate-source controls are
still needed to attribute its exact share. Prioritize recovering throughput
with shared search/context work; further default effort expansion must pass
speed/size gates together.

## 2026-11-25 historical preset latency audit

The [history audit](performance-history-audit-20261125/README.md) freezes
and uniformly reduces the twelve matching 64 KiB inputs. Brotli q8's recorded
allocating latency grew 3.66687x while encoded size fell to 0.956581x of its
old value. Input hashes, requested Brotli 1.2.0 library bytes and reference
wire hashes agree. The old source is exactly `0a673757`; the newer allocating
epoch is `4a9796b0`. Window requests, warmup and CPU differ, so these are
cross-epoch observations rather than a controlled source A/B. Deflate L9's
same-input/same-wire 64 KiB history gives 0.925715x time and does not show an
aggregate slowdown; it is not credited as a causal source speedup.

Commit `cf4e870c` explicitly enabled q8/q9 entropy feedback and recorded
increased text-row latency. A default quality policy that does more work for
smaller output must be described as a speed/size tradeoff, not a speed win.
Investigate that workload expansion together with repeated parse/context
preparation. The audit binds the historical source for a new controlled
comparison against `c2c8f250` using one allocating probe and explicit window16;
it does not attribute the whole observed increase to one commit.

## 2026-11-25 complete 1 MiB allocating-preset cohort

The [same current epoch](modern-encode-refresh-20261125/README.md) now retains
all 72 conditions at 1 MiB as well as the original 64 KiB cohort. Across twelve
corpora, Deflate L6/L9 reaches 0.38189/0.15748x reference throughput at
1.0130/1.0045x size (L9 reference is libdeflate L12). Public Zstd L3/L19 is
0.08173/0.47871x throughput and 1.0259/1.1840x size; Brotli q8/q11 is
0.06099/0.30491x throughput and 0.9881/1.0472x size. The actual full-file
cohort continues in the original process. Those pending rows remain outside
this checkpoint; no codec speedup is attributed to the measurement repair.

## 2026-11-25 current allocating-preset checkpoint

The [current 64 KiB checkpoint](modern-encode-refresh-20261125/README.md)
binds source `4a9796b0` to all twelve Silesia files, six declared policies and
408 measured primary pairs. Its complete 72-row cohort gives throughput
ratios to pinned references of 0.39837/0.52638 for raw Deflate L6/L9,
0.09814/0.66500 for public Zstd L3/L19, and 0.01363/0.27483 for Brotli q8/q11.
The Deflate HQ reference is L12. Brotli uses generic/window16, with an explicit
8 KiB command-state cap only on q11. Size tradeoffs and intervals remain
separate in the linked report. The declared 216-row run continues through
1 MiB and actual full files; this checkpoint does not establish those results.

The [measurement contract repair](encoder-evidence-contracts-20261125.md)
eliminates Deflate's independent fastest-round selection and reference
compressor reuse outside the timer. It also aligns Brotli's HQ preflight and
timing options, declares the effective window/HQ mode, and warms both sides
before a numeric-quality round. These are measurement fixes, not codec wins.

## 2026-11-25 explicit-window q8 diagnosis

The [six-run q8 diagnostic](br/q8-explicit16-profile-20261125/README.md)
uses the actual generic/window16 policy and preserves both frozen NCI/Mozilla
wire hashes. It records 16/33 successful physical outputs per run, of which
15/32 are ultimately lost. Wire events are complete in all runs; Mozilla's
auxiliary context details retain only the first eight of ten calls. The
wire-only evidence gate validates that exact prefix and labels its coverage
incomplete. Thirty Python regression tests and two Zig binding tests cover
the measurement contract; the bundle can be verified offline.

The traced cost distribution changes the next priority: NCI spends 74.25% in
four optimal parses, while Mozilla spends 56.07% in context proposals. Fixed
literal/command/distance split wire and evaluation events are all zero in
these two rows. Mozilla instead has 24 adaptive-distance evaluations and ten
physical outputs, all eventually lost. Shared split-planning time has no
per-family subdivision, so zero candidate events do not prove zero planner
cost. These instrumented shares route investigation; they do not predict a
normal-encoder speedup or establish competitor parity.

## Next measured structural boundary

The [fixed block-length repair](br/fixed-length-complex-20261125/README.md)
closes a functional blocker found while preparing this boundary: legal five-
and six-symbol fixed length trees previously failed at `simpleCode`. Shared
RFC geometry and prepared complex length codes now preserve simple wire bits
and pass focused native/32-bit/WASI and complete-stream libbrotli checks. The
full native Brotli suite passed 1707 tests with one platform-specific skip.
No throughput gain is attributed to this functional repair.

Current q8 can execute a lazy seed plus four optimal proposals, followed by
context and split candidate families. Static dictionary proposals are already
precomputed, and command-model lifetime reuse is already present. Do not
repeat those completed changes or apply old two-pass/wire-count descriptions
to the current source.

The fixed command/distance split family remains a bounded reuse design from
the source audit: several literal/context variants still reconstruct entropy
plans and physical wires. `encodeEntropySplitCandidateAllocRecorded` enumerates the
variants; `encodeEntropySplitWireCandidateInternalAllocRecorded` then reaches
the complete command writer. A shared symbol/entropy plan with exact counting
could retain the existing candidate order and strict-smaller rule while
emitting only that family's winner. `prepared_command_distance.supported`
currently excludes split shapes, so its common plan cannot simply be reused.

Prioritize per-pass search profiles for NCI's four optimal parses and complete
context-preparation/scoring details for Mozilla's ten context calls. Establish
which model-independent index/frontier work can be reused without changing
any parser decisions, then test that structural change with ordinary public
encoding and exact wire gates. Keep the fixed-split family as a later target
until a declared corpus row actually exercises it. Physical wire counts must
exclude pure evaluations and include replaced intermediate winners; truncated
event logs cannot establish exact counts. No encoder performance prototype is
adopted from these diagnostics alone.
