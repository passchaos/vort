# Modeled search development screening, 2026-11-25

**Acceptance is rejected; merge_allowed=false.** The completed reserved developer-host quiet window has elapsed ratio **0.925487** (95% CI **[0.922318, 0.928477]**), or **8.05% overall throughput improvement**, and every wire is unchanged. Overall throughput and control floors pass, but **NCI throughput is 1.181598x, below the unchanged 1.20x target**. That failed weak-row gate prevents merging. The four earlier non-exclusive screens, resources and completed code tests remain complete; this is not an industry ranking.

## Completed reserved developer-host quiet window

| Requirement | Observed | Gate |
|---|---:|---|
| Overall throughput at least1.03x | 1.080512x, CI [1.077033, 1.084224] | pass |
| Controls at least0.98x | 1.013705x minimum (sao) | pass |
| Weak NCI at least1.20x | 1.181598x | **fail** |
| Complete wire size/byte identity | 1.0 | pass |

There are 90 pairs/180 timed calls, with twelve primary rows x six rounds plus six extra pairs for Dickens/Mozilla/NCI; primary corpus weighting is unchanged. Common probe/provenance, both ELF bytes, pinned reference and input bytes were compared exactly with the original S4 copies before packing. Frozen S4 source identity is reused; no quiet rebuild, source/options/order change or codec execution is introduced by archival checks.

Actual quiet window: **2026-11-25T15:59:30.894635+00:00 to 2026-11-25T16:00:37.964065+00:00**. Every one of the 180 full process wall intervals (including warmup/hash/report overhead, not only encode/free nanoseconds) lies inside those bounds. Campaign and analysis each exit0. Collector resume timestamp **2026-11-25T16:00:37.964119+00:00** is at or after quiet_end. The original timed child was allowed to finish naturally before quiet_start; reservation initiation is not mislabeled as the start of quiet measurements.

This is a temporary task-boundary reservation of the same developer host. It is a completed local acceptance attempt, not a permanent dedicated performance-host or industry-leadership result. The original analyze.py/statistics_scope still contains inherited non-quiet wording; those exact raw bytes are preserved. Actual reservation, source/config identity, argv/exit and process-wall/restore records identify the completed window.

label-correction.json records the copied historical comparison description being corrected before quiet_start, with before/after settings SHA. Only comparison text changed; actual c2/S4 source, ELFs, q8/generic/explicit16 options, order and thresholds remained unchanged.

All quiet raw metadata, process reports/stdout/stderr/argv, initial wires, corrected settings and reservation/restore information are in quiet.tar.gz. quiet-intervals.csv is an LF derivative, not a replacement for raw timestamp evidence. No previous four-stage data, resource scope, raw warning or native source-hash limitation has been removed.

## All four exploratory stages

| Stage | Candidate/baseline elapsed | 95% elapsed-ratio CI | Observed throughput gain | NCI throughput gain | Slowest control speed ratio |
|---|---:|---|---:|---:|---:|
| Bounded two-model shared scan | 0.971607 | 0.968179–0.975047 | 2.92% | 4.79% | 0.995326 (sao) |
| + paired exact-cost bound | 0.950385 | 0.946841–0.953943 | 5.22% | 14.47% | 1.004420 (ooffice) |
| + first modeled bounded API | 0.941170 | 0.936375–0.945990 | 6.25% | 16.43% | 1.006640 (x-ray) |
| + same-four-anchor u32 index (final candidate) | 0.924485 | 0.922207–0.926429 | 8.17% | 19.04% | 1.010470 (x-ray) |

The first stage is retained despite its low gain: elapsed decreases 2.84%, which is only about 2.92% throughput improvement and below the declared 3% overall throughput target. Its sao row is slightly slower (elapsed ratio 1.004696). No stage, row, low result or outlier is omitted. All raw process JSON, argv/exit metadata, stdout/stderr and nanoseconds are compressed as exact originals.

Formal requirements remain **at least 3% whole-matrix throughput improvement**, confidence excluding parity under the stated host policy, **controls at least 0.98x**, and the declared **weak NCI target at least 20%**. The final non-quiet NCI observation is about **19.04%**, so it does not satisfy or lower that target. These development screens cannot override the completed reserved-window gate failure.

## Exact comparison identity and lifecycle

