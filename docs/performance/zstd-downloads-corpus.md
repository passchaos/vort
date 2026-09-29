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

## Current loaded-host snapshot

These rows use the retained 512 threshold and selective medium-block wildcopy.
Ratios are Vort/libzstd; the full input hashes, exact byte counts, binary hashes,
and A/B observations are in the [JSON record](data/zstd-downloads-m1-20260929.json).

| Case | Input MiB | Encoded % | One-shot | Reusable | Vort reusable MiB/s | libzstd DCtx MiB/s |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| large SVG | 171.3 | 1.39 | 0.6279x | 0.6113x | 5,973.5 | 9,771.5 |
| robot log | 105.0 | 6.69 | 0.7419x | 0.7243x | 3,325.6 | 4,591.6 |
| trace JSON | 30.2 | 6.10 | 0.7983x | 0.7918x | 2,750.7 | 3,473.8 |
| shared library | 77.7 | 40.81 | 0.8213x | 0.8266x | 1,040.9 | 1,259.3 |
| executable | 37.1 | 40.01 | 0.8127x | 0.8136x | 987.5 | 1,213.8 |
| video | 163.8 | 99.99 | 0.9363x | 1.0269x | 41,522.4 | 40,435.9 |
| ZIP archive | 153.7 | 99.91 | 0.9687x | 1.0107x | 34,823.0 | 34,454.7 |
| large C header | 28.5 | 4.40 | 0.7607x | 0.7456x | 2,640.1 | 3,540.7 |

This is meaningful progress, not leadership. Real compressed multi-block files
remain 17--39% behind libzstd after both changes. The next profile should
separate split-decoder rejection reasons, incomplete-Huffman literal decoding,
FSE table rebuilds, and the remaining exact-copy traffic rather than broadening
wildcopy again.

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
