# Downloads Zstd decode corpus

The 2026-09-29 real-file pass uses eight files already present under the local
`~/Downloads` tree. The retained report stores only category labels, sizes, and
SHA-256 digests; it does not copy file contents or disclose the robot-log path.
The inputs cover highly compressible SVG/C/JSON/log text, ELF shared-library and
executable data, and nearly incompressible video/ZIP data.

All inputs were encoded in memory by Homebrew libzstd 1.5.7 at level 1, then
decoded into caller-owned buffers. One-shot rows compare `decodeFrameInto` with
`ZSTD_decompress`; reusable rows compare warmed `NativeFrameDecoder.decodeIntoSlice`
with warmed `ZSTD_decompressDCtx`. Each invocation alternates five samples and
reports each codec's fastest sample. Iterations were selected to decode roughly
0.5 GiB per sample.

The host was busy: WindowServer, Ghostty, Microsoft Defender, Doubao, and other
system services remained active, with load averages commonly between 6 and 12.
The complete matrices below are therefore triage snapshots. Only the frozen,
alternating-order A/B campaigns are used to claim a code-change speedup.

## Initial real-file gap

The initial `4c98febd` matrix exposed a gap hidden by the synthetic 13-case
suite. Vort was close to libzstd on video/ZIP raw-style frames, but compressed
real files ranged from 0.42x to 0.82x of libzstd. The worst case was the large
SVG: 99.33% of decoded bytes came from matches, 96.53% of match bytes were
eligible for 32-byte copies, and only 0.09% came from overlapping matches.

Prepared-stage inspection showed that most blocks selected an all-FSE policy,
but production sampling found many 512--1023-sequence Huffman blocks still
falling through to `readModeSequence`. The existing packed/grouped all-FSE
executor was gated at 1,024 sequences even when split literal decoding could
not take the block.

## Retained routing change

`huffman_all_fse_sequence_min` is now 512 and is owned by
`zstd/sequence/decode_policy.zig`. Both one-shot and reusable decoders use the
same policy, and the prepared sequence-stage classifier mirrors it. The
noinline all-FSE Huffman executor is aligned to 256 bytes so threshold A/B
binaries have a stable entry alignment.

The aligned 1,024/512 binaries differ only in that threshold. Fifteen
alternating large-SVG pairs improved by **1.3063x median / 1.3072x geometric**,
with **15/15 wins** and a 1.2703x minimum. Vort's median reusable ratio moved
from 0.4270x to 0.5573x libzstd. Seven-pair controls were positive or neutral:

| Case | Candidate/baseline median | Geometric mean | Wins |
| --- | ---: | ---: | ---: |
| robot log | 1.0154x | 1.0217x | 6/7 |
| trace JSON | 1.0250x | 1.0175x | 6/7 |
| shared library | 1.0067x | 1.0046x | 5/7 |
| executable | 0.9992x | 1.0022x | 3/7 |
| large C header | 1.0011x | 0.9985x | 4/7 |

Lowering the threshold again from 512 to 256 did not help the SVG: eleven
pairs measured 0.9984x median / 0.9957x geometric with 5/11 wins. That variant
was removed.

## Selective medium-block match wildcopy

After the threshold change, the 512--1023-sequence all-FSE Huffman executor
still sent every match except the fixed 71-byte case through exact copying.
The retained follow-up uses the existing bounded 16/32/64-byte adaptive
wildcopy only when all of these conditions hold:

- the decoder entry has already proved wildcopy output padding;
- the match is at least 16 bytes and its offset is at least 16 bytes;
- the match source is inside the current frame rather than a dictionary;
- the compressed block is at most 4 KiB and has 512--1023 sequences.

The compressed-size condition is a measured proxy for the long-match-heavy
SVG blocks. Applying the branch to every all-FSE block improved the SVG but
regressed trace JSON; limiting it only by sequence count left a roughly 1%
large-header regression. The 4 KiB gate removes the hot-loop branch from those
existing dense paths.

Against the aligned 512-threshold baseline, fifteen alternating SVG pairs
improve by **1.0972x median / 1.0932x geometric**, with **15/15 wins** and a
1.0398x minimum. The reusable Vort/libzstd median moves from 0.5581x to
0.6122x. Together with the preceding threshold change, the two retained steps
improve this workload by roughly 1.433x.

