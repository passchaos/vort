# x86-64 Brotli reader noalias follow-ups

Date: 2026-10-06. Baseline: `c7b9c4ba`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread.

## Routing audit

After retaining reader `noalias` contracts for the paired full tier and the
65--128-tree middle tier, the remaining decoder tiers were audited before
mechanically applying the same annotation.

The old `.vort_br_wide_lookup10_aux` payload is no longer reachable from the
production dispatcher. Meta-blocks above 128 literal trees with auxiliary
lookups enter the paired executor directly; when auxiliary preparation fails,
the wide10 setup's own entry condition is also false. The function remains as
an explicit transition/boundary oracle, so no production performance claim or
change was made for it.

Two reachable tiers were then measured independently: the flat tail-lookup
payload used by `clustered_q8`, and the large single-tree payload used by
quality-one source/documentation streams. Both wrappers own their fast reader
in storage distinct from output, header/distance state, and lookup arrays, so
the proposed contracts were semantically valid.

## Rejected results

| Candidate | Generated shape | Target result | Decision |
| --- | --- | --- | --- |
| flat tail-lookup reader `noalias` | multi-tree instance `0x1266` -> `0x1252` (-20 B) | clustered q8 `0.9987x` median / `0.9946x` geometric, 5/15 wins | reject |
| single-tree reader `noalias` | instance `0x0ed5` -> `0x0ee4` (+15 B) | source q1 `0.9940x` geometric, roadmap q1 `0.9874x`, both 0/7 wins | reject |

The flat candidate kept paired, wide10, and wide9 custom sections at identical
addresses and sizes, yet still lost complete clustered decode. One `0.9684x`
outlier lowers its geometric mean, but the `0.9987x` median and only 5/15 wins
remain below the retention threshold without that sample.

The single-tree result is decisive across both independent inputs: source q1
ranges from `0.9900x` to `0.9964x`, while roadmap q1 ranges from `0.9808x` to
`0.9933x`. All fourteen candidate runs lose. Eighteen source attempts that
overlapped external Zig builds were discarded; no contaminated attempt is
included.

Both changes compiled and every benchmark run verified decoded size and
checksum. They were removed before broader compatibility gates because the
target performance requirement failed. Production source therefore remains
the retained full/middle implementation from `c7b9c4ba`.

Exact executable hashes, raw timing observations, and discarded-attempt counts
are in
[brotli-reader-noalias-followups-x86-20261006.json](data/brotli-reader-noalias-followups-x86-20261006.json).

## Next direction

Reader alias metadata is now exhausted as a general Brotli strategy: it helps
paired and middle layouts but hurts flat and single layouts. Further work on
`clustered_q8` and q1 should target their distinct command/distance execution
and table working sets, not another ownership annotation. The unreachable
wide10 executor should be considered for test-only isolation or removal in a
separate binary-size cleanup, not presented as a decode optimization.
