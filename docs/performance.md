# Performance evidence

Vort does not yet claim compression performance wins. This document records the
benchmark protocol and the current bootstrap benchmark surface so future claims
can be tied to reproducible evidence.

Recent decoder evidence: [Zstd sequence field grouping](performance/zstd-sequence-fields.md)
records a bounded all-FSE reader optimization, generic-reference safety checks,
and paired comparison with libzstd 1.5.7 on Apple M1 Pro.
[Zstd x86-64 full raw-block copying](performance/zstd-raw-copy-x86.md)
records the ERMSB-gated 128 KiB path and paired comparison with the local
libzstd 1.6.0-dev checkout on Intel Comet Lake.
[Zstd reusable small-frame caching](performance/zstd-small-reusable-cache-x86.md)
records combined Huffman tree/lookup reuse, a fully cached terminal-block path,
and paired one-shot/reusable comparisons with libzstd 1.6.0-dev.
[Zstd small one-shot table construction](performance/zstd-small-oneshot-tables-x86.md)
records bounded Huffman/offset-FSE scratch, direct small-frame parsing, and an
independent paired comparison against the preceding reusable-cache commit.
[Zstd borrowed small-frame metadata](performance/zstd-small-borrowed-section-x86.md)
records removal of the redundant owned-tree section clear and its isolated
one-shot gain against the immediately preceding small-table implementation.
[Zstd direct small-frame Huffman lookup](performance/zstd-small-direct-lookup-x86.md)
records tree-free lookup construction, checked lookup-only tails, and the
remaining measured gap to libzstd on the bounded one-shot target.
[Zstd large-JSON overlap-tail copy](performance/zstd-large-json-overlap-tail-x86.md)
records an exact 71-byte match kernel for the compact split-Huffman pair path
and its complete-frame and prepared-stage measurements.
[Zstd x86-64 dense FSE construction](performance/zstd-dense-fse-x86.md)
records the dense-gap mapped-table builder on x86-64, including threshold and
write-width rejection experiments.
[Zstd raw-literal all-FSE execution](performance/zstd-raw-fse-executor.md)
records grouped bit reads, bounded match-copy specialization, and the resulting
25-file mixed-corpus comparison.
[Brotli external literal lookup](performance/brotli-external-literal-lookup.md)
records the dense-tree fallback optimization and fixed-CPU measurements on an
anonymized private corpus.
[Brotli zero-insert fast path](performance/brotli-zero-insert-fast-path.md)
records the command-loop shortcut, cross-quality controls, and compatibility
coverage.
[Brotli bounded short match copy](performance/brotli-bounded-short-copy.md)
records the meta-block-bounded 16-byte move, its direct boundary oracle, and
paired comparison against the preceding decoder.
[Brotli full-tier ordered match copy](performance/brotli-full-tier-copy64-x86.md)
records the x86-64-only 33--64-byte extension for the 129--256-literal-tree
executor, the rejected global route, and paired whole-frame measurements.
[Brotli zero-insert branch layout](performance/brotli-zero-insert-branch-x86.md)
records the measured command distribution, hot-branch layout reduction, two
rejected state/distance layouts, and paired full/middle-tier measurements.
[Brotli identity dictionary borrowing](performance/brotli-static-dictionary-borrow.md)
records the zero-copy identity transform, full transform equivalence coverage,
and paired dictionary-heavy decode measurements.
[Brotli adaptive command lookup](performance/brotli-command-tail-lookup.md)
records the capacity-checked 10-bit command table, atomic nine-bit fallback,
fused zero-extra command metadata, sampling evidence, and paired decode
measurements.
[Brotli contiguous auxiliary lookups](performance/brotli-contiguous-auxiliary-lookups.md)
records cache-dense command/distance root planes, exact short dictionary
copies, rejected follow-ups, and paired Apple M1 Pro measurements.
[Brotli large single-tree executor](performance/brotli-single-tree-executor.md)
records the structure-gated q1 fast path and real source/document comparisons.
[Zstd wide-Huffman WASM portability](performance/zstd-wasm-portability.md)
records the target-selected aligned wrapper, standalone wasm32 gate, identical
native machine-code section, and fixed-CPU A/B evidence.

## Current local benchmark entrypoints

```sh
zig build -Doptimize=ReleaseFast ci-smoke
zig build bench-checksum -Doptimize=ReleaseFast
zig build -Doptimize=ReleaseFast run-snappy-report-gate
zig build -Doptimize=ReleaseFast run-snappy-reference-bench-gate
zig build -Doptimize=ReleaseFast run-lz4-reference-bench-gate
zig build -Doptimize=ReleaseFast run-br-planned-encode-bench-gate
zig build -Doptimize=ReleaseFast run-br-reference-bench-gate
zig build -Doptimize=ReleaseFast run-br-reference-bench -- --input path/to/file --name corpus_case --quality 5 --iterations 10
zig build -Doptimize=ReleaseFast run-br-reference-bench -- --input path/to/file --encoded-input path/to/file.br --name corpus_case --iterations 10 --vort-only
zig build -Doptimize=ReleaseFast run-zstd-reference-bench-gate
zig build -Doptimize=ReleaseFast run-zstd-reference-bench -- --libzstd /path/to/libzstd
zig build -Doptimize=ReleaseFast run-zstd-reference-bench -- --input path/to/file --name corpus_case --level 1
zig build -Doptimize=ReleaseFast run-zstd-reference-bench -- --input path/to/file --encoded-input path/to/file.zst --name corpus_case --iterations 300
zig build -Doptimize=ReleaseFast run-zstd-decode-profile -- --libzstd /path/to/libzstd
zig build -Doptimize=ReleaseFast run-zstd-decode-profile -- --input path/to/file --name corpus_case --level 1
zig build -Doptimize=ReleaseFast run-zstd-decode-profile -- --input path/to/file --encoded-input path/to/file.zst --name corpus_case --iterations 300
zig build -Doptimize=ReleaseFast run-zstd-encode-bench-gate
zig build -Doptimize=ReleaseFast run-zstd-encode-bench-path-smoke
zig build -Doptimize=ReleaseFast run-zstd-encode-bench -- --level 1 --limit 131072 --path README.md --path src/zstd.zig
zig build -Doptimize=ReleaseFast run-zstd-level-schedule-bench-gate
zig build -Doptimize=ReleaseFast run-zstd-native-encode-stage-bench-gate
zig build -Doptimize=ReleaseFast run-zstd-native-encode-stage-bench-path-smoke
zig build -Doptimize=ReleaseFast run-zstd-native-encode-stage-bench -- --level 1 --case json --candidate primary --stage rep_beam_single --iterations 20 --rounds 9 --warmup 2
zig build -Doptimize=ReleaseFast run-zstd-native-encode-stage-bench -- --level 1 --candidate primary --limit 131072 --path src/zstd.zig
zig build run-zstd-compat-probe
zig build -Doptimize=ReleaseFast run-zstd-decodecorpus-gate -j1
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
zig build -Doptimize=ReleaseFast run-native-tier-range-bench-gate
zig build -Doptimize=ReleaseFast run-native-tier-range-files-bench-gate
zig build -Doptimize=ReleaseFast run-native-tier-range-corpus-bench-gate
zig build run-native-tier-range-corpus-report-smoke
zig build run-native-tier-range-bench-gate-negative-smoke
zig build run-dictionary-report -- README.md docs/roadmap.md
zig build run-dictionary-report -- --target 512 README.md docs/roadmap.md
zig build -Doptimize=ReleaseFast run-dictionary-decode-bench-gate
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
zig build run-zstd-compare-gate
zig build run-zstd-compare-block-sweep-gate
zig build run-zstd-compare-block-sweep-releasefast-gate
zig build run-zstd-compare-standard-gate
zig build run-zstd-compare-standard-releasefast-gate
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
taskset -c 8 zig build run-rust-deflate-bench-gate
taskset -c 8 zig build run-rust-deflate-encode-bench-gate
zig build -Doptimize=ReleaseFast run-rust-deflate-benchmark-summary-repeat3
zig build -Doptimize=ReleaseFast run-standard-multi-corpus-full-dashboard
zig build run-competitor-gap-report-smoke
zig build run-rust-deflate-bench-gate-smoke
taskset -c 8 zig build -j1 run-competitor-gap-report
```

`--encoded-input` lets the Brotli reference benchmark and both Zstd decode
benchmarks reuse a frozen frame instead of recompressing the file supplied by
`--input`. Each benchmark still checks the Vort output against the original
input before timing; reference runs additionally check the corresponding
system library. This keeps independent-binary A/B runs on identical bytes
while avoiding setup work outside the measured decoder.

`run-br-planned-encode-bench` accepts `-- --case <name>` to isolate one of
its built-in Brotli rows, for example `dictionary`, `mixed`, or `source32k`.
Use the filter for profiling and fixed-CPU interleaved A/B runs; omit it for
the formal eight-row `run-br-planned-encode-bench-gate`. An unknown case is an
error rather than a silently empty benchmark.
The ratio encoder's shared RFC dictionary index contains the same 31,704
deduplicated identity/uppercase canonical spellings as upstream Brotli's
static lookup table. Its exact persistent size is 192,354 bytes; the Node
compatibility gate pins that value and independently decodes the dictionary,
mixed, uppercase, and unmatched planned streams.

`run-zstd-encode-bench` accepts repeatable `--path <file>` inputs and a shared
`--limit <bytes>` prefix limit. File rows use stable `fileN_basename` names and
the same Vort/libzstd bidirectional decode check, level filter, and interleaved
timing loop as the built-in matrix. Omit `--path` for the formal five-case,
four-level gate; use file mode for fixed-CPU A/B checks on real JSON, source,
configuration, and corpus files without maintaining a separate benchmark.
The native stage benchmark accepts the same `--path`/`--limit` pair and records
`input_bytes` in every row. This is the preferred way to isolate match-family
costs on real 128 KiB prefixes before running a complete frame A/B.
The Zstd encode, decode-reference, decode-profile, candidate-stage, and
level-schedule CSVs, plus the LZ4, Snappy, and Brotli reference benchmarks used
by the unified competitor report, record the exact input SHA-256, `ReleaseFast`
mode, Zig version, target triple and CPU, host CPU model, process CPU affinity,
benchmark thread count, codec thread policy, executable SHA-256, and
percent-encoded command line. Their gates reject missing or inconsistent
provenance and verify the recorded executable digest against the exact artifact
supplied by the build. These formal benchmark executables are pinned to
ReleaseFast even when the outer build uses another optimization mode. The
shared provenance gate has a 23-check positive/negative smoke covering artifact
tampering, malformed hashes, invalid or overlapping affinity ranges, thread
policy, command escaping, and cross-row consistency.

## Unified competitor gap report

`run-competitor-gap-report` reads the existing Deflate, Zstd, LZ4, Snappy, and
Brotli benchmark CSV artifacts and writes
`zig-out/vort-competitor-gap-report.md` plus
`zig-out/vort-competitor-gap-report.json`. The default build step regenerates
and gates all eight core benchmark inputs before aggregation, then uses strict
and required-provenance modes. Run it with one pinned CPU and `-j1` as shown
above so the eight benchmark producers cannot overlap. Incremental Deflate and the
standard-corpus dashboard are optional because they are not produced by the
same fast benchmark cycle; when present they are included and when absent they
remain explicit in the evidence table. An explicitly supplied input path is
always required, even without `--strict`.

The report keeps codec, operation, and profile separate. Throughput is
`Vort MiB/s / reference MiB/s` (higher is better), while compressed size is
`Vort bytes / reference bytes` (lower is better). Group status checks both the
geometric mean and the weakest case: a strong mean with a material weak case is
`mixed`, not `ahead`. Priority is the largest aggregate or weakest-case gap
inside one group; there is deliberately no cross-format total score. Deflate
`best-speed` and `best-size` rows choose Pareto endpoints per case, so they are
diagnostic rather than stable production configurations and are excluded from
the action ranking and global weakest-case callouts. Standard-corpus Vort zlib
rows are also split into explicit per-reference groups whose names identify
whether the competitor artifact uses zlib, gzip, or zstd framing; those wire
formats are never collapsed into a single best-reference aggregate.

The schema-v3 JSON records the source paths and row counts, reference versions,
git and report-environment metadata, per-input SHA-256/mtime/row/metric evidence,
normalized rows, group summaries, coverage flags, and missing inputs. Existing
source CSVs that predate the provenance columns remain accepted, but the report
counts which loaded sources carry complete benchmark metadata and sets
`benchmark_environment_recorded` only when every loaded source does and their
compile/runtime environment tuple agrees. The formal build passes
`--require-provenance`, so a missing source record or cross-source target, CPU,
affinity, or benchmark-thread mismatch fails instead of producing a nominally
complete report. Provenance
columns must be complete and constant within one CSV; ReleaseFast mode, valid
input/executable hashes, positive affinity metadata, and CSV-safe commands are
validated instead of inferred from the aggregation machine. Real-corpus
coverage becomes true only when usable standard-corpus comparisons were loaded;
peak-memory comparison remains false until a common cross-library memory harness
exists.
The current generated core report has complete, mutually consistent provenance
for all eight loaded sources, and all 274 normalized metrics retain per-input
hashes. Deflate encode/decode use provenance v2 because their Python drivers
coordinate more than one executable. Their canonical percent-encoded artifact
manifest records and hashes the Python driver/interpreter/shared modules, the
ReleaseFast Vort helper, generated Rust runner source and release executable,
Cargo/rustc/Python versions and Rust host/flags, plus the full local fdeflate
and miniz_oxide source-tree digests, commits, and dirty state. Dedicated gates
recompute all ten artifact records from disk, verify the full 210/120-row engine
matrices and exact input hashes, and recompute elapsed seconds, throughput, and
encode ratio from exact nanoseconds and byte counts.
The Deflate decode harness uses `std.heap.c_allocator` for Vort's timed
allocator-returning rows, matching the process allocator used by the Rust
`Vec` baselines on this Linux host; caller-buffer rows allocate their reusable
scratch outside the timed loop. The v2 manifest records both allocator policies
so allocator-inclusive numbers cannot be mistaken for allocator-independent
codec throughput. Use the caller-buffer profiles for core decode comparisons,
and alloc/exact profiles when the application-facing allocation cost matters.
`run-competitor-gap-report-smoke` uses temporary synthetic CSVs to test
aggregation, dynamic reference selection, mixed-status rules, independent and
wire-explicit standard-corpus measurements, strict and explicit-path behavior,
duplicate rows, malformed schemas, and invalid numeric values without running
expensive benchmarks. Its v3 coverage includes provenance v1/v2, canonical
artifact manifests, artifact-set hashes, and cross-source environment mismatch.
The separate Deflate matrix smoke validates engine/case completeness, duplicate
rows, exact input hashes, repeat counts, and recomputed elapsed-time, throughput,
and ratio fields without running the codecs.

The internal `vort-zlib-encode-bench` executable accepts plain zlib modes plus
`raw-` and `gzip-` wrapper prefixes (for example `fastest`, `raw-fastest`, and
`gzip-fastest`). This keeps raw parser/writer cost, Adler-32 wrapping, and
CRC-32 wrapping measurable with one identical-input harness. A fixed-CPU-8
ReleaseFast README profile of `gzip-fastest` after the one-shot histogram and
reserved-reservoir work attributed about 59.82% to hash planning, 12.07% to
dynamic output, 7.10% to match extension, 2.51% to dynamic planning, and only
0.33% to CRC-32. Gzip checksum fusion is therefore not the next encoder
bottleneck on this workload.

