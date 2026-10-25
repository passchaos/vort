# Zstd suffix-preserving anchor-cache experiment

Date: 2026-10-25. Baseline production: `9cc8c477`, after the
[frequency-merge increment](zstd-frequency-merge.md). The industry-best
objective remains open.

This increment adds a bounded diagnostic surface for reusing anchor hashes and
adjacent-match lengths. Its measured improvement is too small to justify
adding its allocations to default encoding. Normal frame encoding continues
through the original uncached scanner; this is an investigated and validated
experiment, not a production throughput milestone.

## Pairing and cache scope

The original unindexed finder scans each suffix from its start, resetting
pending state independently for every hash bucket. Its pairs consume adjacent
occurrences, including collisions and candidates later rejected on cost. If
the bucket contains `q0,q1,q2,q3`, a suffix starting at q1 pairs `(q1,q2)`.
Filtering global `(q0,q1),(q2,q3)` pairs cannot generally reproduce that trace.

Although suffix parity changes whether a position is first or second, a
position that becomes second always pairs with its globally adjacent hash
predecessor. The pure original match length therefore has a stable key at
that second position. The cache retains each position's exact fifteen-bit hash
in u16 storage and lazily retains its length in u32 storage. Lengths 0...7
from collisions are valid cached results; `u32.max` denotes an unknown entry.

The scanner still performs its original position visits, pending flips,
remaining-length breaks, domination tests, candidate pricing, error handling
and tie updates. Only hash retrieval and the original extension call gain a
cache choice. The cache cannot substitute for finders with several possible
predecessors per second, and it cannot cache whole candidate costs.

## Storage and failure contracts

`paired_anchor_cache.Cache.init` borrows input and caller-owned typed storage;
the core never allocates. Capacity, whole supplied-slice byte-range overflow
and overlap checks complete before hashing or writing. Reinitialization resets
all used entries even when the block's pointer and length match an older input.
The immutable input and storage must remain valid for the view's lifetime;
concurrent workers must own separate mutable length buffers.

For block length N, the used anchor count is `max(0,N-7)`. Hash/length payload
is six bytes per anchor: 393,174 bytes at 64 KiB and at most 786,390 bytes at
128 KiB, excluding view metadata, unused capacity and the original finder
scratch. Typed two-buffer diagnostic allocation needs no between-region pad;
a single-slab layout would need ordinary u32 alignment padding.

The opt-in diagnostic helper allocates the two buffers once before any finder
query, frees them on every return and propagates allocation failure. Its
allocator remains explicit. This helper does not claim optional-resource
fallback or arbitrary shared-budget isolation. Future default preparation
would need separate admission and error-classification work: a failed optional
request may leave a sticky shared budget failure flag. Default encoding does
not make that request in this increment.

## Actual cold candidate-stage result

The profile tool accepts `--anchors` and `--no-anchors`, allowing five
alternating settings in one process. The three frozen 64 KiB inputs use
i7-10700K, ReleaseFast, target `skylake+pku+sgx`, CPU8, Zig 0.16.0. Every
cached timed pass includes two allocations, hash preparation, unknown-length
initialization, all suffix queries and final candidate emission. The source
and executable identities remain fixed and compiler observations are zero.

| Input | Uncached median | Cached median | Stage point speedup |
| --- | ---: | ---: | ---: |
| XML | 625.713 ms | 617.165 ms | 1.01385x |
| MR | 516.964 ms | 507.400 ms | 1.01885x |
| Source code | 233.628 ms | 229.907 ms | 1.01618x |

| Input | Query hashes served | Actual extension calls | Extension cache hits |
| --- | ---: | ---: | ---: |
| XML | 7,704,668 | 49,943 | 3,456,817 |
| MR | 6,948,504 | 38,397 | 2,770,486 |
| Source code | 3,849,234 | 38,293 | 1,542,003 |

Each cache prepares 65,529 hashes. Every old candidate output identity and
existing work field remains unchanged, including cost queries, Huffman plans,
refusals, certificate ages, selected matches and histogram scan work. The
experiment does not reduce those cost queries. The profiler carries work
accounting and evaluates a candidate family directly; these durations are not
a full public encoder ranking or proof of stable statistical improvement.

The high extension hit rate does not translate into a large stage speedup.
At roughly 384 KiB per 64 KiB input, this cache is not enabled by default.
The borrowed core, diagnostic mode and reproducible counter/trace checks are
kept for future experiments with caller-provided workspace and fuller profiles.

## Validation

The original core contracts pass native Debug, native ReleaseFast and actual
x86 ReleaseFast. The final finder Debug filter passes 13/13 including import
tests and stronger core assertions. Independent suffix traces reproduce every
pair, then compare each original extension. Real finder tests compare complete
candidate-pricing event arrays and nullable winners in shadow/prune modes,
including actual hash collisions, injected price errors and 4097/65537-byte
inputs. Every published length is checked against a separately reconstructed
global predecessor map. Long positions and lengths exceed u16, collision
lengths include 0...7, and storage guards/overlap/shortage/reinitialization are
covered. Allocation failures at each of the two diagnostic requests preserve
caller output and release successfully acquired storage.

The final native Debug, native ReleaseFast and x86 ReleaseFast finder filters
each pass 13/13, and the complete native ReleaseFast Zstd family passes
1101/1101. The complete build check passes 172/172. Post-rebase evidence will
be appended after completion. The initial benchmark executable
precedes the final test registration; its core implementation identity and
exact measured-source manifest are retained separately. No performance claim
is transferred from that executable to an unmeasured configuration.

An additional temporary-source experiment disables exported profile accounting
on both paths, so the compiler may eliminate unused Work fields. It is kept
separate from the published diagnostic and includes cold allocation, hash and
length preparation, anchor release and candidate emission, while output
validation/free remain outside the timer. Its pinned source snapshot and
executable are separate from the normal production revision. Five alternating
runs, after all compilers finish, observe zero compiler processes and retain
exact wire equality before and after every timed call:

| Input | Unobserved-Work baseline | Unobserved-Work cache | Stage point speedup |
| --- | ---: | ---: | ---: |
| XML | 605.593 ms | 594.349 ms | 1.01892x |
| MR | 498.785 ms | 487.190 ms | 1.02380x |
| Source code | 225.659 ms | 221.296 ms | 1.01972x |

This control also finds only a small gain for the same 393,174-byte storage.
The conclusion remains to keep the feature as an explicit experiment and leave
default encoding unchanged. No throughput ranking is transferred between
these distinct builds or from a candidate stage to the public frame encoder.

Disassembly of the temporary executable confirms anchor-specific Work updates
are eliminated from its enabled helper. The shared winner-pricing function
still contains Work updates in both branches, so this is not a claim that all
accounting overhead is zero. Those limitations are retained with the pinned
ELF and source identities.

The final default public frame smoke retains all fourteen original Vort and
reference frame lengths/hashes and settings. Its one-round elapsed values are
not promoted to a throughput ranking. Default encoding makes no new anchor
storage request; explicit diagnostic allocation failure remains a separate
contract from existing production memory budgets.
