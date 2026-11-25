# V6 parameter-context proposal reuse: rejected reserved comparison

**decision="rejected"; merge_allowed=false.** The independent unmerged V6
candidate fails the unchanged whole-operation acceptance bar. Overall
throughput is **1.0178033718x**, below1.03; NCI is **0.9865368827x**, below1.20.
The primary ooffice and samba controls are **0.9742092198x** and
**0.9699582907x**, below0.98. All three separate public controls pass0.98;
they do not override the primary failures.

All original raw calls, AB/BA order, argv/exits, length mixes, wire bytes,
process intervals, source/ELF identities, outliers, confidence intervals,
resource phases and profile details are retained. The original v4/v5 packages
are untouched. This reserved c2/V6 development-host result, requested-peak1.0,
or an observed profile analysis2→1 does not establish source-performance
leadership or causality from independently sampled v4/v5 epochs.

## Offline reproduction

Copy this whole directory anywhere and run Python3.10+ from any working
directory:

```sh
python3 /path/to/copied/parameter-context-20261126/verify.py
```

An explicit data directory is also supported:

```sh
python3 /path/to/verify.py --root /path/to/copied/parameter-context-20261126
```

The verifier needs only the copied directory. It reads/hashes archive members,
reconstructs the2189 c2 Git blobs using the2193-file V6 filesystem and two
explicit baseline deltas without Git, hashes every relevant ELF/object/WASI
module and pinned reference, validates saved wires/argv/exits, replays primary
and controls bootstrap, resource quota/free ledgers, profile event/detail
reductions and all216 process wall intervals. It compares derived JSON/CSV
bytes and the inventory. Original absolute paths are provenance strings and
are not opened.

No codec, ELF, build, test, WASM, benchmark, sampling runner or Git command is
executed. The original pure primary reducer is imported in a temporary
statistics-only directory; the original profile reduction body runs against
memory-resident archived files. Recorded decode and test receipts are
validated rather than executed again. Bytecode writes are disabled.
Verification exits0 for intact evidence and reports **rejected**. This means
successful evidence replay, not performance acceptance.

`--write-derived` regenerates JSON/CSV/inventories using the unchanged archives.
Ordinary verification does not modify the publication. The migration receipt
documents actual copied-directory verification from an unrelated working
directory, with original artifact-directory access and execution calls blocked.

## Current-source experiment and gates

Baseline source: `c2c8f250302ca2f223740076482dd95b1788eeb1`.
Candidate: `e083531a+parameter-context-proposals-v6`. Legacy primary slots
`old_exact/current` denote these sources; control slots are baseline/current,
and current is V6. Full frozen source2193 and source6 changed/new bytes are
archived. SourceRoot snapshots were obtained after native execution;
instantaneous native compile/run source identity was not measured.

The fixed host is Intel Core i7-10700K, Linux x86_64 GNU, Zig0.16.0,
ReleaseFast, skylake+pku+sgx, one codec thread, measured CPU affinity2.
Primary API lifecycle is continuous public allocating encode + length mix +
free, with one untimed owned encode/free warmup per process, q8/generic/explicit
window16 and twelve original65536-byte Silesia prefixes. Exact commands,
CPU/target/allocator provenance and input hashes are in the raw records.
Pinned libbrotli1.2.0 decoder/common/license validate complete initial wires;
this is not a libbrotli throughput competitor row.

Primary comprises **90 pairs /180 processes /180 timed calls**. Every case has
six alternating AB/BA pairs; Dickens/Mozilla/NCI each receive six additional
balanced pairs. Rows use all their own pairs. The equal-weight12-row matrix
uses shared first-six-round blocks, so weak-row extras do not overweight it.
The original deterministic bootstrap has20000 draws, order stratification and
95% percentile intervals; matrix draws resample common primary-round blocks.
No call or outlier is removed. Absolute median throughput in MiB/s is supplied
in summary.json; acceptance uses paired geometric ratios.

Overall elapsed V6/c2 is **0.9825080440133338**, CI
**[0.9752271380227273,0.9903892554777951]**. Reciprocal throughput is
**1.0178033717822963**, CI **[1.0097040072567915,1.025402145829842]**.

