# Frozen v5 single modeled DP: rejected reserved A/B

`acceptance="rejected"`; `merge_allowed=false`. This directory publishes the
unmerged v5 candidate and the completed reserved comparison against c2. Overall
throughput improves by 6.799%, but NCI reaches **1.164719x**, below the required
1.20x. The legacy public ratio control reaches **0.976641x**, below the unchanged
0.98x floor. Resource improvements and passing code tests do not waive either
performance gate.

All displayed numbers come from the preserved raw bytes and deterministic
offline replay. No timed sample or outlier was deleted. This is a reserved
comparison on one fixed development host, not evidence of competitor parity or
industry leadership. Independently sampled v4/v5 timing ratios must not be used
to infer source causality.

## Reproduce the offline verification

Copy this entire directory anywhere, change to an unrelated working directory,
and run its verifier with Python 3.10 or later:

```sh
python3 /path/to/copied/single-modeled-20261126/verify.py
```

Or choose an explicit copied data directory:

```sh
python3 /path/to/verify.py --root /path/to/copied/single-modeled-20261126
```

The verifier reads only publication files. Original absolute paths in receipts
are provenance strings; they are never opened. It hashes archive members and
their original transformed bytes, reconstructs c2 Git blob identities without
Git, reconstructs v4 source from the v5 filesystem plus explicit deltas, hashes
ELFs/objects/the actual WASI module, checks argv/exits/recorded logs, replays all
primary and public-control statistics, checks caps/free ledgers, and verifies
all 216 measured process wall intervals inside the reservation. It compares
every derived JSON/CSV byte and the publication inventory.

It executes no codec, ELF, WASM module, test, build, Git command, or sampling
runner. It imports only the original pure primary statistics reducer, in a
temporary data directory, to reproduce its JSON and LF CSV exactly. Public
control and resource calculations use the included pure Python replay modules.
Bytecode output is disabled. Successful verification exits 0 and reports the
preserved **rejected** verdict; this is evidence integrity, not acceptance.

`--write-derived` regenerates derived JSON/CSV and inventories from the unchanged
archives. It is useful when auditing the publication implementation. Ordinary
verification does not modify the publication.

`migration-verification.json` preserves an actual arbitrary-directory copy
verification with an unrelated working directory and empty command PATH, plus
four bounded altered-evidence checks. The temporary checks rebind archive and
member hashes before changing a primary sample/manifest, control raw sample,
quota error class, or reservation interval, so the corresponding replay gate
must reject the changed record. They execute only the copied Python verifier;
all temporary copies are removed, and the original archived data stay intact.

## Sampling and measured result

The baseline source is `c2c8f250302ca2f223740076482dd95b1788eeb1`; the candidate is
`e41aa51c+single-compact-modeled-dp-v5`, an unmerged frozen source label. Legacy
slots `old_exact` and `current` denote these two sources, not older historical
epochs. Primary settings are q8, generic mode, explicit window16, 65,536-byte
original Silesia prefixes, public allocating encode/length-mix/free, one untimed
owned encode/free warmup per process, one continuous timed call per process.

The host is Intel Core i7-10700K, Linux x86_64 GNU, Zig 0.16.0, ReleaseFast,
`skylake+pku+sgx`, one codec thread, measured CPU affinity 2. The archived
provenance and argv retain exact commands, target, CPU model and allocator
scope. The pinned decode reference is libbrotli **1.2.0** and its preserved
common library/license; it supplies recorded initial-wire correctness receipts,
not a throughput competitor row.

`summary.json` also provides absolute row throughput in MiB/s from each source's
per-call median. These medians describe whole public encode/mix/free operations;
the acceptance statistic remains the paired geometric ratio, not the ratio of
unpaired median throughput.

There are **90 primary pairs / 180 processes / 180 timed calls**: six balanced
AB/BA rounds for each of 12 cases, plus six balanced additional rounds for
Dickens, Mozilla and NCI. The matrix gives each case equal weight and uses only
the shared first six rounds. Each row uses all its own pairs. Bootstrap uses
20,000 deterministic percentile draws stratified by AB/BA; the matrix resamples
shared primary-round blocks. No weak-row extra round overweights the matrix.

The overall candidate/baseline elapsed ratio is **0.9363383969322572**, with 95%
CI **[0.9315814120831424, 0.9414120633330949]**. Its reciprocal throughput ratio is
**1.0679899524320677**, CI **[1.0622341044361308, 1.0734434876323524]**. The overall
3% gate and confidence interval excluding parity pass. All primary point
estimates pass the 0.98x floor.

| Primary case | Pairs | Equal initial wire bytes | Throughput v5/c2 |
| --- | ---: | ---: | ---: |
| dickens | 12 | 22,367 | 1.055802 |
| mozilla | 12 | 13,924 | 1.019749 |
| mr | 6 | 15,438 | 1.089335 |
| nci | 12 | 4,206 | **1.164719** |
| ooffice | 6 | 30,682 | 1.002333 |
| osdb | 6 | 25,418 | 1.016589 |
| reymont | 6 | 17,128 | 1.123444 |
| samba | 6 | 18,744 | 1.064029 |
| sao | 6 | 46,709 | 1.034597 |
| webster | 6 | 19,555 | 1.052436 |
| x-ray | 6 | 41,180 | 1.001058 |
| xml | 6 | 4,407 | 1.227162 |

