# Zstd larger native history and total requested heap

`FrameOptions.max_match_history_len` and
`NativeFrameOptions.max_match_history_len` select an encode-side history limit
when `window_log` is explicit. The old 64 MiB ceiling is replaced by a shared
coordinate bound. Defaults retain their existing policies: null `window_log`
uses the established 8 MiB history, and an explicit window with null history
uses the established 16 MiB limit.

## Range and actual use

The supported history ceiling is derived from the smaller of the platform's
`usize` maximum and the reserved u32 coordinate boundary, minus one and one
complete 128 KiB block. On current 32- and 64-bit targets this is
4,294,836,222 bytes. The public `native_explicit_window_match_len_max` exposes
that ceiling. A request outside the supported range fails explicitly.

`configuredWindowSize()` reports the optional configured window from the
requested log; it has no input bytes with which to inspect a final frame. For
known content that fits that window, the writer may use a single-segment header
whose actual wire window equals the content size. Inspect the output header
when the actual declared window matters. The resolved match-history policy is
the smaller of the configured window and the requested/default history limit;
`effectiveMatchHistoryLen()` exposes that policy. Profile policy fields are
configuration information, distinct from the final header, observed retained
bytes or heap peaks. Non-single-segment headers can describe window logs
10...41 without implying a 2 TiB matcher or allocation.

Source coordinates, prefix and block sums, repeat offsets and wire offBase
values remain checked. Dictionary suffixes and completed-frame history share
the logical prefix allowance without allocating a complete joined prefix.
History grows from actually completed input rather than allocating the full
requested window for a small stream.

Strategies retain distinct search coverage: fast/double-fast and the general
search index sample older prefix positions, while HQ trees index their complete
accepted prefix. Larger visible history does not promise exhaustive matching
or reference-algorithm equivalence. Explicit large history also reaches the
legacy fast-compressed selector's controlled search path; a header-only change
cannot substitute for ordinary cross-block matching.

Raw/RLE-only incremental encoding retains no unused matching history. Its
declared window and resolved policy remain queryable, while actual retained
match bytes can be zero. Content-size and window-header decisions remain
separate from the caller's requested history cap.

## Total requested-heap budget

Both frame option types expose `max_total_working_memory: ?usize = null` and
`memory_profile: ?*EncodeMemoryProfile = null`. The profile contains
`available`, `peak_requested_bytes`, `live_requested_bytes` and `limit`, with
reset/merge operations. HQ's `max_working_memory` remains a separate inner
workspace budget.

The total policy counts actual encoder-owned requested allocations: retained
history and indexes, pending/plain/scratch buffers, dictionary preparation,
matchers and forks, records/models, alias snapshots, candidate/frame output
until ownership transfer, and caller-allocator requests for worker control and
stack storage. Borrowed input/dictionaries, caller-provided output, fixed
current-thread stack, allocator bookkeeping and unobservable backend/OS
transients are excluded. These measurements are not RSS.

A stable shared allocator authority enforces admission before allocation.
Nested encoders and worker jobs share the same quota, and retained allocations
are adopted using allocation capacity rather than logical length. Old/new
buffers that coexist during caller-visible moving growth are both counted.
The null-limit/null-profile path creates no budget-control allocation.

The ledger synchronizes allocator, reserve, ownership and profile operations.
Only the operation coordinator can reconfigure policy or reset its failure
interval. Quota refusal remains visible until classification, even if another
worker subsequently allocates successfully. Backing `OutOfMemory` and
`WorkingMemoryLimitExceeded` therefore remain distinct; a denied history or
workspace request cannot silently reduce the requested policy.

Call-scoped profiles are detached after reusable calls. An incremental profile
stored in options follows its documented encoder lifetime. Result ownership
transfer, next-frame changes, reset and failure paths keep the allocator
authority valid until the last retained allocation and lease are released.

## Validation boundaries

```sh
zig build test-zstd-large-history -Doptimize=Debug --summary all
zig build test-zstd-large-history -Doptimize=ReleaseFast --summary all
zig build test-zstd-large-history -Dtarget=x86-linux-musl -Doptimize=ReleaseFast --summary all
zig build test-requested-heap-budget -Doptimize=Debug --summary all
zig build test-zstd-window-memory-cli -Doptimize=Debug --summary all
```

The reference driver `run-zstd-large-history-diff` separates small contracts
from its explicit `--run-far` campaign. A real input repeats an anchor at
64 MiB + 8 bytes; an independent sequence reader must observe that distance.
Exact/below budgets and old-window comparisons use the same input and settings.
Declared huge-window metadata is not treated as proof of a huge actual match.

The subsequent [stream-count increment](stream-counts.md) extends cumulative
byte counts, pledges and absolute history positions to a 64-bit domain on
32-bit targets. Local matcher geometry and physical allocation limits remain
unchanged. Full-sized configuration metadata and tiny-input preflight tests
remain distinct from actual long-stream runtime evidence.
