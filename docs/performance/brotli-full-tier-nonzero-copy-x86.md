# Brotli full-tier nonzero match-copy entry

Date: 2026-10-02. Baseline: `40018f0a`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
local libbrotli 1.2.0-dev (`558fc647`), CMake Release (`-O3 -DNDEBUG`).

## Measured shape and implementation boundary

The public stream-summary counters added at the baseline measured the frozen
1,251,399-byte roadmap input as follows:

| Input | Commands | Zero insert | One literal | Implicit distance | Copy-length log2 buckets 0...8 |
| --- | ---: | ---: | ---: | ---: | --- |
| roadmap q9 | 109,100 | 88,384 | 10,935 | 990 | 0;811;32886;59627;13580;1941;243;12;0 |
| roadmap q5 | 118,278 | 93,272 | 14,362 | 1,135 | 0;516;45614;59524;10521;1851;240;12;0 |

Lengths 4--15 therefore cover 84.80% of q9 commands and 88.89% of q5
commands. The streams apply 108,263 and 117,343 LZ77 copies respectively;
the remaining non-terminal commands are static-dictionary copies.

Every decoded Brotli command has a positive copy length by construction. The
129--256-literal-tree executor now calls `appendWideNonZero` after validating
that length against remaining meta-block output. The existing `appendWide`
wrapper keeps zero-length behavior for general callers and tests, while the hot
entry asserts the stronger contract in safe builds and omits the redundant
runtime branch in ReleaseFast. Narrower Brotli executors and all non-x86 copy
policies retain their previous behavior.

The full-tier payload shrinks from `0x16a0` to `0x1690` bytes. Both complete
benchmark executables are 6,104,264 bytes. Baseline SHA-256 is
`a9bf7a273371c9346c67961814dbd1436ade46e3d566ea3e510b0db6065e5764`;
candidate SHA-256 is
`615e569cd24c4201c0f381c7c319c5a4d31acfab427b396490b4a12ae92c6d4e`.

## Whole-frame measurements

Every process used the same pre-encoded frame and five warmed internal timing
rounds. Baseline/candidate launch order reversed on alternate pairs. The main
target runs used 500 caller-owned Vort decode iterations.

| Input | Pairs won | Median | Geometric mean | Minimum |
| --- | ---: | ---: | ---: | ---: |
| roadmap q9 | 14/15 | 1.0049x | 1.0059x | 0.9999x |
| roadmap q5 | 6/7 | 1.0049x | 1.0037x | 0.9979x |

A separate 100-iteration run timed Vort and libbrotli in the same processes.
It measured q9/q5 raw medians of `1.0034x`/`1.0028x`, reference-normalized
geometric ratios of `1.0007x`/`0.9999x`, and candidate/libbrotli medians of
`0.7616x`/`0.7807x`.

Decoder-only seven-pair controls were neutral-positive geometrically: source
q9 `0.9992x` median / `1.0026x` geometric, source q5 `1.0010x` / `1.0018x`,
and clustered q8 `1.0009x` / `1.0023x`. This is a small, bounded full-tier
improvement, not evidence of general Brotli decode parity or leadership.

## Rejected alternatives

- Putting the `<=16` fixed-copy branch before `<=32` was neutral on q9
  (`1.0010x` median, 4/7 wins) and regressed q5 (`0.9976x`, 2/7).
- Classifying meta-blocks that never reach the window-distance limit added a
  second conditional move inside the generated loop and grew the executable by
  304 bytes, so it was rejected before long timing.
- Extending the 32-bit command root to fuse one-literal inserts grew the hot
  payload by 133 bytes. It regressed q9/q5 to `0.9878x`/`0.9751x` medians,
  both with 0/7 wins.
- Marking the once-per-meta-block terminal insert branch unlikely grew the hot
  payload by 111 bytes and regressed q9/q5 to `0.9941x`/`0.9928x` medians.
- Marking the final non-overlap arm of `appendWideNonZero` likely was neutral:
  15 decoder-only pairs measured `1.0000x`/`1.0023x` geometrically on roadmap
  q9/q5, while same-process libbrotli normalization measured
  `0.9999x`/`1.0003x`. Moving the insert-length bounds check inside the
  zero-insert branch was also neutral at `1.0001x`/`1.0006x` across seven
  pairs. Both candidates were removed.

## Validation

- The scalar copy oracle covers distances 1--64, lengths 0--64, and writable
  slack at 0, 1, 15, 16, 31, 32, 47, 48, 63, and 64 bytes.
- The full-wide transition/truncation oracle passes.
- Direct replay of the built test binary: 1,685/1,685 tests passed.
- `run-br-reference-bench-gate`: 13 rows passed against libbrotli 1.2.0-dev.
- `run-br-reference-bench-path-smoke`: three valid and five rejected path cases passed.
- `run-br-upstream-multiblock-diff`: 7,056 generated one-shot, 7,056
  progressive, 1,401 fragmentation, 64 high-tree truncation, and seven Large
  Window cases passed.
- `run-br-real-corpus-diff`: 16/16 one-shot and 16/16 progressive cases passed.
- AArch64 compile, `zig build check -j2`, and CLI `--help` smoke passed.

Raw measurements and hashes are retained in
[brotli-full-tier-nonzero-copy-x86-20261002.json](data/brotli-full-tier-nonzero-copy-x86-20261002.json).
