# DEFLATE dynamic-Huffman optimal refinement

Numeric levels 8 and 9, including the named `best` preset, now perform one
bounded entropy-feedback parse for eligible one-shot inputs. The ordinary
fixed-cost optimal parse remains the seed. Its provisional dynamic Huffman
tree supplies literal, length and distance costs for one modeled proposal;
symbols absent from the seed tree use their legal fixed-Huffman width as a
nonzero prior, and RFC length/distance extra bits remain part of every match
edge.

The model is proposal-only. Raw, zlib and gzip each serialize the seed and
modeled token streams through their normal stored/fixed/dynamic selector and
wrapper writer. The modeled stream replaces the seed only when its complete
member is strictly shorter; equal lengths preserve the established seed
bytes. The modeled parse must also cost no more than the seed under the model,
and token-identical proposals skip the second serialization.

The first production boundary is deliberately narrow:

- default strategy, optimal parser and `stored_fixed_dynamic` selection;
- no preset dictionary and one-shot single-block encoding only;
- input length 4,096 through 65,535 bytes;
- one refinement round and at most the seed parser's existing search budget;
- an LZ77 window no larger than 32 KiB.

Generic token planning is unchanged. Fixed/adaptive split planning,
incremental encoding, dictionaries, levels 0 through 7, non-default strategies
and `stored_fixed` therefore retain their old behavior. Tests cover the exact
input boundaries, level policy, all RFC length/distance ranges, active and
unseen model symbols, modeled-cost ordering, token-plan identity outside the
one-shot wrapper, complete raw/zlib/gzip arbitration, strict ties,
determinism, stored and dynamic winners, excluded dictionary/split/strategy
paths and every allocation failure.

## Ordinary A/B evidence

The baseline is clean `89d7d3f2`; the candidate adds only this refinement.
Separate ReleaseFast executables ran on logical CPU 2 of an Intel Core
i7-10700K. The corpus is all twelve Silesia files at 4, 16 and 64 KiB prefixes.
Every case has three order-alternating process sweeps; each process performs an
untimed warmup followed by three ordinary timed encodes. The reported case
time is the median process sample, and the aggregate is the geometric mean of
the 36 case ratios. The 64 KiB files are exactly 65,536 bytes and intentionally
exercise the disabled side of the production cap.

| Mode | Candidate / baseline time | Worst case | Bytes | Wins / ties / regressions |
| --- | ---: | ---: | ---: | ---: |
| named `best`, raw | `1.406158` | `1.851268` | `382,528 -> 381,768` | `24 / 12 / 0` |
| numeric level 8, raw | `1.404922` | `1.833044` | `382,528 -> 381,768` | `24 / 12 / 0` |

For named `best`, the active 4 KiB and 16 KiB buckets record time ratios of
`1.737379` and `1.617390`; their combined size is
`97,370 -> 96,610`, a 0.781% reduction. Every active case is strictly smaller.
The excluded 65,536-byte bucket remains byte-identical and records a
noise-level `0.989448` time ratio, with a worst case of `1.004890`.

This is a ratio-oriented high-level tradeoff, not an encode-throughput win.
On the most allocation-heavy observed 16 KiB case, `/usr/bin/time -v` reports
maximum RSS moving from 3,560 to 3,900 KiB. The cap, one-round policy and
strict complete-wire arbitration bound the added work and prevent size
regression, but the extra optimal parse is intentionally expensive.

The candidate emitted both levels and all three wrappers for all 36 inputs.
Python's system zlib 1.2.11 independently decoded all 216 streams to the exact
input SHA-256. Aggregate candidate/reference sizes are:

| Level | Wrapper | Vort bytes | zlib bytes | Vort / zlib |
| ---: | --- | ---: | ---: | ---: |
| 8 | raw | `381,768` | `389,550` | `0.980023` |
| 8 | zlib | `381,984` | `389,766` | `0.980034` |
| 8 | gzip | `382,416` | `390,198` | `0.980056` |
| 9 | raw | `381,768` | `389,396` | `0.980411` |
| 9 | zlib | `381,984` | `389,612` | `0.980422` |
| 9 | gzip | `382,416` | `390,044` | `0.980443` |

This corpus establishes a reproducible ratio improvement and compatibility,
not broad DEFLATE leadership: the active encode path is roughly 1.6x-1.7x
slower, the corpus is prefix-based, and streaming/dictionary/multi-block cost
feedback remains future work. Raw samples, wrapper hashes, system-zlib results,
RSS logs, executable identities, inputs, wires, source overlay and exact replay
commands are retained in
[`data/deflate-dynamic-optimal-refinement-20261029/`](data/deflate-dynamic-optimal-refinement-20261029/).
