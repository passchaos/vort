# DEFLATE adaptive bit-state evidence

- `ab-192k.json`: five alternating sweeps over twelve Silesia 192 KiB inputs.
- `ab-512k.json`: three alternating sweeps over Dickens, Mozilla, and Samba
  512 KiB inputs.
- `interop.json` and `wires.tar.xz`: 36 raw/zlib/gzip wires and independent
  system-zlib decode hashes.
- `artificial-screen.json`: the 64-case mixed multi-block size screen.
- `source-overlay.tar.xz` and `source-manifest.json`: the exact two-file
  candidate over clean `d4a80299`.
- `measure.py`, `probe.zig`, `interop.py`, and `commands.txt`: replay tooling.
- `identities.txt` and `SHA256SUMS`: environment and artifact identities.
- `audit.py`: reconstructs timing/size gates, verifies source identities, and
  independently decodes every archived wire.

Exact inputs are shared with:

```text
../deflate-adaptive-split-horizon-20261029/inputs.tar.xz
sha256 51cbf9b523f88c6ca8a1402acafa2fa3ef7e563465fbeeb6faec3d2f2fef3539
```
