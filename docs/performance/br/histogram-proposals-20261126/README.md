# Paired search and complete histogram proposals, 2026-11-26

**Accepted under the unchanged increment gates.** Across the fixed twelve
64 KiB inputs, V7 improves allocating public q8 throughput **17.93%** against
the pinned c2 baseline. NCI reaches **1.217277x**, above the predeclared 1.20x
repair target, and the weakest primary row reaches **1.078964x**. Every complete
initial wire remains byte-identical. All three public controls pass.

This is a temporarily reserved development-host comparison, not competitor
parity or completion of the three-codec product goal. The controlled historical
q8 regression remains separate evidence; these timing epochs must not be
multiplied into a claimed historical-source or reference-library speed ratio.

## Implemented boundary

The candidate combines the previously frozen compact paired-model search with
a new single-slot complete-proposal workspace. The earlier v4/v5/v6 candidates
remain rejected as standalone experiments. V7 is a new measured combination;
the earlier timing epochs do not identify the contributions to its gain.

One quality operation owns the workspace and lends it through private wire
options. The route is enabled for generic q8, standard windows and inputs of
at least 8 KiB. Every proposal call still executes the original `collectAnalysis`
and admission/geometry checks. Successful analyses compare `literal_count`,
all 256 total frequencies and every `[4][64][256]` context frequency. There is
no hash-only equality or struct-padding comparison. Only the fixed complete
pruned chooser uses the workspace; reference and mode/prefix choosers keep
their independent paths.

A hit returns the complete suffix/up-to-16/full proposal values and frees its
fresh analysis. A successful miss transfers that actual analysis to the owner
and releases the preceding one. Errors never publish or substitute old
proposals. The operation frees the retained object through the original codec
allocator before its outer memory lease closes. No allocator adapter, global
cache, extra lease or hidden failure-interval reset is introduced.

The workspace, policy and focused fixtures live in the existing
`literal_context_split/` submodule. Profile counters now distinguish complete
proposal reuse from fresh scoring; a hit records zero actual scorer work while
retaining this call's literal/active-symbol counts and complete proposal shape.
The updated profile contract explicitly checks those zero-work conditions.

The final public diagnostics observe **103 context events and 29 reuses**.
The fixed eight-detail profile prefixes contain all 29 observed reused slots;
the other seven event details are unavailable. This is an untimed prefix
observation, not a new claim of complete profile-detail coverage or throughput.

## Whole-operation performance

Both primary processes call public allocating q8/generic/explicit-window16
encoding with one symmetric encode/free warmup. Each measured interval
continuously covers encode, wire-length mix and owned free. Fixture I/O, SHA,
JSON and cross-library decode stay outside that interval. There is no warmed
persistent encoder workspace across operations.

The primary campaign preserves **90 balanced pairs / 180 timed calls**.
All twelve rows receive six primary rounds, three AB and three BA. Dickens,
Mozilla and NCI receive six additional balanced pairs each. The aggregate uses
only the common six rounds; the NCI repair row uses its twelve pairs and also
discloses the primary-six value.

| Gate | Observed | Result |
| --- | ---: | --- |
| Aggregate throughput at least 1.03x | **1.179252x** | pass |
| Paired aggregate elapsed 95% CI below parity | **0.846121–0.849327x** | pass |
| NCI throughput at least 1.20x | **1.217277x** | pass |
| NCI primary-six throughput, disclosed separately | **1.214241x** | observation |
| Every primary row at least 0.98x | minimum **1.078964x**, x-ray | pass |
| Complete initial wire identity | all twelve full-byte comparisons equal | pass |

Aggregate elapsed is **0.847995x** baseline. Its interval resamples the fixed
twelve-row matrix's common paired round blocks, not corpus rows. All original
samples and outliers remain. The NCI gate is the unchanged point-estimate
threshold; its interval is retained without claiming its lower throughput
bound exceeds 1.20x.

The separate public-control campaign uses the original Mozilla 64 KiB bytes,
its own matched probe and six AB/BA pairs per entry. It retains **18 pairs,
36 processes and 1,224 timed calls**. q4 uses 100 calls per process; q11 and
legacy ratio use one. q11 explicitly uses an 8 KiB command-state cap.

| Public control | Throughput | 95% throughput CI | 0.98x floor |
| --- | ---: | --- | --- |
| q4/generic/window16 | **1.010035x** | 0.995298–1.031923x | pass |
| q11/generic/window16, explicit cap8 | **1.030885x** | 1.016150–1.044123x | pass |
| legacy ratio/generic/window16 | **1.012216x** | 0.999600–1.030229x | pass |

q4 and ratio intervals include parity, so their point values are control
observations rather than established speedups. These three rows cover one
declared control input, not an additional full-corpus competitor matrix.

