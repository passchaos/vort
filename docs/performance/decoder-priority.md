# Deflate, Zstd and Brotli decoder priority

The user prioritized decompression functionality and performance on
2026-10-31. Encoder experiments remain frozen and unmerged. The active objective
still covers all three codecs, with exact output, bounded memory, dictionaries,
streaming progress, malformed input and platform behavior required alongside
throughput.

## Current reference evidence

The corpus contains all twelve Silesia files at 64 KiB, 1 MiB and their actual
full lengths: 36 inputs and 216 externally produced frames. Raw Deflate uses
zlib 1.2.11 levels 6/9, Zstd uses pinned 1.6.0 levels 3/19, and Brotli uses pinned
1.2.0 qualities 6/11, generic mode and window22. Every reference compressor
produces identical bytes twice. Native reference decoders verify complete
contents and 64-byte input/output guards; libdeflate independently validates
all 72 raw streams and their exact consumed lengths.

Direct output benchmarks call Vort's public raw Deflate, Zstd frame and Brotli
stream APIs on those same frames. Reference APIs are libdeflate 1.26 raw
decompression, `ZSTD_decompress`, and `BrotliDecoderDecompress`. Libdeflate's
decompressor context is created outside timing; the other reference one-shot
API context work remains inside its call. Output buffers are allocated before
timing. Loading, startup decode, complete output checks, hashing and freeing are
outside timing. The ordinary decoder call is timed on logical CPU2 of an
Intel i7-10700K, Zig 0.16.0 ReleaseFast, GNU target with
`skylake+pku+sgx`. Compilers, separate probes and archive compression do not
overlap ordinary timing.

The first 576-process reference epoch records these geometric means of
per-input median time ratios. Lower is faster.

| Codec / producer quality | 64 KiB Vort / reference | 1 MiB Vort / reference |
| --- | ---: | ---: |
| Raw Deflate 6 | 2.030779 | 1.842260 |
| Raw Deflate 9 | 2.042403 | 1.800615 |
| Zstd 3 | 1.764190 | 1.794967 |
| Zstd 19 | 1.900484 | 1.820023 |
| Brotli 6 | 1.983126 | 1.165888 |
| Brotli 11 | 1.940589 | 1.335787 |

A separate candidate epoch has 960 prefix processes and 480 full-file
processes. Independent reducers reparse raw stdout, recompute medians and
summaries, verify input/wire/binary/library hashes and check serial intervals.
Full-file baseline/reference time ratios in that epoch are 1.837596/1.834628
for raw Deflate 6/9, 1.723892/1.806760 for Zstd 3/19, and
1.492942/1.528402 for Brotli 6/11. Prefixes and full files remain separate
scopes; ratios from different epochs are not multiplied.

## Adopted Deflate changes

The regular 11-bit semantic decoder now handles non-overlapping matches
without repeatedly dispatching through `copyMatchAt`. After the same distance
and destination checks, lengths 3–32 use exact head/tail fixed-width copies;
larger copies retain `memcpy`. All accesses stay within the actual match.
Distance one, overlapping matches, the separate non-overlap specialization,
bit reservoir, tables, refill and tail behavior retain their existing paths.
The kernel adds no allocation.

The prototype's candidate/baseline time ratios are:

| Producer quality | 64 KiB | 1 MiB | Actual full files |
| --- | ---: | ---: | ---: |
| Raw Deflate 6 | 0.903485 | 0.940292 | 0.938045 |
| Raw Deflate 9 | 0.897773 | 0.942625 | 0.934120 |

The worst prefix ratio is 1.009674 and the worst full-file ratio is 1.000543.
These are prototype point estimates. Final-source measurement and verification
records remain separate in the evidence package.

Cross-platform validation also uncovered a real defect: four semantic
secondary-table accesses narrowed a shifted 64-bit reservoir to `usize`
before masking. Valid OSDB input could panic in Debug on 32-bit targets.
The accesses now mask the bounded suffix in 64-bit space before narrowing.
A permanent guarded OSDB frame and high-reservoir tests reproduce the issue.

Independent scalar copy tests cover all lengths 3–258, offsets and adjacent
regions. Frozen decoder comparisons verify contents, full backing buffers,
reader checkpoints and errors for truncations, mutations, dictionaries,
aliases, output N/N−1 and allocation failures. The prototype's six actual
native/x86/WASI Debug/ReleaseFast suites pass. Post-adoption live Debug and
ReleaseFast each pass 581 complete Deflate tests, and the current public
decoders pass all 216 reference frames with full content and guards. Actual
live WASI Debug/ReleaseFast each pass eight tests, including the three new
meaningful copy/index/reference regressions.

