# x86-64 Zstd pair shifting field group

Date: 2026-10-03. Baseline: `a30a1546`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
local libzstd 1.6.0-dev (`01b7154f`).

## Implementation and safety

The compact split-Huffman pair path decodes two adjacent one-literal rep0
sequences from one proven 64-bit suffix load. Its original `Group` kept the
loaded word immutable and advanced a separate consumed-bit counter, so every
field depended on both the preceding counter addition and a variable shift.

The x86-64 pair instance now uses `ShiftingGroup`: each read extracts the next
high field and shifts the private reservoir left by the consumed width. The
general grouped reader, every single-sequence fallback, and non-x86 targets
remain unchanged. Zero-width reads remain explicit no-ops, widths stay bounded
to 32 bits, and the existing pair proof still limits the complete group to 56
bits while requiring at least 64 physical bits. The parent reader is advanced
only after both command shapes have been validated, preserving truncation and
partial-progress behavior.

A randomized oracle compares the shifting and immutable readers across eight
input alignments, 256 payloads per alignment, and six mixed-width fields per
payload, including zero-width fields.

The complete executable shrinks from 6,493,056 to 6,490,328 bytes. The split
section shrinks from `0x48d2` to `0x4798`; its non-wildcopy instance shrinks
from `0x2276` to `0x20e9`. The production wildcopy instance grows from
`0x265c` to `0x26af`, so end-to-end measurements, rather than section size,
are the deciding evidence.

## Performance

Frozen executables were emitted through the same output path. Every process
was pinned to CPU 2, alternated baseline/candidate launch order, ran five
interleaved Vort/libzstd samples, and retained the fastest sample per codec.

Twenty-one pairs of 3,000 complete `large_json` decodes measured:

| Measurement | Median | Geometric mean | Wins | Range |
| --- | ---: | ---: | ---: | ---: |
| Candidate / baseline | 1.0353x | 1.0314x | 19/21 | 0.9293x--1.1179x |
| libzstd-normalized | 1.0368x | 1.0321x | 20/21 | 0.9233x--1.0513x |

The first four process pairs contain reciprocal host-scheduling outliers; the
remaining 17 pairs are stable and positive. Candidate throughput reaches
0.8469x of libzstd at the median, up from roughly 0.817x, so this is a material
improvement but not a broad leadership result.

Fifteen reusable pairs improve by 1.0385x median / 1.0380x geometric with
15/15 wins. The normalized geometric improvement is 1.0407x and candidate
throughput reaches 0.8277x of `ZSTD_decompressDCtx` at the median.

The prepared sequence-only stage is intentionally unchanged because it does
not execute the pair copy path; its 15-pair result is neutral at 1.0016x median
/ 1.0002x geometric. Seven-pair 13-row matrices measure `large_json` at
1.0384x one-shot and 1.0346x reusable geometrically. Matrix row-median
geometric means are 1.0142x/1.0012x raw and 0.9999x/0.9992x normalized.

Long 3,000-iteration controls remain close to neutral:

| Control | One-shot raw geometric | Reusable raw geometric |
| --- | ---: | ---: |
| huffman80k | 1.0015x | 1.0009x |
| large_text | 0.9999x | 1.0010x |
| binary_mixed | 0.9976x | 1.0022x |

Exact observations and hashes are retained in
[zstd-pair-shifting-fields-x86-20261003.json](data/zstd-pair-shifting-fields-x86-20261003.json).

## Rejected adjacent candidates

- Moving the pair's terminal-sequence handling into the ordinary path shrank
  the target instance by 60 bytes but measured only 0.9947x median / 0.9945x
  geometric over seven pairs.
- Combining each LL/OF shape test into one masked condition shrank the target
  instance by 168 bytes but measured 0.9704x / 0.9713x with 0/7 wins.
- A validated match-source prefetch measured 0.9943x / 0.9944x, and preloading
  the two literal bytes measured 0.9921x / 0.9914x. Both were removed.

## Validation

- The shifting-group oracle covers zero-width fields, mixed field widths, and
  every byte alignment against the immutable reader.
- The split-Huffman specialized-versus-generic oracle passes in ReleaseSafe.
- All 682 direct ReleaseFast Zstd tests pass.
- The 13-row one-shot and reusable reference gates, 12-row path smoke, and
  five-row decode-profile gate pass.
- The 276-case compatibility matrix reports zero unsupported cases.
- Nine upstream decodecorpus campaigns pass all 9,900 frames, all 64 sequence
  mode combinations, and 2,699 block-stream cases.
- Native `zig build check`, full project tests, CLI help, and AArch64 Linux
  ReleaseFast library compilation pass.
