# Brotli q1 compact two-pass entropy writer

Date: 2026-10-19. Baseline: `85e2223b`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Runtime
reference: system libbrotli 1.0.9. Upstream algorithm invariants were audited
against local Brotli `v1.2.0-169-g558fc64`; Vort emits its own deterministic
RFC wire and does not claim byte identity.

## Implementation

`src/br/encoder/fast_fragment_two_pass.zig` converts the q1 fragment command
plan into the reference fast encoder's logical 128-symbol temporary alphabet:
commands occupy 0...63 and distances 64...127. The first pass collects exact
literal, compact-command, and compact-distance histograms. It adds the same
two non-degenerate command and distance sentinel pairs, builds length-limited
8-/15-/14-bit trees, and expands the compact command lengths into Brotli's
704-symbol RFC alphabet. The second pass emits compact events and literals
directly through the shared bounded bit writer.

Insert-plus-copy commands retain the reference two-command representation:
the insert command copies two bytes, an explicit/recent distance follows, and
the continuation command copies the remainder. Zero-insert copies use the
ordinary copy command followed by an explicit distance. The writer updates the
RFC distance ring and output position transactionally for the next meta-block.

The specialized path covers ordinary block-local LZ commands. RAW compound-
dictionary commands deliberately fall back to the complete general writer,
preserving the existing attachment semantics rather than guessing a compact
extension.

## Correctness evidence

Exhaustive formula tests cover every insert length 0...65,536, every copy
length 4...65,536, every last-distance continuation in that range, and every
standard distance 1...65,520. Each temporary event is checked against Vort's
authoritative RFC command table or distance encoder. Histogram tests pin
terminal inserts, repeated-distance symbols, sentinels, and event accounting.

A dedicated 8 KiB/128-literal fixture proves the dense Huffman transition
above the 64-symbol sparse-encoder ceiling and asserts that the q1 writer was
actually selected. The Node differential decodes the same fixture in addition
to the q0...q11 generic/text/font matrix. Existing public-surface tests require
one-shot, chunked, reusable, caller-buffer, and arbitrarily fragmented
incremental q1 output to remain byte-identical, and q0/q1 allocation-failure
injection covers the new path.

`zig build test-br --summary all` now passes 814/814 tests after the q0...q3
writer follow-ups. The complete
`zig build run-br-planned-node-diff` matrix passes with the new wide-literal
case, and `run-br-compound-dictionary-diff` passes its four repository-owned
fallback fixtures. The system 1.0.9 runtime lacks the newer shared-dictionary
symbols, so its optional external matrix remains explicitly skipped.

## Fixed-CPU A/B evidence

The baseline is the preceding dedicated-parser implementation using the
general command/tree writer. Independent ReleaseFast binaries encode frozen
32 KiB prefixes for 200 iterations; each executable selects the best of five
rounds and alternates Vort/libbrotli order. Baseline executable SHA-256 is
`7bbe5d3f82eb91293f6590b5c481f9c9d9324c74ea7e466a4ff498c262563cb9`;
candidate SHA-256 is
`0f56681e61000a47e540dd1fb624153e4b8bf69ca24c0d755219d6c50725e9c3`.

| Input | Input SHA-256 | Baseline MiB/s | Candidate MiB/s | Speedup | Bytes baseline -> candidate | Candidate/libbrotli speed | Candidate/libbrotli size |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| README | `eb72ac8d8090a83afc353c41c9a2aa76140f192345f720005a7a860d86456635` | 43.18 | 73.14 | 1.6937x | 12,427 -> 12,919 | 0.2863x | 0.9794x |
| Zig source | `65fd1e2d12f02061cf486990ba81108d2796b5395045c446547acd69db0f53d5` | 55.92 | 93.89 | 1.6789x | 8,491 -> 8,789 | 0.2603x | 0.9889x |
| structured JSON | `726db67581841c221e1beb4f11041ccbae2cb3131c37f67049cd934461ea569c` | 79.20 | 129.39 | 1.6336x | 6,224 -> 6,475 | 0.2405x | 0.9949x |
| dictionary binary | `d2d62abaf82384d6a58b477d3ad0217c834f81168d7155bebbad8d24782f17ed` | 40.39 | 58.14 | 1.4394x | 22,646 -> 23,814 | 0.2734x | 1.0176x |

Every row improves. Geometric throughput rises by 1.6080x, while output size
grows by 1.0416x versus the prior general writer. The candidate is within
0.51%...1.76% of system libbrotli size on three rows and 2.06% smaller on
README, but reaches only 0.2405x...0.2863x of its throughput. This is an
explicit q1 speed/ratio tradeoff, not a broad parity claim.

Reproduce with:

```sh
taskset -c 2 zig build -Doptimize=ReleaseFast \
  run-br-planned-encode-bench -- \
  --path README.md \
  --path src/lz77.zig \
  --path docs/performance/data/brotli-short-copy-x86-20261002.json \
  --path src/br/dictionary.bin \
  --limit 32768 --iterations 200 --quality 1 --planned-quality 1
```

The remaining q1 throughput gap is now in tree construction/header emission,
allocation/output plumbing, and the bit writer rather than the general
704-symbol command analysis that this path removes.