NCI's all-12-pair elapsed ratio is 0.8585759659584624, CI
[0.8497650963682636, 0.8649720165064607]. Its throughput CI is
[1.1561067652094739, 1.1767958042449758]. The NCI 20% requirement fails.

All 24 primary initial complete wires are preserved, byte-identical between
sources and bound to recorded pinned-decode receipts. Sample processes bind
their warm wire SHA to preflight. Timed outputs are checked by wire length/mix;
there is no complete-output SHA or decode inside the continuous timer. Offline
verification hashes the saved wires and validates the recorded decode result;
it does not rerun the decoder.

The original reducer's prose still mentions observational/non-quiet/pending
scope. Its exact raw output is preserved. The reservation receipts below and
the derived top-level summary supply the actual v5 window and rejected verdict.

## Timed public controls

Controls use a separately built minimal public probe, not the primary ELF. The
133-line extension preserves the exact primary continuous timer body. The plan
was recorded before sampling. Each control has six alternating AB/BA pairs:
**18 pairs / 36 processes / 1,224 timed calls**, with 100 calls per q4 process and
one call per q11 or ratio process. Each process's arithmetic mean uses every
actual per-call ns sample; paired geometric ratios and 20,000 deterministic
order-stratified bootstrap draws use seeds `control-q4`, `control-q11`, and
`control-ratio`. Samples remain grouped by process/pair for bootstrap.

| Public control | Calls/process | Equal initial wire bytes | Elapsed v5/c2 | Elapsed 95% CI | Throughput v5/c2 | 0.98 floor |
| --- | ---: | ---: | ---: | --- | ---: | --- |
| q4 | 100 | 14,057 | 0.9998750888346796 | [0.9893408328373982, 1.010016168605064] | 1.000124926770069 | pass |
| q11 | 1 | 13,906 | 0.969486885016553 | [0.9527419148771246, 0.9865261573385474] | 1.0314734685481857 | pass |
| ratio | 1 | 14,306 | 1.0239176494016364 | [0.9913599445945256, 1.0840305367248457] | **0.9766410419669848** | **fail** |

All controls use the same unchanged Mozilla prefix, generic mode and window16.
q11 explicitly sets `quality=11` and `command_state_max_input_kib=8`. Ratio
actually uses `quality=null`, `level=ratio`. The source dispatcher/default
context preparation route is retained, but an actual `shared_common` runtime
hit remains **unconfirmed**. Options do not establish a runtime route hit.

The separate untimed control preflight has six iterations0 processes, no timed
samples, recorded decode status1, 65,536-byte exact output, and byte-identical
c2/v5 complete wires. The 36 timed processes also preserve all warm complete
wires and exact reports/argv/stdout/stderr; timed outputs have length/mix checks.

## Reservation, startup and collector

The accepted sampling reservation has:

| Boundary | Unix seconds |
| --- | ---: |
| quiet start | 1795626285.6356149 |
| primary start / end | 1795626285.6357312 / 1795626342.1063392 |
| controls start / end | 1795626342.106533 / 1795626370.5470939 |
| analysis start / end | 1795626370.547248 / 1795626376.598062 |
| quiet end | 1795626376.5981967 |
| collector resumed | 1795626376.5983152 |

All 180 primary and 36 control process wall intervals lie inside their stages
and the final quiet interval; measured processes do not overlap. The mechanism
targets original collector parent PID3374522 via pidfd at a task boundary and
lets original timed children finish naturally. These are recorded reservation
and wall-interval facts; they are not independent host-wide scheduling traces.

Startup attempt001 is retained raw. It failed before `quiet_start` with
`Parent stop was not observed; sampling must not start`. Its original receipt
records finally CONT/resume and no primary, control or analysis stage. The
corrected stopped-state acknowledgement loop was used for the final reservation.
Startup001 contributes **zero timed processes and zero timed samples**.

The original collector's final manifest is also preserved: `complete=true`,
216 completed entries, and parent-reported original session92621 exit0. Those
216 collector entries are separate from this campaign's 216 measured processes.
The archive task did not rerun or control the collector.

## Requested-heap resources

The v5 resource campaign has **14 cases / 42 new instrumented operations**:
unlimited, exact observed peak, and peak minus one for each case. The reused c2
and v4 reports/wires are retained separately and were not rerun. All fourteen
c2/v4/v5 complete wire triples are equal. Each profile peak equals tracker and
owned peak; allocated equals freed after caller free; final live bytes are zero.
Exact-peak succeeds with the unchanged wire, and peak-minus-one refuses with
the original `WorkingMemoryLimitExceeded`, zero handoff live bytes and no wire.
The recorded six basic backing/handoff/owner classification tests pass.

