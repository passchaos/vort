# Zstd fast planner transition bit count, 2026-11-20

## Change

`largeFastSequenceTableCost` recomputed the compressed plan's transition bit
count by summing the `transition_bits` array in a separate pass. The FSE
transition fill already visits every sequence and knows each width, so it now
returns the sum alongside the initial state (`large_transition.FillResult`);
the plan stores `transition_bit_count` and the cost function adds it directly.
The non-direct test path computes the same sum while filling. The cost value
and the selected plans are unchanged; only the redundant pass is removed.

## Measurement

- Host Intel i7-10700K, Linux 6.8, Zig 0.16.0 ReleaseFast, `skylake+pku+sgx`,
  single thread.
- `run-zstd-encode-bench`, level 1, one-shot, twelve 128 KiB Silesia prefixes,
  `--iterations 1000 --rounds 3`, interleaved with libzstd 1.6.0.
- Baseline is the current dominance-skip source.

| case | before MiB/s | after MiB/s | speed ratio | bytes |
| --- | ---: | ---: | ---: | ---: |
| dickens | 92.88 | 94.16 | 1.0137 | 59,878 |
| mozilla | 189.41 | 190.80 | 1.0073 | 24,399 |
| mr | 83.60 | 85.04 | 1.0172 | 36,827 |
| nci | 247.49 | 249.93 | 1.0099 | 11,491 |
| ooffice | 102.25 | 102.78 | 1.0052 | 76,442 |
| osdb | 132.27 | 132.51 | 1.0018 | 61,098 |
| reymont | 81.94 | 83.45 | 1.0185 | 43,617 |
| samba | 114.56 | 115.55 | 1.0087 | 54,011 |
| sao | 96.67 | 97.48 | 1.0084 | 114,461 |
| webster | 104.73 | 105.79 | 1.0101 | 48,838 |
| xml | 276.63 | 278.71 | 1.0075 | 12,323 |
| x-ray | 127.29 | 126.73 | 0.9956 | 107,218 |

Geometric-mean speed **1.0086x**; every output is byte-identical. This is a
small structural removal, not a standalone 3% milestone; it is recorded as
part of the level-1 emitter series.

## Correctness

The stored sum is computed from the same per-sequence widths the old pass
summed, excluding the final sequence in both cases. The full `test-zstd` suite
is the adoption check; all twelve measured wires are byte-identical.
