# Zstd standard dictionary finalization profile, 2026-11-09

## Measurement

ReleaseFast `vort-zstd-dictionary-trainer-compare` on 40 generated text
samples (32 training, 4 selector, 4 held-out), target dictionary content 352
bytes and `--maxdict=512`:

- system `zstd --train` (1.4.8): 4.8 ms median;
- Vort probe: 200.3 ms median.

The probe also encodes the held-out samples at levels 1/3/9 for its parity
report, so this is not a pure training comparison. The project's own
`run-dictionary-train-bench` isolates the training modes (20 iterations,
7,680 sample bytes):

| Mode | Best ns / 20 iterations | Per training |
| --- | ---: | ---: |
| basic | 45,134,188 | 2.26 ms |
| validated | 225,660,851 | 11.28 ms |
| validated_separate | 1,122,505,029 | 56.13 ms |
| cover_optimized | 25,946,559 | 1.30 ms |
| zstd_validated | 4,184,080,339 | 209.20 ms |

`zstd_validated` is the standard full-dictionary finalization path measured
above; it is the mode with the historical latency gap.

## Profile

`perf` on the 200 ms probe, self costs:

| Symbol | Share |
| --- | ---: |
| `compiler_rt.memset` | 28.05% |
| `huffman.packageMergeCodeLengths` | 17.09% |
| `zstd.sequenceLiteralsPayloadSectionLen` | 12.09% |
| `zstd.smallHuffmanTreeSerializedLen` | 8.94% |
| `compiler_rt.memcpy.memcpyFast` | 6.85% |
| `zstd.findDictionaryMatchIn` | 4.96% |
| `sort.block` | 3.00% |
| `zstd.finalizeSmallHuffmanLiteralPlan` | 2.99% |
| `zstd.buildFseCompressionTable` | 2.96% |

The dominant call chain is the standard finalizer's sample scoring:
`standardDictionaryFromSelectedContentAndSamplesProfiledAlloc` →
`standardDictionaryEncodedSampleByteCounts` → the native frame encoder →
`findDictionaryMatchIn` and repeated literal-section Huffman planning.

## Next optimization

`standardDictionaryFromSelectedContentAndSamplesProfiledAlloc` first collects
the sample sequence counts with the selected dictionary content, then scores
the baseline and candidate repcode dictionaries by fully encoding every sample
**twice** (`standardDictionaryEncodedSampleByteCounts`, `.literal_only`,
`match_search_budget = 0`). The two dictionaries share content and literal
entropy; only sequence entropy and initial repcodes differ. The parse,
dictionary match search and literal-section Huffman planning are therefore
recomputed for both candidates.

The next bounded increment should reuse the collected sequence trace (or one
shared parse) and evaluate both entropy/repcode variants without re-running
the matcher and literal planner, while preserving the exact selected
dictionary bytes and the held-out parity rows. No optimization is claimed by
this profile.

A cheaper variant that reused one `NativeFrameEncoder` across samples was
tested and rejected: text/JSON improved only 1.2-1.4%, binary regressed 2.9%,
all dictionary checksums stayed identical, and the arena retained about
0.25-0.5 MiB more. Encoder construction was not the bottleneck; the shared
parse is required.
