# DEFLATE distance-cost-class frontier screen

This screen tested whether Vort could adopt libdeflate's reusable match-store
principle without changing its existing level-8/9 parse or wire. The proposed
frontier grouped candidates by the 30 RFC 1951 distance symbols, retained only
strict record-high match lengths within each symbol, and replayed survivors in
the original global nearest-first order.

The representation is provably exact for the fixed seed and Vort's
`dynamic_optimal.Model`, but both tested construction strategies regressed
ordinary execution and were removed completely.

## Exactness boundary

For a frozen position and cost model, let `P(L)` be the minimum length-edge
cost among lengths `3...L`, including the already-computed suffix DP cost. If
two candidates use the same distance symbol, have distances `d1 < d2`, and
the earlier candidate reaches at least the later candidate's length, then:

- fixed and modeled distance costs are equal because Huffman width and
  extra-bit width are constant inside one RFC symbol;
- `P(L1) <= P(L2)`;
- the later candidate cannot strictly improve the DP;
- strict `<` replacement already gives the earlier exact distance tie
  priority.

Therefore only per-symbol record-high lengths are needed, provided that the
implementation first freezes exactly the original candidate prefix:

- `max_chain` still counts every raw chain node;
- dominated valid candidates still consume `max_candidates`;
- no deeper candidate is admitted after frontier compression;
- the first `length == max_len` still terminates discovery;
- surviving candidates retain their cross-symbol global order and exact
  distance.

This proof does not apply to arbitrary `OptimalCostModel.distance` arrays.
Those may assign different costs to exact distances in the same symbol. A
generic implementation must validate class-constant costs or use the existing
predecessor solve.

## Density and memory screen

The exact hash-chain candidate stream is much denser than libdeflate's
binary-tree length frontier. Representative level-9 16 KiB inputs contain:

| Input | Valid candidates | Candidates / input byte |
| --- | ---: | ---: |
| `nci-16384` | `2,607,596` | `159.2` |
| `mr-16384` | `1,938,613` | `118.3` |
| `mozilla-16384` | `1,619,421` | `98.8` |

The prototype stored one byte of per-position counts plus parallel one-byte
length and two-byte distance arrays. A global cap of one record per byte
covered only 2 of 24 active Silesia prefixes. Raising the cap to two records
per byte—the largest bound still compatible with the current peak-heap gate—
covered only 6 of 24. The remaining cases fell back to the unchanged compact
predecessor solve.

## Ordinary A/B results

The baseline is clean `814fd654`. Separate ReleaseFast executables ran on CPU
2; all 36 output sizes tied.

| Prototype | All 36 | 4 KiB | 16 KiB | 64 KiB control | Worst |
| --- | ---: | ---: | ---: | ---: | ---: |
| separate frontier build before both solves | `1.119378` | `1.177808` | `1.198230` | `0.993837` | `1.320180` |
| frontier collection fused into fixed solve | `1.065798` | `1.115777` | `1.089933` | `0.995514` | `1.175405` |

The separate build repeated too much hash-chain work. Fusing collection into
the fixed pass removed that traversal, but class tracking, bounded record
writes and low coverage still outweighed modeled replay savings. Even inputs
that retained a frontier did not provide broad enough benefit to justify the
extra hot-loop state.

## Decision

No frontier API, storage, branch or DEFLATE integration remains in the source
tree. The next viable implementation needs the matcher itself to emit a short
frontier while it already knows common prefixes—for example, a binary-tree or
multi-hop hash-chain search with class-aware record-length output. Building a
sidecar representation inside the DP loop is now rejected.

A follow-up [compact predecessor screen](deflate-compact-predecessor-screen.md)
also rejected transparent `u16` and packed two-hop chain layouts: fewer bytes
and pointer loads did not offset their added coordinate and iterator work.

Raw A/B data, the fused prototype overlay and the diagnostic profiler are in
[`data/deflate-cost-class-frontier-screen-20261030/`](data/deflate-cost-class-frontier-screen-20261030/).
