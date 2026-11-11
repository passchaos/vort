# Shared Deflate chunk borrow correction, 2026-11-11

Commit `b6709ae9f210781ff3b1d90998d57e005fb8b32b` fixes successful wrong
decoding when compressed scratch overwrites an unread chunk or preset
dictionary during coalescing. A two-span stored fixture previously returned
header bytes `010400fb` instead of `abcd`; another fixture overwrote its
dictionary and returned corrupted content with a success result.

The allocation-free shared join validates all copies and operation borrows
before its first write. Its callers protect dictionary bytes, descriptor
tables, complete output/append allocations and objects, reusable receivers
and retained buffers. Outer PNG callers protect row/image buffers before
installing state. Admission conflicts return `InvalidBlockPlan` with protected
bytes and state unchanged.

Single nonempty sources keep their zero-copy path and ignore unused scratch.
Identity layouts remain valid, and current chunks can move in either direction
without corrupting a future source. Original source storage can be reused for
output after a complete coalescing snapshot. Aliased append reads stage through
the caller allocator before output growth, with normal OOM propagation and
cleanup; disjoint append retains its existing direct path.

Validation passed the full Deflate family (698 tests), public-root gate
(94 tests), focused Debug/ReleaseSafe/x86 and actual 32-bit WASI contracts.
An independent normal executable also passed all **216 raw/zlib/gzip wires and
1,368 layout rows**, including one-byte fragmentation, packed identity and
both current-chunk moves. All 1,858 source files match the compiled epoch and
committed Git blobs.

The [evidence package](deflate-chunk-borrows-20261111/README.md) preserves exact
raw results, before failures, probes, WASI execution, committed source overlay,
producer settings and independent verification. Its checks are functional;
they do not update the prior decode throughput matrix or prove leadership.
The [borrow contract](../formats/deflate-chunk-borrows.md) describes supported
layouts, resource behavior and separate ownership surfaces.
