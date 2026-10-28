# Inlined sequence price evidence

The ordinary baseline is `9433c9bb`, including exact row tags. The sole
candidate change is `pub fn` to `pub inline fn` on `sequencePrice`; the complete
function body is byte-identical. Its source and ordinary tests are preserved
with exact identities, raw paired times and full wire/profile artifacts.

The baseline source archive is shared with `zstd-prepared-row-tag-20261029`.
`ordinary-screen.tar.xz` preserves the measured candidate module, original
runner, compile/run commands, terminal statuses, code generation and all
4 KiB results. `inputs.tar.xz` supplies actual inputs. Native runner binaries
and caches are excluded; their measured hashes are recorded.

The `large-trained` subdirectory is a separate one-round experiment on Mozilla
16 KiB and a trained-dictionary 8 KiB input, using the unchanged large-input
runner and identical reference bytes. Final source/platform and bidirectional
records are stored separately from the timing prototype. This package does
not combine the deferred prepared-tag variant with the retained pricing change.

`source-contracts.tar.xz`, `current-validation.json` and `source-validation.json`
freeze the retained price module, independent tests/root and successful
native/32-bit/Wasm, focused, reference and build terminal records. The compiled
WASI image and runner are retained for replay. Run this directory's `audit.py`
to verify all archives, the exact keyword-only runtime change, wire/profile
pairs, raw timing summaries, independent decoder records and final validation.
