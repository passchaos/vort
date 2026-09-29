# Brotli large single-tree executor

Date: 2026-09-29

## Motivation

Repository source and documentation compressed by libbrotli quality 1 expose a
common large-stream shape with exactly one literal block type, one literal
context tree, one command block type, one distance block type, and one distance
context tree. The previous decoder still entered the general external-literal
executor, checking block switches, recomputing context-map indexes, and looking
up the active command and distance trees for every command.

The specialized executor is selected only when all five single-tree and
single-block invariants hold and the decoded meta-block is already on the
existing large-stream path. It prepares one 10-bit literal lookup, one mapped
10-bit command lookup, and one 9-bit distance lookup. The payload loop can then
decode directly from those three objects without block-switch or context-map
work. Root misses still use the canonical Huffman tables, and malformed input,
output bounds, distance validation, dictionary transforms, and recent-distance
updates retain the existing checks.

## Paired performance

The baseline is committed revision `51d5c13f`. Both inputs come from that clean
checkout, were compressed once with local libbrotli 1.2.0 quality 1, and were
kept under `/tmp`; no source path, hash, or file metadata was added to tracked
benchmark data. Independent ReleaseFast binaries were run in alternating order
for 15 pairs, with 100 timed caller-buffer decodes per best-of-five sample.

| workload | median speedup | geometric mean | wins | range |
| --- | ---: | ---: | ---: | ---: |
| source q1 | 1.2029x | 1.2028x | 15/15 | 1.1653x--1.2367x |
| documentation q1 | 1.2478x | 1.2483x | 15/15 | 1.2286x--1.2775x |

Fifteen candidate-versus-libbrotli runs put source q1 at 0.9203x median and
documentation q1 at 0.9050x median. This closes most of the previous gap but
does not establish Brotli decode leadership.

## Correctness evidence

A focused route test builds a large source-backed fast-level stream, proves all
five structural gates, decodes through the specialized executor, and compares
the entire output. The 13-row reference gate passes. The upstream differential
passes 99 core cases, 7,056 one-shot cases, 7,056 progressive cases, 1,401
fragmentation runs, seven Large Window cases, and 64 high-tree truncation
cases. The seven-test real-corpus driver smoke also passes.

## Scope

The specialization is intentionally limited to large standard-window streams
whose literal, command, and distance state cannot switch. Multi-tree,
multi-block-type, small-stream, and Large Window inputs keep their existing
decoders. This removes work only when the parsed Brotli header proves it is
unnecessary.
