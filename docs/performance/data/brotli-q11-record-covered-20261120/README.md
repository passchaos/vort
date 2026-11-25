# Brotli inherited fixed-record floor prototype

This directory contains isolated source snapshots and functional/requested-heap
evidence. The workspace repository was not edited. No clock, throughput sample,
RSS comparison, or performance acceptance judgement is part of this prototype.

## Read-only architecture finding

The ordinary public call reaches `src/br.zig:4683`
`encodePlannedStreamWithOptionsAlloc`, which routes ordinary quality settings at
line 4725 into `encodePlannedStreamQualityWithOptionsAllocRecorded`. At line 5447,
q11 copies the complete options, changes only quality to q10, and recursively
executes the entire quality pipeline. The returned complete q10 winner is merged
into q11's incumbent at line 5505. Strict-smaller arbitration subsequently keeps
the incumbent no larger than that q10 floor.

There is already a `q11_covered_by_q10` guard at line 5769: on inputs through
64 KiB q11 skips its deeper optimal pipeline. The old description that these
rows necessarily run another q11 fixed/modeled pair is stale. Inputs above
64 KiB retain q11's deeper bounded optimal pipeline; q10's optimal input ceiling
is 64 KiB, so these are not two interchangeable optimal passes.

The fixed-record branch at line 5780 still executes for both q10 and q11. Its
generator `encodeRecordOptimalCandidateWithOptionsAlloc` at line 7100 has no
quality, trained model, history, or incoming command-state argument. Both calls
have the same immutable input, advertised format/window, metadata, effective
distance-parameter-search flag, and literal-context-disable flag. It repeats
`recordOptimalPlanAlloc` (line 7055), record-distance refinement, command
construction, 64-shape distance-parameter screening, and full wire creation.
Its distance writer can build a default wire and one alternative wire. The
already-inherited complete q10 winner covers both, so the second generator
cannot strictly improve the incumbent even if q10 selected another candidate.

`production.patch` adds `!q11_covered_by_q10` to this one branch, with its proof
comment. It does not relocate recursion, add a candidate, or retain another
parser/command/model working set. The reusable model-independent fact is
coverage of the exact same record generator, not a cache of its mutable scratch.

This guard is valid only in this quality controller after the same-options q10
operation has completed successfully and its complete winner has been retained.
It must not be exported as a generic "quality is q11" skip. If record inputs or
q10-vs-q11 effective parameter policies change, the coverage proof must be
rechecked or the skip disabled. In particular, adding quality/model/history/
distance-cache inputs to the record generator requires a new key/proof.

## Existing reuse and larger required boundary

`command_candidate_group.zig:4` keeps `shared_common` only inside one immutable
command group. Its ordinary gate is `br.zig:10825`; the command/distance key in
`prepared_command_distance.zig` includes command pointer/length, window,
distance parameters, compound size, output position, recent-distance ring, and
distance-policy flags. Preferred contexts and eligible adaptive literal/distance
products already borrow this common model. This is not cross-quality sharing:
q10/q11 lazy chain budgets are 384/512, so their commands cannot be assumed equal.

`prepared_adaptive_literal` already exactly counts ordinary adaptive literal
splits. `countedAdaptiveLiteralSupported` at line 12514 explicitly excludes
`literal_entropy_plan != null`. Joint literal mode/tree assignment still calls
`literal_joint_context_split.chooseAlloc` at line 12031, returns only a block
plan/context modes/map/tree count, and then routes its candidate at line 12206
through `encodeEntropyAdaptiveLiteralContextWireCandidateAllocRecorded` and the
materializing split writer. Winning frequencies/alphabets/code lengths are not
retained in the returned `literal_entropy_plan.Plan`.

Fully removing ordinary q11 full-q10 recursion is a larger increment: it needs
an operation owner for policy candidates and winning emitter recipes, while
preserving separate q10/q11 parser budgets, commands, entropy feedback models,
literal/split products, final byte-length ties, and complete candidate coverage.
Joint assignment/tree products can be interned only after immutable commands,
literal positions, block assignments, modes/maps and incoming wire state match.
Input identity alone is insufficient.

Streaming already compares q10/q11 block policies at line 10290. Explicit HQ
whole-frame execution at line 10506 compares a q10 frame, an eligible same-shape
legacy q10 floor, and a q11 frame; the q11 frame also compares block-local q10
and native candidates at line 10399. Model/recent-distance/frame/history states
must remain distinct. A complete-frame q10 result cannot be used as a generic
block-local model or history checkpoint. This prototype changes none of those
routes and adds no HQ family.

The existing `docs/performance/brotli-match-evidence.md` records a rejected
match-frontier cache; this increment does not retry that cache or reinterpret
predecessor-only `PreparedOptimal` as shared match evidence.

## Prototype evidence

`before.jsonl` and `after.jsonl` contain 95 paired jobs:

- 60 target jobs: fixed-record 4/8/16/32/64 KiB, one-shot/reusable, standard
  windows 16/24 or explicit Large Window 30, with/without metadata;
- 9 q10 controls;
- 14 chunked/incremental controls across the five record sizes, plus selected
  metadata/wide-window settings;
