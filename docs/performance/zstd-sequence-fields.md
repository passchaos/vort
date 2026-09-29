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

## Dense small-literal routing on a private corpus (2026-09-25)

Profiling the level-1 frame generated from private-json showed 65.81% of cycles in the
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
level-1 frame from the private source, checked Vort and system libzstd 1.5.5
output, and timed five decodes in each of five best-of rounds.

| Input | Pairs won | Median candidate/baseline | Candidate MiB/s | Candidate/libzstd |
| --- | ---: | ---: | ---: | ---: |
| private-pdf-a | 2/7 | 0.9982x | 4656.95 | 0.6565x |
| private-pdf-b | 2/7 | 0.9968x | 5366.51 | 0.7269x |
| private-log | 3/7 | 0.9999x | 2976.18 | 0.7165x |
| private-json | 7/7 | 1.6880x | 2711.30 | 0.7166x |

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
| private-pdf-a | 5/7 | 1.0042x | 4689.27 | 0.6647x |
| private-pdf-b | 5/7 | 1.0019x | 5411.59 | 0.7405x |
| private-log | 7/7 | 1.0182x | 3021.75 | 0.7289x |
| private-json | 7/7 | 1.0070x | 2730.78 | 0.7152x |

The isolated trace sequence stage also moves from 11.456 to 11.389
ns/sequence in a five-round screen. All 14 reverse-reader and grouped-field
oracles pass before the end-to-end compatibility gates.

## Adaptive 32-byte match wildcopy

After the grouped-reader changes, `appendForwardWildcopy16` accounted for
9.59% of the private-json profile. When the match offset is at least 32 and
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
| private-pdf-a | 5/7 | 1.0111x | 4711.30 | 0.6672x |
| private-pdf-b | 3/7 | 0.9976x | 5406.35 | 0.7322x |
| private-log | 7/7 | 1.0558x | 3182.47 | 0.7716x |
| private-json | 7/7 | 1.0436x | 2833.50 | 0.7472x |

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
| private-pdf-a | 3/7 | 0.9989x | 4711.79 | 0.6676x |
| private-pdf-b | 6/7 | 1.0034x | 5357.22 | 0.7243x |
| private-log | 7/7 | 1.0529x | 3359.26 | 0.8067x |
| private-json | 7/7 | 1.0462x | 2983.43 | 0.7820x |

The first PDF is neutral within 0.2%; the second is slightly positive, and the
copy-heavy log and trace both gain another four to five percent. The complete
32/64-byte dispatcher therefore raises private-log and private-json from the
pre-wildcopy 3021.75/2730.78 MiB/s results to 3359.26/2983.43 MiB/s.

## Grouped fields with compact copy policy

Private-corpus level-9 frames exposed a second population of small-literal blocks:
the trace placed 221 of 242 sequence blocks on the bounded field reader, and
the log placed 479 of 485 there. Lowering the previous 2,048-sequence cutoff
directly was not viable because it also replaced the compact executor's common
68--71-byte match kernels.

Field decoding and copy policy are now independent compile-time choices. The
existing below-2,048-sequence executor uses the grouped 64-bit field reader but
retains its compact literal and match paths; denser blocks continue to use both
grouped fields and wide copies. No extra executor instance is emitted. The
1,834-sequence fixed frame now requires more than 1,000 production grouped
reads while retaining all of its single-literal, rep0, 68--71-byte match, and
fast/generic byte-parity assertions.

Seven baseline/candidate pairs were alternated on CPU 5 for every combination
of four private inputs and libzstd levels 1, 3, and 9:

| Level | First PDF | Second PDF | Log | Trace |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 1.0011x | 0.9992x | 0.9991x | **1.0174x** |
| 3 | 1.0002x | 1.0051x | **1.3828x** | **1.0259x** |
| 9 | 0.9975x | 0.9942x | **1.4408x** | **1.4236x** |

The level-9 trace stage changes from 16 generic / 221 bounded / 5 wide blocks
at 21.590 ns/sequence to 16 / 0 / 226 at 11.356 ns/sequence. Fixed-CPU
same-process reference runs measure level-3 log/trace at 2698.69/3039.34 MiB/s
(`0.6973x`/`0.8118x` libzstd 1.5.5) and level-9 log/trace at
3275.72/3206.22 MiB/s (`0.6188x`/`0.5869x`). The remaining level-9 reference
gap is still substantial.

## Compact long-match wildcopy

After grouped fields removed most sequence-bit overhead, level-9 profiles put
roughly 13% in generic match replay and its dynamic copies. The compact copy
policy now enables the bounded 64/32/16-byte dispatcher only for matches of at
least 72 bytes. Short matches, including the established 68--71-byte cluster,
retain their exact specialized copies. Known-size callers pass their existing
wildcopy proof into the compact executor; no-size callers continue to use the
checked path.

Seven fixed-CPU-5 pairs against commit `399aa51f` produced the following
candidate/baseline medians:

| Level | First PDF | Second PDF | Log | Trace |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 1.0232x | 1.0145x | 1.0014x | 1.0068x |
| 3 | 1.0131x | 1.0069x | 1.0315x | 1.0109x |
| 9 | 1.0109x | 1.0071x | 1.0779x | 1.0624x |

All twelve row medians are positive. Same-process fixed-CPU measurements put
level-3 log/trace at 2777.53/3087.66 MiB/s (`0.7177x`/`0.8118x` libzstd
1.5.5) and level-9 log/trace at 3528.15/3390.75 MiB/s
(`0.6578x`/`0.6265x`). Correctness remains tied to the same bounded copy
oracles, fast/generic frame comparison, and caller-suffix checks.

