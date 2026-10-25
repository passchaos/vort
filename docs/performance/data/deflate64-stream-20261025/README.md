# Deflate64 compressed incremental evidence, 2026-10-25

Baseline is 0cf32f1f. New raw/ZIP method9 incremental output supports actual
fixed matches through65538 lengths and65536 distances with bounded ownership;
previous stored and one-shot APIs retain their behavior.

- `codec-debug/`, `codec-x86/`: initial ambiguous module/nested Error aliases.
  Core fixed runs qualify those type names without changing algorithms.
- `codec-*-fixed/`: original real token/roundtrip/failure contract runs183/183.
  `codec-*-final/`: final183/183 including4MiB/1024blocks bounded ownership.
  The helper's resetExactSize call spelling was corrected before compilation.
- `zip-debug/`: initial test placeholder needed explicitu32 type.
  `zip-debug-fixed/` and `zip-x86/`: earlier39-test method9 suite. The x86
  run's broad snapshot detects only a later build.zig test-route addition;
  `source-scope-audit.json` identifies unchanged codec/test sources.
  `zip-debug-final/`/`zip-x86-final/`:41 tests including encrypted failure/PKWARE
  success, under stable complete source snapshots.
- `zip-complete/`:1987/1988 complete ZIP tests pass; the only failure is a legacy
  test expecting default method9 to remain stored-only. The corrected fixture
  explicitly selects .stored while preserving its block size and assertions.
  `zip-complete-fixed/` records the final complete run separately.
- `independent-diff/`, `independent-x86-diff/`, `reference*-fixtures/`:
  native/x86 public-probe raw and ZIP outputs at tiny/zero quotas, independently
  inspected tokens and Info-ZIP UnZip6.00 full contents/CRC/descriptors. Each
  target has28 artifacts42 members58 recorded commands. Binaries are not
  checked in; all inputs are deterministic recipes with length/hash identities.
- `complete-check/`, `final-check/`, `cli-help/`: global compile/API validation.
- `architecture-review.md`, `final-review.md`: independent read-only invariant
  audit. Diagnostic Snapshot is not a clone or checkpoint.
- `post-rebase/`: final ReleaseFast183 codec/41 ZIP handoff, separate from
  reference or performance evidence.

The stored alternative is costed per actual block segmentation/bit offset;
old one-shot encodedBound is not reused for incremental flush overhead. Input
caps validate the full offered slice. FailedProgress is the first failed call's
actual delivered/accepted prefix; later errors are sticky and do not repeat
that progress. PKWARE bridge bytes are not charged as published ciphertext.

Requested payload/state/stack/RSS are distinct concepts. Bounded4MiB test does
not retain a full wire or measure RSS. Encoded fixture sizes are functionality
proofs rather than cross-library throughput/ratio or industry-best evidence.
Raw logs may contain original whitespace; source and report hashes bind the
artifacts byte-for-byte. No executable/object/corpus/archive binaries included.
