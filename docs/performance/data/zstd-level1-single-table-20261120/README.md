# Zstd level-1 single-table parser, 2026-11-20

## Decision

Level 1 now uses the compact parser's `single_table` variant: the 8-byte hash
table, lazy lookahead and rep probes stay, while the 4-byte short table is
dropped. This follows the user-directed zstd level semantics: libzstd level 1
is the speed-first fast parser and level 2 the double-fast parser. Vort level 2
(controlled fast) and level 3 (greedy) are unchanged, so the ladder remains
monotone: level 1 is larger and faster, level 2 smaller, level 3 smaller
still.

The variant is exposed as `FastParserSelection` on `NativeFrameOptions`
(`auto`, `double_fast`, `single_table`); `applySpeedFirstLevelPolicy` selects
`single_table` for level 1 only. Explicit strategies and encode controls still
take precedence.

## Measurement

- Host Intel i7-10700K, Linux 6.8, Zig 0.16.0 ReleaseFast, `skylake+pku+sgx`,
  single thread.
- `run-zstd-encode-bench`, level 1, one-shot, twelve 128 KiB Silesia prefixes,
  `--iterations 1000 --rounds 3`, interleaved with libzstd 1.6.0.
- Baseline is the current two-table source (dominance skip + transition
  bit-count fusion).

| case | before MiB/s | after MiB/s | speed ratio | before bytes | after bytes | size delta |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| dickens | 94.16 | 134.41 | 1.4275 | 59,878 | 61,059 | +1.97% |
| mozilla | 190.80 | 229.25 | 1.2015 | 24,399 | 26,808 | +9.87% |
| mr | 85.04 | 148.26 | 1.7435 | 36,827 | 35,485 | -3.64% |
| nci | 249.93 | 283.61 | 1.1348 | 11,491 | 11,354 | -1.19% |
| ooffice | 102.78 | 144.25 | 1.4034 | 76,442 | 82,574 | +8.02% |
| osdb | 132.51 | 166.67 | 1.2577 | 61,098 | 62,224 | +1.84% |
| reymont | 83.45 | 129.09 | 1.5469 | 43,617 | 47,196 | +8.21% |
| samba | 115.55 | 148.99 | 1.2893 | 54,011 | 56,726 | +5.03% |
| sao | 97.48 | 169.39 | 1.7377 | 114,461 | 118,136 | +3.21% |
| webster | 105.79 | 139.32 | 1.3169 | 48,838 | 50,775 | +3.97% |
| xml | 278.71 | 305.64 | 1.0966 | 12,323 | 12,518 | +1.58% |
| x-ray | 126.73 | 150.32 | 1.1862 | 107,218 | 108,016 | +0.74% |

Geometric-mean speed **1.3466x**, geometric-mean size **+3.23%** (worst
mozilla +9.87%; mr and nci shrink). Every wire is verified by both libzstd
and Vort before timing.

## Correctness

The single-table parser reuses the same rep probes, lazy lookahead, backward
extension and record writer; only the short-table candidate and insertion are
removed. `test-zstd` golden level-1 wires and size bounds are re-frozen for the
new parser; level 2/3 wires are unchanged. The full `test`/`check`/`check-wasm`
gate is the adoption check.

## Scope limits

One host, one-shot level 1, 128 KiB prefixes. The short-table loss is
content-dependent: binary rows (mozilla, ooffice, reymont) pay most of the
size cost, while mr/nci shrink. Level 2 remains the ratio-first fast option.
