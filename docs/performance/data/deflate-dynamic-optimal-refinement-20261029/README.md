# DEFLATE dynamic optimal refinement evidence

This directory preserves the final ordinary A/B and compatibility epoch for
the one-round dynamic-Huffman-aware optimal proposal added to levels 8 and 9.

- `raw-best-ab.json` and `level8-raw-ab.json`: all three process samples for
  every one of 36 Silesia prefix cases, plus case medians and aggregate
  timing/size summaries.
- `interop.json`: 216 level/wrapper/input records independently decoded by
  Python's system zlib, including exact input, decoded and wire hashes plus
  zlib reference sizes.
- `inputs.tar.xz` and `wires.tar.xz`: exact ordinary inputs and candidate
  compatibility outputs.
- `measure.py`, `interop.py`, `numeric_bench.zig` and `wire_probe.zig`: the
  measurement and compatibility harnesses used by this epoch.
- `rss-baseline.txt` and `rss-candidate.txt`: `/usr/bin/time -v` output for the
  allocation-heavy `nci-16384` representative.
- `source-overlay.tar.xz`: the complete three-file candidate source overlay
  relative to clean baseline commit `89d7d3f2751d96e9c9c80be8492a97217f825edf`.
- `summary.json`, `identities.txt`, `commands.txt` and `SHA256SUMS`: condensed
  results, immutable identities, exact replay and archive checksums.

The measurement is ordinary uninstrumented execution. No profile timing is
used as throughput evidence. The 65,536-byte cases intentionally sit one byte
above the 65,535-byte production cap and act as unchanged controls.
