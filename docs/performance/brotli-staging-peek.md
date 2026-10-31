# Brotli staging peek

A line-level `perf` profile after the batched literal run attributed about 26%
of decoder cycles to bit-reader refill work: 12.4% to the staged-reservoir store,
7.8% to the refill loop test and 5.8% to the lookahead gather. The prepared
lookup path called `peekBitsPadded` and then `advanceBitsStagedAssumeAvailable`;
each byte was loaded once by the gather and again by the advance.

## Change

`peekBitsPadded` now stages the bytes it gathers directly into the reader's
reservoir instead of building a private window. The paired advance then only
shifts and decrements the staged count, so its refill loop is normally a no-op.
Truncated lookups still pad with zeros and are rejected by `hasStagedBits`
before consumption. Every incremental caller checkpoints before decoding and
restores on `TruncatedFrame`, so staging during a failed attempt cannot publish
partial state.

The reader test still compares values and full cursor state against committed
`readBits` calls for a random stream and a short tail.

## Measurement

A 576-process, four-sweep paired epoch measures the frozen baseline, the
batched-literal build and the staging-peek build on the same 48 Silesia rows
(12 sources, 64 KiB/1 MiB, qualities 6/11). Every process times caller-owned
reset plus direct `step`/`finish`; loading, buffers, warmup, output checks, SHA
and guards stay outside the interval. Input and output chunks are 64 KiB/1 MiB
and 4 KiB. The run is pinned to logical CPU2 of an Intel i7-10700K with Zig
0.16.0 ReleaseFast, GNU target `skylake+pku+sgx` and an 8 MiB stack limit.
Binary hashes are `e3a76a00…` (baseline), `c7fc9b4e…` (batched literal) and
`c1529df1…` (staging peek).

Lower is faster. Geometric means over the twelve sources per row group:

| Producer quality / scope | Batched / baseline | Peek / batched | Peek / baseline |
| --- | ---: | ---: | ---: |
| q6 / 64 KiB | 0.5580 | 0.9369 | 0.5228 |
| q6 / 1 MiB | 0.4870 | 0.9306 | 0.4532 |
| q11 / 64 KiB | 0.5278 | 0.9427 | 0.4975 |
| q11 / 1 MiB | 0.4659 | 0.9288 | 0.4327 |

All 48 rows: batched/baseline `0.5084`, peek/batched `0.9347`, combined
`0.4752`. The four sweeps independently reduce the peek increment to
`0.9361/0.9340/0.9367/0.9325`. The best row is Mozilla 1 MiB q11 at `0.894`; the
worst is Webster 1 MiB q6 at `0.993`, so every row is faster.

Raw records and comparison files stay local under
`/tmp/vort-br-lookup-20261101/` under the lean-evidence policy.

## Validation

The complete ReleaseFast Brotli suite passes 1504/1505 with one 32-bit-specific
skip and zero failures. Focused prepared-lookup and incremental runs pass in the
default build.

## Next work

The remaining refill cost is the byte-at-a-time staging loop itself. A 16-bit
pair refill or a wider reservoir for the command loop is the next candidate.
The copy path, long-code fallback and non-power-of-two history remain work.
