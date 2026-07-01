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
zig build bench-native-parallel -Doptimize=ReleaseFast -- README.md 4096 2
zig build -Doptimize=ReleaseFast run-native-parallel-corpus-report
zig build -Doptimize=ReleaseFast run-native-parallel-dashboard
zig build -Doptimize=ReleaseFast run-native-parallel-dashboard -- --workers 2 --block-len 4096 --paths README.md docs/roadmap.md
zig build -Doptimize=ReleaseFast run-native-parallel-dashboard -- --worker-sweep 1,2,4 --paths README.md docs/roadmap.md
zig build -Doptimize=ReleaseFast run-native-parallel-full-dashboard
zig build -Doptimize=ReleaseFast run-native-parallel-full-dashboard -- --workers 2 --paths README.md docs/roadmap.md
zig build -Doptimize=ReleaseFast run-native-parallel-multi-corpus-dashboard -- --limit 3
zig build -Doptimize=ReleaseFast run-native-parallel-multi-corpus-full-dashboard
zig build -Doptimize=ReleaseFast run-native-parallel-multi-corpus-full-dashboard -- --workers 2 --paths README.md docs/roadmap.md
zig build run-split-policy-report
zig build run-split-policy-report -- README.md docs/roadmap.md
zig build -Doptimize=ReleaseFast run-split-policy-corpus-report
zig build -Doptimize=ReleaseFast run-split-policy-corpus-report -- --all
zig build run-native-range-report
zig build run-native-range-report -- README.md docs/roadmap.md
zig build run-native-range-report -- --offset 32 --length 64 README.md
zig build run-native-range-report -- --sweep README.md
zig build run-dictionary-report -- README.md docs/roadmap.md
zig build run-dictionary-report -- --target 512 README.md docs/roadmap.md
zig build -Doptimize=ReleaseFast run-dictionary-corpus-report
zig build -Doptimize=ReleaseFast run-dictionary-corpus-report -- --per-file
zig build -Doptimize=ReleaseFast run-dictionary-corpus-dashboard
zig build -Doptimize=ReleaseFast run-dictionary-corpus-dashboard -- --targets 128,256,512
zig build -Doptimize=ReleaseFast run-file-corpus-report -- README.md docs/roadmap.md
zig build -Doptimize=ReleaseFast run-file-corpus-dashboard -- README.md docs/roadmap.md
zig build -Doptimize=ReleaseFast run-file-corpus-dashboard -- docs
zig build -Doptimize=ReleaseFast run-file-corpus-dashboard -- ~/Work/zlib-rs/silesia-small.tar
zig build -Doptimize=ReleaseFast run-file-corpus-standard-dashboard -- --limit 3
zig build run-zstd-compare
zig build -Doptimize=ReleaseFast run-standard-corpus-report
zig build -Doptimize=ReleaseFast run-standard-corpus-report -- --suite
zig build -Doptimize=ReleaseFast run-standard-corpus-suite
zig build -Doptimize=ReleaseFast run-standard-corpus-dashboard
zig build -Doptimize=ReleaseFast run-standard-corpus-full-dashboard
zig build -Doptimize=ReleaseFast run-standard-corpus-report -- --paths README.md docs/roadmap.md
zig build -Doptimize=ReleaseFast run-standard-corpus-report -- --paths ~/Work/zlib-rs/silesia-small.tar
zig build -Doptimize=ReleaseFast run-standard-corpus-report -- --full
zig build -Doptimize=ReleaseFast run-standard-multi-corpus-suite
zig build -Doptimize=ReleaseFast run-standard-multi-corpus-dashboard -- --limit 3
zig build -Doptimize=ReleaseFast run-standard-multi-corpus-full-suite
zig build -Doptimize=ReleaseFast run-standard-multi-corpus-full-dashboard
```

The checksum smoke benchmark processes a deterministic 1 MiB buffer repeatedly
through Adler-32, CRC-32 scalar, CRC-32 slice-by-4, CRC-32 slice-by-8, CRC-32 slice-by-16, CRC-32 best dispatch, CRC-32C scalar, CRC-32C slice-by-8, CRC-32C slice-by-16, and CRC-32C best dispatch paths and reports aggregate MiB/s plus selected checksum dispatch names. The deflate decode smoke benchmark repeatedly decodes representative raw/zlib/gzip fixed and dynamic samples and includes the fixed-Huffman literal/distance lookup fast path. The corpus decode benchmark builds Vort raw/zlib/gzip frames for text, structured, repetitive, and deterministic binary corpora, then reports wrapper-specific decode MiB/s while verifying every round trip. The fixed encode smoke benchmark runs greedy-LZ77-backed raw fixed deflate encoding and verifies round trips. `run-level-report` reports parser/level/strategy/cost-model settings on built-in samples or provided files; `run-split-policy-report` compares one-shot vs adaptive split sizes for every compression level on built-in corpora or provided file paths; `run-split-policy-corpus-report` runs the same policy delta report over a bounded Silesia subset by default, with `-- --all` for all bounded Silesia files. `store-sidecar-range-demo` exercises external sidecar indexes; `run-native-range-report` verifies checksum-validated indexed range decode and accepts `-- --offset <n> --length <n>` or `-- --sweep` across store, blocked best, dictionary, self-contained/trained dictionary, indexed LDM, and blocked LDM native streams, or across provided file paths using blocked-best native streams. `run-compression-report` includes trained-dictionary stream selection metrics; `run-dictionary-report` can train on built-in samples or provided files, accepts `-- --target <bytes>`, and reports dictionary patch/native-best ratios; `run-dictionary-corpus-report` applies that dictionary report to a bounded Silesia subset, with `-- --per-file` for per-file rows, `-- --targets a,b,c` for target-size sweeps, and `run-dictionary-corpus-dashboard` for a Markdown dashboard. The native parallel benchmark compares planned, spawned-thread, fixed thread-pool, and work-queue native stream encoders on either its built-in corpus, a provided real file path plus block size/worker count, dashboard `-- --block-len <bytes>` overrides, bounded/full Silesia files via `run-native-parallel-corpus-report`, discoverable standard corpora via `run-native-parallel-multi-corpus-dashboard` / `run-native-parallel-multi-corpus-full-dashboard` (`-- --limit n` bounds rows for smoke runs), or Markdown dashboards via `run-native-parallel-dashboard` and `run-native-parallel-full-dashboard`; the bounded and full dashboard steps also accept `-- --workers <n>` or `-- --worker-sweep a,b,c` plus `-- --paths <files-or-dirs-or-tar-archives>` for external corpora and include per-mode/worker total throughput summaries. The file corpus report/dashboard emits per-file ratio plus encode/decode MiB/s for Vort fastest/fast/best deflate and expands directory inputs recursively, tar archives via the system `tar`, and discoverable standard corpora via `run-file-corpus-standard-dashboard` (`-- --limit n` bounds rows for smoke runs); `run-zstd-compare` emits zstd size beside Vort best/fixed size; `run-standard-corpus-report` compares Vort, gzip, zlib-ng, zlib-rs, and zstd compression and decompression timings on a bounded Silesia sample, with `-- --suite` (or the `run-standard-corpus-suite` alias) for per-file bounded Silesia automation, `-- --paths <files-or-dirs-or-tar-archives>` for arbitrary external corpora, `run-standard-corpus-dashboard` for a bounded Markdown dashboard with per-codec summary totals at `zig-out/vort-standard-corpus-dashboard.md`, `run-standard-corpus-full-dashboard` for a full-size Silesia dashboard at `zig-out/vort-standard-corpus-full-dashboard.md`, `run-standard-multi-corpus-suite` / `run-standard-multi-corpus-full-suite` plus `run-standard-multi-corpus-dashboard` / `run-standard-multi-corpus-full-dashboard` to discover local Silesia/Calgary/Canterbury/enwik-style corpora (`-- --limit n` bounds rows for smoke runs), and `-- --full` for the full local Silesia tar. Use `-Doptimize=ReleaseFast` for any performance interpretation; Debug timings are only build-smoke signals. These are still smoke reports and not a final competitor benchmark claim.
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
