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

## Current loaded-host snapshot

These rows additionally use the large-frame cache bypass. Ratios are
Vort/libzstd; the full input hashes, exact byte counts, binary hashes, and A/B
observations are in the [JSON record](data/zstd-downloads-m1-20260929.json).

| Case | Input MiB | Encoded % | One-shot | Reusable | Vort reusable MiB/s | libzstd DCtx MiB/s |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| large SVG | 171.3 | 1.39 | 0.6258x | 0.6228x | 5,893.4 | 9,462.0 |
| robot log | 105.0 | 6.69 | 0.7380x | 0.7326x | 3,269.4 | 4,462.8 |
| trace JSON | 30.2 | 6.10 | 0.8055x | 0.7876x | 2,714.4 | 3,446.5 |
| shared library | 77.7 | 40.81 | 0.8220x | 0.8180x | 1,040.1 | 1,271.4 |
| executable | 37.1 | 40.01 | 0.8155x | 0.8100x | 971.5 | 1,199.4 |
| video | 163.8 | 99.99 | 0.9656x | 1.0210x | 40,262.3 | 39,435.2 |
| ZIP archive | 153.7 | 99.91 | 0.9987x | 0.9415x | 32,418.3 | 34,433.2 |
| large C header | 28.5 | 4.40 | 0.7660x | 0.7488x | 2,627.8 | 3,509.6 |

The ZIP reusable snapshot is an outlier under the recorded host load. Its raw
fast path returns before the cache policy and is byte-for-byte unchanged, so
the drop is not attributed to this change.

This is meaningful progress, not leadership. Real compressed multi-block files
remain 17--39% behind libzstd after both changes. The next profile should
separate split-decoder rejection reasons, incomplete-Huffman literal decoding,
FSE table rebuilds, and the remaining exact-copy traffic rather than broadening
wildcopy again.

## Validation

- 671/671 direct Zstd tests pass in ReleaseFast.
- The one-shot and reusable 13-row reference gates pass against libzstd 1.5.7.
- The decode-profile gate and three-row/two-API path smoke pass.
- The 276-case compatibility matrix passes with zero unsupported cases.
- All nine upstream decodecorpus campaigns pass: 9,900 frames, all 64 sequence
  mode combinations, and real reusable table hits.

The broad `zig build check -Doptimize=ReleaseFast -j1` was not completed: its
dependency on the monolithic all-codec `vort-tests` root remained in LLVM code
generation for tens of minutes. This is not reported as a pass. The direct
Zstd suite and codec-specific gates above are the authoritative validation for
this change.
