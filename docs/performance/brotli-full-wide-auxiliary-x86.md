# Brotli full-tier command and distance roots

Date: 2026-10-02. Baseline: `d8a9e6c6`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, one codec thread pinned to CPU 2.
Reference: local libbrotli 1.2.0-dev, commit `558fc647`, built with CMake
Release (`-O3 -DNDEBUG`).

## Change

The 129--256-literal-tree decoder previously retained separate command-symbol
and length-metadata lookups, in-header distance roots, and repeated literal
block-state loads. The new executor uses the middle tier's established fused
ten-bit command roots and contiguous nine-bit distance roots while preserving
the full tier's ten-bit literal roots.

Active command tree/root, four-entry distance context map, context-three tree
index, and literal context state are retained until the corresponding block
switch. Single-literal runs use the existing shared literal loop. Long Huffman
codes, nonzero insert lengths, dictionary references, distance-history updates,
and checked match copies keep the existing helpers.

The existing large-stream routing and auxiliary eligibility remain in force:
the large decoder handles encoded streams of at least 16 KiB; this literal
path requires a meta-block of at least 64 KiB; command types must fit the
32-tree inline tier and distance trees the 64-tree tier, with the established
tail-table-capacity checks. The new auxiliary storage is explicitly limited
to more than 128 literal trees. The generic wide helper retains its original
auxiliary executor for smaller groups and its canonical fallback for other
trees. Setup and payload execution live in a separate text section.

## Memory and code size

The extra fixed root storage is 192 KiB: 32 command roots of 4 KiB and 64
distance roots of 1 KiB. Only the trees present in the meta-block are built.
The existing 512 KiB full-tier literal plane is unchanged. This remains an
allocation-free decoder with bounded function-owned scratch.

In the measured x86-64 executable, the additional setup function reserves
212,096 bytes of stack before register saves/alignment; this includes the
root arrays, temporary table-building storage, and spills. Its isolated text
section occupies 8,213 bytes. These are explicit memory/code tradeoffs for
full-frame throughput, not a memory reduction.

## Measurement method

Inputs are frozen repository files reconstructed from `488c5415`, so adding
tests or updating this report cannot alter the timed workload. The roadmap
snapshot contains 1,251,399 bytes and 143 literal trees; local libbrotli emits
350,069 bytes at quality 5 and 335,220 at quality 9. Those streams use three
command types and 22/27 distance trees. The source snapshot contains 1,726,567
bytes and uses 117/104 literal trees at qualities 5/9, covering the unchanged
middle tier.

Complete reference comparisons alternate Vort and libbrotli inside each of
five warmed rounds and retain each implementation's best time. Baseline and
candidate process order reverses on successive pairs. Decoder-only controls
use the same five-round estimator and alternating process order; they omit
the separate size/allocating-API timings. Full decoded output is verified by
the benchmark, and every comparison requires matching input/encoded sizes,
iteration counts, and checksums. The full comparison also records input and
executable SHA-256 hashes and runtime reference versions.

## Final throughput

Ratios below compare the final candidate with the frozen pre-change executable.

| Input / quality | Pairs won | Median | Geometric mean | Minimum pair | Candidate/libbrotli median |
| --- | ---: | ---: | ---: | ---: | ---: |
| roadmap q9 | 15/15 | 1.1218x | 1.1348x | 1.0998x | 0.6975x |
| roadmap q5 | 7/7 | 1.1263x | 1.1285x | 1.1174x | 0.7171x |

The q9 geometric result includes one 1.2993x pair under varying host load;
the 12.18% median improvement and 9.98% minimum improvement are the primary
acceptance evidence. Reference-normalized geometric improvement is 1.1286x.
The final executable SHA-256 is
`cb594fddb5b00e1b8d93bd077ab9aa7ad697187e5b4f51263d44b4e9118c673b`;
the baseline is
`fc9a2be0e78fe66c53a0b12a2ed4f53443a4257b7cc04538986fa4a50e5d5291`.

Final decoder-only controls retain the following complete-frame results:

| Control | Pairs | Median | Geometric mean | Wins |
| --- | ---: | ---: | ---: | ---: |
| source q9, 104 literal trees | 7 | 0.9953x | 0.9961x | 1/7 |
| source q5, 117 literal trees | 7 | 1.0000x | 1.0018x | 3/7 |
| clustered q8 | 15 | 1.0012x | 1.0007x | 10/15 |

Source q9 has a small 0.47% median regression in this executable; it is not
reported as a gain. The unchanged middle-tier executor retains its machine-
code size but moves in the linked image. The retained tradeoff improves the
previously slower full tier by more than 12% while keeping the existing
reference-gate floors. Further work must continue to track this source control.

## Layout control

An initial version removed the old ordinary-text auxiliary executor and
regressed `clustered_q8` to 0.9928x median / 0.9924x geometric throughput,
with 1/11 wins. Retaining the generic wide helper's original smaller-tier
fallback and making the new storage threshold explicit restores this control
to 1.0012x median / 1.0007x geometric over 15 pairs, with 10 wins. The rejected
layout is retained in the evidence separately from the final implementation.

## Correctness coverage

A differential test promotes each of the twelve existing copy/context/block-
switch fixtures to the full literal tier. It compares the new executor with
the previous wide executor at every truncated payload bit and shortened
output boundary, including error identity, consumed-bit position, output
progress, recent-distance history, all three block-state counters/types, and
the untouched physical caller suffix.

A public-API fixture exercises 128, 129, and 256 literal trees, checks actual
selection of the new executor, verifies truncated copy-length fields and
short output errors, and guards the caller suffix. AArch64 tests are also
cross-compiled and linked; they are not executed on this x86 host.

The final source passes all 544 direct Brotli tests, the focused Debug
transition/boundary oracle, 7,056 generated upstream cases and their 7,056
progressive counterparts, 1,401 fragmentation schedules, 64 high-tree
truncations, seven Large Window cases, and the four-file 16/16 real-corpus
matrix. `zig fmt --check src/br.zig`, `zig build check -j2`, and
`zig build run -j2 -- --help` pass.
The final 13-row local-libbrotli reference gate passes its existing throughput
floors, and the benchmark path smoke passes three valid rows and five invalid
argument combinations.

The remaining reference gap is still substantial. These results apply to the
recorded full-tier workloads and controls and do not establish broad Brotli
leadership across corpora, qualities, streaming APIs, or architectures.

All sample times, hashes, exact commands, reference builds, invariant checks,
and the rejected-layout control are recorded in
[brotli-full-wide-auxiliary-x86-20261002.json](data/brotli-full-wide-auxiliary-x86-20261002.json).
