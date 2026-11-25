# Dictionary setters and wrapped encoder transitions, 2026-11-20

This functional increment extends the [lifecycle contracts](../formats/encoder-lifecycle.md)
to Zstd binding setters and Deflate's independent zlib/gzip member transitions.

Before the change, serial and parallel Zstd setters accepted receiver/profile
storage as a new prefix/dictionary, modified it, and deferred conflict rejection
until the next step. Four ordinary public setter regressions failed, including
two observed input-byte mutations. Setters now admit new content, standard
backing and prepared state against current observers, receiver and full owned
capacity before mutation. Parallel stable checks run before queue locking.
Empty bindings, replacement reads and busy-state errors keep their behavior.

The zlib/gzip transitions similarly accepted metadata or dictionary bytes from
the completed encoder object and changed them during reset. The first before
case returned success instead of `InvalidBlockPlan`. Transition admission now
protects the prospective dictionary/header reads and permits replacement of
the ended immutable configuration. It runs before resetting raw history,
pending output, checksum and member counters.

## Validation

Current-source Zstd setter tests pass 29/29 runner tests, with prefix lifecycle
27/27 and existing step borrows 26/26. Cases cover RAW/FULL/prepared reads,
current exclusive/shared observers, owned spare storage, clear/re-attach,
replacement and disjoint retry, and native held-mutex rejection.

The Deflate transition matrix passes its 12-test filtered runner. It exercises
both fixed/best wrapper types across two zlib and four gzip public transition
variants, all three gzip header metadata fields, natural retained full/spare
capacity, receiver conflict, unchanged caller/state storage, rejection-before
clone wire controls, exact member pledges and compatible concatenated decode.

The combined lifecycle gate passes 33/33 build steps and 180/180 native/x86
runner tests. Actual WASI executes all three codec families through `_start`.
Full current test-suite and lifecycle WASI compilation pass 14/14 steps. The
current libzstd 1.6.0 complete differential matrix passes 171/171 cases.

Evidence is retained under
[data/encoder-binding-setters-20261120](data/encoder-binding-setters-20261120/).
The original complete ReleaseSafe test job passed its separately recorded
pre-setter snapshot: 5,716 tests passed and two skipped. Compilation took 116
minutes; execution took 11 minutes. This current setter increment is verified
by the focused, neighbor, native/x86/WASI, complete-test-compilation and reference
results above. The overall compression goal remains active.
