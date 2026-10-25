# Brotli native q8 candidate profile

Date: 2026-10-25. Baseline: `b5606cd7`. The objective of industry-best
functionality and performance remains incomplete.

Existing Brotli stage tools measure legacy fast/ratio pipelines or q10/q11
command-state planning. They cannot attribute the actual public native q8
encoder's cost. This increment profiles that q8 pipeline through the same
lazy/optimal/context/split implementation used by ordinary callers, without
changing candidates, parser limits, quality settings or byte selection.

The diagnostic is fixed to quality8, generic mode, normal window16 and inputs
up to 65536 bytes. It has no HQ, shared-dictionary or Large Window override.
Normal APIs keep those broader features and invoke empty compile-time disabled
recorders. The diagnostic alone reads stage clocks and caller-owned event
storage; it does not install a global observer or add an encoder runtime flag.

## Timing and candidate report

`QualityQ8Profile` owns 512 event slots and a 32-frame timing stack. Each event
identifies its parent, origin (lazy/optimal), optional command variant, stage,
input/command count, elapsed inclusive/exclusive time, actual encoded length,
error and wire configuration. Strict size decisions record accepted status,
gain, incumbent length and known candidate event links. Released wire buffers
lose live identity so reused allocator addresses cannot identify an older
candidate as the current wire.

Direct-child inclusive time is subtracted once from each parent's inclusive
time. Exclusive values are aggregated by stage; outer residual is reported as
unaccounted. Negative/impossible duration, conversion/sum overflow or timing
depth exhaustion marks timing incomplete. Report capacity exhaustion marks
events truncated and returns unknown links, while coding and selection
continue unchanged. These flags must be checked before interpreting coverage.
No nested inclusive totals are added as if they were independent phases.

The main 64 KiB pipeline records lazy parse/commands, preferred context work,
split planning, every common wire attempt, distance-parameter work, optimal
parse/commands and final arbitration. Native dictionary auxiliaries for inputs
at most 4096 bytes remain coarse `other` work and mark detailed wire-attempt
coverage incomplete. The initial slice therefore does not claim a complete
small-input dictionary candidate report.

The profile borrows input and returns allocator-owned output. Optional total
heap caps and memory profiles use the same lease/ownership contract as ordinary
encoding. Fixed diagnostic event storage belongs to the caller and is outside
the codec's requested-heap ledger. The command-line tool allocates that storage
once before its measured calls and serializes only initialized events.

## Independent validation

The new contract filter passes 25/25 in native Debug, native ReleaseFast and
actual x86 ReleaseFast. The named product contract compares ordinary/profile
wire bytes, independent allocator requests and cleanup for empty, tiny,
repetitive, structured and random 64 KiB inputs. It replays selected allocation
failures, rejects oversized input before allocation, tests zero budget, and
measures a finite budget with a separate moving-allocation tracker before
checking exact-peak success and peak-minus-one denial. Event-capacity zero/one
keeps bytes and allocation behavior, while marking reporting truncated.

The tests check deterministic event semantics excluding clocks, wire linkage,
parent relations and ownership. `quality_profile_gate.py` independently checks
actual output reports against local input/executable identities, parent timing,
exclusive stage aggregation, strict selection/gain values and returned wire
links. Six malformed-evidence smoke tests verify those checks reject invalid
timing, stage totals, truncation, winner references and changed input.

Initial compile/type and missing record-object link failures are retained
separately from the successful three-target runs. The test and tool build
instructions attach the repository's existing record-planner object; no new
external encoder implementation is introduced.
The complete native ReleaseFast Brotli family reports 1420/1421 tests passed
with one skip. Final build checks pass 173/173, including the updated profile
tool. The five isolated file-ownership smoke cases reject same-path, spelling,
symbolic-link and hard-link aliases without changing input, then validate a
separate tiny output report.

## Measurements and boundaries

