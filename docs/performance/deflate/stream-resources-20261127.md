# Persistent Deflate stream resources, 2026-11-27

Status: implementation, focused public contracts and whole-library gates pass;
the complete default-path diagnostic fails its non-regression floor. The
increment is not adopted. The frozen main baseline is d5d9d8aa.
This is a functional/resource increment toward the three-codec objective,
not a throughput or industry-leadership result.

The initial full ReleaseSafe gate returned actual exit1 with unchanged source:
417/419 steps succeeded and6107/6110 tests passed (two skipped, one failed).
`check` and `check-wasm` succeeded. The single failed test was the existing
clone contract's universal `Allocator.Error` assertion, which became stale
when the six Fixed/Best clone APIs gained explicit resource-policy errors.
Stored clone retains its narrow allocator error set.

Only the old test expectation was corrected: Stored still requires exactly
`Allocator.Error`; the six Fixed/Best types require exactly OutOfMemory,
IntegerOverflow, InvalidBlockPlan and WorkingMemoryLimitExceeded. The existing
physical allocation-failure assertion still requires OutOfMemory. The focused
clone gate then passed Native104/104 and actual WASI execution of both codec
and public artifacts, each with exit0 and unchanged source. The repeated full
gate returned actual exit0 with419/419 steps and6108/6110 tests passed (two
skipped), with unchanged source. Original failure receipts are preserved, and
the old untimed benchmark epochs are invalidated rather than relabeled current.

The [portable functional evidence package](../codec-contracts-20261127/README.md)
now retains both whole-library attempts, the Native/actual WASI clone gates,
both complete source registries and the final 2,267-file source overlay.
Its offline verifier passes from the original package and an unrelated copied
location, and rejects corrupted or missing evidence even when the outer
inventory is rebuilt. A separate Root replay from `/tmp` also returned exit0.
This verifies saved functional evidence only. The separate formal 540-wire
preflight subsequently completed with all actual exits0, full peer wire
identity and external EOF checks. Formal throughput controls and resource
observations remain unrun; the two-round diagnostic below fails its floor.

The original frozen complete2267-file source manifest is
`beb79f99ed3809717dee3d3a3438247f835c45f012bfbb3aeab6cab6e6b0955f`.
The successful full gate receipt is retained under
`/tmp/vort-encoder-contract-integration.44n9_fus/whole-library-after-clone-types`.
Fresh benchmark builds and complete-wire preflight passed with that actual
source/exit binding. Diagnostic timing completed; formal timing is not
authorized following the failed diagnostic. The separate six-round
formal default-stream controls retain the original54 tiny/empty rows and add
216 Silesia64KiB/1MiB/full rows across the six public encoders. Every row must
pass the0.98 point floor and the predeclared simultaneous non-inferiority lower
bound; the old two-round diagnostic cannot substitute for this proof.

The six Fixed/Best raw/zlib/gzip encoders now accept the existing compression
cap/profile fields. One stable shared ledger covers all retained raw buffers,
wrapper pending storage and temporary block work. Default untracked encoding
keeps the provided allocator and creates no ledger control allocation.
Parameter updates preserve resources; wrapper resource tuples synchronize only
after admission. Clone payloads remain independent while explicitly tracked
targets obey their shared parent authority. Full API/lifetime semantics are in
[the format contract](../../formats/deflate-stream-resources.md).

Supporting recoverable quotas required closing two existing publication gaps:
post-plan wire failure now restores unpublished bits and matcher position;
wrappers write raw output directly to caller storage, removing a fallible
transfer after output had already left the raw queue. `stepDetailed` returns
the actual committed input/output prefix with its error. General failed indexed
parsing may reseed to different valid matches; normal successful cap/profile
runs retain default wire bytes. Retry content, checksums and consumption are
validated rather than claiming universal failure-path bit identity.

The final block and its byte alignment are committed separately. Real tail
allocation tests observe `final_block_written=true`, incomplete alignment,
four pending bytes and two residual bits before failing the allocation.
Recovery completes alignment without writing BFINAL again. The same tests
isolate quota refusal using the measured pre-tail live heap.

Current frozen public Native ReleaseSafe and actual WASI gates pass16/16 each,
with actual exit0 and unchanged source manifests. They include:

- Six public encoders across fragmented input/output, flush/finish, dictionary,
  parameter updates and member/stream continuation, comparing complete wires.
- Independent observed capacities/live/peak, moving-growth coexistence,
  exact D/D-1, warm lowered-cap zero-progress refusal and resumed output.
- Profile aliases against receiver, caller buffers, dictionaries, metadata,
  spare capacity and control storage; no profile writes on rejected aliases.
- Independent ordinary clones, explicit parent-aggregate clones, policy
  compatibility and stateless allocator identity without reading undefined ptr.
- 262 real once-failed allocation cases,42 post-plan wire failures,22 failures
  after wrapper body progress,20 observed moving growths and full cleanup.
- All six encoders' physical final-tail failure at output quanta1/3 and all six
  measured quota-tail cases, followed by complete fixed gold/checksum/consumption.

The default allocator compatibility utility passes Native/actual WASI13/13.
The existing wide encoder/counter/transaction gate passes13/13 after restoring
its supported temporary failing-allocator injection on an untracked stream.
Real leases still refuse incompatible allocator rebinding.