## Compact short-match wildcopy

The compact all-FSE split executor now follows libzstd's common sequence-copy
shape for short matches as well as long ones. When the frame declares its output
size, the match offset is at least 16, and the rounded destination remains
inside that declared frame, matches of 3--67 bytes use the existing bounded
16/32/64-byte forward wildcopy. The measured 68--71-byte cluster keeps its
exact specialized kernels, and matches of at least 72 bytes retain the previous
adaptive wildcopy route. Unknown-size, dictionary, generic, and fallback paths
are unchanged.

Against commit `d0b7486d`, independent ReleaseFast binaries were alternated on
CPU 5. Values are candidate/baseline medians; the q5 PDF-B and both q9 PDF
controls use 15 higher-iteration pairs.

| Level | PDF-A | PDF-B | Log | JSON |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 1.0013x | 1.0002x | 0.9992x | 1.0018x |
| 5 | 1.0025x | 0.9996x | 1.1984x | 1.0201x |
| 9 | 0.9994x | 0.9996x | 1.1647x | 1.1265x |

The controls stay within 0.1% at their confirmed medians. A 50-decode q9 Log
hardware-counter run reduced P-core cycles by about 9.2%, branches by 3.6%,
and branch misses by 32.5%; instructions increased by about 1.2%, consistent
with trading a branch-heavy exact-length dispatcher for bounded fixed-width
copies. Same-process q9 throughput is 4,071.26/3,897.95 MiB/s on Log/JSON,
or 0.7630x/0.7056x system libzstd 1.5.5. The gap is materially smaller but
industry leadership remains unproven.

The routing boundary, all 19 match-copy oracles, fast/generic split parity,
124-case libzstd-generated probe, 9,900-frame decodecorpus with every sequence
mode combination, reference benchmark gate, and full test/check graph pass.

## Minimum-width compact wildcopy

The compact executor now caps matches through 16 bytes at one 16-byte
wildcopy, even when the adaptive dispatcher could legally select a 32- or
64-byte store. This keeps the branch-light route above while avoiding up to
four times the necessary writes for the most common short-match buckets. Dense
and wide executors retain their established adaptive policy.

Against commit `437377b9`, independent ReleaseFast binaries were alternated on
CPU 5. Values are candidate/baseline medians; Log/JSON use seven pairs except
for the 15-pair q5 Log confirmation.

| Level | PDF-A | PDF-B | Log | JSON |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 1.0052x | 0.9982x | 0.9999x | 0.9994x |
| 5 | 0.9967x | 1.0028x | 1.0037x | 1.0064x |
| 9 | 0.9986x | 0.9978x | 1.0266x | 1.0320x |

The q5 Log confirmation wins 9/15 pairs with a 1.0036x geometric mean. All
other controls remain within 0.4%; the substantial q9 gains are isolated to
the intended short-match-heavy path. A 17--32-byte single-vector extension was
rejected after q9 Log/JSON measured 0.9988x/1.0003x over seven pairs.

Same-process q9 throughput reaches 4,172.74 MiB/s on Log and 4,014.74 MiB/s on
JSON, or 0.7755x/0.7262x system libzstd 1.5.5. The full correctness and
compatibility gates were repeated after this follow-up and remain green.

## Single-move compact short copies

The compact <=16-byte route now calls a dedicated one-move kernel instead of
the general 16-byte loop. Its preconditions prove a complete 16-byte source and
destination span, while the logical cursor still advances by the exact match
length. A full-buffer oracle covers every length from 3 through 16 at distances
16, 23, and 32 and verifies both logical bytes and the untouched caller suffix.

Against commit `3d27921e`, seven fixed-CPU-5 pairs improve q9 Log/JSON by
1.0029x/1.0090x and q5 by 1.0025x/1.0067x. The q5 Log result was confirmed over
15 higher-iteration pairs at 1.0037x median / 1.0036x geometric mean. The other
eight matrix controls range from 0.99495x to 1.0047x; the weakest q1 PDF-B row
measures 0.9981x median / 0.9993x geometric mean over 15 higher-iteration
pairs, while its 0.9950x five-pair screen included wider noise.

Same-process q9 throughput is 4,166.73 MiB/s on Log and 4,097.32 MiB/s on JSON,
or 0.7620x/0.7275x system libzstd 1.5.5 in that run. The small incremental gain
does not close the remaining reference gap.

## X86-64 sequence-loop alignment

The ReleaseFast all-FSE split executors now mirror the deliberate instruction
layout used by libzstd's `ZSTD_decompressSequences_body*` loops. On x86-64 an
inline assembler boundary places the sequence-loop entry 48 bytes into a
64-byte cache line, after the Huffman setup that makes function-entry alignment
alone insufficient. Builds other than x86-64 ReleaseFast omit the layout
directive, so the optimization has no semantic or portability surface outside
its measured target.

Against commit `7b246260`, independent ReleaseFast binaries were alternated on
CPU 5 with identical inputs and 50 iterations per process. Values are
candidate/baseline medians; Log/JSON q9 use seven pairs and all other rows use
five.

| Level | PDF-A | PDF-B | Log | JSON |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 0.9986x | 1.0029x | 1.0012x | 1.0013x |
| 5 | 1.0010x | 0.9996x | 1.0090x | 1.0026x |
| 9 | 1.0008x | 1.0089x | 1.0083x | 1.0079x |

