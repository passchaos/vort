# Deflate64 predecessor capacity and requested allocation

Date: 2026-10-25. Baseline: `35229f7c`. The industry-best functionality and
performance objective remains incomplete.

The full-range Deflate64 matcher previously allocated32768 hash heads and65536
predecessor links for every nonempty input, including a16-byte payload. This
increment sizes predecessor storage to the actual local history/input span.
The hash function,32768 heads, matching budget/tie order,65536 distance window
and65538 maximum match remain unchanged. All measured wires are identical.

## Capacity, growth and exact matching

`requiredPreviousLen(span)` is the next power of two of`max(1,min(span,65536))`.
For a span below65536, the allocated ring covers every valid local coordinate,
so no two inserted positions share a slot. At larger spans the ring is65536
and has the original wrap behavior. One-shot planning prepares each borrowed
chunk's history+input span; the streamed encoder prepares its current history
plus pending input. The completed first one-shot pass retains sufficient capacity
for replay without new allocations.

`ensureForSize` grows capacity without shrinking it. Reset retains that capacity.
Every subsequent matching pass rebuilds hash heads and reachable predecessor
links, so successful growth does not copy a previous pass's chains. All input
and history references are cleared before capacity changes between one-shot
passes; failed allocation preserves the old index state and references.

Growth first asks the backing allocator to remap an existing predecessor
allocation. Success transfers its ownership directly and no further fallible
operation follows. A refused remap falls back to new-allocation-before-old-free;
that fallback can temporarily own both rings. Allocation failure preserves the
old pointers, lengths and initialized links, and releases provisional new heads.
Memory measurements report this ownership accurately rather than assuming
all allocators support remapping.

The existing full-size `ensure` remains as a reference/internal preparation
route. Explicit capacity size is not a new compression window or match-search
limit. Deflate64's public options and output behavior remain unchanged.

## Independent tests and output evidence

The matcher contract uses a frozen copy of the original full65536-ring matcher,
whose function payload hash matches the original source. It does not merely
compare two modes of the optimized implementation. Tests compare complete
length/distance results, initialized links, selected byte positions and every
actual match-token position over random/repetitive/zero inputs, history0/16/
32768/65536, spans around powers of two and128KiB input. Actualdistance65536
and length65538 are preserved.

Capacity tests cover0 throughusizeMax numeric arguments, monotone growth and
retained reset storage. Initial head/link allocation failures and forced remap+
allocation refusal preserve old ownership and match results. A fixed buffer
allocator separately exercises in-place remap success. Uninitialized predecessor
tails are not read by comparison tests.

Final native Debug, native ReleaseFast and actual32-bit x86 each pass the complete
Deflate64 suite100/100, including one new matcher contract matrix. An earlier
core verification ran while the independent resource tool was being created;
its coding/test sources remained unchanged and source-scope audits record that
tool-only difference. Final runs bind the completed source/tool epoch separately.

The complete native ReleaseFast ZIP/codec suite passes1993/1993 under a
stable fullsource snapshot. Final build checks pass177/177 and CLI help7/7. The focused ZIP method9 suite passes44/44.
Independent Python token parsing and
Info-ZIP verify48 actual raw/ZIP artifacts64 member plaintexts per target on
native and x86. Their complete
input/wire/progress manifest equals the preceding revision's manifest, including
full-distance/length boundaries and300000-byte cross-block encoding. No new
approximate pricing or candidate limit produces the allocation improvement.

## Requested allocation measurement

`deflate64_index_probe.zig` calls the same public Deflate64 APIs against old and
current modules. The input recipes, decoded-output checks, wire collector and
JSON metadata use an untracked allocator. Only codec requests, including its
returned owned raw output, enter the fixed-slot allocation tracker. Successful
alloc/resize/remap/free updates logical current/peak requests; the backing
allocator's private slabs, physical remap transients, stack and RSS are excluded.

Seven one-shot inputs record full input/wire hashes, round-trip verification,
allocation events, cleanup and selected real allocation-failure checks.
The streamed pass reuses4KiB input for4MiB with small caller output and tracks
capacity checkpoints; it independently reconstructs/decodes the complete wire
through an untracked collector. Initialization allocates nothing and deinit
releases all codec requests. Peak is not the same as any one checkpoint's
retained capacity or total cumulative request bytes.

| One-shot input | Old peak requested bytes | Candidate peak requested bytes |
| --- | ---: | ---: |
| Empty | 2 | 2 |
| Tiny16 | 393234 | 131154 |
| Pattern12079 | 393262 | 196654 |
| Random4097 | 397318 | 167942 |
| Random16387 | 409608 | 278536 |
| Repeat65539 | 393222 | 393222 |
| Distance131072 | 462314 | 462314 |

The4MiB streamed pass finishes with the same462909-byte requested peak as the
old matcher and retains the same full index after warmup. Four growth remap
attempts include two successes in this backing allocator. The first allocate-
before-free-only candidate instead peaked at593981 bytes; that result drove
addition of the remap path and is retained as a separate source/executable
epoch. Refused-remap fallback retains the overlap tradeoff, so the final result
does not imply every allocator has the same peak or uniform memory leadership.

All one-shot and streamed input/wire identities match old/current, and all
tracked requests release after output free/deinit. The small table reduces
predecessor payload;32768 hash heads still cost131072 bytes. Tiny hash-head
specializations or match-free short-input paths require independent future work
if their compression behavior changes.

## Timing scope and limits

Optional timing uses a noinline public encode/complete-output-checksum/free
helper through a plain allocator. The tracker, input generation, hash/decode
verification and streamed resource pass are outside that timer. Three alternate
old/current process pairs use100 calls per five raw rounds on CPU8, i7-10700K,
Zig0.16.0 ReleaseFast. Source/executable identities remain fixed and compiler
observations are zero. These are point timings with checksum/free included,
not exclusive matcher CPU cycles or a competitor comparison.

The measured small-input resource gains do not prove throughput gains on all
cases. Median per-pair point speedups are0.991503x empty,1.050315x Tiny16,
0.987761x Pattern12079,1.083390x Random4097,0.994060x Random16387,
0.968706x Repeat65539 and0.975177x Distance131072. Geometric aggregate over
all input/pair ratios is1.005803x, without a statistical-significance claim.
The repeat full-window points are negative despite unchanged allocation size;
that throughput tradeoff remains explicit in this requested-memory increment.

A full/small constant-index specialization was also tested, but its repeat
points were0.959985x/0.963626x/0.955621x and did not support a benefit. The
extra code was withdrawn; final source retains the simpler variable-ring mask
with exact prior matches. Its source/raw timing is separate experimental
evidence. ELF inspection identifies extra length/mask work in the initial
variable-index loop and retained full-output checksum calls, but those static
instructions alone do not establish a measured CPU-time cause.

The [evidence package](data/deflate64-index-capacity-20261025/artifact-manifest.json)
retains full-ring reference, allocate-first and remap
source epochs, requests/cleanup and raw timing, independent references and
final handoff. The parallel read-only dynamic-encoder plan identifies next
functional work:32 distance symbols, extended285 lengths, bounded318 code-length
entries, actual histogram/RLE costs and exact stored/fixed/dynamic arbitration.
Dynamic Huffman, dictionaries and broad quality/platform/memory leadership
remain incomplete.
