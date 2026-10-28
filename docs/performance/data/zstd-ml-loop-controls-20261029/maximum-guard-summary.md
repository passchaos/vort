# Maximum-guard evidence archive

The candidate remains unadopted after a mixed exploratory screen. It adds exactly two lines after the original maximum and short exhaustive edges, skipping the unchanged ML loop when `maximum <= 17` for btopt or `maximum <= 66` for other sampled strategies. Baseline revision: `5f38d682101e7840c89939877b9dd71517d9c4a8`.

`maximum-guard.tar.xz` contains 134 members, including the ordinary runner, original commands/results, all 24 wire/profile records, original source diff, exact candidate/reference sources, compiler and binary/object identities, smoke/codegen evidence, and six exact contract sources with their three observed terminal records. Full source trees, caches, ELF runners and objects are omitted; `baseline-source.tar.xz` and `inputs.tar.xz` are shared dependencies. The diff is contained inside the archive.

| Case | Strategy | Median candidate / median baseline | Round 0 | Round 1 |
| --- | --- | ---: | ---: | ---: |
| dickens | btopt | 0.992429552 | 0.978197014 | 1.006457235 |
| dickens | btultra2 | 0.983288095 | 1.008862983 | 0.959000399 |
| mozilla | btopt | 0.994298161 | 0.999032271 | 0.989570257 |
| mozilla | btultra2 | 0.969412594 | 0.977413072 | 0.961537808 |
| mr | btopt | 1.080517536 | 1.208580010 | 0.950963592 |
| mr | btultra2 | 0.975622743 | 0.981036929 | 0.970224090 |

Ratios are independently recomputed as `median(candidate_ns) / median(baseline_ns)` with exact rational arithmetic before conversion to floating point. Raw rounds and their reversed AB/BA order are preserved. MR btopt first-round baseline ordinary/profile timings were 8.386470/8.286943 ms; candidate timings were 10.135720/10.025051 ms. In round 1 candidate timings were 7.883414/7.850788 ms and baseline timings were 8.289922/8.384495 ms. The first candidate was slower in both encode observations; the two rounds do not establish a stable regression magnitude.

Independent audit verified 24 ordinary rows, 12 baseline/candidate wire/profile pairs, six median ratios, the exact two-line source transformation and endpoint minima 17/66. All 24 archived wires were decoded with the local libzstd 1.6.0 oracle (version 10600, SHA256 `c76f4c4457df67a5e0c7bb6bb4f58b9857cf4f2cdd7925bfb9345daac4e6b83e`) and matched the three 4096-byte inputs exactly. The screen recorded 48 native decodes; these are preserved historical results.

Contract Debug, ReleaseFast and x86 Debug records each show actual exit 0 and 7/7. Their independent trace fixture covers 1,572,900 pairs per run. Wasm was prepared but not executed. The contract directory has no original artifact manifest; its supplied six source hashes and validation records are archived and verified. Original screen and reused-baseline manifests were audited for all 117 and 118 artifacts before packing.

Candidate compilation and smoke records show exit 0 and 6/6. Original compile flags/affinities are preserved; compiler executable identity and host model were observed during archival. The archived disassembly independently totals 628 baseline bytes and 672 candidate bytes. Benchmark CPU2 was separate from compilation CPUs 4,6; a background compiler was observed on CPU4, without a directly observed CPU2 overlap.

Run `python3 docs/performance/data/zstd-ml-loop-controls-20261029/guard_validation_audit.py` for a read-only artifact/source/ratio/record audit. Add `--decode` to repeat the 24 oracle decodes. `maximum-guard-index.json` binds archive members, shared dependencies and standalone reports/scripts by SHA256 and size. Archival performed no new compilation, codec tests or timing rounds.