| Case | Candidate/baseline median | Geometric mean | Wins |
| --- | ---: | ---: | ---: |
| robot log | 1.0076x | 1.0109x | 6/7 |
| trace JSON | 1.0237x | 1.0073x | 4/7 |
| shared library | 0.9964x | 1.0002x | 3/7 |
| executable | 1.0002x | 0.9992x | 4/7 |
| large C header | 1.0073x | 1.0023x | 4/7 |

A 32-byte minimum was also rejected: it lost 1.65% median on the SVG versus
the retained 16-byte minimum and did not improve JSON.

## Large-frame reusable cache bypass

The decode profiler now identifies its API mode and reports sequence-table and
Huffman-tree cache hits from only the timed interval. After one warmup decode,
all six compressed Downloads files reported zero hits for both caches on the
next complete decode. Their 229--1,377 compressed blocks cycle through more
descriptions than the four-slot workspace can retain. By contrast, ten timed
decodes of the small `numbered_json` case report ten sequence-table and ten
Huffman-tree hits.

Known-size frames above 512 KiB now bypass the small reusable caches. Unknown
and smaller frames retain them, and the workspace decision is hoisted from the
per-block loop to the first compressed block. Fifteen alternating SVG pairs
improve by **1.0139x median / 1.0160x geometric**, with **13/15 wins**. The
reusable Vort/libzstd median moves from 0.6126x to 0.6192x.

| Case | Candidate/baseline median | Geometric mean | Wins |
| --- | ---: | ---: | ---: |
| robot log | 1.0070x | 1.0052x | 8/15 |
| trace JSON | 1.0009x | 1.0019x | 5/7 |
| shared library | 0.9997x | 1.0005x | 3/7 |
| executable | 0.9998x | 0.9923x | 3/7 |
| large C header | 1.0052x | 1.0062x | 6/7 |

The sub-percent mixed controls remain inside the observed loaded-host jitter;
none shows a consistent directional loss. A generated >512 KiB compressed
frame verifies two correct decodes without allocating the cache workspace.

## FSE table distribution and rejected generalization

The decode profiler now reports sequence-block counts, all four table modes,
low-probability usage, and accuracy-log histograms. Its extra normalized-count
pass is diagnostic-only; production decoding does not retain or update the new
bookkeeping. A fresh profile of the six compressed files produced:

| Case | Explicit FSE tables | No-low tables | No-low share | New-tree / treeless blocks | Accuracy-log distribution (5/6/7/8/9) |
| --- | ---: | ---: | ---: | ---: | --- |
| large SVG | 4,130 | 4,130 | 100.00% | 846 / 531 | 66 / 117 / 2,573 / 1,374 / 0 |
| robot log | 2,652 | 2,489 | 93.85% | 840 / 44 | 2 / 30 / 130 / 2,378 / 112 |
| trace JSON | 741 | 149 | 20.11% | 241 / 6 | 0 / 2 / 31 / 270 / 438 |
| shared library | 2,260 | 841 | 37.21% | 715 / 53 | 1 / 77 / 315 / 837 / 1,030 |
| executable | 1,185 | 316 | 26.67% | 394 / 0 | 0 / 8 / 46 / 513 / 618 |
| large C header | 678 | 218 | 32.15% | 198 / 31 | 0 / 2 / 1 / 307 / 368 |

The executable also has four raw-literal compressed blocks and the shared
library has one; none of these files uses an RLE literal section.

The profile now classifies every sequence-bearing block into mutually
exclusive split-decoder paths and weights them by decoded output, rather than
using block counts alone. `Other` combines non-Huffman literals, one-stream
Huffman sections, and incomplete lookup tables. No incomplete lookup table was
observed in these six files.

