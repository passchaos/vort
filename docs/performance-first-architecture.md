# Performance-First Architecture

Status: proposed architecture and migration contract.

This document makes performance a durable Vort product property instead of a
sequence of unrelated micro-optimizations. It is normative for new Deflate,
Zstandard, and Brotli performance work. Existing public behavior remains
authoritative until a migration slice replaces it and passes the gates below.

**MUST**, **MUST NOT**, **SHOULD**, and **MAY** are requirements, not claims
that the current implementation already has the described architecture.

## 1. Product contract

Performance is Vort's first optimization objective. Correctness, wire
compatibility, deterministic behavior, bounded resources, and hostile-input
safety are hard constraints, never tradeable metrics.

Feature work precedes measured performance work only when it:

- removes a blocker to a faster architecture;
- enables a clearly valuable user workflow;
- closes a compatibility or safety defect; or
- creates evidence required to choose the next performance investment.

Another option, wrapper, candidate, or format mode is otherwise lower priority
than removing duplicated work from an established hot path.

“Performance” includes throughput, compressed size, small/cold latency,
streaming overhead, allocations, requested heap, RSS, stack, generated text,
parallel scaling, and x86-64/AArch64/WebAssembly portability. No single point
establishes product leadership.

## 2. Evidence and audited facts

### 2.1 The current-source rule

A result is current only when one evidence bundle binds:

- exact Vort revision and dirty-state digest;
- exact competitor revision/binary, flags, and build mode;
- corpus and compressed-fixture hashes;
- target, CPU/features, OS, compiler, affinity, and power policy;
- public API, codec settings, dictionary, chunk schedule, and threads;
- warmup, raw samples, sample ordering, and background-load notes;
- report schema and reproduction command.

This document deliberately does not hard-code a permanent “current Vort
commit.” Each report captures the checked-out revision. Older clean evidence
remains historical and MUST NOT be presented as a current ranking. The numbers
below are audit observations used to route work, not future-source claims.

### 2.2 Structural snapshot

| Area | Audited fact | Architectural implication |
| --- | --- | --- |
| Deflate | `src/deflate.zig` is about 24,371 lines | Facade, algorithms, wrappers, policy, and tests need ownership boundaries. |
| Zstandard | `src/zstd.zig` is about 48,964 lines | Candidate, entropy, execution, API, and test work cannot evolve independently enough. |
| Brotli | `src/br.zig` is about 44,000 lines | Planning, repeated materialization, emission, decoding, and tests obscure repeated work. |
| API shape | One-shot and streaming often follow separate implementations | An optimization or fix does not automatically benefit both modes. |
| Dispatch | Hot specialization is dominated by compile-time routing | Instantiation and `.text` grow; a native binary cannot select for the actual CPU. |
| Evidence | Many gates are smoke, minimum, or loose ratio checks | Green often proves execution/schema, not a supported improvement. |

Large roots are a symptom. Moving declarations without narrowing ownership or
removing repeated work does not satisfy this architecture.

### 2.3 Codec bottlenecks

Deflate duplicates one-shot/streaming matcher work, wrapper copies, and
per-call allocation. Audited chunked dynamic throughput at 4 KiB, 64 B, and
1 B was about 40%, 39%, and 30% of contiguous. The best ROI is one reusable
workspace and matcher, direct sinks, one streaming-first fast engine, then
runtime dispatch.

Zstandard repeats complete candidate materialization and entropy emission.
Some operations create workers per call or permit nesting. Options decode first
creates owned output and copies it. Audited compressed-corpus decode was about
0.81--0.88x libzstd; HQ encoding took about 3.1--4.6x reference time. The best
ROI is policy separation, a metadata-only `BlockPlan`, winner-only emission,
persistent scheduling, and direct options decode. Note that
`formatted_decode.owned` already decodes directly into its exact allocation;
`into`/`append` stage a complete decoded buffer before publishing to preserve
all-or-nothing publication and charged-budget accounting. A direct sink for
those two forms therefore needs a transactional publication/budget API rather
than a simple copy removal.

Brotli q8 materialized a complete wire about 18 times; audited throughput was
0.0283x libbrotli. Small decoder matrices are strong, but audited real one-shot
decode took about 1.52--1.55x reference time. The best ROI is a shared candidate
graph, exact counting, one winner emission, non-recursive q11/q10 comparison,
and one prepared meta-block for all decoder tiers.