| Geometric requested-heap metric | Silesia12 | All14 including RLE/opaque |
| --- | ---: | ---: |
| v5/c2 requested peak | 0.7371821370845164 | 0.7589466834761748 |
| v5/v4 requested peak | 0.9737712708094992 | 0.9774756861022083 |
| v5/c2 cumulative requested allocation | 0.8067865726709378 | 0.7991086232991498 |
| v5/v4 cumulative requested allocation | 0.9476742161255773 | 0.9448070826308826 |

This is the existing `force_moving_growth=true` whole-operation requested heap
scope, including stable budget control and returned wire. It excludes native
RSS, stack, physical allocation traffic, input/oracle/decode/report allocations,
allocator bookkeeping and remap internal transients. No resource throughput was
measured. The same helper is bound across c2/v4/v5. Finite-cap refusal and error
class remain intact; the archive makes no fallback or degraded-output claim.

## Actual v5 code validation

The actual v5 outputs are from `/tmp/vort-modeled-single.xw7ogzb4/`, archived in
`code-tests.tar.gz`: native22 exit0, x86-64 GNU22 exit0, WASI22 exit0, and full
Brotli ReleaseSafe terminal 5/5 successful steps, 1,710 passed / one skipped.
The full log retains its original misleading `failed command` diagnostic text;
the recorded terminal success is preserved without editing the log.

The native nine-source snapshot was obtained **after native completion**. It
does not measure instantaneous native compile/run source identity. The same
nine hashes were measured before x86/WASI/full checks, unchanged afterward, and
match the primary frozen v5 sources. The archived `base-identity.json` is the
older v4 starting parent and must not label v5. Older unrelated 14/14 logs are
not part of this publication's v5 validation.

The actual saved WASI module SHA256 is
`ff5fdf30e3e7a64e6329f7e8e85c0a46f03996433ff9303335e32b0195636e28`.
Offline verification checks module bytes and original run receipt, not a rerun.

## Identity and archive inventory

| ELF role | SHA256 |
| --- | --- |
| primary c2 normal | `f634b02f8e63bf497c5eb3dcd17acbc791b2db46b5a6d534d73ef0ca3a047df5` |
| primary v5 normal | `919db198ed7bb5d5587246258e8ffa6bb8c79949fde819b1b7f01c43e5df93db` |
| public-control c2 | `577ef8468aa04bfdbac90e1a26851a2568a8035ae4212fc61b04082beba155c2` |
| public-control v5 | `66a4861d9390f324672bb941b529c910051c20dec75f9f4841802835b867cf60` |
| resource c2 | `06be59a5c53873dcd036a9fb6833978b548be1eb7e8430f32e572a90742f760e` |
| resource reused v4 | `82ae01f86ee4dabdab9f8a17e438fa6f7707dc78a56f3ffabacc9995da7c1888` |
| resource v5 | `3fc5e2b5e823e6c54c10fdc8eea6fe765d89a60905a61ba7b5d7c5b28c929ba5` |

Primary and controls have different probe/ELF identities. Resource binaries
also have their own instrumented lifecycle and identities. They are not
mechanically interchangeable. The full 2,196-file v5 source filesystem and
nine changed/new-file registry are frozen in the primary archive. The 2,189 c2
source Git blobs reconstruct using shared equal v5 files plus the explicit c2
delta. The 2,195-file reused v4 source reconstructs using its original SHA256
registry and four explicit differences from v5; v5-only files are not included.
Reused resource source receipts, ELFs and record objects are packaged locally.

| Package | Members | Compressed bytes | Contents |
| --- | ---: | ---: | --- |
| `primary.tar.gz` | 3,101 | 16,002,223 | all primary raw records/scripts/argv/exits, preflight, references, inputs, full frozen v5 sources, c2 reconstruction, startup and collector receipts |
| `controls.tar.gz` | 240 | 7,381,843 | separate frozen controls build/probe/ELFs/inputs/references/untimed validation and all 36 timed process groups |
| `resources.tar.gz` | 276 | 14,216,962 | all v5/reused resource raw/wire/argv/exits, cap/classification data, instrumented ELFs/objects, v4 source delta/registry and source receipts |
| `code-tests.tar.gz` | 12 | 538,273 | actual22 native/x86/WASI/full logs, module, receipts and source-before-platform record |

`archive-bindings.json` records every member's SHA256, byte count, original path,
and explicit gzip transform/original identity where applicable. Package hashes
are also in that binding and `SHA256SUMS`. There is no dependency on a neighboring
archive or the original `/tmp` trees.

Derived files are `summary.json`, `offline-receipt.json`, `primary-pairs.csv`,
`control-calls.csv`, `process-intervals.csv`, and `resource-rows.csv`. CSV uses LF
and preserves every raw call/pair. `inventory.json` covers every publication
file except itself and `SHA256SUMS`; `SHA256SUMS` additionally binds the inventory.
The verifier modules are cohesive and included in that same inventory.

Recommended follow-up is a fresh separately declared matched A/B targeting the
remaining NCI 20% gap and legacy ratio control floor. This publication does not
merge v5, change the thresholds, relabel older evidence, or update the root
status ledger. The root owner handles its separate ledger update.
