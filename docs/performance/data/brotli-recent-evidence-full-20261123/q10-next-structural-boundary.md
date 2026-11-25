# Primary q10 profile and next sharing boundary

Both recent-length evidence variants fail the complete-operation adoption gate.
The next investment is routed by an optimized full q10 call profile, rather
than by the earlier long Debug quality-ceiling stack sample.

The baseline ReleaseFast benchmark encoded the Dickens 8 KiB prefix at q10,
generic mode, window 16, command-state 8 KiB, CPU 2, twenty iterations and five
rounds. Its process also performs libbrotli and auxiliary balanced/ratio work.
The primary filter requires **both** `planned_encode_bench.measureVort` and
`br.encodePlannedStreamQualityWithOptionsAllocRecorded` in each call chain.
This includes the per-round untimed warmup, so it is routing evidence, not an
independent ordinary-call throughput measurement.

`profile_primary.py` reproduces attribution from `perf script` with explicit
`comm,pid,time,event,period,ip,sym,dso` fields. The full capture has 13,895
samples / 16,977,573,649 sampled period cycles; the filter keeps 10,552 samples /
12,919,026,601 periods. `q10-primary-profile.json` normalizes anonymous
instantiation suffixes and records weighted leaf/inclusive shares. The exact
8,192-byte input SHA-256 is
`602ff7349c8ca821c5d560915480aff05096986b89396b059b09ebce046dc48c`.

| Primary self source | Share |
| --- | ---: |
| `literal_context_split.chooseModeFromHistograms` | 17.68% |
| all normalized `small_huffman.buildInternal` instances | 9.38% |
| `compiler_rt.memset` | 9.36% |
| `context_map.build` | 8.51% |
| `encodeCommandPlanWithStandardWrite` | 7.92% |
| `literal_alphabet.buildLargeSupport` | 6.77% |
| `static_dictionary_matcher.Index.findCandidates` | 4.76% |
| `complex_prefix.codeLengthCodeLengths` | 4.55% |
| `literal_context_split.treeBitCostProfiled` | 3.94% |
| `distance.encodeWithFormat` | 2.87% |

`chooseProposals` is 62.04% inclusive; it includes children above and cannot be
added to their self shares. The legacy preferred-context chain is 71.77% of
the filtered periods, the prepared context chain 10.92%. These fractions are
not projected savings.

In `src/br.zig:11843`, the shared prepared/counting context path requires
`use_recent_distances`. `prepared_command_distance.supported` also requires it.
The ordinary nonrecent route fully encodes its primary near line 11855, then
fully encodes distinct suffix/bounded-16/full literal contexts near line 11890.
Commands and common command/distance settings remain immutable during that
candidate group. Sharing their preparation and counting candidate wire sizes
before one winning emission is the next architectural boundary.

This is not a duplicate `chooseProposals` call within the same group: prepared
and legacy each already make one proposal search. Proposal search itself is a
separate remaining cost.

Nonrecent support requires more than eligibility changes. The context group
currently assumes a true recent flag and has different plain-arbitration early
return rules. The prepared literal emitter also assumes recent mapping, while
nonrecent same-last recoding changes cached symbols and payload extra bits.
A correct extension must share the accepted same-last plan, publish all common
state transactionally, honor actual recent mode and preserve candidate order,
strict ties, proposal-zero cutoff, output and resource/fallback contracts.
An isolated follow-up is investigating that support; no implementation or
performance benefit is yet accepted on main.
