# Zstd dense decoder register-pressure screen, 2026-11-23

Three variants of the dense split-Huffman sequence executor were measured
against committed `f3e80aa7`. All three were rejected. The screen records the
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

## Conclusion

The executor is bounded by register allocation, not by any single arithmetic
step. Every variant that adds loop-carried state or a data-dependent branch
lost 7--14%, while the adopted `ShiftingGroup` change won 1.86% precisely
because it removed state. The next serious attempt must reduce live values or
process several sequences per iteration (libzstd-style unrolling) rather than
add a cache, a tier, or an extra selector. The 12.38% match-source load is the
largest single target but needs a copy shape that avoids a new unpredictable
branch.

## Raw data

`r{1..5}-<case>-<size>-{B,V}.csv` for the 24 rows and five rounds of screen 1
(schema of `run-zstd-reference-bench`); `analysis.txt` is the exact analyzer
output used above. Screens 2 and 3 were quick alternating runs and were not
expanded after the large negative signal.
