# Zstd HQ exact sequence pricing inlined at edge calls

`EntropyModel.sequencePrice` is now explicitly inlined. Its complete body,
LL/ML/OF validation order, long-offset penalty, checked caller cost addition
and error behavior remain unchanged. Each admitted edge still computes its
original price and records the original counters. No prepared prices, new
table, cache or allocation are added. The implementation is saved in
`dcd748f7`; its standalone price test root exposes the existing independent
symbol, model and offset-penalty contracts for portable execution.

The [current ordinary sampling](zstd-prepared-row-tag-screen.md) shows that
sequence pricing and edge extension have become larger shares after the row
tag index reduced duplicate scanning. Pricing contributes 15.60% of sampled
user periods on Mozilla 4 KiB btultra2 and 5.63% on Dickens btopt, with a further
4.11%/1.65% in call setup and return instructions. The profiles are measured
with diagnostics disabled and global raw-period denominators.

## Ordinary encoder evidence

The [evidence package](data/zstd-sequence-price-inline-20261029/) compares
the current `9433c9bb` row-tag baseline with a candidate differing only by the
`inline` keyword. Both binaries are freshly compiled with Zig 0.16.0 LLVM
ReleaseFast/Skylake, using the same ordinary allocating runner. CPU-2 two-round
AB/BA timings use real Silesia 4 KiB prefixes, window log 15, block maximum
32768 and checksums. Input setup, caller output release, native decode,
hashing and a subsequent independent profiled encode are outside the timer.

| Input | btopt candidate/baseline time | btultra2 candidate/baseline time |
| --- | ---: | ---: |
| Dickens 4 KiB | 0.9643 | 0.9590 |
| Mozilla 4 KiB | 0.9747 | 0.9401 |
| MR 4 KiB | 0.9986 | 0.9738 |

Each cell is median candidate time divided by median baseline time. Five
configurations improve in both rounds by roughly 2.5%-6%; MR btopt has mixed
paired ratios (0.9832/1.0138) and is treated as near parity. All 24 ordinary
encodes, 48 native decodes and complete wire/profile comparisons pass.
Independent libzstd 1.6.0 decodes all 24 archived wire artifacts exactly.

LLVM removes the standalone pricing call and folds the computation into
`extend`. Baseline extension is 549 bytes plus a 420-byte pricing function;
the candidate extension is 962 bytes. Insertion and unindexed fallback calls
remain. This is a code-shape change, not a reduction in price admissions.

A separate single balanced CPU-2 round uses Mozilla 16 KiB and the previously
trained 4096-byte standard dictionary with its 8 KiB reference input. The
unchanged large-input runner requests window log 17 and block maximum 16384;
input/dictionary preparation precedes the ordinary timer.

| Input | btopt candidate/baseline time | btultra2 candidate/baseline time |
| --- | ---: | ---: |
| Mozilla 16 KiB | 0.9687 | 0.9614 |
| Trained dictionary input 8 KiB | 0.9982 | 0.9593 |

Both versions preserve complete wires, all profiles and requested heap peaks
in eight ordinary encodes and sixteen native decodes. The dictionary retains
78/87 actual references; dictionary btopt is near parity. The one-round epoch
remains separate from the small-prefix matrix.

These limited CPU-2 observations include background activity and do not
establish statistical significance, general throughput or competitor rank.
Exact clocks, source/binary/input identities and command lines remain frozen.
The ten-format functionality/performance objective remains active; wider
ratio/speed/memory coverage and edge/state materialization are next targets.

The retained price root passes 5/5 in native Debug/ReleaseFast, actual x86
Debug and executed wasm32-wasi. It checks independent format-symbol boundaries,
effective integer/fractional costs and exact long-offset penalties. Existing
HQ/search/incremental tests pass 385/385, and versioned bidirectional
references pass 52 HQ plus 41 expanded-search groups. The broader build check
exits zero. The final source, WASI image and terminal records are retained
separately from the measured prototype; the function body remains identical.