- 4 non-record controls, 2 legacy ratio controls, 4 RAW/serialized-RAW dictionary
  controls, and 2 existing explicit HQ controls on 1 KiB.

Both sides use native ReleaseFast codec source and the identical frozen Debug
record object. This is sufficient for paired functional/requested-resource
evidence; it is not a matched production throughput build. All options use
generic mode. The command-state ceiling is explicitly 8 KiB on quality jobs.
Every job performs normal, exact-peak cap and peak-minus-one operations. The
4 KiB target also exercises backing-allocation failures 0/1/2 and clean retries.

The probe-only `audit_record_plan_calls` counter measures entries into
`recordOptimalPlanAlloc`; raw `record_wire_calls` measures entries into the
record candidate generator, not the number of physical lower-level wire emits.
These identical counters are confined to `before/src` and `after/src` and are
not in `production.patch`. The separate `clean-before/src` and `clean-after/src`
copies use the exact clean production sources without these codec counters.

`reduce.py` independently reconstructs every input, compares complete wire hex,
checks native decode markers, requested/profile peaks and allocator balance,
and decodes 91 jobs through system libbrotlidec 1.0.9 with full input consumption.
The four external-dictionary jobs use native attached-dictionary decode and
complete before/after wire identity; system dictionary attachment is excluded.

Observed target record-plan and candidate-generator calls fall from 2 to 1;
21--31 allocation attempts and 296,624--2,389,734 cumulative allocated bytes are
removed per target call. All target peaks are unchanged. All control work,
peaks and success wires are unchanged. Exact caps succeed and peak-minus-one
returns `WorkingMemoryLimitExceeded` on all 95 jobs per side. Actual tracked
live bytes end at zero and allocated/freed totals agree throughout.

The raw `profile_final_live` field needs its lifetime qualifier: reusable
`total_reusable.Scope.finish` detaches the call-scoped profile before encoder
deinit. Its last report can retain 80 control bytes or 1,048,656 control/matcher
bytes after the actual allocations have been freed. This is not post-deinit
live storage. Before/after normal observer snapshots agree, and the independent
allocator proves zero actual final live bytes. One-shot/chunked/incremental
observer reports do end at zero.

## Reproduction and review

The emitted executables accept optional start/end job ids. Commands contain no
timing samples:

```sh
./before-probe > before.jsonl
./after-probe > after.jsonl
python3 reduce.py
./clean-before-probe > clean-before.jsonl
./clean-after-probe > clean-after.jsonl
```

The original clean codec files are `br.production-before.zig` and
`br.production-after.zig`; the input fixture and probes are preserved in this
directory. `provenance.sha256` pins sources, objects, executables and reports.
`production.patch` passes `git apply --check` and application/cmp on the
isolated `patch-check/src/br.zig` baseline.

Existing follow-up validation entries are:

- `br quality record candidate honors the advertised small window`;
- `br quality eleven retains the complete quality ten winner`;
- `br planned quality and mode matrix is deterministic bounded and reusable`;
- q10 entropy-feedback monotonicity/allocation-failure tests;
- `zig build -j2 test-br-total-memory` and
  `zig build run-br-record-optimal-shape-gate`.

These workspace build gates were not started by this task. Acceptance still
requires the mainline functional campaign to finish, broader modes/parameter
flag/cross-architecture checks as appropriate, and later matched ordinary-call
throughput sampling on an idle performance host. The source patch remains an
isolated prototype pending that decision.

## Clean native and narrow portability confirmation

`clean-summary.json` confirms the complete 95-row clean production matrix:
normal/exact wires and decode, requested resources, exact caps, cap-minus-one
refusals, and backing-failure retries agree with the instrumented evidence.
Its codec source has no counter shim. The final production comment explicitly
names q11. Clean-after was rebuilt and the full matrix rerun for that comment
epoch. Counter evidence preserves its original comment-only source epoch.

`portability/summary.json` describes a separate **12-row** matrix per target and
side, executed on x86-linux-musl and wasm32-wasi. It is not 95-row portability.
The ids are `0,3,5,60,66,69,70,83,85,86,87,88`: three q11 4 KiB targets covering
standard16, standard24+metadata, LargeWindow30+metadata; q10 standard16 and wide
controls; chunked, incremental, nonrecord, legacy, RAW, serialized-RAW and
existing explicit HQ 1 KiB controls.

All 12 portable normal wire SHA256 values per side/target equal the already
verified clean native reference. The separate native Vort decoder checks normal,
exact-cap and retry wires: 27 native decode receipts per side/target, 108 total.
Each portable side/target also passes its own 12 exact-peak caps, 12 peak-minus-one
refusals and three backing-allocation failure/retry checks. Target cases retain
the required allocation-work reduction; controls retain their work/peak within
each architecture. No foreign library runs inside these portable processes.

Portable record objects are compiled from the same frozen source for each
target in ReleaseFast. The native reference used the paired frozen Debug native
record object. Wire parity is proven directly; numeric resource values are
compared within each architecture rather than treated as cross-architecture
equivalent layouts.

`portability/collect.py` records every command and exit code, and
`portability/reduce.py` validates the explicit subset against
`clean-summary.json`. The native decoder source is `native_decode.zig`.
