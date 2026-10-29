# DEFLATE cost-class frontier negative screen

This directory preserves the rejected exact DEFLATE distance-symbol frontier
experiment relative to baseline `814fd654`.

- `separate-build-ab.json`: frontier constructed independently before both DP
  solves.
- `fused-build-ab.json`: frontier collection fused into the fixed solve.
- `frontier-profile.zig`: coverage and owned-capacity diagnostic used with the
  prototype overlay.
- `fused-source-overlay.tar.xz`: complete fused candidate `src/lz77.zig` and
  `src/deflate.zig`.
- `summary.json`, `identities.txt`, `commands.txt` and `SHA256SUMS`: condensed
  results, provenance, replay guidance and hashes.

All prototype source changes were removed after the screen. These artifacts
record a negative engineering decision, not a retained code path.
