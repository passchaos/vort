# Brotli recent-distance match evidence audit

Status: source audit and next experiment; no performance win is claimed.
Code revision: `1862c75a`. This follows the completed history-error fix without
changing encoder source or weakening the quality-ceiling tests.

A short call-stack sample of the full Debug suite reached
`br command-state override reaches q10 and q11 input ceilings`
(`src/br.zig:30923`). That case uses a 32-byte periodic 64 KiB q10 input and
a 32 KiB q11 prefix. It executes the narrow and wide command-state planners;
repeated `hq_command_parser.matchLengthAtDistance` comparisons are a visible
cost. The sample identifies work to investigate, rather than measuring a
whole-operation improvement or competitor ranking.

## Existing sharing and missing boundary

In `src/br/encoder/hq_command_parser.zig`, the position loop obtains ordinary
hash candidates near line 297. `cached_match_lengths` near lines 305--349
already shares those candidate lengths between beam states. Optimizing that
same ordinary-candidate work again would duplicate an existing facility.

The recent-distance loop near lines 406--417 still calls
`matchLengthAtDistance` separately for each state. `RecentCandidates.init`
deduplicates within one state; it does not share a distance with another
state or with the ordinary-candidate length cache. The comparison helper near
line 656 depends on input, position, distance, minimum and maximum, rather
than entropy prices or beam state. Its extension loop starts from the first
byte each time.

`selectQualityCommandStateCandidate` in `src/br.zig` first runs the narrow
solver, then may call `selectWideCommandStateCandidate`; text inputs at least
32 KiB select beam 8. Both calls currently build and solve independently. The
first experiment should reduce repeated recent probes within each solver,
before attempting sharing between solver invocations.

## Proposed bounded experiment

Store only requested distance evidence in a bounded lazy cache. A beam-8
position has at most 128 recent requests; a complete per-input frontier is
unnecessary. A miss or eviction performs the original comparison.

At the same position, compatible minimum/maximum requests can reuse a known
length. For later positions at the same distance, a verified equal-byte span
can avoid comparing those bytes again. If an old `(p, d)` comparison ended at
a real mismatch after `L` bytes, `(p + 1, d)` has exact length `L - 1` when
`L > 0`, subject to the new limit. If it reached a requested maximum, only
that prefix is known; extend from the unverified tail. Handle physical EOF,
zero-length results and changed limits separately. A failure shorter than the
requested minimum is not an exact zero-length proof for another position or
another minimum.

Keep the cache scoped to one immutable input operation. Preserve every
ordinary/recent transition, its order, distance-code choice, cost computation,
strict tie rule and logical search-budget charge. Cache byte evidence only;
do not cache or replace the state's recent-distance ring or model prices.
Positive ordinary-candidate evidence can be reused only when its bounds and
minimum semantics support the recent request.

The rejected [whole-frontier experiment](brotli-match-evidence.md) measured
combined time 1.046294x and eliminated only 0.23%--11.77% of second-pass
length requests, with dense-input fallbacks. The
[prepared-optimal screen](brotli-prepared-optimal-screen.md) explains why
sharing predecessors alone leaves length comparisons. This proposal caches
actual recent requests and does not precompute or copy that whole frontier.

## Required evidence before adoption

Compare exact commands against the scalar path for beams 2/4/8, model and
starting-distance variants, short failed prefixes, capped matches, EOF and
cache eviction. Record physical comparisons, compared bytes and hits separately
from logical evaluation-budget counters. Prove unchanged allocation/failure
contracts and candidate/wire identity, including maximum-input cases.

Then measure ordinary full q10/q11 APIs on a quiet performance host with raw
interleaved samples, matched settings, non-regression controls and declared
memory scope. Use the existing 8 KiB command-state benchmark control before
separately measuring the explicit 64/32 KiB override cliff. A source-level
reduction in comparisons is insufficient for adoption without the codec's
whole-operation throughput, wire and resource gates.
