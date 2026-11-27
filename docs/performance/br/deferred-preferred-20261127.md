# Deferred preferred emission, 2026-11-27

Status: isolated implementation; focused Native/WASI and full native Brotli
regression gates pass. Performance acceptance remains pending.
Baseline is `d5d9d8aa`. No throughput, historical recovery or industry ranking
has been measured for this candidate.

The [portable focused functional evidence package](deferred-preferred-functional-20261127/README.md) preserves every terminated failed and passed attempt. Its offline verifier passes from an unrelated directory and rejects corrupted or missing evidence. This report describes the isolated source, which has not been adopted into main.

The preferred selector now returns a shape, exact candidate reference, semantic
stats and either owned bytes or a thin prepared frame view. The view borrows
the enclosing append-only literal-model owner and shared command/distance
common, retaining the original full header/payload lengths and key. Final
entropy selection uses the same candidate reference; a prepared preferred
winner emits through the existing emitter after selection. A winning physical
split closes the unused preferred view. Other physical candidates retain their
existing materialization paths.

Candidate order, strict ties, plain equality preference, model misses and
resource errors remain constraints. The implementation does not reduce the
quality, window, search budgets or candidate family. Test-only counter and
failpoint hooks are excluded from production execution.

## Observed functional evidence

The v1 Native/WASI compilation returned actual exit1 with six type/syntax
errors and unchanged source. The two-file braces/typed-trace/typed-options
repair produced v2 build exit0, 9/9 steps. Native and actual WASI execution
each returned exit1: 39/40 tests passed, with one public boundary test failing.
The completed comparisons preceding that failure verify all four gold wires
and the six synthetic complete group wires/stats/decode results.

| Public q8 fixture | Exact wire bytes | Prepared views | Late preferred emits | Physical split winners |
| --- | ---: | ---: | ---: | ---: |
| Mozilla | 13,924 | 9 | 0 | 9 |
| Xray | 41,180 | 3 | 0 | 3 |
| Nci | 4,206 | 8 | 8 | 0 |
| Xml | 4,407 | 8 | 8 | 0 |

These are functional invocation counts, not speed estimates. Mozilla/Xray
demonstrate unused preferred emissions being skipped; Nci/Xml demonstrate
late winner emission with the same complete bytes. The corresponding real
group tests also exercise both final outcomes.

The initial boundary failure was an invalid test expectation: the ordinary
literal builder returns null when the owner is full before calling
`Owner.capture`, so the group's `capacity_misses` can remain zero. V3 instead
fills all five slots through real preparation, supplies a valid uncached key
and real histogram/trees to the builder, and requires null, zero allocator
requests and unchanged slots/counters. Those checks and nonrecent fallback
passed in actual Native/WASI execution.

V3 compilation also passed 9/9, but functional execution remained 39/40.
The next failure is the nondefault window17/npostfix1/ndirect_high2 case with
`optimize_same_last_distance=true` and non-exact commands. The existing wide
writer deliberately rejects this combination; its parameter producers
normalize the unsupported flag to false. Pending V4 tests retain the original
exact-error case and add the same wide parameters under the producer's legal
normalization. No production gap or pointer-fallback cause is claimed from
this observation.

V4 retained those unsupported exact-error cases and added the normalized wide
success cases, but compilation returned exit1 (4/9 steps) because its optional
captured errors were compared directly with an error literal. V5 explicitly
requires each captured error to be present and compares a typed `anyerror`
value with `InvalidBlockPlan`. Only the test file changes. V5 compilation
returned actual exit0 with9/9 steps and unchanged source. Actual Native and
WASI execution each passed40/40, including the original unsupported errors,
normalized wide-parameter complete wires/Stats/decode, the full owner refusal,
strict returned/wire/evaluate association, three independent view-key guards,
both physical OOM checkpoints with allocation/free balance, and exact-cap,
cap-minus-one and resumed public encoding. The V4 source and failure log remain
preserved. Full Brotli regression subsequently returned actual exit0 with
5/5 steps and1754/1755 tests passed (one skipped), on the same unchanged frozen
source. Its original receipt and complete logs are retained separately under
`broader-v5` in the validation epoch; diagnostic `failed command` text does not
override that terminal exit and summary.

The final complete2,257-file source/runner registry is
`dd21162bfc7912cbc932781c9ccafd6ea7e2017b5d62037e11cdd7645b629eaf`.
The functional Native ELF is
`dfc65af9ac81ed3562036243f40c01a240691fa9f21982263868aa76f8552482`;
the actual WASI module is
`32ca711cdd54cba5ba37a18218cc0fc69a658c1091e70587b57bd5822f8ed20a`.
These artifacts and observations do not establish a performance improvement.

Original v1-v5 source identities, exact failed source bytes, Native/WASI
artifacts, releases, stdout/stderr and actual receipts are preserved under
`/tmp/vort-q8-deferred-preferred-validation-20261127`. The main worktree's
Deflate/Zstd increment remains independently frozen. Functional builds/tests
use CPU6/7 alongside the untimed CPU2 Deflate wire preflight; they collect no
throughput or RSS samples. Performance/resource matrix releases require the
subsequent quiet window.

## Remaining gates

Complete integration checks, then obtain independent current-source A/B, direct
historical-anchor and pinned libbrotli comparisons with unchanged public
lifecycle and codec policy. The three-codec industry-best objective remains
unfulfilled; this slice only removes one identified source of repeated work.
