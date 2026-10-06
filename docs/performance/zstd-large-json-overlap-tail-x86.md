# x86-64 Zstd 71-byte overlap-tail copy

The 2026-10-01 change reduces the exact-copy cost in the compact split-Huffman
executor selected by the synthetic `large_json` benchmark. Its four full
blocks each contain about 1,834 sequences and 2 KiB of literals; most output is
formed by non-overlapping 68--71-byte matches.

## Implementation and safety

The existing 71-byte helper used two 32-byte moves followed by an eight-byte
tail load, shift, destination-suffix load, merge, and eight-byte store. The new
pair-path helper loads all source bytes before writing, stores the same first
64 bytes, then writes an exact eight-byte tail at destination offsets 63--70.
The final store overlaps the preceding store by one byte but never writes past
the logical match.

The helper is selected only inside the already validated paired
one-literal/rep0 path and only when `match_len == 71` and
`match_offset >= 71`. Existing combined pair bounds prove output capacity, and
the non-overlap condition proves every source load is initialized before any
destination store. All other matches retain their established kernels.

## Performance evidence

Measurements use frozen ReleaseFast executables pinned to CPU 2 on an Intel
Core i7-10700K. Each process alternates five Vort/libzstd samples and reports
the fastest; 15 outer pairs alternate baseline/candidate process order. The
baseline is commit `89ce6618`; the reference is the user-provided
`~/Work/zstd` checkout at commit
`01b7154f1172432f8abe9b3bb9909e14a1176b7d` (libzstd 1.6.0-dev).

Across 15 pairs of 3,000 complete `large_json` decodes, the candidate improves
by **1.0096x median / 1.0105x geometric mean**, wins **14/15**, and ranges from
0.9981x to 1.0255x. After simultaneous libzstd normalization the geometric
gain is 1.0144x with 15/15 wins. Vort remains at 0.7940x libzstd by median, so
this is a bounded executor improvement rather than a leadership result.

A seven-pair 13-row control matrix measures `large_json` at 1.0065x median /
1.0114x geometric mean with 7/7 wins. `huffman80k`, `large_text`, and
`binary_mixed` remain within 0.45% of neutral geometrically. Short rows retain
wider scheduler noise and are not attributed to this path.

The nearest prepared-stage shape generated from the fixed 128 KiB payload at
libzstd level 2 contains 1,835 sequences and 2,117 literals. Across 15 paired
5,000-decode runs its executor improves by 1.0030x median / 1.0032x geometric
mean with 10/15 wins. The exact repository fixture has a different 2,874-byte
wire shape, so complete-frame results remain the primary evidence.

Exact observations and hashes are retained in
[zstd-large-json-overlap-tail-x86-20261001.json](data/zstd-large-json-overlap-tail-x86-20261001.json).

## Zig 0.16 LLVM lowering follow-up (2026-10-06)

Software PC sampling of the current ReleaseFast binary placed 11.1% of the
compact production executor's samples in `appendNonOverlapping71OverlapTail`.
The source still expressed the retained two-vector plus overlapping eight-byte
tail design, but current LLVM recognized that the tail's first byte duplicates
the preceding 32-byte store. It eliminated that byte and lowered the remaining
seven bytes into 4+2+1 scalar loads and stores. The generated implementation
therefore no longer matched the machine shape whose performance justified the
helper.

The helper now uses proven unaligned volatile accesses for the overlapping
second vector and `u64` tail. Both source loads still precede every destination
store, the tail remains entirely inside destination offsets 63--70, and no
suffix byte is read or written. Volatile is used only to preserve the already
required move widths against overlapping-store elimination; it does not add an
I/O or synchronization contract. ReleaseFast machine code is exactly two
32-byte loads/stores plus one eight-byte load/store. The complete-frame
production instance shrinks from `0x257e` to `0x2530`, the strict sibling from
`0x223e` to `0x220e`, and the split section from `0x47bc` to `0x473e`.

The same frozen 512 KiB `large_json` frame was measured in five independent
clean campaigns. Nineteen fixed-CPU-2 pairs improve by **1.0123x median /
1.0131x geometric** throughput, win **19/19**, and have a **1.0024x** minimum.
Candidate/libzstd 1.6.0 throughput rises from 0.9139x to 0.9255x at the median.
Seven prepared-stage pairs improve by 1.0190x median / 1.0184x geometric, all
7/7 wins. A separate 128-byte-matched seven-pair control repeats the target at
1.0175x median / 1.0183x geometric with 7/7 wins. Matched non-target medians
are `huffman80k` 1.0009x, `ascii64k` 0.9994x, `large_text` 0.9971x, and
`binary_mixed` 0.9942x; the raw-FSE, Huffman-only, and FSE/FSE/RLE hot sections
for the first, second, and fourth controls are byte-identical.

