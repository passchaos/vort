# Brotli literal context tables

After the prepared prefix lookup increment, a `perf` profile of Mozilla 1 MiB
q6 showed `br.literalContextFromMode` at 12.3% of decoder cycles. The function
is called for every literal, and its UTF-8 and signed modes classified the
previous two bytes with character-range branches.

## Change

The incremental path now uses the table-driven `literal_context.valueClustered`
classifier already used by the high-tree one-shot payload loop. UTF-8 mode
becomes two 256-byte table loads, signed mode becomes two signed-bucket table
loads, and the two compact modes stay a mask or a shift. The exhaustive
`value`/`valueClustered` equivalence test covers every mode and every byte pair
(4 x 256 x 256 combinations), so the branch classifier remains the oracle.

`literalContextFromMode` still returns an error union for its existing callers,
but it no longer contains the branchy classifiers. A separate change that
removes the unused error union was not part of this epoch.

## Measurement

The same minimal harness and 48 Silesia rows (12 sources, 64 KiB/1 MiB, qualities
6/11) were used. A paired three-way epoch measures the frozen header-ownership
baseline, the prepared-lookup-only build and the context-table build in two
alternating sweeps. Every process times caller-owned reset plus direct
`step`/`finish`; loading, buffers, warmup, output checks, SHA and guards are
outside the interval. Input and output chunks are 64 KiB/1 MiB and 4 KiB. The
run is pinned to logical CPU2 of an Intel i7-10700K with Zig 0.16.0 ReleaseFast,
GNU target `skylake+pku+sgx` and an 8 MiB stack limit. Binary hashes are
`e3a76a00…` (baseline), `d1c8848b…` (lookup-only) and `7e5b845c…` (context
tables).

Lower is faster. Geometric means over the twelve sources per row group:

| Producer quality / scope | Lookup / baseline | Context / lookup | Context / baseline |
| --- | ---: | ---: | ---: |
| q6 / 64 KiB | 0.6556 | 0.8853 | 0.5805 |
| q6 / 1 MiB | 0.5914 | 0.8680 | 0.5133 |
| q11 / 64 KiB | 0.6317 | 0.8837 | 0.5582 |
| q11 / 1 MiB | 0.5648 | 0.8707 | 0.4918 |

All 48 rows: lookup/baseline `0.6099`, context/lookup `0.8769`, combined
`0.5348`. The two sweeps independently reduce to `0.6085/0.6113`,
`0.8781/0.8756` and `0.5343/0.5352`. The context increment's best row is
Mozilla 1 MiB q6 at `0.624` and its only near-parity row is Webster 1 MiB q6 at
`0.988`. The combined worst row is x-ray 1 MiB q11 at `0.951`; Mozilla 1 MiB q6
is the best at `0.178`.

The reference column is not part of this paired epoch because the reference
lifecycle differs. Raw records and comparison files stay local under
`/tmp/vort-br-lookup-20261101/` under the lean-evidence policy.

## Validation

The complete ReleaseFast Brotli suite passes 1504/1505 with one 32-bit-specific
skip and zero failures. The focused exhaustive clustered-context test passes in
both the default and release builds. The earlier prepared-lookup, reader,
large-window, whole-block and complete-length focused runs remain green.

## Next work

The remaining incremental cost is in the literal loop, copy dispatch and per-step
bookkeeping. Next work should profile those after this change and target the
largest dependency rather than widening lookup tables further.
