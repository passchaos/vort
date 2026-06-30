# Performance evidence

Vort does not yet claim compression performance wins. This document records the
benchmark protocol and the current bootstrap benchmark surface so future claims
can be tied to reproducible evidence.

## Current local benchmark entrypoints

```sh
zig build -Doptimize=ReleaseFast ci-smoke
zig build bench-checksum -Doptimize=ReleaseFast
zig build bench-deflate-decode -Doptimize=ReleaseFast
zig build bench-corpus-decode -Doptimize=ReleaseFast
zig build bench-deflate-encode -Doptimize=ReleaseFast
zig build bench-native-parallel -Doptimize=ReleaseFast
zig build bench-native-parallel -Doptimize=ReleaseFast -- README.md 4096
zig build -Doptimize=ReleaseFast run-native-parallel-corpus-report
zig build -Doptimize=ReleaseFast run-native-parallel-dashboard
zig build -Doptimize=ReleaseFast run-native-parallel-dashboard -- --paths README.md docs/roadmap.md
zig build -Doptimize=ReleaseFast run-native-parallel-full-dashboard
zig build -Doptimize=ReleaseFast run-file-corpus-report -- README.md docs/roadmap.md
zig build run-zstd-compare
zig build -Doptimize=ReleaseFast run-standard-corpus-report
zig build -Doptimize=ReleaseFast run-standard-corpus-report -- --suite
zig build -Doptimize=ReleaseFast run-standard-corpus-suite
zig build -Doptimize=ReleaseFast run-standard-corpus-dashboard
zig build -Doptimize=ReleaseFast run-standard-corpus-full-dashboard
zig build -Doptimize=ReleaseFast run-standard-corpus-report -- --paths README.md docs/roadmap.md
zig build -Doptimize=ReleaseFast run-standard-corpus-report -- --paths ~/Work/zlib-rs/silesia-small.tar
zig build -Doptimize=ReleaseFast run-standard-corpus-report -- --full
```

The checksum smoke benchmark processes a deterministic 1 MiB buffer repeatedly
through Adler-32, CRC-32 scalar, CRC-32 slice-by-4, CRC-32 slice-by-8, CRC-32 best dispatch, CRC-32C scalar, CRC-32C slice-by-8, and CRC-32C best dispatch paths and reports aggregate MiB/s. The deflate decode smoke benchmark repeatedly decodes representative raw/zlib/gzip fixed and dynamic samples and includes the fixed-Huffman literal/distance lookup fast path. The corpus decode benchmark builds Vort raw/zlib/gzip frames for text, structured, repetitive, and deterministic binary corpora, then reports wrapper-specific decode MiB/s while verifying every round trip. The fixed encode smoke benchmark runs greedy-LZ77-backed raw fixed deflate encoding and verifies round trips. The native parallel benchmark compares planned, spawned-thread, fixed thread-pool, and work-queue native stream encoders on either its built-in corpus, a provided real file path and block size, bounded/full Silesia files via `run-native-parallel-corpus-report`, or Markdown dashboards via `run-native-parallel-dashboard` and `run-native-parallel-full-dashboard`; the dashboard step also accepts `-- --paths <files-or-dirs-or-tar-archives>` for external corpora and includes per-mode total throughput summaries. The file corpus report emits per-file ratio plus encode/decode MiB/s for Vort fastest/fast/best deflate; `run-zstd-compare` emits zstd size beside Vort best/fixed size; `run-standard-corpus-report` compares Vort, gzip, zlib-ng, zlib-rs, and zstd compression and decompression timings on a bounded Silesia sample, with `-- --suite` (or the `run-standard-corpus-suite` alias) for per-file bounded Silesia automation, `-- --paths <files-or-dirs-or-tar-archives>` for arbitrary external corpora, `run-standard-corpus-dashboard` for a bounded Markdown dashboard at `zig-out/vort-standard-corpus-dashboard.md`, `run-standard-corpus-full-dashboard` for a full-size Silesia dashboard at `zig-out/vort-standard-corpus-full-dashboard.md`, and `-- --full` for the full local Silesia tar. Use `-Doptimize=ReleaseFast` for any performance interpretation; Debug timings are only build-smoke signals. These are still smoke reports and not a final competitor benchmark claim.
`ci-smoke` is a validation aggregate rather than a full benchmark suite; it
includes bounded reports to catch regressions quickly, while full-corpus or
long-running throughput evidence should still be run as dedicated commands.

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