The weakest control, q1 PDF-A, has a 0.9980x geometric mean; q5 PDF-B is
effectively neutral at 0.99997x. The q9 Log/JSON rows win 5/7 and 6/7 pairs,
with 1.0061x/1.0081x geometric means. Same-process candidate medians reach
4,213.69/4,030.42 MiB/s, or 0.7965x/0.7345x system libzstd 1.5.5 in this run.
The 124-case libzstd-generated probe, 9,900-frame decodecorpus, full test/check
graph, and 13-row reference benchmark gate all pass. Zstd decode leadership is
still not established.

## Complete X1 Huffman entries

The four-stream X1 decoder now uses a dedicated two-byte entry after canonical
table construction has proved complete prefix coverage. This follows
libzstd's fast-X1 invariant that a complete table needs no per-entry validity
tag: the entry stores one symbol and a full-byte bit count. Incomplete or
malformed tables retain the existing tagged lookup and checked fallback.

The ReleaseFast reservoir helper shrinks from `0x624` to `0x5cc` bytes. Its
disassembly contains 11 nibble-mask instructions instead of 39, while the
adjacent sequence executor remains the same size. A 256-tree randomized oracle
compares every compact symbol and bit count with the tagged reference table;
separate tests cover incomplete, overlapping, and excessive-weight trees.

Against commit `1011e1d8`, independent ReleaseFast binaries were alternated on
CPU 5. The table reports candidate/baseline throughput; longer confirmations
were used for q1/q9 PDF-A and q5 JSON.

| Level | Input | Pairs | Wins | Median | Geometric mean |
| ---: | --- | ---: | ---: | ---: | ---: |
| 1 | PDF-A | 15 | 4 | 0.9980x | 0.9980x |
| 1 | PDF-B | 5 | 5 | 1.0140x | 1.0152x |
| 1 | Log | 5 | 5 | 1.0096x | 1.0085x |
| 1 | JSON | 5 | 5 | 1.0054x | 1.0053x |
| 5 | PDF-A | 5 | 3 | 1.0013x | 1.0053x |
| 5 | PDF-B | 5 | 4 | 1.0033x | 1.0002x |
| 5 | Log | 5 | 4 | 1.0084x | 1.0031x |
| 5 | JSON | 11 | 9 | 1.0041x | 1.0039x |
| 9 | PDF-A | 15 | 7 | 0.9999x | 1.0003x |
| 9 | PDF-B | 5 | 5 | 1.0035x | 1.0039x |
| 9 | Log | 5 | 5 | 1.0074x | 1.0078x |
| 9 | JSON | 7 | 5 | 1.0082x | 1.0043x |

The sole confirmed negative control is q1 PDF-A at about -0.20%; q9 PDF-A is
neutral, and the other ten row medians are positive. Same-process q9
throughput reaches 4,232.21/4,073.28 MiB/s on Log/JSON, respectively
`0.7827x`/`0.7386x` system libzstd 1.5.5. The compact/reference table tests,
four-stream tail and corruption tests, 364-case native probe, 276-case
compatibility matrix, 9,900-frame decodecorpus across all 64 sequence-mode
combinations, full test/check graph, and 13-row reference gate pass. This
narrows one Huffman cost but does not establish Zstd decode leadership.

## Zero-width split and single-shift field extraction

The grouped field reader stores one sequence's reverse bit fields in a
left-aligned immutable `u64`. Its original branch-free extraction used two
dependent shifts so a zero-width field never requested an undefined 64-bit
shift. Every nonzero field paid for both shifts, up to six times per sequence.

The reader now returns zero immediately for a zero-width field. Nonzero fields
use the directly defined `bits >> (64 - consumed)` extraction, reducing that
path to one variable shift while preserving the same mask and monotonically
advanced cursor. The change stays in `zstd/sequence/field_group.zig`, so it does
not add another large sequence-executor instance.

Against commit `62563067`, 15 alternating-order complete 13-row reference
matrix pairs used independently built ReleaseFast binaries and explicit
Homebrew libzstd 1.5.7. Each row ran 1,000 decodes and retained identical input
hashes, encoded sizes, and checksums.

| Case | Pairs won | Median speedup | Geometric mean | Candidate MiB/s | Candidate/libzstd |
| --- | ---: | ---: | ---: | ---: | ---: |
| `huffman80k` | 15/15 | 1.3016x | 1.2951x | 1923.14 | 0.9474x |
| `large_json` | 15/15 | 1.1048x | 1.1055x | 5842.99 | 0.8744x |
| `binary_mixed` | 11/15 | 1.0036x | 1.0057x | 8280.79 | 1.1984x |
| `numbered_json` | 10/15 | 1.0028x | 1.0103x | 700.74 | 1.0550x |
| `ascii64k` | 7/15 | 0.9996x | 1.0008x | 1125.08 | 1.0642x |

The geometric mean of all 13 row medians is 1.0273x. The weakest non-tiny row
is the sequence-free `incompressible` control at 0.9916x; the 12-byte `tiny`
row measures 0.9829x while remaining 18.67x faster than the reference. Neither
control executes the optimized grouped reader, so these movements are treated
as fixed-overhead and host noise rather than an algorithmic regression.

The 14 direct reader tests cover zero-width fields, all starting alignments,
mixed six-field groups, rejected unsafe loads, cursor equality, and subsequent
reads. The fixed 80,000-byte raw/all-FSE frame passes one-shot and reusable
decode plus mutation/error recovery. The 13-row reference gate, 276-case
libzstd compatibility matrix, and all 9,900 upstream decodecorpus frames across
64/64 sequence-mode combinations pass.

