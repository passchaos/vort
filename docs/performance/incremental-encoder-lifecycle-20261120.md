# Accepted metadata and next-frame observer lifetimes, 2026-11-20

This increment follows the [incremental buffer admission work](incremental-encode-borrows-20261120.md)
with two ordinary public lifecycle sequences that were not covered by the
step-only regressions.

Brotli `writeMetadata("M")` followed directly by `finish()` discarded the
accepted metadata on stored, planned and static-dictionary encoders. The empty
fixture emitted `06`, while explicitly draining the metadata before finish
emitted `2c004d03`. Preserving the flush request also requires delaying final
plaintext blocks until the pending metadata has been emitted.

Zstd serial next-frame setup could publish a new memory profile over bytes
supplied as the next prefix, before installing that prefix. Parallel setup
could publish a changed heap limit into an old profile after the caller selected
those bytes as the next prefix and removed that observer from the new options.
The latter changed a caller's 64 MiB limit bytes into 65 MiB before successful
handoff. Prospective admission now rejects new observer/read conflicts before
publication and permits ended prefix/observer storage to change roles safely.

The [lifecycle contract](../formats/encoder-lifecycle.md) describes caller
lifetimes and the public verification commands. Raw failures, isolated patches
and current-source logs are under
[data/incremental-encoder-lifecycle-20261120](data/incremental-encoder-lifecycle-20261120/).

## Validation

Current-source native tests pass: Brotli 35/35 runner tests, with 60 exact-wire
comparisons between immediate finish and explicit metadata drain, plus 60
frozen no-metadata wire controls; Zstd 27/27 runner tests validate serial and
parallel preset/exact-size conflicts, unchanged caller/profile/state bytes,
disjoint retry and bidirectional observer/prefix reuse. Isolated neighbor suites
also passed 73/73 parallel and 91/91 incremental Zstd tests, and 26/26 Brotli
generic bridge tests.

`check-encoder-lifecycle` passed 28/28 build steps and 124/124 native/x86 runner
tests. Actual WASI executed the same two suites through `_start` and produced a
successful receipt. `check-library-tests check-encoder-lifecycle-wasm` passed
13/13 steps, compiling the entire current library test suite.

The current Zstd complete interoperability matrix passes 171/171 cases against
the pinned libzstd 1.6.0 library/header. Current Brotli reference interoperability
also passes against libbrotli 1.0.9: 98 main cases, 7,056 generated fixtures and
their progressive replays, with metadata/window/chunked/operation controls.
Current `zig build -j2 check check-wasm --summary all` passed 401/401 steps and
86/86 native/x86 auxiliary runner tests. The original full ReleaseSafe test
execution completed successfully: 11/11 build steps, 5,716 runner tests passed
and two skipped. Compilation took 116 minutes with 25 GiB MaxRSS; execution
took 11 minutes. `source-before-brotli-setters.json` binds that snapshot, while
later setter increments have separate evidence. The preceding
buffer-admission snapshot separately passed the complete Debug suite with
5,710 passed/two skipped and 394/394 build-check steps.

This is functional and wire-compatibility evidence; the overall compression
goal remains active.