All stages reuse the same baseline ELF, SHA256 `f634b02f8e63bf497c5eb3dcd17acbc791b2db46b5a6d534d73ef0ca3a047df5`, originally compiled from **c2c8f250302ca2f223740076482dd95b1788eeb1**. Candidate overlays are based on e41 and bind seven source/test files in stages1–3 and eight in stage4. Every frozen source file still matches its original candidate-source-sha256.json. The baseline source CID is preserved rather than relabeled as a fresh e41 build.

The historical old_exact/current slot names remain in the original harness. Here they mean **c2 baseline / candidate**, not the 11/3 historical source. An inherited raw comparison_scope string still describes the earlier history task; actual settings.variants, build receipts and ELF/source hashes establish the present comparison. Raw metadata is not silently rewritten.

The same common probe/provenance runs Zig0.16 ReleaseFast, GNU x86_64, skylake+pku+sgx, CPU2 and one codec thread. Public API/options are allocating encodePlannedStreamWithOptionsAlloc, quality8, generic, explicit window16. Each child performs one symmetric warmup then one continuous timed interval through encode + wire-length mix + owned free; no SHA, decode, file I/O or JSON lies between encode/free.

Each stage has **90 pairs / 180 timed calls**: twelve fixed Silesia inputs x six alternating AB/BA primary pairs, plus six additional balanced pairs for Dickens/Mozilla/NCI. The primary matrix weights all twelve rows equally using only the first six rounds; weak-row additions do not change corpus weights. Descriptive 95% intervals use 20,000 deterministic paired bootstrap draws stratified by order and common paired primary-round blocks, not a resampled corpus population.

All 24 initial wires per stage are byte-identical baseline/candidate and retain exact pinned libbrotli1.2.0 decode assertions. Input/reference closure, license, source, ELF and initial SHA bindings are checked. All later process initial wires match preflight. Timed output identity is checked by length/mix only: **initial_wire_only** scope. Compressed fixtures and raw JSON retain their original bytes and line endings.

Development-host provenance and observed compiler/collector activity are retained in raw manifests. No competitor throughput ranking is measured here. Common baseline/input/reference/probe bytes are stored once after exact comparison across the four stages, while all per-stage original metadata and wire/report members remain complete.

## Separate whole-operation resource gates

The independent resource probe uses each source tree's unmodified TrackingAllocator and public memory_profile on CPU1. The policy is **force_moving_growth=true**, counting overlapping old/new requested buffers, stable budget control and returned wire. Caller input/oracle/decode/report allocations, stack, allocator bookkeeping, internal remap transients and native RSS are excluded. These are requested-heap quantities, not a normal allocator RSS measurement or instrumented throughput result.

The original v3 group verifies **14 cases x two sources x three caps = 84 operations**. The compact-v4 group adds **14 x three caps = 42 operations** without rerunning/overwriting baseline or v3. All unlimited/exact caps preserve complete baseline wire; each peak-1 returns the original WorkingMemoryLimitExceeded, profile and tracker peaks agree, and caller free leaves zero live bytes with allocated/freed ledgers balanced. RLE and opaque controls are retained.

For the twelve Silesia rows, v3/baseline whole-operation peak geometric ratio is **0.861530**; v4/baseline is **0.757038**. These are measured whole-operation results, not a claim that a sixteen-byte workspace necessarily reduces all memory.

| Case | Baseline requested peak | v3 requested peak | v4 requested peak |
|---|---:|---:|---:|
| dickens | 7,879,402 | 6,590,593 | 5,965,846 |
| mozilla | 6,478,879 | 5,639,294 | 4,852,734 |
| mr | 6,909,732 | 5,941,844 | 5,155,284 |
| nci | 4,978,760 | 4,640,173 | 3,853,613 |
| ooffice | 8,274,522 | 6,907,576 | 6,228,106 |
| osdb | 7,281,396 | 6,243,041 | 5,456,481 |
| reymont | 7,075,271 | 6,063,732 | 5,277,172 |
| samba | 7,165,309 | 6,171,206 | 5,384,646 |
| sao | 9,245,441 | 7,531,000 | 6,983,273 |
| webster | 7,265,413 | 6,241,384 | 5,454,824 |
| x-ray | 10,140,755 | 8,425,295 | 7,905,263 |
| xml | 4,952,830 | 4,620,758 | 3,834,198 |
| rle | 4,341,724 | 4,204,408 | 3,545,866 |
| opaque | 6,076,086 | 6,076,086 | 6,076,086 |

