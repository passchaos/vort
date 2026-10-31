# Stream ring index mask

After the prepared lookup and literal-context increments, a `perf` profile of
Mozilla 1 MiB q6 attributed 6.3% of decoder cycles to a single `div` in the
per-literal history write. The incremental decoder stores every literal at
`total_output % history.len`, and the history capacity is usually a power of
two for bounded 64 KiB/1 MiB frames.

## Change

`stream_count.ringIndex` now uses `position & (capacity - 1)` when the capacity
is a power of two and keeps the existing modulo otherwise. The change is
equivalent for every position and capacity; the stream-count test now covers
capacities 1, 2, 64, 1024 and 2^20, including a position above the 32-bit
boundary.

The optimization is not Brotli-specific: Deflate, Zstd, Snappy and other
incremental decoders call the same ring helper. Full-file inputs whose caller
chooses a non-power-of-two history keep the division path.

## Measurement

A 576-process, four-sweep paired epoch measures the frozen header-ownership
baseline, the prepared-lookup plus context-table build, and the ring-mask build
on the same 48 Silesia rows (12 sources, 64 KiB/1 MiB, qualities 6/11). Every
process times caller-owned reset plus direct `step`/`finish`; loading, buffers,
warmup, output checks, SHA and guards are outside the interval. Input and output
chunks are 64 KiB/1 MiB and 4 KiB. The run is pinned to logical CPU2 of an
Intel i7-10700K with Zig 0.16.0 ReleaseFast, GNU target `skylake+pku+sgx` and an
8 MiB stack limit. Binary hashes are `e3a76a00…` (baseline), `7e5b845c…`
(lookup+context) and `951dc8a1…` (ring mask).

Lower is faster. Geometric means over the twelve sources per row group:

| Producer quality / scope | Lookup+context / baseline | Ring / lookup+context | Ring / baseline |
| --- | ---: | ---: | ---: |
| q6 / 64 KiB | 0.5830 | 0.9605 | 0.5600 |
| q6 / 1 MiB | 0.5143 | 0.9535 | 0.4904 |
| q11 / 64 KiB | 0.5597 | 0.9481 | 0.5307 |
| q11 / 1 MiB | 0.4925 | 0.9548 | 0.4703 |

All 48 rows: lookup+context/baseline `0.5362`, ring/lookup+context `0.9542`,
combined `0.5117`. The four sweeps independently reduce the ring increment to
`0.9482/0.9542/0.9554/0.9533`. The ring increment's best row is OSDB 1 MiB q11
at `0.918` and its worst is NCI 64 KiB q6 at `0.983`; every row is faster. The
combined best is Mozilla 1 MiB q6 at `0.172` and the worst is x-ray 1 MiB q11 at
`0.954`.

Raw records and comparison files stay local under
`/tmp/vort-br-lookup-20261101/` under the lean-evidence policy.

## Validation

The complete ReleaseFast Brotli suite passes 1504/1505 with one 32-bit-specific
skip and zero failures. The focused stream-count ring test passes in the default
build. The earlier prepared-lookup, literal-context, reader, large-window,
whole-block and complete-length focused runs remain green.

## Next work

Non-power-of-two history still pays a division per ring access. A per-frame
reciprocal or an explicitly maintained ring cursor is the next candidate for
full-file workloads. The literal loop, copy dispatch and per-step bookkeeping
remain the main decoder targets.