Two nearby alternatives were rejected. Moving the sequence decrement before
field extraction measured only 0.9994x median with 10/21 wins on `huffman80k`.
Aligning the raw/all-FSE function to 16 bytes moved its page-edge entry by eight
bytes but measured 0.9983x with 8/21 wins; 64-byte alignment screened at
0.9764x. The retained gain comes from removing a dependent shift, not from
function placement.

## Restored direct 256-state FSE construction

A source/history audit found that the documented bitset builder had drifted
back to a three-stage implementation: fill a 264-byte contiguous symbol array,
scatter those symbols into the table, then revisit all 256 entries to derive
their transitions through a symbol-indexed counter. The decoder still selected
that path as `buildNoLowProbabilityAssumeValid`, so the extra work appeared in
every cold `large_json` frame.

The validated builder again constructs each symbol's final entries directly.
Four 64-bit masks represent its spread states; probabilities below 128 set the
occupied states, while dense probabilities start full and clear the smaller
complement. Ascending set-bit enumeration supplies the exact ordinal required
for `next_state`, eliminating both the symbol scratch and the final
symbol-indexed transition pass. The existing caller continues to prove the
256-state total and absence of low-probability `-1` symbols before entering the
unchecked implementation.

Against commit `e15013d1`, 15 alternating-order complete 13-row reference
matrix pairs used independent ReleaseFast binaries and Homebrew libzstd 1.5.7:

| Case | Pairs won | Median speedup | Geometric mean | Candidate MiB/s | Candidate/libzstd |
| --- | ---: | ---: | ---: | ---: | ---: |
| `large_json` | 15/15 | 1.0422x | 1.0443x | 6037.25 | 0.9179x |
| `binary_mixed` | 15/15 | 1.0284x | 1.0286x | 8464.84 | 1.2235x |
| `huffman80k` | 12/15 | 1.0025x | 1.0061x | 1923.83 | 0.9488x |

The geometric mean of all 13 row medians is 1.0046x. The initial matrix's
short `tiny` and `text` controls measured 0.9721x/0.9792x amid large individual
outliers. Longer 31-pair reruns recover them to 0.9967x/0.9926x medians.
Normalized symbol inspection shows that `decodeFrameInto`, both raw/all-FSE
executors, all split-Huffman executors, and the four-stream Huffman decoder
retain identical addresses between the two binaries, so unrelated control
movement is not caused by shifted decode code.

A five-second `large_json` sample reduces direct
`buildNoLowProbabilityAssumeValid` attribution from 351/3,987 samples (8.80%)
to 162/3,630 (4.46%). The 256-case randomized table oracle and pinned dense
226/208/255 distributions remain exact. The five-row decode-profile gate,
13-row reference gate, 276-case compatibility matrix, and all 9,900 upstream
decodecorpus frames across 64/64 sequence modes pass.

### Per-symbol transition ranges

The restored builder initially still recomputed `log2(next_state)`, the state
width, and the shifted transition baseline for every one of the 256 final
states. For one symbol, `next_state` walks the contiguous range
`[probability, 2 * probability)`, so its width crosses at most one power-of-two
boundary.

The finalized builder computes the share size, boundary count, and the two
baseline strides once per symbol. Its ascending set-bit walk advances a running
baseline and changes width only at that boundary. Values encoding an absent
symbol are skipped before this calculation; the randomized oracle includes
those zero-probability entries.

Against the direct-builder baseline `fa050e76`, 15 alternating pairs measure
`large_json` at 1.0151x median / 1.0164x geometric throughput with 14/15 wins.
`binary_mixed` is 1.0035x / 1.0024x with 9/15 wins, and `huffman80k` is neutral
at 1.0004x / 1.0053x. This isolates the transition precomputation from the
larger scratch-removal gain reported above.

## Rejected post-transition probes

Follow-up profiling at `13f323a3` attributed roughly 72% of `large_json`
samples to the small-copy split-Huffman sequence executor, 6.5% to its
four-stream Huffman reservoir, and 4.6% to the specialized 256-state FSE
builder. The four Huffman blocks have maximum code widths `10/7/7/7`; their
FSE descriptions are all different, so a within-frame exact-description cache
cannot remove the one-shot table builds.

Several narrowly scoped candidates were measured and removed:

- A six-symbol reservoir batch for widths at most nine improved `large_json`
  by only 1.0097x median / 1.0065x geometric mean in a five-pair screen, while
  growing the helper by `0xa0` bytes and reducing the raw/all-FSE `huffman80k`
  control to 0.9306x median with 0/5 wins.
- Moving grouped-reader fallback behind a checked noinline call shrank the
  target helper from 5,192 to 3,708 bytes and improved `large_json` by 1.0191x
  median / 1.0187x geometric mean over 15 pairs, but `binary_mixed` regressed
  to 0.9840x / 0.9861x. Keeping only the 68--71-byte match clusters inline and
  calling out for the remaining twelve sequences was worse: a five-pair screen
  put `large_json` at 0.9208x median.
- Reordering the direct-offset and positive-rep0 tests lost all five target
  pairs at a 0.9766x median. Marking the 6,059-of-7,299 common fused sequence
  branch likely also lost all five pairs, with a 0.9712x median.
- Reducing the small-copy instance's literal scratch bound from 16 KiB to its
  policy-proven 4 KiB changed only the stack decrement (`0x71a0` to `0x41a0`)
  and retained every key function address, but reached only 0.9911x median on
  `large_json` in five pairs.
- Carrying a no-low-probability flag out of normalized-count parsing removed a
  second symbol scan but reached only 0.9964x median on the target. Keeping each
  FSE bitset word in a local during set-bit enumeration initially screened
  positive, but a complete 15-pair 13-row matrix put `large_json` at 0.9967x
  median / 0.9973x geometric mean and `large_text` at 0.9790x; the row-median
  geometric mean was only 1.0013x.
