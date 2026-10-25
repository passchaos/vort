# Brotli non-HQ Large Window history functional baseline

Date: 2026-10-26. Baseline: `e047456b`; feature revision:
`2f421462ce9399dfa9d4febcc39028dba2ce95c2`. The final streaming ratio-candidate
preservation correction is included. Required functional validation is complete,
including later test-only adaptive coverage at
`2adbe60b64767220acc037317ff5bda48d8d0276`. Codec, runtime and test-only source
scopes remain distinct. Earlier
`18a7fc6d` results retain their own source epoch. No performance improvement is
assigned.

## History and matching scope

Explicit Large Window encoding lets non-HQ q2+ and legacy non-fragment streams
retain accepted history up to the advertised distance `(1 << window_bits) - 16`.
History grows with actual accepted data; window30 does not immediately allocate
a 1 GiB buffer. q0/q1 keep fragment-local matching and zero cross-block match
history. Standard-format policy is unchanged. Explicit Large Window bytes may
change when a newly reachable match wins.

Public Large Window one-shot q2...q11 and legacy non-fragment paths also consider
the wide augmenter with empty external history. Such a far copy refers to an
earlier position in the same input, not history from a previous call. The
streaming/chunked/reusable paths separately exercise sources in an old block
and short current blocks. These are distinct capabilities and test geometries.

The shared near matcher still uses only the last 65,535 bytes and its original
u16 token representation. A dedicated Large Window history augmenter creates
wide copy commands with usize distances from available history and the current
block. Three-byte anchors admit matches of 3...258 bytes. Each search is bounded
to 512 chain candidates and reachable-band strides of 1/2/4/8/16. These limits
do not search every possible source distance or prove a globally optimal parse.
The older standard/ratio augmenter retains four-byte anchors and its 16-byte
minimum match.

The final selection contract retains existing standard and ratio candidates for
comparison rather than replacing them with the new matcher. Review of the
recorded `18a7fc6d` stage found that its Large Window streaming ratio path used
the new augmenter in place of the older four-byte/min16 alternative. The final
`2f421462` path now evaluates both old and new alternatives with strict
full-wire selection. The earlier omission and its results remain separately
recorded.
Ordinary quality q11 still inherits the
complete q10 result on the no-shared-dictionary route. Prepared shared-dictionary
encoding already has a different candidate pipeline and no universal q11<=q10
size guarantee; adding its wide candidate does not establish that guarantee.

Original commands and literal-only alternatives remain candidates. q2/q3 must
also consider the far-history alternative when the near parser finds no copy.
Actual full-wire encoding costs, including distance and entropy declarations,
select a replacement only on a strict improvement. A larger advertised window
is a legal distance bound, not a promise to emit a far copy for every input.

## Memory admission and state

History capacity is admitted before wire publication; the prepared append then
has no fallible allocation. Adaptive evaluation reserves rollback history
capacity before clearing branch storage. Multiple branch/history buffers,
matcher tables and candidate outputs remain real allocations under the existing
requested-heap authority. One history length is not a complete memory bound,
and this increment does not establish RSS or peak-memory leadership.

The logical history length is limited by accepted input and the advertised
window. Allocation reserves use geometric `ArrayList` growth, so actual capacity
may exceed the needed logical span and even the logical window bound. Quotas
account for those allocation bytes and all simultaneously owned copies; the
length limit must not be described as an exact allocated-capacity limit.

Metadata and flush do not reset match history. Reset and a next-stream transition
start an independent frame. Existing alias protection, caller-output lifetime,
OOM and progress contracts remain part of validation; capacity preparation does
not create a general whole-call rollback guarantee.

## Completed target and aggregate validation

Independent target tests cover far source bytes in an old block,
short current blocks and distances 65,536/70,000, so a within-current-block match
cannot substitute for retained history. A window17 fixture discards sources
older than its 131,056-byte distance bound. The tests also cover q0/q1
fragment behavior, standard-format bytes, metadata/flush continuation,
reset/next-stream separation, exact quota admission and branch rollback.
One-shot and reusable cases additionally check physical far copies within a
single input, with the ordinary no-shared-dictionary q11/q10 comparison scoped
separately from dictionary routes.

Final native Debug, native ReleaseFast and x86 ReleaseFast filtered contracts
each pass 27/27 executions, including imports. The earlier independent matcher
filter's 20/20 executions have a different import/source scope, not 20 distinct
matcher cases or a substitute for the final combined gate.

Each final native/x86 differential campaign passes 450/450 cases and 450
commands: 423 streaming cases and 27 one-shot cases. The reported actual-far
subset is 324 (297 streaming plus 27 one-shot); the 27 window-boundary cases
are classified separately and are not added to that subset counter. Each
campaign independently decodes 300 newly produced frames with the actual loaded
libbrotli 1.2.0 reference. Counts are executions and fixture categories, not
exhaustive distance/candidate coverage or every quality/input/platform combination.

Complete wires, headers, progress and retained-history tails agree across
architectures. Geometric capacities and memory-profile fields remain
target-specific: a recorded native/x86 capacity pair is 104,576/104,512 bytes.
Those fields are excluded from cross-target equality, retained separately and
not described as equal memory use. The source manifest contains 1,901 files
at the feature revision, with SHA-256
`c5826893636702133534c07f2f82c9fa3a77729682a94bf1d16ca660b2a9766b`.

