# Zstd local optimal parsing and repeated-segment search

Bounded sampled btopt/btultra/btultra2 now default to a deterministic local
optimal parser with one best path per position. It replaces the previous 8/16
state search for that policy. The original beam engine remains available as
`HqOptions.parser_engine = .beam`. Whole-block and complete-length requests
continue to use beam, preserving their position/length coverage. The profile
reports the actual engine, and the CLI exposes `--hq-parser-engine`.

This is an algorithm change inspired by the local zstd optimal-parser design,
not a requirement to preserve the previous bounded sampled output bytes. Both
engines produce interoperable Zstd frames, and finite/unlimited price quotas
run the same selected algorithm. The broader industry-best objective remains
unmet.

## Search design

The reference is zstd commit `01b7154f1172432f8abe9b3bb9909e14a1176b7d`,
especially `lib/compress/zstd_opt.c`. Its single-path scores include pending
literal-length cost. Vort's new score has the same useful invariant: extending
a literal removes the old LL term before adding its byte cost and the new LL
term. A match closes the literal run and establishes LL0 for the next run.
Negative LL increments therefore do not underflow unsigned arithmetic.
Final records, offsets, repeats, statistics and estimated cost are independently
recomputed by the existing plan finalizer.

No-match positions advance outside local DP. The first match starts a local
search with a dynamic reachable endpoint, capped by the existing 4096-position
table. Newly reached rows are initialized lazily; unused old storage cannot
participate. Ordinary increasing-length candidates only expand new length
intervals. Repeat candidates retain independent short-length competition.
A sufficiently long match or an endpoint reaching the local capacity ends
the search; an external tail descriptor permits a full copy beyond that
capacity without materializing its interior rows.

Cold btultra2 still learns first-pass statistics and runs a second parse under
refined costs, retaining the lower-cost plan. It rebuilds the matcher per pass
instead of treating unvisited positions in an old dense frontier cache as
empty. The current matcher still fully indexes skipped positions and allocates
fixed hash heads. A compact stretch representation, the reference's LL1 rescue,
sparse indexing and data-dependent table sizing remain future work.

## Repeated-segment algorithm

After shrinking DP work, a separate periodic-input profile identified
`findRepeatedPatternSegmentIn` as 86.39% of the sampled benchmark workflow.
The profile includes startup, hashing and reference work; that percentage is
not a timing attribution for every encoder input.

The old detector repeatedly compared overlapping start/period candidates
against their original modulo anchor. The new small module preserves exactly
the same Segment and strict first-winner ties. For a fixed period, consecutive
shifted equalities prove the same periodic prefix by induction. A cached first
mismatch lets later starts reuse the already verified run. Bounds on the
maximum possible match length stop candidates that cannot strictly improve
the current winner. Three-byte filtering, SIMD and little-endian word
comparisons remain bounded by the caller's input/end range.

The 65-entry cache uses 520 stack bytes on native64 or 260 on 32-bit targets,
with no heap allocation. The original modulo reference and independent
comparison tests remain available.

## Ordinary evidence

All campaigns use Zig 0.16.0 LLVM ReleaseFast, Intel i7-10700K, one codec thread
on CPU2 and local libzstd1.6.0. Both libraries explicitly request the same HQ
strategy, depth64, nice64, minimum3, checksum/content-size flags and natural
block ceiling. Reference hash/chain settings remain level3 defaults; actual
algorithms and table sizing differ. Input setup, hashes, profiles and decoder
checks are outside the timed allocating encode/free calls. Compilers and
separate codec-validation campaigns do not overlap ordinary timers.

There are three distinct campaigns: a three-sweep four-way engine ablation,
a three-sweep repeated-detector comparison, and a two-sweep wide comparison.
The total is 230 serial processes and 83 case rows. Each process alternates
two Vort/reference encode rounds. All inputs, settings, source/binary identities,
raw rounds, wires and requested-heap diagnostics are retained separately.

