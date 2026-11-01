# Current three-codec decode gap

This epoch re-measures the public one-shot decoders against the pinned
references after the committed Brotli and shared decoder increments. It replaces
the stale gap estimates in the decoder-priority audit for the one-shot API.

## Protocol

All 216 reference frames are used: twelve Silesia sources at 64 KiB, 1 MiB and
actual full lengths for raw Deflate levels 6/9, Zstd levels 3/19 and Brotli
qualities 6/11. Each process times one public one-shot decode call
(`decodeRawAuto`, `decodeFrameInto` or `decodeStreamInto`); loading, warmup,
output checks, SHA and guards stay outside the interval. Two alternating sweeps
give 1,296 processes. The run is pinned to logical CPU2 of an Intel i7-10700K
with Zig 0.16.0 ReleaseFast, GNU target `skylake+pku+sgx` and an 8 MiB stack
limit. Reference libraries are libdeflate (pinned build), libzstd 1.6.0 and
libbrotli 1.2.0 with different lifecycle costs.

## Results

Lower is faster. `current/baseline` compares the committed source with the
frozen decoder-priority baseline; `current/reference` compares it with the
pinned library.

| Codec / level / scope | Current / baseline | Current / reference |
| --- | ---: | ---: |
| Deflate 6 / 64 KiB | 0.9213 | 1.8222 |
| Deflate 6 / 1 MiB | 0.9378 | 1.6828 |
| Deflate 6 / full | 0.9394 | 1.7257 |
| Deflate 9 / 64 KiB | 0.9043 | 1.8032 |
| Deflate 9 / 1 MiB | 0.9361 | 1.6693 |
| Deflate 9 / full | 0.9364 | 1.7283 |
| Zstd 3 / 64 KiB | 0.9156 | 1.5840 |
| Zstd 3 / 1 MiB | 0.8864 | 1.5738 |
| Zstd 3 / full | 0.8686 | 1.5270 |
| Zstd 19 / 64 KiB | 0.8501 | 1.6045 |
| Zstd 19 / 1 MiB | 0.8738 | 1.5786 |
| Zstd 19 / full | 0.8713 | 1.5578 |
| Brotli 6 / 64 KiB | 0.9679 | 1.8833 |
| Brotli 6 / 1 MiB | 0.9986 | 1.1621 |
| Brotli 6 / full | 0.9862 | 1.4434 |
| Brotli 11 / 64 KiB | 0.9096 | 1.7536 |
| Brotli 11 / 1 MiB | 0.8739 | 1.1432 |
| Brotli 11 / full | 0.9161 | 1.3885 |

The current source is 6–15% faster than the frozen baseline for every group
except Brotli q6 at 1 MiB, which is neutral. The remaining reference gaps are
largest for raw Deflate (1.67–1.82x), then Zstd (1.53–1.60x), then Brotli
(1.14–1.88x); Brotli 1 MiB is the closest at 1.14–1.16x. Small 64 KiB frames
have the largest Brotli gap because fixed per-call setup dominates.

These ratios use different reference lifecycles and describe warmed one-shot
calls only. They do not establish cold-start, streaming, dictionary or peak-memory
leadership.

A follow-up [one-shot fallback lookup](brotli-oneshot-fallback-lut.md) moved the
standard and large-window literal fallbacks to the prepared lookup, a
[further command/distance increment](brotli-oneshot-command-distance-lut.md)
extended it to the command and distance readers, and the
[standard packed literal cache](brotli-standard-packed-cache.md) removed repeated
packed-tree expansion from the one-shot standard path. The epoch before the
Deflate overcopy gives Brotli current/reference
`1.5093/1.1563/1.1727` for q6 and `1.3869/1.1271/1.2267` for q11 at
64 KiB/1 MiB/full. Raw Deflate remains the largest gap at about 1.69–1.77x,
followed by Zstd at about 1.52–1.61x. Brotli has the smallest gap at 1 MiB and
full.

## Epoch after the Deflate overcopy

A further 1,296-process epoch with the sixteen-byte Deflate overcopy gives
current/reference:

| Codec / level | 64 KiB | 1 MiB | full |
| --- | ---: | ---: | ---: |
| Deflate 6 | 1.7863 | 1.6890 | 1.7115 |
| Deflate 9 | 1.8288 | 1.6807 | 1.7030 |
| Zstd 3 | 1.6016 | 1.5921 | 1.5200 |
| Zstd 19 | 1.6089 | 1.5731 | 1.5632 |
| Brotli 6 | 1.4935 | 1.1073 | 1.2234 |
| Brotli 11 | 1.4017 | 1.1353 | 1.2296 |

Epoch-to-epoch variation is 1–3%, larger than the about 1% paired Deflate gain,
so this table describes the current gap rather than proving the increment. The
paired screens in [the overcopy evidence](deflate-sixteen-byte-overcopy.md)
remain the adoption authority. The largest gap is still raw Deflate at about
1.68–1.83x, then Zstd at about 1.52–1.61x, then Brotli at about 1.11–1.49x.


Raw records, comparison and process intervals stay local under
`/tmp/vort-br-lookup-20261101/` under the lean-evidence policy.

## Next work

The largest remaining gap is the raw Deflate semantic dynamic block loop, then
the Zstd sequence decode. Brotli's 1 MiB gap is already small; its 64 KiB gap
needs per-call setup work. Each target requires its own current-source epoch and
must keep the compatibility and malformed-input contracts.