The old public q8 benchmark has a new fourteen-input five-round control using
frozen 64 KiB prefixes, q8/generic/default window policy and explicit local
libbrotli encoder/decoder/common files. Source/input/executable identities are
fixed and no compiler process is observed. Its competitor settings and window
differences are retained; quality numbering alone does not establish algorithm
equivalence.

The first Mozilla smoke, executed during builds, is retained only as a tool
verification. The accepted full profile runs after known compilers and family
tests finish, with five alternating ordinary/profile calls on each of fourteen
frozen 64 KiB inputs. All seventy profiled wires match both the normal encoder
and their previous baseline identities. Every round passes the independent
event/selection/parent-time gate, has complete timing and detailed wire coverage,
and remains within event capacity. Source/input/executable identities stay
unchanged and compiler observations are zero.

| Instrumented stage median | Mozilla 64 KiB | Source 64 KiB |
| --- | ---: | ---: |
| Outer call | 100.994 ms | 37.488 ms |
| Lazy parse | 1.235 ms | 1.589 ms |
| Lazy commands | 0.178 ms | 0.173 ms |
| Optimal parse | 7.685 ms | 11.044 ms |
| Optimal commands | 0.176 ms | 0.177 ms |
| Preferred/context preparation, exclusive | 69.792 ms | 7.258 ms |
| Split planning, exclusive | 1.710 ms | 1.068 ms |
| All wire encoding, exclusive | 18.291 ms | 13.715 ms |
| Distance parameter work, exclusive | 1.794 ms | 2.342 ms |

These are separate per-stage medians; their sum need not equal the median outer
call. Exact per-round accounting is checked from raw data. The median preferred
fraction is 69.17% for Mozilla and 19.30% for source. Classified non-`other`
stage coverage is at least 99.93%/99.88% in those five rounds; that fraction is
a wall-time attribution measure, not proof of CPU clock precision.

Both inputs materialize eighteen common wire candidates per round: ten from
the lazy plan and eight from the optimal plan. Mozilla's final 14216-byte wire
comes from the lazy plan's distance-parameter alternative; source's 11687-byte
wire comes from an optimal plan context proposal. The different winners and
stage proportions do not justify turning off either parser or its candidates.
Preferred work includes recent-distance scans, context proposal scoring and
selection overhead; the scope alone does not prove all 69.792ms belongs to one
function.

A separate ordinary public q8 benchmark also retains every old frame identity
and setting. Its version timing geometric point ratio is 1.01058x; this
instrumentation change is not presented as an encoder optimization or a
significant speedup. Throughput relative to the explicit experimental
libbrotli 1.2.0-dev (`558fc647`) build is 0.0282557x geometrically, with no wins.
Ordinary Mozilla/source medians are 99.807/36.913ms versus reference
1.607/1.283ms. Defaults retain Vort window16/reference lgwin22. The report keeps
all raw rounds and requested library-file hashes; those do not verify the full
loader dependency closure or establish all-quality/platform leadership.

The next bounded investigation separates actual recent-distance scans and
context proposal scoring inside the preferred scope, using the same q8 plans.
Existing analysis already merges histograms and has local memoization, so an
additional cache needs measured duplicate-score evidence. One candidate is
sharing an exact full-frequency tree-score cache within a single immutable
analysis; map-only keys must not be shared across modes. No context cache,
speed optimization or broader format milestone is claimed completed here.

The [evidence package](data/brotli-q8-profile-20261025/artifact-manifest.json)
retains frozen input/output identities, ordinary and instrumented raw rounds,
exclusive timing/event validation, budget/ownership tests, earlier failures,
ELF/source reviews and final checks.

After pulling with rebase, the linked q8 contract filter passes 25/25 again
and all five file alias/report smoke cases pass again. A full src/tools/build
before/after hash snapshot covers these handoff checks. Earlier timing-run
manifests cover core source and executable identity with supplemental Br-tool
bindings; the final full snapshot is not retroactively described as having
existed during those runs. No source changes occur between timing and handoff.
