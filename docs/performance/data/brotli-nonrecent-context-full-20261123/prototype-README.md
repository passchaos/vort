# Nonrecent prepared context candidate prototype

Status: bounded correctness proof passed; not adopted, no performance timing.
Source is an isolated git archive of clean main b929184e4f815773f9fde0d2c40224a0a5dcf938.
It contains none of the rejected recent match-evidence cache experiments.
Main source files were not edited; no commits were made.

## Eligibility and required invariants

The prepared/counting/winner-only group now supports ordinary
use_recent_distances=false, preserving same-last on/off requests in its key.
Group entry still requires input >= 8 KiB, literal-context proposals enabled,
clustered proposals enabled, a standard window, and supported complete headers.
The tested scope is bounded through 8 KiB; larger-input acceptance needs main gates.
Prepared remains limited to standard windows 10..24, distance alphabet <= 79,
no command/distance/literal block splits or entropy plan, no output-model/final
wire-state side effects. Metadata/large-window/disabled-context routes retain
ordinary fallback. Exact commands keep their 0/15 complete-frame constraint.
The independent distance-context writer is explicitly excluded from common
reuse; no special-writer recoding semantics were expanded.

Simply removing the recent-only gates would be incorrect. Nonrecent same-last
selection changes final command/distance histograms after baseline symbols and
extras were collected. Cold write/count now capture the original accepted
SameLastDistancePlan together with corrected payload_extra_bits and canonical
codebooks. Warm write reuses that plan. Counted capture constructs both encoders
before changing payload/plan data and publishes ready last. On failure ready is
withdrawn and existing data is not partially replaced.

Prepared emission honors the requested recent flag, gives exact representations
priority, and maps accepted same-last shapes to the saved implicit versus
explicit-distance-zero form. The <= 128 baseline command symbol cache is bypassed
when an accepted same-last plan is enabled; larger and smaller command streams
therefore share the same final recoding semantics. This prototype does not
materialize a new array of recoded symbols.

The candidate controller reports the actual recent flag, keeps proposal order,
duplicate checks, strict ties, alternates and proposal-zero cutoff. Nonrecent
without an explicit context request returns before plain arbitration regardless
of ratio. Explicit requests retain strict comparison against the plain wire.

## Final proof

Debug and ReleaseSafe each pass 33 selected/import-wrapper tests:

- 104 cold ordinary-write/cold-count/warm-count/prepared-emit rows compare exact
wire bytes, all encode stats, common codebooks/frequencies/extras/recoding plan,
and decoded output. Cases include ordinary greedy/lazy commands, same-last
accepted/rejected and on/off, <=128 and >128 commands, distance params0/15 and
0/0, suffix/bounded16/full64 contexts, exact and mixed exact/ordinary commands,
and static-dictionary plus ordinary history copies.
- Pinned Dickens 8 KiB q10/q11 public outputs compare against the old materialized
nonrecent controller, using generic/window 16/command-state 8. Both outputs and
summaries are identical, and 14 actual nonrecent groups execute. The fixture
SHA256 is 602ff7349c8ca821c5d560915480aff05096986b89396b059b09ebce046dc48c.
- Aggregate direct prepared output failure checks cover 2 actual emit OOM cases,
valid common/literal state retention, atomic invalid-codebook capture, changed
and mismatched keys, reset/retry, group exact heap cap versus cap-1, and outer
stats rollback. The allocation sweeps did not encounter count-path OOM on this fixture;
encoder publication is tested with invalid canonical lengths, while the
emit and group-budget OOM checks exercise actual allocation failures.
- Metadata, large-window, disabled-context, no-explicit-request and special
writer fallback boundaries are exercised. Source immutability comes from the
borrowed const command/input contract and unchanged source/fixture hashes.

Final existing candidate ownership/primary decision/same-last controls pass 28
selected tests. prior-stage-existing-controls.log is kept distinct and is not
bound to final source hashes. Authoritative logs are final-debug-proof.log,
final-releasesafe-proof.log and final-existing-controls.log.

## Reproduce and review

See proof-results.json for exact commands. Direct Zig tests require the small
record_optimal_object.zig object, matching the repository test-br linkage;
no root/build edits or full default suite are needed.

source-sha256.json binds every changed source and the relative fixture.
nonrecent-context.patch applies to the clean base with GNU patch --binary -p1,
preserving the exact fixture line endings/EOF. Reverse dry-run passes.
source-overlay.tar.xz contains the same seven changed source/fixture paths.
original-source/ contains the clean base versions for review.

Next main-agent work: rebuild from these final hashes, then run the complete
public wire/resource matrix and whole-operation throughput/ratio/memory gates.
No performance gain or adoption is claimed by this proof.
