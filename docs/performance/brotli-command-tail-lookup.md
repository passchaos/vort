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
