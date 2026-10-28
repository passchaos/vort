# Exact node cost comparison evidence

The ordinary baseline is `7adf8393`; the retained implementation is
`52eccf45`. The source/build baseline, exact candidate row-tag module,
non-FP ordinary runner, original commands, raw times, full wire/profile
records and code generation are retained with SHA-256 identities. Native
compiled runners and caches are excluded.

`ordinary-screen.tar.xz` is the two-round 4 KiB screen; `large-trained.tar.xz`
is the independent one-round Dickens/Mozilla16KiB and trained8KiB matrix.
They remain separate measurement epochs. `reference-decode.json` records
exact libzstd decoding of all 36 ordinary wire artifacts and the library
identity. `inputs.tar.xz` and the larger archive contain actual input bytes.

The `deferred-edge-borrow` directory preserves the separate pointer-parameter
alternative, its full ordinary screen, frozen current-edge contracts and
borrowed argument lifetime/alias checks. Its baseline and input identities
are shared with this package; the implementations were never combined.

Final source/portable contracts and reference terminal records are archived
separately from the timed prototype. Reproduction extracts the baseline,
overlays the chosen candidate or final test source and rewrites the archived
structured command paths while preserving flags, CPU affinity and inputs.
The report documents exact behavior and the uncertain small-input timing point.

`source-contracts.tar.xz`, `source-validation.json` and
`current-validation.json` bind the retained implementation and independent
frozen-reference tie matrix to actual successful native, 32-bit, WASI, focused,
reference and build terminal records. The WASI image and runner are available
for execution. Run this directory's `audit.py` to recompute source identity,
paired timing summaries, wire/profile agreement and all validation records.
