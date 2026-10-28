# Bzip2 adaptive Huffman coding and strategies

Date: 2026-10-29. Zig 0.16.0, Linux x86-64, Intel Core i7-10700K.

The encoder replaces its fixed two-table Huffman-only baseline with
positive-weight, length-limited canonical coding and complete physical bit
cost selection. Standard Bzip2 streams remain interoperable; compressed bytes
legitimately change. RLE1 block boundaries, BWT bytes/original pointers and
checksums retain their prior behavior. One-shot and incremental encoding use
the same strategy and remain byte-exact under input/output fragmentation.

`EncodeStrategy` is exposed by `bzip2` and as `Bzip2EncodeStrategy` at the root.
One-shot `EncodeOptions.strategy` and incremental `Options.strategy` default
to `balanced`. Fast uses fixed/global/uniform candidates without group
training. Balanced trains the standard symbol-count group choice
(2/3/4/5/6 at 200/600/1200/2400 thresholds) for four rounds and refines
selectors. Ratio first preserves that complete balanced result, then searches
the other group counts through six and refines the winner again.

## Cost, structure and safety

The forward BWT core stays separate. Huffman group seeding/assignments,
planning/costing, bounded length construction and wire emission are cohesive
modules in `src/bzip2`. The length builder uses `max(frequency, 1)` and stable
weight/index ties; the ordinary optimal tree is used when it fits twenty bits.
A noinline back-reference package-merge fallback supplies the constrained
optimum for deeper distributions, with `u64` weights. The natural and fallback
paths have about 7/68 KiB fixed scratch and no allocator. This is optimal for
the positive-weight objective, not a proof of globally optimal whole-stream
Huffman models or group partitions.

Every candidate cost includes:

```text
18 (group-count + selector-count fields)
+ sum(selector MTF ranks + 1)
+ sum(tables: 5 + alphabet size + 2 * adjacent-length absolute differences)
+ sum(selected symbol code lengths)
```

The fixed equal-width candidate is always retained; strict improvements alone
replace it. Unused groups are removed and their selector MTF cost is recomputed.
One used group is duplicated to satisfy the protocol's two-group minimum.
Payload-only assignments train models, while the final selector-aware greedy
candidate also prices the MTF unary bits. Its full-wire evaluation preserves
the old candidate when a local choice loses. Identical training tables keep
their lowest-index representative.

A single 50-symbol chunk can only train a global-frequency table plus empty
uniform-weight tables. If all global counts are 0/1, every possible group is
uniform after positive smoothing. The shared global/uniform candidates already
cover those cases, so all strategies return directly. Uniform weighting is a
separate cheap candidate because its table description can beat the global
model despite a slightly higher payload cost. For alphabets narrower than the
requested group count, valid chunk-region seeds allow all 2...6 groups without
underflowing alphabet partitions.

At most 900001 MTF/RUNA/RUNB/EOB symbols require at most 18001 selectors.
Two K-byte allocations request no more than 36002 bytes temporarily; one K-byte
selector array survives in the returned plan and is freed after wire emission.
All lengths are 1...20 and canonical values are below 2^20. Internal shape
errors map into the encoder's existing `InvalidBzip2Stream` error. Caller
allocators, sticky failures and atomic one-shot publication remain in use.
No whole-codec RSS or cross-library memory leadership is claimed.

Candidate inheritance establishes per-block physical-bit ordering:

```text
ratio <= balanced <= fast <= previous fixed-code encoder
```

Common block/stream fields and boundaries are unchanged, so final stream
byte counts have the same ordering after the sole final padding. This ordering
concerns the three strategies for the same input/settings; it does not imply
an ordering relative to another library.

## Native comparison

The final campaign has 18 inputs, five variants (old fixed, three strategies,
installed libbz2), two reversed-order repeats, five samples per call and three
iterations per sample: 180 calls / 900 raw rows. Every call's preflight output
is independently decoded with Python `_bz2`, and a separate Python entropy
inspector actually decodes canonical symbols through EOB, including numeric
RUNA/RUNB expansion, original-pointer bounds and bit-aligned next markers.
It checks physical selector/table/data costs rather than searching for magic.

