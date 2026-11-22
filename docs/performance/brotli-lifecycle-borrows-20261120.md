# Brotli lifecycle borrow admission, 2026-11-20

The public incremental metadata setter accepted receiver or encoder-owned
storage and then made the queued request impossible to execute. With metadata
pointing at `flush_requested`, the setter also changed the metadata byte while
accepting it. `nextStream` similarly accepted metadata pointing at `done` and
then changed that byte during reset. Three public encoder facades shared these
paths.

Metadata requests now validate their read borrow before changing flags.
Next-stream setup validates new metadata/dictionary reads and future observers
against all owned capacity, plus the actual allocator observer that activation
can still write. Old external dictionary and ended HQ observer borrows are
released according to the new configuration. The existing ownership walker is
shared by the step and lifecycle checks.

The [lifecycle contract](../formats/encoder-lifecycle.md) documents retry and
observer release. [Raw evidence](data/brotli-lifecycle-borrows-20261120/) includes
the isolated before failures, verified patch, current-source regression logs
and portability receipt.

Current-source validation passes the new 43/43 lifecycle runner tests, existing
46/46 step-borrow and 35/35 metadata-finalization runner tests. Refusals verify
complete receiver, caller data, allocator and profile bytes, and unchanged
memory snapshots; retries require no reset. Cases also cover valid external
metadata, empty spans, complete/spare retained capacity, completed dictionary
storage reuse, ended HQ observer reuse and explicitly detached budget observers.

The combined lifecycle gate passes 28/28 build steps and 148/148 native/x86
runner tests. Actual WASI executes the combined metadata/lifecycle suite plus
the Zstd transition suite through `_start`. Complete current library test
compilation and lifecycle WASI compilation pass 13/13 steps. Current reference
interop passes against libbrotli 1.0.9: 98 main cases, 7,056 generated fixtures
and their progressive replays, including window, metadata, chunked, static
transform and operation-schedule controls. The run contains no real-file corpus
and makes no throughput claim.

The original whole-library ReleaseSafe run completed with exit zero: 11/11
build steps, 5,716 passed tests and two skipped. That result binds the snapshot
before this setter increment. The raw directory retains the earlier live
checkpoint and a separate terminal receipt. Later source has the current
validation scopes above. Prior snapshots separately passed complete Debug
tests and native/WASM build checks. The overall compression goal remains active.
