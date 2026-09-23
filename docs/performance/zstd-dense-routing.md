# Dense Zstd sequence routing

The decoder previously selected its long-match small-literal executor solely
when a block regenerated at most 4 KiB of literals. Sparse literals do not
imply few sequences: the frozen build.zig sample's second block contains
2,101 literal bytes and 6,016 sequences. Sampling placed about 60% of its
decode time in that executor.

The small executor now also requires at most 4,096 sequences. A Zstd block
produces at most 128 KiB, so a greater sequence count implies fewer than
32 output bytes per sequence on average. Such blocks use the existing grouped
reader and short-match executor, even with sparse literals. The rule is in
`src/zstd/sequence/decode_policy.zig` and is shared by one-shot, reusable, and
prepared-stage routing. Dictionary exclusions, four-stream/all-FSE guards,
literal scratch capacities, and exact caller-output bounds remain unchanged.

## Validation

- A fixed libzstd 1.5.7 level-3 frame regenerates 6,000 deterministic short
  assignments, with 2,076 literals and 5,820 sequences. The fixture test proves
  more than 5,000 grouped-reader hits through the public one-shot and reusable
  APIs, including a warm sequence-table-cache hit.
- The same fixture compares every output byte with generic decoding, checks
  a short caller buffer and suffix sentinels, compares truncated/mutated input
  errors, and streams input/output in 47/113-byte chunks. The prepared-stage
  oracle must classify the block as grouped and retain its sequence count.
- The selector boundary test covers 4,096/4,097 sequences and 4,096/4,097
  literal bytes, plus the retained large_json shape.
- Focused ReleaseFast Zstd tests: 496 passed. Final ReleaseSafe route and
  mutation tests: 7 passed. CLI `zig build run -j1 -- --help` passed.
- Runtime libzstd 1.5.7 compatibility matrix: 276 cases. Upstream decodecorpus:
  9 campaigns, 9,900 frames, all 64 sequence-mode combinations, and 2,699
  block-stream cases passed.

## Measurement protocol

Baseline commit: `72ed5ea6`. Host: Apple M1 Pro, macOS, Zig 0.16.0,
ReleaseFast, target CPU apple_m1, one codec thread, no affinity pinning.
Reference library: `/opt/homebrew/opt/zstd/lib/libzstd.dylib`, version 1.5.7.
Desktop/system processes remained active; use paired results rather than
interpreting absolute throughput as an idle-host maximum.

Both executables consume frozen README/build/roadmap/source snapshots from
the preceding field-group experiment. Files are encoded with libzstd level 1.
The public caller-owned decode harness checks output equality before timing,
selects the best of five rounds per process, and alternates baseline/candidate
process order across 11 pairs. Build and README use 1,500 iterations; the
larger roadmap/source files use 300. Controls use 1,500 iterations on
large_json, ascii64k (level 9), and binary_mixed.

```sh
zig build run-zstd-reference-bench -j1 -- --input /path/to/frozen-build --iterations 1500 --csv /path/to/result.csv --libzstd /opt/homebrew/opt/zstd/lib/libzstd.dylib
zig build run-zstd-sequence-decode-stage-bench -j1 -- --input /path/to/frozen-build --iterations 1000 --rounds 7 --csv /path/to/stage.csv --libzstd /opt/homebrew/opt/zstd/lib/libzstd.dylib
```

## Results (2026-09-23)

| Input | Median new/old | Geometric new/old | Wins | Vort MiB/s | libzstd MiB/s | Vort/libzstd |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| readme | 1.0003x | 0.9966x | 6/11 | 1368.81 | 1402.52 | 0.9760x |
| build | 1.4085x | 1.4082x | 11/11 | 1973.78 | 2244.06 | 0.8770x |
| roadmap | 1.0033x | 1.0054x | 8/11 | 857.60 | 1281.83 | 0.6672x |
| source | 1.0514x | 1.0498x | 11/11 | 1538.63 | 1855.59 | 0.8275x |
| ascii64k | 1.0033x | 1.0020x | 6/11 | 1055.05 | 991.78 | 1.0578x |
| large_json | 1.0018x | 0.9991x | 6/11 | 5964.02 | 6415.33 | 0.9321x |
| binary_mixed | 0.9916x | 0.9971x | 4/11 | 7540.50 | 6555.55 | 1.1407x |

All 22 build/source pairs improve. Other row medians are within 0.84% of
baseline; no improvement is claimed for those controls. Throughput columns
are independent medians, and Vort/libzstd is the median of same-process
ratios. Raw CSVs and validation logs are retained locally under
zig-out/zstd-dense-routing-20260923/.

## Goal coverage

This change corrects a specific routing bottleneck. The compatibility and
mutation gates cover correctness, while same-input public-API benchmarks
measure the speed improvement. Neither establishes industry-leading Zstd
decoding overall: broader corpora, compression levels, streaming/dictionary
performance, memory comparisons, and additional architectures remain open.
