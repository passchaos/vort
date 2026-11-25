# Zstd dense decoder register-pressure screen, 2026-11-23

Five variants of the dense split-Huffman sequence executor were measured
against committed `f3e80aa7`. All five were rejected. The screen records the
register/branch-predictability wall the executor now sits against, so the next
attempt starts from the profile evidence instead of repeating these shapes.

## Profile of the committed executor

`perf record` on `vort-zstd-reference-bench` (dickens.1m, level 9, 1500
iterations, saved binary `zb-base`) attributes the whole process as:

| symbol | share |
| --- | ---: |
| `tryDecodeAllFseSplitDenseHuffmanSequencesNative` | 58.63% |
| `tryDecodeAllFseSplitWideHuffmanSequences` | 7.26% |
| libzstd 1.4.8 decode | ~26% |
| `decodeFourStreamHuffmanReservoirNative` | 2.13% |
| `sequence.fse_builder.buildMapped` | 1.50% |

Inside the dense executor the single hottest instruction is the 16-byte
match-source load of `appendForwardWildcopy16Once` at **12.38%** of total
samples; its store is 1.73%. The rest of the ~100-instruction loop spreads
roughly evenly at ~1.5% per instruction, including a store/reload pair for the
loop counter (`mov %rbx,-0xc8(%rbp)` / `mov -0xc8(%rbp),%rbx`) and repeated
`reader.remaining_bits` and `reader.bytes.ptr` reloads. `perf stat` reports
0.57 `ld_blocks.store_forward` blocks and 0.76 split loads per sequence, so the
match load mostly cannot forward from the previous wildcopy stores and drains
the store buffer.

## Screen 1: repeated offsets in registers (full campaign)

`tryDecodeAllFseSplitDenseHuffmanSequencesImpl` kept the three repeat offsets
in locals and resolved them inline, removing the `state` pointer reload and the
16-byte load/store pair that `updateRepeatedOffsets` emits per sequence.

Method: five alternating before/after pairs per row, 24 rows (twelve 64 KiB
and 1 MiB level-9 prefixes), 300 iterations, libzstd 1.4.8 reference in every
row; per-row median of the candidate/baseline Vort/reference ratio, geometric
mean, row-resampled bootstrap (10,000 resamples, seed 0x5A17).

Result: geometric mean **0.9967x**, bootstrap 95% CI **[0.9935, 1.0001]**;
weakest rows `mozilla.64k` 0.9823, `webster.64k` 0.9829, `reymont.64k`
0.9836, `xml.64k` 0.9869. Three controls fall below the 0.98 floor and the CI
does not exclude parity, so the variant is rejected. The three extra
loop-carried values displaced more valuable state; the compiler moved the
offsets to stack slots and the vector store became three scalar stores.

## Screen 2: 8-byte short-match copy

For `match_len <= 8` the fast path copied one 64-bit word instead of one
16-byte vector, on the theory that an 8-byte load can forward from a single
pending 16-byte wildcopy store. Codegen was the expected `mov`/`mov` pair.

Quick alternating screen (dickens, level 9, 300 iterations, four runs each
size, base/variant interleaved; the tool's `vort_over_reference` column is
reference/Vort, so lower is slower):

| size | base | variant |
| --- | ---: | ---: |
| dickens.64k | 0.7939, 0.7983 | 0.6969, 0.7070 |
| dickens.1m | 0.7518, 0.7607 | 0.6466, 0.6480 |

Rejected: the added `match_len <= 8` branch is data-dependent and
unpredictable, costing about 13% end to end — far more than the forwarding win
could return.

## Screen 3: bit-window reservoir

The dense loop cached the next 64 stream bits in a register (`Reservoir` in
`src/zstd/sequence/field_group.zig`) and reloaded only when the next sequence
did not fit, removing the per-sequence eight-byte stream load and its address
computation.

Quick alternating screen, same method:

| size | base | variant |
| --- | ---: | ---: |
| dickens.64k | 0.7935, 0.7837 | 0.6738, 0.6820 |
| dickens.1m | 0.7529, 0.7528 | 0.6997, 0.6926 |

Rejected: the refill test is taken every two to three sequences with no
predictable pattern, and the window plus valid count added two loop-carried
registers. The branch misprediction and extra spills cost 7--14%.

## Screen 4: batched field/copy split

The executor decoded one sequence per pass. The candidate decoded up to eight
sequences' fallible field work into a pending array (validating every copy
precondition in bitstream order against projected cursors) and then ran an
infallible copy pass over the batch, on the theory that separating the FSE
state from the output cursors would relieve the spill pressure.

Quick alternating screen, same method:

| size | base | variant |
| --- | ---: | ---: |
| dickens.64k | 0.7891, 0.7844 | 0.7017, 0.6969 |
| dickens.1m | 0.7582, 0.7543 | 0.7141, 0.7046 |

Rejected: the two loops remove the out-of-order overlap between one sequence's
copy and the next sequence's FSE table loads, which the single-pass loop gets
for free. The register relief does not repay the lost instruction-level
parallelism; the batch is 6--12% slower.

## Screen 5: dense executor for every four-stream literal section

The dispatcher sends literal sections above 16 KiB to the wide executor
(capacity 128 KiB), which carries the pair fast path and the 68--71-byte match
kernels. The candidate raised the dense executor's staged-literal capacity to
the 128 KiB Zstd block bound and routed every four-stream section to it.

Quick alternating screen, same method:

| size | base | variant |
| --- | ---: | ---: |
| dickens.64k | 0.8000, 0.7719 | 0.7936, 0.7936 |
| dickens.1m | 0.7657, 0.7585 | 0.7525, 0.7501 |
| mozilla.1m | 0.7495, 0.7416 | 0.7403, 0.7444 |
| x-ray.1m | 0.8460, 0.8504 | 0.7957, 0.7999 |

Rejected: text gains about 1.4% on the 1 MiB row, but binary `x-ray` loses
about 6%, so the wide executor's long-match kernels are essential for that
shape. A size-only threshold cannot replace the existing dispatch; any future
attempt needs a block-shape classifier and a full paired campaign, and the
realistic ceiling is about one percent.

## Conclusion

The executor is bounded by register allocation and out-of-order overlap, not
by any single arithmetic step. Every variant that adds loop-carried state or a
data-dependent branch lost 7--14%, the batched split lost the copy/FSE overlap,
and replacing the wide executor lost binary-data kernels; the adopted
`ShiftingGroup` change won 1.86% precisely because it removed state without
adding a branch. Screen 3 also repeated a previously rejected reservoir design
(recorded in `zstd-wide-split-capacity.md`), so future work should search that
note first. The next serious attempt must reduce live values inside the
single-pass loop or find a classifier-backed executor choice, not add a cache,
a tier, or a second pass. The 12.38% match-source load is the largest single
target but needs a copy shape that avoids a new unpredictable branch.

## Raw data

`r{1..5}-<case>-<size>-{B,V}.csv` for the 24 rows and five rounds of screen 1
(schema of `run-zstd-reference-bench`); `analysis.txt` is the exact analyzer
output used above. Screens 2--5 were quick alternating runs and were not
expanded after the negative signal; their exact observed ratios are recorded
in the tables above.
