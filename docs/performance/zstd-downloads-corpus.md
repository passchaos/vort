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

## Current loaded-host snapshot

These rows use the retained 512 threshold. Ratios are Vort/libzstd; the full
input hashes, exact byte counts, binary hashes, and A/B observations are in the
[JSON record](data/zstd-downloads-m1-20260929.json).

| Case | Input MiB | Encoded % | One-shot | Reusable | Vort reusable MiB/s | libzstd DCtx MiB/s |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| large SVG | 171.3 | 1.39 | 0.5681x | 0.5517x | 5,330.0 | 9,661.1 |
| robot log | 105.0 | 6.69 | 0.7391x | 0.7257x | 3,296.5 | 4,542.6 |
| trace JSON | 30.2 | 6.10 | 0.7926x | 0.7979x | 2,829.5 | 3,546.2 |
| shared library | 77.7 | 40.81 | 0.8174x | 0.8182x | 1,030.9 | 1,259.9 |
| executable | 37.1 | 40.01 | 0.8126x | 0.8089x | 970.2 | 1,199.3 |
| video | 163.8 | 99.99 | 0.9950x | 0.9835x | 38,860.5 | 39,511.2 |
| ZIP archive | 153.7 | 99.91 | 0.9847x | 1.0012x | 34,432.8 | 34,389.9 |
| large C header | 28.5 | 4.40 | 0.7578x | 0.7325x | 2,519.4 | 3,439.3 |

This is meaningful progress, not leadership. Real compressed multi-block files
remain 18--45% behind libzstd after the change. Production sampling points next
to the generic/incomplete-Huffman fallback, literal decode, FSE table rebuilds,
and match-copy traffic. Those paths should be measured separately before
expanding the 512 threshold or adding more copy special cases.

## Validation

- 670/670 direct Zstd tests pass in ReleaseFast.
- The one-shot and reusable 13-row reference gates pass against libzstd 1.5.7.
- The 276-case compatibility matrix passes with zero unsupported cases.
- All nine upstream decodecorpus campaigns pass: 9,900 frames, all 64 sequence
  mode combinations, and real reusable table hits.

The broad `zig build check -Doptimize=ReleaseFast -j1` was not completed: its
dependency on the monolithic all-codec `vort-tests` root remained in LLVM code
generation for tens of minutes. This is not reported as a pass. The direct
Zstd suite and codec-specific gates above are the authoritative validation for
this change.