The checksum smoke benchmark processes a deterministic 1 MiB buffer repeatedly
through Adler-32, CRC-32 scalar, CRC-32 slice-by-4, CRC-32 slice-by-8, CRC-32 slice-by-16, CRC-32 slice-by-32, CRC-32 slice-by-32 segmented update rows for 64/256/1024/4096-byte batches, benchmark-only decoded-span threshold rows for 256/1024/2048/4096-byte gzip CRC batching prototypes plus a selective 4096-byte accumulator row, CRC-32 best dispatch, CRC-32C scalar, CRC-32C slice-by-8, CRC-32C slice-by-16, CRC-32C slice-by-32, and CRC-32C best dispatch paths and reports aggregate MiB/s plus selected checksum dispatch names; it also emits per-algorithm CSV rows so zlib Adler-32 and gzip CRC-32 wrapper bottlenecks can be tracked separately from inflate throughput, and `bench-checksum-csv` writes those rows to `zig-out/vort-checksum-bench.csv`, and `run-checksum-bench-gate` schema-checks the CSV plus the matching digest mixes across scalar/slice/best rows. Each iteration perturbs and restores one input byte and marks the digest as used, keeping ReleaseFast runs from folding repeated checksum calls into a constant. The deflate decode smoke benchmark repeatedly decodes representative raw/zlib/gzip fixed and dynamic samples, reports allocator-returning, exact-size allocation, and caller-buffer rows for each sample, includes fixed-Huffman literal/distance lookup fast paths, adds multi-member stored zlib/gzip rows for concatenation wrapper overhead, and emits dynamic-block stage rows for length parsing, literal-table construction, distance-table construction, payload decode, and total caller-buffer decode on the small dynamic sample. Huffman fast-decode evidence should be read from ReleaseFast runs because the optimized path records maximum code widths and resumes long-code fallback after the lookup width rather than replaying short widths on each miss. `run-deflate-decode-stage-report` isolates raw/zlib/gzip alloc, exact-size alloc, and caller-buffer decode overhead; its dashboard writes CSV/Markdown plus schema-checked JSON, and the JSON/Markdown artifacts carry an error-path smoke table for malformed, truncated, checksum-mismatched, and concatenated-gzip boundary inputs. The timing rows now include first raw-DEFLATE block diagnostics (`raw_block_type`, consumed header bits/bytes, and dynamic HLIT/HDIST/HCLEN plus literal/distance non-zero, zero, and max-bit counts) so text-heavy decode regressions can be separated from dynamic-header shape before changing Huffman table policy. `run-deflate-huffman-build-bench-gate` writes and validates `zig-out/vort-deflate-huffman-build-bench.csv`, isolating HuffmanTable and FastDecoder construction cost for literal, distance, and code-length alphabets before table setup changes; FastDecoder initialization now uses lookupCoverage to preserve the no-memset path for fully-covered tables while avoiding the old double-fill work for partial dynamic tables; `run-deflate-huffman-lookup-bench-gate` writes and validates `zig-out/vort-deflate-huffman-lookup-bench.csv`, isolating Huffman symbol decode throughput for fixed literals, fixed distances, code-length symbols, dynamic mixed/long-tail literal shapes, and dynamic distance shapes across the compact table decoder and FastDecoder lookup widths 5/8/9/11/12; use it before changing fast-table width selection, miss fallback, or fixed-Huffman lookup code. `run-deflate-chunked-huffman-bench-gate` adds the same Huffman decode shapes over buffered, 4 KiB, 64-byte, and 1-byte chunked readers for fixed literals and dynamic literal fast tables, plus coalesced 4 KiB/64-byte/1-byte rows that pre-join the same chunks into a contiguous buffer before timing `BufferedBitReader`, joined 4 KiB/64-byte/1-byte rows that include the per-iteration copy cost, `windowed1024_*` / `windowed4096_*` prototype readers that refill 1 KiB or 4 KiB staging windows from chunks, and `span_*` prototype readers that keep a current chunk slice/local offset and feed the bit buffer directly from that span. Together these expose the combined `hasBits`/peek/advance reader cost that plain Huffman lookup rows hide and bracket bounded-refill/coalescing designs before changing production decode; the first `windowed1024_*` and `windowed4096_*` smokes are intentionally evidence-only because their naive per-byte bit staging did not reliably beat the current chunked reader, despite larger windows sometimes helping isolated rows; the `span_*` rows are also benchmark-only but are a stronger production-candidate signal because per-chunk span/local-offset feeding is much closer to joined/coalesced throughput on dynamic rows. A direct production A/B that added a `staged_local` offset to `ChunkedBitReader.fill`, trying to transfer the span idea into the existing absolute-offset reader, was rejected: chunked Huffman was mixed and `run-chunked-zlib-bench-report -- --repeat 1 --iterations 800` against `921c01f` showed median direct ratios around `0.846x` for `png-rgb8-literal-large-4k`, `0.852x` for `png-rgb8-match-large-4k`, and `0.978x` for the stored-direct row. The benchmark-only span result therefore points to a deeper reader-shape rewrite, not a small staged-local patch. A follow-up isolated `ChunkedSpanBitReader` production candidate, wired only into chunked zlib direct decode, kept the existing public reader intact while using a per-chunk slice/local-offset state internally; ReleaseFast A/B against `59edd4c` on `run-chunked-zlib-bench-report -- --repeat 1 --iterations 800` improved true chunked-reader direct throughput by about `1.171x` on `png-rgb8-literal-large-4k` and `1.167x` on `png-rgb8-match-large-4k`, while the stored-direct row stayed roughly neutral (`0.997x`). The same span reader now backs PNG streaming chunked zlib decode as well; ReleaseFast A/B against `b51d9d8` on `run-png-streaming-zlib-bench-report -- --repeat 3 --iterations 1000` improved chunked rows by about `1.09x` for dynamic RLE, `1.01x` for row-repeat dynamic, and `1.05x` for row-repeat fixed, with small-distance dynamic mixed/slightly negative in the short median probe. PNG small-distance pending matches now use a seed-and-doubling copy for length >=16 instead of repeating 2/3/4-byte stores; ReleaseFast A/B on the same PNG streaming benchmark improved `png-stream-small-distance-dynamic` chunked throughput by about `1.107x` while RLE and row-repeat rows stayed roughly neutral. PNG streaming pending matches with overlapping distances greater than four now also seed one distance window from the history ring and then use the destination-row doubling copy; ReleaseFast A/B on `run-png-streaming-zlib-bench-report -- --repeat 3 --iterations 800` moved row-repeat dynamic/fixed rows from about `153.33` / `154.61` MiB/s to about `1208.80` / `1224.76` MiB/s for contiguous decode and from about `153.63` / `152.97` MiB/s to about `1174.51` / `1177.64` MiB/s for chunked decode. Lowering the threshold to 8 bytes was tested and rejected after the PNG streaming smoke showed no clear small-distance gain and a row-repeat dynamic regression, so the 16-byte cutoff remains. The chunked zlib allocating unknown-size path now uses the same span reader, preserving the existing allocation-count tests while avoiding the old chunked bit reader for API callers that request owned output from chunks. ZlibDecoder direct chunked reset paths now reuse the already-computed chunk total when installing frame length, avoiding a second chunk-length scan after successful direct decode. A follow-up attempt to localize `ChunkedSpanBitReader.fill` state into stack variables was rejected: zlib direct rows were mixed and PNG streaming chunked rows regressed sharply in the short A/B, so the simpler field-based span fill remains in production. Generic FastDecoder paths now check the reader's staged reservoir after the mandatory padded peek instead of recomputing total remaining bits on the buffered/chunked hot path; the fixed Huffman specialized helpers keep the older `hasBits` check after A/B exposed noisy fixed-code rows. The local ReleaseFast A/B of `vort-deflate-chunked-huffman-bench --iterations 256` showed about `1.025x` median geomean overall and about `1.039x` on dynamic rows, with the clearest wins on 4 KiB/64-byte chunk rows while 1-byte rows remain noisy and still need a broader direct-reader redesign. Chunked zlib/PNG paths that already computed total compressed length now initialize `ChunkedBitReader` with that known total to avoid a second chunk-length scan; the focused true `chunked-reader` row A/B on `png-rgb8-literal-large-4k` measured about `1.021x` median and `1.033x` geomean on direct throughput. The zlib chunk footer validator now uses the known total length to read the common final Adler-32 from the tail chunks instead of scanning forward from chunk zero; a focused A/B against `b1a9d3d` on the same true chunked-reader row measured about `1.038x` median and `1.069x` geomean direct throughput, while split-footer tests cover empty chunks and multi-chunk footers. A later attempt to reuse that first deflate block-type probe to skip the stored-direct attempt on non-stored large streams was rejected: short ReleaseFast A/B against `8baae19` was mixed to negative, with median direct ratios around `0.979x` for the literal true-chunked row, `0.984x` for the match-heavy true-chunked row, and `0.984x` for the stored-direct row. A literal-only dynamic decode experiment that skipped distance-table construction when `dynamic_distance_max_bits == 0` was also rejected: a ReleaseFast same-machine `run-deflate-decode-stage-report -- --repeat 7 --iterations 1000` A/B on the `dynamic-literal-only` row improved some exact-size rows (`raw_exact` about `1.040x`, `zlib_exact` about `1.038x`, `zlib_into` about `1.007x`) but regressed caller-buffer rows that matter for decompression throughput (`raw_into` about `0.891x`, `gzip_into` about `0.875x`, raw alloc about `0.953x`). Keep the normal distance-table setup path until a variant can prove broad caller-buffer wins. A follow-up dynamic literal lookup policy A/B kept max-bit 10 blocks on the existing 11-bit table after a `<=10` cutoff regressed the binary row, but moved max-bit <=9 blocks to the cheaper 9-bit table; the ReleaseFast repeat3 stage report improved caller-buffer zlib rows for text/dynamic-match/structured while preserving the max-bit-10 binary policy. `run-deflate-dynamic-decode-profile-csv` writes `zig-out/vort-deflate-dynamic-decode-profile.csv` with dynamic payload counters for literal/match counts, literal/distance fast-table hit/miss ratios, fast-table lookup coverage/size ratios, match-copy class byte ratios/dominant class, per-class extra-bit attribution, and length/distance extra-bit reads; `run-deflate-extra-bits-bench-gate` writes and validates `zig-out/vort-deflate-extra-bits-bench.csv`, isolating contiguous, legacy chunked, and span-reader extra-bit throughput for 1/3/5/9/13-bit widths plus README/roadmap mixed distance-extra distributions across 4 KiB, 64-byte, and 1-byte chunks before production bitreader changes; the first mixed rows show span readers at about `227.61` / `241.66` Mreads/s on 4 KiB chunks for README/roadmap distributions versus legacy chunked at `145.07` / `176.11` Mreads/s, so the true text-heavy extra-bit shape is now visible beside single-width smokes. The gate now also carries README/roadmap mixed length-extra rows derived from profile width histograms (`1026;216;191;125;20;2` and `7435;1982;709;291;31;0`), with `current` and `staged` kernels, median-of-3 timing, checksum-equivalence validation, and staged/current ratio summaries so length extra-bit reader experiments stay measurable after the staged length-extra production candidate was rejected on end-to-end evidence. The same gate now has distance-symbol-plus-extra rows for README/roadmap distributions; local ReleaseFast 4 KiB span rows were about `207.36` / `204.05` Mreads/s versus legacy chunked `144.98` / `138.96` Mreads/s, making the combined distance decode + extra-bit cost visible before production changes. A benchmark-only `fused18` kernel now peeks/advances distance extra bits after the 5-bit symbol proxy; the first ReleaseFast rows improved buffered README/roadmap from `315.81` / `318.52` to `321.30` / `327.20` Mreads/s and 4 KiB span from `167.72` / `167.19` to `181.60` / `175.56` Mreads/s. A narrow production helper now applies that staged peek/advance only to distance extra bits (not length bits and not symbol-specific branches); ReleaseFast repeat3 README/roadmap probes improved README broadly and kept roadmap within mixed-positive bounds, while `run-chunked-zlib-bench-report-gate` and `run-png-streaming-zlib-bench-report-gate` passed; A broader production attempt that fused dynamic distance FastDecoder hits with distance extra-bit consumption was rejected: it improved `docs/roadmap.md` in the targeted repeat3 probe but regressed README raw/zlib/gzip caller-buffer rows to about `474.04` / `495.73` / `453.28` MiB/s, so keep the narrower extra-bit-only helper for now; span rows show the new reader also improves length/distance extra-bit reads rather than only Huffman-symbol lookup; A follow-up production experiment that special-cased hot distance symbols `12/13/20/22/24/26/28` with constant extra-bit widths was rejected: ReleaseFast repeat3 README rows improved in some modes, but `docs/roadmap.md` regressed sharply (raw/zlib/gzip caller-buffer rows around `269.45` / `266.90` / `270.21` MiB/s versus the restored baseline around `313.27` / `300.05` / `308.80` MiB/s), so keep the table-based distance decode until a narrower corpus-safe fusion is proven. ChunkedBitReader fill now avoids re-running full staged-cursor synchronization while the staged byte remains inside the cached chunk, a narrow A/B that improved the large literal-coded chunked-reader row by about `1.069x` (`133.92 -> 143.22` MiB/s) and direct geomean by about `1.018x` on the chunked zlib repeat5 benchmark; A similar consumed-cursor fast path in `advanceBitsStagedAssumeAvailable` was rejected: the extra-bit microbenchmark regressed sharply across 4 KiB, 64-byte, and 1-byte chunk rows, showing that the added per-advance branch was more expensive than the existing `syncCursor` call pattern. A narrower chunk-local multi-byte staging attempt inside `fill` was also rejected: it regressed the extra-bit gate across all chunk sizes, with geomean ratios around `0.73x` for 4 KiB/64-byte chunks and `0.71x` for 1-byte chunks, so the one-byte staging loop with the staged-cursor guard remains the production path. a chunked-reader fill batching experiment was measured against that gate and rejected because chunked_64/chunked_1 regressed for most widths despite isolated gains at 13-bit chunked_64 and 3-bit chunked_1; `run-deflate-match-copy-bench-gate` writes and validates `zig-out/vort-deflate-match-copy-bench.csv`, a focused microbenchmark for current, non-overlap-first, and small-unrolled match-copy kernels across RLE, small-distance, non-overlapping, and overlapping cases; `run-deflate-dynamic-decode-profile-gate` validates the README/roadmap rows and histogram/top-symbol consistency and is included in `ci-smoke`. The current README/roadmap/chunked-window-match profile shows literal misses are effectively zero while distance fast-table misses are low single-digit percentages; the gate now requires the chunked-window-match synthetic row to exceed the stack-join raw threshold, be match-heavy, and be non-overlap dominated so true chunked-reader match/history costs remain visible beside the literal-only throughput row. It also shows high extra-bit density on text-heavy matches (about `7.92` bits per README match and `9.70` bits per roadmap match), and now includes semicolon-delimited length/distance symbol histograms, top-3 symbol summaries, extra-bit-width read/bit histograms, and match-class extra-bit density. The latest profile attributes README/roadmap non-overlap matches to about `7.946` / `9.824` extra bits per match, or `0.612` / `0.970` extra bits per non-overlap byte; including distance Huffman code bits, those non-overlap distance fields cost about `11.707` / `13.703` bits per match, so code-length and extra-bit costs can be separated from match-copy throughput before changing distance/extra-bit decode (current README top distance symbols include `12:152`, `13:105`, `20:101`, while top distance extra-bit costs are `28:949`, `20:909`, `22:790`; roadmap count leaders are `26:540`, `28:516`, `24:512`, and extra-bit cost leaders are `28:6708`, `26:6480`, `24:5632`). The remaining gap likely needs bitreader/extra-bit, table setup, and payload-loop evidence beyond simple fast-table width tweaks. The repeat3 stage report also appends `README.md` and `docs/roadmap.md` via `--builtins-plus-files`, keeping the known text-heavy weak cases visible beside the built-in smoke corpus. `run-chunked-zlib-bench-report-gate` validates the repeat3 CSV for contiguous zlib decode, legacy join-then-decode chunks, direct chunked zlib decode on PNG-like payloads with fixed-size and tiny/empty IDAT-style chunks, and exact-size allocating chunk decode (`chunk_exact_mib_s` / `exact_over_direct`). The CSV includes `direct_strategy` so direct-API rows distinguish `stack-join`, `stored-direct`, legacy `chunked-reader`, and current `span-reader` execution before accepting small chunked-reader changes; the benchmark includes large literal-coded and match-heavy rows that exceed the bounded stack-join limit so true chunked-reader throughput stays visible across both pure literal and match-copy dynamic payloads, and the exact-size rows keep known-output-size users such as imx split-IDAT full-inflate fallback visible beside caller-buffer direct decode. `run-chunk-cursor-bench-gate` adds a lower-level CSV for read-byte and copy-to cursor kernels across one-byte empty, seven-byte empty, and 256-byte chunk layouts so cursor micro-optimizations can be evaluated before re-running full zlib decode. The direct chunked path still uses a bounded stack join for small compressed non-stored members when that beats cursoring through thousands of tiny chunks, but the join buffer is tiered (4 KiB / 16 KiB / 64 KiB) so small PNG IDAT streams do not pay a full 64 KiB stack frame. A follow-up A/B that forced all stored chunked zlib members onto the direct stored reader was rejected: ReleaseFast `run-chunked-zlib-bench-report -- --repeat 5 --iterations 4000` showed direct geomean around `0.979x`, with `png-indexed-stored-7b-empty` direct throughput falling from about `1654.07` to `1435.63` MiB/s, so the existing `stack_chunked_zlib_tiny_chunk_count` cutoff remains in place. The same benchmark kept a narrower `joinChunks` empty-chunk skip: join throughput improved by about `1.047x` geomean in the A/B, with empty-chunk rows moving roughly `610.12 -> 649.38` MiB/s for `png-rgb8-dynamic-1b-empty` join and `2028.96 -> 2384.63` MiB/s for `png-indexed-stored-7b-empty` join, while preserving direct decode correctness on empty chunk layouts. The gate now also includes `png-indexed-stored-1b-empty` so the pathological one-byte stored split case stays visible beside the 7-byte empty stored row. An attempted `ChunkCursor` micro-optimization that advanced past consumed chunks and skipped empty chunks inside `readByte`/`copyTo` was not kept: the repeat5 chunked benchmark was noise-level overall (`~1.001x` direct geomean) and regressed the newly added one-byte stored empty case (`332.89 -> 329.31` MiB/s), so direct-reader policy needs a more targeted redesign. A later attempt to reuse the already-known `total_len` in stack joins, avoiding a second `chunksTotalLen` scan, was also not kept: join geomean was about `0.987x` and `png-indexed-stored-1b-empty` join fell from roughly `456.02` to `424.37` MiB/s, so the simple `joinChunks` shape remains preferable until a dedicated cursor/copy benchmark justifies a broader rewrite. The follow-up cursor microbenchmark showed that a copy-only empty-chunk advance can improve isolated `copyTo` rows, but the production A/B was still rejected: full `run-chunked-zlib-bench-report -- --repeat 5 --iterations 4000` direct geomean was about `0.996x` and `png-rgba8-stored-256b` direct fell from roughly `10642.72` to `10149.34` MiB/s, so cursor changes must be tied to a more selective stored-reader path. Stored-footer read tweaks were also rejected: replacing footer reads with `readChunkedBigU32` had only noise-level direct geomean (`~1.002x`) while regressing `png-indexed-stored-7b-empty`, and an in-cursor `readBigU32` loop measured about `0.997x` direct geomean, so footer reads are not the current bottleneck. A more selective copy-only empty-chunk advance that triggered only before actual empty chunks was also rejected: repeat5 direct geomean stayed below 1.0 (`~0.997x`) because `png-rgba8-stored-256b` and `png-literal-16b` regressed despite improvements on one-byte empty rows. `run-dictionary-decode-bench-gate` writes and validates `zig-out/vort-dictionary-decode-bench.csv`, measuring allocator-returning, exact-size allocator, and reusable caller-buffer raw/zlib preset-dictionary decode on history-replay, JSON-prefix, and log-prefix fixtures; the history fixture first seeds output from the preset dictionary and then replays from decoded history, while JSON/log rows keep service-style structured payloads visible. This protects dictionary-backed inflate from regressing to byte-at-a-time fallback after either the initial match reaches into the preset dictionary or later match distances are fully inside output history; Debug build gates validate CSV shape only, while ReleaseFast runs enforce the throughput floors. `run-deflate-wrapper-fuzz-corpus-dashboard` retains schema-checked JSON/Markdown evidence for raw/zlib/gzip wrapper fuzz corpus accept/reject and exact-error expectations, while `run-fuzz-corpus-coverage-smoke` enforces the external minimum mode/error coverage matrix. The corpus decode benchmark builds Vort raw/zlib/gzip frames for text, structured, repetitive, and deterministic binary corpora, then reports wrapper-specific decode MiB/s while verifying every round trip. The fixed encode smoke benchmark runs greedy-LZ77-backed raw fixed deflate encoding and verifies round trips. `run-level-report` reports parser/level/strategy/cost-model settings on built-in samples or provided files, including token counts, literal/match counts, matched-byte coverage, average match length, fixed bits-per-byte, and one-shot/adaptive size ratios for each level/strategy row; `run-level-report-csv` writes the same diagnostics to `zig-out/vort-level-report.csv` for dashboard indexing and regression evidence, and `run-level-report-dashboard` writes a Markdown companion at `zig-out/vort-level-report.md` with a best-raw/best-adaptive summary per case for quick human review. `run-huffman-length-report-dashboard` writes CSV/Markdown oracle evidence for fixed and generated small length-limited Huffman cases plus large DEFLATE alphabet regressions (286 literal/length, 30 distance, 19 code-length symbols) including configurable length-generation `ns/op` via `-- --iterations <n>`, so package-merge behavior and cost can be validated before and after production changes; `run-rust-deflate-benchmark-summary` also includes these Huffman oracle totals when the CSV artifact is present. `run-dynamic-plan-builtins-report-csv` writes the same dynamic header/token diagnostics for the built-in Rust benchmark samples, including `distance-heavy` and `dynamic-match`, and records bit-boundary slack (`dynamic_bits_mod8` / `dynamic_bits_to_save_byte`) so byte-level size gaps can be investigated without changing production encoders. `run-split-policy-report` compares one-shot vs adaptive split sizes for every compression level on built-in corpora or provided file paths; `run-split-policy-corpus-report` runs the same policy delta report over a bounded Silesia subset by default, with `-- --all` for all bounded Silesia files. `run-sidecar-verify-report` (also accepts `-- --dir <path>`, `-- --limit <n>`, `-- --keep-going`, and `-- --markdown <path>` / `-- --json <path>`), `store-sidecar-range-demo`, `vort-sidecar-blocked-best-range-demo`, `vort-sidecar-ldm-range-demo`, and file commands `encode-vort-sidecar-best-file` / `verify-vort-sidecar-index-file` / `decode-vort-sidecar-range-file` and `encode-vort-sidecar-dict-file` / `decode-vort-sidecar-auto-range-file`, and `encode-vort-sidecar-ldm-file` exercise external sidecar indexes; `run-native-range-report` verifies checksum-validated indexed range decode and accepts `-- --offset <n> --length <n>` or `-- --sweep` across store, blocked best, dictionary, self-contained/trained dictionary, indexed LDM, and blocked LDM native streams, or across provided file paths using blocked-best native streams. `run-native-tier-range-bench-gate` is a library-level benchmark for the public `seek_fast` / `balanced` / `ratio` seekability tiers, timing centered range decode through direct Vort APIs rather than the CLI zstd-compare surface; ReleaseFast runs enforce conservative throughput floors for each tier. `run-native-tier-range-files-bench-gate` runs the same direct-API matrix on README.md and docs/roadmap.md so real project text stays visible beside synthetic fixtures; `run-native-tier-range-corpus-bench-gate` extends that direct-API tier matrix to the first bounded discoverable standard-corpus rows; ReleaseFast README rows are currently about 116 / 41 / 41 MiB/s for `seek_fast` / `balanced` / `ratio`, while roadmap is about 53 / 12 / 6 MiB/s. `run-compression-report` includes trained-dictionary stream selection metrics; `run-dictionary-report` can train on built-in samples or provided files, accepts `-- --target <bytes>`, and reports dictionary patch/native-best ratios; `run-dictionary-corpus-report` applies that dictionary report to a bounded Silesia subset, with `-- --per-file` for per-file rows, `-- --targets a,b,c` for target-size sweeps, and `run-dictionary-corpus-dashboard` for a Markdown dashboard. The native parallel benchmark compares planned, spawned-thread, fixed thread-pool, and work-queue native stream encoders on either its built-in corpus, a provided real file path plus block size/worker count, dashboard `-- --block-len <bytes>` overrides, bounded/full Silesia files via `run-native-parallel-corpus-report`, discoverable standard corpora via `run-native-parallel-multi-corpus-dashboard` / `run-native-parallel-multi-corpus-full-dashboard` (`-- --limit n` bounds rows for smoke runs), or Markdown dashboards via `run-native-parallel-dashboard` and `run-native-parallel-full-dashboard`; the bounded and full dashboard steps also accept `-- --workers <n>` or `-- --worker-sweep a,b,c` plus `-- --paths <files-or-dirs-or-tar-archives>` for external corpora and include per-mode/worker total throughput summaries. `run-native-thread-pool-full-dashboard` filters the same full standard-corpus automation to the production thread-pool path for dedicated evidence. The file corpus report/dashboard emits per-file ratio plus encode/decode MiB/s for Vort fastest/fast/best deflate and expands directory inputs recursively, tar archives via the system `tar`, and discoverable standard corpora via `run-file-corpus-standard-dashboard` or full per-file reads across discovered standard corpora via `run-file-corpus-standard-full-dashboard` (`-- --limit n` bounds rows for smoke runs); `run-zstd-compare` / `run-zstd-compare-gate` retain zstd size plus decode smoke rows beside Vort raw fixed, native best, blocked native stream, and native embedded sizes, splitting stream-fragmentation bytes from embedded-index bytes; `run-zstd-compare-block-sweep-gate` sweeps 4/8/16/32/64 KiB native blocks on the bounded standard smoke so stream-fragmentation cost and centered 4 KiB range-decode throughput are tracked as a seekability knob; `run-zstd-compare-block-sweep-releasefast-gate` repeats that sweep with a ReleaseFast Vort CLI as an opt-in tier signal; Vort decode timings use CLI-internal loops while zstd rows still include process/stdout plumbing; `run-standard-corpus-report` compares Vort, gzip, zlib-ng, zlib-rs, and zstd compression and decompression timings on a bounded Silesia sample, accepts `-- --progress` for per-case stderr progress during long dashboard runs, with `-- --suite` (or the `run-standard-corpus-suite` alias) for per-file bounded Silesia automation, `-- --paths <files-or-dirs-or-tar-archives>` for arbitrary external corpora, `run-standard-corpus-dashboard` for a bounded Markdown dashboard with per-codec summary totals at `zig-out/vort-standard-corpus-dashboard.md`, `run-standard-corpus-full-dashboard` for a full-size Silesia dashboard (also accepts forwarded `-- --paths`/`-- --limit`) at `zig-out/vort-standard-corpus-full-dashboard.md`, `run-standard-multi-corpus-suite` / `run-standard-multi-corpus-full-suite` plus `run-standard-multi-corpus-dashboard` / `run-standard-multi-corpus-full-dashboard` to discover local Silesia/Calgary/Canterbury/enwik-style corpora (`-- --limit n` bounds rows for smoke runs), and `-- --full` for the full local Silesia tar. Use `-Doptimize=ReleaseFast` for any performance interpretation; Debug timings are only build-smoke signals. These are still smoke reports and not a final competitor benchmark claim.
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

Latest local ReleaseFast stored-path evidence after raw and wrapper stored-plan
reuse (2026-07-21, `zig build -Doptimize=ReleaseFast
run-deflate-decode-stage-report-csv-repeat3`) keeps the `stored-binary` row at
repeat 3 / 512 iterations over 64 KiB input. Raw stored reports
`raw_stored_mib_s = 3746.44`, `raw_stored_exact_mib_s = 3775.82`, and
`raw_stored_into_mib_s = 43776.01`; zlib reports `zlib_stored_mib_s =
3282.02`, `zlib_stored_exact_mib_s = 3194.62`, and
`zlib_stored_into_mib_s = 17584.83`; gzip reports `gzip_stored_mib_s =
1601.41`, `gzip_stored_exact_mib_s = 1575.41`, and
`gzip_stored_into_mib_s = 2656.78`. The same row records
`raw_stored_alloc_time_ratio = 0.9769`, `zlib_stored_alloc_time_ratio =
0.9910`, `gzip_stored_alloc_time_ratio = 1.0167`,
`raw_stored_alloc_exact_time_ratio = 1.0078`,
`zlib_stored_alloc_exact_time_ratio = 0.9734`, and
`gzip_stored_alloc_exact_time_ratio = 0.9838`, so the recent
safety-preserving plan reuse is documented with mixed but near-neutral repeat3
evidence rather than assumed from code structure alone.

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
(2026-09-11) shows Vort remains close on deflate size but is still mixed on
throughput versus the Rust ecosystem. Size ratios below 1.0 are smaller than the
best Rust row, while throughput ratios above 1.0 are faster:

| metric | geomean ratio | weakest case | next focus |
| --- | ---: | --- | --- |
| `zlib encode default size / best Rust` | `0.999` | `distance-heavy 1.027` | default match parsing / cost model |
| `zlib encode best size / best Rust` | `0.990` | `dynamic-match 1.008` | dynamic header/token byte-boundary gap |
| `raw encode default size / best Rust` | `0.999` | `distance-heavy 1.029` | default match parsing / cost model |
| `raw encode best size / best Rust` | `0.989` | `dynamic-match 1.008` | dynamic header/token byte-boundary gap |
| `zlib decode into / best Rust` | `1.221` | `roadmap 0.401` | roadmap/readme text-heavy dynamic decode |
| `raw decode into / miniz_oxide` | `1.874` | `readme 0.613` | README/roadmap text-heavy dynamic decode |
| `zlib decode alloc / best Rust` | `0.952` | `stored-binary 0.211` | stored/binary allocation and exact-size path |
| `raw decode alloc / miniz_oxide` | `1.310` | `stored-binary 0.235` | stored/binary allocation and exact-size path |
| `zlib encode best-speed / best Rust` | `1.697` | `readme 0.131` | fast/default source-text parser throughput |
| `raw encode best-speed / best Rust` | `1.727` | `readme 0.087` | fast/default source-text parser throughput |