The old codec source comes from Git commit
`80ea656b962b3f0abba89812b51a4e67139779f2`; current and old native probes are
rebuilt with Zig ReleaseFast and libc linkage. Both declare identical target,
compiler and CPU metadata. All codecs execute on CPU 2 with one codec thread.
The native timer includes output/scratch allocation, encode, sampled output
consumption, final shrinking and free. File I/O, hashes, raw BWT comparisons
and full decoder/entropy checks are outside timing. Preflight retains two raw
BWT outputs and the variant's encoded output; empty input omits raw BWT.
This is a warmed allocating-API comparison, with ordinary background load
recorded. It does not measure cold startup or equalize each algorithm's live
memory footprint.

libbz2 uses `BZ2_bzBuffToBuffCompress` with verbosity 0, workFactor 30 and the
case's blockSize100k 1 or 9. Its installed version is 1.0.8; actual shared-library,
Python extension, compiler, probe and input hashes are retained. Original
installed-library build flags are unavailable. Nominal block settings match;
libbz2's reserve below the advertised maximum can make the 900000-byte case
use two blocks where Vort uses one. The 899000-byte comparison also records
actual block geometry. Python decoding and native libbz2 use the same library
implementation and are not counted as two algorithmically independent oracles.

Sizes are bytes. Speed is old median divided by variant median across all ten
samples: below 1 means lower throughput / longer time.

| Input | Bytes | Old fixed | Fast | Balanced | Ratio | libbz2 | Fast speed | Balanced speed | Ratio speed |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| empty | 0 | 14 | 14 | 14 | 14 | 14 | 1.002x | 0.990x | 0.989x |
| tiny | 12 | 53 | 53 | 53 | 53 | 55 | 0.414x | 0.411x | 0.410x |
| unique256 | 256 | 419 | 388 | 388 | 388 | 445 | 0.728x | 0.446x | 0.162x |
| random16k | 16384 | 18604 | 16566 | 16566 | 16566 | 16852 | 0.965x | 0.650x | 0.322x |
| random64k | 65536 | 74020 | 65860 | 65860 | 65837 | 66169 | 0.993x | 0.758x | 0.414x |
| random900k | 900000 | 1014869 | 902798 | 902798 | 902436 | 903935 | 0.997x | 0.828x | 0.539x |
| source | 9576 | 4434 | 2534 | 2518 | 2495 | 2555 | 0.970x | 0.752x | 0.490x |
| json64k | 65536 | 3066 | 1259 | 1119 | 1116 | 1144 | 1.016x | 0.997x | 0.970x |
| periodic64k | 65536 | 54 | 46 | 46 | 46 | 45 | 0.989x | 0.983x | 0.991x |
| periodic900k | 900000 | 58 | 50 | 50 | 50 | 77 | 1.002x | 0.999x | 1.006x |
| nearly_periodic64k | 65536 | 62 | 53 | 53 | 53 | 53 | 1.001x | 0.998x | 0.991x |
| random899k | 899000 | 1013742 | 901796 | 901796 | 901432 | 902755 | 0.998x | 0.836x | 0.535x |
| logs64k | 65536 | 6087 | 2982 | 2167 | 2167 | 2176 | 0.991x | 0.936x | 0.823x |
| binary | 39296 | 23535 | 14956 | 14766 | 14662 | 14796 | 0.990x | 0.748x | 0.455x |
| already_compressed | 66169 | 74701 | 66466 | 66466 | 66449 | 66769 | 0.996x | 0.747x | 0.415x |
| mixed64k | 65536 | 30796 | 24120 | 22342 | 22260 | 22234 | 0.985x | 0.886x | 0.683x |
| longruns900k | 900000 | 51 | 49 | 49 | 49 | 48 | 1.007x | 1.000x | 1.019x |
| multiblock | 251000 | 6905 | 2386 | 2384 | 2384 | 2699 | 0.993x | 1.002x | 0.985x |

| Input | Fast MiB/s | Balanced MiB/s | Ratio MiB/s | libbz2 MiB/s |
| --- | ---: | ---: | ---: | ---: |
| random16k | 10.90 | 7.34 | 3.64 | 7.92 |
| random64k | 9.34 | 7.13 | 3.90 | 12.08 |
| random899k | 6.22 | 5.21 | 3.33 | 12.79 |
| random900k | 6.16 | 5.12 | 3.33 | 12.75 |
| source | 11.86 | 9.18 | 5.99 | 10.47 |
| json64k | 12.15 | 11.93 | 11.59 | 15.25 |
| binary | 10.67 | 8.06 | 4.91 | 17.58 |
| mixed64k | 5.94 | 5.34 | 4.12 | 15.67 |
| multiblock | 5.77 | 5.82 | 5.73 | 9.69 |

