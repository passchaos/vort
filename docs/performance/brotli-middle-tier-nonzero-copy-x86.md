# Brotli middle-tier nonzero match-copy entry

Date: 2026-10-02. Baseline: `b1bd6f5a`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
local libbrotli 1.2.0-dev (`558fc647`), CMake Release (`-O3 -DNDEBUG`).

## Scope and invariant

The preceding full-tier change established that decoded Brotli commands always
have a positive copy length and benefit from bypassing the generic helper's
zero-length guard. This change extends that invariant only to the isolated
65--128 literal-tree executor. The frozen source q9/q5 frames contain
50,574/54,075 commands and apply 48,751/52,136 LZ77 copies, so the redundant
guard executes tens of thousands of times per frame.

`append` retains its prior implementation and zero-length behavior for every
existing caller. The new `appendNonZero` duplicates the compact 32-byte copy
policy with a safe-build assertion, and only the 9-bit middle-tier executor
calls it after validating the copy length against remaining meta-block output.
The x86-64 full-tier helper keeps its separate 64-byte policy; on non-x86
targets it continues to call the original generic helper.

The selected `processWideExternalLiteralLookup9CompressedPayload` instance
shrinks from `0x10b6` to `0x10a4` bytes. GNU `objcopy` comparisons show that
the ordinary `.text`, Large Window, paired full-tier, and 10-bit auxiliary
sections are byte-identical. Total ELF text/data/bss size is unchanged; only
debug metadata grows the file from 6,104,264 to 6,104,424 bytes. Baseline
SHA-256 is
`615e569cd24c4201c0f381c7c319c5a4d31acfab427b396490b4a12ae92c6d4e`;
candidate SHA-256 is
`b0a714fb246939689d52932f7c6a9b1266a797a6d6fca7478e5cb847325ac8ed`.

## Performance evidence

The 1,726,567-byte source snapshot is from commit `488c5415`, SHA-256
`b75cf6294797c217c0e4a17054a65c5e2d6a355529eccd65c7fd94c24f26fff0`.
Its q9/q5 frames are 141,001/147,580 bytes. Each process uses five warmed
internal rounds, is pinned to CPU 2, and alternates baseline/candidate launch
order across pairs.

| Input | Iterations | Pairs won | Median | Geometric mean | Minimum |
| --- | ---: | ---: | ---: | ---: | ---: |
| source q9 | 500 | 13/15 | 1.0059x | 1.0054x | 0.9984x |
| source q5 | 500 | 7/7 | 1.0053x | 1.0053x | 1.0035x |

A separate 100-iteration campaign timed Vort and libbrotli in each process.
Source q9 improved `1.0069x` median / `1.0071x` geometric with 15/15 wins;
reference-normalized geometry is `1.0082x`. Source q5 improved `1.0059x` /
`1.0066x` with 7/7 wins and `1.0033x` normalized geometry. Candidate
throughput remains `0.7567x`/`0.7493x` local libbrotli, so this is a bounded
middle-tier gain rather than a broad leadership result.

Seven-pair, 500-iteration full-tier controls are neutral: roadmap q9 measures
`1.0024x` median / `1.0012x` geometric; roadmap q5 measures `0.9978x` /
`1.0007x`. A separate 13-row matrix has `0.9996x` row-median geometric mean;
its non-target executable sections are byte-identical, so the remaining
sub-percent row movement is scheduling noise rather than changed code.

## Rejected alternatives

- Refactoring the generic `append` into a wrapper around the new entry retained
  strong source gains, but changed non-target code generation. Its 13-row
  matrix fell to `0.9975x` row-median geometric mean, with `structured_q11` at
  `0.9903x` median, so the generic implementation was restored verbatim.
- Removing the prepared-distance symbol bound across shared optimized paths
  regressed roadmap q9/q5 to `0.9917x`/`0.9922x` medians. Isolating the same
  change to full-tier still measured `0.9935x`/`0.9948x`; both were removed.
- Always invoking the staged reader for the almost-unused zero-width distance
  field measured `0.9983x`/`0.9994x` on roadmap q9/q5 and was removed.
- Two exact 32-byte vectors for non-overlapping 33--64-byte matches regressed
  source q9/q5 to `0.9544x`/`0.9541x` geometrically. Combining the zero and
  out-of-window distance tests also regressed the middle tier to
  `0.9954x`/`0.9918x`; the equivalent full-tier experiment was neutral at
  `1.0012x`/`0.9992x`. All three variants were removed.

The retained successor instead marks the post-short-copy non-overlap branch
likely. It changes no copy operation or error ordering and improves source q9
and q5 by `1.0038x`/`1.0022x` geometrically over 15 decoder-only pairs. Full
evidence is in
[brotli-middle-nonoverlap-branch-x86.md](brotli-middle-nonoverlap-branch-x86.md).

## Validation

- The scalar copy oracle compares `appendNonZero` with bytewise replay for
  distances 1--64, lengths 1--64, and all existing writable-tail boundaries.
- The 65--128-tree specialized/generic oracle passes.
- Direct replay of the complete test binary passes all 1,685 tests.
- The 13-row reference gate and benchmark path smoke pass against local
  libbrotli 1.2.0-dev.
- The upstream differential passes 7,056 one-shot, 7,056 progressive, 1,401
  fragmentation, 64 high-tree truncation, and seven Large Window cases.
- The four-category real-corpus matrix passes 16/16 one-shot and 16/16
  progressive cases.
- AArch64 compile, `zig build check -j2`, and CLI `--help` smoke pass.

Raw measurements and hashes are retained in
[brotli-middle-tier-nonzero-copy-x86-20261002.json](data/brotli-middle-tier-nonzero-copy-x86-20261002.json).