The same repeat3 run emits decode-stage rows for `README.md` and
`docs/roadmap.md`: in the current sample `README.md` reports raw/zlib/gzip
caller-buffer decode at about `1127.25` / `1073.26` / `1059.31` MiB/s, with a
`615`-bit dynamic header (`HLIT/HDIST/HCLEN=285/30/17`, literal
`122/163/13`, distance `30/0/14`). `docs/roadmap.md` reports about `844.60` /
`833.59` / `828.86` MiB/s, with a `788`-bit dynamic header
(`HLIT/HDIST/HCLEN=285/30/19`, literal `132/153/15`, distance `30/0/13`).
These rows should be used to separate text-heavy dynamic payload cost from
wrapper and allocation overhead before changing Huffman table policies again.
A follow-up length-extra-bit staged peek/advance experiment was rejected on
2026-07-20: one short ReleaseFast repeat3 candidate improved some
README/roadmap caller-buffer rows, but also regressed README `gzip_into` and
showed mixed binary/structured behavior in the same sample. Keep the production
staged helper limited to distance extra bits until broader A/B evidence proves
length extra-bit changes are corpus-safe across raw/zlib/gzip decode.
A narrower no-dictionary caller-buffer-only retry was also rejected the same day: even after the focused extra-bit gate showed positive median-of-3 staged/current ratios, decode-stage repeat3 regressed README `gzip_into` (`~553.72 -> ~436.26` MiB/s) and structured `gzip_into` (`~2180.39 -> ~1817.18` MiB/s), so length staged reads remain benchmark-only.
An audit against zlib-ng's `inflate_fast` output-space contract produced a
narrower caller-buffer win on 2026-09-11. Dynamic blocks whose distance tree
selects Vort's deep-distance non-overlap semantic loop now enter that loop only
with 262 bytes of output available: four bytes for the two paired-literal
entries that can precede a match, plus DEFLATE's 258-byte maximum match. The
loop can therefore omit its redundant per-match output-capacity check while
retaining distance/history validation; the transactional tail still owns the
exact `OutputTooSmall` boundary. On a fixed Intel i9-13900K P-core (CPU 8),
nine alternating 1,000-iteration baseline/candidate pairs measured median
caller-buffer ratios of `1.0264x/1.0128x/1.0216x` for README raw/zlib/gzip and
`1.0087x/1.0077x/1.0053x` for `docs/roadmap.md`, with wins in
`9/9, 8/9, 7/9` and `9/9, 9/9, 9/9` pairs respectively. A mixed-match oracle
pins a maximum-length match that exactly fills the last 258 output bytes and a
one-byte-short caller buffer. Two adjacent ideas were measured and rejected:
extending the PNG-only zero-length-extra branch to the full-output loop
regressed README by roughly 4% and roadmap by roughly 12% in the initial
repeat3 caller-buffer probe, while delaying the third/fourth literal-table
loads lost about 0.6--2.0% on the text rows.
Unknown-size raw and zlib allocation without preset dictionaries now reuse the capacity already reserved
from the compressed-size hint as a caller-buffer decode target before falling
back to the growing ArrayList decoder. This mirrors zlib-rs's slice-oriented
inflate interface, preserves bounded fallback for expansion beyond the hint,
and lets the existing semantic fast loop handle large text streams without
per-token ArrayList updates. On the same fixed i9-13900K P-core, seven
alternating 500-iteration pairs moved README raw/zlib allocation medians from
about `435.91/431.43` to `828.66/823.38` MiB/s (`1.9078x/1.9097x`) and roadmap
from `387.86/384.28` to `717.05/705.79` MiB/s (`1.8502x/1.8394x`), with every
pair winning. The already-direct exact-size and caller-buffer controls stayed
within roughly one percent by paired median. Gzip allocation already uses the
trailer ISIZE exact-buffer path and therefore remains unchanged. Tests cover
the no-growth allocation boundary, insufficient reserved capacity, and a
caller limit below the decoded size.
A narrowly gated attempt to reuse the existing semantic single-distance decoder
for the three-symbol `overlap-rle` caller-buffer case was rejected. Nine
alternating fixed-P-core runs regressed its raw/zlib/gzip caller-buffer medians
to roughly `0.951x/0.955x/0.959x`; broader small-tree dynamic controls also
regressed because the extra semantic-table construction outweighed payload-loop
savings. The general 9-bit FastDecoder path remains in place.
A follow-up isolated one-bit-distance loop avoided rebuilding semantic tables
and used the fixed-width RLE fill directly. Its `overlap-rle` caller-buffer
median improved only about `1.004--1.008x`, while several unrelated controls
still moved down by about one percent. Applying the fixed-width fill globally
made the target `2.15--2.72x` faster but caused the same broad code-layout
regressions. Both variants were rejected; RLE copy needs either call-site-local
code generation or a stronger selection mechanism before another production
attempt.
A later bitstream audit found that this generated final block has an even
narrower shape that those rejected loops did not use: its complete
literal/length tree contains only one literal, EOB, and length 258 with widths
`2/2/1`, while distance symbols zero and one both have width one. The resulting
payload alphabet is four exact two-bit tokens: RLE258/distance-one, the lone
literal, RLE258/distance-two, and EOB. The caller-buffer decoder now proves that
canonical layout directly from the already-built compact literal table and
parsed lengths, before constructing either the 9-bit literal or 8-bit distance
fast table, then decodes the two-bit tokens in an isolated RLE258 section.
Final-block, no-dictionary, non-aliasing guards keep multi-block, chunked-reader,
dictionary, and in-place inputs on their prior paths.

Thirty interleaved ReleaseFast pairs on fixed CPU 8 used independent baseline
and candidate binaries and verified identical mixes on every run. Target
caller-buffer median speedups were `3.8339x` raw, `4.6415x` zlib, and `3.7848x`
gzip, all with 30/30 wins. Across 30 non-target raw/zlib/gzip rows covering
tiny, repetitive, distance-heavy, dynamic-match, text, binary, stored,
incompressible, README, and roadmap inputs, the geometric mean of row medians
was `1.0081x` and the lowest row median was `0.9972x`. A second 30-pair target
matrix covered alloc, exact-size alloc, and caller-buffer APIs: every row won,
with medians from `2.2101x` (zlib alloc, including allocation/checksum work) to
`6.7540x` (raw caller-buffer). The formal repeat-3 comparison now reports Vort
zlib alloc/into at `10,992.78/21,480.23 MiB/s` versus fdeflate zlib at
`7,257.16 MiB/s`, and Vort raw alloc/into at `13,356.35/34,052.81 MiB/s`
versus miniz_oxide raw at `6,988.75 MiB/s`. Caller-buffer and Rust owned-result
rows remain different API contracts; the directly comparable Vort owned-result
rows are about `1.51x` and `1.91x` the respective Rust baselines here.
Single-member and concatenated gzip caller-buffer plus allocator-returning decode now have `GzipDecodeOptions` through `decodeGzipWithOptions`, `decodeGzipAllocWithOptions*`, and `decodeGzipConcatenated*WithOptions` APIs, exposing strict-by-default toggles for CRC-32, ISIZE, and trailing-data validation; this gives wrapper/checksum investigations a public measurement surface analogous to `ZlibDecodeOptions` without changing normal API behavior. A first production attempt to update CRC-32 incrementally inside the single-member caller-buffer inflate loop was rejected: per-literal/match `Crc32Slice32.update` calls regressed ReleaseFast gzip caller-buffer rows badly (for example README `gzip_into` around `297.25` MiB/s versus no-CRC `506.45`, structured around `1852.31` versus `6878.47`), so future CRC fusion needs chunk/span batching rather than per-symbol updates. A follow-up block-level 4 KiB batched CRC candidate was also rejected: it improved some structured rows but regressed README (`~492.58 -> ~365.97` MiB/s), dynamic-match (`~1960.50 -> ~1798.71` MiB/s), and binary (`~1642.66 -> ~1375.55` MiB/s), so gzip CRC fusion needs a more selective batching design than flushing once per deflate block. The decode-stage report now emits `zlib_into_no_adler_mib_s`, `adler32_mib_s`, `zlib_adler_time_ratio`, gzip alloc/exact/into no-CRC rows, `gzip_into_no_isize_mib_s`, `gzip_into_relaxed_mib_s`, standalone `crc32_mib_s`, and strict-ratio columns; this separates Adler-32 and CRC-32 scan costs from wrapper validation beside strict zlib/gzip rows. Allocator-returning zlib relaxed decode now also skips Adler work when `ignore_adler` is set, matching the caller-buffer measurement path.

This is not a final ecosystem claim: Rust's compression stack still has broader
zstd/brotli/lz4 coverage, mature fuzzing, platform dispatch, and production
usage. Treat this table as the current deflate-focused gap ledger and update it
after meaningful codec or benchmark changes.

