# x86-64 LZ4HC linked and dictionary frame baseline

Date: 2026-10-12. Baseline: `72e31560`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0 ReleaseFast, CPU 2, one codec thread. Reference:
liblz4 1.9.3 dynamically loaded through its frame/CDict APIs.

## Method

`run-lz4-hc-reference-bench` measures allocation-inclusive one-shot frame
encoding through the public Vort and liblz4 APIs. Every row first requires the
complete frame bytes to match, so compressed size, block decisions, checksums,
and dictionary/linked match selection are identical before timing begins.
Three alternating in-process rounds retain the best Vort and reference sample.
The fixed-CPU evidence below used 20 encodes per sample:

```sh
taskset -c 2 zig build -j2 run-lz4-hc-reference-bench -- \
  --iterations 20 --csv /tmp/vort-lz4-hc-reference-fixed.csv
```

The 300 KiB linked corpus starts with 60 KiB of deterministic high-entropy
bytes and then repeats at distance 60 KiB. The 192 KiB dictionary corpus starts
with a 65,535-byte preset-dictionary match and repeats across later blocks.

## Result

| row | encoded/input | Vort MiB/s | liblz4 MiB/s | Vort/liblz4 |
| --- | ---: | ---: | ---: | ---: |
| independent level 9 | 0.950309 | 53.04 | 83.21 | 0.6374x |
| linked level 9 | 0.204248 | 146.26 | 286.72 | 0.5101x |
| linked level 12 | 0.204248 | 134.01 | 242.25 | 0.5532x |
| dictionary independent level 9 | 0.004278 | 311.75 | 1246.02 | 0.2502x |
| dictionary linked level 9 | 0.668238 | 45.19 | 68.44 | 0.6603x |
| dictionary linked level 12 | 0.668238 | 44.98 | 60.72 | 0.7408x |

The benchmark is evidence-only for now: its gate locks six rows, provenance,
wire equality, dictionary/mode coverage, positive timings, and compression,
but does not turn the initial ratios into regression floors.

## Interpretation

Vort deliberately reconstructs a fresh logical `prefix ++ block` context for
each HC block. The byte-identical result proves the search/parser behavior is
correct, but independent dictionary frames repeatedly seed the same 64 KiB
dictionary hash/chain state; liblz4's CDict precomputes that state once. That
row is therefore the clearest next optimization target. Linked rows also pay
for prefix concatenation and history-table seeding, while the stronger level-12
ratio does not introduce a proportionally larger gap.

The next candidate should cache a validated dictionary seed or restore a
prebuilt HC table snapshot while preserving exact liblz4 bytes. Reusable and
incremental throughput need separate rows after the one-shot setup cost is
reduced; they should not be conflated with this allocation-inclusive baseline.
