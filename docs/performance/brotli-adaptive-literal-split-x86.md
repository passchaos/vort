# Brotli adaptive literal-block splitting

Date: 2026-10-14. Host: Intel Core i7-10700K, Linux x86-64, Zig 0.16.0,
ReleaseFast, CPU affinity 2, one codec thread.

## Functional result

The shared integer-Q8 Viterbi splitter is now connected to the actual emitted
Brotli literal stream:

- discovery flattens only `Command.insert_len` byte ranges, excluding bytes
  reproduced by copy commands;
- block boundaries may occur inside one command's insert run;
- arbitrary boundaries and non-cyclic type sequences use the general
  previous/successor/direct transition model;
- per-type histograms, alphabets, code lengths, and encoders are allocator
  owned and support the complete 256-type wire range;
- each type currently uses one context-independent literal tree, with a
  `type_count * 64` identity context map;
- legacy literal splits and literal context clustering remain separate complete
  wire candidates; an adaptive literal plan is mutually exclusive with both.

The focused 8,192-literal production fixture uses boundaries
901/2305/5179/7001 and tree reuse `A-B-A-C-A`. A single insert command spans all
boundaries. Its stream is 5,201 bytes, and Vort, Node, runtime libbrotli 1.0.9,
plus Vort's 17-byte-input/31-byte-output progressive decoder reproduce the
payload exactly.

A maximum-width fixture declares 256 one-literal block types and 256 literal
trees. Its full 16,384-entry identity context map makes the header 16,948 bytes
for a 256-byte payload. Node, libbrotli, one-shot Vort, and Vort progressive
decode with caller-provided compressed-header scratch all accept the stream.
The required differential now reports `planned_literal_split_cases=11`.

Tests cover off-grid and non-cyclic discovery, boundary switching inside one
insert run, complete 256-type wire, exact-wire winner selection, public
ratio-only/size-monotonic behavior, malformed plan combinations, context-map
bit-cost equality at 256×64, and every splitter/writer allocation failure.

## Adoption and performance

The public feature is ratio-only and opt-in through
`PlannedEncodeOptions.adaptive_literal_split`. The retained production budget
uses one iteration, eight temporal seeds, 2,048--32,768 emitted literals, and a
2 MiB scratch cap. Exact complete-wire size remains authoritative.

Nine built-in benchmark rows retained identical output sizes. Six explicit
128 KiB source/Markdown paths also retained their default size while measuring:

| Input | Default/adaptive throughput |
| --- | ---: |
| `src/br.zig` | 0.9076x |
| `src/zstd.zig` | 0.9074x |
| `src/deflate.zig` | 0.9324x |
| `README.md` | 0.9295x |
| `docs/roadmap.md` | 0.9108x |
| `docs/zstd-gap.md` | 0.9093x |

This evidence does not support automatic enablement. The feature remains
available for heterogeneous caller corpora and as the structural base for the
next block-type × literal-context joint clustering increment.

Eleven alternating fixed-CPU-2 default-path comparisons against commit
`a273746e`, 20 source32k encodes per process, retained the same 6,572-byte wire
and checksum. The current binary won 6/11 pairs; independent medians were
189.125 -> 188.918 ms and the paired geometric throughput ratio was
`1.000518x`. This is no-regression layout evidence, not a speed claim.
