# Zstd wide split-literal capacity

Large all-FSE blocks with four Huffman literal streams are faster when Vort
decodes the literals once and then executes the sequence stream against that
scratch buffer. The wide split path was previously limited to 32 KiB of
regenerated literals. A real level-1 `docs/roadmap.md` frame contains a block
just above that boundary, so it fell back to per-symbol Huffman decoding even
though the existing split executor otherwise supported its shape.

The wide scratch limit first moved to 64 KiB, which keeps the allocation-free
decoder and adds 32 KiB of bounded stack scratch over the prior implementation.
The 16 KiB dense path remains a separate specialization, so its generated code
and smaller stack frame are unchanged.

## Evidence

Baseline: local commit `1c2f3581`. Host: Apple M1 Pro, macOS, Zig 0.16.0,
ReleaseFast, one codec thread, no affinity pinning. Reference:
`/opt/homebrew/opt/zstd/lib/libzstd.dylib`, version 1.5.7. The input is a frozen
1,164,573-byte snapshot of `docs/roadmap.md` with SHA-256
`1704fb667b58db5f1189f2f79bc9e13d2fb7ba556d7e99895f989ceacaf3ce2d`.
libzstd level 1 produces a 402,431-byte frame with nine compressed blocks,
86,285 sequences, and 265,787 regenerated literal bytes.

Before the change, a five-second system sample attributed roughly one third of
the decode samples to the interleaved `decodeAllFseHuffmanSequences` fallback.
After raising the bound, that fallback disappeared from the same workload and
all nine blocks used the split path.

Both binaries used the same frozen input and runtime libzstd. Each process
reported its best of five rounds, and process order alternated between baseline
and candidate. Every pair matched input hash, encoded size, and output checksum.

| API | pairs won | median speedup | geometric mean | minimum pair | candidate/libzstd median |
| --- | ---: | ---: | ---: | ---: | ---: |
| caller-owned one-shot | 15/15 | 1.3646x | 1.3645x | 1.3389x | 0.9833x |
| reusable decoder | 11/11 | 1.3761x | 1.3800x | 1.3498x | 0.9846x |

Seven-pair controls remained near neutral: `README.md` 0.9962x median,
`build.zig` 0.9999x, frozen `src/zstd.zig` 1.0044x, `ascii64k` 1.0007x, and
`binary_mixed` 1.0087x. A longer 15-pair `large_json` control measured 0.9966x
median and 0.9939x geometric mean. These small movements are treated as noise,
not as gains. The target is now near reference throughput on this machine, but
the result does not establish broad industry-leading performance across
corpora, levels, APIs, or CPUs.

## Rejected variants

- A persistent sequence-bit reservoir reduced source loads in theory, but
  increased the prepared roadmap sequence stage from about 10.56 to 12.03
  ns/sequence and regressed the end-to-end decoder.
- A dedicated zero-literal branch regressed the target substantially despite
  removing redundant 16-byte literal wildcopies.
- Forcing all three split-loop entry points to 64-byte alignment made the
  `build.zig` control 0.9607x median across seven pairs, so explicit alignment
  was not retained.

The correctness gate for this change is the existing split-Huffman generic
parity and mutation test plus the native compatibility/decodecorpus suites.

## Full-block follow-up (2026-09-24)

Testing every file under `~/Downloads/vort-test` exposed a second routing gap:
large literal-heavy blocks with fewer than 1,024 sequences remained on the
per-symbol Huffman path. The wide scratch is therefore extended to Zstd's
128 KiB maximum decoded block size, and the split path is selected when either
the block has at least 1,024 sequences or at least 32 KiB of regenerated
literals. The latter threshold amortizes bulk Huffman setup without routing
small blocks away from the established decoder.

Against the preceding `7715d03e` decoder, 15 alternating pairs improve the
7,587,144-byte `nndl-v2 (1).pdf` input by 1.6025x median / 1.5994x geometric
mean and the 38,933,880-byte `zellij` input by 1.6722x / 1.6685x; both win
15/15 pairs with identical input hashes, encoded sizes, and decoded checksums.
The corresponding reusable-decoder medians are 1.6038x and 1.6747x, again with
15/15 wins. Fifteen-pair controls are neutral: build 1.0020x, source 1.0003x,
roadmap 1.0005x, large_json 1.0069x, binary_mixed 1.0005x, and ascii64k
0.9999x by median. This follow-up adds another bounded 64 KiB of stack scratch
to the wide specialization, for 128 KiB plus its 16-byte overcopy guard in
total.
