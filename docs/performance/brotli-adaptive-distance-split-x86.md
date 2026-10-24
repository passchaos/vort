# Brotli adaptive distance-block splitting

Date: 2026-10-14. Host: Intel Core i7-10700K, Linux x86-64, Zig 0.16.0,
ReleaseFast, CPU affinity 2, one codec thread.

## Functional result

The general integer-Q8 Viterbi splitter is now integrated through the complete
Brotli distance-symbol wire rather than stopping at its standalone model:

- arbitrary non-empty distance blocks and normalized non-cyclic type reuse;
- shared previous (`0`), successor (`1`), and direct (`type + 2`) transition
  coding with dynamically planned block-length prefixes;
- allocator-owned per-type distance histograms, Huffman lengths, and encoders;
- an identity distance context map supporting the complete 2--256 type/tree
  range and all four distance contexts per block type;
- individual adaptive-command, adaptive-distance, and combined candidates,
  all subject to strict complete-wire arbitration.

The focused production fixture has 8,192 explicit distance symbols, off-grid
boundaries 901/2305/5179/7001, and normalized types `A-B-A-C-A`. Its compressed
size is 9,521 bytes for a 98,304-byte payload. Vort, Node, runtime libbrotli
1.0.9, and Vort's 17-byte-input/31-byte-output progressive decoder reproduce
the payload byte-for-byte. A second 1,528-byte production stream expands to
66,560 bytes and exercises all 256 distance block types, all 256 distance
context trees, and the full 1,024-entry context map through the same external
decoders. The required upstream differential reports ten planned
distance-split cases.

Core coverage includes exact off-grid/non-cyclic Viterbi assignments,
stationary rejection, malformed symbols/options, every splitter allocation
failure, adaptive writer allocation cleanup, 2/3/4/5/8/17/50/256-tree context
map bit-cost oracles, public automatic/disabled/forced policy, and exact-wire
selection against the unsplit and legacy fixed-grid candidates.

## Automatic ratio policy

Ratio mode automatically considers adaptive distance splitting only for inputs
of at least 64 KiB whose derived explicit-distance stream contains
2,048--32,768 symbols. The retained budget uses one iteration and eight
temporal seeds under a 2 MiB scratch cap.
`PlannedEncodeOptions.adaptive_distance_split` is nullable: `null` selects this
automatic policy, `false` disables it, and `true` explicitly requests it.

The benchmark's nine built-in rows retained identical sizes. A fixed 128 KiB
prefix sweep over six repository source/Markdown files compared explicit
disabled and enabled runs:

| Input | Disabled bytes | Adaptive bytes | Delta | Disabled/adaptive speed |
| --- | ---: | ---: | ---: | ---: |
| `src/br.zig` | 21,652 | 21,627 | -25 | 0.7796x |
| `src/zstd.zig` | 22,160 | 22,080 | -80 | 0.7774x |
| `src/deflate.zig` | 22,435 | 22,435 | 0 | 0.7602x |
| `README.md` | 29,485 | 29,335 | -150 | 0.7614x |
| `docs/roadmap.md` | 34,019 | 33,830 | -189 | 0.7574x |
| `docs/zstd-gap.md` | 41,314 | 41,057 | -257 | 0.7750x |

The size result justifies automatic search for the quality-oriented ratio
level; the latency cost remains explicit and is not presented as a speed win.
Callers prioritizing latency can disable the candidate.

## Default-path isolation

The adaptive writer stays in the existing cold adaptive text section. Eleven
alternating fixed-CPU-2 comparisons against commit `ce909cf3`, 20 source32k
encodes per process, retained the same 6,606-byte wire and checksum. The current
binary won 9/11 pairs, with independent medians 189.033 -> 187.994 ms and a
paired geometric throughput ratio of `1.008979x`. This is no-regression layout
evidence, not a general throughput claim.

The distance encoder additionally implements and independently checks all 64
legal RFC `NPOSTFIX/NDIRECT` shapes. Production selection, its isolated
520-symbol writer, and complete-wire arbitration are now implemented and
measured separately in `brotli-distance-parameters-x86.md`.