- A dedicated 128-entry complete X1 table for four-stream trees of width seven
  or less passed forced-X1 and split-Huffman output checks, but its five-pair
  `large_json` median was only 1.0018x and the moved `binary_mixed` control was
  0.9752x. The existing full-width X1 path remains smaller overall.

These results reinforce that this AArch64 decode path is unusually sensitive
to instruction placement and register allocation. Future work should avoid
adding branches or helper calls to the established small-copy loop and should
prefer a separately measured one-shot table-state design or a genuinely
smaller, size-stable replacement rather than another additive specialization.

## Successor-aware sequence-table retention

The caller-owned multi-block decoder no longer copies the current block's
roughly 12 KiB LL/OF/ML table state when the immediately following compressed
block proves that all three sequence modes are independently defined. A small
out-of-line lookahead reads only the next block header, literals-section sizes,
sequence count, and mode byte. Any truncation, reserved mode bit, raw/RLE
successor, zero-sequence block, or Repeat_Mode field conservatively keeps the
old commit. Repeat offsets remain committed independently on every nonterminal
split-Huffman block.

The split-Huffman helper now owns only sequence execution and repcode progress;
its caller performs the large table copy when the frame-state flag requires it.
Other sequence executors, allocating APIs, incremental decoding, and the
reusable workspace retain their original table policy. Focused tests force both
an independent successor and a later Repeat_Mode block, and directly verify
that a followed split-Huffman block can preserve output and repcodes while
leaving `previous_tables` empty.

Against the frozen `13f323a3` profile binary, 15 alternating 20,000-decode
pairs measured `large_json` at 1.0254x median / 1.0236x geometric throughput
with 13/15 wins. `huffman80k` was neutral at 0.9971x median and `binary_mixed`
was positive at 1.0054x. A separate 15-pair complete 13-row matrix measured the
target at 1.0213x median / 1.0262x geometric throughput with 15/15 wins and a
1.0020x row-median geometric mean. A 21-pair, 10,000-decode `large_text`
control recovered the short matrix's noisy result to 0.9985x median. One later
campaign was discarded rather than reported because the frozen control
unexpectedly collapsed from roughly 5.9 GiB/s to 2.9 GiB/s while the candidate
stayed in its established range.

The final formal Homebrew libzstd 1.5.7 gate measures `large_json` at 6,102.34
MiB/s versus 6,509.45 MiB/s (`0.9375x`), up from the prior roughly `0.918x`
one-shot ratio without claiming parity. `huffman80k` reaches `0.9619x`, while
`binary_mixed` remains ahead at `1.2343x`.

All 659 ReleaseFast Zstd tests, the five-row decode-profile gate, 13-row
reference gate, 276-case compatibility matrix, and the full 9,900-frame
decodecorpus pass. The corpus covers 2,699 block-stream cases, 76,578 streamed
sequence blocks, every one of the 64 sequence-mode combinations, and reusable
cache hits; `zig build check -j1` also passes.

## Compact literal-plus-rep0 field decode

The small split-Huffman executor now recognizes its dominant one-literal,
OF-code-zero shape from the already loaded LL/OF words. That shape has no LL or
OF extra bits, so it skips both dynamic zero-width reads and selects rep0
directly; ML extra bits remain fully decoded because the common 71-byte match
is represented by a shorter base plus extra bits. The later exact one-literal
plus 71-byte copy continues to provide all literal, history, output, and caller-
suffix checks. A production-only hit counter in the fixed 128 KiB oracle proves
that more than 1,000 sequences use the compact field route before the existing
generic and 128-mutation comparisons.

The change shrinks the ReleaseFast small-copy helper from roughly 4,796 to
4,728 bytes. Against the frozen `f131da21` binary, 15 alternating 20,000-decode
profile pairs improve `large_json` by 1.0158x at the median with 13/15 wins.
The raw controls are neutral: `huffman80k` is 0.9962x and `binary_mixed` is
1.0055x at their medians. One 1.55x scheduling outlier inflates the target
geometric mean to 1.0426x and is not treated as representative evidence.

A separate 15-pair complete 13-row reference matrix measures `large_json` at
1.0064x median / 1.0016x geometric throughput with 10/15 wins and a 1.0050x
row-median geometric mean. Its short `large_text` control initially measured
0.9728x, but a 21-pair 10,000-decode rerun recovers to 1.0076x median / 1.0040x
geometric throughput with 13/21 wins. The formal libzstd 1.5.7 gate now reports
6,306.49 versus 6,597.31 MiB/s on `large_json` (`0.9559x`).

The explicit long-term decode requirement is at least `1.20x` libzstd on every
locked reference row, rather than aggregate or selected-row leadership. In the
current formal snapshot, five rows remain below that floor:

| Case | Vort/libzstd | Further Vort speedup needed for 1.20x |
| --- | ---: | ---: |
| `huffman80k` | 0.9193x | 1.3053x |
| `large_json` | 0.9559x | 1.2554x |
| `raw256k` | 0.9822x | 1.2217x |
| `numbered_json` | 1.0566x | 1.1357x |
| `ascii64k` | 1.0612x | 1.1308x |

`binary_mixed` is the first sequence-heavy row above the new floor at 1.2273x.
The complete 659-test suite, profile/reference gates, 276-case compatibility
matrix, 9,900-frame/64-mode decodecorpus, and `zig build check -j1` pass.

## AArch64 raw-block vector copy

