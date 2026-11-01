# Brotli incremental 720-process epoch

This epoch measures the committed prepared-lookup, literal-context, ring-mask,
batched-literal and staging-peek increments together on the full reference
corpus. It covers all 72 externally produced Brotli frames: twelve Silesia
sources at 64 KiB, 1 MiB and their actual full lengths, qualities 6 and 11.

## Protocol

Each frame runs with 1-, 7- and 4096-byte input chunks at 64 KiB, and 4096-byte
input chunks at 1 MiB and full length; output chunks are 4096 bytes. Two
alternating sweeps give 720 processes. Every process times caller-owned
`resetForTiming` plus direct `step`/`finish`; loading, buffers, warmup, complete
output checks, SHA and guards stay outside the interval. The run is pinned to
logical CPU2 of an Intel i7-10700K with Zig 0.16.0 ReleaseFast, GNU target
`skylake+pku+sgx` and an 8 MiB stack limit. The reference is libbrotli 1.2.0
with a different create/decompress/destroy lifecycle; its ratios are not an
apples-to-apples streaming comparison.

Binaries: baseline `e3a76a00…` (frozen header-ownership source), candidate
`c1529df1…` (committed source), reference `6f90ab22…`.

## Results

Lower is faster. Geometric means over the twelve sources per group:

| Quality / scope / input chunk | Final / baseline | Final / reference |
| --- | ---: | ---: |
| q6 / 64 KiB / 1 | 0.9503 | 8.1595 |
| q6 / 64 KiB / 7 | 0.7341 | 5.2613 |
| q6 / 64 KiB / 4096 | 0.5139 | 3.8458 |
| q6 / 1 MiB / 4096 | 0.4527 | 3.8351 |
| q6 / full / 4096 | 0.6726 | 6.2558 |
| q11 / 64 KiB / 1 | 1.0349 | 14.6749 |
| q11 / 64 KiB / 7 | 0.8257 | 6.8248 |
| q11 / 64 KiB / 4096 | 0.4892 | 2.9513 |
| q11 / 1 MiB / 4096 | 0.4320 | 3.1420 |
| q11 / full / 4096 | 0.6183 | 4.9283 |

The two sweeps agree within about one percent for every group. The 4096-byte
chunk groups are 49–57% faster and the 7-byte groups 17–27% faster. The
1-byte q6 group is 5% faster, but the 1-byte q11 group is 3.5% slower: without
the rejected resumable header parser, tiny fragments still re-parse the
compressed header, and the lookup/context changes do not help that path.

Full-file results are not uniform. For q6 the strongest sources are SAO
`0.306`, Mozilla `0.459`, OSDB `0.477`, ooffice `0.500` and x-ray `0.541`;
reymont and dickens are near neutral (`0.924`/`0.945`), while webster
`1.069`, samba `1.147` and xml `1.166` regress. For q11 the strongest are SAO
`0.255`, OSDB `0.364` and NCI `0.544`; x-ray `0.963`, Mozilla `1.002` and
ooffice `1.031` are neutral or slightly slower. The group geometric mean is a
win, but individual full files can be slower and the cause is not established.

Raw records, comparison and process intervals stay local under
`/tmp/vort-br-lookup-20261101/` under the lean-evidence policy.

## Validation

The complete ReleaseFast Brotli suite passes 1504/1505 with one 32-bit-specific
skip and zero failures on the committed source. Project-wide
`zig build -j2 check` passes.

## Packed-tree expansion fix

The full-file q6 regression was traced to `PackedPrefixCode.expand`. The
`PrefixCode` struct literal initialized the 512-byte prepared lookup to zero and
returned it by value on every packed-tree expansion. A `perf` profile of
xml.full q6 attributed 35.8% to expansion and 10.4% to `memset` in the candidate.
`expand` now writes only the single-symbol, prepared flag and table fields and
leaves the lookup undefined; the owner clears `prepared` and builds the lookup
on first use, so the unused slots are never zeroed or copied.

xml.full q6 changes from baseline 44.76 ms and pre-fix 52.47 ms (ratio `1.172`)
to post-fix 45.20 ms (`1.010`). A four-sweep 48-row paired epoch gives
post-fix/pre-fix `0.9946/0.9853/0.9932/0.9908` for q6/q11 at 64 KiB/1 MiB and
post-fix/baseline `0.5173/0.4455/0.4935/0.4292`. The full ReleaseFast suite
passes 1504/1505 with one platform skip.

## Next work

The webster and samba full-file q6 cases still need a dedicated check, as does
the 1-byte q11 regression. Candidates include non-power-of-two history indexing,
per-meta-block lookup rebuild cost and code layout. The copy path, long-code
fallback and one-shot reference epochs remain separate work.