Focused receipts and original failures are retained in
`/tmp/vort-encoder-contract-integration.44n9_fus` and
`/tmp/vort-deflate-incremental-resource-gate.0gtwu3ih`. These include the old
helper-name compilation failure, incorrect error-value wrapping, the initial
growth fixture that did not actually grow, the decoder-alias correction and
the detected default allocator regression. None is relabeled successful.

The relevant Native/actual WASI gates are:

```sh
zig build -j2 test-deflate-stream-resources -Doptimize=ReleaseSafe
zig build -j2 test-deflate-stream-resources-wasm -Doptimize=ReleaseSafe
zig build -j2 test-deflate-wide-encode -Doptimize=ReleaseSafe
```

The predeclared default performance control covers six encoders, caller output
quanta1/17/4096, structured/opaque4KiB and empty input. It uses matched complete
init/feed/finish/drain/deinit/mix/free operations with the same fixed input
schedule. All54 rows must satisfy the0.98 point floor in the diagnostic screen;
CI is null and the screen alone cannot authorize merge. Direct-output savings
do not override the measured default-path regressions below.

## Actual default-path diagnostic, November 28

The original sampler exited1 before creating a run manifest or launching any
codec: it expected `preflight.row_definitions`, absent from the frozen original
PF. That original failure, sampler, release and complete PF remain unchanged.
The separately signed v2 sampler consumes the original 108 warm rows and
attempts directly, checking each actual input/ELF/source/argv/complete wire and
retained external-decode result. It does not manufacture a new PF field.
Three data-only mutation tests reject changed row parameters, duplicate
variants and changed ELF identities. The timed body/reducer is byte-identical
after normalizing only the new `diagnostic-v2` output paths.

V2 completed all **54 rows x 2 paired rounds = 108 pairs / 216 children**,
with actual exit0. Each child retains all 100 complete default stream
lifecycles, for 21,600 timed streams. The operation includes fresh
init/feed/finish/drain/deinit, caller output collection and wire mix/free;
SHA and initial external validation remain outside timing. It uses
ReleaseFast, `skylake+pku+sgx`, Intel Core i7-10700K, CPU2 affinity and a
single codec thread. All successful initial complete wires remain identical
to `d5d9d8aa` under unchanged defaults and schedules.

The equal-row throughput GM is **0.93178920x**. **27 of 54 rows** fall below
the fixed 0.98 point floor. Selected weak rows are:

| Default row | Candidate/baseline throughput GM |
| --- | ---: |
| gzip Fixed, structured 4 KiB, output1 | 0.56799571x |
| zlib Fixed, structured 4 KiB, output1 | 0.56836711x |
| zlib Best, structured 4 KiB, output1 | 0.62170969x |
| gzip Best, structured 4 KiB, output1 | 0.65798844x |
| raw Fixed, structured 4 KiB, output1 | 0.81191124x |
| raw Fixed, structured 4 KiB, output17 | 0.92164640x |

All original rows and samples remain in the result. There is no CI or formal
acceptance, and this screen does not rank Vort against a competitor. The
functional increment must repair its default-path cost before adoption;
neither a passing functional gate nor the removed transfer copy excuses the
weak rows. The [portable diagnostic evidence](stream-resources-diagnostic-20261128/README.md)
preserves both the pre-codec tooling failure and the actual completed screen.
The source audit below identifies repair boundaries; it does not individually
attribute the measured loss to each check.

## Pre-timing default-path audit

A read-only comparison against d5d9d8aa identified additional work to inspect
in the fixed controls. These observations are source structure, not measured
regressions or accepted optimization results:

- The old wrappers called raw through a 4096-byte scratch batch. Direct caller
  output can now repeat raw's complete alias gate on every one-byte body drain,
  alongside the wrapper gate that already checks retained raw storage. A future
  internal admission reuse must preserve public raw validation, profile/counter
  aliases and the direct-output failure contract.
- Raw progress submission performs checked input/output additions and checksum
  updates even for zero input progress. Zero-only work can potentially be
  skipped while still committing all nonzero error progress before propagation.
- Default resource admission repeats constant policy/null-profile/allocator
  classification, and convenience step passes through Detailed/Outcome/unwrap.
  Compiler elimination has not been measured. Default admission already avoids
  retained-capacity scanning, ledger creation, configuration and locking.

The planned controls retain all six encoder classes and all output quanta.
Any repair must keep actual caller/base admission records, temporary failing
allocator injection, existing Lease/parent authority, error ordering and full
wire/resource checks. Do not restore the old fallible scratch-to-pending copy
or reduce the control matrix to hide one-byte/default costs.

The follow-up admission audit narrows the potential reuse boundary. Wrapper
receiver storage includes raw receiver storage, and both gates use the same
`addRaw` collector for eight retained-capacity spans and ledger/control
storage. The later raw input/output suffixes are subsets of the already
checked caller spans. This supports a possible per-call internal alias reuse
for default untracked operation only: no Lease, both resource tuples null,
and both caller allocators untracked. It does not establish general profile
or inherited-authority reuse during first adoption or allocator rebinding.

Public raw `step`/`stepScopedDetailed` must keep their full validation. An
internal alias slice must still run raw input/output and block-target checks,
sync/trim logic, tuple guards and the live `beforePublish` check. In particular,
gzip has no equivalent outer raw-output check, and zlib's 4096-byte precheck
does not certify arbitrary current raw output room. Resource/profile admission
must remain before any header or pending-output drain. No admission may be
cached across calls. This is a read-only proof boundary, not an implemented
fast path or a measured performance result.
