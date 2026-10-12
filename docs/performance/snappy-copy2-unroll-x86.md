# x86-64 Snappy COPY_2 loop unroll

The 2026-10-13 change halves loop-control work in Vort's existing exact
eight-byte Snappy match copier. For offset-at-least-eight, length-at-least-16
matches, each iteration now performs two ordered eight-byte load/store pairs.
The ordering is intentional: at the minimum offset of eight, the second load
observes the first store, preserving Snappy overlap semantics. The scalar tail
and all smaller-offset paths are unchanged.

## Correctness

The existing exhaustive oracle compares every offset 1...96 and length 1...64
against bytewise LZ replay. The complete 54-test Snappy suite passes in
ReleaseSafe, and the runtime-libsnappy probe passes 16 bidirectional raw/framed
cases including chunked, incremental, and malformed coverage.

## Performance evidence

ReleaseFast baseline and candidate executables were frozen and pinned to CPU 2
on an Intel Core i7-10700K. Fifteen pairs reverse process order on alternating
runs; every process decodes 20,000 blocks and measures Vort plus Ubuntu
libsnappy 1.1.8 in the same process.

The locked repetitive row is one 32-byte literal followed by 546 COPY_2 tokens.
Candidate/baseline throughput improves **1.0157x median / 1.0153x geometric**,
with a 1.0079x minimum and 15/15 wins. Normalized by simultaneous libsnappy it
improves 1.0140x geometrically with 15/15 wins.

Controls remain neutral in raw Vort time: text is 1.0001x median / 1.0000x
geometric, incompressible is 0.9999x / 0.9998x, and RLE is 0.9997x / 0.9996x.
Structured input moves to 0.9973x median / 0.9971x geometric; its 0.9916x
minimum remains inside the one-percent per-observation retention boundary by a
narrow margin. This host's final repetitive ratio is still only 0.8751x
libsnappy, so this is a measured incremental gain, not an industry-lead claim.

Exact nanosecond observations, executable hashes, commands, control summaries,
code sizes, and rejected variants are retained in
[snappy-copy2-unroll-x86-20261013.json](data/snappy-copy2-unroll-x86-20261013.json).

## Rejected follow-ups

Wider 16-byte loops improved the distance-50 structured row but regressed the
distance-31/32 text and repetitive rows. A four-way eight-byte unroll and a
dynamic `memcpy` tail were also negative. Fixed 64-byte wildcopy made structured
and repetitive faster than libsnappy in single snapshots, but every inline,
noinline, cold-layout, and separately selected form caused more than one percent
regression in text or literal-only controls. None is retained.
