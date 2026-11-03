# Brotli q8 stage profile, 2026-11-03

`run-br-quality-stage-profile` records the public q8 candidate pipeline on
64 KiB Silesia slices. Three rounds use q8, generic mode and actual window 16;
the first round's exclusive stage clocks are summarized here. Ordinary public
encoding is the wire oracle; profile instrumentation is diagnostic and not an
ordinary throughput sample.

| Case | Outer ms | optimal_parse | context_proposals | wire | evaluate | distance_parameters | lazy_parse | split_planning |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| xml | 24.79 | 15.81 (63.8%) | 5.18 (20.9%) | 0.80 (3.2%) | 0.88 (3.5%) | 0.85 (3.4%) | 0.77 (3.1%) | 0.27 (1.1%) |
| dickens | 31.58 | 5.50 (17.4%) | 5.40 (17.1%) | 4.52 (14.3%) | 4.28 (13.6%) | 4.16 (13.2%) | 3.58 (11.3%) | 2.30 (7.3%) |
| x-ray | 40.13 | 2.05 (5.1%) | 8.87 (22.1%) | 16.35 (40.7%) | 4.34 (10.8%) | 2.99 (7.4%) | 1.74 (4.3%) | 2.27 (5.7%) |

XML is dominated by the optimal parse; x-ray is dominated by payload emission.
Dickens spreads work across optimal parse, context proposals, wire emission,
candidate evaluation and distance parameters. Context proposals remain 17–22%
on all three, and their internal `cluster_score_ns` is the largest sub-stage
(1.2–1.7 ms).

This routes q8 speed work by content: optimal-search cost for text/XML,
literal and command payload emission for binary data, and context clustering
for every class. The table does not establish full-file shares; the earlier
[bounded full-file screen](full-file-q8-20261103.md) measured a 3.6x geometric
encode-time gap at competitive size.

```sh
zig build run-br-quality-stage-profile -- --rounds 3 \
  --path /tmp/xml-64k --path /tmp/dickens-64k --path /tmp/x-ray-64k \
  --json /tmp/q8-profile.json
```

[Raw rows](q8-stage-profile-20261103.csv) retain the complete exclusive-stage
counters and candidate-attempt counts.