## Final-source verification and measurements

The adopted source is frozen separately from the prototype. It uses the same
three-codec driver, build options and objects as the baseline. The final source
passes 581 Deflate tests in both native Debug and ReleaseFast, the x86 targeted
regressions, actual WASI Debug/ReleaseFast (eight tests each), and 212/212
native/WASI build checks. All 216 reference frames pass current-source complete
decoding, content hashes and caller-buffer guards.

The final 864-process epoch runs four alternating serial sweeps over all 72
raw Deflate frames, retaining the producer level and scope per row. Every
timed output matches its expected content. Its raw stdout, medians, wire/input
and binary/library hashes and process intervals are independently reduced.

| Producer / scope | Final / baseline time | Final / libdeflate time |
| --- | ---: | ---: |
| 6 / 64k | 0.901135 | 1.815757 |
| 6 / 1m | 0.944687 | 1.693295 |
| 6 / full | 0.935576 | 1.716425 |
| 9 / 64k | 0.896619 | 1.821566 |
| 9 / 1m | 0.946576 | 1.688412 |
| 9 / full | 0.932455 | 1.712236 |

Final-source full-file time falls 6.4–6.8%, while still taking about 1.71x
libdeflate time. This current-source epoch is the basis of the adopted
performance claim; it is not multiplied with prototype ratios. The exact copy
and lookup-mask kernels add no heap allocation. Decoder requested-heap/RSS
ranking against the C references was not measured in this turn.

## Retained experiments and next work

The subsequent [dense Zstd transition study](zstd-dense-transitions.md) targets
the specialized sequence path with broad reference-frame coverage. Its scalar
and per-sequence oracles preserve fields, state and error progress. A clean
paired prototype epoch records 4.6–5.3% less full-file time, and the change is
adopted independently of the rejected metadata, spreading and Brotli chunk
variants. Final-source checks and measurements are kept with that study.

The later [short-match and header ownership increment](brotli-header-ownership.md)
uses one proven 16-byte copy for dense short Zstd matches and parses Brotli
progressive headers into owned state. Its final-source two-sweep epochs cover
1,296 direct-output and 288 owned-streaming processes: full-file Zstd time
falls 7.4–8.2% and Brotli streaming time falls 4.0–4.2%. The same direct-output
epoch still measures full-file reference time ratios around 1.71–1.72 for
Deflate, 1.53–1.56 for Zstd and 1.52–1.55 for Brotli. Individual regressions,
two-sweep variation and reference streaming gaps remain explicit in that
report; ratios from different epochs are not multiplied.

The 9-bit Deflate reservoir prototype is not adopted: all 48 prefix raw streams
contain 482 dynamic 11-bit blocks and zero 9-bit blocks. Its narrower functional
evidence remains partial. OSDB sampling instead attributes about 69% to the
regular semantic loop and another 22% to copy-related work, motivating the
adopted exact short-copy increment.

Zstd's persistent generic sequence reservoir reduces repeated field loads,
but only 5/48 prefix frames use that path. Its full-file time ratios are
1.000863/0.993683 for producer levels 3/19, so it remains isolated. The measured
specialized FSE/Huffman sequence path, table construction and clearing are the
next priorities; broader dictionary/reusable/incremental evidence remains
required.

Brotli's direct packed literal-table setup saves 228 temporary expansions in
4/48 prefix frames. Full-file time ratios are 0.995337/1.002233 for qualities
6/11, without a stable overall gain. A separate fused10 command trial has
29/48 prefix frames with hits but regresses: full-file ratios are
1.013672/1.010170. Both remain isolated. Mozilla q11 sampling shows the external
literal payload loop dominates, so subsequent work must target its actual
dependencies rather than rare table setup or wider roots. A Debug resource
test has a default-stack failure shared by baseline and candidates before the
optimized path; both pass with a 64 MiB stack. That limitation is recorded and
remains independent platform work.

None of these results establishes overall decoder leadership. Allocating,
reusable, dictionary and incremental performance, hostile-input/resource
behavior, RSS and broader CPUs require their own current-source comparisons.

## Reproduction

The [evidence package](data/decoder-priority-20261101/README.md) retains actual
inputs and frames, source overlays, exact commands, raw stdout, guards,
reference pins, process exits and independent audits. The full corpus is
archived separately from the smaller source/test evidence. Existing unrelated
Bzip2 working-tree changes prevent a commit or push under repository rules.