The one-shot hash parser now switches to its already-proven bounded predecessor
ring above 64 KiB instead of waiting until 512 KiB. The exact 64 KiB boundary
keeps the established full-table layout for common binary/image blocks; larger
inputs use one active power-of-two history window. The existing full-table
oracle remains token-for-token and stat-for-stat identical across all supported
window sizes, and explicit assertions pin both sides of the new threshold. On a
fixed Intel i9-13900K P-core (CPU 8), 15 alternating 100-iteration README
fastest pairs preserved the 22,172-byte zlib frame and improved median encode
time from about 85.06 ms to 74.14 ms (`1.147x`, 15/15 wins). Eleven matching
fast/default pairs preserved 26,286/20,150-byte frames: fast improved from
about 95.09 ms to 84.14 ms (`1.130x`, 11/11 wins), while default remained
noise-neutral at `0.999x` paired median. The local fdeflate source uses the
same bounded predecessor-ring principle (`links[offset % WINDOW_SIZE]`); Vort's
threshold keeps it selective rather than globally changing small allocations.
An fdeflate-style no-match skip-ahead prototype was tested separately and not
kept. It used the local hash-chain parser's shift-6 policy only for Vort's
`.fastest` preset, retaining every skipped input byte as a literal while
omitting its hash probe/insertion. On the same fixed CPU 8, 15 alternating
100-iteration pairs moved README to `0.9936x` paired-median throughput with
only 1/15 wins (the 22,172-byte frame was unchanged), while roadmap moved to
`0.9804x` with 1/15 wins and grew from 290,385 to 290,387 bytes. Source text
does not contain enough long no-match runs for the extra policy state to pay
for itself, so the exhaustive hash-greedy scan remains in production.
The one-shot hash-greedy parser now stores head and predecessor positions as
signed 32-bit indices whenever the input length fits `i32`, halving those hot
tables on 64-bit targets; inputs above that explicit boundary retain the
machine-width implementation. Existing `isize` full-table oracles compare the
compact public path token-for-token and stat-for-stat for both full and ring
layouts, and a boundary test pins the fallback decision. Fixed CPU 8 A/Bs
preserved every measured frame: 15 alternating `.fastest` pairs improved README
from about 74.28 ms to 69.29 ms (`1.0721x`, 15/15 wins) and roadmap from
875.36 ms to 846.25 ms (`1.0340x`, 15/15); eleven `.fast` pairs improved them
by `1.0684x` and `1.0274x`, both 11/11. Full-table source cases below the ring
threshold benefited more: `src/png.zig` reached `1.2202x` and
`src/deflate/incremental/tests.zig` `1.2911x`, both 11/11 with identical output.
Hash-greedy search now also normalizes the minimum/maximum match lengths and
derived chain-walk limit once per plan rather than repeating the same clamps at
every input position. The precomputed limits feed both reusable and one-shot
table layouts without changing candidate order or acceptance. Against the
compact-index baseline on fixed CPU 8, 15 alternating `.fastest` pairs kept the
22,172/290,963-byte README/roadmap frames and improved paired-median throughput
by `1.0339x` (12/15 wins) and `1.0155x` (15/15). Eleven `.fast` pairs improved
by `1.0255x` and `1.0224x`; full-table `src/png.zig` and incremental-test source
rows improved by `1.0108x` and `1.0183x`. All four retained identical frames.
For the one-shot heap parser, the now-compact 128 KiB head table is cleared to
the `-1` sentinel once per plan instead of carrying a 4 KiB initialization
bitmap check through every lookup and insertion. Tiny and reusable parsers keep
lazy initialization, where avoiding repeated clears remains the better policy.
Against the hoisted-limit baseline on fixed CPU 8, eleven alternating
`.fastest` pairs improved README/roadmap/`src/png.zig` by `1.0513x` / `1.0289x`
/ `1.0476x`, all 11/11 wins; `.fast` improved README/roadmap by `1.0439x` /
`1.0193x`, also 11/11. The 64 KiB `src/checksum.zig` control was nearly neutral
but positive at `1.0042x` (10/11), and every measured frame stayed identical.
A full four-byte prefix check for the four-byte hash anchor was also rejected.
Although it preserved chain-budget accounting and every measured frame, the
global variant reached only about `1.005x` on README/roadmap and regressed the
44 KiB `src/png.zig` case to `0.9742x` (2/11 wins). Restricting it at compile
time to the ring-backed path removed that regression, but a final 15-pair run
was noise-neutral: README `1.0043x` with 9/15 wins and roadmap `0.9985x` with
5/15. The existing last-required-byte filter and zero-offset `matchLength` stay.
A one-shot 65,536-bucket head-table experiment was rejected as well. It paired
the larger table with the high 16 bits of the four-byte multiplicative hash,
but doubling the per-plan clear from 128 KiB to 256 KiB outweighed fewer
collisions: eleven fixed-CPU-8 README `.fastest` pairs fell to `0.9295x` with
0/11 wins and no size change. A partial roadmap probe saved two frame bytes but
was noisy and did not justify the clear/cache cost. Keep the 32,768 buckets.
A larger initial token reserve for one-shot hash parsing was rejected. Reserving
`input.len / 5` (capped at 32K tokens) above 64 KiB improved README `.fastest`
by about `1.025x`, but roadmap was only `1.004x` and a 1 MiB single-byte-repeat
control fell to `0.994x`. Adding a 64-byte diversity sample protected the
allocation size but still cost roadmap throughput (`0.9959x`, 0/12 wins), while
README improved `1.0161x`. Keep the simple 4,096-token initial reserve until a
signal already available from parsing can size it without an extra prepass.
One-shot hash planning for `.stored_fixed_dynamic` now accumulates literal/
length and distance histograms as tokens are emitted, eliminating the full
token scan in `DynamicCodingPlan.init`. Length/distance extra-bit totals are
derived afterward from the 29+30 symbol slots so their lookup work does not
inflate the match-finder hot loop. The observer lives in `deflate.zig` and the
generic LZ77 module only invokes its callback, avoiding a module cycle; tiny,
scan, dictionary, split, and `.stored_fixed` paths retain their old layout. A
token/plan/wire oracle compares the observed and scan-based paths through raw,
zlib, and gzip output. Against an independently built `5b8a5c9e` baseline,
eleven alternating ReleaseFast pairs pinned to i9-13900K CPU 8 kept every frame
byte-identical and improved `.fastest` by `1.0488x` on README (11/11), `1.0455x`
on roadmap (11/11), and `1.0276x` on `src/png.zig` (9/11); zlib-wrapped README
improved `1.0466x` (11/11). The `.fast` controls, which do not use dynamic
selection, remained noise-neutral at `1.0005x` on README and `0.9985x` on
roadmap. Full validation passed 1,498 tests, all 83 compile-check steps, the
50-check Rust differential, the five-case incremental encode gate, and the
265-success/60-expected-failure Python zlib differential dashboard.
The reserved-capacity dynamic block writer now keeps pending fields in a local
64-bit reservoir and appends eight bytes only when it fills, following the
batched emission shape used by zlib-ng and zlib-rs. The prior implementation
materialized and appended every complete-byte fragment after each literal or
fused match even though total output capacity was already reserved. Checked,
split, and general-purpose `BitWriter` paths remain unchanged. A dedicated
oracle covers every starting bit alignment and widths 0...56 across repeated
64-bit boundaries; the retained checked-vs-reserved dynamic block oracle covers
the complete header, token payload, EOB, and all alignments. Against an
independently built `b19130b3` baseline, eleven alternating ReleaseFast pairs
pinned to i9-13900K CPU 8 preserved every frame and improved raw `.fastest` by
`1.0464x` on README (11/11), `1.0334x` on roadmap (11/11), `1.0244x` on
`src/png.zig` (10/11), and `1.0306x` on `src/checksum.zig` (11/11).
Zlib-wrapped README improved `1.0421x` (11/11), default raw README improved
`1.0092x` (11/11), and the non-dynamic `.fast` control remained neutral at
`1.0028x`. A follow-up README profile reduced `DynamicCodingPlan.writeReserved`
from about 13.83% to 12.59% and sampled `memcpy` from 3.37% to 0.29%. Full
validation passed 1,499 tests, all 83 compile-check steps, the 50-check Rust
differential, the five-case incremental encode gate, and the
265-success/60-expected-failure Python zlib differential dashboard.
The same trusted reserved path now omits per-token symbol bounds/non-zero
branches after its three encoder constructors have validated the coding tables;
Debug builds retain assertions, while checked and externally assembled token
writers still report `InvalidHuffmanCode`. Against the committed 64-bit
reservoir baseline, eleven alternating fixed-CPU-8 pairs kept output identical
and improved README/roadmap raw `.fastest` by `1.0096x` / `1.0031x`, both
11/11 wins, plus `src/png.zig` by `1.0149x` with 9/11 wins. The follow-up
profile reduced `DynamicCodingPlan.writeReserved` from about 12.59% to 11.71%.
Final validation again passed 1,499 tests, all 83 compile-check steps, the
50-check Rust differential, and the 265-success/60-expected-failure Python
zlib differential dashboard.
Two follow-up encoder-table changes were measured and rejected. Constructing
the three canonical encoders in place into undefined storage avoided clearing
unused entries and a large return copy, but gained only about `1.002x` on
README/roadmap `.fastest`, made `src/png.zig` slightly negative, and reduced
default README to `0.9933x` with 0/11 wins. Packing each reversed code and bit
length into one `u32` slot, similar to the compact entries used by zlib-ng and
zlib-rs, regressed every tracked source row: README/roadmap `.fastest` reached
`0.9769x` / `0.9859x`, `src/png.zig` `0.9729x`, `src/checksum.zig` `0.9770x`,
and default README `0.9909x`. Keep the existing split code/length arrays and
validated constructors; after reservoir batching, table construction/layout is
not a profitable standalone target on this compiler and CPU.
Building sorted active-symbol lists during the one-shot histogram post-pass and
feeding the existing sparse Huffman length builder was rejected too. It kept
the plan/wire oracle exact, but list materialization plus the alternate builder
reduced README/roadmap `.fastest` to `0.9845x` / `0.9930x` and `src/png.zig`
to `0.9877x` in eleven fixed-CPU-8 pairs. Keep the dense 286/30-symbol scans;
the remaining `initFromStats` cost is not removed profitably by reconstructing
incremental-style active lists after parsing.
Splitting the observed hash parser's token callback into branch-specific
`recordLiteral` / `recordMatch` methods was rejected. The all-layout form
improved ring-backed README/roadmap `.fastest` by `1.0059x` / `1.0041x`, but
regressed full-table `src/png.zig` and `src/checksum.zig` to `0.9862x` /
`0.9790x`, plus default README to `0.9907x`. A ring-only comptime form still
left the control rows negative and made roadmap unstable. Keep the compact
single `recordToken` observer; the compiler already specializes its known union
tag well enough that another large-loop code-shape split is counterproductive.
A dedicated `u8` length-symbol LUT for the observer was rejected. It replaced
the six-byte `CodeExtra` table lookup used only to obtain a length symbol, but
fixed-CPU-8 results were negative on README/roadmap `.fastest` (`0.9949x` /
`0.9977x`) and default README (`0.9978x`); only `src/png.zig` was marginally
positive at `1.0038x`. Keep the shared length metadata table and avoid another
hot constant table for this sub-percent address calculation.
A 16-byte vector tail after the existing 32-byte `matchLength` loop was also
rejected. It preserved every mismatch/limit result through 321 bytes, but
replacing at most two eight-byte tail probes reduced README/roadmap `.fastest`
to `0.9921x` / `0.9982x`, full-table `src/png.zig` / `src/checksum.zig` to
`0.9858x` / `0.9948x`, and README `.fast` to `0.9935x`. Keep the current
32-byte vector loop followed by the compact u64/scalar tails.
Replacing the four-byte 32-bit golden-ratio hash with fdeflate's 64-bit
golden-ratio mix was rejected at the same 32,768-bucket size. It changed the
bounded collision chains as expected, but README `.fastest` fell to `0.9941x`
and grew by three bytes; README/roadmap `.fast` fell to `0.9731x` / `0.9781x`
despite shrinking by 4/12 bytes. Full-table `src/png.zig` / `src/checksum.zig`
improved `1.0130x` / `1.0262x`, but that isolated gain does not justify slower
primary source workloads or a mixed level policy. Retain the zlib-ng/zlib-rs
style 32-bit high-product hash.
Pairing consecutive dynamic literals into one reserved-reservoir update was
rejected. The lookahead and second token-tag branch outweighed fewer writes:
README/roadmap `.fastest` fell to `0.9882x` / `0.9906x`, `src/png.zig` to
`0.9931x`, and default README to `0.9862x`; `src/checksum.zig` alone was a
noise-level `1.0026x`. Keep the simple one-token loop now that reservoir
updates no longer materialize output bytes on every symbol.
Removing the observed one-shot planner's otherwise-unused `PlanStats` updates
was rejected after two layouts. Returning only the owned token slice improved
README/roadmap `.fastest` by `1.0095x` / `1.0130x`, but shifted the unrelated
default README path to `0.9856x`. Restoring the `GreedyPlan` ABI and isolating
the observed loop in its own executable section left only `1.0030x` / `1.0040x`
on those fastest rows, while default README still fell to `0.9897x` with 0/11
wins and the full-table `src/png.zig` control to `0.9958x`. Retain the three
cheap counters until the parser can be isolated without whole-binary code-layout
regressions.
A 32-bit internal token format for one-shot hash/dynamic selection was rejected
after both global and short/full-table-only trials. Packing literal or
`length-3`/`distance-1` behind one tag reduced each token from six bytes to
four and improved the 44--45 KiB `src/png.zig` / `src/checksum.zig` rows by up
to `1.0441x` / `1.0781x` when isolated. The global form, however, reduced
README/roadmap `.fastest` to `0.9707x` / `0.9833x`; the isolated <=64 KiB form
left README raw/zlib neutral-negative and still reduced unrelated default/fast
README to `0.9937x` / `0.9899x`. Keep the common six-byte `Token`; compact
decode branches and duplicated writer/parser bodies do not repay the footprint
gain across the complete public encoder.
Caching the reserved writer's output pointer and byte length locally was also
rejected. Direct eight-byte stores plus one final `items.len` commit avoided
`appendSliceAssumeCapacity` bookkeeping, but increased live state and left all
tracked rows neutral-to-negative: README raw/zlib `.fastest` were `0.9973x` /
`0.9966x`, roadmap `1.0007x`, `src/png.zig` `0.9979x`, and default README
`0.9906x`. Keep the standard ArrayList append primitive, which LLVM already
reduces to efficient reserved stores.
Packing `CodeExtra` from its natural six-byte layout into 32 bits was rejected.
The table footprint shrank, but extracting 9-bit symbols and 6-bit widths on
every match was broadly slower: README raw/zlib `.fastest` reached `0.9950x` /
`0.9977x`, `src/png.zig` / `src/checksum.zig` `0.9796x` / `0.9868x`, and
README `.fast` `0.9798x`; only roadmap was marginally positive at `1.0039x`.
The exhaustive RFC length/distance metadata and fused-writer oracles remained
exact. Keep the naturally aligned fields for cheaper hot-path extraction.
Fusing each code-length RLE symbol and its optional repeat-count bits into one
reserved-reservoir update was rejected. README/roadmap raw `.fastest` improved
only `1.0047x` / `1.0061x`, while `src/png.zig` was `0.9984x` and default
README fell to `0.9916x` with 0/11 wins. Keep the two simple updates in the
small dynamic-header loop; its branch/layout cost is visible outside the target.
Reducing only the observed hash parser's retained match-tail anchors from four
to three was rejected as a poor speed/ratio trade. Eleven fixed-CPU-8 pairs
improved README/roadmap `.fastest` by `1.0093x` / `1.0162x` and full-table
`src/png.zig` / `src/checksum.zig` by `1.0453x` / `1.0460x`, but grew those
frames by 281 / 4,332 / 153 / 84 bytes respectively. The non-target default/
fast paths were slightly negative. Retain four final anchors; one fewer hash
insert is not worth roughly 1--1.5% worse source compression.
Precomputing all 256 dynamic length fields after building each literal encoder
was rejected. The table fused length symbol code, extra value, and total width
into one 32-bit lookup per match, but its fixed construction and 1 KiB stack
footprint reduced README raw/zlib `.fastest` to `0.9947x` / `0.9939x`, roadmap
to `0.9979x`, `src/png.zig` to `0.9967x`, and default README to `0.9894x`.
All length-boundary and block-wire oracles remained exact. Keep direct access
to the small static metadata plus per-block Huffman encoder.
An exact `.fastest` observed-parser clone with compile-time window, chain, nice,
minimum, maximum, walk, acceptance, and four-byte-anchor settings was rejected.
Although its generic-vs-specialized token/stat and wrapper-wire oracles were
exact for full-table and ring-backed inputs, duplicating the large loop reduced
every measured row: README raw/zlib `.fastest` to `0.9500x` / `0.9495x`,
roadmap to `0.9743x`, and full-table `src/png.zig` / `src/checksum.zig` to
`0.9764x` / `0.9367x`. Keep the shared runtime-options loop; its already-hoisted
limits are cheaper than the instruction-footprint cost of another instance.
High-diversity one-shot hash blocks through 64 KiB now use the existing lazy
head-initialization bitmap instead of clearing the compact 128 KiB head table.
The selector requires more than the tiny-parser threshold and at least 240
distinct byte values in the first 1 KiB; source-like low-diversity inputs keep
the proven full clear. The lazy and cleared observed planners share the same
hash/search loop, and a deterministic 64 KiB binary oracle compares tokens,
statistics, and final raw bytes exactly. Against an independently built
`e670db72` baseline, fifteen alternating ReleaseFast pairs pinned to i9-13900K
CPU 8 improved deterministic binary raw/zlib/gzip `.fastest` by `1.1145x` /
`1.1155x` / `1.1086x`, all 15/15 wins with byte-identical 2,844/2,850/2,862-byte
frames. README/roadmap controls were neutral at `1.0022x` / `1.0012x`;
`src/png.zig` and `src/checksum.zig` improved `1.0247x` / `1.0261x`, while
non-target `.fast`/`.default` controls stayed neutral-to-positive. Binary
profiling reduced sampled `memset` from about 15.73% to 1.62%. Full validation
passed 1,501 tests, all 83 compile-check steps, the 50-check Rust differential,
the five-case incremental encode gate, and the 265-success/60-expected-failure
Python zlib differential dashboard.
High-diversity one-shot blocks with at least 240 active literal/length symbols
now try an isolated ordinary Huffman tree builder before the 15-bit package-
merge path. The natural tree is accepted only when every depth satisfies the
DEFLATE limit; otherwise construction falls back to the unchanged bounded
builder. A 64-case oracle spanning 240--286 active symbols verifies the public
helper against package merge, including exact per-symbol lengths on successful
fast paths and exact fallback output. Fifteen alternating ReleaseFast CPU-8
pairs from independently cached baseline and candidate builds preserved the
2,844/2,850/2,862-byte binary raw/zlib/gzip frames and improved them by
`1.1736x` / `1.1724x` / `1.1610x` (15/15, 15/15, 14/15 wins). README and
roadmap stayed neutral; `src/png.zig` was the weakest control at `0.9935x`, and
default README was positive. The binary profile now places the
isolated dense builder at about 1.35%; the former `initFromStats` symbol no
longer appears above the 0.15% reporting threshold. Full validation passed
1,502 tests, all 83 compile-check steps, the Rust/Python differential checks,
and the incremental encode gate.
The isolated dense DEFLATE tree builder now fuses leaf-bucket counting into its
existing frequency scan and orders leaves directly into the destination index
array. Frequencies 1--4 use exact stable buckets; the remaining tail is sorted
by the full `(weight, serial)` key. The general and dense-Zstd builders retain
their previous sort. The deterministic 64 KiB binary histogram has 263 active
literal/length symbols: 20/88/88/62 occur 1/2/3/4 times, and only five symbols
form the tail (three at 53, one at 97, and one at 661). Thus the old generic
path never sorted a multi-element coarse bucket; its avoidable cost was the
second index scan, 192-entry bucket management, and intermediate array. A
128-case ordering oracle covers ties, the former 165 boundary, and large tails
against the exact comparison order, while the existing 64-case dense-tree
oracle continues to require exact package-merge code lengths. Independently
cached ReleaseFast builder binaries pinned to CPU 8 improved one million builds
of the real histogram by `1.4357x` median with 21/21 wins and an identical
checksum. Fifteen longer alternating encode pairs against detached `7234297e`
improved binary raw/zlib/gzip `.fastest` by `1.0107x` / `1.0116x` / `1.0068x`
with 11/15, 13/15, and 11/15 wins, preserving the 2,844/2,850/2,862-byte
frames. README/roadmap/PNG/checksum and default controls were neutral within
about 0.35%. Final validation passed 1,504 tests, all 83 compile-check steps,
the 50-check Rust differential, the five-case incremental encode gate, and the
265-success/60-expected-failure Python zlib differential dashboard.
A follow-up dense-builder cleanup removes the redundant `serial` field from
ordinary-tree nodes. Node indexes already increase exactly in creation order,
so comparing indexes on equal weights preserves the previous total order and
all package-merge-equivalent lengths. The 64 random dense-tree cases and the
128-case ordering oracle remain exact. Although alignment keeps the node stride
at 16 bytes, avoiding the leaf/parent serial stores and equal-weight loads
improved one million real-histogram builds by `1.0109x` median with 21/21 wins.
Fifteen longer CPU-8 encode pairs improved binary raw/zlib/gzip `.fastest` by
`1.0058x` / `1.0060x` / `1.0037x` with 12/15, 12/15, and 11/15 wins and
unchanged frame sizes; README/roadmap/default controls stayed within about
0.25%, while `src/png.zig` was `1.0051x`. Final validation passed 1,504 tests,
all 83 compile-check steps, the 50-check Rust differential, the five-case
incremental encode gate, and the 265-success/60-expected-failure Python zlib
differential dashboard.
A follow-up lazy-head experiment moved the current-position insertion into the
hash lookup, reusing the bitmap/head load before walking the old chain in the
style of zlib-family quick-insert helpers. The existing 64 KiB oracle confirmed
identical tokens, statistics, and wire bytes, but independent fixed-CPU-8 A/Bs
did not justify the control-flow change: binary raw/zlib/gzip `.fastest` were
only `1.0017x` / `1.0000x` / `1.0026x`, roadmap was a repeatable `0.9966x`
with 0/11 wins, and default README was `0.9946x`. Keep the separate lookup and
insertion until a design can remove more work without shifting source paths.
Two further dense-builder layout experiments were rejected. Splitting symbols
from the ordinary-tree nodes produced an 8-byte hot weight arena and improved
the isolated real-histogram builder by `1.1548x`, but the extra symbol map and
final frequency rescan enlarged the generated fast-helper stack from about
79.7 KiB to 80.5 KiB; full binary raw/zlib/gzip encode measured only `1.0031x`
/ `0.9983x` / `1.0029x`. Separately no-inlining the rare package-merge fallback
reduced the fast helper to a 14 KiB stack frame and improved the isolated
builder by `1.0247x`, but complete zlib/gzip encode fell to `0.9961x` /
`0.9937x` with only 3/15 and 2/15 wins. Keep the unified node layout and
inlined fallback; neither isolated micro win survived the full encoder.
A dense-only trusted literal encoder constructor was also rejected. It skipped
oversubscription checks and left inactive slots undefined for the already-
trusted reserved writer; a 64-case checked/trusted code-and-width oracle and
the real one-shot wire oracle were exact. However, adding the specialized
writer instance made binary raw `.fastest` `0.9986x`, PNG `0.9957x` (1/11),
checksum `0.9965x` (0/11), and default README `0.9913x`; only zlib/gzip binary
improved about 0.6--0.7%. Retain the single checked encoder constructor.
High-diversity one-shot hash blocks through 64 KiB now store lazy-head and
predecessor positions as `u16`, reserving 65,535 as the empty-chain sentinel.
With three- or four-byte anchors, the largest insertable position is 65,533 or
65,532, so all positions remain exact. The head/prev working set for a 64 KiB
block falls from 384 KiB to 192 KiB, in addition to the unchanged 4 KiB
initialization bitmap. A boundary differential builds the maximum-size block
with both anchor widths and compares every token and statistic against an i32
lazy-head reference, including the final inserted head; the existing one-shot
oracle also preserves final wire bytes. Fifteen alternating ReleaseFast CPU-8
pairs against independently cached `facc90fd` binaries improved deterministic
binary raw/zlib/gzip `.fastest` by `1.4906x` / `1.4756x` / `1.4744x`, all
15/15 wins with unchanged 2,844/2,850/2,862-byte frames. README/roadmap and
default/`.fast` controls remained within about 0.8%; PNG/checksum were slightly
positive. Final validation passed 1,505 tests, all 83 compile-check steps, the
50-check Rust differential, the five-case incremental encode gate, the
265-success/60-expected-failure Python zlib differential dashboard, and the
x86-linux-musl LZ77 compile check.
The same compact path now stores absolute `u16` predecessors in a ring sized to
the active power-of-two history window. This differs from the rejected relative-
distance ring: links remain absolute and need no encode/decode arithmetic, while
the existing ring mask and earliest-position guard provide overwrite safety. At
the `.fastest` 16 KiB window, head plus predecessor storage falls again from
192 KiB to 96 KiB (plus the 4 KiB bitmap). The maximum-size three-/four-byte
anchor differential now compares this ring directly with the i32 full table,
including final head and predecessor values. Fifteen long alternating CPU-8
pairs against the independently built u16-full-table baseline improved binary
raw/zlib/gzip `.fastest` by `1.6683x` / `1.6395x` / `1.6391x`, all 15/15 wins
with unchanged frames. README/roadmap/PNG/checksum `.fastest` improved by
`1.0143x` / `1.0065x` / `1.0036x` / `1.0021x`; default README was `1.0021x`,
and the non-target binary `.fast` control was neutral at `0.9988x`. Final
validation passed 1,505 tests, all 83 compile-check steps, the 50-check Rust
differential, the five-case incremental encode gate, the 265-success/60-
expected-failure Python zlib differential dashboard, and the x86-linux-musl
LZ77 compile check.
A follow-up that cleared the compact 64 KiB `u16` head to the sentinel and
removed bitmap probes was rejected immediately: fifteen long fixed-CPU-8 raw
pairs fell to `0.9205x` with only 1/15 wins. Even after halving the head width,
the per-block clear remains much more expensive than the 4 KiB bitmap.
A u16-lazy four-byte-prefix specialization was rejected too. It compared the
complete four-byte anchor before calling `matchLength` and continued from byte
four on exact prefixes, preserving candidate-budget semantics and every oracle
token/wire byte. Fifteen long binary raw pairs nevertheless fell to `0.9809x`
with 0/15 wins; the extra load and branch cost more than the avoided prefix
comparison.
The default lazy parser now stores its full hash head and predecessor positions
as absolute `u32` indexes on inputs through 4 GiB, reserving `0xffffffff` as the
empty sentinel and retaining the `isize` fallback above that bound. Unlike a
ring specialization, this changes neither chain traversal nor window checks; on
64-bit targets it simply halves the two index allocations. A 96 KiB
mixed-history oracle
compares every token, statistic, initialized head, and predecessor against the
old `isize` representation and checks the exact allocation-byte reduction.
Fifteen alternating fixed-CPU-8 raw-default pairs preserved the README and
roadmap wires while improving median throughput by about `1.11x` and `1.075x`.
A separate seven-pair raw/zlib/gzip matrix over README, roadmap, `src/png.zig`,
and `src/checksum.zig` kept every encoded size/checksum identical and measured
default-path median gains of roughly `1.06x`--`1.13x`; `.fastest`/`.fast`
controls were essentially neutral.
A predecessor-ring variant for the same default lazy parser was rejected before
the compact full-table representation was selected. It reduced retained index
memory further, but the per-link mask and earliest-position branch reduced
README and roadmap raw-default throughput to roughly `0.94x` and `0.96x`; the
deeper default search does not share the shallow `.fastest` ring's tradeoff.
The retained `u32` specialization now mirrors zlib-ng's `longest_match`
front/back screening after a candidate consumes search budget. Once a best
match exists, two-, four-, or eight-byte checks reject candidates that cannot
extend it before entering Vort's 32-byte-vector match scan. The `isize` path in
the 96 KiB oracle remains an unscreened reference and produces identical tokens,
statistics, heads, and predecessors. Fifteen long README/roadmap raw-default
pairs improved by `1.011x`/`1.006x` with 14/15 wins each. A nine-pair, twelve-row
raw/zlib/gzip matrix over four source files reached a `1.0112x` row-median
geometric mean with identical wires; the apparent weakest roadmap-gzip row was
then confirmed over 21 longer pairs at `1.0065x` median with 16/21 wins.
A threshold-only lazy-lookahead search was rejected on top of that retained
screen. It returned as soon as the next position found the one-byte gain needed
to displace the current match, while preserving candidate order, budget,
acceptance, tokens, and wire bytes. The duplicated search body and added
acceptance branch still outweighed the saved tail work: fifteen fixed-CPU-8
raw-default pairs measured only `0.9671x` on README and `0.9787x` on roadmap,
with the latter losing all 15 pairs. Keep the shared full match search.
Replacing the compact lazy parser's 128 KiB `u32` head clear with the existing
4 KiB initialization bitmap was also rejected. It preserved the full-table
token/head/predecessor oracle, but default text rapidly touches enough buckets
that per-lookup and per-insert bitmap work dominates the saved clear. Fifteen
fixed-CPU-8 raw-default pairs measured `0.9648x` on README and `0.9780x` on
roadmap, with neither candidate winning a pair. The one-time `u32` clear stays.
The stored-fast-path classifier now counts repeated four-byte sample windows
with an exact 2,048-slot open-addressed position set instead of sorting 1,021
`u32` values. Hash collisions probe onward and compare the original four bytes,
so the existing “four repeats” decision is unchanged; the old sort remains as
a 256-case randomized/constructed differential reference. The lookup helper is
isolated in its own executable section so low-diversity inputs still return
after the existing byte-cardinality test without shifting unrelated hot code.
Against independently cached `ce58be28` baseline/candidate builds, fixed-CPU-8
ReleaseFast medians improved deterministic incompressible raw/zlib/gzip by
`1.4347x` / `1.4104x` / `1.3912x` (15/15 each) and the compressible high-
diversity binary row by `1.0571x` (14/15), with identical frame bytes. README,
roadmap, and default controls remained neutral. Full validation passed 1,503
tests, all 83 compile-check steps, the 50-check Rust differential, the five-case
incremental encode gate, and the 265-success/60-expected-failure Python zlib
differential dashboard.
Ring-backed hash search now tests a newly selected match against the
per-position maximum immediately, instead of checking whether the previous
best reached that maximum at the start of every candidate iteration. The
full-table specialization keeps its prior control flow after an unrestricted
version regressed the 44 KiB source control. Against the ring-window-bound
baseline on fixed CPU 8, README `.fastest/.fast` improved by `1.0176x` /
`1.0165x`, and roadmap improved by `1.0121x` / `1.0054x`; the corresponding win
counts were 14/15, 11/11, 14/15, and 7/11. The `src/png.zig` full-table control
was `1.0052x` with 8/11 wins, and every measured frame stayed identical.
Ring-backed hash search now precomputes the earliest legal predecessor once per
input position and compares candidate positions directly, removing the
impossible zero-distance test and repeated distance/window comparison from its
chain loop. Full-table parsing keeps the prior branch shape after an unrestricted
version regressed 44--45 KiB source rows by about 0.8%. Fixed-CPU-8 A/Bs kept
all frames identical: README `.fastest/.fast` improved by `1.0157x` / `1.0095x`
with 14/15 and 11/11 wins, roadmap improved by `1.0038x` / `1.0027x` with 14/15
and 11/11 wins, and the isolated `src/png.zig` full-table control was exactly
neutral at `1.0000x`.
The hash-chain candidate budget check now follows the candidate that consumes
it instead of being repeated at every loop header. A zero-budget preflight
preserves the custom no-search case, while prefix collisions still do not spend
the checked-candidate budget. Fixed-CPU-8 A/Bs kept every frame unchanged:
README `.fastest/.fast` improved by `1.0090x` / `1.0076x` (15/15 and 11/11
wins), roadmap by `1.0107x` / `1.0114x` (14/15 and 10/11), and the 44 KiB
full-table control remained neutral at `0.9989x`.
A ring-only compile-time specialization for the proven accept-all match policy
was rejected. It removed the runtime selection inside the hash loop but added a
second large loop instance: fixed-CPU-8 `.fastest` results were effectively
neutral on README (`1.0009x`, 8/15) and roadmap (`0.9990x`, 6/15), while the
supposedly isolated 44 KiB full-table control regressed to `0.9910x` with 0/11
wins. Keep the single loop with its once-computed runtime boolean.
Moving the chain-walk budget test from the loop header to both candidate exit
paths was rejected. It avoided one final predecessor load at budget exhaustion,
but duplicated control flow and reduced fixed-CPU-8 `.fastest` throughput to
`0.9957x` on README (5/15 wins) and `0.9910x` on the first eight roadmap pairs
(0/8 wins), with unchanged frames. Keep `walked < max_walks` in the loop header.
Incrementally maintaining the hash candidate's required-prefix offset was also
rejected. It replaced `max(best.length, minimum - 1)` in the loop with mutable
state, but fixed-CPU-8 `.fastest` samples were slightly negative on README
(`0.9994x`, 5/15 wins) and the first ten roadmap pairs (`0.9979x`, 3/10), with
unchanged frames. The compiler's branchless maximum is cheaper than the extra
live state on this loop.
Splitting the one-shot hash scan before its final at-most-three literal bytes was
rejected. The dedicated tail test and existing token oracles passed, but
fixed-CPU-8 A/Bs reduced README `.fastest` to `0.9984x` (4/15 wins), roadmap
`.fastest/.fast` to `0.9962x` / `0.9971x`, and `src/png.zig` to `0.9973x`, with
unchanged frames. Keep the rare end-of-input checks in the shared loop.
Combining the one-shot hash head and predecessor arrays into one allocation was
also rejected. The checked length sum and two logical slices preserved every
token and frame, but fixed-CPU-8 results were mixed: README `.fastest` reached
`0.9982x`, roadmap `.fast` `0.9963x`, while README `.fast` and the 44 KiB
full-table source control reached only `1.0068x` and `1.0108x`. Keep separate
allocations; one fewer allocator call did not improve the primary workloads.
A ring/full-head four-byte hash helper that omitted the final bucket mask was
rejected. The high 15 bits already fit the 32,768-entry table and all oracle
tokens stayed identical, but fixed-CPU-8 gains on README/roadmap were only
`1.001--1.005x`; the nominally isolated 44 KiB full-table control fell to
`0.9947x` with 1/11 wins. Keep the shared masked hash helper to avoid another
code-shape split for a single redundant instruction.
A one-shot match-tail insertion simplification was rejected. Replacing the
existing increment-and-clamp sequence with `end - min(match_len - 1, 4)` kept
the exact same inserted positions and wire bytes, and improved two full-table
source rows (`src/png.zig` `1.0282x`, `src/checksum.zig` `1.0272x`). However,
the all-layout form was neutral on README and `.fast`, and isolating it to the
full-table specialization shifted code layout enough to regress README/roadmap
`.fastest` to `0.9881x` / `0.9922x`. Keep the current shared tail loop shape.
A `u16` relative-distance predecessor ring was rejected despite halving the
16 KiB-window link storage from 64 KiB to 32 KiB. The expanded oracle included
the full 32 KiB DEFLATE window and remained token/stat identical, but the extra
distance encode/decode arithmetic reduced the first three fixed-CPU-8 README
`.fastest` pairs to roughly `0.875x`; the experiment was stopped before broader
measurement. Keep absolute `i32` ring positions.
An isolated `.fastest` chain-depth sweep also retained the existing six-entry
budget. Reducing it to four made a single 200-iteration sample about 3.8% faster
on README and roadmap, but grew their frames by 23 and 339 bytes; the 44 KiB
PNG source gained only about 0.4% while growing 34 bytes, and the 45 KiB
checksum source was slightly slower while growing 18 bytes. Depths two and one
increased README by 241/1,560 bytes and roadmap by 4,231/22,499 bytes. Those are
explicit speed/ratio tradeoffs, not free wins, so the tuned depth six remains.

