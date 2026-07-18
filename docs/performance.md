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
zig build run-dynamic-plan-builtins-report-csv
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
through Adler-32, CRC-32 scalar, CRC-32 slice-by-4, CRC-32 slice-by-8, CRC-32 slice-by-16, CRC-32 best dispatch, CRC-32C scalar, CRC-32C slice-by-8, CRC-32C slice-by-16, and CRC-32C best dispatch paths and reports aggregate MiB/s plus selected checksum dispatch names; it also emits per-algorithm CSV rows so zlib Adler-32 and gzip CRC-32 wrapper bottlenecks can be tracked separately from inflate throughput, and `bench-checksum-csv` writes those rows to `zig-out/vort-checksum-bench.csv`. Each iteration perturbs and restores one input byte and marks the digest as used, keeping ReleaseFast runs from folding repeated checksum calls into a constant. The deflate decode smoke benchmark repeatedly decodes representative raw/zlib/gzip fixed and dynamic samples, reports allocator-returning, exact-size allocation, and caller-buffer rows for each sample, includes fixed-Huffman literal/distance lookup fast paths, and emits dynamic-block stage rows for length parsing, literal-table construction, distance-table construction, payload decode, and total caller-buffer decode on the small dynamic sample. Huffman fast-decode evidence should be read from ReleaseFast runs because the optimized path records maximum code widths and resumes long-code fallback after the lookup width rather than replaying short widths on each miss. `run-deflate-decode-stage-report` isolates raw/zlib/gzip alloc, exact-size alloc, and caller-buffer decode overhead; its dashboard writes CSV/Markdown plus schema-checked JSON, and the JSON/Markdown artifacts carry an error-path smoke table for malformed, truncated, checksum-mismatched, and concatenated-gzip boundary inputs. The timing rows now include first raw-DEFLATE block diagnostics (`raw_block_type`, consumed header bits/bytes, and dynamic HLIT/HDIST/HCLEN plus literal/distance non-zero, zero, and max-bit counts) so text-heavy decode regressions can be separated from dynamic-header shape before changing Huffman table policy. `run-deflate-huffman-lookup-bench-gate` writes and validates `zig-out/vort-deflate-huffman-lookup-bench.csv`, isolating Huffman symbol decode throughput for fixed literals, fixed distances, dynamic mixed/long-tail literal shapes, and dynamic distance shapes across the compact table decoder and FastDecoder lookup widths 5/8/9/11/12; use it before changing fast-table width selection, miss fallback, or fixed-Huffman lookup code. A follow-up dynamic literal lookup policy A/B kept max-bit 10 blocks on the existing 11-bit table after a `<=10` cutoff regressed the binary row, but moved max-bit <=9 blocks to the cheaper 9-bit table; the ReleaseFast repeat3 stage report improved caller-buffer zlib rows for text/dynamic-match/structured while preserving the max-bit-10 binary policy. `run-deflate-dynamic-decode-profile-csv` writes `zig-out/vort-deflate-dynamic-decode-profile.csv` with dynamic payload counters for literal/match counts, literal/distance fast-table hit/miss ratios, fast-table lookup coverage/size ratios, match-copy class byte ratios/dominant class, per-class extra-bit attribution, and length/distance extra-bit reads; `run-deflate-extra-bits-bench-gate` writes and validates `zig-out/vort-deflate-extra-bits-bench.csv`, isolating contiguous and chunked extra-bit reader throughput for 1/3/5/9/13-bit widths before production bitreader changes; a chunked-reader fill batching experiment was measured against that gate and rejected because chunked_64/chunked_1 regressed for most widths despite isolated gains at 13-bit chunked_64 and 3-bit chunked_1; `run-deflate-match-copy-bench-gate` writes and validates `zig-out/vort-deflate-match-copy-bench.csv`, a focused microbenchmark for current, non-overlap-first, and small-unrolled match-copy kernels across RLE, small-distance, non-overlapping, and overlapping cases; `run-deflate-dynamic-decode-profile-gate` validates the README/roadmap rows and histogram/top-symbol consistency and is included in `ci-smoke`. The current README/roadmap profile shows literal misses are effectively zero while distance fast-table misses are low single-digit percentages; it also shows high extra-bit density on text-heavy matches (about `7.92` bits per README match and `9.70` bits per roadmap match), and now includes semicolon-delimited length/distance symbol histograms, top-3 symbol summaries, and extra-bit-width read/bit histograms so those extra-bit costs can be traced to specific DEFLATE code ranges (current README top distance symbols include `12:152`, `13:105`, `20:101`, while top distance extra-bit costs are `28:949`, `20:909`, `22:790`; roadmap count leaders are `26:540`, `28:516`, `24:512`, and extra-bit cost leaders are `28:6708`, `26:6480`, `24:5632`). The remaining gap likely needs bitreader/extra-bit, table setup, and payload-loop evidence beyond simple fast-table width tweaks. The repeat3 stage report also appends `README.md` and `docs/roadmap.md` via `--builtins-plus-files`, keeping the known text-heavy weak cases visible beside the built-in smoke corpus. `run-chunked-zlib-bench-report` compares contiguous zlib decode, legacy join-then-decode chunks, and direct chunked zlib decode on PNG-like payloads with fixed-size and tiny/empty IDAT-style chunks; use its repeat3 CSV step before accepting small chunked-reader changes. The direct chunked path still uses a bounded stack join for small compressed non-stored members when that beats cursoring through thousands of tiny chunks, but the join buffer is tiered (4 KiB / 16 KiB / 64 KiB) so small PNG IDAT streams do not pay a full 64 KiB stack frame. `run-deflate-wrapper-fuzz-corpus-dashboard` retains schema-checked JSON/Markdown evidence for raw/zlib/gzip wrapper fuzz corpus accept/reject and exact-error expectations, while `run-fuzz-corpus-coverage-smoke` enforces the external minimum mode/error coverage matrix. The corpus decode benchmark builds Vort raw/zlib/gzip frames for text, structured, repetitive, and deterministic binary corpora, then reports wrapper-specific decode MiB/s while verifying every round trip. The fixed encode smoke benchmark runs greedy-LZ77-backed raw fixed deflate encoding and verifies round trips. `run-level-report` reports parser/level/strategy/cost-model settings on built-in samples or provided files, including token counts, literal/match counts, matched-byte coverage, average match length, fixed bits-per-byte, and one-shot/adaptive size ratios for each level/strategy row; `run-level-report-csv` writes the same diagnostics to `zig-out/vort-level-report.csv` for dashboard indexing and regression evidence, and `run-level-report-dashboard` writes a Markdown companion at `zig-out/vort-level-report.md` with a best-raw/best-adaptive summary per case for quick human review. `run-huffman-length-report-dashboard` writes CSV/Markdown oracle evidence for fixed and generated small length-limited Huffman cases plus large DEFLATE alphabet regressions (286 literal/length, 30 distance, 19 code-length symbols) including configurable length-generation `ns/op` via `-- --iterations <n>`, so package-merge behavior and cost can be validated before and after production changes; `run-rust-deflate-benchmark-summary` also includes these Huffman oracle totals when the CSV artifact is present. `run-dynamic-plan-builtins-report-csv` writes the same dynamic header/token diagnostics for the built-in Rust benchmark samples, including `distance-heavy` and `dynamic-match`, and records bit-boundary slack (`dynamic_bits_mod8` / `dynamic_bits_to_save_byte`) so byte-level size gaps can be investigated without changing production encoders. `run-split-policy-report` compares one-shot vs adaptive split sizes for every compression level on built-in corpora or provided file paths; `run-split-policy-corpus-report` runs the same policy delta report over a bounded Silesia subset by default, with `-- --all` for all bounded Silesia files. `run-sidecar-verify-report` (also accepts `-- --dir <path>`, `-- --limit <n>`, `-- --keep-going`, and `-- --markdown <path>` / `-- --json <path>`), `store-sidecar-range-demo`, `vort-sidecar-blocked-best-range-demo`, `vort-sidecar-ldm-range-demo`, and file commands `encode-vort-sidecar-best-file` / `verify-vort-sidecar-index-file` / `decode-vort-sidecar-range-file` and `encode-vort-sidecar-dict-file` / `decode-vort-sidecar-auto-range-file`, and `encode-vort-sidecar-ldm-file` exercise external sidecar indexes; `run-native-range-report` verifies checksum-validated indexed range decode and accepts `-- --offset <n> --length <n>` or `-- --sweep` across store, blocked best, dictionary, self-contained/trained dictionary, indexed LDM, and blocked LDM native streams, or across provided file paths using blocked-best native streams. `run-compression-report` includes trained-dictionary stream selection metrics; `run-dictionary-report` can train on built-in samples or provided files, accepts `-- --target <bytes>`, and reports dictionary patch/native-best ratios; `run-dictionary-corpus-report` applies that dictionary report to a bounded Silesia subset, with `-- --per-file` for per-file rows, `-- --targets a,b,c` for target-size sweeps, and `run-dictionary-corpus-dashboard` for a Markdown dashboard. The native parallel benchmark compares planned, spawned-thread, fixed thread-pool, and work-queue native stream encoders on either its built-in corpus, a provided real file path plus block size/worker count, dashboard `-- --block-len <bytes>` overrides, bounded/full Silesia files via `run-native-parallel-corpus-report`, discoverable standard corpora via `run-native-parallel-multi-corpus-dashboard` / `run-native-parallel-multi-corpus-full-dashboard` (`-- --limit n` bounds rows for smoke runs), or Markdown dashboards via `run-native-parallel-dashboard` and `run-native-parallel-full-dashboard`; the bounded and full dashboard steps also accept `-- --workers <n>` or `-- --worker-sweep a,b,c` plus `-- --paths <files-or-dirs-or-tar-archives>` for external corpora and include per-mode/worker total throughput summaries. `run-native-thread-pool-full-dashboard` filters the same full standard-corpus automation to the production thread-pool path for dedicated evidence. The file corpus report/dashboard emits per-file ratio plus encode/decode MiB/s for Vort fastest/fast/best deflate and expands directory inputs recursively, tar archives via the system `tar`, and discoverable standard corpora via `run-file-corpus-standard-dashboard` or full per-file reads across discovered standard corpora via `run-file-corpus-standard-full-dashboard` (`-- --limit n` bounds rows for smoke runs); `run-zstd-compare` emits zstd size beside Vort best/fixed size; `run-standard-corpus-report` compares Vort, gzip, zlib-ng, zlib-rs, and zstd compression and decompression timings on a bounded Silesia sample, accepts `-- --progress` for per-case stderr progress during long dashboard runs, with `-- --suite` (or the `run-standard-corpus-suite` alias) for per-file bounded Silesia automation, `-- --paths <files-or-dirs-or-tar-archives>` for arbitrary external corpora, `run-standard-corpus-dashboard` for a bounded Markdown dashboard with per-codec summary totals at `zig-out/vort-standard-corpus-dashboard.md`, `run-standard-corpus-full-dashboard` for a full-size Silesia dashboard (also accepts forwarded `-- --paths`/`-- --limit`) at `zig-out/vort-standard-corpus-full-dashboard.md`, `run-standard-multi-corpus-suite` / `run-standard-multi-corpus-full-suite` plus `run-standard-multi-corpus-dashboard` / `run-standard-multi-corpus-full-dashboard` to discover local Silesia/Calgary/Canterbury/enwik-style corpora (`-- --limit n` bounds rows for smoke runs), and `-- --full` for the full local Silesia tar. Use `-Doptimize=ReleaseFast` for any performance interpretation; Debug timings are only build-smoke signals. These are still smoke reports and not a final competitor benchmark claim.
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
ratio-only improvements must not hide decompression regressions. Dynamic-header
size changes should also be checked with `run-dynamic-plan-builtins-report-csv`;
Vort now RLEs the literal and distance code-length arrays as one contiguous
RFC-1951 sequence, so sparse dynamic blocks can save header bits when zero runs
cross the HLIT/HDIST boundary.