Fast preserves roughly 0.965...1.016x old throughput on most larger inputs
while cutting random sizes about 11%, source about 43%, and JSON about 59%.
Balanced cuts source/JSON about 43%/64% and improves log/mixed data further,
but random/source/binary rows still have material CPU overhead. Tiny unchanged
53-byte output takes about 2.4x the old time; unique256 has additional planning
cost as well. Ratio often spends substantially more time for small final byte
savings. These regressions remain explicit rather than being labeled a broad
speed win. In this corpus several Vort rows beat installed libbz2 size, while
periodic64k, longruns and mixed64k have slightly larger output; many rows have
lower throughput. No industry-best result follows from this slice.

[Final raw comparison](data/bzip2-huffman-adaptive-20261029/strategies.json)
retains all source/input/binary hashes, flags, commands, native clocks,
consumption checksums, code-size/order checks and per-block physical costs.
The complete source and reference identities are checked again before status
`ok`. [The initial full-search prototype](data/bzip2-huffman-adaptive-20261029/pilot.json)
passes 108 calls / 540 rows but regresses throughput strongly, so it is not the
production default. Its exact source delta/new files are preserved with
[reconstruction metadata](data/bzip2-huffman-adaptive-20261029/pilot-source.json).

## Verification and reproduction

```sh
zig build -j2 test-bzip2
zig build -j2 test-bzip2 -Doptimize=ReleaseFast
python3 tools/bzip2/huffman_wire_smoke.py
python3 tools/bzip2/huffman_campaign.py \
  --current zig-out/bin/vort-bzip2-bwt-bench \
  --baseline-commit 80ea656b962b3f0abba89812b51a4e67139779f2 \
  --cpu 2 --iterations 3 --samples 5 --repeats 2 \
  --report /tmp/bzip2-huffman.json
zig build -j2 test-bzip2-stream-consumers run-bzip2-stream-contract-diff \
  -Doptimize=ReleaseFast
zig build -j2 run-bzip2-diff
zig build -j2 check check-wasm
```

Debug and ReleaseFast each pass 74 Bzip2 tests. New length tests compare small
alphabets against brute optimum costs, Fibonacci bounds against an independent
depth dynamic program, and dense/zero/u32-edge weights against Kraft/canonical
properties. Planner tests check exact physical costs, threshold boundaries,
monotonic strategies, deterministic small paths, nonstationary groups,
allocation failures and the largest complete 20-bit values. Incremental tests
exercise all strategies across multi-block, one-byte-input/seven-byte-output
encoding. The independent wire smoke passes 100 valid tiny streams, complete
20-bit extremes, dynamic selectors, an embedded payload marker, 50 malformed
cases and six system streams including a non-byte-aligned multi-block input.

Final current-source compilation/Wasm passes 211/211 steps with observed
exit 0. Current ReleaseFast archive consumers pass 95 tests; Debug bidirectional
bz2, CLI help, and the independent 92-case stream-contract campaign pass.
A detached, clean checkout at feature commit `1fe1eda4` runs the full root tests
separately. That frozen-source test session later returns exit0 with5046 passed / two
skipped; its final log and source
identity are recorded separately from subsequent BWT changes. [Validation records](data/bzip2-huffman-adaptive-20261029/validation.json)
retain command exit codes/log hashes and the frozen-worktree identity.
Post-rebase ReleaseFast Bzip2 74 and the 92-case independent contract campaign
pass again; Wasm compilation and CLI help also return exit 0.
The pilot source reconstruction has independently recovered and hash-matched
all 48 files from the published base, exact tracked patch and nine new files.

Continue lowering tiny/planning overhead, profiling the remaining MTF/BWT
work, and measuring broader ratio/speed/memory frontiers with competitor build
provenance. An independent exact periodic-BWT ordering model is available for
the next core performance increment; no periodic fast path is added here.
All ten formats and the full functionality/performance objective remain open.