| Case | all-FSE split blocks / output | Generic split blocks / output | Below policy blocks / output | Other blocks / output |
| --- | ---: | ---: | ---: | ---: |
| large SVG | 461 / 33.62% | 0 / 0% | 916 / 66.38% | 0 / 0% |
| robot log | 831 / 97.69% | 1 / 0.06% | 52 / 2.25% | 0 / 0% |
| trace JSON | 236 / 96.79% | 0 / 0% | 11 / 3.21% | 0 / 0% |
| shared library | 725 / 96.84% | 28 / 2.27% | 8 / 0.85% | 1 / 0.04% |
| executable | 378 / 98.03% | 14 / 1.20% | 0 / 0% | 4 / 0.77% |
| large C header | 219 / 96.03% | 7 / 3.07% | 1 / 0.03% | 2 / 0.88% |

This rules out incomplete Huffman tables as the current broad gap. It also
shows that the existing split path already covers at least 96% of decoded
sequence-block output for every compressed input except the SVG. The SVG's
512--1023-sequence blocks are the focused threshold experiment; widening split
routing globally is not justified by the other five rows.

A 1 kHz pure-Vort SVG sample attributes 45.42% of samples to the interleaved
all-FSE/Huffman executor, 24.57% to the existing split executor, 6.80% to the
two FSE-table builders, and 2.26% to Huffman-tree construction. Lowering the
split threshold was nevertheless counterproductive under matched 256-byte
helper alignment: 512, 768, and 896 sequences measured 0.9642x, 0.9629x, and
0.9556x medians over seven alternating pairs, all with 0/7 wins. Bulk literal
staging does not amortize on these sparse-literal medium blocks.

Several interleaved-loop changes were also rejected. Five fixed AArch64 NOPs
that moved the loop head to a 64-byte boundary were neutral at 1.0027x median /
1.0000x geometric with 4/7 wins. With that loop placement fixed, bypassing the
generic direct-offset resolver measured only 0.9882x / 0.9976x with 2/7 wins.
Keeping only the sequence reader local measured 0.9978x / 0.9936x with 2/7
wins. Borrowing the 5,240-byte Huffman state through a `noalias` pointer was
also neutral at 1.0081x / 1.0037x with 4/7 wins, while less constrained pointer
forms and a two-literal lookup increased register/code pressure and fell into a
roughly 0.85--0.86x code-generation regime. A persistent Huffman reservoir
prototype was removed before timing because the full SVG round trip exposed a
four-stream progress mismatch that the fixed fixture did not cover.

The distribution suggested extending the specialized no-low builder beyond
256 states, but the real-file A/B results rejected that direction. A 128-state
route measured 0.9951x median / 0.9891x geometric on the SVG with 5/21 wins;
the 512-state route measured 0.9899x median on the header and 0.9977x on the
executable. Recording the no-low count while parsing and using it to remove the
existing 256-state verification scan was also neutral on the robot log:
**0.9977x median / 1.0002x geometric, 10/21 wins**. All three production-path
experiments were removed.

## Sequence-table normalized-count reservoir

Production sampling attributed about 11% of the SVG decode samples to sequence
mode parsing and FSE table construction. The byte-aligned LL/OF/ML normalized-
count parser now keeps a 64-bit little-endian reservoir and refills it only as
needed, instead of reconstructing neighboring bytes for every 1--9-bit field.
It derives the final byte count from loaded bytes minus remaining reservoir
bits, so the hot read no longer increments a separate consumed-bit counter.
The older bit reader remains the independent differential oracle and continues
to serve callers whose input is not at a byte boundary.

Against the frozen `b7ca21c9` binary, fifteen alternating pairs on all six
compressed files are positive at the median. Ratios below are candidate over
baseline:

| Case | One-shot median / geometric | Wins | Reusable median / geometric | Wins |
| --- | ---: | ---: | ---: | ---: |
| large SVG | 1.0176x / 1.0189x | 15/15 | 1.0167x / 1.0177x | 14/15 |
| robot log | 1.0155x / 1.0143x | 13/15 | 1.0118x / 1.0130x | 14/15 |
| trace JSON | 1.0111x / 1.0117x | 14/15 | 1.0114x / 1.0158x | 15/15 |
| shared library | 1.0044x / 1.0029x | 11/15 | 1.0049x / 1.0016x | 10/15 |
| executable | 1.0103x / 1.0093x | 13/15 | 1.0075x / 1.0059x | 13/15 |
| large C header | 1.0147x / 1.0151x | 14/15 | 1.0081x / 1.0066x | 12/15 |