The null-workspace plumbing comparison retains another **72 pairs / 144 timed
calls** against the frozen paired-only build. Null/paired elapsed is
**1.004252x**, with round-block 95% CI **0.998935–1.009597x**. This controls the
cache-disabled option/call-path plumbing, not solely pointer layout. It does
not establish a layout regression or enter the primary acceptance gate.

## Requested heap and safety

Fourteen inputs, including RLE and opaque controls, pass **42 resource-cap
operations**: fourteen unlimited, fourteen exact-peak and fourteen peak-minus-one.
Unlimited/exact outputs match c2 byte for byte. Every peak-minus-one call
returns `WorkingMemoryLimitExceeded`. Tracker/profile peaks agree, allocation
ledgers balance, and freeing the caller output leaves zero live requested bytes.
The separate backing/ownership/handoff gate passes **6/6**.

| Scope versus c2 | Requested peak | Cumulative allocated | Acquisition attempts |
| --- | ---: | ---: | ---: |
| twelve Silesia inputs | **0.794524x** | **0.839044x** | **0.932828x** |
| all fourteen inputs | **0.811730x** | **0.830604x** | **0.926605x** |

Acquisition attempts are alloc + resize + remap. Measurements use the same
force-moving growth policy and include the retained analysis. They exclude
caller inputs/oracles, stack, allocator bookkeeping and native RSS.

**Opaque peak increases 4.33%**, from 6,076,086 to 6,339,262 requested bytes.
Acceptance preserves this negative control: the increase is below the
architecture's 5% limit and accompanies the supported target throughput and
aggregate memory wins. It is not presented as universal memory improvement.
The figures describe the whole combined operation, not a measured isolated
workspace or pointer-layout contribution. Earlier and final resource runs,
including this same negative result, remain independently retained.

## Source, platform and verification

The base is `b199db72`; production Brotli/LZ source there matches the frozen c2
baseline `c2c8f250302ca2f223740076482dd95b1788eeb1`. Seventeen codec/test files
form the integration. The original full identity manifest has **2,201 entries**:
2,200 source files plus one generated Python-cache artifact. That cache is
retained only to reproduce original identity checks and is excluded from Git
source integration. Original eighteen-entry delta receipts are preserved.

All source identities match before/after final probe builds and sampling.
The primary baseline ELF is frozen c2 reuse; its retained stamp and byte hash
are verified, while original per-stage build exits are unavailable. That
boundary is explicit. Final candidate/profiling/control build argv and exits
are retained, using Zig 0.16.0 ReleaseFast, GNU x86-64,
`skylake+pku+sgx`, CPU2 for samples and one codec thread on an i7-10700K.

The final complete Brotli ReleaseSafe suite passes **1,721 tests, one platform
skip**. Owner fixtures pass seven runner tests. Real chooser gates pass twelve
runner tests on native, x86 and actual WASI; those twelve contain five focused
tests plus seven import tests. Cases cover complete fields, different legal
commands, replacement, fresh/score OOM, real lease/sticky-limit recovery,
null/invalid spans and actual profile shape. Deflate's unchanged optimal/BT
paths and Zstd's unchanged allocating/reuse path pass their narrow controls;
those counts include imported tests and are not whole-codec completion claims.

The first full suite's outdated baseline-score assertion failed once; its
complete logs, source overlay and identity manifest remain. The correction
requires explicit zero work on reuse and retains wire, allocation/error and
event-link contracts. Untimed directory/executable setup failures are also
retained and contribute no measured samples.

Pinned libbrotli 1.2.0 decodes all 24 primary initial wires exactly. Full-byte
and SHA checks apply to initial wires; timed outputs are checked by length/mix.
Source/probe/reference/ELF/command and raw sample identities are archived.
Code-size and integrated CLI/WASM smoke results are retained with their actual
scope. This does not claim full historical-regression repair or industry best.

## Portable evidence

`raw.tar.gz` and `resources.tar.gz` retain exact raw data, required frozen
source/probe closures, binaries as exact gzip members, reference libraries,
fixtures, original failures and final verification records. Their bindings
enumerate every member by length/SHA and bind the uncompressed ELF identities.
The primary archive stores identical content once by SHA256; its complete
logical-path mapping reconstructs all 8,807 original files without changing
their bytes. Resource snapshots retain their separate exact file members.
`summary.json`, `control-summary.json`, `null-workspace-summary.json` and
`independent-performance-summary.json` preserve the reductions and gate decision.

```sh
python3 /path/to/histogram-proposals-20261126/verify.py
```

The verifier hashes published inventories and raw membership, reconstructs
complete initial-wire/source/ELF/command/sample and performance gates offline,
and checks the independent summary. It never executes a codec or original argv.

## Next work

Continue q8 architecture work with fewer remaining match searches and losing
candidate emissions. Restrict retained proposal lifetime where later phases
have no reuse, then validate opaque peak without changing this milestone's raw
data. Preserve the scalar oracles, current wires, quota/OOM classification and
full non-regression controls. The three-codec industry-best goal stays active.