The initial two reference campaigns each passed 441 and failed nine cases.
All nine were legacy-fast first 64 KiB blocks across three APIs and three
windows, incorrectly sent to the tiny 32 KiB parser. The repaired path uses
the full hash planner for larger blocks, preserving block size, search budgets
and sampling. Added checks cover the nine routes, standard-format 64 KiB bytes
and OOM after 65,536 accepted bytes followed by retry against fresh output.
The initial failures and their earlier source identities remain archived; they
are functional failures, not benchmark results or skipped coverage.

Final legacy-wire refresh matches 216/216 main comparisons and 120/120 reset
comparisons against saved old artifacts. All 336 new streams pass independent
reference decoding; this refresh does not rerun or recompile the old encoder.
The earlier full old/new report and its 672 decoding checks retain their original
pre-fix source epoch. The final refresh report has SHA-256
`1b5da6691fabc72d29a4628df809e7ac85d511e8ccac4064a104a5f41e4b4c66`.
The intermediate `18a7fc6d` refresh is preserved separately; its 336 decodes are
not added to the original 672 or the final 336 as one uniform-source run.
CLI help passes 7/7, and the 32-bit-only host-overflow gate passes an independent
x86 ReleaseFast 20/20 execution scope including imports.

The complete native ReleaseFast family at corrected codec revision `2f421462`
passes five build steps and 1432 tests, with one skipped out of 1433.
The skipped 32-bit-only host-overflow gate is covered by the separate x86
execution above, not inferred from the filtered 27-test run. The final build
check passes 182/182 at that codec revision. Earlier 27-test/family/build
results retain their source epochs and are not relabeled as these final runs.

An additional test-only adaptive matrix passes on native Debug, native
ReleaseFast and x86 ReleaseFast, still within 27/27 filtered executions per
configuration. The unchanged aggregate count does not mean unchanged coverage.
It uses q2/window25, explicit 65,536-byte adaptive blocks and a 70,000-byte
prefix, exercising a 70,000-byte history snapshot and 135,536-byte split/grid
histories with an actual far copy. Exact/below budgets, reset and targeted growth
refusals for history, history_snapshot and adaptive_split_history check state
before clear: committed history, output bits, recent distances and context are
preserved, while already accepted current input remains visible. Retry after
lifting the refusal reproduces fresh output.

This coverage is test commit `2adbe60b`, whose 1,902-file manifest has SHA-256
`124606e1cd3bfc8bd165c86d5123232c47cfad2e00d8c3177fdf73828eee6a74`.
`source-epochs/adaptive-test-delta.json` records only the root test hook and the
new adaptive test module. The unchanged codec and external reports stay bound
to the 1,901-file `2f421462` manifest; full/reference runs are not relabeled as
test-only reruns, and 450-case campaigns are not repeated for unchanged code.
The evidence directory is
[`data/br-large-window-history-20261026/`](data/br-large-window-history-20261026/).
The initial parser-failure source is retained with a reverse reconstruction
matching its original source hash, rather than attributed to the repaired code.
Final native/x86 campaign files are retained in lossless `.tar.xz` archives with
hash manifests and separate plain JSON reports. Compressed historical files
retain a reversible identity map; archive file counts are not test counts.

## Recorded size and requested-memory examples

The pre-correction `18a7fc6d` examples compare the same 70,258-byte input under
two specified routes. q2 incremental output changes from 70,270 to 70,039 bytes,
and its observed maximum copy distance changes from zero to 70,000; retained
history grows from 65,535 to 70,258. Native requested peak increases from
1,148,487 to 1,307,577 bytes and x86 from 1,086,202 to 1,243,780. More retained
history has a real allocation cost despite the smaller output.

q8 chunked output changes from 70,051 to 70,053 bytes, two bytes larger. The old
stream already contains a 70,000-distance copy; the new stream has two copies
totalling 261 copied bytes versus the old single 257-byte copy. Requested peaks
remain 2,598,592 bytes native and 2,271,396 x86 for this route. Its internal
history length is unobserved, not zero. This earlier negative size point remains
archived rather than being overwritten by the correction.

The final `summary-retained.json` uses the same old evidence and actual
`2f421462` target output. q2 remains 70,270→70,039 bytes with the same history
growth and requested-peak increases. q8 changes from 70,051 to 70,050 bytes,
one byte smaller than old and three bytes smaller than the pre-correction
candidate, with one 258-byte copy at distance 70,000. Its native/x86 requested
peaks remain 2,598,592/2,271,396 bytes. The final summary SHA-256 is
`3f1b834823f0bb0f7703010524cf5fe51bcf66e4232d52aa143d57719f47c0c3`.
These narrow examples do not establish universal ratio or memory improvement;
they are not throughput, RSS or peak-process-memory measurements.

The earlier [general Large Window baseline](brotli-large-window-functional-baseline.md)
and [metadata baseline](brotli-metadata-functional-baseline.md) retain their
original source, wire and test epochs. Their 65,535-byte history descriptions
and performance observations are not refreshed as this increment's results.
Broader encoder quality/performance, explicit core Zstd magicless APIs and
bounded XZ worker encoding remain separate functional or optimization work.