Dynamic Huffman decode work is tracked separately from wrapper overhead. `BufferedBitReader.readBits` and the chunked reader now consume via staged advance after `peekBitsPadded`, avoiding a second no-op fill on every length/distance extra-bit read; a targeted ReleaseFast `run-deflate-decode-stage-report -- --repeat 5 --iterations 200 README.md docs/roadmap.md` probe showed README caller-buffer rows around raw/zlib/gzip `583.47` / `591.37` / `452.22` MiB/s and roadmap `414.27` / `408.57` / `355.41` MiB/s after this change, though full repeat3 Rust summaries remain noisy and should still be used before claiming broad wins. Raw/zlib and PNG streaming decode also read the DEFLATE `BFINAL+BTYPE` block header as one 3-bit field at block boundaries, a narrow reader-call reduction that keeps Huffman/distance policy unchanged and was validated with the repeat3 decode-stage, PNG streaming zlib, and chunked zlib gates. A follow-up experiment that added reader `hasStagedBits` and used it in Huffman fast-hit checks was reverted because the same targeted probe was mixed to negative: README raw/zlib/gzip caller-buffer rows were about `528.80` / `533.43` / `468.85` MiB/s versus the restored baseline `575.38` / `544.94` / `492.31`, while roadmap was only marginally mixed (`417.34` / `398.00` / `363.51` versus `409.90` / `406.48` / `336.61`). Keep full `hasBits` in Huffman fast-hit validation unless a future branch can prove a robust win. Keep the generic length/distance extra-bit `readBits` path as well: a narrower `readBitsStaged` experiment for extra bits was reverted because the same targeted probe was again mixed, with README raw/zlib/gzip caller-buffer rows around `569.12` / `577.16` / `312.49` MiB/s versus restored baseline `600.98` / `580.87` / `497.26`, while roadmap was only marginally mixed (`421.49` / `412.18` / `360.67` versus `412.73` / `408.42` / `356.00`). A follow-up unchecked length/distance helper experiment, used only after Huffman had already constrained symbol ranges, was also reverted: README raw/zlib/gzip caller-buffer rows were about `523.28` / `510.36` / `443.50` MiB/s versus baseline `578.45` / `577.80` / `488.84`, while roadmap was essentially mixed (`412.64` / `405.77` / `353.73` versus `411.27` / `407.00` / `317.83`). PNG streaming zlib row decode now batches pending DEFLATE matches into scanline buffers instead of emitting every match byte through `readInflatedByteOrEnd`; it also batches 64+ byte Adler updates through the vectorized Adler helper. `run-png-streaming-zlib-bench-report-gate` validates the repeat3 CSV for the PNG streaming zlib benchmark, which tracks contiguous/chunked scanline throughput on RLE, small-distance, repeated-row dynamic/fixed, Up-filtered rows, and a wide-row RLE payload. The streaming history recorder skips bytes that would be overwritten inside the 32 KiB DEFLATE history ring before any later symbol can reference them; the first wide-row ReleaseFast gate row (`png-stream-wide-rle-dynamic`, 64 KiB rows) reports about `913.03` / `887.32` MiB/s contiguous/chunked while retaining the row-repeat floors above 700 MiB/s. PNG scanline reconstruction now special-cases None and Up filters; a same-machine ReleaseFast A/B against `4326e9e` on `run-png-streaming-zlib-bench-report -- --repeat 5 --iterations 512` moved the existing streaming rows by about `1.4x` to `2.6x`, and the new `png-stream-up-filter-dynamic` row reports about `2310.68` / `2215.34` MiB/s contiguous/chunked with 1000 MiB/s ReleaseFast floors. The same benchmark now includes `png-stream-sub-filter-dynamic`, `png-stream-average-filter-dynamic`, and `png-stream-paeth-filter-dynamic` rows for the remaining non-filter0 predictors; an Average-specific reconstruction path improved the Average row by about `1.190x` contiguous and `1.019x` chunked in a same-machine `--repeat 5 --iterations 512` A/B, so Average now has conservative 250 MiB/s ReleaseFast floors. Sub reconstruction now dispatches directly to a dedicated Sub loop instead of the generic per-byte filter switch, with vector-sized left-neighbor steps for bpp=1/4/8; focused ReleaseFast scanline rows in the same environment moved Sub bpp=1/4/8 from old evidence around `917.55` / `865.89` / `1124.76` MiB/s to about `3437.59` / `2250.69` / `4351.40` MiB/s, while bpp=2/3/6 stay on the scalar Sub loop because fixed-vector variants were not consistently faster. `run-png-scanline-bench-gate` now adds a lower-level reconstruction-only CSV (`zig-out/vort-png-scanline-bench.csv`) for filters 0..4 and bpp 1/2/3/4/6/8, keeping predictor work visible without zlib/Huffman noise; ReleaseFast runs enforce conservative floors for the optimized Up, Sub, and Average rows plus low-noise floors for optimized Paeth rows while Debug runs remain structure-only smoke checks. A dedicated Paeth bpp=1 path for indexed/low-bit grayscale payloads preserved alias-safe Adam7 in-place reconstruction and moved focused ReleaseFast median throughput from about `222.37` to `281.94` MiB/s (`+26.79%`) in alternating same-machine A/B runs. A follow-up wider Paeth split now covers RGB/RGBA-style rows: focused scanline medians for bpp=4/6/8 improved by about `+27.85%` / `+24.28%` / `+24.36%`, and the new end-to-end `png-stream-paeth-rgba8-dynamic` row improved contiguous/chunked medians from about `385.37` / `374.97` MiB/s to `523.11` / `505.76` MiB/s with conservative ReleaseFast floors. A further fixed-bpp Paeth dispatch removes the runtime stride branch inside bpp=3/4/6/8 Paeth rows; the clearest short ReleaseFast scanline signal was bpp=4/6/8 moving from about `554.68` / `561.18` / `575.05` MiB/s to about `708.27` / `738.92` / `713.77` MiB/s, with bpp=3 positive but treated as lower-confidence evidence. PNG streaming dynamic literal decode now applies the same <=9-bit small-alphabet table policy as general inflate while capping PNG streaming state at 11-bit for complex alphabets; a ReleaseFast `run-png-streaming-zlib-bench-report -- --repeat 5 --iterations 1000` A/B against the previous fixed 11-bit PNG streaming decoder showed about `1.007x` geomean throughput across contiguous/chunked rows, with dynamic RLE `1054.21/1045.30 -> 1056.66/1054.55` MiB/s, small-distance `923.09/1038.32 -> 931.67/1062.89` MiB/s, and repeated-row dynamic `154.51/152.78 -> 154.11/153.84` MiB/s. A full 12-bit PNG streaming variant was also probed and not kept because the larger resident decoder state gave mixed/noisy results and regressed RLE and repeated-row rows in the longer A/B. A follow-up attempt to inline the PNG streaming `readInflatedBytes` payload loop and bypass `readInflatedByteOrEnd` for literal/stored bytes was also not kept: the ReleaseFast `run-png-streaming-zlib-bench-report -- --repeat 5 --iterations 1000` A/B was mixed, with the all-path variant around `0.995x` geomean and the contiguous-only variant around `0.993x`; small-distance contiguous improved, but chunked small-distance and/or RLE rows regressed enough to reject the change. A profile-backed FastDecoder init experiment was also reverted/kept out of production: a `max_bits > lookup_bits` guard and a broader lookup-coverage prepass avoided duplicate sparse-table fills in theory but produced mixed repeat3 decode-stage results, including slower README/gzip and text/raw rows in local probes. The lookup coverage fields remain in the profile so the next table-setup change can target actually sparse cases rather than guessing. The same profile now splits match bytes into RLE, small-distance, non-overlapping memcpy, and overlapping replay classes. The latest local profile shows README/roadmap matches are dominated by non-overlapping copies (about `97.68%` / `99.77%` of match bytes), while synthetic text/dynamic-match fixtures are almost entirely overlapping replay and binary is non-overlapping. That means future match-copy and extra-bit optimizations should be corpus-specific instead of assuming one replay style dominates all dynamic blocks; per-class extra-bit fields now show whether those reads belong to the non-overlap or overlap side of the payload loop. Two narrow non-overlap copy A/Bs were measured and rejected: manual small-length copy improved README in one run but regressed roadmap and dynamic-match, while moving the non-overlap branch ahead of small-distance copy badly hurt README raw decode and did not provide a robust roadmap win. A distance-code formula experiment, replacing the distance table lookup for symbols >= 4, was also rejected: synthetic text/dynamic-match/binary improved in one repeat3 probe, but README raw/zlib/gzip decode regressed sharply and roadmap zlib regressed. Keep the table-based distance decode until a corpus-safe variant is found. The
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
Stored/binary allocation remains a wrapper-path weak spot rather than a raw inflate-copy problem. The current repeat3 decode-stage smoke still shows `stored-binary` caller-buffer raw decode far ahead of allocator-returning wrapper rows (for example raw/zlib/gzip into around `44493.96` / `18157.05` / `2343.17` MiB/s in the pre-experiment probe), while zlib/gzip allocator rows are much lower due to wrapper validation, checksum, and owned-slice allocation work. A single-pass stored-only allocator experiment that allocated an upper-bound buffer and shrank after copying/checksum was rejected: the same focused probe moved `stored-binary` raw/zlib/gzip alloc rows to about `3505.68` / `3011.80` / `1458.99` MiB/s, below the baseline `3768.88` / `3294.87` / `1480.92` MiB/s. An IEEE CRC-32 x86/PCLMUL dispatch attempt was also rejected before enablement because the existing hardware path failed a scalar/table differential check (`123456789`-style cases did not match). Future stored-wrapper work should therefore target a correct faster CRC-32 implementation, exact-size/known-size allocator APIs, or wrapper-specific allocation policy rather than another plan/copy fusion.
The decode-stage report now includes explicit `raw_stored_mib_s`, `raw_stored_exact_mib_s`, `raw_stored_into_mib_s`, `zlib_stored_mib_s`, `zlib_stored_exact_mib_s`, `zlib_stored_into_mib_s`, `gzip_stored_mib_s`, `gzip_stored_exact_mib_s`, and `gzip_stored_into_mib_s` columns, plus stored-specific allocation time ratios, so the generic wrapper alloc path can be compared directly with the explicit stored APIs on the `stored-binary` row. In the first dashboard refresh after adding the original stored alloc/into columns, `stored-binary` reported about `3740.76` / `3294.28` / `1472.14` MiB/s for raw/zlib/gzip stored alloc, making the zlib path roughly equal to generic zlib alloc while gzip remains CRC-bound. IEEE CRC-32 now also has a portable slice-by-32 table path and `crc32Best` dispatches to it instead of slice-by-16 while x86 PCLMUL remains disabled; the first ReleaseFast checksum smoke on the local machine moved CRC-32 best from about `2493.10` MiB/s to about `2971.17` MiB/s with identical digest mixes, and gzip stored/raw-stored hash paths use the same slice-by-32 state for their stored-only fast paths. The same ReleaseFast decode-stage smoke now shows the `stored-binary` generic gzip alloc and explicit gzip stored alloc rows around `1609.57` / `1622.22` MiB/s, up from the earlier `~1486` / `~1472` MiB/s evidence while still far behind caller-buffer stored copy. Explicit `decodeGzipStoredAlloc` now also tries the gzip trailer ISIZE as an exact allocation hint before falling back to the stored planner path, so ordinary single-member stored gzip streams copy and compute CRC in one pass; a local ReleaseFast stage smoke after that change reported `stored-binary` gzip exact/gzip stored rows around `1629.90` / `1627.90` MiB/s. CRC-32C now has a matching portable slice-by-32 path: the ReleaseFast checksum smoke reported `crc32c-slice32` around `2967.36` MiB/s versus the prior portable `crc32c-slice16` baseline around `2478.71` MiB/s, and `crc32cBest` uses slice-by-32 on machines without SSE4.2 while still dispatching to hardware when available.
Stored-only header parsing has a shared byte-level BTYPE predicate and a single
little-endian LEN/NLEN word load for contiguous stored paths. The same
ReleaseFast repeat3 stage probe that motivated this change now folds stored-only
throughput columns into median selection when populated, avoiding median samples
that are good for generic inflate but noisy for explicit stored APIs. The first
local post-change probe kept `stored-binary` explicit raw/zlib/gzip stored
allocator rows in the same class as baseline (roughly `3787` / `3333` / `1633`
MiB/s in that run) while preserving caller-buffer stored rows around the
copy/checksum limits; future stored-wrapper wins still need either a stronger
CRC-32 path or allocation-policy work rather than another full planner/copy
rewrite.
Stored exact-size allocation APIs now exist for raw/zlib/gzip stored wrappers
(`decodeRawStoredAllocExactSize`, `decodeZlibStoredAllocExactSize`,
`decodeZlibStoredAllocWithDictionaryExactSize`, and
`decodeGzipStoredAllocExactSize`). They allocate the caller-declared exact output
size and decode/checksum directly into it, returning `SizeMismatch` when the
declared size is too small or too large. The decode-stage `*_stored_exact_mib_s`
rows keep this path visible beside allocator-returning and caller-buffer stored
rows, which is useful for applications such as image decoders that already know
the uncompressed image size. The first local ReleaseFast repeat3 probe after
adding these rows reported `stored-binary` raw/zlib/gzip stored exact rows around
`3760.19` / `3318.66` / `1642.13` MiB/s, essentially matching the explicit
stored allocator rows while keeping exact-size mismatch checks visible.
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

## Adler-32 AVX2 evidence (2026-08-15)

The Adler implementation now lives in `src/checksum/adler.zig` rather than
continuing to grow the general checksum facade. Portable targets retain the
64-byte u32-vector reference kernel. AVX2 targets use the same 32-byte narrow
lane decomposition as `simd-adler32` 0.3.9:

- `VPSADBW` accumulates the first Adler sum;
- `VPMADDUBSW` and `VPMADDWD` accumulate the weighted second sum;
- three vector accumulators retain the per-block sum, weighted sum, and
  cross-block prefix contribution for a complete 5,536-byte chunk;
- the main loop handles eight 32-byte blocks per turn and performs horizontal
  reductions only at the chunk boundary.

The AVX2 kernel remains a `noinline` implementation boundary. An earlier inline
candidate reached high standalone throughput but changed PNG decode code layout
enough to regress a 128-pixel icon by about 3–5%. Keeping the 0x372-byte kernel
out of each caller and unrolling internally recovered both locality and checksum
throughput. `bestAdler32Backend` and the checksum smoke header expose whether the
compiled target selected `portable` or `avx2`.

On the i9-13900K, Zig 0.16.0 ReleaseFast, fixed CPU 6, nine alternating old/new
rounds over the existing 1 MiB × 128 checksum workload measured:

- old portable-vector median: `29,392.73 MiB/s`;
- new AVX2 median: `53,327.73 MiB/s`;
- paired median/geomean: `1.67798x` / `1.72238x`;
- worst paired round: `1.45921x`.

The production imx PNG binary was then compared against the committed old
binary over all 15 image-png fixtures, fixed CPU 6, seven alternating rounds.
Strict `decode-into` improved from `775.61` to `781.98 MiB/s` by independent
medians (`1.00821x` aggregate, `1.01063x` fixture geomean, `1.01303x` fixture
median). The weakest independent fixture medians were `0.99800x` for Lohengrin
and `0.99854x` for `kodim07`; 15-round focused repeats measured `1.00175x` and
`1.00700x`. A separate 15-round `paletted-zune` strict repeat measured
`1.00562x`. This is a strict-checksum improvement, not evidence that PNG decode
as a whole surpasses image-png.

Correctness evidence includes known zlib vectors, a scalar oracle at
32/64/256/NMAX boundaries and four input alignments, fragmented streaming
updates, the all-`0xff` NMAX case, generic x86_64 and AArch64 portable builds,
Zig standard-library differential checks, and black-box Python zlib/system gzip
differentials.

## Rejected image-png Paeth ports (2026-08-16)

An instruction profile of the 300x300 RGBA8 `Transparency.png` fixture put
Vort's scanline reconstruction at the top of the remaining PNG decode costs:
Paeth accounted for about 21.6% of imx instructions, Up for about 8.1%, Sub for
about 4.6%, and AVX2 Adler for about 7.1%. The corresponding image-png
`4ab5484` single-fixture profile spent about 20.0% in all PNG unfiltering
combined. This motivated a direct source and generated-code audit of
image-png's stable and optional SIMD Paeth paths rather than another DEFLATE
table-layout experiment.

The stable x86_64 image-png implementation keeps one `[i16; BPP]` left pixel
and one upper-left pixel and uses the same stb_image threshold predictor already
present in Vort. The important generated-code difference was image-png's compact
four-lane word loop versus Vort's larger scalarized call graph. An explicit
`@Vector(4, i16)` RGBA kernel made Zig 0.16 emit the intended
`vpmovzxbw`/`vpminsw`/`vpmaxsw`/`vpblendvb`/`vpaddb` sequence. Its
reconstruction-only results were real:

- 128/32/16-pixel RGBA fixtures improved by about `1.0557x`, `1.1409x`, and
  `1.2344x` aggregate in a 31-round fixed-CPU-6 run;
- `Transparency.png`, where only 11 of 300 rows are Paeth, improved about
  `1.0198x`;
- a 101-round lorem screenshot confirmation was `1.0115x` aggregate.

It was not accepted. In the complete decoder, inlining or routing all bpp=4
rows through the new kernel produced repeatable losses on non-target work:
`Transparency.png` reached only about `0.9974x` in a 101-round confirmation,
and noinline/all-row variants kept 128-pixel or Transparency rows around
`0.996x`. Narrow width dispatch recovered roughly `1.04x` on 16/32-pixel icons
but still moved unrelated code enough to regress wider images. An explicit
Vort drainer and imx-only dispatch eventually delivered about `1.053x` on both
small icons, yet the full 15-fixture run exposed RGB Exoplanet and Fantasy at
`0.9904x` and `0.9932x`; 101 focused rounds confirmed `0.9921x` and
`0.9920x`. ELF `linksection` isolation moved the new bodies out of `.text`, but
their unwind metadata still shifted the main text base, so it did not provide a
clean production boundary.

The image-png optional portable-SIMD bpp=3 implementation was also ported in
both relevant forms. A pixel-at-a-time four-lane expression generated compact
XMM predictor instructions but reconstructed Fantasy at only about `728 MiB/s`.
The closer 48-byte/16-pixel pump, including deferred wide add/store, measured
about `709 MiB/s`. The committed stable-style Vort kernel is about
`1,075 MiB/s` on the same fixture. Zig's lowering of the 48-lane temporary and
predictor staging therefore does not reproduce Rust/LLVM's optional-SIMD win.
Both ports and all dispatch experiments were fully reverted.

Do not retry these exact shapes unless Zig's vector lowering or linker section
ordering materially changes. The next Paeth investigation needs a different
code-generation strategy—most plausibly target intrinsics/assembly in an
already-existing hot boundary, or profile-guided function ordering—while the
larger remaining PNG gap still includes Vort's semantic DEFLATE loop. Local
kernel throughput is not sufficient evidence when a non-target real fixture
regresses.

## Up-dominant whole-image PNG reconstruction (2026-08-16)

The real 300x300 RGBA8 `Transparency.png` fixture uses filter Up on 274 of
300 rows (91.3%), with 15 Sub and 11 Paeth rows. Vort's existing Up kernel was
already a 32-byte vector add, so this change does not duplicate or replace that
kernel. Instead, a narrow whole-image path avoids the generic filter enum,
shape, and error-union dispatch on proven Up rows while retaining the generic
reference path for the mixed rows.

The specialization is isolated in `src/png/up_dominant.zig` rather than growing
the 20K-line DEFLATE facade. It is considered only for 8-bit RGBA images with
rows at least 1 KiB and at least 128 rows, then requires rows 1...15 to be Up.
The real 15-file image-png corpus therefore selects only `Transparency.png`.
The implementation lives in a dedicated executable section on ELF/Mach-O/COFF;
the fallback caller remains a narrow noinline boundary.

Independent tests cover the size/color policy, prefix hit and miss, first-row
non-Up behavior, a 257-byte vector tail, later mixed Paeth and Up rows,
in-place-safe scalar Up equivalence, and an invalid filter after the accepted
prefix. The active and disabled-policy ReleaseFast binaries have byte-identical
`.text` and `.rodata` sections, identical function addresses/sizes, and an
identically sized 1,257-byte specialization section. Only the comparison value
inside that isolated section differs.

Thirty-one alternating fixed-CPU-6 active/control rounds over all 15 PNGs show
the selected `Transparency.png` row at `1.0071x` strict and `1.0072x`
no-Adler by independent medians. All no-Adler non-selected medians stay within
`0.9985x...1.0029x`; aggregate throughput is `0.99987x`, fixture geomean
`1.00077x`, and median `1.00008x`. Separate hardware-counter rounds show the
specialized path reduces instructions by about 1.3--1.5% and branches by about
2.1--2.3%; cycles improve about 0.3--0.5%. This is a small targeted win, not a
claim that PNG decode has reached image-png parity.

Several superficially promising variants were rejected rather than folded into
the result. A 64-byte two-vector Up loop reduced instructions and branches but
did not reduce cycles. Two-row and four-row vertical pipelines reduced
instructions by roughly 3--4% but lengthened the dependency chain and regressed
cycles/end-to-end time by about 5--7%. Grouping consecutive Up rows without
vertical vector chaining also increased instruction count and did not beat the
simpler per-row specialization.

A final horizontal-tail candidate kept the accepted 32-byte Up loop and added
one 16-byte vector add before the scalar remainder. This is the shape LLVM uses
for the real 1,200-byte `Transparency.png` rows: 37 YMM iterations plus one XMM
tail, with no scalar bytes. A scalar/sentinel oracle covered the standalone
15/16/17 and 31/32/33 thresholds, combined YMM/XMM thresholds through 65 bytes,
and 1,199/1,200/1,201-byte real-row boundaries.

Same-source causal binaries used a benchmark-only terminal reserve in
`.vort_png_up_dominant`: the active binary retained a one-byte `ret`, while the
control retained 32 `nop` bytes plus `ret`. Both isolated sections were 1,290
bytes. All runtime section addresses and metadata matched; shared `.text`,
`.rodata`, RLE258, indexed-decode, and other allocatable section bytes were
identical. The only companion difference was three bytes in the isolated
function's own FDE range/epilogue description; the reserve itself had no FDE.

Thirty-one fixed-CPU-6 target counter rounds were positive. Strict paired
median elapsed/cycles/instructions improved
`1.00635x/1.00858x/1.00977x`; no-Adler improved
`1.00938x/1.00912x/1.01135x`. Non-selected `kodim17.png` remained effectively
neutral. The corpus gate nevertheless rejected the change. Because unrelated
Lux/Cangjie builds were recurring, each of the 30 stage/fixture items used its
own complete 31-round alternating batch; a 50 ms process monitor discarded
the complete item and restarted it whenever a compiler, generated test runner,
or low-idle guard appeared. Only after all 15 strict and 15 no-Adler items
completed did the report become valid.

`Transparency.png` improved `1.00982x` strict and `1.00510x` no-Adler, and
fixture geomeans were about `1.00046x` / `1.00047x`. However, sums of the 15
independent fixture median times regressed to `0.99960x` / `0.99950x`.
The weakest short batches were strict indexed Exoplanet at `0.99615x` and
no-Adler non-indexed Exoplanet at `0.99424x`. A guarded 101-round confirmation
cleared the strict row (`1.00093x` paired median), but the no-Adler row remained
slightly negative: `0.99866x` paired median, `0.99905x` independent-median
ratio, and `0.99952x` paired geomean. The vector tail and its candidate-only
oracle were fully reverted. Do not retry this exact 16-byte tail shape unless
the design also removes the observed aggregate/non-target sensitivity; a local
target win is not sufficient.

A broader image-png-inspired buffering experiment was then tested instead of
another reconstruction micro-kernel. Rust image-png incrementally inflates into
an `UnfilteringBuffer`, keeps the immutable 32 KiB DEFLATE lookback, and
unfilters complete mutable rows in place. Vort's established throughput path
instead inflates the complete filtered image and then reconstructs into final
pixels; its bounded streaming path keeps a separate history ring and row
buffers. The candidate tried a third layout: write reconstructed pixels
directly to final output, retain one current residual row plus row-filter bytes,
and recover historical residual bytes by applying the inverse PNG predictor to
already reconstructed rows. It therefore needed neither a full 360.3 KiB
filtered image nor a duplicate 32 KiB history ring.

A read-only token-position parser first justified the experiment. It matched
Python zlib's 360,300-byte output and classified all 1,518 matches in
`Transparency.png`: 60.6% of match bytes are distance-one RLE, 54.4% are
258-byte RLE matches entirely inside target Up rows, 91.1% target Up rows, and
95.9% have the same source/target row filter. There are no non-RLE overlapping
matches. An isolated sink oracle covered literals, distance-one replay,
whole-row matches crossing both filter-byte boundaries, later mixed Paeth rows,
complete output, and strict filtered-stream Adler-32.

The production probe remained deliberately narrow: RGBA8/size policy, one
final dynamic block, the accepted 12/9-bit canonical-table shape, and the same
15-row Up prefix. The direct-history sink lived under
`png/up_dominant/direct.zig` rather than growing the facade, while DEFLATE kept
only parsing and semantic-loop dispatch. Real strict and no-Adler decodes
produced the exact expected output. Performance was decisively worse. The first
generic sink reached only about `1,167 MiB/s` no-Adler. Routing the proven
two-bit RLE258 pair through a dedicated sink entry improved the candidate by
`1.1686x`, to about `1,363 MiB/s`, but the committed same-layout control median
is about `2,781 MiB/s`; the final ratio was only `0.4903x`.

The saved scratch traversal could not compensate for residual-history mapping,
row-state handling, and reconstruction inside every semantic match. A
diagnostic counter batch was discarded when the host busy guard fired, but it
is not needed for the rejection: even the checksum-free end-to-end upper bound
was roughly half the committed path. The API, imx dispatch, semantic sink
instance, 520-line candidate module, and tests were fully reverted. Do not
retry reconstructed-output-as-filtered-history without a representation that
keeps ordinary RLE/non-overlap match emission as cheap as the current linear
inflater; merely eliminating the filtered allocation is insufficient.

## Canonical RLE258 semantic pair (2026-08-16)

The same `Transparency.png` profile exposes a second narrow shape in its single
dynamic DEFLATE block: 1,280 of 1,518 length symbols are 285 (length 258), 915
distance symbols are zero (distance one), and 60.6% of all matched bytes are
RLE. Both symbol 285 and distance symbol zero own canonical one-bit code zero.
The common length-258/distance-one match is therefore exactly the two low zero
bits of the semantic reservoir.

Vort now proves that pair from the canonical tables in O(1), only for a final
dynamic block with the observed 12-bit literal and 9-bit distance table shape.
The selected semantic-loop instance consumes both bits together and emits the
existing fixed-width 258-byte repeated-byte fill. It does not alter match-copy
semantics, and all other table shapes retain the original semantic loop.

Policy and executable-section ownership live in
`src/deflate/semantic/rle258.zig`; the large DEFLATE facade retains only the
tightly coupled loop instance and block dispatch. The complete specialized
loop is emitted into `.vort_png_rle258`, while ordinary semantic loops keep
their prior generated-code shapes. Tests prove the exact canonical table
requirements and compare the specialized and ordinary loops byte-for-byte,
including consumed-bit and reader-byte-offset state.

Thirty-one alternating fixed-CPU-6 active/control counter rounds use binaries
with byte-identical `.text` and `.rodata`. On `Transparency.png`, the policy
improves no-Adler elapsed time by `1.034x`, cycles by `1.031x`, instructions by
`1.044x`, and branches by `1.040x`. A non-selected `kodim17.png` control stays
within about `0.9997x...1.0007x` across elapsed/cycles/instructions/branches.
The final 15-file active/control gate improves `Transparency.png` by `1.033x`
strict and `1.031x` no-Adler; aggregate/geomean are positive and the worst
no-Adler non-target independent median is `0.9979x`.

Two broader versions were rejected. Putting the pair branch in every semantic
loop improved `Transparency.png` but regressed indexed Exoplanet and kodim17.
Selecting every matching dynamic block isolated the loop but left a small
multi-block indexed fluctuation; requiring the profitable final 12/9-bit table
shape keeps the accepted policy to the profiled single-block workload.

Two post-integration follow-ups were also rejected. Enabling the existing
inline non-overlap `memcpy` branch inside only the isolated RLE258 instance
slightly reduced instructions and branches, but fixed-CPU-6 counters put
strict/no-Adler elapsed ratios at about `0.996x/0.990x` and cycles at
`0.999x/0.998x`; fewer instructions did not improve execution time.

The fixed 258-byte fill was then profiled separately. LLVM lowers its four
64-byte body vectors to eight AVX2 stores, while the generic helper's
speculative tail adds two more 32-byte stores even though only two logical
bytes remain. An exact-tail candidate retained the 256-byte vector body and
wrote bytes 256 and 257 exactly. A redzone oracle covered all 64 starting
alignments and four byte values, and the existing specialized/reference
decoder oracle continued to compare output and reader state.