Profiling the two-block `raw256k` frame showed that the complete structural
scan costs only about 6--7 ns per frame, while copying the two 128 KiB payloads
dominates the roughly 4 us decode. Recording block offsets or recognizing the
canonical two-block shape therefore cannot close the gap by itself. The
retained AArch64 path instead copies validated raw blocks of at least 4 KiB in
a 128-byte loop made from four 32-byte vectors. Other architectures and small
blocks keep `@memcpy`, and a non-multiple tail is copied exactly. Validation
still completes before the first output write, so unsupported frames preserve
the existing no-mutation fallback contract.

Against the frozen `c715ffc2` executable (SHA-256
`7f75f068cab21bed94cfe06721e65fa188a3cc6a435492c790a8abed737a5553`),
15 alternating 20,000-decode pairs improve `raw256k` by 1.0891x median /
1.0675x geometric throughput with 13/15 wins. The candidate executable is
SHA-256 `f9266d3129862c49070b9937dd9f6ae1a616919a027fb8b4c9f2d2dff423b1a3`;
`tryDecode` moves from `0x100047990` to `0x100047a30`, its real body grows by
only four bytes (612 to 616), and the isolated 96-byte copy helper starts at
the requested 256-byte boundary `0x100047d00`.

The same 15-run campaign measures a candidate/libzstd 1.5.7 median of 1.1716x
and geometric mean of 1.1591x, with only 4/15 individual runs at or above the
1.20x floor. A separate complete 13-row run records 60,792.61 MiB/s versus
53,779.15 MiB/s (`1.1304x`) for `raw256k`. This is a retained, reproducible raw
decode gain, but it does not satisfy the per-row 1.20x acceptance target; the
remaining median gap is about 2.4%, and the full-matrix observation leaves
about 6.2%. The host was concurrently loaded during these measurements, so the
relative paired result is the optimization evidence and neither absolute run
is promoted as an idle-host ceiling.

All 660 ReleaseFast Zstd tests, the five-row decode-profile gate, 13-row
reference gate, 276-case compatibility matrix, and the full 9,900-frame
decodecorpus pass. The corpus still covers 2,699 block-stream cases, 76,578
streamed sequence blocks, every one of the 64 sequence-mode combinations, and
reusable cache hits; the AArch64 helper also compiles out cleanly for an
`x86_64-linux-gnu` target, and `zig build check -j1` passes.

## Dense raw-literal short-pair sequences

The `huffman80k` name describes its five-symbol source rather than its literal
wire kind: libzstd emits one compressed block with only 19 raw literals and
5,161 all-FSE sequences. Of those sequences, 5,155 have zero literals. The
steady state alternates 2,574 eight-byte, distance-seven overlapping matches
with 2,575 non-overlapping 23-byte matches. Sampling attributes about 73% of
runtime to the raw all-FSE executor and another 8% to FSE table construction.

A separate narrow executor is now selected once per block when there are at
most 64 raw literals and at least 4,096 sequences. It recognizes packed LL/OF
symbols with zero base, zero extra bits, and zero transition width together
with an ML symbol for either the eight- or 23-byte match and one transition
bit. The fast iteration consumes that bit directly, performs the exact rep1
rotation, advances the three FSE states, and executes the already validated
match-copy primitive. Any field, state, history, output-bound, final-sequence,
or match-shape mismatch stays in the complete generic iteration. The block
router is out of line so ordinary raw all-FSE executors retain their previous
machine code; in particular, the `binary_mixed` FSE/FSE/RLE helper remains at
`0x1000657c8` with byte-identical instructions apart from relocations.

Against the frozen `002b0980` profile executable (SHA-256
`3058bfa22b4bb5e1890f8f44035668d0da0d5d2b881252343570bfa0a50a5122`),
15 alternating five-row pairs improve `huffman80k` by 1.4897x median /
1.4917x geometric throughput with 15/15 wins. The candidate executable is
SHA-256 `7d6a62f1e406f309e8a2ee5690906d51edc9fbd13ffbcab638f3ca254d89499d`.
The former compact executor begins at `0x100066438` and spans about 4,708
bytes; the dedicated instance begins at `0x100068a0c` and spans about 5,396
bytes. Five-row controls remain neutral by median: `numbered_json` 0.9968x,
`ascii64k` 0.9996x, `large_json` 1.0001x, and `binary_mixed` 1.0015x. A longer
21-pair `binary_mixed` rerun is 0.9961x median / 0.9973x geometric throughput,
consistent with the unchanged hot helper rather than a routed-path regression.

Fifteen independent same-process comparisons against Homebrew libzstd 1.5.7
put `huffman80k` at 1.4217x median / 1.4199x geometric throughput. The slowest
run is still 1.3864x, so all 15 runs clear the per-row 1.20x requirement. A
separate full 13-row run records 2,781.61 versus 1,963.23 MiB/s (`1.4169x`).
The raw all-FSE oracle requires more than 4,000 specialized hits, compares the
decoded bytes with the fixed 80,000-byte payload, checks allocating and
reusable decoders, and differentially tests 24 bitstream mutations against the
generic executor.

The reference gate's former 100-iteration raw row false-failed three times
during sustained `mobileassetd`/`dasd` load even though the identical binary's
immediate 5,000-iteration `raw256k` run measured `1.0846x`. The gate now uses
5,000 iterations per row (1.25 GiB of decoded output for `raw256k`) without
changing any performance floor, and passes. All 660 ReleaseFast Zstd tests,
the five-row decode-profile gate, 13-row reference gate, 276-case
compatibility matrix, full 9,900-frame/64-mode decodecorpus, and
`zig build check -j1` pass.

