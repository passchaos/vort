# Shared context-cache experiment assessment

This is a read-only assessment of the completed `analysis.json` and its raw
reports. It does not compile, benchmark, run `analyze.py`, modify sources/tools,
or decide whether to adopt the change. Parent's three alternating ordinary
old/new process pairs are separate follow-up evidence and were still in progress
at this assessment point.

## What the first full public run establishes

The 14 fixed64KiB public q8 rows retain the same input identity, settings,
Vort/reference wire byte counts and final wire SHA-256. The original processes
returned zero, and their records report stable sources and zero observed
compiler processes. These are useful functional and measurement-window checks;
they do not establish zero system noise or statistical significance.

The old/new median-time ratio geometric mean is **0.992884058975**. Since the
ratio is old time divided by new time, its inverse is **1.007166940552**: about
0.717% greater new execution time in this comparison. It is not a 0.993%
regression or a 99.3% regression. Three of14 rows have point speedups; no row
beats the reference in throughput. This single version process per setting,
five internal rounds per input, is insufficient to declare a stable improvement
or stable regression. It currently does **not** support a public speedup claim.

Mozilla is a favorable point here:100.251017→98.492379ms, ratio1.017856×.
The new version's aggregate result is nevertheless below1 because other rows
move the other way. Preserve the per-input rows; do not substitute a chosen
hot sample for the corpus-wide result.

## The counters are accurate work descriptions, not benefit estimates

The new deep profile isolates Mozilla's context_proposals median73.876127ms
and recent-distance scan0.109829ms (profiled outer105.605643ms). Its two actual
plans show:

| Mozilla plan | Requests | Hits | Misses | Cold | Conflicts | Cross-scope | Cross-mode |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| lazy | 1842 | 257 | 1585 | 128 | 1457 | 12 | 0 |
| optimal | 1841 | 254 | 1587 | 128 | 1459 | 7 | 0 |

Source64KiB has cross-mode hit counts2/3 for lazy/optimal, with cross-scope1/0.
The source scopes differ and should not be projected onto Mozilla. On Mozilla,
the shared cross-mode lifetime adds no observed cross-mode reuse; the observed
cross-scope reuse is small relative to requests, while direct-map conflict
misses dominate. Ordinary same-scope hits include reuse already available to
the old per-mode cluster cache. Therefore total hits cannot be described as all
newly avoided work.

`cross_scope_hits` and `cross_mode_hits` are independent predicates of one hit
against its stored origin. A hit may satisfy both, so the counts are **not
disjoint**. Their sum is not the number of distinct novel reuses. Without an
intersection counter or per-request trace, union bounds are only
`max(cross_scope,cross_mode) ≤ union ≤ min(hits,cross_scope+cross_mode)`.
Also, a hit's saved score cost depends on histogram/alphabet complexity; neither
hit count nor a ratio of hit counts measures saved nanoseconds. Extra full-key
hash/equality work and eviction can offset an exact score reuse.

There is no basis to claim allocation savings here: the inspected tree/map
score closure uses fixed stack storage, and the cache's actual ABI grew by384
bytes in the recorded layout reports. No total-stack high-water or RSS was
measured. Key correctness and unchanged allocator requests are useful properties,
but are not equivalent to a net performance benefit.

## Deep-profile timing versus pure optimization

The new profile adds actual recent/context subscopes, profiled proposal search,
per-mode/scope counters, tree/Huffman/prefix timers and shape observations.
The old profile did not observe all that work. Comparing new profile outer to
old coarse outer cannot isolate the cache change from new diagnostic overhead,
factoring/inlining or timestamp reads. The public old/new benchmark is the
appropriate ordinary-code comparison; deep profile is for attribution.

Within the new profile, the sum of reported stage medians is not necessarily
the median outer time. Each median is computed separately. Deep modes,
cluster score, tree score, Huffman and prefix are hierarchical inclusive timings;
do not add them together. Per-round exclusive accounting and unaccounted time
remain the valid conservation check.

Mozilla tree-length medians19.930872/21.921746ms highlight a potential next
investigation, but they are profiled tree-score miss work nested inside suffix
and cluster timings. They are not a measured ordinary-code saving from an
alternative algorithm, and removing candidates or Huffman correctness is not
justified by these numbers.

## What `analyze.py` actually compares

The analysis maps previous rows by input SHA-256 and compares complete final
`wires` and `settings`. Its profile event comparison filters only `wire` and
`selection`, preserving event order and the following fields:

`stage, origin, variant, input_bytes, command_count, wire_bytes, error_name,
accepted, gain_bytes, incumbent_bytes, config`.

For the current raw files this read-only audit additionally verified14 unique
input SHA identities in each set, exact case/input-byte equality,14 matching
public/profile row sets, five rounds per row and all70 candidate comparisons.
It independently recomputed0.992884058975 and confirmed each new final profiled
wire hash/length matches its prior report. Details and source hashes are saved
in `assessment-verification.json`.

This semantic comparison is deliberately insensitive to new hierarchy IDs,
parent IDs, link IDs and timestamps. It establishes same ordered recorded
candidate configurations, lengths and strict decision outcomes, **not** full
execution identity. Intermediate candidate SHA-256 is not recorded; same config
and length are weaker than byte equality. Complete returned wire hash equality
does cover the final published result.

The script itself lacks explicit duplicate-key/row-count checks and uses zip
without an explicit equal-round-count assertion; malformed inputs could be
silently overwritten or trailing rounds ignored. Those issues do not invalidate
the current files because this audit checked the missing preconditions, but
future reports should retain those checks in their independent gate. No tool
source was changed by this assessment.

## Criteria for the parent's decision

Treat the pending three paired ordinary-code runs as new evidence: both version
processes alternate order across pairs, maintain exact frozen wires/settings,
and keep sources/executable/reference/input hashes stable with no observed
compilers. Report each input's three ratios and the corpus aggregate; avoid a
significance claim from only three pairs.

Useful acceptance criteria are: sufficient-resource correctness and explicit
error/budget behavior first; no candidate/tie reordering; preserved public
wire/ratio; a reproducible ordinary-code aggregate benefit or an explicitly
justified per-workload tradeoff; no material regression concealed by averaging;
and the measured memory/stack cost stated separately. Exact caching with small
or zero benefit can still be evaluated for maintainability or diagnostic value,
but it must not be marketed as a speed win.

The current first result supplies accurate cache-work attribution and unchanged
selected semantics, but **does not settle adoption**. Parent owns that decision
after the paired evidence and relevant full validations. This assessment adds
no benchmark or source mutation.