The compact stage's allocation request counts match v3; request sizes decrease. Opaque peak/allocated/requests remain unchanged. Each original resource source/helper/ELF identity and all cap/ledger reports are retained separately. Parent unit-root backing-OOM tests are code-gate evidence; archival checks do not introduce a new fault-injection campaign.

## Completed code tests and source review

Final native, explicit x86 and WASI suites each pass **14/14**. Native original stdout and exit0 were recovered from the original tool JSONL without rerunning: invocation 2026-11-25 14:47:13Z, session79673, completion14:50:49Z. The verifier requires all fourteen OK lines, All14, and exact stdout equality with receipt.test_result.output plus receipt.test_result.exit_code==0. No source hash was measured at native execution; the stored source hashes are later archive snapshots, not contemporaneous test identities.

The explicit x86 original stdout is complete. WASI stdout/stderr and exit0 JSON bind the retained final WASM SHA256; the reused fixed-length runner schema is preserved as original metadata while the actual fourteen modeled-pair test names identify the exercised suite.

The complete ReleaseSafe full-Brotli log ends with **5/5 steps succeeded, 1710 passed / 1 skipped**. Its original failed-command diagnostic text is also retained, rather than hidden; the terminal successful build/test summary is the recorded outcome. Archival review never reruns these builds/tests.

Final test mother source is captured separately from each frozen performance source. Baseline lz77.zig has **5915 lines**, frozen compact performance source **6036**, and the final tested mother **6103** (net **+188** versus baseline, including later test additions). This remains a giant module. Paired solver, compact index and feedback orchestration have already been extracted into modeled_pair.zig, modeled_index.zig and feedback_rounds.zig; that does not complete the structural split.

The follow-up split plan is to move four-anchor modeled adapters and pack/unpack/bridge glue into lz77/modeled/adapter.zig, and move root modeled oracle/test bodies into lz77/modeled/root_tests.zig. Keep only thin public delegators and shared type views in lz77.zig, retaining the existing scalar implementation as an independent oracle and preserving native/x86/WASI gates. No source refactor is performed by this archive task.

Known small documentation discrepancy: modeled_pair.zig still says -1 sentinel, while actual Api.index_empty supports u32max for the compact index. Frozen production source is preserved unchanged; the comment is a follow-up documentation fix. The bounded single-model path passes **collect_profile=false** because the distance_cost-5 histogram is fixed-cost-only and must not consume modeled prices. The offline source check retains this guard.

## Compact original-byte packages and offline replay

| Package | Scope |
|---|---|
| quiet.tar.gz | Complete quiet raw metadata/labels/reservation/restore and initial/process evidence; immutable S4 common payloads reused by exact identity. |
| screens.tar.gz | All four complete original screens, common probe/provenance, shared c2 ELF/reference/license/input bytes, candidate ELFs and seven/eight frozen source files, raw commands/logs/process reports/wires. |
| resource-v3.tar.gz | Exact original v3 resource evidence archive, including raw cap reports/wires/probes/source/helper/build identities. |
| resource-v4.tar.gz | Exact separate compact-v4 resource evidence archive with unchanged-v3 linkage. |
| code-tests.tar.gz | Final recovered native tool/stdout, x86/full-Brotli/WASI logs/results/module and archive-time source snapshot. |
| summary.json, stages.csv, controls.csv, resource-peaks.csv, quiet-intervals.csv | Complete recomputed per-stage/per-row evidence and LF derived ledgers. |
| verify.py, screening.py, resources.py, code_checks.py, verification-receipt.json, SHA256SUMS | Portable archive/identity/statistics/resource/code audit, its receipt and full inventory. |

```sh
taskset -c 0 python3 /path/to/modeled-search-20261125/verify.py
```

The package can be copied anywhere. The verifier hashes every published file and compressed original member, checks source/ELF/input/reference/license/wire/lifecycle identities, reconstructs every stage's primary and weak raw ns medians/ratios/CI, checks all resource exactcap/peak-1/zero-live arithmetic and code-test outputs/source snapshots. It does not execute an original ELF, codec, WASM, test, compiler or Git, and rechecks every completed quiet wall interval against the reservation and restored collector timestamp. Builds/decode/test runs are audited as original receipts. Source archive identities are not claims of fresh or byte-reproducible compiler execution.

Acceptance is rejected for this completed reserved window. Any future candidate or rerun must keep the original overall/control/NCI thresholds and preserve this failed result.
