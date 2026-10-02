# x86-64 Zstd pair entry guards

Date: 2026-10-03. Baseline: `f6123f84`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
local libzstd 1.6.0-dev (`01b7154f`).

## Implementation and safety

Every compact split-Huffman pair attempt first requires at least two remaining
sequences and at least 64 physical bits. The original combined source
condition made LLVM lower these overwhelmingly false failures to two `setcc`
instructions, an `or`, a comparison, and one branch before every pair.

The two conditions are now separate and each failure edge is marked unlikely.
On the measured x86-64 target this produces two direct compare-and-branch
guards, allowing the common fallthrough to enter the LL/OF table loads without
the boolean dependency chain. The checks are otherwise identical and retain
their order before every table lookup, bit read, state update, repeated-offset
update, or output write. A failed check still falls through to the ordinary
one-sequence decoder, so truncated-input and partial-progress behavior do not
change.

The frozen complete executable changes from 6,489,048 to 6,489,112 bytes, but
the split section shrinks from `0x479c` to `0x46ae`. Its non-wildcopy instance
shrinks from `0x2142` to `0x20fb` (71 bytes), and the production wildcopy
instance shrinks from `0x265a` to `0x25b3` (167 bytes).

## Performance

Both binaries were emitted through the same `-femit-bin` path and then frozen.
Every process was pinned to CPU 2, baseline/candidate launch order alternated,
and each process retained the fastest of five interleaved Vort/libzstd samples.

Twenty-one pairs of 3,000 complete `large_json` decodes measured:

| Measurement | Median | Geometric mean | Wins | Range |
| --- | ---: | ---: | ---: | ---: |
| Candidate / baseline | 1.0181x | 1.0187x | 21/21 | 1.0087x--1.0262x |
| libzstd-normalized | 1.0175x | 1.0172x | 20/21 | 0.9863x--1.0304x |

Candidate throughput reaches 0.9010x local libzstd at the median and
geometrically, versus 0.8854x/0.8857x for the frozen baseline. This is the
first retained measurement above 0.90x for this target, but it remains a gap
rather than a leadership result.

Fifteen reusable pairs improve by 1.0183x median / 1.0164x geometric with
15/15 wins. The normalized geometric improvement is 1.0167x. Candidate
throughput reaches 0.8772x `ZSTD_decompressDCtx` at the median and 0.8763x
geometrically, versus 0.8606x/0.8619x for the baseline.

Seven-pair 13-row matrices keep `large_json` positive at 1.0224x one-shot
(7/7) and 1.0094x reusable (6/7) by median. Short unrelated rows remain noisy;
the geometric mean across row medians is 1.0071x one-shot and 0.9953x reusable,
or 1.0044x and 0.9973x after simultaneous libzstd normalization.

Long controls resolve the meaningful non-target rows:

| Control | One-shot raw geometric | Reusable raw geometric | Pairs |
| --- | ---: | ---: | ---: |
| huffman80k | 0.9978x | 0.9973x | 31 |
| large_text | 1.0001x | 0.9980x | 15 |
| binary_mixed | 1.0052x | 0.9992x | 15 |
| numbered_json | 1.0004x | 1.0111x | 15 |

`huffman80k` uses the separate raw/all-FSE executor. Its section address,
size, and complete disassembly hash are identical in the two frozen binaries;
the small negative movement is therefore control noise rather than changed
generated code.

Exact observations and hashes are retained in
[zstd-pair-entry-guards-x86-20261003.json](data/zstd-pair-entry-guards-x86-20261003.json).

## Rejected adjacent candidates

- Branching around a complete three-field transition group when all widths are
  zero used measured 57%/62% first/second-group hit rates, but regressed the
  target to 0.9723x median / 0.9699x geometric with 0/7 wins.
- Extracting each transition triplet in parallel and shifting the reservoir
  once measured 0.9931x / 0.9928x with 0/7 wins. The cumulative-width
  dependency cost more than the two removed shifts.
- Requiring the target's two observed nonzero match-extra widths and using an
  unchecked positive-width reader was neutral-negative at 0.9997x / 0.9996x.
- Reusing a shifted OF control word produced byte-for-byte identical target
  disassembly and was removed without timing.

## Validation

- The split-Huffman specialized-versus-generic oracle passes in ReleaseFast;
  all 682 direct ReleaseFast Zstd tests pass.
- The system-libzstd one-shot 13-row gate, 12-row path smoke, and five-row
  decode-profile gate pass. Fourteen further 13-row gates (seven one-shot and
  seven reusable) pass against pinned local libzstd 1.6.0-dev.
- The 276-case compatibility matrix reports zero unsupported cases.
- Nine upstream decodecorpus campaigns pass all 9,900 frames, all 64 sequence
  mode combinations, and 2,699 block-stream cases.
- Generic x86-64 and AArch64 Linux ReleaseFast library compilation,
  `zig build check -j2`, the full project tests, and CLI help pass.

The separately installed libzstd 1.4.8 reusable smoke remains below its
`numbered_json` 0.95 floor at 0.9383x. The frozen parent baseline also failed
that host-sensitive row, while the 100,000-iteration candidate/baseline
control is positive. The floor is not weakened as part of this optimization.