## 3. End-to-end architecture

```text
public facade -> context/workspace -> checked format/reference boundary
              -> codec match analysis graph
              -> codec plan/candidate graph
              -> codec entropy plan -> exact winner -> one physical emit

compressed source -> checked parser -> prepared decode plan
                  -> runtime-selected fast/reference kernel -> sink/history

persistent scheduler: only around coarse independent units
evidence: around every layer, never an afterthought
```

### 3.1 Layer responsibilities

| Layer | Owns | Must not own |
| --- | --- | --- |
| Public facade | stable names, option translation, convenience allocation, error mapping | codec algorithms or a second one-shot engine |
| Context/workspace | persistent tables, stream state, bounded block scratch, capacity preparation | hidden hot-call growth or global state |
| Format/reference | checked parsing, bounds, compatibility, simple scalar truth | target-specific optimization policy |
| Match analysis graph | anchors, distances, lengths, predecessor/repeat facts | bitstream buffers or final policy |
| Plan/candidate graph | choices, state transitions, exact/bounded costs, stable tie-breaks | fully serialized losing candidates |
| Entropy planning | counts, tables, prices, serialized-table description | physical full-block output for every candidate |
| Winner-only emit | bounded direct write and transactional final state | candidate search or policy arbitration |
| Prepared decode plan | validated ranges, tables, output bound, kernel requirements | reparsing during execution |
| Kernels | allocation-free execution over validated spans | allocation, public options, parsing, threads |
| Runtime dispatch | one-time host route installation | per-symbol feature checks |
| Scheduler | persistent coarse jobs, worker contexts, ordered commit | symbol/match/entropy inner loops |
| Evidence | raw samples, counters, provenance, gates | codec semantics or corpus policy |

### 3.2 Context and transaction rules

Encoder and decoder contexts classify memory as persistent tables, frame/stream
state, or bounded per-block scratch. Named preparation methods grow capacity;
matchers, planners, emitters, and kernels do not allocate secretly.

Every workspace declares requested bytes, alignment, maximum retained capacity,
reset behavior, worker lending, and alias rules for input/output/history/
dictionary. Worker scratch is allocated when the scheduler context is prepared,
not once per job.

One-shot is an adapter over the streaming core. It may create a temporary
context for convenience, but it does not select a different matcher, planner,
model, or decoder because input happens to be contiguous.

Preparation and emission are transactional. Failure cannot install entropy
tables, repeat offsets, checksums, history, or output length from a partial
unit. Streaming retains and resumes the same prepared object that one-shot
drives to completion.

### 3.3 Analysis, planning, and winner-only emission

Match discovery produces reusable codec facts. Multiple policies may view the
same graph but must not rebuild an equivalent index unless evidence selects a
materially different structure.

A candidate is metadata, not bytes. It records policy identity, token/sequence/
command references, boundary transitions, exact or safe bounded cost, entropy
plan identity, final codec state, and evidence counters.

Exact costs include headers, tables, alignment, end markers, and state
transitions. Conservative lower bounds may reject losers; the winner has an
exact cost. Equivalent entropy plans may be interned only with collision-safe
keys containing every semantic input.

Only the selected handle reaches physical emission. Debug/evidence builds may
serialize a loser to check accounting; production must not serialize all
candidates and compare output slices.

### 3.4 Prepared decode

Parsing produces a `PreparedBlock`, `PreparedMetaBlock`, or equivalent
capability whose construction proves the executor's invariants. Malformed
input is rejected before an unchecked kernel observes invalid ranges.

- Deflate fixed and dynamic tables converge on one executor contract.
- Zstandard prepared literals/sequences share resolved frame/block state.
- Brotli one `PreparedMetaBlock` feeds small, middle, and full executors.

Preparation is resumable and transactional. Execution does not rebuild tables
or parse public options.

## 4. Share infrastructure, not codec hot loops

The following MAY be shared:

- explicit source/progress abstractions and bounded direct sinks;
- context/workspace lifetime and requested-heap accounting;
- allocation/RSS/stack instrumentation;
- CPU feature detection and dispatch-table installation;
- scheduler adapter, worker lifetime, cancellation, and ordered commit;
- corpus loading, provenance, samples, statistics, and reports;
- guards, canaries, determinism, and differential helpers.

The following remain codec-specific:

- admissible match edges and history/dictionary semantics;
- level/strategy/quality policy and tie-breaking;
- candidate graph and entropy model;
- Deflate blocks/Huffman decisions;
- Zstandard literals, sequences, FSE, repcodes, and frames;
- Brotli commands, distance cache, contexts, clustering, trees, and meta-blocks;
- prepared objects, executor tiering, bit emission, and state commit.

Do not build a generic “LZ planner,” “entropy codec,” or symbol executor whose
type parameters hide different algorithms. Share storage and lifetime
protocols; specialize codec hot loops.

## 5. Target layout and module scale

```text
src/<codec>.zig                  public facade
src/<codec>/api/                adapters and option translation
src/<codec>/context/            persistent encoder/decoder state
src/<codec>/workspace/          sizing, ownership, scratch
src/<codec>/format/             checked wire parse/write
src/<codec>/reference/          scalar/reference algorithms
src/<codec>/encode/analysis/    match evidence
src/<codec>/encode/plan/        policy, candidates, exact costs
src/<codec>/encode/entropy/     codec entropy planning
src/<codec>/encode/emit/        winner-only emission
src/<codec>/decode/prepare/     validated decode plans
src/<codec>/decode/kernel/      scalar and accelerated executors
src/<codec>/dispatch/           runtime routes
src/<codec>/tests/              focused tests mirroring production
src/<codec>/test_support/       independent fixtures/oracles
```

Rules:

- a public facade MUST stay below 2,000 lines;
- a production module SHOULD stay below 1,500 lines;
- a production module above 3,000 lines MUST split before gaining another
  responsibility;
- generated tables/frozen data live in named data modules;
- tests mirror the production hierarchy and MUST NOT accumulate in a mega root;
- splitting without narrowing ownership does not count.

## 6. Codec roadmaps

### 6.1 Deflate

P0 — highest ROI:

- introduce reusable encoder/decoder contexts and explicit workspace sizing;
- route one-shot through the streaming engine and unified matcher;
- give raw/zlib/gzip and fixed/dynamic paths direct sinks;
- remove wrapper copies where alias contracts allow;
- add runtime dispatch for prepared Huffman and match-copy kernels.

P1:

- represent stored/fixed/dynamic/split choices as lightweight plans;
- reuse match evidence and count exact bits without serializing losers;
- isolate wrapper checksum state from raw block emission;
- install dictionaries/history directly into reusable contexts.

P2:

- add measured x86-64/AArch64 kernels;
- tune block policy from current full-corpus evidence;
- fuse checksums only where end-to-end measurement wins;
- delete legacy one-shot code after wire/error parity.

### 6.2 Zstandard

P0 — best serial and parallel ROI:

- split level/strategy policy from mechanics;
- introduce shared `BlockAnalysis` and metadata-only `BlockPlan`;
- prepare entropy descriptions but emit only the winner;
- decode options directly into caller output;
- borrow a persistent scheduler; forbid per-call spawn and nested MT.

P1:

- compose checked parsing into reusable prepared decode plans;
- reuse indexes only where counters prove equivalent rebuild work;
- keep repcodes, entropy tables, dictionary, and history transactional;
- runtime-dispatch literal, sequence, and copy executors;
- make incremental and one-shot use the same executor.

P2:

- improve HQ search/price updates after duplicate emission is gone;
- tune policy against matched current-source competitors;
- extend seekable NUMA placement only after scaling gates;
- add other parallel units only with independent ownership and successful A/B.

### 6.3 Brotli

P0 — required before another HQ candidate family:

- build a shared command/match candidate graph;
- exactly count headers, maps, trees, commands, and distances;
- intern equivalent clustering/entropy products safely;
- materialize the winning meta-block exactly once;
- replace recursive q11 full-q10 encoding with shared policy comparison;
- construct one `PreparedMetaBlock` for all three decoder tiers.

P1:

- reuse matcher, command, histogram, cluster, and prefix scratch;
- converge one-shot/incremental meta-block state;
- route real one-shot decode through prepared executor tiers;
- dispatch lookup/refill/literal/copy kernels at runtime;
- preserve distance-cache/context state over suspension.

P2:

- improve parse and cluster quality after single emission is proven;
- add AArch64 counterparts to measured x86 kernels;
- share tier infrastructure without merging tier hot loops;
- reconsider parallelism only after serial P0/P1 gates.

Brotli does not adopt a scheduler in the near term: repeated serial planning
and emission, not missing threads, is its audited bottleneck.

## 7. Runtime CPU dispatch

The context resolves a dispatch table once for the actual host and options.
Hot loops enter a selected executor or stable function pointer; they do not
test features for every symbol.

| Target | Required route | Optional measured routes |
| --- | --- | --- |
| x86-64 | scalar | SSE2/SSSE3, AVX2, BMI2, ERMS as applicable |
| AArch64 | scalar | NEON and later proven target features |
| wasm32 | scalar | `simd128` behind build/feature and runtime coverage |

Compile-time selection remains appropriate where one artifact cannot execute
multiple variants, notably WebAssembly. It must not be the only selection for
native multi-feature binaries.

Each fast kernel needs boundary/overlap tests, randomized scalar differential,
malformed-input tests at preparation, and target-specific performance evidence.
Scalar remains buildable and tested on all supported targets.

## 8. Parallel policy and the `parz` pilot

The exact local audit reference is:

- checkout `/home/passchaos/project-z/parz`;
- revision `04ab4e1c61919bc30017f71d4c96d5f783832c85`;
- package `0.0.1`, minimum Zig `0.16.0`;
- evaluated scope: persistent `Pool`, coarse task/`Future`, cancellation,
  affinity, and deterministic range/fold primitives.

This identifies an audit source, not a dependency. Vort first defines a private
scheduler interface with serial and pilot adapters. No public codec API exposes
a `parz` type, and no dependency is added before the pilot passes.

Policy:

- scheduler lifetime is caller-owned and persistent;
- worker scratch is prepared once;
- jobs are independent frames/blocks/dictionary candidates, never symbol,
  match-extension, DP, entropy, or bit-emission loops;
- output ranges are owned and committed in deterministic order;
- per-call thread spawn and nested multithreading are forbidden;
- an operation entered from a worker runs serially or uses reserved lanes.

First pilot: Zstandard seekable encoding. Implement the internal adapter, pin
the evaluated revision in the pilot branch, prepare worker contexts, run whole
frame jobs, and A/B 1/2/4/8 workers on real corpora before dependency adoption.

Local `parz` evidence includes 6.23x range-fold and 7.95x compute results, but a
real large-input Spectra workload regressed about 1.9--2.7%. Only the
operation-specific Vort gate decides adoption.

Stop the pilot if scaling gates fail, one-worker throughput loses over 2%, a
profile shows per-call spawn, nested work wakes another pool, ordered commit
needs a second full output copy, or worker scratch/stack misses resource gates.

## 9. Benchmark policy and the `harnessz` pilot

The exact local audit reference is:

- checkout `/home/passchaos/project-z/harnessz`;
- revision `80117591603f35b1b084b9a5eafd040810ab4b3d`;
- package `0.0.1`, minimum Zig `0.16.0`;
- evaluated scope: `run`, `compareMany`, raw samples, Welch and Mann--Whitney,
  process isolation, baseline storage, hashing, and provenance.

Audit score: about 8/10 as a generic substrate, 4/10 as a complete compression
platform. Missing compression needs include paired statistics, declared
multiple-comparison correction, full WASI coverage, and complete domain
metrics. Therefore no dependency is added before a Zstandard pilot.

### 9.1 Ownership boundary

`harnessz` may own clocks, sampling, raw storage, generic summaries, process
control, baseline comparison, and hashing. Vort retains codec schema, corpus,
competitor build/invocation, streaming schedules, ratio/throughput definitions,
dictionary policy, and provenance schema v2.

Welch and Mann--Whitney are supporting analyses where appropriate. Vort must
add paired deltas/confidence intervals and predeclared matrix correction before
using a large report as a merge gate.

### 9.2 Two measurement lanes