## Persistent Huffman-weight reservoir and grouped small fields

The `numbered_json` one-shot path still spends substantial time rebuilding its
FSE-compressed Huffman tree and then decoding 39 mixed-table sequences. The
weight stream has two independent FSE states, so its retained fast path keeps a
64-bit reverse reservoir across three even/odd pairs before refilling instead
of reconstructing a small reservoir for every transition. The last fewer than
64 bits retain the checked reader, including legal partial final transitions.

The same frame's LL=Predefined/OF=Compressed/ML=Predefined executor now groups
all extra fields and nonterminal transitions when the complete sequence fits
within 56 bits and at least eight physical bytes remain. A separate fallback
retains the original per-field checked reads. The fixed-frame oracle proves
that more than 30 of 39 sequences use grouped fields, while the existing
specialized/generic comparison, short-output progress check, and every
single-bit sequence mutation retain exact results and error ordering.

Against the frozen `b55f2111` profile binary (SHA-256
`7d6a62f1e406f309e8a2ee5690906d51edc9fbd13ffbcab638f3ca254d89499d`),
15 alternating five-row pairs improve `numbered_json` by 1.0822x median /
1.0853x geometric throughput with 14/15 wins. The candidate binary is SHA-256
`a1db3f61094c9fcb54e5e362c599b81b7a7ea462176194a80f6233fff7440984`.
Control medians are `huffman80k` 0.9997x, `ascii64k` 1.0003x, `large_json`
0.9950x, and `binary_mixed` 1.0035x; the five-row median geometric mean is
1.0156x.

Fifteen independent same-process comparisons against libzstd 1.5.7 measure
`numbered_json` at 1.1375x median / 1.1365x geometric throughput. No run yet
reaches 1.20x, so this row remains open and needs another roughly 5.5% median
Vort improvement rather than being declared complete. All 660 ReleaseFast
Zstd tests, the profile/reference gates, 276-case compatibility matrix, full
9,900-frame/64-mode decodecorpus, and `zig build check -j1` pass.

## Wide two-symbol table for seven-bit literals

The sequence-free `ascii64k` frame has a 7-bit Huffman tree and a compressed-
literal ratio near 0.83. The existing 11-bit X2 table cannot represent two
worst-case symbols in one entry, so its larger entries do not remove the hot
dependent lookup and it loses to the tuned X1 reservoir on this shape. The new
wide route builds a 16,384-entry, 14-bit table only for 7-bit four-stream
sections of at least 64 KiB whose literal ratio is at most 0.90. Every table
entry contains exactly two output bytes and their combined bit count. Four
persistent reservoirs therefore emit eight bytes per stream from four lookups
before refill, halving the steady-state lookup chain. Other X2 and X1 shapes
retain their established routes.

The initial X1 follow-up remains useful as the fallback: widths up to seven
decode eight symbols per stream before refill. Against the frozen X1 profile
binary (SHA-256
`e92e5b7092c06c6af38931544e46c9426522605692db5376f3665cb1fd719035`),
the final wide-table profile binary (SHA-256
`77da7ba1ca86a4e55c3d46f004e8a516020d984a648bcf9a57b82daac3bcded1`)
improves focused `ascii64k` by 1.3054x median / 1.3088x geometric throughput
over 15 alternating pairs with 15/15 wins. A separate 15-pair five-row matrix
with the same hot instructions records control medians of `numbered_json`
0.9995x, `huffman80k` 1.0024x, `large_json` 0.9949x, and `binary_mixed`
1.0013x; all movements are below one percent and are treated as layout/noise,
not cross-row gains or regressions.

Fifteen independent same-process comparisons using the final reference binary
(SHA-256
`04a188870b68250f933516ab3e744f767f044c4150f28e840608c24ba2aaa1e9`)
measure Vort/libzstd 1.5.7 at 1.5182x median / 1.5205x geometric throughput.
The minimum is 1.4979x and all 15 runs clear the required 1.20x floor. A
separate 5,000-iteration complete reference gate records 1.5017x. The dedicated
oracle covers the 7-bit table, direct ABI, guarded output, truncation, and the
production selector. All 664 ReleaseFast Zstd tests, the five-row profile gate,
13-row reference gate, 276-case compatibility matrix, full 9,900-frame/64-mode
decodecorpus, and `zig build check -j1` pass. `ascii64k` is therefore removed
from the below-floor list; `raw256k`, `numbered_json`, and `large_json` remain
open.

## Prepared narrow lookup and single-stream literal batches

The small `numbered_json` frame rebuilds an FSE-compressed seven-bit Huffman
tree, then executes 39 LL-predefined/OF-FSE/ML-predefined sequences. Its fixed
oracle contains 36 one-byte literal runs and begins with one 64-byte literal
run. The decoder now fills the complete 128-entry narrow lookup while assigning
canonical tree prefixes, instead of walking the completed tree a second time.
Thirty-three non-tail one-byte runs use one direct checked lookup. The initial
single-stream run keeps the same reverse reservoir across eight symbols per
refill and covers at least 48 literal bytes before returning its tail to the
existing checked cursor. Other literal lengths, stream tails, and malformed
input retain the established fallback and error ordering.

Against the frozen `13bb21a4` profile binary (SHA-256
`77da7ba1ca86a4e55c3d46f004e8a516020d984a648bcf9a57b82daac3bcded1`),
the final candidate (SHA-256
`bc578bf0bf25c1ce7feffba804d063c4fe707ff858de94a519a8c211a2e30216`)
improves focused `numbered_json` by 1.1604x median / 1.1601x geometric
throughput over 15 alternating pairs with 15/15 wins. A separate 15-pair
five-row matrix records 1.1441x / 1.1474x on the target. Control medians are
`huffman80k` 0.9948x, `ascii64k` 0.9916x, `large_json` 1.0108x, and
`binary_mixed` 0.9870x; all stay within 1.4% on the loaded host.