| btultra2 scope | New / old time | New / old size | New / libzstd time | New / libzstd size |
| --- | ---: | ---: | ---: | ---: |
| Three real 4 KiB files | `0.093152` | `1.012838` | `4.424183` | `0.998144` |
| Three real 16 KiB files | `0.072651` | `1.008052` | `3.718068` | `1.003804` |
| All twelve Silesia 64 KiB prefixes | `0.062327` | `1.017088` | `3.145551` | `1.004801` |
| All twelve Silesia 128 KiB prefixes | `0.064724` | `1.017637` | `3.219051` | `1.005144` |
| Three real 1 MiB multi-block inputs | `0.078287` | `1.001710` | `4.624444` | `0.992800` |

These are geometric means of per-case median ratios. The 64/128 KiB speedups
are about 16.0x/15.5x. Larger sizes are a recorded tradeoff: NCI128KiB grows
9.79% relative to the old beam output, while remaining about0.96% smaller than
the reference on that case. Beam retains that alternative search choice.
No statistical-significance, all-input/platform or industry-lead claim is made.

btopt's twelve-file64/128KiB time ratios are0.133727/0.140294 versus old,
with new/reference size1.011950/1.012661. Periodic4KiB btultra2/btopt time
ratios are0.002455/0.010973, about407x/91x faster than old at identical sizes;
they still take 74.86x/50.01x reference time. The old and new graph evaluate
23,968,313/2 actual ultra sequence prices there. Pure repetition bypasses
these graphs and retains a small1.003042 ultra time regression. Random and
trained-dictionary rows, including slower point observations, remain archived.

Native parser requested peaks move from 4,616,748 to 962,256 bytes at 4 KiB and
5,681,708 to1,584,848 at 16 KiB, reductions of79.2%/72.1%. These are requested
bytes, not process RSS. The typed source, dictionary/history, returned plan
and whole-encoder budgets remain explicit.

## Compatibility and contracts

Native Debug/ReleaseFast full Zstd tests each pass 1235/1235. Old beam cost,
alias allowance, cache, horizon and row-tag oracles retain their strict
assertions through an explicit beam request. Legacy non-HQ/default frozen
wires remain unchanged. New engine tests verify actual metadata and capN/N−1
behavior; public resource, retry, byte accounting and ownership tests remain
applicable to the new default.

Actual x86 Debug/WASI ReleaseFast frontier tests pass 7 named tests each;
repeated-pattern tests pass 4 named tests per target. The detector's four
platform executions each compare 554,455 cases against the independent modulo
oracle. Actual public WASI one-shot and incremental operations verify default
local engine selection, exact quota/heap, zero/one-below refusal, caller output
and emitted-state preservation, empty-input same-state retry and cleanup.

The CLI gate completes 214 round trips,76 legacy wire checks,45 profile/wire
checks and138 rejected-output checks. The versioned reference campaign covers
77 groups and preserves eight original frozen rows. Its allocator probe checks
actual operation-owned memory separately from a reusable encoder's detached
end-of-call profile snapshot; snapshots can describe retained capacity without
being a live post-deinit observer.

The native/Wasm build check completes212/212 steps; CLI help and diff checks
complete with exit zero. A separate current-source check covers16 small and51
wide cases, retaining the selected prototype's exact wires. Current all-twelve
64/128KiB btultra2 time ratios versus libzstd are3.154517/3.216303; the three
1MiB inputs record4.632625. The corresponding size ratios remain
1.004801/1.005144/0.992800. The final source check is a distinct epoch, not a
multiplier applied to earlier speedups.

Raw measurements, source overlays, module oracles, original legacy wire rows,
actual executed Wasm and final gate records are frozen under
[`data/zstd-local-optimal-20261031/`](data/zstd-local-optimal-20261031/).
Run its read-only `audit-frozen.py --no-live` to recompute the retained ratios.
Frozen and live-identity reducers both pass: all five campaigns comprise 290
serial processes and 150 case rows, including the independent final-source
small/wide checks. The final-source frames match the selected prototype exactly.
 Unrelated pre-existing Bzip2 changes
prevent a safe focused commit in this shared worktree; no commit or push is
included in this increment.
