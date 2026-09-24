# Zstd raw-literal all-FSE executor

This note records the 2026-09-24 optimization of the native Zstd decoder's
raw-literal, compressed-LL/OF/ML sequence path. The candidate is based on
`d7047e6a`, built with Zig 0.16.0 in `ReleaseFast` on an Apple M1 Pro, and is
compared with Homebrew libzstd 1.5.7 using one codec thread.

## Motivation and implementation

An eight-second, 1 kHz sample of the level-1 `nndl-v2 (1).pdf` frame collected
4,930 stacks. Dynamic `memmove` accounted for 2,033 top-of-stack samples,
while the raw/all-FSE executor and four-stream Huffman decoder were the two
dominant codec functions. The frame contains 8,295 sequences; 7,959 matches
are non-overlapping, and 7,926 matches have lengths from 3 through 63 bytes.

The raw/all-FSE executor now:

- loads each eight-byte FSE entry as one packed word;
- consumes sequence extras and state transitions from one grouped reverse-bit
  read whenever the bounded reader can supply the complete group;
- handles direct offsets and positive-literal rep0 without the generic offset
  dispatcher;
- uses a 16-byte forward wildcopy when the declared frame size proves writable
  tail space and the match distance is at least 16 bytes;
- keeps exact specialized copies for non-overlapping 3--63-byte matches and
  the existing dense 68--71-byte cases;
- preserves the generic checked match copier for overlap, dictionary, frame
  tail, and malformed-input cases.

The one-shot and reusable callers share one noinline runtime-selected executor
instead of emitting two `comptime` specializations. This keeps the optimized
path isolated and avoids unnecessary code duplication.

## Independent-binary A/B

The baseline and candidate were frozen before timing. Each pair alternated
execution order. The pure-Vort decode profiler used the same libzstd-generated
frame for each executable and verified the decoded bytes before timing.

| Input | Pairs won | Median speedup | Geometric mean |
| --- | ---: | ---: | ---: |
| `nndl-v2 (1).pdf` | 15/15 | 1.1851x | 1.1801x |
| `nndl-practice.pdf` | 15/15 | 1.4110x | 1.4141x |
| `zellij` | 11/15 | 1.0053x | 1.0060x |
| `build.zig` | 5/15 | 0.9906x | 0.9885x |
| `src/zstd.zig` | 6/15 | 0.9939x | 0.9967x |

The best-of-five reference harness gives a more stable `build.zig` control:
15 alternating pairs measure 0.9981x median / 0.9988x geometric mean. The
target improvements are therefore much larger than the observed non-target
variation.

The complete `~/Downloads/vort-test` result is recorded in
`zstd-vort-test-corpus.md`. Compared with the preceding decoder, level-1
one-shot time aggregation improves from 0.7321x to 0.8803x libzstd and reusable
aggregation from 0.8056x to 0.9173x. All 100 file/API/level combinations retain
byte-exact output.

## Rejected experiment

Replacing libc's dynamic copy for long raw literal runs with an explicit
16-byte vector loop reduced `nndl-v2` to 0.9736x of the grouped-executor
candidate by median, with only one win in seven alternating pairs. The loop was
removed; platform `memmove` remains preferable for those long runs.

## Validation

- `zig test src/zstd.zig -OReleaseFast`: 653/653 passed.
- Targeted ReleaseSafe raw/all-FSE test and all 16 match-copy tests passed.
- The fixed raw/all-FSE frame and 24 sequence-bitstream mutations compare the
  optimized decoder with the generic executor, including exact error parity.
- Compatibility probe: 276 cases, zero unsupported cases.
- Upstream `decodecorpus`: 9 campaigns, 9,900 frames, all 64 sequence-mode
  combinations, and real reusable table hits passed.
- Reference benchmark gate: 13 rows passed.
- Decode-profile gate: 5 rows passed.

These results establish a substantial improvement for a common PDF shape and
a broad mixed-corpus gain. They do not establish industry-leading Zstd decode
performance: the time-aggregated corpus ratios remain below libzstd, especially
for higher-level PDF frames.
