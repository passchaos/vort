# Performance evidence

Vort does not yet claim compression performance wins. This document records the
benchmark protocol and the current bootstrap benchmark surface so future claims
can be tied to reproducible evidence.

## Current local benchmark entrypoints

```sh
zig build bench-checksum -Doptimize=ReleaseFast
zig build bench-deflate-decode -Doptimize=ReleaseFast
```

The checksum smoke benchmark processes a deterministic 1 MiB buffer repeatedly
through Adler-32, CRC-32, and CRC-32C and reports aggregate MiB/s. The deflate decode smoke benchmark repeatedly decodes representative raw/zlib/gzip fixed and dynamic samples. These are intended as sanity checks for timing infrastructure, not as competitor comparisons yet.

## Required evidence before performance claims

For each claim against `zlib`, `zlib-ng`, `zlib-rs`, or `zstd`, record:

- Vort git commit;
- competitor name, version, build flags, and command/API used;
- CPU model, OS, Zig version, optimization mode, and enabled CPU features;
- corpus name and input sizes;
- compression level/strategy/dictionary settings;
- compression throughput, decompression throughput, ratio, compressed bytes, and
  peak or configured memory use;
- correctness gate used after benchmark output was produced.

Compatibility-format benchmarks and native-format benchmarks must be reported
separately.
