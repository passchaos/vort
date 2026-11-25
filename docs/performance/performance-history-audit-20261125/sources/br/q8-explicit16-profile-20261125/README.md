# Explicit-window16 q8 candidate diagnostics, 2026-11-25

All six retained runs preserve the frozen q8/generic/window16 output. NCI
materializes **16 physical wires and loses 15 per run**; Mozilla materializes
**33 and loses 32 per run**. The complete event logs support exact physical
counts even though Mozilla retains only an eight-record context-detail prefix.
This is a diagnosis of current architectural work, not an optimization result.

The three rounds per input ran on CPU **2**, with one codec thread, on an
Intel Core i7-10700K. The executable is Zig 0.16.0, ReleaseFast,
`x86_64-linux-gnu`, target `skylake+pku+sgx`. This CPU placement and the
instrumented context routines are recorded in the raw provenance; these
times do not establish throughput parity, a competitor ranking, or the
speedup obtainable by removing a stage.

## Wire identity and event coverage

| 64 KiB input | Frozen wire bytes | Frozen/current wire SHA256 | Events per run | Evaluations per run | Context details |
|---|---:|---|---:|---:|---|
| NCI | 4,206 | `5e82ff1682e22f8b9e9bbe0f06f49e43b6679bcc736f691a24261295a1d13615` | 130/130 | 25 | 8/8, complete |
| Mozilla | 13,924 | `29686649968e0dadd3dec91675d545298aa37fbbb58c00e3b6277881f9a6d2eb` | 234/234 | 57 | 8/10, truncated prefix |

Both original inputs and both complete frozen matrix sample reports are
retained. The diagnostic uses one fixed `PlannedEncodeOptions` value for its
ordinary byte oracle, normal pass, generic traced call, and reported settings:
quality 8, generic mode, explicit window16. The default-window q8 convenience
profile API is not the oracle. The producer asserts exact ordinary/traced
byte equality and decoded roundtrip; the archived verifier checks those
recorded assertions and the frozen output identities without executing a codec.

Every run has `events_truncated=false`, `wire_attempt_coverage_complete=true`,
`timing_complete=true`, a real final returned wire event, and no failed or
unclassified wire attempt. All wire/evaluate configurations advertise standard
window16. Event contents, configurations, candidate byte lengths and identities
are identical across each input's three rounds after removing timer fields.

Mozilla has `context_details_truncated=true`: only the first eight of ten
complete `context_proposals` events have their auxiliary scorer details saved.
This is independent of event or wire coverage. The repaired gate accepts only
the exact first-eight prefix in `--wire-counts-only` mode and labels context
detail coverage incomplete. Its default full-context mode rejects this report.
Complete context-stage timing and complete wire counts remain usable; aggregate
scorer/cache statistics from those eight details are not complete Mozilla
context-search statistics.

## Physical output materialization

"Lost" means every successful physical wire except the final returned event.
An earlier strict-selection winner replaced later is still lost. A counted
`evaluate` event is not a physical output. Summed encoded lengths below describe
materialized output bytes, not peak allocation, allocator totals, or memory traffic.

| Input | Physical wires/run | Lost/run | Final event and origin | Total encoded lengths/run | Lost encoded lengths/run |
|---|---:|---:|---|---:|---:|
| NCI | 16 | 15 | 123, optimal | 71,205 | 66,999 |
| Mozilla | 33 | 32 | 85, lazy | 504,604 | 490,680 |

Across all six runs there are **147 successful physical materializations**,
**141 lost materializations**, **1,727,427 materialized encoded bytes**, and
**1,673,037 lost encoded bytes**. No attempt failed or remained unclassified.

| Input/origin | Physical/run | Lost/run | Materialized bytes/run | Lost bytes/run | Share of traced outer time, pooled |
|---|---:|---:|---:|---:|---:|
| NCI/lazy | 6 | 6 | 27,703 | 27,703 | 8.87% |
| NCI/optimal | 10 | 9 | 43,502 | 39,296 | 90.84% |
| Mozilla/lazy | 15 | 14 | 214,130 | 200,206 | 31.09% |
| Mozilla/optimal | 18 | 18 | 290,474 | 290,474 | 68.01% |

Remaining `other` origins account for 0.29% of NCI and 0.90% of Mozilla outer
time, with no physical wires. Origin time includes all non-outer stages
attributed to that origin; it is not only emission time. The complete per-run
origin and stage ledgers are in `summary.json` and `physical-wires.csv`.

The public parameter-pair counters are also retained. NCI reports
`parameter_pairs=1`, `parameter_counted_candidates=1`,
`parameter_physical_emits=0`, `parameter_skipped_pair_emits=1` in every round.
Mozilla reports **1, 2, 1, 0**, respectively. These are specific parameter-pair
controller counters, not the total 16/33 physical-wire counts.

## Cost distribution and split families

Shares divide the sum of three stage-exclusive durations by the sum of three
traced outer durations. Exclusive stage accounting avoids counting a child
wire/evaluation inside its parent's split-planning time a second time.

| Stage | NCI share | Mozilla share |
|---|---:|---:|
| `optimal_parse` | 74.25% | 17.85% |
| `context_proposals` | 15.25% | 56.07% |
| `wire` | 3.05% | 8.16% |
| `evaluate` | 2.32% | 6.46% |
| `split_planning` | 1.03% | 3.95% |
| `other` | 2.69% | 5.57% |
| `lazy_parse` | 0.81% | 0.64% |
| `distance_parameters` | 0.17% | 0.71% |

