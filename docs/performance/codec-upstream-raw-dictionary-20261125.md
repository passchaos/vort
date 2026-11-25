# Upstream dictionary stream conformance, 2026-11-25

This is a correctness check, not a compression-ratio or speed result. The
codec source is `c639c3b9`; this change extends the differential harness. The
reference libraries were libz 1.2.11, libzstd 1.6.0, and libbrotli 1.2.0. The
version checks matched the producer and decoder for each family.

```sh
export LD_LIBRARY_PATH="$HOME/Work/brotli/build-vort:$HOME/Work/zstd/lib"
zig build run-codec-real-dictionary-smoke
xml="$HOME/Work/corpora/silesia-20261025/files/xml"
head -c 32768 "$xml" > /tmp/xml-prefix.raw
zig build -Doptimize=ReleaseFast run-codec-differential-fuzz -- \
  --real-file="$xml" --real-dictionary=/tmp/xml-prefix.raw
```

Both inputs were encoded with 64 KiB flush intervals in raw Deflate, zlib,
Zstd and Brotli. Gzip has no preset-dictionary mechanism and was omitted.
The built-in fixture is 196,941 bytes with SHA-256
`c86873b44d9a81fde1df8e8c289469422a08c28eaf84ef97639b429ed697823b`;
its dictionary SHA-256 is
`10179aeea3c01a2062571da59171bab5df9ef5ba650c83cd6935fbba774c132f`.
The complete 5,345,280-byte Silesia XML input uses its first 32 KiB as a
fixture dictionary (SHA-256
`c2f7f129956f8d6fc3d0e3595d93f98d5270b6f5bc4ab5e70f45867822efdd71`),
not a dictionary trained on an independent corpus. Its complete source hash
is in the [full-file receipt](codec-upstream-real-20261124.md).

All eight complete wires decoded identically both with the reference and
with Vort's ordinary and exact-size paths. Neither the reference nor Vort
reconstructed the original bytes with the dictionary omitted. The two
incremental schedules passed 16 complete runs and 16 final-byte cuts. They
also passed 48 flush-cut replays: three cuts per wire with two schedules.
Each replay consumed its complete compressed prefix and reported truncation;
prevalidated Zstd retained its unfinished frame while the other routes
published the exact upstream plaintext prefix. The runner prints full source,
dictionary and wire digests for reproduction.

The ordinary no-dictionary smoke remains usable with the older system
libbrotli. Selecting Brotli for dictionary mode with that library explicitly
fails instead of counting a skipped reference check as a pass.
