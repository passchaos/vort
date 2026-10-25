# Deflate64 one-shot full-match evidence, 2026-10-25

Baseline runtime is06d8909c. The candidate reuses bounded streamed match and
wire emission over borrowed128KiB blocks/64KiB history, preserves the original
whole stored bound and output transaction/alias behavior, and widens nice_length
without rejecting previously valid0..2 values.

- `old-sizes.json`, `old-sizes-binding.json`, `old_sizes_probe.zig`: frozen
  default old-codec output sizes and exact probe identity. The `old_probe.zig`
  source later adds allocation counters; its original size-only source is
  reconstructed/hash-matched as `old_sizes_probe.zig`, not retroactively bound
  to the modified probe text.
- `old/new-allocation-sizes.json`, `allocation-size-comparison.json`: default
  settings encoded sizes/allocation count/total requested bytes, not peak/RSS or
  performance. Initial wide-candidate emit decisions match the final fix on
  these inputs; final same-input check confirms output hashes separately.
- `initial-candidate-source/`, `initial-validation-epoch.json`, `codec-*`,
  `zip-*`, `independent-diff/`, `reference-fixtures/`, `zip-complete/`,
  `complete-check/`: first correct full-wire candidate, before the private wide
  pricing fix. An independent review identifies a losingfixed candidate that
  can exceed usize despite a representable stored choice. Those tests and
  reference runs retain their actual initial source epoch, not final results.
- `wide-candidate-audit.json`, `wide-cost-proof.json`: numeric boundary audit and
  correction. Finalu128 complete costs compare wide before narrowing a strict
  winner; no huge physical input allocation/encoding is implied by proof/tests.
- `final-*`: corrected privateu128 pricing and exact output boundary tests,
  same-wire old/current reference replay and final complete source snapshots.
- `architecture-review.md`, `final-review.md`, `doc-review.md`: independent
  read-only source invariants and current versus historical evidence boundaries.
- `post-rebase/`: final codec/ZIP handoff under stable fullsrc/tools/build hashes.

The schema-v2 reference matrix contains8 cases×6 artifacts=48: streamingraw and
known/unknown ZIP at two chunk patterns plus one-shotraw and known-size ZIP.
Target streams actually encode maximum65538 lengths/65536 distances and3fixed
blocks for a300000-byte input. One-shot pattern/progress is null, not fake
streaming accounting. Info-ZIP independently decodes every member, while Python
validates token geometry, descriptors, CRC and the original global stored bound.

No original/reference encoded binary, input corpus, executable or compiler object
is checked in; recipes and raw identities/reports are retained. Total requested
allocation bytes are not simultaneous peak, stack or RSS. Rawgeneratedlogs may
retain trailing spaces, bound by SHA. This functional increment does not establish
all-level/corpus/platform throughput or complete industry-best behavior.
