# DEFLATE compact predecessor negative screen

This directory records two rejected wire-transparent predecessor layouts
relative to clean baseline `f7750905`.

- `u16-ab.json`: 16-bit head and predecessor screen.
- `packed2-ab.json`: 16-bit head plus two predecessors packed per `u32`.
- `packed2-source-overlay.tar.xz`: complete packed-two-hop candidate
  `src/lz77.zig`.
- `summary.json`, `identities.txt`, `commands.txt` and `SHA256SUMS`: condensed
  results, provenance, replay and hashes.

All source changes were removed after the screen.
