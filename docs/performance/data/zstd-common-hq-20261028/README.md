# Common requested HQ reference evidence

Runtime is `e29650ca`; tools are `50e709ce`. The manifest records the exact
tool source hashes, reference library identity, archives and members. The
state-shift package supplies the runtime baseline and final overlay.

- `tool-sources.tar.xz`: benchmark, option/pair modules, runtime parameter
  adapter, functional probes, evidence validators, provenance and build rules.
- `modern-functional.tar.xz` / `system-functional.tar.xz`: bounded actual
  CLI/evidence campaigns, frozen source/dictionary fixtures, reports, CSV,
  manifests, summary and private reference-library copies used by alias tests.
- `real-corpus.tar.xz`: actual 4/16 KiB and trained-dictionary input bytes,
  runner script/config, each command and terminal status, raw two-round JSON,
  CSV, manifests and complete profiles. `real-summary.json` is a readable view.
- The validation JSON files preserve earlier independent probe/gate commands
  and observed statuses. Final parent validation is recorded separately.

Extract the frozen tools over the runtime snapshot to reproduce. The two
build entrypoints are `test-zstd-reference-parameters -- LIBRARY...` and
`test-zstd-common-hq-bench -- --libzstd LIBRARY --output-dir DIRECTORY`.
The real campaign script's structured paths can be rewritten to relocated
inputs, executable and reference. Keep its flags and two alternating rounds.
The reference getter metadata remains requested, including default sentinels;
the search budget mapping is nominal. The main report explains timing scope
and limits.

`final-tool-overlay.tar.xz` and `final-functional.tar.xz` preserve the
`a66c067d` level-zero boundary fix and both expanded functional campaigns.
They reuse the earlier private reference-library identities; the original
14-row real epoch remains frozen. `current-validation.json` records final
terminal statuses and these additional identities.