Timing runs in-process: preload fixtures, prepare contexts, finish builds,
warm as declared, balance old/new or Vort/reference order, pin where supported,
and store every duration plus output checksum. It excludes startup, compilation,
and corpus loading.

RSS runs one case per child: capture peak RSS, status, timeout, and stderr while
codec instrumentation reports requested heap and allocations. Caller buffers,
retained context, scratch, and stack remain separately labeled.

Never merge child RSS and in-process timing into one unlabeled number.

### 9.3 Raw samples, hosts, and matrix

Store ordered samples, pair IDs, warmup observations, and exclusions. Report
median, ratio geometric mean, paired confidence interval, worst row, and count.
“Best of N” is forbidden.

CI proves build/correctness/determinism/schema, minimum samples, and gross
regression bounds. A dedicated quiet, pinned host approves narrow speed claims;
it records environment/power policy and runs no competing build.

Minimum current-source matrix:

- text, JSON, source, logs, binary, small, repetitive, already-compressed, and
  mixed real files;
- 64 KiB, 1 MiB, and full-file inputs;
- one-shot, reusable, and incremental/chunked calls;
- representative fast/default/HQ levels, with and without dictionaries;
- size, encode/decode throughput, requested heap, allocations, RSS, stack,
  generated text, cold/warm behavior, and weakest rows;
- x86-64 first, then AArch64; scalar and WebAssembly compatibility lanes.

Use versioned zlib/zlib-ng/zlib-rs/libdeflate, libzstd, and libbrotli only where
wire mode, API, and settings match. Unmatched levels are explicitly labeled and
do not become equivalent-quality rankings.

## 10. Quantified gates

These are milestone policy. They may be raised with stronger evidence. They may
be lowered only by a recorded decision with new reproducible evidence, never by
schedule pressure or a green historical report.

### 10.1 Hard constraints

Every merge requires exact wires when claimed, full-content/exact-consumption
differential decode, scalar/fast differential, malformed/truncated/overlap/
retry/boundary tests, promised determinism across workers, zero guard/canary
failures, and unchanged progress/error semantics unless explicitly versioned.

### 10.2 Codec performance gates

| Codec | Milestone | Gate |
| --- | --- | --- |
| Deflate | chunked dynamic 4 KiB | at least 85% contiguous throughput |
| Deflate | chunked dynamic 64 B | at least 65% contiguous throughput |
| Deflate | chunked dynamic 1 B | track always; no loss from pinned P0 baseline |
| Deflate | warmed reusable | zero codec allocations after preparation |
| Deflate | fast/default first | at least 0.5x matched reference |
| Deflate | fast/default product | throughput geomean at least 1.0x reference; disclose weakest rows |
| Zstd | decode convergence | at least 0.95x libzstd on initial current matrix |
| Zstd | decode product | every declared product row at least 1.2x libzstd |
| Zstd | HQ convergence | at most 1.5x matched libzstd encode time |
| Zstd | HQ product | at most 1.0x at the declared size/quality constraint |
| Zstd | seekable 2/4/8 workers | at least 1.6/2.8/4.0x the persistent one-worker path |
| Brotli | q8 architecture | at least 3.0x pinned pre-P0 Vort throughput |
| Brotli | wire materializations | reduce about 18 to exactly one winner |
| Brotli | per-call allocations | reduce at least 75% on q8 matrix |
| Brotli | requested-heap peak | reduce at least 50% on q8 matrix |
| Brotli | q0--q3 control | no row loses more than 2% throughput |
| Brotli | clustered control | at least 0.95x baseline throughput |
| Brotli | decode convergence | real one-shot time ratio to libbrotli at most 1.10x |

The q8 3x target is an internal architecture gain, not reference parity; the
0.0283x audited start makes that distinction mandatory.

### 10.3 Allocation, memory, text, and stack

- warmed context encode/decode makes zero allocations;
- convenience one-shot allocation is reported separately;
- requested heap or RSS may not grow over 5% without a supported throughput or
  ratio win and explicit decision;
- losing-candidate materialized bytes do not scale with candidate count;
- parallel memory is bounded context + workers × scratch + inflight output;
- every dispatch change records codec `.text` by symbol group;
- up to 2% text growth requires target-matrix improvement; over 5% blocks merge
  absent a decision proving an otherwise unavailable product win;
