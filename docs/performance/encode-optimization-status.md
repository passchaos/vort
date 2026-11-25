# Encoder optimization status

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