| Primary case | Pairs | Equal initial wire bytes | Throughput V6/c2 | 0.98 floor |
| --- | ---: | ---: | ---: | --- |
| dickens |12|22367|1.0173942794|pass|
| mozilla |12|13924|1.0387106233|pass|
| mr |6|15438|1.0117493845|pass|
| nci |12|4206|0.9865368827|pass; fails1.20 target|
| ooffice |6|30682|**0.9742092198**|**fail**|
| osdb |6|25418|1.0554932321|pass|
| reymont |6|17128|1.0154539573|pass|
| samba |6|18744|**0.9699582907**|**fail**|
| sao |6|46709|1.0944220052|pass|
| webster |6|19555|0.9881129453|pass|
| x-ray |6|41180|1.0328331162|pass|
| xml |6|4407|1.0133026463|pass|

| Declared gate | Observed | Result |
| --- | --- | --- |
| Overall geomean throughput≥1.03 |1.0178033718|**fail**|
| Overall95% CI excludes parity |lower1.0097040073|pass|
| Weak NCI throughput≥1.20 |0.9865368827|**fail**|
| Every primary row throughput≥0.98 |ooffice/samba below floor|**fail**|
| Every public control throughput≥0.98 |all three pass|pass|
| Complete initial wires identical |24 primary +6 untimed control wires|pass|
| Finite caps/original error/free ledger |42 new cap operations|pass|
| Recorded actual test outputs/module match |real22; fixture10 each; full1715/1skip|pass|

Every row's elapsed/throughput CI and raw pairs remain in summary.json and
the original raw summary. All24 primary initial wires are saved and pinned
decoder verified in recorded preflight. Warm wire SHA binds timed processes
to preflight. Timed outputs check length/mix only; no complete-output SHA or
decoder runs inside the continuous timer. Original reducer prose still calls
the matrix observational/non-quiet/pending; it is preserved raw. The actual
reservation and explicit V6 rejected gates are supplied by this publication.

## Separate public controls

Controls use the unchanged133-line minimal public probe and its exact
continuous primary timer body. Each has six balanced AB/BA pairs, totaling
**18 pairs /36 processes /1224 timed calls**. q4 has100 calls/process;
q11/ratio each have one. Arithmetic means include every raw call within a
process. Paired geometric ratios and20000 order-stratified draws use the
original control-specific seeds. Calls are not independently resampled outside
their process/pair groups.

| Control | Actual options | Equal wire bytes | Throughput V6/c2 | Throughput95% CI | Floor |
| --- | --- | ---: | ---: | --- | --- |
| q4 |quality4/generic/window16|14057|1.0026461759764966|[0.9969139726749613,1.0084113391477807]|pass|
| q11 |quality11/explicit command_state_max_input_kib8/generic/window16|13906|1.0463206574979418|[1.033267857793133,1.0616542091042047]|pass|
| ratio |quality=null/level=ratio/generic/window16|14306|0.9985757041800317|[0.9964102588483345,1.0011047532416246]|pass|

The six untimed control wire identities are three original c2 golden encodes
and three fresh V6 iterations0 encodes. Both sets were pinned-decoded anew in
the control preparation. All36 timed control warm complete wires and each raw
sample/index/mix/argv/stdout/stderr are preserved. Actual options do not prove
a shared_common runtime hit; that claim remains unconfirmed.

## Reservation and original collector completion

The original collector had already completed216 entries with actual
parent-reported exit0. Its final manifest bytes/SHA are archived separately
from this campaign's216 measured processes. Original formal session35962
finished exit0. The reservation used **collector-complete** and did not signal,
stop or resume any original process.

| Boundary | Unix seconds |
| --- | ---: |
| quiet_start |1795630711.9521909|
| primary start/end |1795630711.952324 /1795630769.3809083|
| controls start/end |1795630769.3810446 /1795630797.634933|
| analysis start/end |1795630797.6350808 /1795630804.1280248|
| quiet_end |1795630804.1281552|

All180 primary and36 control wall intervals lie inside their stages and the
reservation; measured processes do not overlap. These recorded development-host
intervals do not independently trace all host-wide scheduler activity.

## Requested-heap resources and actual profile scope

The resource package preserves14 new V6 cases with42 cap operations:
unlimited, exact observed peak and peak-minus-one. The42 old c2 cap operations
are reused separately. Every complete wire is byte-identical, profile/tracker
peaks match, all allocation/free ledgers balance, returned-wire ownership
matches, and caller free leaves zero live bytes. All14 peak-minus-one cases
refuse with the unchanged WorkingMemoryLimitExceeded; exact-peak succeeds with
the original wire. Six budget/backing/handoff classification tests passed.

