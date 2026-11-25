# Encoder optimization status

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
