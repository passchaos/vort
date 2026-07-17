# Performance evidence

Vort does not yet claim compression performance wins. This document records the
benchmark protocol and the current bootstrap benchmark surface so future claims
can be tied to reproducible evidence.

## Current local benchmark entrypoints

```sh
zig build -Doptimize=ReleaseFast ci-smoke
zig build bench-checksum -Doptimize=ReleaseFast
zig build bench-deflate-decode -Doptimize=ReleaseFast
zig build -Doptimize=ReleaseFast run-deflate-decode-stage-report
zig build -Doptimize=ReleaseFast run-deflate-decode-stage-report-dashboard
zig build -Doptimize=ReleaseFast run-deflate-decode-stage-report-csv-repeat3
zig build -Doptimize=ReleaseFast run-chunked-zlib-bench-report-dashboard
zig build -Doptimize=ReleaseFast run-chunked-zlib-bench-report-csv-repeat3
zig build run-deflate-wrapper-fuzz-corpus-dashboard
zig build run-fuzz-corpus-coverage-smoke
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
zig build -Doptimize=ReleaseFast run-native-thread-pool-full-dashboard
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
zig build -Doptimize=ReleaseFast run-file-corpus-standard-full-dashboard -- --limit 3
zig build run-zstd-compare
zig build -Doptimize=ReleaseFast run-standard-corpus-report
zig build -Doptimize=ReleaseFast run-standard-corpus-report -- --suite
zig build -Doptimize=ReleaseFast run-standard-corpus-suite
zig build -Doptimize=ReleaseFast run-standard-corpus-dashboard
zig build -Doptimize=ReleaseFast run-standard-corpus-full-dashboard
zig build -Doptimize=ReleaseFast run-standard-corpus-full-dashboard -- --paths README.md --limit 1
zig build -Doptimize=ReleaseFast run-standard-corpus-report -- --paths README.md docs/roadmap.md
zig build -Doptimize=ReleaseFast run-standard-corpus-report -- --paths ~/Work/zlib-rs/silesia-small.tar
zig build -Doptimize=ReleaseFast run-standard-corpus-report -- --full
zig build -Doptimize=ReleaseFast run-standard-multi-corpus-suite
zig build -Doptimize=ReleaseFast run-standard-multi-corpus-dashboard -- --limit 3
zig build -Doptimize=ReleaseFast run-standard-multi-corpus-full-suite
zig build -Doptimize=ReleaseFast run-rust-deflate-bench-csv-repeat3
zig build -Doptimize=ReleaseFast run-rust-deflate-encode-bench-csv-repeat3
zig build -Doptimize=ReleaseFast run-rust-deflate-benchmark-summary-repeat3
zig build -Doptimize=ReleaseFast run-standard-multi-corpus-full-dashboard
```

