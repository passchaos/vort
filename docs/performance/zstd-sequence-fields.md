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

## Frame-start invariant hoist (2026-09-24)

The split executor now validates `frame_output_start <= written` once before
decoding any sequence. Since every successful literal and match copy only
advances `written`, the relation is an invariant for the rest of the block.
Removing the repeated comparison from the common wildcopy predicate and the
bounded fallback cases shortens the hottest loop without weakening malformed
input handling. A direct test also pins the entry rejection before any output
or sequence state is consumed.

The baseline is local commit `34e63ba9`; candidate and baseline binaries use
the same frozen inputs and runtime libzstd 1.5.7 on Apple M1 Pro with Zig
0.16.0 ReleaseFast. Each result alternates process order and compares input
hash, encoded size, and decoded checksum.

| Input | Pairs won | Median candidate/baseline | Geometric mean | Candidate/libzstd median |
| --- | ---: | ---: | ---: | ---: |
| build.zig | 18/21 | 1.0123x | 1.0122x | 0.8841x |
| src/zstd.zig | 19/21 | 1.0067x | 1.0076x | 0.8408x |
| large_json | 15/15 | 1.0402x | 1.0396x | 0.9768x |
| README.md | 12/15 | 1.0093x | 1.0055x | 1.0080x |
| roadmap | 10/15 | 1.0029x | 1.0035x | 0.9868x |
| ascii64k | 9/15 | 1.0002x | 0.9999x | 1.0645x |
| binary_mixed | 6/15 | 0.9957x | 0.9969x | 1.1561x |

The small `binary_mixed` movement is below one percent and is treated as
noise. Experiments that cached all FSE states locally, borrowed the full table
specification, split out zero-literal sequences, or used an eight-byte short
match wildcopy all regressed the target loops and were removed.

## Dense small-literal routing on Downloads (2026-09-25)

Profiling the level-1 frame generated from
`~/Downloads/trace_1751546764.3447797.json` showed 65.81% of cycles in the
all-FSE split sequence executor. The prepared-stage report classified 234 of
242 sequence blocks as bounded and only two as wide, leaving their state
transitions on repeated checked `peekSmall`/`readSmall` calls even though the
blocks contain thousands of sequences.

The bounded small-literal path is now limited to fewer than 2,048 sequences.
Denser blocks reuse the existing same-capacity grouped executor, which reads up
to all six extra/state fields from one preflighted 64-bit group and uses the
already-validated copy kernels. This changes neither the maximum stack buffer
nor the generic, dictionary, or low-density route. A policy
boundary test pins 2,047/2,048 selection, while the existing split-Huffman and
dense sparse-literal tests retain fast/generic byte parity, malformed-input
classification, output-suffix guards, and reusable-state coverage.

The candidate and commit `63b60760` executables were frozen and alternated on
CPU 5 of the Intel Core i9-13900K host. Every invocation regenerated the same
level-1 frame from the Downloads source, checked Vort and system libzstd 1.5.5
output, and timed five decodes in each of five best-of rounds.

| Input | Pairs won | Median candidate/baseline | Candidate MiB/s | Candidate/libzstd |
| --- | ---: | ---: | ---: | ---: |
| `白话机器学习中的数学.pdf` | 2/7 | 0.9982x | 4656.95 | 0.6565x |
| `part1_22.pdf` | 2/7 | 0.9968x | 5366.51 | 0.7269x |
| `Controller.log.2025-09-01-11` | 3/7 | 0.9999x | 2976.18 | 0.7165x |
| `trace_1751546764.3447797.json` | 7/7 | 1.6880x | 2711.30 | 0.7166x |

The three unaffected files remain within 0.4% of the baseline median. On the
trace, routing changes the prepared-stage mix from 6 generic / 234 bounded / 2
wide blocks to 6 / 12 / 224 and reduces the isolated stage from 22.510 to
11.456 ns/sequence. A 1,536-sequence threshold was rejected: it displaced the
existing 1,834-sequence long-match fixture from its specialized path and was
slower on the trace smoke measurement.

## Immutable grouped reservoir

