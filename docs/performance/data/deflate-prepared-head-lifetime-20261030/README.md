# DEFLATE prepared-head lifetime evidence

This epoch compares clean `c01ff424` with the single-file prepared-index
lifetime change.

- `raw-best-ab.json` and `level8-raw-ab.json`: retained level-9 and level-8
  ordinary A/B campaigns.
- `rejected-cache8-ab.json` and `rejected-cache1-ab.json`: exact-wire negative
  screens for the removed match-length caches.
- `interop-baseline.json` and `interop-candidate.json`: 216 raw/zlib/gzip wire
  hashes per side and independent system-zlib decode results.
- `heap-results.json`, `rss-*.txt` and `rss-summary.json`: requested-byte and
  process-level memory evidence.
- `source-overlay.tar.xz`: the complete candidate `src/lz77.zig`.
- `summary.json`, `validation.txt`, `identities.txt`, `commands.txt` and
  `SHA256SUMS`: condensed results, gates, provenance, replay and hashes.

Timing uses ordinary uninstrumented executables. The heap probe is used only
for requested-memory accounting.
