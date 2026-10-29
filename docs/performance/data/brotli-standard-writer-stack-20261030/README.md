# Brotli standard-writer stack evidence

This directory compares baseline `3d2ffb7b` with the standard 79-symbol writer
split into a separate `noinline` specialization.

- `frames.json`: compiled Debug Wasm function frames.
- `stack-witness.json`: 4/5/5.5/6/8 MiB public-gate outcomes and artifact
  identities.
- `q8-formal-comparison.json`: 36-case ordinary q8 A/B.
- `q10q11-comparison.json`: fifteen samples per side for q10/q11 source32k.
- `q8-formal.py` and `q10q11.py`: ordinary measurement/reduction scripts.
- `source32k.bin`: exact q10/q11 benchmark input.
- `wire_parity.zig`: 32-case dual-module exact-wire oracle.
- `wasm_stack_frames.py`: frame extractor including the new standard body.
- `source-overlay.tar.xz`: complete candidate `src/br.zig`.
- `summary.json`, `validation.txt`, `identities.txt`, `commands.txt` and
  `SHA256SUMS`: condensed results, gates, provenance, replay and hashes.

The Wasm binaries are identified by SHA-256 rather than duplicated here.
