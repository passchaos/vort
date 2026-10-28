# Prepared row-tag exploratory evidence

Baseline is `9433c9bb`, including the exact row-tag index. The candidate changes
only `row_tags.zig` and `search_edges.zig` to prepare one tag per offset choice.
It remains a private unadopted prototype. Exact source hashes, binary identities,
raw round clocks and wire/profile records are retained in the manifest/archive.

`baseline-source.tar.xz` contains the source/build snapshot. `ordinary-screen`
and `inputs` archives preserve both exact candidate modules, runner, structured
commands, generated code, all results and actual input/output bytes. The
`current-hotspots` archive separately preserves ordinary-only FP sampling,
raw perf/IP periods, source and binary identities and instruction attribution.
`frozen-contracts` contains the prepared-tag tests, frozen current reference
modules, the small generic helper adaptation and its actual three-target
9/9 terminal records. Native runner binaries and caches are excluded.

Run this directory's `audit.py` to check archive/source identities, wire/profile
pairs, timing summaries, global sampled periods, contract terminal records and
the independent decoder records. Replay uses the shared snapshot plus candidate
or test overlays and rewrites archived structured path arguments. Keep FP
sampling separate from non-FP timing and retain the recorded input identities.