Requested-peak V6/c2 geomean is **1.0** for Silesia12 and all14: there is no peak
reduction. Cumulative requested allocation ratios are0.9953157972312129 and
0.995983623279309 respectively. This is forced-moving whole-operation requested
heap, including budget control and returned wire. Input/oracle/decode/report,
allocator bookkeeping and internal remap transients are excluded. Native RSS,
stack and physical traffic are not measured. Raw test/build MaxRSS strings do
not change this encoder-resource scope. No resource throughput is measured.

| Actual profile row | Complete events c2/V6 | Context builds c2/V6 | Details |
| --- | ---: | ---: | --- |
| Mozilla |234/233|**10/9**|first8 each; truncated|
| NCI |130/130|**8/8**|all8 each; complete|

Mozilla's observed parameter branches other57/preferred58 `(0,0)` and
other79/preferred80 `(2,2)` both have input65536, lazy/nonvariant and
command_count4316. c2 context slots59/82 each contain actual analysis detail;
V6 retains slot59 only: this bounded observation is **2→1**. Corresponding
non-time proposal values/counters match. The trace has no cache/family ID or
commands pointer/content fingerprint. Numeric cache-hit and shared_common-hit
counters stay null; attribution is limited to these slots and the bound source
call sequence. NCI does not demonstrate analysis-count reduction.

All event records are complete. Mozilla's first-eight detail sums cover
different sets because V6's saved prefix includes a later optimal build. They
are not whole-row analysis totals or matched throughput. The unmodified
profile tool's normal_ns/profile_call_ns end on encode return before
comparison/free; their instrumented stages are diagnostics, not the formal
continuous owned encode/mix/free lifecycle. Full events/details and original
ordinary wires remain in profile.tar.gz; its pure reduction replays in memory.

## Actual V6 code tests and snapshot limits

Actual saved outputs show native real22 including imports, fixture native10,
x86-64 GNU10 and WASI10, with observed exit0. Full Brotli ReleaseSafe has
terminal5/5 steps succeeded,1715/1716 tests passed, one skipped. Original
failed-command diagnostic text is retained; the terminal result is recorded
without editing the log. Actual WASI module SHA256 is
`6880ee6540361c18d58a900fbc35b54918ba1d7097ba5cdc434f99603cc60c3f`.

SourceRoot/native snapshots were obtained after native execution. The full
frozen source2193/source6 and later unchanged-source receipts are checked;
instantaneous native compile/run source identity was not measured. The raw
base-identity is the starting e083 source state, not the modified V6 snapshot.
Some raw inherited build scope strings say v5; their actual V6 source label,
source2193/source6, object and ELF identities determine the derived role.

The test receipt's old preflight.log digest matches the exact **27-byte
prefix** `Preflight explicit16 begin\n` of the later complete progress log.
Root wrote that receipt while preflight was still running, before its done
line. Its scope is an in-progress stdout snapshot, so it does not bind the
later final log's full digest. The exact matching prefix, original receipt and unchanged full log are
all preserved, with an explicit prefix/full-byte binding. Seven actual
test/build log hashes and the module match directly. The old snapshot does
not bind the later suffix; archive/member SHA binds the final complete log.
The false full-digest comparison and passing prefix comparison are both
reported with that scope; they are distinct from the seven verified actual
test/build logs and their observed successful exits.

## Self-contained inventory

| Package | Members | Compressed bytes |
| --- | ---: | ---: |
| primary.tar.gz |3105|16132656|
| controls.tar.gz |266|8086914|
| resources.tar.gz |199|10330159|
| profile.tar.gz |93|15345924|
| code-tests.tar.gz |15|480645|

All3678 members are hash/byte-count bound in archive-bindings.json. The V6 full
source and c2 reconstruction, normal/control/resource/profile ELFs and objects,
pinned libraries/license, actual WASI module and every raw output dependency
are local to these five archives. No original/tmp or neighboring archive is
needed for offline replay. Sources, raw files, original paths and generated
prefix/collector receipts are explicitly distinguished in member provenance.

Derived summary.json, offline-receipt.json, primary-pairs.csv,
control-calls.csv, process-intervals.csv and resource-rows.csv preserve LF and
complete raw call/pair coverage. inventory.json/SHA256SUMS also bind all included
verifier modules and documentation. Ordinary, control, instrumented resource
and profile ELFs retain distinct roles and are never mechanically substituted.

The next engineering decision should address the measured whole-operation
gap and primary ooffice/samba regressions before another separately declared
matched reserved A/B. Root owns the main status ledger; this publication does
not merge V6, lower a gate or alter the original v4/v5 evidence.
