# Performance evidence

Vort does not yet claim compression performance wins. This document records the
benchmark protocol and the current bootstrap benchmark surface so future claims
can be tied to reproducible evidence.

## Current local benchmark entrypoints

```sh
zig build bench-checksum -Doptimize=ReleaseFast
zig build bench-deflate-decode -Doptimize=ReleaseFast
zig build bench-deflate-encode -Doptimize=ReleaseFast
zig build run-file-corpus-report -- README.md docs/roadmap.md
zig build run-zstd-compare
zig build run-standard-corpus-report
```

The checksum smoke benchmark processes a deterministic 1 MiB buffer repeatedly
through Adler-32, CRC-32, and CRC-32C and reports aggregate MiB/s. The deflate decode smoke benchmark repeatedly decodes representative raw/zlib/gzip fixed and dynamic samples. The fixed encode smoke benchmark runs greedy-LZ77-backed raw fixed deflate encoding and verifies round trips. The file corpus report emits per-file ratio plus encode/decode MiB/s for Vort fastest/fast/best deflate; `run-zstd-compare` emits zstd size beside Vort best/fixed size; `run-standard-corpus-report` compares Vort, gzip, zlib-ng, zlib-rs, and zstd on a bounded Silesia sample. These are still smoke reports and not a final competitor benchmark claim.

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