Upstream attribution confirms that this is not evidence for a decode-ahead
queue. All 30 observed libzstd block calls selected regular BMI2, while split
and long decoders had zero hits. A clean seven-pair build forced to the
eight-entry long decoder reached only 0.7906x median / 0.7893x geometric
normal-decoder throughput with 0/7 wins. Exact PC/gprof attribution, binary
hashes, retained observations, discarded-contamination accounting, and
control samples are in
[zstd-overlap-tail-lowering-x86-20261006.json](data/zstd-overlap-tail-lowering-x86-20261006.json).

### Single-sequence coverage follow-up

After retaining the lowering fix, a clean 2,000-sample PC profile placed 4.95%
of the compact executor in the older suffix-preserving 71-byte helper used by
four non-pair branches. Reusing the exact overlap-tail helper there was
semantically valid and let LLVM merge substantially more code: the production
instance fell from `0x2530` to `0x2413`, the strict instance from `0x220e` to
`0x2019`, and the split section from `0x473e` to `0x442c`.

The smaller layout was nevertheless slower. Seven clean prepared-stage pairs
measured 0.9969x median / 0.9961x geometric throughput with 1/7 wins, and seven
complete-frame pairs measured 0.9969x / 0.9984x with 3/7 wins. The four
single-sequence call sites therefore keep the suffix-preserving helper; only
the independently proven pair path uses the overlap-tail helper. Exact hashes
and observations are in
[zstd-single-71-overlap-followup-x86-20261006.json](data/zstd-single-71-overlap-followup-x86-20261006.json).

### Second 70-byte pair-tail follow-up (2026-10-07)

The same lowering lesson was tested on the pair executor's second 70-byte
match. Its retained exact tail uses a four-byte plus two-byte load/store. A
candidate loaded all source bytes before writing and forced one unaligned
eight-byte move at offsets 62--69, overlapping the second 32-byte vector by two
bytes without touching the caller suffix. LLVM emitted exactly the intended
two vector moves plus one `u64` move and removed two tail instructions. The
strict and production instances remained `0x220e` and `0x2530`; the complete
split section remained `0x473e`.

The smaller tail did not improve the complete frame. Seven continuously
monitored fixed-CPU-2 pairs measured **0.9994x median / 0.9993x geometric** raw
throughput with **3/7 wins**. Candidate/libzstd 1.6.0 median fell from 0.9160x
to 0.9145x. Five pairs happened to share the same 128-byte input/output layout;
their median remained 0.9994x with 2/5 wins. Four attempted fixed-layout
campaigns were discarded in full because a separate Zig workload appeared
during their measurement windows. The source candidate was removed; the
second 70-byte pair match retains its exact 4+2 tail. Exact hashes, samples,
layout accounting, and discarded-campaign metadata are in
[zstd-second-70-overlap-tail-x86-20261007.json](data/zstd-second-70-overlap-tail-x86-20261007.json).

## Validation and remaining work

- The copy helper is compared with the generic LZ match copy across lengths,
  minimum-distance boundaries, full output bytes, and untouched suffix bytes
  in ReleaseFast and ReleaseSafe.
- The existing split-Huffman oracle proves byte equality against the generic
  executor, short-output behavior, 64 sequence-bit mutations, 64 literal-bit
  mutations, and production route selection.
- All 677 direct ReleaseFast Zstd tests pass.
- The 276-case compatibility matrix, 9,900-frame/64-mode decodecorpus, generic
  x86-64/AArch64 compile checks, 13-row one-shot reference gate, and repository
  build check pass.

The lowering follow-up passes 682 direct ReleaseFast Zstd tests, the 276-case
compatibility matrix, all nine decodecorpus campaigns (9,900 frames, 2,699
block-stream cases, 76,578 streamed sequence blocks, and all 64 sequence-mode
combinations), generic x86-64/AArch64 compilation, 1,701 complete project
ReleaseFast tests, all 104 build-check steps, the ReleaseSafe copy oracle, and
the CLI help smoke.

A combined 68--71-byte tail kernel regressed the target, and a pair-first
one-byte-overwrite variant had zero hits in the fixed fixture; both were
removed. A post-lowering exact `u64` tail for the pair's second 70-byte match
was also neutral-negative and removed. Remaining work should change the
compact loop's table/bitstream execution model rather than revisit adjacent
68--71-byte tail spellings, then address the wider `binary_mixed` path.