The checksum smoke benchmark processes a deterministic 1 MiB buffer repeatedly
through Adler-32, CRC-32 scalar, CRC-32 slice-by-4, CRC-32 slice-by-8, CRC-32 slice-by-16, CRC-32 best dispatch, CRC-32C scalar, CRC-32C slice-by-8, CRC-32C slice-by-16, and CRC-32C best dispatch paths and reports aggregate MiB/s plus selected checksum dispatch names. The deflate decode smoke benchmark repeatedly decodes representative raw/zlib/gzip fixed and dynamic samples, reports allocator-returning, exact-size allocation, and caller-buffer rows for each sample, includes fixed-Huffman literal/distance lookup fast paths, and emits dynamic-block stage rows for length parsing, literal-table construction, distance-table construction, payload decode, and total caller-buffer decode on the small dynamic sample. Huffman fast-decode evidence should be read from ReleaseFast runs because the optimized path records maximum code widths and resumes long-code fallback after the lookup width rather than replaying short widths on each miss. `run-deflate-decode-stage-report` isolates raw/zlib/gzip alloc, exact-size alloc, and caller-buffer decode overhead; its dashboard writes CSV/Markdown plus schema-checked JSON, and the JSON/Markdown artifacts carry an error-path smoke table for malformed, truncated, checksum-mismatched, and concatenated-gzip boundary inputs without changing the throughput CSV schema. `run-chunked-zlib-bench-report` compares contiguous zlib decode, legacy join-then-decode chunks, and direct chunked zlib decode on PNG-like payloads with fixed-size and tiny/empty IDAT-style chunks; use its repeat3 CSV step before accepting small chunked-reader changes. `run-deflate-wrapper-fuzz-corpus-dashboard` retains schema-checked JSON/Markdown evidence for raw/zlib/gzip wrapper fuzz corpus accept/reject and exact-error expectations, while `run-fuzz-corpus-coverage-smoke` enforces the external minimum mode/error coverage matrix. The corpus decode benchmark builds Vort raw/zlib/gzip frames for text, structured, repetitive, and deterministic binary corpora, then reports wrapper-specific decode MiB/s while verifying every round trip. The fixed encode smoke benchmark runs greedy-LZ77-backed raw fixed deflate encoding and verifies round trips. `run-level-report` reports parser/level/strategy/cost-model settings on built-in samples or provided files, including token counts, literal/match counts, matched-byte coverage, average match length, fixed bits-per-byte, and one-shot/adaptive size ratios for each level/strategy row; `run-level-report-csv` writes the same diagnostics to `zig-out/vort-level-report.csv` for dashboard indexing and regression evidence, and `run-level-report-dashboard` writes a Markdown companion at `zig-out/vort-level-report.md` with a best-raw/best-adaptive summary per case for quick human review. `run-huffman-length-report-dashboard` writes CSV/Markdown oracle evidence for fixed and generated small length-limited Huffman cases plus large DEFLATE alphabet regressions (286 literal/length, 30 distance, 19 code-length symbols) including configurable length-generation `ns/op` via `-- --iterations <n>`, so package-merge behavior and cost can be validated before and after production changes; `run-rust-deflate-benchmark-summary` also includes these Huffman oracle totals when the CSV artifact is present. `run-split-policy-report` compares one-shot vs adaptive split sizes for every compression level on built-in corpora or provided file paths; `run-split-policy-corpus-report` runs the same policy delta report over a bounded Silesia subset by default, with `-- --all` for all bounded Silesia files. `run-sidecar-verify-report` (also accepts `-- --dir <path>`, `-- --limit <n>`, `-- --keep-going`, and `-- --markdown <path>` / `-- --json <path>`), `store-sidecar-range-demo`, `vort-sidecar-blocked-best-range-demo`, `vort-sidecar-ldm-range-demo`, and file commands `encode-vort-sidecar-best-file` / `verify-vort-sidecar-index-file` / `decode-vort-sidecar-range-file` and `encode-vort-sidecar-dict-file` / `decode-vort-sidecar-auto-range-file`, and `encode-vort-sidecar-ldm-file` exercise external sidecar indexes; `run-native-range-report` verifies checksum-validated indexed range decode and accepts `-- --offset <n> --length <n>` or `-- --sweep` across store, blocked best, dictionary, self-contained/trained dictionary, indexed LDM, and blocked LDM native streams, or across provided file paths using blocked-best native streams. `run-compression-report` includes trained-dictionary stream selection metrics; `run-dictionary-report` can train on built-in samples or provided files, accepts `-- --target <bytes>`, and reports dictionary patch/native-best ratios; `run-dictionary-corpus-report` applies that dictionary report to a bounded Silesia subset, with `-- --per-file` for per-file rows, `-- --targets a,b,c` for target-size sweeps, and `run-dictionary-corpus-dashboard` for a Markdown dashboard. The native parallel benchmark compares planned, spawned-thread, fixed thread-pool, and work-queue native stream encoders on either its built-in corpus, a provided real file path plus block size/worker count, dashboard `-- --block-len <bytes>` overrides, bounded/full Silesia files via `run-native-parallel-corpus-report`, discoverable standard corpora via `run-native-parallel-multi-corpus-dashboard` / `run-native-parallel-multi-corpus-full-dashboard` (`-- --limit n` bounds rows for smoke runs), or Markdown dashboards via `run-native-parallel-dashboard` and `run-native-parallel-full-dashboard`; the bounded and full dashboard steps also accept `-- --workers <n>` or `-- --worker-sweep a,b,c` plus `-- --paths <files-or-dirs-or-tar-archives>` for external corpora and include per-mode/worker total throughput summaries. `run-native-thread-pool-full-dashboard` filters the same full standard-corpus automation to the production thread-pool path for dedicated evidence. The file corpus report/dashboard emits per-file ratio plus encode/decode MiB/s for Vort fastest/fast/best deflate and expands directory inputs recursively, tar archives via the system `tar`, and discoverable standard corpora via `run-file-corpus-standard-dashboard` or full per-file reads across discovered standard corpora via `run-file-corpus-standard-full-dashboard` (`-- --limit n` bounds rows for smoke runs); `run-zstd-compare` emits zstd size beside Vort best/fixed size; `run-standard-corpus-report` compares Vort, gzip, zlib-ng, zlib-rs, and zstd compression and decompression timings on a bounded Silesia sample, accepts `-- --progress` for per-case stderr progress during long dashboard runs, with `-- --suite` (or the `run-standard-corpus-suite` alias) for per-file bounded Silesia automation, `-- --paths <files-or-dirs-or-tar-archives>` for arbitrary external corpora, `run-standard-corpus-dashboard` for a bounded Markdown dashboard with per-codec summary totals at `zig-out/vort-standard-corpus-dashboard.md`, `run-standard-corpus-full-dashboard` for a full-size Silesia dashboard (also accepts forwarded `-- --paths`/`-- --limit`) at `zig-out/vort-standard-corpus-full-dashboard.md`, `run-standard-multi-corpus-suite` / `run-standard-multi-corpus-full-suite` plus `run-standard-multi-corpus-dashboard` / `run-standard-multi-corpus-full-dashboard` to discover local Silesia/Calgary/Canterbury/enwik-style corpora (`-- --limit n` bounds rows for smoke runs), and `-- --full` for the full local Silesia tar. Use `-Doptimize=ReleaseFast` for any performance interpretation; Debug timings are only build-smoke signals. These are still smoke reports and not a final competitor benchmark claim.
Rust deflate decode and encode benchmark scripts accept `--repeat <n>` when
invoked directly; the CSV row records the repeat count and median elapsed time for each
engine/case/mode. The Zig build steps keep `--repeat 1` behavior for smoke speed,
while investigation runs should use repeats such as `--repeat 3` before accepting
small performance deltas.
`run-deflate-decode-stage-report` also accepts forwarded `-- --repeat <n>` and
keeps the median-ish sample by aggregate elapsed score across raw/zlib/gzip
alloc, exact-size, and caller-buffer rows; `run-deflate-decode-stage-report-csv-repeat3`
writes `zig-out/vort-deflate-decode-stage-report-repeat3.csv` for the repeat3
summary path, and `-- --iterations <n>` can keep ad-hoc repeat probes short during
local investigations.