The geometric mean across row geometric means is 1.0120x for one-shot and
1.0101x for reusable decoding. A separate matched-layout experiment aligned
the four-stream Huffman and split-sequence helpers to 256 bytes in both
binaries; the parser alone remained positive at 1.0205x/1.0235x on SVG,
1.0190x/1.0203x on the log, and 1.0050x/1.0022x on the shared library. Those
temporary alignment changes were removed from production.

Five adjacent follow-ups were measured and removed. Porting libzstd's generic
X1/X2 cost selector produced only a 1.0009x reusable row-geometric mean and
moved trace JSON, the executable, and the header slightly backward by geometric
mean. Making the 64/32/16-byte match copier depend on logical match length
reduced the six-row reusable geometric mean to 0.9940x, including 0/7 wins on
the shared library and header. Finally, batching absent-symbol writes in the
new parser reduced SVG and log to 0.9928x and 0.9951x medians over 15 matched-
layout pairs. Keeping the normalized-count width as incremental remaining/
threshold state also regressed SVG and log to 0.9939x and 0.9936x medians.
A libzstd-style `ctz` scan over consecutive absent-symbol repeat pairs was
correct under both random differential oracles but measured only 1.0012x
median / 1.0022x geometric with 9/15 SVG wins; it was removed as noise. The
original loops remain.

## Current loaded-host snapshot

The six compressed rows below use medians from the normalized-count-reservoir
campaign. Video and ZIP retain the preceding raw-path snapshot because they do
not contain explicit FSE tables. Ratios are Vort/libzstd; the full input hashes,
exact byte counts, binary hashes, and A/B observations are in the
[JSON record](data/zstd-downloads-m1-20260929.json).

| Case | Input MiB | Encoded % | One-shot | Reusable | Vort reusable MiB/s | libzstd DCtx MiB/s |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| large SVG | 171.3 | 1.39 | 0.6373x | 0.6305x | 6,084.3 | 9,661.2 |
| robot log | 105.0 | 6.69 | 0.7521x | 0.7400x | 3,353.7 | 4,547.6 |
| trace JSON | 30.2 | 6.10 | 0.8078x | 0.8002x | 2,871.7 | 3,573.4 |
| shared library | 77.7 | 40.81 | 0.8242x | 0.8199x | 1,025.3 | 1,251.4 |
| executable | 37.1 | 40.01 | 0.8199x | 0.8156x | 988.1 | 1,210.8 |
| video | 163.8 | 99.99 | 0.9656x | 1.0210x | 40,262.3 | 39,435.2 |
| ZIP archive | 153.7 | 99.91 | 0.9987x | 0.9415x | 32,418.3 | 34,433.2 |
| large C header | 28.5 | 4.40 | 0.7655x | 0.7593x | 2,694.8 | 3,555.3 |

The ZIP reusable snapshot is an outlier under the recorded host load. Its raw
fast path returns before the cache policy and is byte-for-byte unchanged, so
the drop is not attributed to this change.

This is meaningful progress, not leadership. Real compressed multi-block files
remain 18--37% behind libzstd after the retained changes. The next profile should
separate split-decoder rejection reasons, incomplete-Huffman literal decoding,
FSE table rebuilds, and the remaining exact-copy traffic rather than broadening
wildcopy again.

## Validation

- 672/672 direct Zstd tests pass in ReleaseFast.
- The one-shot and reusable 13-row reference gates pass against libzstd 1.5.7.
- The decode-profile gate and three-row/two-API path smoke pass.
- The 276-case compatibility matrix passes with zero unsupported cases.
- All nine upstream decodecorpus campaigns pass: 9,900 frames, all 64 sequence
  mode combinations, and real reusable table hits.

The broad `zig build check -Doptimize=ReleaseFast -j1` was stopped after more
than 25 minutes while its monolithic all-codec tools were still consuming CPU
in LLVM code generation. This is not reported as a pass. The direct Zstd suite,
x86-64 cross-compilation, and codec-specific gates above are the authoritative
validation for this change.
