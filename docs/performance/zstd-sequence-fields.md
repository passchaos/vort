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

## Interleaved-path extension

The split decoder only accepts four-stream sections up to 32 KiB and at least
1,024 sequences. Blocks just below that count, or with larger regenerated
sections, decode through `decodeAllFseHuffmanSequences`, which interleaves
per-symbol Huffman decoding with sequence fields. The change following this
note applies the same one-load grouping to that path: six-field extraction
uses `sequence_field_group.Group`, with the checked `readSequenceField`
reader retained for overlong groups and the physical stream tail. Literal
Huffman per-symbol decoding, copy bounds, and error routing are unchanged.

Paired A/B (same host/executable protocol as above; old = `72ed5ea6`,
11 alternating pairs for roadmap/source, 7 for build/readme):

| Input | Median new/old | Geometric new/old | Wins | Vort MiB/s | libzstd MiB/s | Vort/libzstd |
| --- | ---: | ---: | --- | ---: | ---: | ---: |
| roadmap | 1.0385x | 1.0366x | 11/11 | 865.8 | 1249.5 | 0.6933x |
| source | 1.0012x | 1.0013x | 6/11 | 1489.8 | 1791.4 | 0.8303x |
| build | 0.9897x | 0.9969x | 3/7 | 1935.97 | 2184.39 | 0.8813x |
| readme | 0.9851x | 0.9940x | 3/7 | 1307.62 | 1346.96 | 0.9708x |

The gain is concentrated on roadmap, whose per-block sequence counts average
just under the 1,024 split threshold and therefore previously never used the
grouped reader. The other three inputs remain within run-to-run noise.
`zig build test` exits 0 with the change.

## Long-literal bulk fast path

The split fast path (`decodeAllFseSplitHuffmanSequences`) previously required
`literal_len <= 15`; any sequence with a longer literal run fell through to
`executeSplitHuffmanSequenceCold`, which rebuilds bounds and uses the generic
match copy. Temporary instrumentation of the real roadmap level-1 frame
counted 152,362 path decisions: 146,812 (96.4%) take the wildcopy fast path,
5,550 (3.6%) reach the cold path. Of those cold failures, 5,382 (96.9%) are
caused solely by `literal_len > 15`; the other 168 are `match_offset < 16`.
No failures come from literal bounds, offset upper bounds, or output space.

A new `appendBulkWildcopy16` in `src/zstd/literals/copy.zig` copies whole
16-byte chunks directly and handles the 1--15 trailing bytes with one
16-byte window, using the same source-padding/destination-overwrite contract
as `appendUpTo15Wildcopy16`. A dedicated branch handles `literal_len > 15`
before the cold path, leaving the original <=15 branch unchanged.

Paired A/B (same protocol; old = `fc2c6982`):

| Input | Median new/old | Geometric new/old | Wins |
| --- | ---: | ---: | ---: |
| roadmap | 1.0402x | 1.0409x | 11/11 |
| readme | 1.0380x | 1.0274x | 7/9 |
| source | 1.0207x | 1.0212x | 9/9 |
| build | 0.9865x | 0.9954x | 5/11 |

The net is a solid improvement. Build's ~1% negative is a codegen-layout
effect near the run-to-run noise floor; it has only 160 cold sequences and no
long-literal cases, so it pays branch-layout cost without benefit. The new
copy helper is covered by a length/alignment oracle test; `zig build test`
exits 0.

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