The grouped reader originally advanced each field by left-shifting the complete
64-bit reservoir. Its replacement keeps that word immutable and advances a
small consumed-bit cursor; each extraction uses the cumulative offset and a
width mask. This removes the loop-carried reservoir write dependency while
preserving the same one-load safety proof and zero-width behavior.

Seven fixed-CPU-5 level-1 pairs against commit `3b81b575` measured:

| Input | Pairs won | Median candidate/baseline | Candidate MiB/s | Candidate/libzstd |
| --- | ---: | ---: | ---: | ---: |
| `白话机器学习中的数学.pdf` | 5/7 | 1.0042x | 4689.27 | 0.6647x |
| `part1_22.pdf` | 5/7 | 1.0019x | 5411.59 | 0.7405x |
| `Controller.log.2025-09-01-11` | 7/7 | 1.0182x | 3021.75 | 0.7289x |
| `trace_1751546764.3447797.json` | 7/7 | 1.0070x | 2730.78 | 0.7152x |

The isolated trace sequence stage also moves from 11.456 to 11.389
ns/sequence in a five-round screen. All 14 reverse-reader and grouped-field
oracles pass before the end-to-end compatibility gates.

## Adaptive 32-byte match wildcopy

After the grouped-reader changes, `appendForwardWildcopy16` accounted for
9.59% of the Downloads trace profile. When the match offset is at least 32 and
the declared frame slice contains the rounded 32-byte destination span, the
split executor now copies one 32-byte vector per iteration. Smaller offsets or
tighter output tails retain the existing 16-byte implementation. The caller
still clips the writable slice to the declared frame size, so the wider copy
does not expand the public overwrite allowance.

The direct oracle compares the 32-byte implementation with generic LZ replay
over overlapping distances 32/47/64 and match lengths 3 through 128. A second
oracle requires the adaptive wrapper to choose the wide path only when its
full rounded destination is available, and verifies that the fallback leaves
the caller suffix untouched.

Seven fixed-CPU-5 level-1 pairs against commit `f9e9c02c` measured:

| Input | Pairs won | Median candidate/baseline | Candidate MiB/s | Candidate/libzstd |
| --- | ---: | ---: | ---: | ---: |
| `白话机器学习中的数学.pdf` | 5/7 | 1.0111x | 4711.30 | 0.6672x |
| `part1_22.pdf` | 3/7 | 0.9976x | 5406.35 | 0.7322x |
| `Controller.log.2025-09-01-11` | 7/7 | 1.0558x | 3182.47 | 0.7716x |
| `trace_1751546764.3447797.json` | 7/7 | 1.0436x | 2833.50 | 0.7472x |

The second PDF remains within 0.25% of baseline; the other three medians are
positive, with the copy-heavy log and trace showing the intended gain.

## Adaptive 64-byte match wildcopy

Matches with offsets of at least 64 bytes now have a third bounded tier. It
copies two 32-byte vectors per loop iteration and requires writable space
through the match length rounded up to 64. The adaptive dispatcher continues
to use the 32- and 16-byte implementations whenever either the history distance
or destination suffix is too short. Its direct oracle covers overlapping
distances 64/95/128 and match lengths 3 through 191.

Seven fixed-CPU-5 level-1 pairs against commit `b401f6dc` measured:

| Input | Pairs won | Median candidate/baseline | Candidate MiB/s | Candidate/libzstd |
| --- | ---: | ---: | ---: | ---: |
| `白话机器学习中的数学.pdf` | 3/7 | 0.9989x | 4711.79 | 0.6676x |
| `part1_22.pdf` | 6/7 | 1.0034x | 5357.22 | 0.7243x |
| `Controller.log.2025-09-01-11` | 7/7 | 1.0529x | 3359.26 | 0.8067x |
| `trace_1751546764.3447797.json` | 7/7 | 1.0462x | 2983.43 | 0.7820x |

The first PDF is neutral within 0.2%; the second is slightly positive, and the
copy-heavy log and trace both gain another four to five percent. The complete
32/64-byte dispatcher therefore raises the Downloads log and trace from the
pre-wildcopy 3021.75/2730.78 MiB/s results to 3359.26/2983.43 MiB/s.
