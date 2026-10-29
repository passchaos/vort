# DEFLATE adaptive split horizon evidence

- `ab-192k.json`: five case-paired sweeps over all twelve Silesia 192 KiB
  prefixes, including every process command and raw timer.
- `ab-512k.json`: three case-paired sweeps over Dickens, Mozilla, and Samba
  512 KiB prefixes.
- `interop.json`: raw/zlib/gzip wire hashes and system-zlib decode results for
  all twelve 192 KiB inputs.
- `wires.tar.xz`: the exact 36 wrapper wires; `audit.py` decodes them again.
- `reference-sizes.json`: zlib 1.2.11 level-6/level-9 sizes for those inputs.
- `inputs.tar.xz`: the exact 12 x 192 KiB and 3 x 512 KiB prefixes.
- `audit.py`: reconstructs medians/geometric means and checks the size and
  independent-decode gates.
- `measure.py`: the retained case-paired campaign runner.
- `probe.zig` and `interop.py`: the retained wrapper-wire producer and
  independent system-zlib verifier/reference-size generator.
- `source-overlay.tar.xz` and `source-manifest.json`: the complete candidate
  source overlay on baseline `f560b156`.
- `replay-check.json`: a clean archive+overlay rebuild and byte-identical Samba
  wrapper-wire replay, independent of the dirty calling worktree.
- `commands.txt` and `identities.txt`: concrete source, executable, input,
  compiler and command identities.

The baseline is clean `f560b156`. Timing uses ordinary ReleaseFast calls, not
instrumented profiles. The benchmark includes allocation/free and performs one
untimed warmup before the timed encode.

`SHA256SUMS` binds every retained source, runner, result and archive; `audit.py`
checks the complete list before reconstructing timing and decoding wires.
