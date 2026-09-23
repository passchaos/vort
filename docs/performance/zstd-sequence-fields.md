# Zstd sequence field grouping

The dense and wide all-FSE/four-stream-Huffman decoder loads a complete group
of offset, match-length, literal-length, and FSE-transition bits once, instead
of loading the input separately for up to six fields. The implementation is
isolated in `src/zstd/sequence/field_group.zig`. The prepared sequence-stage
benchmark uses the same reader and checks ordered results against the generic
sequence decoder before timing.

The fast path accepts at most 56 bits and requires at least 64 unread bits.
This proves the unaligned 64-bit input load is inside the actual stream and
that all fields fit after byte alignment. Zero-width fields are defined.
Larger groups and the final bytes retain the existing checked reader. Output
copy bounds, dictionary routing, and public APIs retain their existing rules;
the change adds no allocation or persistent decoder state.

## Validation

- ReleaseSafe reader tests compare all bit alignments, zero-width fields,
  variable six-field groups, unaligned input addresses, and rejected groups
  against exact reverse reads. Rejected groups leave the cursor unchanged.
- The fixed upstream frame test requires more than 1,000 grouped reads, checks
  byte parity with generic decoding, and directly exercises grouped decoding
  on 64 sequence-bit mutations with matching block-level errors and an
  untouched caller suffix.
- Upstream decodecorpus: 9 campaigns, 9,900 frames, 64/64 sequence-mode
  combinations; runtime libzstd 1.5.7 compatibility matrix: 276 cases.
- Focused ReleaseFast Zstd run: 493 tests passed. Final ReleaseSafe reader
  run: 14 tests passed; forced grouped-path/mutation run: 6 tests passed.
- `zig build check -j2 --summary all`: 98/98 steps passed. The optional full
  ReleaseFast test build was stopped during prolonged LLVM InstCombine; the
  broader Debug test run was also stopped while executing expensive encoder
  arbitration cases. Neither is counted as a full-suite pass.

## Benchmark protocol

Baseline: local commit `ad167131`. Host: Apple M1 Pro, macOS, Zig 0.16.0,
ReleaseFast, target CPU `apple_m1`, one codec thread, no affinity pinning.
Reference: `/opt/homebrew/opt/zstd/lib/libzstd.dylib`, version 1.5.7.
Background desktop/security processes remained active, so these are same-host
paired measurements, not idle-host peak-throughput claims.

Both executables consume identical snapshots of README.md, build.zig,
docs/roadmap.md, and src/zstd.zig from the baseline commit. The reference harness
compresses each with libzstd level 1, verifies Vort and libzstd output against
the source, and times caller-owned decode in-process. Each row is best-of-five;
the comparison alternates baseline/candidate process order and reports the
median and geometric mean across independent pairs. The generated controls
are ascii64k (level 9), large_json, and binary_mixed (level 1).

Build each revision using its own checkout/cache:

```sh
zig build run-zstd-reference-bench -j1 -- --input /path/to/frozen-input --iterations 3000 --csv /path/to/result.csv --libzstd /opt/homebrew/opt/zstd/lib/libzstd.dylib
zig build run-zstd-sequence-decode-stage-bench -j1 -- --input /path/to/frozen-input --iterations 1000 --rounds 7 --csv /path/to/stage.csv --libzstd /opt/homebrew/opt/zstd/lib/libzstd.dylib
```

Use 600 iterations for the larger roadmap/source snapshots. Freeze the two
executables and run 11 alternating pairs without compiling or running tests
concurrently. For generated controls, replace `--input PATH` with
`--case ascii64k`, `--case large_json`, or `--case binary_mixed`.
The CSV records input and executable SHA-256, exact command, build mode,
target, and competitor version. Use seven pairs for the prepared stage.

## Results (2026-09-23)

| Input | Median new/old | Geometric new/old | Wins | Vort MiB/s | libzstd MiB/s | Vort/libzstd |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| readme | 1.1118x | 1.1103x | 11/11 | 1388.05 | 1393.93 | 0.9974x |
| build | 1.0196x | 1.0208x | 11/11 | 1466.58 | 2292.85 | 0.6417x |
| roadmap | 1.0512x | 1.0512x | 11/11 | 841.86 | 1258.81 | 0.6696x |
| source | 1.0709x | 1.0750x | 11/11 | 1428.83 | 1811.70 | 0.7888x |
| ascii64k | 0.9960x | 0.9990x | 5/11 | 1074.00 | 1015.13 | 1.0617x |
| large_json | 0.9996x | 0.9960x | 5/11 | 5933.51 | 6372.12 | 0.9318x |
| binary_mixed | 1.0044x | 0.9904x | 6/11 | 7456.09 | 6394.75 | 1.1673x |

Each throughput column is its own median; Vort/libzstd is the median of
same-process ratios. All 44 file-backed pairs improve. Controls stay near
neutral by median. The binary_mixed geometric mean includes a 0.8657x pair
at a host throughput shift: baseline/candidate fall from roughly 7,500 to
6,600 MiB/s for subsequent runs. This point is retained, not discarded.
An additional 11 pairs at 6,000 iterations for binary_mixed measure `1.0092x`
median / `1.0120x` geometric mean, with 10/11 wins. The initial dip does not
reproduce; this remains a control rather than a claimed optimization target.

Raw CSVs, input/executable hashes, commands, and validation logs are retained
locally in zig-out/zstd-sequence-fields-20260923/.

The target wide decoder starts at the same address in the two reference
executables; disassembly confirms one grouped input load and fewer total
instructions. This reduces the likelihood of an entry-alignment-only win.

Seven independent prepared-stage pairs also reduce sequence decode time:

| Input | Old ns/sequence | New ns/sequence | Median speed ratio |
| --- | ---: | ---: | ---: |
| README | 9.773 | 9.557 | 1.0259x |
| build.zig | 14.229 | 13.783 | 1.0297x |
| roadmap | 11.049 | 10.524 | 1.0505x |
| src/zstd.zig | 12.292 | 10.792 | 1.1392x |

The baseline stage was rebuilt from a clean archive of `ad167131`. Its ordered
checksum oracle and generic comparison remain enabled. These timings include
stage bookkeeping and use a separate executable layout; they diagnose the
sequence kernel and do not substitute for the public-API results above.

## Goal audit

This optimization is a bounded improvement toward industry-leading Zstd
compatibility decoding. Completion still requires repeatable superiority
across representative real corpora, compression levels, one-shot/reusable/
streaming APIs, dictionary workloads, memory measurements, and target CPUs.
The compatibility/corpus gates establish correctness coverage; they do not
establish that performance objective.

| Requirement | Evidence and remaining scope |
| --- | --- |
| Faster production decoder | Paired public-API benchmark above; the prepared stage is diagnostic only. |
| Optimized path matches a reference | Exact reader oracles, forced grouped-path fixture, generic block/error comparison, libzstd output comparison. |
| Bounded reads and writes | ReleaseSafe alignment/rejection/mutation tests, unchanged output copy preflight, suffix sentinels, decodecorpus stream-buffer bounds. |
| Preserve dictionaries and streaming | 276-case compatibility matrix and 9,900-frame corpus; grouped routing still excludes dictionary history. |
| No memory cost for the speedup | Group contains one u64 on the stack; no allocator, table, or persistent-state additions. This is a source-level bound, not a cross-competitor peak-RSS measurement. |
| Industry-leading performance | Not established: broader standard corpora, levels, APIs, CPUs, and competitor builds remain to be measured and improved. |
