# x86-64 Zstd pair terminal-state branch

Date: 2026-10-03. Baseline: `c336646b`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference:
local libzstd 1.6.0-dev (`01b7154f`).

## Scope and safety

The compact split-Huffman executor decodes two consecutive single-literal
rep0 sequences when both packed LL/OF symbols match the established shape.
Only a terminal pair, where exactly two sequences remain, omits the second
FSE transition triplet and validates the end of the reverse bitstream. Every
non-terminal pair performs the three transitions and continues the loop.

A test-only audit of the locked 128 KiB oracle observed 708 first-symbol shape
matches, 663 second-symbol matches, 663 completed pairs, and no terminal pair.
Their complete field groups used only 8--11 bits: 190/344/124/5 pairs at each
width, with no 56-bit-limit rejection. Terminal handling is therefore a cold
edge on this target, while remaining mandatory for general valid streams.

The retained change names the existing `remaining == 2` predicate once, marks
its first edge unlikely, and reuses the same value to omit the transition
updates and call `expectEnd`. Predicate meaning, bit consumption, state update
order, error behavior, output writes, and public APIs are unchanged. The
production wildcopy instance shrinks from `0x25b3` to `0x257e` bytes. The
strict non-wildcopy instance grows from `0x20fb` to `0x223e`, so the complete
split section grows from `0x46ae` to `0x47bc`; direct tests cover that path.

The Huffman-only, raw-FSE, wide-split, and dense-split sections retain their
addresses and are byte-identical between frozen binaries. Their SHA-256 values
are `5ac48bbe...481c8f`, `e92c15be...14db47`,
`7c3f5e55...e6ed06df7`, and `a0a771fa...39b51` respectively.

## Performance

The frozen 524,307-byte `large_json` input has SHA-256
`b0d873df5fbe94a60e8e10a51cde4b08b3370ae4f251357c16adbfc69fd27c95`.
Its 9,905-byte level-1 frame contains five compressed blocks and 7,299
sequences. Every process uses 3,000 iterations, retains the fastest of five
interleaved Vort/libzstd rounds, runs on CPU 2, and alternates frozen
baseline/candidate launch order. Process snapshots were clear before and after
the retained campaigns. The original continuous-monitor shell exited early
when its first `ps -C zig` query found no process, so it is not counted as
additional evidence; the simultaneous libzstd normalization remains the
control for within-campaign host drift.

| API | Candidate / baseline median / geometric | Wins | libzstd-normalized median / geometric | Candidate/libzstd median / geometric |
| --- | ---: | ---: | ---: | ---: |
| one-shot | 1.0140x / 1.0131x | 14/15 | 1.0165x / 1.0158x | 0.9144x / 0.9147x |
| reusable | 1.0115x / 1.0137x | 15/15 | 1.0144x / 1.0102x | 0.8883x / 0.8876x |

This raises the measured target above the preceding 0.9010x one-shot and
0.8772x reusable results, but Vort remains below libzstd on this row. It is a
bounded decoder gain, not a broad Zstd leadership claim.

Clean seven-pair controls use 10,000 iterations per process:

| Control | One-shot median / geometric | Reusable median / geometric | One-shot / reusable normalized geometric |
| --- | ---: | ---: | ---: |
| huffman80k | 1.0006x / 1.0017x | 1.0009x / 0.9952x | 1.0032x / 1.0016x |
| large_text | 1.0056x / 1.0016x | 1.0017x / 0.9998x | 1.0036x / 0.9998x |
| binary_mixed | 1.0005x / 0.9984x | 1.0012x / 0.9988x | 1.0002x / 0.9934x |

All six medians are neutral-positive; raw geometric movement stays within
0.48% of neutral. `large_text` has only one predefined sequence per block and
does not select this executor. Its separate 15-pair, 30,000-iteration campaign
measures 1.0010x median / 1.0004x geometric with 8/15 wins and 1.0017x after
libzstd normalization, resolving the initial short-sample dip as noise.

## Rejected adjacent candidate

Marking the 56-bit pair-field limit itself unlikely inverted the successful
pair edge, but grew the production instance from `0x25b3` to `0x28eb` and the
complete split section from `0x46ae` to `0x4b9e`. Seven `large_json` pairs
regressed to 0.9779x median / 0.9777x geometric with 0/7 wins and 0.9805x after
libzstd normalization. It was removed. The audit also found zero bit-limit
rejections on the target, confirming that moving the entire pair body for an
unobserved rejection was the wrong layout tradeoff.

Exact executable hashes, raw timing pairs, control results, and validation
are retained in
[zstd-pair-terminal-branch-x86-20261003.json](data/zstd-pair-terminal-branch-x86-20261003.json).

## Validation

- All 682 direct ReleaseFast Zstd tests and the full project test suite pass.
- The local libzstd one-shot/reusable 13-row gates, 12-row path smoke, five-row
  decode-profile gate, and three-row profile path smoke pass.
- The compatibility probe passes 276 cases with zero unsupported cases.
- The upstream decodecorpus gate passes nine campaigns and all 9,900 frames,
  covering all 64 sequence-mode combinations and 2,699 block-stream cases.
- Generic x86-64 and AArch64 Linux ReleaseFast compilation,
  `zig build check -j2`, and the CLI help smoke pass.