The remaining small stages and exact integer durations are retained in
`stage-shares.csv`. Mean traced outer durations are 99.962 ms for NCI and
188.886 ms for Mozilla. Every run records four optimal-parser events; NCI has
eight context-proposal events and Mozilla ten. The context stage uses profiled
context selection, so even a large share is a prioritization signal, not a
predicted ordinary-encoder improvement.

| Candidate family, per run | NCI evaluations / physical / lost | Mozilla evaluations / physical / lost |
|---|---:|---:|
| Fixed literal split | 0 / 0 / 0 | 0 / 0 / 0 |
| Fixed command split | 0 / 0 / 0 | 0 / 0 / 0 |
| Fixed distance split | 0 / 0 / 0 | 0 / 0 / 0 |
| Adaptive literal split | 4 / 0 / 0 | 10 / 0 / 0 |
| Adaptive command split | 0 / 0 / 0 | 0 / 0 / 0 |
| Adaptive distance split | 0 / 0 / 0 | 24 / 10 / 10 |
| Joint literal/block contexts | 0 / 0 / 0 | 0 / 0 / 0 |

Thus none of the fixed literal/command/distance split families actually
materializes or evaluates a wire in these two rows. Shared split-planning work
does run eight times for NCI and ten times for Mozilla, but the trace has no
per-family planner subdivision. Zero fixed-family candidate events cannot be
used to claim zero fixed-family proposal-search cost, or to name a particular
two/three/four/clustered fixed layout as the measured bottleneck.

The observed split candidates are adaptive. NCI's four adaptive-literal
evaluations emit no wire. Mozilla's ten adaptive-literal evaluations also emit
none; its adaptive-distance family performs 24 evaluations and ten emissions,
all eventually lost. For round zero, those ten distance emissions use 2.226 ms
of wire-exclusive time and their 24 evaluations use 3.502 ms. All three rounds'
exact family durations and lazy/optimal contributions are retained. Shared
planner time is not reassigned to that family.

The highest-ROI follow-up is to remove repeated analysis/planning while
preserving every candidate's exact decisions: investigate model-independent
match evidence across NCI's four optimal parses, and reuse context preparation
and scoring across Mozilla's repeated command plans. A separate prepared-wire
arbitration follow-up can avoid emitting candidates ultimately discarded,
including Mozilla's ten adaptive-distance outputs. The larger parser/context
shares make fixed-split layout tuning a lower priority for these rows. Any
change still needs current-source ordinary-encoder A/B measurements, complete
wire identity, and the full non-regression matrix before acceptance.

## Retained artifacts and validation phases

| Artifact | Retained evidence |
|---|---|
| `profile.json.gz` | Exact original six-run report bytes |
| `fixtures.tar.gz` | Exact NCI and Mozilla 65,536-byte input payloads |
| `frozen-matrix.tar.gz` | Exact original explicit16 q8 matrix sample JSONs, including settings and provenance |
| `diagnostic-executable.gz` | Original ELF bytes; SHA256 `ab8516edccb600a679310b263f3cbe14de4975a086811bd2e385c1f4998c30d5` |
| `diagnostic-command.json`, `diagnostic-build.log.gz`, `diagnostic-run.log.gz` | Original invocation, successful build/test log and empty successful run log |
| `source-snapshot.tar.gz`, `diagnostic-dirty.patch.gz` | Archive-time diagnostic source/build/test snapshot and focused q8 source delta |
| `post-run-gate-fix.patch.gz`, `audit/`, `audit-regressions.json` | Later Python-only exact-prefix gate correction, archived audit sources and observed 30-test receipt |
| `original-gate.json.gz`, `gate-summary.json` | Original and freshly rerun repaired six-run gate outputs |
| `summary.json`, `physical-wires.csv`, `stage-shares.csv` | Complete raw-event reduction and exact cost ledgers |
| `archive-bindings.json`, `SHA256SUMS`, `verify.py`, `summarize.py`, `verification-receipt.json` | Original-byte bindings, full inventory, offline audit/reducer and its receipt |

The diagnostic checkout HEAD is
`0dd219d929d1883affab68a98c73a910487a07ce`. A direct Git comparison finds no
differences in `src/br.zig` or `src/br/` against frozen-matrix revision
`4a9796b0`. Source snapshots and dirty patches were captured at archive time;
they are retained source evidence rather than a claim of reproducible compiler
inputs. The diagnostic patch is separated from the later Python audit patch,
which was not part of encoder compilation and did not change the ELF hash.

The original diagnostic build log records **2 Zig binding tests**, **19 Python
event tests**, and **9 Python physical-wire tests**: 28 Python tests in that
phase. The actual Mozilla prefix exposed the later gate mismatch; the repaired
gate phase passes **19 + 11 = 30 Python tests**. Those later tests and the
successful six-run gate are retained separately, without attributing them to
the original build.

From any directory, run the offline verifier:

```sh
python3 /path/to/q8-explicit16-profile-20261125/verify.py
```

It verifies every package checksum and compressed member's original bytes,
relocates archived fixtures for the archived gate, hashes the archived ELF
without executing it, checks both frozen wire identities, and regenerates the
complete physical/stage summary. It does not require the original `/tmp`
paths, a Git checkout, Zig, a compiler, or a foreign codec library. The original
paths remain intact in the raw report; only an in-memory gate input is relocated.
