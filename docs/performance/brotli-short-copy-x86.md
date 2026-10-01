# Brotli ordered short match copies

Date: 2026-10-02. Baseline: `70c25c1f`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
local libbrotli 1.2.0-dev (`558fc647`), CMake Release (`-O3 -DNDEBUG`).

## Remaining literal fallback cost

A non-timing audit of the frozen roadmap input finds 47,239 decoded literals
at quality 9: 46,779 short-root hits, 271 ten-bit sibling hits, and 189 longer
fallbacks (165 eleven-bit and 24 twelve-bit). Quality 5 has 53,639 literals,
242 sibling hits, and 247 longer fallbacks (246 eleven-bit and one twelve-bit).
Long fallbacks therefore account for about 0.40%/0.46% of literals.

A separate 100-decode diagnostic measures 2,820,855/2,470,710 ns inside these
fallbacks at q9/q5, including timer overhead. The corresponding per-frame
cost is about 28/25 microseconds, roughly 1% of complete decoding. Only 24/13
packed-tree expansions occur per frame. Expanding all long-code tables is
therefore deferred in favor of the more frequent match-copy path.

## Copy implementation

The previous helper used a fixed 16-byte copy for eligible short matches and
a dynamically sized copy beyond 16 bytes. The retained helper handles lengths
1--32 at distances of at least 16 using ordered 16-byte moves when the current
meta-block has enough writable space. It emits the second move only for
lengths above 16; near the end, the original 16-byte and exact-copy fallbacks
remain available.

Ordering is necessary at distances 16--31: the first move initializes the
history that the second move may read. Each individual 16-byte source and
destination range is non-overlapping. A single 32-byte move would not satisfy
that property for these distances. All speculative bytes remain inside the
meta-block, and zero-length calls retain their no-write behavior.

The local reference's `ProcessCommandsInternal()` also starts with a 16-byte
move and uses another fixed move for the 17--32 range. Vort keeps its stronger
caller-buffer boundary instead of relying on private ring-buffer padding.

## Rejected variants

Adding one 32-byte copy only for non-overlapping distances of at least 32
measured 0.9994x median on roadmap q9, 0.9837x on source q9, and 0.9866x on
clustered q8 across seven pairs each. That variant was removed.

Changing the paired literal lookup result to a byte type, to remove the
caller's redundant range check, regressed roadmap q9 to 0.9619x median versus
the ordered-copy candidate, with 0/7 wins. Its baseline-relative result was
0.9725x. The type change was also removed; the retained change is confined to
the match-copy helper.

## Validation and measurement

The new scalar replay oracle covers distances 1--64, lengths 0--64, and six
different writable suffix lengths. It compares the complete logical prefix,
the physical caller suffix, written-byte accounting, and zero-length no-op
behavior. It passes in Debug and ReleaseFast.

All 548 direct Brotli tests pass, as do 7,056 upstream generated cases and
their 7,056 progressive counterparts, 1,401 fragmentation schedules, 64
high-tree truncations, seven Large Window cases, and the four-file 16/16 real-
corpus matrix. AArch64 copy tests are cross-compiled and linked, not executed
on this x86 host.
Changed Zig source passes formatting checks; `zig build check -j2` and
`zig build run -j2 -- --help` also pass.

Inputs are frozen files from `488c5415`. Full reference comparisons alternate
Vort/libbrotli within each of five warmed rounds and reverse baseline/candidate
process order on successive pairs. Decoder-only controls use the same five-
round estimator and reversed process order. Every comparison requires matching
sizes, iteration counts, and decoded checksums; full comparisons also record
input and executable hashes.

The final candidate's complete-frame comparison against the frozen baseline:

| Input | Pairs won | Median | Geometric mean | Minimum pair | Candidate/libbrotli median |
| --- | ---: | ---: | ---: | ---: | ---: |
| roadmap q9 | 15/15 | 1.0181x | 1.0174x | 1.0050x | 0.7456x |
| roadmap q5 | 7/7 | 1.0138x | 1.0156x | 1.0056x | 0.7584x |

The reference-normalized geometric improvement for q9 is 1.0181x.

Final decoder-only controls measure source q9 at 1.0033x median / 1.0042x
geometric (6/7 wins), source q5 at 1.0045x / 1.0056x (6/7), and clustered q8
at 1.0006x / 1.0018x (8/15). The clustered median is treated as neutral. The
final 13-row reference gate passes its existing throughput floors, and the
input-path smoke passes three valid rows and five rejected argument cases.

These are workload-specific warm decode measurements. The broader Zstd/Brotli
performance and functionality goal remains open.

Exact timings, commands, hashes, reference builds, diagnostic instrumentation,
and rejected candidate patches are in
[brotli-short-copy-x86-20261002.json](data/brotli-short-copy-x86-20261002.json).