The causal binaries used a benchmark-only alignment fence inside
`.vort_png_rle258`: shared `.text`, section addresses, and the following
Up/indexed executable sections were byte-identical. Shared `.rodata` differed
only in one 16-byte, four-entry computed-jump table referenced exclusively by
the isolated RLE258 function; after normalizing that proven companion table,
the rest of `.rodata` was byte-identical. Thirty-one fixed-CPU-6 counter rounds
showed real target gains: strict elapsed/cycles/instructions improved
`1.0081x/1.0055x/1.0075x`, and no-Adler improved
`1.0123x/1.0111x/1.0094x`. Non-selected `kodim17.png` remained effectively
neutral.

The required 31-round, 15-fixture gate still rejected the candidate.
`Transparency.png` improved `1.0064x` strict and `1.0062x` no-Adler, but
aggregate throughput regressed to `0.99922x/0.99935x`. Strict indexed
Exoplanet fell to `0.99594x`, and the no-Adler 32-pixel icon fell to
`0.99793x`. The exact-tail implementation and its test were fully reverted;
the generic speculative tail remains production behavior. Do not retry this
store schedule without a design that also avoids the observed non-target
layout/cache regressions.

A separate read-only DEFLATE parser then measured consecutive canonical
length-258/distance-one pairs before changing the loop again. Python zlib
independently validated every complete output length across all 15 PNG bench
fixtures. The selected final 12/9-bit `Transparency.png` block contains 783
pairs in 287 runs: lengths one/two/three/four occur 96/6/65/120 times, and no
run exceeds four. A four-pair decode can therefore cover 480 pairs (`61.3%`)
without broadening the accepted dispatch. Exoplanet has longer runs, but its
multi-block/table shapes intentionally remain outside this specialization.

An inline batch-four candidate tested the low eight reservoir bits, consumed
four canonical pairs together, and emitted one 1,032-byte repeated-byte fill.
Differential tests covered zero through nine adjacent pairs, including every
one-to-three-pair remainder and two complete batches, while comparing output,
consumed bits, and reader byte offsets with the ordinary semantic loop.
ReleaseFast generated the intended one-byte reservoir advance, but expanded
the fill into 32 AVX2 stores plus one speculative tail.

The same-source causal binaries used a benchmark-only 8 KiB section fence:
ordinary `.text`, following Up/indexed sections, section addresses, and total
section sizes were identical. The only shared `.rodata` differences were the
same four-entry computed-jump table referenced exclusively by the isolated
RLE258 function. Thirty-one fixed-CPU-6 rounds rejected the candidate before a
corpus gate. Strict elapsed was only `1.0009x`, while cycles/instructions
regressed to `0.9974x/0.9935x`; no-Adler elapsed/cycles/instructions were
`0.9955x/0.9986x/0.9933x`. Branches improved about `1.017x`, but the expanded
bulk fill cost more than the saved loop control. The candidate was fully
reverted. Do not retry inline batch-four filling; any follow-up needs a
materially different out-of-line bulk-fill code-generation boundary.

That remaining boundary was tested as well. A standalone Zig 0.16 probe and
the production ReleaseFast artifact both lowered a noinline fixed 1,032-byte
helper to a 20-byte pointer adjustment followed by a tail jump to
`compiler_rt.memset`; the semantic loop retained just one call instead of 32
expanded vector stores. The same zero-through-nine-pair oracle passed. A
same-source control retained the otherwise dead helper explicitly, while the
8 KiB fence kept ordinary `.text`, following hot sections, addresses, and
sizes identical. The three differing `.eh_frame` bytes described only the
isolated function's FDE end/epilogue positions, and five `.rodata` bytes
remained inside its proven four-entry computed-jump table.

The out-of-line shape was substantially worse. Thirty-one fixed-CPU-6 rounds
measured strict elapsed/cycles/instructions at
`0.8862x/0.8883x/0.8970x`, and no-Adler at
`0.8799x/0.8871x/0.8908x`; branch ratios were also about `0.918x`.
Non-selected `kodim17.png` stayed neutral. The call forces the register-heavy
semantic loop to save/restore live state, while generic memset adds its own
loop control, overwhelming the four-pair branch reduction. The helper and all
batching code were fully reverted. Decode-side consecutive-pair batching is
closed for both inline and noinline fill boundaries unless a future target has
materially different calling convention or bulk-store support.

A final decode-side run-grouping candidate kept every existing 258-byte fill
unchanged. It processed at most four adjacent pairs in a bounded inner loop,
reused one repeated-byte broadcast, and moved reservoir refill plus the next
literal-table lookup to the run boundary. Zero-through-nine-pair differential
tests covered every run length, remainders, and a run continuing into the next
outer iteration. ReleaseFast preserved the original eight AVX2 body stores and
speculative tail per pair, while reusing the YMM value at offsets `+0x102`,
`+0x202`, and so on.

Same-source 8 KiB-fenced binaries again had identical ordinary `.text`,
following hot sections, addresses, and sizes; the only shared `.rodata`
differences were the isolated four-entry jump table. Thirty-one fixed-CPU-6
rounds rejected the candidate before a corpus gate. Strict
elapsed/cycles/instructions were `0.9944x/0.9952x/0.9960x`, and no-Adler
were `0.9977x/0.9956x/0.9954x`. Branches improved about `1.010x` and branch
misses 6--9%, but the bounded inner-loop/register-pressure cost exceeded the
saved refill and lookup work. Non-selected `kodim17.png` remained near
neutral. The candidate was fully reverted. RLE258 store scheduling, exact
tails, inline/noinline batch four, and consecutive-run grouping are all closed
on this target; further PNG work must return to a broader profiled bottleneck.

A fresh committed-binary DWARF callgraph profile then resolved the prior flat
`memcpyFast` sample. All of its user-space caller frames lead through
`decodeSemanticDynamicBlockIntoRle258BufferedReader -> copyMatchAt`; it is not
a PNG transform or temporary-buffer copy. The profile attributes about 16.0%
self cycles to the isolated loop, 4.6% to `memcpyFast`, 8.0% to generic Paeth,
5.5% to the Up-dominant reconstruction section, and about 0.8--0.9% each to
literal-table construction and dynamic-length parsing. This closes memcpy as a
new direction because the isolated non-overlap integration has already failed
its counters gate.

Token joint-distribution analysis found one last metadata-only opportunity in
the selected block. Symbol 285 occurs 1,280 times: 783 are the accepted
two-bit distance-one pair, while 497 use other distances. Those non-pair
distances are led by symbols 20/16/17 at 299/86/48 occurrences. Because the
canonical-table proof already makes the low one bit uniquely identify symbol
285, a candidate directly assigned code bits/base/extra as `1/258/0` and then
reused the complete existing distance/copy path. A distance-two non-pair
oracle joined the pair oracle and compared all output and reader state.

The final source shape used one low-bit branch around the complete old slow
path; ReleaseFast emitted exactly one test and reduced the isolated loop from
about 3,770 to 3,751 bytes. Same-source fenced binaries retained identical
ordinary `.text`, following hot sections, addresses, and normalized
`.rodata`. Thirty-one fixed-CPU-6 rounds still rejected it before a corpus
gate. Strict elapsed/cycles were only `1.0021x/1.0004x`, while
instructions/branches regressed to `0.9985x/0.9914x`; no-Adler measured
`0.9991x/1.0007x/0.9986x/0.9913x` for
elapsed/cycles/instructions/branches, with worse branch misses. Non-selected
`kodim17.png` stayed neutral. The candidate was fully reverted. RLE258
metadata, copy, store, batch, and run-grouping follow-ups are now closed on
this target.

The earlier image-png four-lane RGBA Paeth source shape was retested behind the
new Up-dominant executable-section boundary, which is materially narrower than
the previously rejected broad dispatches. A scalar oracle covered lengths
0...257 plus disjoint and in-place reconstruction, and ReleaseFast generated
the expected `vpmovzxbw`/`vpminsw`/`vpmaxsw`/`vpblendvb` loop. Same-layout
active/control counters reduced instructions by 17--19%, but improved cycles by
only about 0.1--0.6% and elapsed by roughly 0.2--0.7%. The 31-round corpus gate
then measured only `1.0005x/1.0030x` strict/no-Adler on the target fixture,
while strict aggregate/geomean regressed to `0.9952x/0.9984x`. The complete
candidate was reverted. Even under a clean isolated boundary, this dependency-
bound Zig vector shape does not provide a reliable end-to-end win.

## Rejected fdeflate match overcopy integration (2026-08-16)

A source audit against image-png's `fdeflate` 0.3.7 backend found that Vort's
buffered semantic loop already has the major structural pieces: four-entry
prefetch, three semantic literal groups per iteration, paired-literal handling,
unified match-bit consumption, and 16 bytes of input/output fast-loop
headroom. The remaining concrete difference was fdeflate's speculative
16-byte match copy.

The focused match-copy benchmark now keeps an `overcopy16` kernel as explicit
evidence. It snapshots and stores 16 bytes at a time, permits up to 15
speculative bytes after the logical match, and compares/checksums only logical
output bytes. `--case` and `--kernel` filters permit fixed-case hardware-counter
probes without changing the aggregate 28-row CSV contract. Broad ReleaseFast
screening showed why this cannot replace every production copy:

- non-overlapping lengths 3/6/32 were about `2.59x` / `2.68x` / `2.35x`
  faster than the current kernel;
- RLE was only about `1.03x`, overlapping distance 16 was positive, but
  overlapping distance 45 and distance 2 fell to about `0.40x` and `0.29x`.

A production candidate was therefore narrowed to exact-size zlib output,
dynamic blocks with distance code widths of at least 12, non-overlapping
matches, and lengths no greater than 16. Ordinary caller-buffer decode retained
exact stores, because writing speculative bytes after `output_written` would
violate its observable suffix contract. The candidate passed scalar match
oracles and exact-size/oversized-buffer sentinel tests. Code generation also
stayed isolated: existing semantic specializations remained `0xc90` and
`0xcc0` bytes, while only the exact-size specialization added a `0xcf0` body.

It was still rejected. On the match-heavy Fantasy PNG fixture, nine alternating
fixed-CPU-6 `perf stat` rounds showed a very stable instruction improvement:
the old/new instruction ratio median was `1.028824714x`. The corresponding
cycle ratio median was only `0.999749144x`, below the required greater-than-one
gate. One noisy round reinforced that instruction count alone is not enough to
claim a latency win. The production decoder and exact-size API changes were
fully reverted before commit; only the reusable benchmark/oracle and this
negative evidence remain. Do not retry the same short non-overlap
specialization without a materially different scheduling or copy shape.

## Rejected isolated RLE258 12/9 primary tables (2026-08-16)

The accepted RLE258 dispatch identifies a final dynamic block whose literal and
distance maximum widths are exactly 12 and 9 bits, but its semantic decoder
still uses the general 11/8 primary tables plus secondary lookups. This is not
the same experiment as the earlier broad semantic-12 policy: that policy
selected the separate fused decoder only when a block had at least 1,024
double-literal primary slots, while `Transparency.png` has only 277 and was
never selected.

A narrow candidate therefore built complete primary-only 12/9 semantic tables
only after the existing final-block and canonical RLE258 proof. The reusable
builder lived under `src/deflate/semantic/primary.zig` rather than enlarging the
DEFLATE facade. A synthetic complete max-12/max-9 tree exercised a 12-bit
literal, a 9-bit distance, an ordinary match, the two-bit RLE258 pair, and a
12-bit EOB; output bytes, consumed bits, and reader byte offsets matched the
established 11/8 secondary-table decoder. All 263 ReleaseFast Deflate tests
also passed.

Thirty-one fixed-CPU-6 alternating target rounds showed a small real signal.
Strict elapsed/instructions/branches improved by
`1.0022/1.0124/1.0321x`, but paired cycles were `0.9997x` and branch misses
regressed to `0.8139x`. No-Adler elapsed/cycles/instructions/branches improved
by `1.0100/1.0041/1.0169/1.0397x`, while branch misses were only `0.9718x`.
The active binary also grew the isolated section from 3,770 to 6,523 bytes and
changed ordinary `.text`, because it no longer constructed the old RLE258
decoder before dispatch.

The guarded corpus gate rejected the candidate. Each stage/fixture was a
separate complete 31-round alternating batch; any compiler or generated runner
restarted that item from round zero. Strict indexed Exoplanet measured
`0.995024x` from independent medians and `0.993418x` paired geomean.
No-Adler `lorem_ipsum_oxipng.png` measured `0.996983x` from independent
medians. Both are non-target regressions, so the remaining batches were not
used to manufacture an aggregate pass. The builder, wider loop, dispatch, and
candidate oracle were fully removed.

This closes the straightforward fdeflate-style table-width port for the
current RLE258 boundary. A future 12/9 design must materially change table
lifetime or storage—for example amortizing construction across repeated
decodes—rather than allocating and building wider primary tables once per
image.

## Bounded filtered-history PNG decode (2026-08-17)

The next accepted change addresses the whole-image data flow rather than
another DEFLATE micro-kernel. image-png's `UnfilteringBuffer` retains the last
32 KiB of raw filtered output for DEFLATE lookback and reconstructs complete
rows only after they become mutable. Vort's prior throughput path instead
inflated all 360,300 filtered bytes for `Transparency.png` before a second
reconstruction traversal; its bounded streaming path copied every retained
byte through a separate 32 KiB ring.

Vort now has an experimental whole-image helper for the already-proven final
dynamic 12/9-bit canonical RLE258 shape. A resumable direct semantic loop
pauses only at complete token boundaries. It appends into a contiguous 64 KiB
window, keeps the newest 32 KiB immutable, reconstructs older complete rows
into final output, and compacts only released row prefixes. Transactional tail
decode restores the exact bit reservoir when the next literal, literal pair,
or match does not fit. Strict Adler-32 is accumulated from original filtered
rows before reconstruction. Input, history, and output overlap is rejected,
and the public scratch contract is exported as
`png_windowed_rle258_history_scratch_len`.

This is distinct from the rejected reconstructed-output-as-history design:
ordinary DEFLATE matches still address raw filtered bytes in one linear
window. For the 300x300 RGBA8 fixture, bounded history replaces the 360,300
byte full filtered scratch with 65,536 bytes, removing 294,764 bytes plus the
complete second filtered-buffer traversal. Unsupported block/table shapes are
rejected before output is written so imx can fall back to the established
full-scratch path.

The lifecycle lives in the focused
`src/deflate/png/windowed_history.zig` module; public contract tests live under
`src/root_exports/png/`, while only the tightly coupled resumable semantic loop
remains in the large DEFLATE facade. ReleaseFast tests cover token-boundary
resume and reader state, whole-row release/compaction, short buffers, ordinary
tables, overlapping storage, and forged overflowing metadata. A real-fixture
probe compares strict and no-Adler candidate output against the independent
ring-streaming reference: all 360,000 bytes match, with CRC32 `2202190348`.

Final same-layout v6 binaries are the same size and have byte-identical
ordinary `.text`, `.rodata`, `.vort_png_rle258`, and
`.vort_png_up_dominant` sections. Only the isolated
`.imx_png_windowed` policy immediate differs. Thirty-one alternating
fixed-CPU-6 pairs per stage, with interrupted batches restarted from zero,
measure:

| `Transparency.png` stage | elapsed | cycles | instructions | branches |
| --- | ---: | ---: | ---: | ---: |
| strict decode-into | `1.163x` | `1.156x` | `0.802x` | `1.299x` |
| decode-into no-Adler | `1.197x` | `1.180x` | `0.817x` | `1.358x` |

Ratios are control divided by active paired medians. Active executes roughly
22--25% more instructions yet takes 15--18% fewer cycles, so this gain comes
from reduced memory traffic/dependency cost rather than instruction-count
reduction. The earlier complete 30-item corpus gate measured positive
strict/no-Adler aggregate ratios of `1.000183x/1.000912x` and fixture
geomeans of `1.009268x/1.012307x`; non-selected dimensions short-circuit
before the policy's differing color immediate.

## General bounded-history PNG decode (2026-08-17)

The bounded-history architecture now extends beyond the single canonical
RLE258 block. The general whole-image helper accepts arbitrary dynamic, fixed,
and stored block sequences while preserving one continuous raw-filtered
DEFLATE history across block boundaries. Complete canonical dynamic trees use
the resumable semantic loop; unsupported semantic-table shapes use a compact
transactional reference loop. Fixed blocks share that reference boundary, and
stored blocks are split into safe output segments when a maximal 65,535-byte
block cannot fit beside the retained lookback.

The minimum public scratch remains two DEFLATE windows (64 KiB). Vort exports a
four-window 128 KiB recommendation as
`png_windowed_history_scratch_len`; imx uses it to compact less often. A
1024x128 mixed-filter oracle forces more than one compaction and compares
multi-dynamic, multi-fixed, and multi-stored streams against the established
full-scratch image decoder. A second stored oracle uses only the 64 KiB
minimum. Wrapper coverage locks strict/ignored Adler, trailing data,
truncation, invalid filters, short scratch, and aliased storage.

All 15 image-png benchmark fixtures have non-interlaced row strides below the
32 KiB lookback limit, but performance evidence selects only large RGB8/RGBA8
images. Indexed images retain imx's in-place expansion, grayscale Lohengrin
retains its existing path, and the 300x300 RGBA8 workload retains the narrower
RLE258 specialization.

The final same-layout policy control keeps equal binary sizes and
byte-identical ordinary `.text`, `.rodata`, RLE258, Up-dominant, indexed, and
existing windowed sections. Seven selected fixtures completed independent
31-round fixed-CPU-6 batches for both checksum policies; interrupted items
were restarted from zero:

| stage | aggregate | fixture geomean | fixture median | minimum |
| --- | ---: | ---: | ---: | ---: |
| strict decode-into | `1.142x` | `1.121x` | `1.057x` | `1.044x` |
| decode-into no-Adler | `1.120x` | `1.109x` | `1.048x` | `1.028x` |

Strict RGB Exoplanet and RGBA screenshot improve `1.302x` and `1.306x`;
Fantasy's 65 dynamic plus one fixed block improves `1.077x`; all four Kodak
rows improve `1.044x...1.057x`. No-Adler remains positive on every selected
fixture.

Code organization was benchmarked as part of the change. Moving the hot
row-commit lifecycle behind a new cross-module function regressed RGB
Exoplanet, kodim07, and screenshot by roughly 1--2%, so that extraction was
rejected. `windowed_history.zig` continues to own the data structure and PNG
row lifecycle, while the token/commit driver remains beside the semantic loop
to preserve generated-code locality. General and RLE258 public-contract tests
are split under `src/root_exports/png/windowed/` instead of growing one flat
test facade.

The bounded-history driver now also defers compaction across non-final EOBs.
Compressed blocks already stop before a token whose output does not fit, and
stored blocks already split transactionally, so an EOB itself does not require
copying the retained history. A dynamic-to-maximum-stored-block oracle proves
the deferred transition byte-exactly. In 31 alternating fixed-CPU-25 rounds,
the seven selected imx PNG rows improve `1.036x/1.034x` geomean for
strict/no-Adler decode. `kodim02/07/17/23` improve
`1.093/1.046/1.014/1.079x` strict and
`1.078/1.049/1.017/1.079x` no-Adler; four non-selected controls remain within
`0.9945x..1.0054x` and `0.9966x..1.0026x`.

## Deep-distance PNG literal and zero-extra specialization (2026-08-24)

The bounded-history deep-distance semantic loop now uses the same packed
little-endian speculative literal stores already proven by the filter-0 RLE1
path. The change is restricted to the resumable non-overlap specialization;
the ordinary full-output and generic window loops retain their existing store
shape. The same specialization also bypasses a dynamic mask and two variable
shifts for length symbols 257 through 264, whose extra-bit width is zero. On
`kodim17.png`, those short lengths account for roughly 83% of match tokens.

The mixed-match oracle now places three adjacent literals before its RLE,
small-distance, short/long non-overlap, and overlapping cases. It compares exact
output and the entire buffered-reader state with the generic window loop at both
a forced output boundary and EOB. Existing tail and public-decode comparisons
continue to cover nonzero length-extra widths. The x86-64 specialized body
shrinks from `0x683` to `0x633` bytes. The ordinary semantic full-output loop,
generic window loop, Sub reconstruction, and row-commit functions remain
byte-identical at the same addresses; `.text` and `.rodata` sizes are unchanged.

On fixed P-core 14, 101 alternating process rounds against Vort `534e7e4`
move `kodim17` median throughput from `379.23` to `382.78` MiB/s strict
(`1.0094x`) and from `381.99` to `386.00` MiB/s no-Adler (`1.0105x`). A final
repeat-9 full comparison against image-png `4ab5484` reports:

| policy | aggregate | geomean | median | weakest fixture |
| --- | ---: | ---: | ---: | ---: |
| strict decode-into | `1.280x` | `1.288x` | `1.297x` | `kodim17`, `1.0017x` |
| decode-into no-Adler | `1.311x` | `1.327x` | `1.317x` | `kodim17`, `1.0116x` |

All 15 locked fixtures exceed image-png in this snapshot. This establishes
per-row parity for the locked decode-into corpus on this machine, not PNG-wide
or cross-platform leadership. A broader per-row Adler batching attempt regressed
both checksum policies by about 1%, a global 12-bit semantic table produced only
about `1.004x/1.002x`, and extending speculative match copies through 16 bytes
was neutral; all three experiments were reverted.

## Zstd interleaved four-stream Huffman decode (2026-09-04)

`perf` attributed 98.56% of the locked `ascii64k` profile's cycles to the
sequence-free Huffman literal loop. Following the scheduling used by the local
upstream `~/Work/zstd` decoder, Vort now advances all four independent literal
streams together and decodes five symbols per stream from each 64-bit reservoir
load. The ordinary checked decoder still handles each stream tail and validates
its reverse-bitstream end marker.

Twelve alternating fixed-CPU-8 runs at 5,000 decodes moved the median from about
188.03 MiB/s to 781.84 MiB/s, a `4.16x` improvement with 12/12 wins against
commit `49848ad8`.
A same-process 1,000-iteration comparison measured about 787.90 MiB/s for Vort
and 1,178.58 MiB/s for libzstd 1.5.5 (`0.6685x`). The reference gate floor for
this row is raised from `0.14x` to `0.50x`. This evidence applies to the locked
64 KiB sequence-free, four-stream, high-entropy ASCII shape; it is not a general
Zstd decompression parity claim.

## Zstd decisive ratio-level primary frames (2026-09-04)

The level-aware one-shot and reusable encoders now accept a single-block level-9+
primary result immediately when distributed alphabet sampling classifies the
input as structured and the encoded frame is no larger than 1/32 of the source.
This extends the existing exact 1/256 prefix-tail shortcut with a conservative
structured-data policy, avoiding the otherwise mandatory 8 KiB split candidate.
If the primary misses the threshold, the allocating encoder retains it for
normal arbitration rather than encoding it a second time.

Twelve alternating fixed-CPU-8 comparisons at 20 encodes per side moved the
locked 32 KiB JSON level-9 row from about 2.45 MiB/s to 12.5--13.1 MiB/s
(`5.2x`, 12/12 wins), while preserving the exact 640-byte output and libzstd
round trip. An eight-run complete nine-row matrix kept every encoded size and
checksum identical; non-target level/corpus medians stayed within noise. A
12-case generated structured oracle compares the early return byte-for-byte
with exhaustive primary/4 KiB/8 KiB arbitration, and a low-alphabet
non-decisive case pins the fallback and primary-result reuse path.

The same policy now covers level 3 as an explicit speed/ratio tradeoff. A
1,024-case, 16-shape audit found that 1,013 cases retained the exhaustive winner;
11 cases preferred a split by 92 bytes total, with a worst individual cost of
29 bytes. A locked plain-structured counterexample records the exact 333-byte
primary versus 291-byte exhaustive result after cross-block FSE-table reuse, so this tradeoff cannot disappear
silently. Twelve fixed-CPU-8 pairs keep the benchmark JSON frame at 640 bytes
and improve level-3 throughput from about 3.4 MiB/s to 12.6--13.1 MiB/s
(`~3.8x`, 12/12 wins). An eight-run nine-row matrix preserved every locked
size/checksum and kept non-target rows within noise.