Current deflate tuning keeps speed and ratio goals separate by preset. The
production `.default` path remains the speed/ratio compromise used by zlib-level
6 style callers, while `.best` now spends a measured 256-candidate optimal
parser budget (custom options may request up to the 512-candidate hard cap).
Focused weak-corpus probes on bounded Silesia `mozilla`, `osdb`, and `x-ray`
showed that raising the old 16-candidate cap improves best-size output on all
three samples; 512 candidates gave a little more ratio on `mozilla` but with a
larger encode-time cliff, so 256 is the current production compromise. In the
ReleaseFast direct API probe, `.best` zlib bytes moved to `mozilla=22476`,
`osdb=51036`, and `x-ray=93063` on the 128 KiB weak-corpus samples (previous
focused baseline: `22710`, `51441`, `93184`). Decode hot-path changes should
continue to be checked with `run-rust-deflate-benchmark-summary-repeat3` because
ratio-only improvements must not hide decompression regressions.

Dynamic Huffman decode work is tracked separately from wrapper overhead. The
Huffman table now stores bit-length bucket offsets/counts for active canonical
entries, so long-code fallback after a fast-table miss scans only candidates of
the current bit width and skips per-entry bit-width checks. `FastDecoder.decodeValue`
also has a value-only fallback path, avoiding Symbol materialization for dynamic
literal/distance misses. ReleaseFast `run-deflate-decode-stage-report` remains
the quick smoke for this path; repeat3 Rust summaries should still be used before
accepting small throughput deltas because the decode microbenchmarks are noisy.
Match replay is another decode hot path: overlapping matches above the
specialized distance-1..4 cases now copy by seeding one distance window and
doubling the initialized prefix. This improves long repeated/source-like matches
without changing fixed, dynamic, zlib, or gzip wire compatibility.

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
