# Brotli batched literal run

A line-level `perf` profile after the ring-index mask showed that the incremental
literal loop rebuilt a bit reader, re-read the cumulative output limit, performed
two overflow-checked counter adds and recomputed the history ring index for every
literal. The same command can emit thousands of literals, so those checks belong
outside the run.

## Change

The `.literals` phase now keeps one `progressive_bits.Reader` and one ring cursor
for the whole run. Before the loop it computes the accepted run length from the
caller output room and the cumulative output limit:

```
cap = min(output.len - output_written, outputLimit() -| total_output)
```

Each iteration only writes the output byte, stores the history byte, advances
the ring cursor, updates the two-byte literal context and decrements the pending
count. `output_written` and `total_output` are committed once per run, including
the truncation and failure exits. If the caller has output room but the
cumulative limit is exhausted, the run preserves the previous
`OutputLimitExceeded` result instead of reporting `need_output`.

The per-literal `emit` helper remains for stored, metadata and dictionary paths.
The pre-checked cumulative add cannot overflow, which is stated in the code.

## Measurement

A 576-process, four-sweep paired epoch measures the frozen baseline, the
ring-mask build and the batched-literal build on the same 48 Silesia rows
(12 sources, 64 KiB/1 MiB, qualities 6/11). Every process times caller-owned
reset plus direct `step`/`finish`; loading, buffers, warmup, output checks, SHA
and guards stay outside the interval. Input and output chunks are 64 KiB/1 MiB
and 4 KiB. The run is pinned to logical CPU2 of an Intel i7-10700K with Zig
0.16.0 ReleaseFast, GNU target `skylake+pku+sgx` and an 8 MiB stack limit.
Binary hashes are `e3a76a00…` (baseline), `951dc8a1…` (ring mask) and
`c7fc9b4e…` (batched literal run).

Lower is faster. Geometric means over the twelve sources per row group:

| Producer quality / scope | Ring / baseline | Batched / ring | Batched / baseline |
| --- | ---: | ---: | ---: |
| q6 / 64 KiB | 0.5567 | 0.9974 | 0.5553 |
| q6 / 1 MiB | 0.4911 | 0.9898 | 0.4861 |
| q11 / 64 KiB | 0.5325 | 0.9932 | 0.5288 |
| q11 / 1 MiB | 0.4694 | 0.9905 | 0.4650 |

All 48 rows: ring/baseline `0.5113`, batched/ring `0.9927`, combined `0.5076`.
The four sweeps independently reduce the batched increment to
`0.9918/0.9927/0.9947/0.9917`. The best row is Mozilla 1 MiB q6 at `0.899`; the
worst is Mozilla 64 KiB q6 at `1.029`, so the increment is small and not uniform.
It is retained because four independent sweeps agree and literal-heavy frames
benefit most.

Raw records and comparison files stay local under
`/tmp/vort-br-lookup-20261101/` under the lean-evidence policy.

## Validation

The complete ReleaseFast Brotli suite passes 1504/1505 with one 32-bit-specific
skip and zero failures. Focused incremental, prepared-lookup and stream-contract
runs pass in the default build.

## Next work

The remaining per-step cost is now diffuse across the literal loop, command and
distance readers and copy dispatch. Next work should profile the copy path and
the long-code fallback, and keep the one-shot API as a separate epoch.