- stack is input-size independent and targets at most 256 KiB per synchronous
  call, 128 KiB per worker job, and 64 KiB per WebAssembly codec call;
- larger measured needs move to explicit workspace or block product release.

Stack measurement includes Vort local arrays and combines static inspection
with worst-case high-water probes.

### 10.4 Statistical merge/product gates

An exact-output change may merge with at least 3% dedicated-host median gain,
paired 95% confidence interval excluding zero on primary rows, and no material
control loss. Smaller effects require more samples and a predeclared practical
threshold.

A neutral structural slice must improve a gated resource, text, build time, or
ownership and remain within 2% on every primary throughput control. Product
leadership requires the full current-source matrix, never a microbenchmark.

## 11. Migration sequence

1. **Freeze evidence.** Generate a fresh matrix with raw samples, hashes,
   provenance, work counters, allocation/heap/RSS/stack/text/build baselines,
   and the top three end-to-end costs.
2. **Create seams.** Reduce roots toward facades, place tests with owners, and
   introduce source/sink/context/workspace interfaces without behavior change.
3. **Converge APIs.** Make one-shot drive reusable streaming state, remove
   wrapper copies, reach warmed zero allocation, then delete superseded paths.
4. **Separate choices.** Reuse match analysis, represent candidates as metadata,
   count exact entropy/total bits, and emit only the winner.
5. **Prepare decode.** Separate checked preparation from allocation-free
   execution and install runtime scalar/fast dispatch.
6. **Pilot evidence.** Use `harnessz` for one Zstandard matrix without moving
   Vort corpus/schema/competitor ownership or adding a dependency.
7. **Pilot scheduling.** Use `parz` for Zstandard seekable frames behind the
   internal adapter without adding a dependency.
8. **Retire/enforce.** Delete old engines, gate counters/resources/module size,
   refresh dedicated-host evidence, and adopt only successful pilots.

Each slice stays buildable, bisectable, reviewable, and independently measured.
There is no big-bang codec rewrite.

## 12. Stop criteria and decision log

Stop, isolate/revert, and reprofile when:

- correctness, compatibility, determinism, or resource bounds change;
- an abstraction adds a hot-path copy or allocation;
- a “shared” hot loop needs codec flags inside its iteration;
- three attempts move no named end-to-end metric by at least 3% and improve no
  other gated resource;
- compile time grows over 10% or codec text over 5%;
- dedicated-host results contradict the microbenchmark;
- parallel scaling fails or one-worker throughput loses over 2%;
- the superseded path cannot be deleted within two completed slices; or
- evidence cannot separate policy quality from implementation overhead.

Refactoring counts as progress only when it produces end-to-end speed, fewer
allocations/lower memory, smaller text/stack, deleted duplicate work, or a gate
against a demonstrated regression.

Record each material decision with:

```text
Decision, date, owner
Vort revision/dirty digest; competitor revision/build
Corpus/fixture hashes; problem and profile attribution
Options considered; chosen boundary; expected counters
Correctness/safety proof; raw sample artifact
Throughput/size/heap/RSS/stack/text results
Weakest/rejected rows; rollback condition; revisit trigger
```

Retain rejected experiments when they narrow the search. Their measurements
remain attached to their source epoch and never become current results.

## 13. Completion and immediate order

A codec has this architecture only when its root is a sub-2,000-line facade;
one-shot/streaming share state machines; warmed contexts allocate nothing;
analysis/planning/entropy/emission have distinct ownership; losers are not
serialized; decode is prepared/resumable; native selection is runtime with
scalar differential truth; parallel work is persistent and non-nested; and its
current-source matrix passes the codec gates.

Execute in this order:

1. freeze a fresh three-codec current-source epoch;
2. implement Zstandard `BlockPlan` winner-only emission;
3. implement Deflate workspace, unified matcher, and direct sinks;
4. implement Brotli candidate graph and one meta-block materialization;
5. converge prepared decode and runtime dispatch codec by codec;
6. pilot `harnessz` on the Zstandard matrix;
7. pilot `parz` on Zstandard seekable frames;
8. pin/adopt only pilots that pass product gates.

Until these conditions hold, Vort may have strong individual kernels, but it
does not yet have a performance-first codec architecture.