### Current Rust deflate gap snapshot

Latest local ReleaseFast `run-rust-deflate-benchmark-summary-repeat3` evidence
shows Vort is close on deflate size but still behind the broader Rust compression
ecosystem on several hot paths. Size ratios below 1.0 are smaller than the best
Rust row, while throughput ratios above 1.0 are faster:

| metric | geomean ratio | weakest case | next focus |
| --- | ---: | --- | --- |
| `zlib encode default size / best Rust` | `0.999` | `distance-heavy 1.027` | default match parsing / cost model |
| `zlib encode best size / best Rust` | `0.989` | `dynamic-match 1.008` | dynamic header/token byte-boundary gap |
| `raw encode default size / best Rust` | `0.999` | `distance-heavy 1.029` | default match parsing / cost model |
| `raw encode best size / best Rust` | `0.989` | `dynamic-match 1.008` | dynamic header/token byte-boundary gap |
| `zlib decode into / best Rust` | `1.128` | `readme 0.362` | readme/roadmap text-heavy dynamic decode |
| `raw decode into / miniz_oxide` | `1.676` | `readme 0.431` | readme/roadmap text-heavy dynamic decode |
| `zlib decode alloc / best Rust` | `0.682` | `stored-binary 0.272` | stored/binary allocation and wrapper path |
| `raw decode alloc / miniz_oxide` | `0.897` | `binary 0.267` | binary allocation/exact-size path |