Level 3 now also treats a wide-alphabet, single-block primary as final instead
of evaluating its 4 KiB screen and possible 2 KiB deferred split. A 1,152-case
audit spanning 9--128 KiB, 41--256 symbols, eight seeds, and plain/copied-tail
shapes found 1,130 cases with no loss and 22 split winners totaling 175 bytes;
the worst individual cost was 22 bytes. That counterexample is retained as a
6146-byte primary versus 6124-byte exhaustive split test, including one-shot,
reusable, and decode verification. Twelve alternating fixed-CPU-8 binary
level-3 pairs improved mean throughput by `4.01x` with 12/12 wins. An eight-run
nine-row matrix measured `4.11x` on the target (about 2.4 to 10 MiB/s), kept
all sizes/checksums identical, and left control rows within `0.98--1.06x`.

Ratio levels now have a narrower wide-alphabet shortcut: the primary must also
be no larger than one third of the source. An initial 1,152-case unrestricted
audit rejected unconditional early return after finding 71 split winners
(1,412 bytes total, worst 67 bytes). A second 1,008-case audit spanning
9--128 KiB, seven distributed-noise ratios, eight seeds, and plain/copied-tail
shapes found 280 inputs meeting the 3:1 threshold and zero split winners. Tests
pin the 8,607-byte level-9/22 primary winner and a below-threshold
10,842-versus-10,809-byte fallback split. Twelve alternating fixed-CPU-8
binary level-9 pairs improve mean throughput by `3.30x` with 12/12 wins; an
eight-run nine-row matrix measures `3.27x`, with every size/checksum unchanged
and control rows within about 1.6%.

The retained double-fast parser now participates in a narrow block-level
consensus check for wide level-1--3 and level-9+ blocks. Its candidate must compress by at
least 3:1 and match the independent repeat-beam candidate byte-for-byte before
the encoder skips mixed, greedy, lazy, optimal, repeated, and duplicate
families. A 1,008-case audit found 280 double-fast candidates below the size
threshold: 184 agreed with repeat-beam, and all 184 matched complete arbitration
exactly. Without the agreement requirement, 16 cases lost 242 bytes in total
(worst 32), so the broader shortcut was rejected. Twelve fixed-CPU-8 binary
level-9 pairs improve mean throughput by `2.74x` with 12/12 wins on top of the
frame-level shortcut; an eight-run nine-row matrix measures `2.76x`,
keeps all output bytes/checksums unchanged, and leaves control rows neutral or
faster.
The consensus now compares parser tokens and accounting before the second wire
would be generated, because deterministic token encoding makes equal token
streams sufficient. On the same 1,008-case audit, token and wire agreement each
covered exactly 184 cases with zero disagreement. Against the committed
double-wire implementation, twelve fixed-CPU-8 pairs improve binary level 9 by
another `1.24x` with 12/12 wins; an eight-run nine-row matrix measures `1.27x`,
with controls within about 2%. The encode gate now uses three iterations and
three rounds; later level extensions keep every optimized binary row mutually
bounded rather than assuming one remains a stable slow control.

The same token-consensus probe now starts at level 3's 64-state budget rather
than only at level 4+/ratio budgets. A separate 1,008-case audit found 168
wide blocks whose double-fast wire met the 3:1 threshold, 89 token/statistics
agreements with repeat-beam, and 89/89 byte-exact matches with full level-3
arbitration. Twelve fixed-CPU-8 binary level-3 pairs improve by `2.14x` with
12/12 wins; an eight-run nine-row matrix measures `2.38x`, retains every
size/checksum, and keeps controls within about 2%.

The trigger now includes level 1's 16-state and level 2's 32-state budgets.
Separate runs of the same 1,008-case audit found the same 168 threshold matches
and 89 parser agreements at each budget, with all 89 matching complete
arbitration. Twelve fixed-CPU-8 binary level-1 pairs improve by `1.71x` with
12/12 wins; an eight-run nine-row matrix measures `1.64x`, keeps all wires and
checksums unchanged, and leaves levels 3/9 within 0.5% of baseline. The gate now
requires all three binary levels to remain within 25% latency of one another.

Level 1 now always uses a speed-oriented one-state repeat beam, while levels 2+
retain the established two-state ratio parser as their default/fallback. The
isolated module owns the same
4,096-bucket compact index and one state per input position; placing it in a
dedicated text section restores the original two-state function's exact machine
code size. On the primary text/JSON/binary stage rows, the one-state parser is
about `1.13x`/`1.51x`/`1.54x` faster; text and binary block sizes are unchanged
and JSON grows only 633 to 636 bytes. A 64-shape structured/noise audit has no
regressions and is three bytes smaller in aggregate. Across 24 JSON-record
blocks, 20 differ, growing only 47 bytes cumulatively with a three-byte worst
case. Thirty-one independent fixed-CPU-8 full-encode pairs improve locked JSON
level 1 by `1.2633x` (31/31 wins), changing the complete frame from 640 to 643
bytes while remaining below libzstd 1.5.5 level 1's 838 bytes. The final
eight-row target/control matrix reaches `1.0280x` by row-median geometric mean;
its weakest median is binary level 1 at `0.9932x`, while text and multi-block
controls are neutral. Three attempts to retain the single-state arrays across
encodes were rejected: an indirect scratch object reduced JSON by about 1%, an
embedded object reduced small text by about 6.7%, and borrowing existing
sequence arrays reduced binary level 1 by about 2.4%. The isolated per-call
scratch remains preferable until reuse can preserve code layout and all control
rows.
The single-state predecessor index is now built in the same forward pass that
evaluates DP states, following upstream zstd's query-then-insert fast-match
shape instead of first writing and then rereading the complete predecessor
array. A generated 8 KiB oracle pins every predecessor and final hash head to
the former prebuilt layout. Thirty-one alternating fixed-CPU-8 pairs improve
the locked JSON level-1 median by another `1.0223x` (29/31 wins); six primary
target/control medians reach `1.0045x` geometrically with a `0.9964x` floor,
and two additional multiblock level-3/9 controls remain at `1.0023x`/`1.0007x`.
All compared frame bytes and checksums are unchanged.
Level 3 now has a separately bounded single-state fast path for low-alphabet
blocks larger than 32 KiB. It is eligible only when there is no prefix-to-tail
copy shortcut, its complete block is between 1/128 and 1/32 of the source, and
its token fixed-bit cost beats an independent double-fast plan by at least
1/32; all
other inputs retain the two-state parser and complete arbitration. This follows
the latency intent of upstream zstd's level-3 double-fast strategy while still
requiring stronger Vort-specific ratio evidence before accepting one state. On
the locked 32,797-byte JSON row, 31 independent fixed-CPU-8 interleaved pairs
improve median end-to-end encode throughput by `3.2317x` with 31/31 wins. The
frame grows from 640 to 643 bytes (`+0.47%`) but remains 269 bytes (`29.5%`)
smaller than libzstd 1.5.5 level 3's 912-byte frame. A six-row, 15-pair control
matrix has a `0.9920x` weakest median and `1.2152x` row-median geometric mean.
The isolated one-state parser is `1.4875x` faster than the two-state parser at
the median. A 128-case mixed/noise/copied-tail audit and 24 shorter JSON streams
retain the two-state result exactly; among 24 eligible large JSON streams, 19
select the fast path, adding 49 bytes cumulatively with a four-byte worst case.
Public one-shot, reusable, caller-buffer, round-trip, and allocation-failure
tests cover the selected path.
The retained follow-up still runs the cheap double-fast parser for independent
evidence, but compares its token fixed-bit cost instead of serializing a second
complete Huffman/FSE block. A `1/32` proxy-cost margin preserves the locked
selection and rejects all 48 analyzed JSON/log/source/CSV cases that passed the
outer input classifier. Removing the proxy entirely exposed a 47-byte
structured JSON regression and was rejected. Thirty-one fixed-CPU-8 pairs
measure another `1.2616x` median improvement over the prior full-wire proof
(27/31 wins), for a cumulative `4.1281x` median over the original level-3
two-state path (31/31 wins). A five-row, 21-pair control matrix has a `0.9941x`
weakest median and `0.9982x` row-median geometric mean, with all control wires
unchanged. The retained proxy still accepts all 24 target-style large JSON
cases: 20 produce different output, adding 52 bytes cumulatively with a
four-byte worst case.
Wider single-state hash tables were measured and rejected. With the same
compact heap-backed index layout, 8,192 buckets improved JSON level 1 by only
`1.0085x`; the eight-row row-median geometric mean was `1.0023x` and the
weakest median `0.9988x`. A 16,384-bucket table improved JSON by only
`1.0028x` while binary level 1 fell to `0.9935x`. Moving the original
4,096-bucket head from its small stack array into the predecessor allocation
was also neutral on JSON (`1.0005x`) and slightly negative on text
(`0.9950x`). The 4,096-bucket stack layout therefore remains: the wider tables
do not clear the 1% retention bar and consume 8--32 KiB more scratch.
The retained 4,096-bucket parser now loads each current four-byte anchor once,
uses the complete anchor to reject hash collisions, and starts both indexed and
recent-offset match extension after those four proven bytes. This mirrors the
prefix-validation contract in upstream zstd's fast matcher and removes the
previous fourth-byte-only collision probe plus redundant prefix comparisons. A
boundary oracle covers every match length from 4 through 258. Forty-one
alternating fixed-CPU-8 JSON level-1 pairs improve the median by `1.0320x`
(40/41 wins); eight target/control medians reach `1.0045x` geometrically with a
`0.9940x` floor. Text level 1 improves by `1.0218x`, all frame bytes/checksums
are unchanged, and the isolated parser body shrinks from `0xab4` to `0xa70`.
The level-1 single-state chain depth is now capped at 16 rather than 128. A
128-shape, 4--32 KiB audit found one parser plan with a 12-bit higher proxy
cost, but complete candidate encoding produced identical bytes in all 128
cases (`649,782` bytes per side); a deliberately constructed 24-collision
chain likewise produced the same 779-byte block after complete arbitration.
Forty-one alternating fixed-CPU-8 JSON level-1 pairs improve the median by
`1.0237x` (40/41 wins), binary level 1 improves by `1.0169x`, and the eight-row
target/control median geomean is `1.0062x` with a `0.9985x` floor. All locked
frame bytes and checksums remain unchanged. Depth 32 improved JSON only
`1.0081x`; depth 8 regressed it to `0.9574x`, so neither is retained.
The dedicated `rep_beam_single` stage also rejected accumulating `PlanStats`
during token backtracking. Forty-one fixed-CPU-8 JSON pairs improved by
`1.0296x`, but binary fell to `0.9759x` with only 2/31 wins and the three-row
geometric mean reached only `1.0016x`. Keep the separate forward token-
statistics pass until an alternative preserves the binary control.
Compacting each one-state DP node from 16 to 8 bytes by reconstructing tokens
from predecessor spans was also rejected. It preserved every focused token and
candidate oracle and shrank the isolated parser body from `0xa85` to `0xa24`,
but forty-one fixed-CPU-8 JSON level-1 pairs fell to a `0.8767x` median; text
and binary controls were also negative. Retain the power-of-two 16-byte state
layout with the explicit token until a different representation improves the
end-to-end pipeline.

