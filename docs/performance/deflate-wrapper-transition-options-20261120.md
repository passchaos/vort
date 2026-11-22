# Deflate wrapper transition option admission, 2026-11-20

Gzip `nextMember` could accept an invalid filename/comment or an oversized
extra field, reset the completed member and fail only while writing the next
header. Independent before regressions observed a successful transition for a
filename containing NUL instead of `BadGzipHeader`, and a successful zlib
exact-size transition with cap zero and pledge one instead of
`OutputLimitExceeded`. Zlib/gzip exact-size transitions accepted pledges larger
than the raw input cap, making the new stream impossible to finish under its
selected limit.

All four Fixed/Best gzip member transition variants now validate header fields
after borrow admission and before mutation. They retain the existing header
errors: `BadGzipHeader` for filename/comment NUL and `IntegerOverflow` for
extra fields above 65,535 bytes. Exact-size variants and zlib
`nextStreamExactSize` validate the pledge against the proposed raw cap;
header-only gzip exact transitions use the active raw cap. An impossible
pledge returns `OutputLimitExceeded` at the transition boundary.

Validation reuses the existing header-size and raw-option validators. Header
emission and successful stream planning retain their existing implementations.
The public [lifecycle contract](../formats/encoder-lifecycle.md) records the
new refusal behavior and caller retry boundary.

## Validation

The expanded narrow runner passes 12/12 tests. Its contract matrix covers
Fixed/Best encoders, all four gzip variants, filename/comment NUL, a
65,536-byte extra field, header error precedence, valid empty/nonempty fields,
FHCRC, zero header fields and compression-level changes. Zlib/gzip exact-size
tests cover input caps zero and three, over-cap rejection and legal boundary
pledges.

Each rejection compares the complete receiver, full retained capacities,
caller bytes, six allocator counters and allocation-failure state. A clone
made before rejection supplies the successful retry wire oracle. Concatenated
decode, two-member counters, cumulative input accounting and parsed gzip
header fields validate the completed retry.

Current `check-encoder-lifecycle` passes 33/33 build steps and 192/192
native/x86 runner tests. Actual WASI execution passes Deflate, Brotli and Zstd
through the Zig test runner `_start`. Complete library test compilation plus
the lifecycle WASI compilation passes 14/14 steps.

Current libz parameter interoperability passes 8/8 build steps against runtime
zlib 1.2.11. The matrix covers three wrappers, six main bidirectional cases,
six partial-flush cases, two sync-recovery cases and 84 parameter changes.
Complete library execution and `check`/`check-wasm` passed 406/406 build steps,
with 5,825 passed tests and two skipped. The root library run passed 5,732
tests with two skipped, executing for 56 minutes in Debug. This result binds
the frozen wrapper/lifecycle source before the subsequent differential
reporting and dynamic Huffman admission increments. Previous complete
Debug/ReleaseSafe results retain their earlier source snapshots.

[Raw evidence](data/deflate-wrapper-transition-options-20261120/) retains the
initial before/after logs, two independent before logs, baseline/runner archive,
source hashes, architecture log, complete-library compilation log, reference
log and successful WASI receipt. The independent before runs each compiled
successfully and failed their target assertion with 11 auxiliary tests passing.
Their production baselines come from the three pre-option-validation Git index
blobs recorded in `before-source-provenance.json`. This increment closes a
functional retry gap; the broader compression objective remains active.