The same repeat3 run now emits decode-stage rows for `README.md` and
`docs/roadmap.md`: in the current sample `README.md` reports raw/zlib/gzip
caller-buffer decode at about `497.76` / `537.32` / `448.09` MiB/s, with a
`579`-bit dynamic header (`HLIT/HDIST/HCLEN=284/29/13`, literal
`112/172/12`, distance `28/1/11`). `docs/roadmap.md` reports about `378.09` /
`374.97` / `324.40` MiB/s, with a `567`-bit dynamic header
(`HLIT/HDIST/HCLEN=279/30/15`, literal `102/177/13`, distance `27/3/12`).
These rows should be used to separate text-heavy dynamic payload cost from
wrapper and allocation overhead before changing Huffman table policies again.

This is not a final ecosystem claim: Rust's compression stack still has broader
zstd/brotli/lz4 coverage, mature fuzzing, platform dispatch, and production
usage. Treat this table as the current deflate-focused gap ledger and update it
after meaningful codec or benchmark changes.

Dynamic Huffman decode work is tracked separately from wrapper overhead. `BufferedBitReader.readBits` and the chunked reader now consume via staged advance after `peekBitsPadded`, avoiding a second no-op fill on every length/distance extra-bit read; a targeted ReleaseFast `run-deflate-decode-stage-report -- --repeat 5 --iterations 200 README.md docs/roadmap.md` probe showed README caller-buffer rows around raw/zlib/gzip `583.47` / `591.37` / `452.22` MiB/s and roadmap `414.27` / `408.57` / `355.41` MiB/s after this change, though full repeat3 Rust summaries remain noisy and should still be used before claiming broad wins. A follow-up experiment that added reader `hasStagedBits` and used it in Huffman fast-hit checks was reverted because the same targeted probe was mixed to negative: README raw/zlib/gzip caller-buffer rows were about `528.80` / `533.43` / `468.85` MiB/s versus the restored baseline `575.38` / `544.94` / `492.31`, while roadmap was only marginally mixed (`417.34` / `398.00` / `363.51` versus `409.90` / `406.48` / `336.61`). Keep full `hasBits` in Huffman fast-hit validation unless a future branch can prove a robust win. Keep the generic length/distance extra-bit `readBits` path as well: a narrower `readBitsStaged` experiment for extra bits was reverted because the same targeted probe was again mixed, with README raw/zlib/gzip caller-buffer rows around `569.12` / `577.16` / `312.49` MiB/s versus restored baseline `600.98` / `580.87` / `497.26`, while roadmap was only marginally mixed (`421.49` / `412.18` / `360.67` versus `412.73` / `408.42` / `356.00`). A follow-up unchecked length/distance helper experiment, used only after Huffman had already constrained symbol ranges, was also reverted: README raw/zlib/gzip caller-buffer rows were about `523.28` / `510.36` / `443.50` MiB/s versus baseline `578.45` / `577.80` / `488.84`, while roadmap was essentially mixed (`412.64` / `405.77` / `353.73` versus `411.27` / `407.00` / `317.83`). PNG streaming zlib row decode now batches pending DEFLATE matches into scanline buffers instead of emitting every match byte through `readInflatedByteOrEnd`; it also batches 64+ byte Adler updates through the vectorized Adler helper. `run-png-streaming-zlib-bench-report-csv-repeat3` tracks contiguous/chunked scanline throughput on RLE, small-distance, repeated-row dynamic, and fixed payloads; the local ReleaseFast smoke after this change reported about `978.81`/`943.63` MiB/s for dynamic RLE contiguous/chunked and about `1018.76`/`1037.96` MiB/s for small-distance rows.  A profile-backed FastDecoder init experiment was also reverted/kept out of production: a `max_bits > lookup_bits` guard and a broader lookup-coverage prepass avoided duplicate sparse-table fills in theory but produced mixed repeat3 decode-stage results, including slower README/gzip and text/raw rows in local probes. The lookup coverage fields remain in the profile so the next table-setup change can target actually sparse cases rather than guessing. The same profile now splits match bytes into RLE, small-distance, non-overlapping memcpy, and overlapping replay classes. The latest local profile shows README/roadmap matches are dominated by non-overlapping copies (about `97.68%` / `99.77%` of match bytes), while synthetic text/dynamic-match fixtures are almost entirely overlapping replay and binary is non-overlapping. That means future match-copy and extra-bit optimizations should be corpus-specific instead of assuming one replay style dominates all dynamic blocks; per-class extra-bit fields now show whether those reads belong to the non-overlap or overlap side of the payload loop. Two narrow non-overlap copy A/Bs were measured and rejected: manual small-length copy improved README in one run but regressed roadmap and dynamic-match, while moving the non-overlap branch ahead of small-distance copy badly hurt README raw decode and did not provide a robust roadmap win. A distance-code formula experiment, replacing the distance table lookup for symbols >= 4, was also rejected: synthetic text/dynamic-match/binary improved in one repeat3 probe, but README raw/zlib/gzip decode regressed sharply and roadmap zlib regressed. Keep the table-based distance decode until a corpus-safe variant is found. The
Huffman table now stores bit-length bucket offsets/counts for active canonical
entries, so long-code fallback after a fast-table miss scans only candidates of
the current bit width and skips per-entry bit-width checks. `FastDecoder.decodeValue`
also has a value-only fallback path, avoiding Symbol materialization for dynamic
literal/distance misses, and fast decode now advances through a staged-bit helper
after peeking so buffered/chunked readers do not re-enter fill logic for every
symbol. A broader 12-bit dynamic literal table threshold (`HLIT >= 260`,
`max_bits >= 11`) was tested against the repeat3 Rust decode benchmark and
reverted because it did not improve the readme/roadmap weak cases and slowed some
dynamic-match rows; keep the current denser-table threshold until a targeted
payload-level benchmark shows a clear win. An allocating-inflate literal append
experiment that replaced `ArrayList.append` with an ensure-then-assume-capacity
helper was also tested with ReleaseFast `run-deflate-decode-stage-report -- --repeat 5 --iterations 200 README.md docs/roadmap.md` and reverted: README raw/zlib/gzip caller-buffer rows moved from about `520.13` / `523.63` / `453.92` MiB/s before to `494.57` / `506.00` / `427.39` MiB/s after, while roadmap rows were essentially noise (`378.52` / `372.07` / `329.48` before versus `374.84` / `369.81` / `327.73` after). Avoid repeating that micro-optimization unless allocator or ArrayList semantics change. ReleaseFast `run-deflate-decode-stage-report` remains
the quick smoke for this path; repeat3 Rust summaries should still be used before
accepting small throughput deltas because the decode microbenchmarks are noisy.
Match replay is another decode hot path: overlapping matches above the
specialized distance-1..4 cases now copy by seeding one distance window and
doubling the initialized prefix. Allocating inflate paths reuse the same doubling
copy after reserving the match span, so long no-dictionary matches avoid
byte-at-a-time ArrayList appends. This improves repeated/source-like matches
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
