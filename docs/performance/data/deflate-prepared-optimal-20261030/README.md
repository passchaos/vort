# DEFLATE prepared optimal evidence

This directory records the exact-wire performance and memory follow-up to the
2026-10-29 dynamic-optimal refinement.

- `raw-best-ab.json`: level-9/named-best 36-case ordinary A/B, seven timed
  encodes and five alternating process sweeps.
- `level8-raw-ab.json`: numeric level-8 36-case ordinary A/B, five timed
  encodes and five alternating process sweeps.
- `interop-baseline.json` and `interop-candidate.json`: 216 raw/zlib/gzip wire
  hashes per side and independent system-zlib decode results.
- `heap_probe.zig` and `heap-results.json`: requested-byte peak, cumulative
  traffic and allocation-count evidence for active and control inputs.
- `rss-*.txt` and `rss-summary.json`: five alternating `/usr/bin/time -v`
  samples per side.
- `source-overlay.tar.xz`: complete candidate `src/lz77.zig` and
  `src/deflate.zig` relative to baseline `803834d3`.
- `summary.json`, `validation.txt`, `identities.txt`, `commands.txt` and
  `SHA256SUMS`: condensed results, completed gates, provenance, replay commands
  and artifact hashes.

The input corpus and shared measurement helpers are retained in the preceding
[`deflate-dynamic-optimal-refinement-20261029`](../deflate-dynamic-optimal-refinement-20261029/)
epoch. Timing evidence is ordinary uninstrumented execution; heap
instrumentation is used only for requested-memory evidence.