A follow-up attempted to extend level 1's audited double-fast speed tradeoff
from wide alphabets to extremely compressible narrow/JSON blocks. A 44:1
threshold skipped repeat-beam on the locked 32 KiB JSON row, changing its frame
from 640 to 694 bytes (still below libzstd 1.5.5 level 1's 838 bytes) while
improving 21 alternating fixed-CPU-8 pairs by up to about `4.45x` after the
required exact-single checks. A generated audit covered 64 narrow periodic/noise
blocks with zero triggers and 24 JSON record streams with seven triggers; those
seven grew from 4,106 to 4,464 bytes cumulatively, with a 52-byte worst case.
The candidate was rejected because every attempted placement or out-of-line
dispatcher still regressed the unchanged 32 KiB binary level-1 control by about
1.4%--2.7% at the median. Keep repeat-beam authoritative for narrow level-1
blocks until the speed policy can be isolated without a general-path cost.

The consensus helper now emits its double-fast wire directly into the caller's
reusable candidate buffer and transactionally restores the original length on
threshold misses, parser disagreements, or allocation failures. On the locked
32 KiB binary block this removes one allocation and 13,028 cumulative requested
bytes while preserving the exact wire. The speed effect is intentionally not
claimed as a stable win: twelve fixed-CPU-8 pairs averaged `1.04x` but only 5/12
pairs won. The allocation reduction and exhaustive failure rollback are pinned
by tests instead.

When that probe reaches repeat-beam but the two parsers disagree, the fallback
now carries the already-computed `PlanStats` and token scratch into full
arbitration instead of running repeat-beam a second time. The fixed 16 KiB
disagreement fixture remains byte-identical. Twelve fixed-CPU-8 pairs at each
level improve fallback throughput by `1.25x`, `1.21x`, and `1.13x` for levels
1, 3, and 9 respectively, with 12/12 wins at every level. A counting-allocator
comparison on the same fixture also removes four allocations and 897,583
cumulative requested bytes.

Level 1 now accepts the double-fast block directly at the stricter `4/15`
source-size threshold instead of requiring repeat-beam consensus. Across 784
generated wide blocks, 136 met this threshold: double-fast beat complete
16-state arbitration in 51 cases by 144 bytes total, tied 76, and lost nine by
133 bytes total; aggregate output was 11 bytes smaller, while the worst
individual tradeoff was 32 bytes. That worst 6,619-versus-6,587-byte case is
pinned through block, one-shot, reusable, and decode paths; level 2 retains the
smaller exhaustive result. Twelve fixed-CPU-8 binary level-1 pairs improve by
`2.20x` with 12/12 wins. An eight-run nine-row matrix measures `2.22x`, keeps
the locked 8,607-byte benchmark wire unchanged, and leaves all controls within
about 2%.

Level 3 now has an additional, much stricter direct-double-fast cutoff at a
`1/16` block/source ratio. A 784-case wide-alphabet audit spanning 9--63 KiB,
seven noise densities, eight seeds, and plain/copied-tail inputs found eight
qualifying blocks: three direct candidates saved eight bytes total, four tied,
and one cost a single byte. That worst case is retained as a 2,038-byte level-3
frame versus the strict level-9 2,037-byte frame, with block, one-shot, reusable,
decode, and allocation-failure rollback coverage. Twelve alternating fixed-CPU-8
pairs improve the target level-3 encode by `7.06x` on average (`7.04x` median,
12/12 wins). An eight-run 12-row matrix measures `7.10x`; the other eleven
case/level rows remain within about 1% and keep their frame sizes unchanged.
Level 2 and level 9+ continue to require double-fast/repeat-beam consensus.

## Zstd FSE-weight Huffman tree construction (2026-09-12)

Zstd frames whose Huffman weights are themselves FSE-compressed now use a
Vort-local parser backed by the existing native FSE table reader. Canonical
tree nodes are produced with stable 16-bucket weight counts and starts, matching
the rank-based construction used by upstream zstd while preserving the exact
`std.compress.zstd` tree representation consumed by the decoder. Direct-weight
headers continue through Zig std's decoder, and the new FSE path is isolated in
`.vort_zstd_huffman_build` (with object-format equivalents) to avoid inflating
the sequence hot loops.

Twenty-one alternating fixed-CPU-8 independent-binary pairs against a freshly
built parent measured the following caller-buffer decode medians with identical
encoded sizes and checksums: `numbered_json 1.3724x`, `large_json 1.0371x`,
`large_text 1.1013x`, `ascii64k 1.0240x`, `huffman80k 0.9998x`, and
`binary_mixed 1.0038x`. Across all 13 reference rows the row-median geometric
mean is `1.0455x` and the weakest median is `0.9992x`. The generated
`numbered_json` reference row now reaches about `0.454x` libzstd 1.5.5
throughput rather than the prior `0.339x`; the gate floor is conservatively
raised to `0.38x`. Correctness coverage includes direct/FSE node-by-node
differentials, 512 deterministic malformed/truncated headers, 64 generated
trees, both 273-case libzstd compatibility matrices, and the 9,900-frame
upstream decodecorpus suite with all 64 sequence-mode combinations.

The large all-FSE/Huffman sequence loop additionally relies on the validated
Zstd LL/ML alphabets when adding extra bits: compile-time checks cap decoded
literal and match lengths at 131,071 and 131,074 bytes, respectively, so those
two additions cannot overflow even a 32-bit `usize`. Removing only the
unreachable generic overflow branches keeps the helper start address fixed and
reduces its body by 20 bytes. Thirty-one fixed-CPU-8 core pairs improve
`large_json` by `1.0373x` (30/31 wins), with `huffman80k` at `1.0004x` and
`binary_mixed` at `1.0048x`. The 21-pair 13-row reference matrix reaches a
`1.0066x` row-median geometric mean and a `0.9927x` floor. The analogous
FSE/FSE/RLE change was not kept after `rle64k` fell to `0.9735x`.

## Zstd speed-level multi-block scheduling (2026-09-04)

Large level-1--3 encodes now overlap the primary candidate on the calling thread
with the larger adaptive split candidate in a worker. This restores concurrency
lost when the level-9 primary was moved into the worker set: level 9+ retains
that three-worker shape because its primary can itself spawn mixed-search work,
while levels 4--8 keep their existing scheduling. Candidate sets, deferred-small
split rules, strict shortest-frame arbitration, and tie order are unchanged.

An 80-case generated audit spanning 129/192 KiB, five distributed-noise
densities, four seeds, and plain/copied-tail shapes found the larger adaptive
split won every level-1 and level-3 case; the deferred smaller split won none.
The retained 129 KiB fixture is byte-identical to complete serial arbitration at
levels 1/2/3 and decodes through the public API. Twelve alternating ReleaseFast
A/B pairs pinned to separate performance cores measured median speedups of
`1.038x` for level 1 and `1.090x` for level 3 before sequence-table reuse. The
current frames are 27,863/27,517 bytes at levels 1/3. Wide cross-block sequence
state is now covered separately by `run-zstd-large-sequence-probe`: its public
256 KiB frame is 69,882 bytes, contains 2,044 sequences in each 128 KiB block,
and uses ML=Repeat in the second block while decoding byte-exactly through Vort
and runtime libzstd 1.5.5. The speed-level decisive-wide consensus path now emits
against current frame entropy state directly. On the 513-sequence unit fixture
this preserves the exact rewritten wire while removing 16 allocations and
237,173 cumulative requested bytes; strict ratio-level and non-decisive paths
retain full candidate arbitration. The runtime probe additionally pins a
15,517-byte two-block level-1-style frame whose disjoint byte alphabets exclude
history matches, with 526 sequences per block and LL/ML=Repeat plus OF=RLE in
the second 33 KiB block. Its Repeat reachability DP now allocates two `u64`
words per sequence for the normal 128-state tables instead of eight, a 75%
reduction for that scratch buffer while preserving the exact wire. Frame-level
scratch reuse removes another 13 allocations and 76,482 cumulatively requested
bytes from the two-33-KiB path; retaining the same scratch in
`NativeFrameEncoder` removes 18 allocations on the next identical encode. The
tests also cover recovery after an injected OOM and balanced final deallocation.
A same-process
parallel-versus-serial gate on efficiency cores measured
stable medians of roughly `1.075x`/`1.072x`/`1.116x` for levels 1/2/3 across
five runs, each 5/5 wins; its conservative enforced floor is `1.01x`. Five
256 KiB prefixes from the local Silesia corpus retained identical output in a
separate candidate/baseline check pinned to two efficiency cores. Geometric-mean
speedups were `1.109x` at level 1 (4/5 files faster) and `1.087x` at level 3
(3/5 faster); the slowest individual rows were about `0.975x` and `0.970x`, so
this is an aggregate scheduling gain rather than a claim that every file wins.

## Zstd level-1 four-byte optimal search (2026-09-14)

Level-1 blocks above 64 KiB use a dedicated four-byte optimal hash-chain kernel.
It is isolated in an object-format-specific text section and leaves the shared
LZ77 parser in place for Deflate, Brotli, shorter Zstd blocks, and higher Zstd
levels. The route is limited to the measured seven-candidate level-1 policy and
the standard 128 KiB Zstd block bound.

Fifteen interleaved fixed-CPU-2 pairs against an independent `3294719c` binary
improve the isolated optimal stage by `1.4534x` geometrically across 128 KiB
prefixes of Ghostty `Terminal.zig`, README, the roadmap, and `src/zstd.zig`; the
slowest row is `1.3372x`, and all four win 15/15 samples. End-to-end level-1
frame encoding improves `1.1694x` geometrically on the same inputs, with a
`1.0019x` floor and aggregate output shrinking from 113,545 to 113,524 bytes.
Twelve 128 KiB Silesia prefixes improve `1.1408x` geometrically with a `0.9998x`
floor; aggregate output shrinks from 575,562 to 575,231 bytes versus libzstd
1.5.5's 632,131 bytes. The only larger file is `sao`, up four bytes.

The built-in 20-row level-1/3/9/22 control matrix keeps every encoded size
unchanged, measures `1.0027x` geometrically, and retains a `0.9964x` floor. A
31-pair longer JSON level-1 confirmation is `0.9975x`. Correctness coverage
includes 128 generated large-block plan comparisons with no fixed-cost increase,
a 32-frame full-wire audit, exact 64 KiB routing boundaries, replay, profiler
accounting, allocation-failure enumeration and recovery, plus 32-bit compilation.
The final source also passes the 100-row native-stage and 20-row libzstd 1.5.5
encode gates, the 273-case compatibility probe, five-row decode profile,
9,900-frame decodecorpus gate, 131,072-byte large-sequence probe, 237-case
native-frame probe, and the complete `zig build test` / `zig build check` suite.

The dedicated four-byte kernel now also reuses the shared compile-time
259-entry fixed match-length cost table instead of repeating a branch ladder for
each newly constructed dynamic-programming length. No second table is emitted:
the final baseline/candidate binaries have byte-identical `.rodata`, identical
ordinary `.text` address/size, and the isolated four-byte section shrinks from
`0x893` to `0x842` bytes. Twenty-one interleaved fixed-CPU-2 pairs against
the independent `8a394685` binary preserve every output size and checksum.
The isolated stage improves `1.0855x` geometrically across the four real-source
rows with a `1.0376x` floor and 15/15 wins per row. Complete level-1 frames
improve `1.0396x` geometrically with a `1.0004x` floor; twelve Silesia
prefixes improve `1.0129x` with a `0.9983x` floor. The 20-row level-1/3/9/22
control matrix is neutral at `0.9999x` geometrically with a `0.9930x` floor.

Large sequence-table plans now stay borrowed through scoring and final bitstream
emission instead of copying `LargeSequenceTableEmitPlan` at each symbol,
transition, payload-length, and validation helper call. This affects only blocks
with more than 512 sequences and preserves every selected plan and wire byte.
Fifteen fixed-CPU-2 stage pairs across double-fast, greedy, and optimal on four
128 KiB source files improve all twelve rows, with a `1.1035x` row-median
geometric mean and a `1.0429x` floor. Twenty-one complete-frame pairs improve
the four source files by `1.0391x`--`1.1467x` (`1.0717x` geometric mean)
and twelve Silesia prefixes by `1.0046x`--`1.1320x` (`1.0755x` geometric
mean, 249/252 pair wins). The 20-row level-1/3/9/22 control matrix keeps every
size and checksum, measures `0.9998x` geometrically, and retains a `0.9932x`
floor. The ReleaseFast executable's ordinary `.text` shrinks by 3,072 bytes.
The 100-row native-stage and 20-row libzstd 1.5.5 encode gates, 273-case
compatibility probe, five-row decode profile, 9,900-frame decodecorpus gate,
237-case native-frame probe, 2,044-sequence large-block probe, all 1,543 tests,
and all 85 compile-check targets pass.

## Zstd decisive single-duplicate lower bound (2026-09-15)

Ratio-level structured blocks already let a decisive repeat beam cancel the
expensive mixed planner, but cancellation still required an exact
single-duplicate search to prove that the remaining primitive family was at
least 24 times larger. The retained path first finds the maximum match length
available in the existing paired duplicate index. Because one single-match
candidate can remove only one interval of at most that length, at least
`frequency[symbol] - maximum_match_length` occurrences of every symbol must
remain literal. The optimal 11-bit-limited Huffman cost of those independently
guaranteed counts is a conservative lower bound for any real retained literal
stream. Tree bytes, four-stream markers and padding, sequence bits, and the
block header are deliberately omitted. When even that weakened bound is at
least `repeat_beam_bytes * 24`, the exact single-duplicate scorer cannot affect
the winner or the existing mixed-cancellation decision and is skipped.

The proof is compiled only into the mixed-dominance specialization. Ordinary
level-1/3 and non-cancellation paths retain the original selector body; this
compile-time split was required because earlier runtime-only layouts created
repeatable short-text regressions despite never executing the new proof. The
locked 32,797-byte JSON case hits the lower bound once and remains exactly 640
bytes. Disabling the bound and running the complete exact single search emits
the same block; 24 generated structured streams repeat that fast/exact wire
comparison, and a separate 32-shape oracle checks every successful dominance
proof against the exact selected single candidate.

Independent ReleaseFast binaries on the i9-13900K, fixed to CPU 2 and run in
eleven alternating pairs, improve complete JSON level-9 encoding by `1.2930x`
at the median and `1.2943x` geometrically, with 11/11 wins and identical
640-byte output. Sixteen non-target text, binary, level-3-tradeoff, and
multiblock level-1/3/9/22 rows retain identical sizes and checksums; their
row-median floor is `0.9911x` and geometric mean is `0.9967x`. The 20-row
libzstd 1.5.5 encode gate, runtime-libzstd compatibility probe (256 checked
cases), comparison and block-sweep gates, all 1,558 tests, and all 93 compile
checks pass.

## Zstd decisive beam-first entropy pruning (2026-09-15)

After removing decisive single-duplicate scoring, `perf` attributes about
22.1% of complete JSON level-9 cycles to the repeat-beam parser, while the
remaining selector still serializes the losing greedy and lazy token plans.
The retained mixed-cancellation specialization now evaluates the repeat beam
first only for the existing 95-state non-mixed pass. If its block is already
within the existing absolute 1/32 threshold, it parses greedy and lazy but
skips their entropy encoding when a conservative wire lower bound is larger.

For each fixed token stream, the bound counts its unmatched literals, uses the
optimal 11-bit-limited Huffman cost for that histogram (or one-byte RLE), and
adds only unavoidable LL/ML/OF extra bits. Per-value extra-bit widths take the
minimum across direct, repeat-aware, and predefined representations; tree
descriptions, FSE states/transitions, markers, padding, and other positive
overhead are omitted. Target bounds are 714 bytes for greedy and 831 bytes for
lazy versus the 633-byte beam. Original tie priority remains when the proof is
inconclusive.

The scheduler is an out-of-line helper: an earlier in-body prototype produced
a `0.9835x` non-target floor despite not executing there. The isolated version
improves the 32,797-byte JSON level-9 frame by `1.1175x` median / `1.1182x`
geomean over 21 fixed-CPU-2 alternating pairs, with 21/21 wins and identical
640-byte output. A 20-row level-1/3/9/22 control matrix preserves all sizes and
checksums; excluding the matching JSON ratio rows, its row-median floor is
`0.9931x` and geomean is `1.0036x`. A 48-shape generated oracle checks 44
emitted greedy/lazy candidates and confirms the bound never exceeds exact wire
length; 20 are prunable at the locked 633-byte limit. Fast/disabled-bound tests
also preserve the target and 24 generated structured frames byte-for-byte.

The ReleaseFast 20-row libzstd 1.5.5 gate reports JSON level 9 at 640 versus
677 bytes and about 31.20 versus 220.98 MiB/s. The 256-case compatibility,
comparison and block-sweep gates, all 1,560 tests, and all 93 compile checks
pass. Literal-cost hoisting (`0.9651x`) and shrinking beam states from 16 to 12
bytes (`0.9791x`) were rejected after 0/21 stage wins.

The lower-bound hot loop no longer scans all predefined LL/ML/OF states for
every sequence. Exhaustive format-range tests prove that the direct LL and ML
code widths are no greater than the minimum predefined width for every encodable
literal length through `u17` and every match length through 258; the same holds
for direct OF codes through the 32 KiB window. The bound therefore uses direct
LL/ML widths and the minimum of repeat-aware/direct OF widths without becoming
stronger than any supported table representation. This removes the profile's
roughly 4.1% predefined-symbol scan. Against the preceding beam-first binary,
21 fixed-CPU-2 JSON level-9 pairs improve `1.0671x` median / `1.0663x` geomean,
all wins, with 640-byte output. The complete 20-row control remains bit-exact;
excluding JSON ratio rows, its floor is `0.9973x` and geomean is `1.0016x`.
The final formal run passes 1,561 tests, all 93 compile checks, and the same four
Zstd gates.

The next profile moved the fast scheduler's duplicate-index build to the second
largest cost: roughly 10.8% of complete encoding. That helper only runs the
single-duplicate dominance proof, which consumes paired candidate positions,
predecessors, cached match lengths, and byte-frequency summaries; it never uses
the 65,535-entry cursor hash chain needed by mixed lookahead. It now calls the
existing `buildBounded` variant. The 16-seed full-versus-bounded index oracle
already checks candidate positions, predecessors, cached lengths, and selected
matches; target and 24 generated cancellation tests remain byte-exact. Against
the direct-bound baseline, 21 fixed-CPU-2 level-9 pairs improve `1.0558x` median
/ `1.0567x` geomean with 21/21 wins. The full 20-row matrix keeps every size
and checksum; excluding JSON ratio rows, its floor is `0.9918x` and geomean is
`1.0007x`. The formal gate now reports JSON level 9 at 640 bytes and about
35.21 MiB/s versus libzstd 1.5.5 at 677 bytes and 224.98 MiB/s; all four Zstd
gates, 1,561 tests, and 93 compile checks pass.

The dominance proof no longer needs to materialize that bounded index on its
successful path. It now pairs the same truncated-hash occurrences in one pass,
tracks only the maximum verified match length and byte frequencies, and applies
the unchanged conservative Huffman lower bound directly. If the proof fails,
the encoder still builds the ordinary bounded index and runs the exact
single-match selector, preserving candidate and tie behavior. A 24-seed oracle
over 4,097--64,288-byte inputs and six cost limits matches the indexed proof on
every pruned and retained case; the existing target and 24 generated full-wire
oracles remain exact. The helper has a separate text section because colocating
it with unrelated fast helpers measurably perturbed non-target code layout.
Against the preceding bounded-index binary, 21 fixed-CPU-2 complete-matrix pairs
improve JSON level 9 by `1.0351x` median / `1.0312x` geomean (19/21 wins) and
level 22 by `1.0294x` / `1.0333x` (21/21 wins). All 20 rows retain their sizes,
input hashes, reference sizes, and checksums; excluding the four JSON rows, the
row-median floor is `0.9926x` and geomean is `1.0001x`. The formal gate reports
JSON level 9 at 640 bytes and about 37.56 MiB/s versus libzstd 1.5.5 at 677
bytes and 233.29 MiB/s. All four Zstd gates, 1,562 tests, 93 compile checks, the
328-case native probe, and the 237-case frame probe pass. A bitset in the shared
bounded-index builder was rejected because the full matrix exposed non-target
medians near `0.985x`; retaining byte frequencies in the large index was also
rejected after a focused 21-pair A/B reached only `0.9989x` geomean.

## Brotli q8 fixed-width record baseline (2026-09-14)

The planned-encode and ratio-stage gates now include a deterministic 32 KiB
`records_q8` workload: 128-byte fixed-width records with eight reproducible
mutations per row. One shared fixture helper feeds both tools, so the end-to-end
libbrotli comparison and internal parser profile use identical input bytes
(`SHA-256 57838ff8...74a45`) without an external corpus. On the i9-13900K
ReleaseFast single-thread gate, Vort fast/balanced/ratio emit
4,479/3,912/3,459 bytes versus libbrotli 1.1.0 q8 at 3,117 bytes. Ratio mode is
10.97% larger and measures 3.96 MiB/s versus 79.49 MiB/s.

The stage profile exposes a command-fragmentation counterexample rather than
merely a larger search budget. The four-byte optimal proposal emits 1,293
commands, covers 31,484 bytes with 1,284 literals, and costs 38,520 fixed-proxy
bits. The lazy plan emits only 1,253 commands, covers 31,510 bytes with 1,258
literals, and costs 38,188 bits. Optimal even has more recent-distance hits
(413 versus 374) and code-zero last-distance hits (284 versus 269), so simply
adding recent-distance probes cannot explain the loss. Its 3,504-byte wire is
45 bytes larger than lazy's selected 3,459-byte wire despite spending about
86% of the measured 31.18 ms aggregate over three encodes. The gate locks
these relationships, all search-counter identities, and independent libbrotli
decoding. This complements `source32k`, where four-byte optimal remains the
exact-wire winner.

A diagnostic three-byte optimal sweep at 16/32/64/128 candidates emitted
3,982/3,835/3,637/3,503 bytes. At low budget it covered more bytes but created
up to 1,754 commands; at full budget it converged back to the four-byte shape.
The probe was removed. The next useful experiment is therefore an explicit
Brotli command-fragmentation cost in the DP, not a lower minimum-match length.

Follow-up cost-model experiments refined that conclusion. Charging every match
a fixed 1...12-bit command tax left the `records_q8` path unchanged; 16...32
bits removed only one command and enlarged the proposal from 3,504 to 3,507
bytes, while larger penalties degraded rapidly. Matching the lazy candidate's
`NDIRECT=15` layout improved the internal proposal to 3,491 bytes, but exact
public arbitration did not improve 4/16/32 KiB source inputs and a two-layout
wire trial missed the throughput floor (roughly 0.79x/0.92x/0.95x in the
screening runs). Both variants were removed.

Literal cost was the effective missing variable. Replacing the fixed 8/9-bit
literal proxy with a uniform seven-bit alphabet-width proxy changed the record
distance choices, raised recent-distance/code-zero hits from 413/284 to
464/308, and reduced the exact wire from 3,459 to 3,442 bytes. A six-bit proxy
reached 3,387 bytes and a four-bit proxy reached 3,362 bytes, demonstrating that
the previous command fragmentation was partly a consequence of overpricing
printable-record literals. Unconditionally enabling alphabet-width costs was
not safe: a 12-row 64 KiB Silesia audit improved `nci`/`xml` by 50/29 bytes but
enlarged five rows, including Dickens by 57 bytes and Samba by 54 bytes. A
strict fixed-width-record classifier restored all 12 Silesia rows bit-exact and
kept the 3,442-byte target, but every attempted integration changed shared
optimal-parser or ratio hot-code layout: the best complete 12-row fixed-CPU-2
control matrix still had a 0.9802 row-median floor, and copied/noinline/text-
section variants produced isolated `nci` medians as low as about 0.82...0.97.
The retained implementation now places that record-aware parser in an
independently compiled Zig object behind a narrow caller-owned-buffer ABI. A
strict classifier admits only 4...64 KiB printable ASCII/tab records with
32...1024-byte fixed rows, at least 16 rows, and at least 87.5% template-column
stability. The generic shared LZ77 module and its hot loop remain unchanged.
The object uses lazy hash-head initialization, packed `u32` suffix costs, a
four-byte prefix guard, a 256-hop chain, and 128 valid candidates, while its
literal proxy is the uniform bit width of the record byte alphabet. Exact wire
arbitration against the existing lazy plan remains mandatory.

In the first retained stage, `records_q8` ratio output reached 3,442 bytes
instead of 3,459 bytes (`-17`, `-0.49%`), versus libbrotli q8 at 3,117 bytes.
Fixed-CPU-2 independent-binary A/B over eleven interleaved pairs
measured 4.12 versus 3.97 MiB/s at the median (`1.0372x`, 11/11 wins). A
deterministic 480-row family audit spanning 4/8/16/32/64 KiB, 32/64/128/256-
byte rows, three mutation densities, and eight seeds improved 134 rows, found
301 record proposals that exact-wire arbitration correctly rejected, and found
zero cases where record output beat lazy but lost to the generic optimal plan.
All rows decoded with both Vort and libbrotli. The 12-row 64 KiB Silesia
control stayed byte-for-byte identical; its fixed-CPU-2 row-median floor was
1.0051x and matrix geomean was 1.0143x. Explicit non-default Brotli windows
remain on the generic parser so the specialized object's fixed 32 KiB history
cannot violate advertised window limits.

A follow-up `run-br-record-optimal-shape-gate` separates lazy, generic optimal,
and record-optimal command structure without changing production selection. On
`records_q8`, generic and record optimal both emit 1,293 commands, so the
3,504-to-3,442-byte improvement is not a command-count reduction. Instead, the
record plan converts 51 explicit distances into recent-distance symbols
(880 to 829 explicit, 413 to 464 recent), including 24 additional code-zero
uses (284 to 308). Distance 128, exactly one record width, rises from 461 to
514 matches and dominates all other distances; lazy uses it 394 times. The
insert/copy code histograms and top-eight distance/count pairs are now gated
alongside token coverage and recent/explicit conservation identities.

This evidence motivated a bounded row-distance cost sweep inside an isolated
worktree. Charging distance 128 as 1 bit produced a 2,779-byte wire, and a
2-bit proxy produced 3,110 bytes, seven bytes smaller than libbrotli 1.1.0 q8's
3,117-byte output on this workload. Costs 3...9 emitted 3,320/3,340/3,347/
3,349/3,361/3,368/3,387 bytes. None was retained: fixed-CPU-2 three-pair
screening stayed around 0.94...0.96x of the 3,442-byte baseline because the
cheap row distance caused a command-count phase change. A length-16 eligibility
threshold saved only four bytes (3,438) and fell to about 0.87x. The next model
must therefore represent recent-distance reuse without making every row-width
match locally cheap; a bounded stateful beam or a two-pass cost refinement is
more promising than another scalar distance discount.
Rewriting an already chosen match to the row distance when the copied bytes
were identical was wire-neutral at 3,442 bytes, as were row-distance tie and
near-tie preferences with zero through four proxy bits of slack. The missing
choices are therefore not equivalent-distance ties available after the current
DP; they require carrying distance history through path selection.

A width-two forward beam that tracked only the newest distance confirmed that
stateful conclusion without restoring the rejected full q8 parser. It reused
the same three-byte hash index, 256-hop chain, and bounded 16 ordinary matches
per position, plus direct probes for `rep0` and the record width. On
`records_q8` it reduced the exact wire to 2,630 bytes and raised code-zero hits
to 1,587, but emitted 1,794 commands and made distance 896 more frequent than
distance 128. The 480-row family audit improved 465 cases, rejected 14 losing
proposals, and found zero arbitration hazards. It was still removed: five
fixed-CPU-2 target pairs measured only `0.9149x` median throughput versus the
retained 3,442-byte parser. The next stateful design must constrain command
growth or run as a selectively admitted second pass; merely adding beam states
trades too much encode speed for the ratio gain.

A two-parameter follow-up combined the one-bit row-distance proxy with a fixed
per-match penalty to limit that command growth. Penalties 2/4/6/8/10 produced
3,110/3,320/3,340/3,347/3,347 bytes and 1,511/1,332/1,303/1,295/1,295
commands. The eight-bit penalty is the first structural Pareto point: it saves
95 bytes while adding only two commands, with 554 recent and 346 code-zero
hits. It was nevertheless removed because five fixed-CPU-2 target pairs
measured only `0.9491x`. Keeping row distance at its original fixed cost while
penalizing only other distances preserved the same 3,347-byte shape but fell
further to `0.8525x`, showing that the extra per-candidate branch/code shape is
itself expensive. Scalar two-parameter costs are therefore not a production
substitute for a compact state representation.

The retained follow-up avoids search-time state entirely. After the isolated
record DP fixes every literal/match boundary, a linear pass tracks only the
current Brotli last distance. For each existing match, it substitutes `rep0`
only when that distance reproduces the complete copy; otherwise it keeps the
original distance and updates `rep0`. No command, literal, or copy length can
change, and the pass allocates no additional state. On `records_q8`, token and
command counts remain 2,630 / 1,293, while recent hits rise 464 -> 542, code-zero
hits rise 308 -> 504, and explicit distances fall 829 -> 751. The exact wire
shrinks from 3,442 to 3,209 bytes (`-233`, `-6.77%`), leaving only a 2.95% gap
to libbrotli q8's 3,117 bytes. Fixed-CPU-2 independent-binary A/B over eleven
interleaved pairs measured 4.14 versus 4.12 MiB/s (`1.0096x` median) with
10/11 wins. The
480-row record audit improved 448 cases, rejected 28 losing proposals, and
found zero arbitration hazards. A 12-row 64 KiB Silesia control remained
byte-exact with a `0.9919x` row-median floor and `1.0016x` matrix geomean.
The next distance-only refinement can consider the older three cache slots,
but must avoid reintroducing per-match multi-candidate validation: the retained
code-zero pass performs at most one additional full-copy comparison.

The next retained wire refinement removes UTF-8 literal context modeling only
for classifier-approved fixed-width record plans. Inspecting the decoded
meta-block shape showed that libbrotli q8 uses one literal tree for the target,
whereas Vort was paying for two; the existing literal/command/distance split
proposals were all wire-neutral. A single-tree record candidate reduces
`records_q8` from 3,209 to 3,187 bytes (`-22`, `-0.69%`) without changing any
token, command, or distance decision, leaving 70 bytes (`2.25%`) over
libbrotli q8. Across the complete 480-row record grid it improved every row
relative to the former two-tree encoding, by 1...32 bytes and 9,901 bytes in
aggregate. Fixed-CPU-2 independent-binary A/B over eleven interleaved target
pairs measured `1.0041x` median / `1.0039x` geomean with 9/11 wins. The 12-row
64 KiB Silesia control remained bit-exact in size and checksum with a `0.9995x`
row-median floor and `1.0001x` matrix geomean. A narrower `rep1` distance
probe was also rejected: it reached only 3,207 bytes, so the extra per-match
branch was not justified despite neutral short-A/B throughput.

A retained reconstruction pass now extends each already-proven DP match only
from its original endpoint, using the same distance and the existing 258-byte
copy limit. Because an extension can skip later DP boundaries and alter global
entropy, the alternate path is selected only when it creates at least four
additional literal/token boundaries; otherwise reconstruction repeats the
original steps. This moves `records_q8` from 3,187 to 3,134 bytes (`-53`,
`-1.66%`), just 17 bytes (`0.55%`) above libbrotli q8, with 2,661 tokens, 1,368
literals, and the same 1,293 matches/commands. The original 480-row grid has
215 improvements, 265 unchanged rows, and zero regressions under the gate; an
independent 2,592-row grid across 4...64 KiB, 32...1024-byte rows, three
mutation densities, and 32 new seeds has 969 improvements, 1,623 unchanged,
and zero regressions. Eleven fixed-CPU-2 target pairs measured `0.9997x`
median/geomean with 5/11 wins. A 12-row 64 KiB Silesia control remained
bit-exact with a `0.9909x` row-median floor and `0.9932x` geomean.

Bit-level comparison explains the former 3,187-versus-3,117 gap: Vort spent
110 more header bits, 249 more command bits, 43 more length-extra bits, and
626 more distance bits, partly offset by 463 fewer literal bits. Both streams
use NPOSTFIX=0/NDIRECT=0 and one block/tree per symbol family. Fixed NDIRECT=4
was rejected despite reaching 3,182 bytes because it enlarged 23 of 1,152
independent record variants. Unconditionally applying upstream-style
literal-count RLE smoothing reached only 3,184 bytes, and a local attempt to
copy libbrotli's first command boundary regressed to 3,191 bytes; neither is
retained in those forms.
The smoothing idea becomes viable when it is not a second full-stream
candidate: record encoding now constructs the original and smoothed literal
trees together, computes each tree's exact header plus original-frequency
payload bit cost, and emits only the cheaper one. This trims 3,134 -> 3,132
bytes, leaving 15 bytes (`0.48%`) over libbrotli q8. The original 480-row grid
improves in 397 cases and is unchanged in 83, with no regressions. Eleven
fixed-CPU-2 pairs measured `1.0076x` median / `1.0090x` geomean and 11/11 wins;
the Silesia control remained bit-exact with a `0.9972x` floor and `1.0001x`
geomean. This supersedes the rejected whole-stream smoothing experiment: the
new path performs one bounded 256-symbol decision and never encodes a losing
candidate stream.
Generalizing the same selector to the 15-symbol command and 18-symbol distance
trees was wire-neutral at 3,132 bytes because upstream's smoothing deliberately
does not alter alphabets with fewer than 28 active symbols; that broader option
was not retained. Reapplying an equal-length `rep1` probe after match-tail
extension reached 3,129 bytes, but eleven fixed-CPU-2 pairs measured only
`0.9907x` median / `0.9899x` geomean with 0/11 wins, so the extra per-match
comparison was rejected.

A second width-two beam moved the ordinary hash-chain search outside the state
loop: each position computed one shared longest ordinary match, while each of
the two `rep0` states additionally probed only its repeat distance and the row
distance. This kept most of the ratio gain (`2,648` bytes), improved 465 of 480
record variants with zero arbitration hazards, and emitted 1,721 commands. It
was much slower, however: five fixed-CPU-2 target pairs measured `0.6025x`. The
cost is the forward visit to every byte/state plus repeat probes, not repeated
ordinary-candidate enumeration. Do not enlarge this beam to two or four shared
ordinary candidates; the next viable design should reuse the existing reverse
DP path and refine only sparse command boundaries.

An upstream-inspired q8 parser was evaluated but not retained. The prototype
used four-byte hashes, Brotli length/distance scoring, ten recent-distance
probes, four delayed literals, and a bounded 16-hop predecessor chain. Exact
wire arbitration reduced `records_q8` from 3,459 to 2,674 bytes and Silesia
`nci` from 2,688 to 2,637 bytes; across 96 independent 16/32 KiB Silesia
slices it improved 17 and enlarged none. Target throughput was about 0.953x of
baseline, but an equivalent-harness control matrix had a 0.9587 row-median
floor. Helper, wrapper, compile-time, and text-section isolation did not restore
the required 0.99 non-target floor, so all production parser code was removed.
Future work should integrate Brotli-aware costs behind a layout-stable boundary.

## Zstd shifted single-beam match reuse (2026-09-15)

The speed-oriented one-state Zstd parser now reuses the exact length of an
indexed match when the immediately preceding position selected the same
distance. A length-`L` match proves `L-1` equal bytes at the shifted position;
when `L < 258`, the mismatch that ended the prior match proves the shifted
length cannot extend. Capped 258-byte matches deliberately keep the established
vector extension path because they dominate the text fixture and an initial
broader form reduced its complete-frame medians below the 0.99 control floor.
Candidate order, costs, recent-offset state, and tie behavior are unchanged.

A 64-shape generated oracle compares the optimized and full-extension planners
token-for-token and statistic-for-statistic, and requires the reuse path to be
exercised. The stage profile and its 100-row gate now expose
`single_shifted_matches`: primary JSON reuses 28,448 of 31,661 successful
indexed matches and primary binary reuses 22,356 of 23,063, while primary text
reuses only 253 of 37,300 because almost all its matches reach length 258.

Independent ReleaseFast binaries fixed to CPU 2 improve complete JSON level-3
encoding by `1.0254x` median / `1.0282x` geometric mean over 21 alternating
pairs, with 21/21 wins and identical 643-byte frames and checksums. A separate
15-pair, 20-row level/input matrix keeps every size and checksum identical,
reaches a `1.0012x` row-median geometric mean, and has a `0.9926x` weakest row.
The formal libzstd gate reports about 100.05 MiB/s at 643 bytes versus libzstd
1.5.5's 1445.50 MiB/s at 912 bytes, so this is a measured parser improvement,
not an overall Zstd encoder parity claim.
