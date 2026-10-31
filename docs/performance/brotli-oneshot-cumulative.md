# Brotli one-shot cumulative screen

The incremental decoder epochs measure the caller-owned `step`/`finish` API. The
one-shot `decodeStreamInto` path is separate: it has its own payload loops and
tail-lookup strategy, but it shares the stream ring helper and the literal
context classifier.

This screen checks whether the committed shared increments also moved the public
one-shot API. It compares the frozen header-ownership baseline with the current
source over the same 48 Silesia rows (12 sources, 64 KiB/1 MiB, qualities 6/11).
The harness calls `br.decodeStreamInto` and keeps loading, warmup, output checks,
SHA and guards outside the timed interval. Four alternating sweeps produce 384
processes. The run is pinned to logical CPU2 of an Intel i7-10700K with Zig
0.16.0 ReleaseFast, GNU target `skylake+pku+sgx` and an 8 MiB stack limit.

Lower is faster. Geometric means over the twelve sources per row group:

| Producer quality / scope | Current / baseline |
| --- | ---: |
| q6 / 64 KiB | 1.0018 |
| q6 / 1 MiB | 1.0126 |
| q11 / 64 KiB | 0.9078 |
| q11 / 1 MiB | 0.8736 |

All 48 rows reduce to `0.9471`; the four sweeps independently give
`0.9484/0.9447/0.9492/0.9469`. The median row is `1.0003`, so roughly half the
rows are neutral and the gain is concentrated in high-tree q11 frames. The best
row is Mozilla 1 MiB q11 at `0.482`; the worst is ooffice 64 KiB q6 at `1.041`.
The q6 point estimates are within a few percent and do not establish a q6 win.

This is a cumulative screen against the frozen baseline, not a paired isolation
of one change, and the reference library is not part of this epoch. It does not
establish one-shot leadership; it records that the shared ring and context
changes did not regress the API overall and improved the high-tree path.

Raw records and comparison files stay local under
`/tmp/vort-br-lookup-20261101/` under the lean-evidence policy.
