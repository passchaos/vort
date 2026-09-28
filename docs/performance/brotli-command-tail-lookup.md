# Brotli adaptive command lookup

Date: 2026-09-28

## Motivation

A five-second macOS sample of the `clustered_q8` decode path after identity
dictionary borrowing attributed 110 of 3,978 samples, or 2.77%, directly to the
704-symbol command table's long-code fallback. The existing in-table command
lookup resolves nine bits. Sparse command trees can fit a 10-bit lookup in the
same unused entry storage without growing `MinimalCompressedHeader`.

The flat 16--64 literal-tree decoder now attempts an atomic wider setup:

- every command tree must be single-symbol or have enough unused entries for a
  10-bit table;
- every distance tree must still be single-symbol or fit the established
  9-bit table;
- all capacity checks complete before either family is modified;
- if the wider command setup is unavailable, the decoder rebuilds neither
  partial state nor compatibility shims and uses the existing atomic 9-bit
  route.

The fast reader already has a fixed 10-bit peek for literal lookups. The
generic Huffman table now exposes the same width for eligible in-tail tables,
while dense tables retain their compact fallback representation.

## Correctness evidence

Focused tests cover 8-, 9-, and 10-bit lookup equivalence, long-code fallback,
truncation, capacity rejection, fixed-width fast-reader decoding, and atomic
fallback from a dense command tree:

```sh
zig test src/huffman.zig -OReleaseFast --test-filter 'tail lookup decoder'
zig test src/br.zig -OReleaseFast --test-filter 'adaptive auxiliary lookup'
zig test src/br.zig -OReleaseFast --test-filter 'fast bit reader preserves tail lookup'
```

The complete 13-row Brotli reference gate passes against local libbrotli 1.2.0.
The real-corpus manifest smoke runs seven tests, and the upstream differential
passes 7,056 one-shot cases, 7,056 progressive cases, 99 core cases, 64
high-tree truncation cases, and the operation-schedule and Large Window
matrices.

## Paired result

The baseline is commit `206f18ee`. Separate ReleaseFast binaries for the
baseline and candidate were run in alternating order for 15 pairs. Each
`clustered_q8` row records 100 timed decodes selected from the benchmark's five
samples. The source is 1 MiB and the Brotli stream is 52,622 bytes. The target
is aarch64 macOS with Zig 0.16.0 and `target_cpu=apple_m1`; CPU affinity was
unavailable.

| metric | 9-bit command lookup | adaptive 10-bit command lookup |
| --- | ---: | ---: |
| median Vort throughput | 1234.51 MiB/s | 1241.19 MiB/s |
| median Vort/libbrotli ratio | 0.7842x | 0.7883x |
| paired median speedup | 1.0000x | 1.0076x |
| paired geometric-mean speedup | 1.0000x | 1.0084x |
| paired wins | - | 13 / 15 |

The individual ratios range from 0.9716x to 1.0467x; excluding that single
low outlier, the remaining 14 range from 0.9959x to 1.0467x. A separate 13-row
run measures `clustered_q8` at 1243.19 MiB/s and 0.7808x local libbrotli. That
single-run value is not used for the speedup claim; the full matrix serves as a
coverage and regression gate, and all rows pass.

## Mechanism check

The same five-second sampling procedure was repeated on the candidate. Direct
samples in `HuffmanTable(704).decodeValueLongAfterLookup` fell from 110/3,978
(2.77%) to 58/4,016 (1.44%), a 47.9% reduction in observed command long-code
fallback share. This supports the intended lookup-width mechanism rather than
relying on throughput alone.

The result is a narrow improvement for sparse command trees. Dense command
trees still use the established 9-bit lookup, and broad Brotli decode
leadership remains open.

## Follow-up experiments rejected

The same independent-binary, alternating-order protocol was used to avoid
keeping source-level simplifications that only reshuffled this layout-sensitive
executor:

- Widening both command and distance tables to 10 bits eliminated the sampled
  distance long-code fallback (8/4,016 samples to zero), but 15 pairs measured
  a 0.9950x median, 0.9940x geometric mean, and only 2/15 wins. The committed
  command-10/distance-9 split remains faster.
- A fixed eight-bit reader entry point for the flat literal root lookup
  measured 1.0006x median, 1.0016x geometric mean, and 9/15 wins. This is below
  the retention threshold despite a positive short screen.
- Explicitly hoisting the window-distance limit measured 1.0013x median,
  1.0043x geometric mean, and 9/15 wins. LLVM already removes enough of this
  invariant work that the source change is not justified.
- Aligning all three payload executor instances to 64 bytes measured 0.9956x
  median and 2/15 wins. A 256-byte alignment screen measured 0.9903x, so fixed
  alignment was rejected rather than used to mask layout sensitivity.
- Screens for a combined zero-extra-bit branch, a trusted command-symbol entry,
  compile-time UTF-8 specialization, and an inlined dictionary transform ranged
  from neutral to roughly 2% slower. None advanced to the retained tree.
- Reusing the second spare slot bit to tag commands with only copy extra bits
  equal to zero was also rejected. Although a short screen was positive, 15
  alternating pairs measured 0.9990x median, 1.0012x geometric mean, and only
  7/15 wins. Tag dispatch remains restricted to commands with both extra-bit
  widths zero.

These results narrow the next work to changes that reduce payload-loop work
without adding executor instances or moving small checks across call boundaries.

## Fused zero-extra command entries

The 10-bit command table originally stored only `(symbol + 1, Huffman bits)` in
each 16-bit slot. A root hit then indexed the separate 704-entry compact command
table to recover insert/copy bases, extra-bit widths, and implicit-distance
state. The two formats cannot overlap: every ordinary command slot is below bit
15 because the alphabet has only 704 symbols.

The unused high bit now tags a fused slot for commands whose insert and copy
lengths have no extra bits. The remaining bits hold the Huffman width, the
complete insert and copy bases, and the implicit-distance flag. Such a root hit
therefore returns `InsertCopyLengths` directly. Commands with either extra-bit
field keep the ordinary symbol slot and compact metadata lookup; codes longer
than 10 bits keep the canonical fallback. The table remains 2 KiB per command
tree and no decoder-state structure grows.

The builder checks all command and distance capacities before writing any tail
table. Unit coverage exhaustively checks all 704 command metadata rows for
ordinary/fused encoding separation and exact field recovery. Decoder tests
cover a fused root hit, an extra-bit root hit, an 11-bit fallback, dense-tree
rejection, and the original invalid-symbol path.

Against commit `cf9b124c`, 15 alternating-order `clustered_q8` pairs on the
same aarch64 macOS host produced:

| metric | symbol-only lookup | fused zero-extra lookup |
| --- | ---: | ---: |
| median Vort throughput | 1518.06 MiB/s | 1577.54 MiB/s |
| median Vort/libbrotli ratio | 0.7923x | 0.8195x |
| paired median speedup | 1.0000x | 1.0414x |
| paired geometric-mean speedup | 1.0000x | 1.0387x |
| paired wins | - | 15 / 15 |

Individual ratios range from 1.0086x to 1.0768x. A separate full 13-row run
passes the reference gate and measures `clustered_q8` at 1581.52 MiB/s, or
0.8281x local libbrotli 1.2.0. Because that matrix was not paired under a fixed
host load, its large apparent movement on unrelated small rows is not used as
a performance claim.

The full command-table oracle, 10-bit Huffman lookup oracle, focused decoder
tests, seven-test real-corpus manifest smoke, and upstream differential all
pass. The latter covers 7,056 one-shot cases, 7,056 progressive cases, 99 core
cases, and 64 high-tree truncation cases. Broad Brotli leadership remains open.