Fifteen independent 50,000-iteration comparisons using the final reference
binary (SHA-256
`18f7ae363e7cd73d3efcc6fc743289e4a64cfd98093a46d430842934f032c6d7`)
measure Vort/libzstd 1.5.7 at 1.3195x median / 1.3204x geometric throughput.
The minimum is 1.2935x and all 15 runs clear the required 1.20x floor; the
separate complete 13-row gate records 1.3059x. The fixed-frame oracle compares
specialized and generic output, requires 33 direct
single-literal hits and at least 48 reservoir literal hits, checks short-output
progress, and differentially mutates every sequence byte. `numbered_json` is
therefore removed from the below-floor list; only `raw256k` and `large_json`
remain open.
All 664 ReleaseFast Zstd tests, the profile/reference gates, 276 compatibility
cases, the 9,900-frame/64-mode decodecorpus, and `zig build check -j1` pass.

## Compact split-Huffman sequence pairs and exact long-match tails

The `large_json` blocks contain 1,834 sequences per full block. Their dominant
shape is a one-byte literal followed by positive-literal rep0; 663 pairs can be
decoded from one 64-bit sequence-field load. The retained pair path validates
both FSE transitions before committing reader progress, checks the pair's
literal/output/history bounds once when the frame content size provides a
bounded output slice, and falls back to the complete single-sequence decoder
for every other shape. A second single-sequence path covers 111 positive-rep0
sequences whose literal lengths are 2--4 and whose matches are all 68--71
bytes. Direct offsets retain their separate one-literal fast path.

The 68--71-byte copy cluster keeps exact logical writes. The 71-byte kernel
loads its seven-byte tail once from an eight-byte initialized window; when one
destination suffix byte exists it preserves that byte and emits one packed
eight-byte store, while a tight slice uses the exact 4+2+1-byte fallback. The
paired executor also gives the dominant 70-byte case a constant-length branch. The 256-state no-low FSE
builder has a linear one-gap path for a 255/256-probability symbol, and paired
field decoding uses `Group.initProven` after its existing 64-bit availability
proof. These are portable scalar/vector Zig paths selected by format shape;
the AArch64 raw-copy loop separately keeps four independent 32-byte loads live
before its four stores.

Against frozen `/tmp/vort-large-direct-offset` (SHA-256
`912e5bda8b3ef97d0381ea8f16542278e94dd1c237c36ae68a42d846bdad0af6`),
the final candidate improves focused `large_json` throughput by `1.0469x`
median / `1.0460x` geometric over 21 alternating pairs with 21/21 wins. The
70-byte branch separately measures `1.0073x` median / `1.0098x` geometric
with 14/15 wins, and the preloaded exact 71-byte tail measures `1.0138x` /
`1.0151x` with 14/15 wins. Fifteen long comparisons against libzstd 1.5.7
measure `1.1979x` median / `1.1990x` geometric, range `1.1881x`--`1.2095x`;
5/15 runs clear 1.20x. The row is therefore materially improved but remains
open under the strict every-run 1.20x requirement.

A follow-up AArch64 builder specializes normalized tables whose dominant
symbol owns at least 192 of 256 states. It enumerates only the sparse gap
states, then writes each contiguous dominant-symbol run in four packed table
entries at a time; all lower-density distributions retain the established
bitset/`ctz` builder. The existing randomized 256-state oracle and the three
locked `large_json` distributions compare every generated entry with the
generic mapped builder. Against frozen committed candidate
`5247b6e2be7fc9999cc57f07411af17265366c72960996e63844942e3fc4742b`,
21 alternating pairs improve `large_json` by `1.0197x` median / `1.0202x`
geometric throughput with 21/21 wins and a `1.0121x` minimum. Fifteen
5,000-iteration comparisons against libzstd 1.5.7 reach `1.2269x` median /
`1.2266x` geometric, range `1.2121x`--`1.2382x`; every run now clears the
strict 1.20x floor, so `large_json` is closed.

The reference benchmark now alternates the five Vort and libzstd samples
instead of measuring all Vort samples, then allocation, then all reference
samples. It still reports each codec's best sample and uses the same payload,
iteration count, correctness checks, and throughput formula. This removes a
large ordering bias on heterogeneous Apple cores without changing a floor.
Even with that correction, `raw256k` remains strongly bimodal under sustained
`mobileassetd`, `dasd`, Defender, and concurrent Zig load. The load-first
128-byte kernel is retained because its independent-load schedule improves
the two noisy alternating campaigns by `1.0059x` median / `1.0124x` geometric
(12/21 wins) and `1.0216x` / `1.0424x` (9/15 wins), but those results are not
strong enough to declare the raw row complete. No Downloads corpus was run,
because the requested all-row 1.20x precondition is not yet satisfied.

Two later M1 raw-copy follow-ups were measured and removed. A canonical
two-full-128-KiB-block detector plus fixed-boundary copier measured 0.9423x
median / 0.9575x geometric throughput with only 7/21 wins against the retained
kernel. Rewriting the same 128-byte loop around an end pointer removed one
`sub` from each iteration, but measured only 0.9603x / 0.9649x with 6/21 wins;
the extra mask/tail setup and changed register layout outweighed the saved
instruction. The committed remaining-length loop therefore stays authoritative
for `raw256k`.
