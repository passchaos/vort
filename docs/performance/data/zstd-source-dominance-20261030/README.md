# Zstd source dominance evidence

- `comparison.json`: eight-sweep ReleaseFast cold-btultra2 A/B and controls.
- `measure.py`: retained AB/BA runner and reducer.
- `inputs.tar.xz`: exact 4/16 KiB Silesia prefixes and trained dictionary case.
- `hq-search-report.json`: 41-row public search differential plus eight frozen
  baseline wires.
- `source-overlay.tar.xz` and `source-manifest.json`: exact candidate source
  over clean `88eebd7f`.
- `validation.txt`: focused, differential, Wasm, and full-suite gates.
- `commands.txt`, `identities.txt`, and `SHA256SUMS`: replay and provenance.
- `audit.py`: reconstructs timing/profile gates and checks all artifact hashes.
