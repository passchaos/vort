# x86-64 Zstd pair branchless FSE transitions

Date: 2026-10-03. Baseline: `72de95e7`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
local libzstd 1.6.0-dev (`01b7154f`).

## Implementation and safety

The compact split-Huffman pair decoder consumes two match extra fields and up
to six FSE transition fields from its private shifting reservoir. In the fixed
128 KiB `large_json` oracle, neither match field is zero width. The transition
fields are usually zero width, however: across 663 accepted pairs the first
LL/ML/OF fields are zero 542/653/469 times and the second fields are zero
542/661/504 times.

The x86-64 shifting group now exposes a branchless read for those transition
fields. It converts `64 - width` to its modulo-64 shift count and masks the
result to exactly `width` low bits. A zero width therefore uses a zero shift,
a zero mask, and leaves the reservoir unchanged; widths 1--32 retain the
existing high-bit extraction and left-shift behavior. On the measured BMI2
target this becomes a `shrx`/`bzhi`/`shlx` sequence and removes the old
zero-width conditional result dependency. Match extra fields retain the
ordinary read because their observed width is nonzero.

The immutable `Group` implements the same method as an alias of its existing
checked read. Consequently non-x86 targets retain their prior extraction, and
the general reader, single-sequence paths, stream progress, malformed-input
handling, and public API are unchanged. The randomized shifting-group oracle
now compares ordinary and branchless reads with the immutable implementation
over eight alignments, 256 random payloads per alignment, six mixed-width
fields per payload, and explicit zero-width coverage.

The frozen complete executable shrinks from 6,490,328 to 6,489,048 bytes. The
split section changes only from `0x4798` to `0x479c`. Its production wildcopy
instance shrinks from `0x26af` to `0x265a` (85 bytes), while the non-wildcopy
instance grows from `0x20e9` to `0x2142` (89 bytes). End-to-end measurements,
not aggregate section size, decide retention.

## Performance

Both binaries were emitted through the same `-femit-bin` path and then frozen.
Every process was pinned to CPU 2, baseline/candidate order alternated by pair,
and each benchmark retained the fastest of five interleaved Vort/libzstd
samples.

Twenty-one pairs of 3,000 complete `large_json` decodes measured:

| Measurement | Median | Geometric mean | Wins | Range |
| --- | ---: | ---: | ---: | ---: |
| Candidate / baseline | 1.0440x | 1.0446x | 21/21 | 1.0205x--1.0750x |
| libzstd-normalized | 1.0429x | 1.0426x | 21/21 | 1.0141x--1.0632x |

Candidate throughput reaches 0.8835x local libzstd at the median and 0.8833x
geometrically, up from 0.8461x/0.8472x for the frozen baseline. This closes a
material part of the target gap but does not establish Zstd decode leadership.

Fifteen reusable pairs improve by 1.0435x median / 1.0441x geometric with
15/15 wins. The normalized geometric improvement is 1.0449x. Candidate
throughput reaches 0.8643x `ZSTD_decompressDCtx` at the median and 0.8634x
geometrically, versus 0.8241x/0.8263x for the baseline.

Seven-pair 13-row matrices keep `large_json` positive at 1.0397x one-shot and
1.0472x reusable by median. Geometric means across row medians are 1.0095x and
1.0027x directly, or 1.0043x and 1.0041x after simultaneous libzstd
normalization.

Long controls remain neutral:

| Control | One-shot raw geometric | Reusable raw geometric |
| --- | ---: | ---: |
| huffman80k, 3,000 iterations | 0.9991x | 1.0013x |
| large_text, 3,000 iterations | 1.0014x | 1.0022x |
| binary_mixed, 3,000 iterations | 1.0002x | 1.0013x |
| numbered_json, 100,000 iterations | 0.9987x | 0.9976x |

Exact observations and hashes are retained in
[zstd-pair-branchless-transitions-x86-20261003.json](data/zstd-pair-branchless-transitions-x86-20261003.json).

## Rejected adjacent candidates

- Marking every transition zero branch as likely changed control flow and
  measured only 0.9829x median / 0.9824x geometric over seven target pairs,
  with 0/7 wins.
- Applying the masked read to both match-extra and transition fields improved
  the target by 1.0300x median / 1.0291x geometric over 21 pairs, but was weaker
  than transition-only extraction and produced negative one-shot long-control
  geometry on `large_text`, `binary_mixed`, and `numbered_json`. It was removed.

## Validation

- All 16 field-group/bit-reader tests and the split-Huffman specialized versus
  generic oracle pass in ReleaseFast.
- All 682 direct ReleaseFast Zstd tests, `zig build check -j2`, the full project
  tests, and CLI help pass.
- Fourteen 13-row gates (seven one-shot and seven reusable) pass against the
  pinned local libzstd 1.6.0-dev reference; the 12-row path smoke and five-row
  decode-profile gate also pass.
- The 276-case compatibility matrix reports zero unsupported cases.
- Nine upstream decodecorpus campaigns pass all 9,900 frames, all 64 sequence
  mode combinations, and 2,699 block-stream cases.
- Generic x86-64 and AArch64 Linux ReleaseFast library compilation pass.

The host's separately installed libzstd 1.4.8 reusable smoke is currently
below the `numbered_json` 0.95 floor for both the unchanged baseline (0.9199x)
and candidate (0.9237x in the gate sample). The isolated 100,000-iteration
candidate/baseline control is neutral, and all pinned local-1.6.0 gates pass,
so this pre-existing absolute-reference drift is recorded rather than hidden
by lowering the gate.
