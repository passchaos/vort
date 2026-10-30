# DEFLATE adaptive split drift evidence

- `ab-192k.json`: five alternating process sweeps over all twelve Silesia
  192 KiB prefixes.
- `ab-512k.json`: three alternating sweeps over Dickens, Mozilla, and Samba
  512 KiB prefixes.
- `interop.json`: 36 raw/zlib/gzip wire hashes and independent system-zlib
  decode results.
- `reference-sizes.json`: zlib 1.2.11 level-6 and level-9 reference sizes.
- `wires.tar.xz`: exact wrapper wires covered by `interop.json`.
- `source-overlay.tar.xz`: the four candidate source/test files over clean
  baseline `790ea6a3`.
- `source-manifest.json`: baseline, input archive, source, executable, and
  archive identities.
- `k-selection.json`: the bounded K1-K4 screening decision.
- `measure.py`, `probe.zig`, and `interop.py`: retained measurement and wire
  generation tools.
- `audit.py`: reconstructs timing/size aggregates, validates source identities,
  and independently decodes every archived wire.
- `commands.txt`: clean archive replay and validation commands.
- `identities.txt`: compiler, kernel, CPU, and pinned hashes.
- `SHA256SUMS`: checksums for every retained artifact except itself.

The exact inputs are shared with the preceding horizon campaign rather than
duplicated here:

```text
../deflate-adaptive-split-horizon-20261029/inputs.tar.xz
sha256 51cbf9b523f88c6ca8a1402acafa2fa3ef7e563465fbeeb6faec3d2f2fef3539
```
