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

## Prepared-prefix optimization

On 2026-10-13, the independent-dictionary path was changed to build the
retained dictionary hash/chain state once and restore that snapshot for each
block. The one-shot frame writer owns one prepared prefix for the complete
frame, while the incremental HC adapter retains one until the dictionary
changes or the encoder is released. Linked frames continue through the
existing rolling-history path. The prepared-prefix setup and independent
dictionary frame writer use a separate text section so their cold code does
not expand the ordinary frame writer.

The performance A/B compared the original baseline executable
`ba9b2160e59c15b5bfccd565df1f8b4052a3372a1b16f29c594b7bc1f9576254`
with candidate executable
`2998fc4ab97d1e216d76c158fc1fccd01ea1678ec9dfee6bb13ff821b387d4ca`.
Both were ReleaseFast binaries. Eleven process pairs were pinned to CPU 2,
the baseline/candidate order alternated between pairs, and every process used
60 benchmark iterations. The ratios below are baseline elapsed time divided
by candidate elapsed time; values above one favor the candidate. The
confidence interval is calculated over the paired log ratios.

| row | median | geometric mean | 95% CI | candidate wins |
| --- | ---: | ---: | ---: | ---: |
| independent level 9 | 0.9985x | 1.0016x | 0.9899x...1.0135x | 5/11 |
| linked level 9 | 1.0036x | 1.0017x | 0.9869x...1.0168x | 6/11 |
| linked level 12 | 0.9885x | 0.9961x | 0.9809x...1.0116x | 4/11 |
| dictionary independent level 9 | 1.6641x | 1.6651x | 1.6310x...1.7000x | 11/11 |
| dictionary linked level 9 | 0.9913x | 0.9916x | 0.9797x...1.0036x | 3/11 |
| dictionary linked level 12 | 1.0002x | 0.9960x | 0.9806x...1.0116x | 6/11 |

All paired rows retained identical encoded sizes. The independent-dictionary
gain is large, stable, and excludes one by a wide margin; every control row's
interval includes one, so the matrix does not detect a control-path change.
The dictionary-linked level-9 point estimate remains the weakest control and
should stay visible in future layout or HC-core work rather than being treated
as a demonstrated improvement.

Focused correctness evidence after the optimization consists of 13 LZ4HC
tests, the six-row reference benchmark gate, and the native differential probe:
253 liblz4-generated frames and 304 total cases, including 13 incremental HC
linked/CDict cases. The probe continues to require exact Vort/liblz4 frame
bytes, not only successful round trips.
