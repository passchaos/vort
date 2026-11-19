# Zstd level-3 block-only match fast path, 2026-11-20

## Change

`zstd/match/controlled_search.zig`'s `matchAt` selected a dictionary, prefix
history, or block span on every 32-byte comparison chunk. One-shot frames have
neither a dictionary nor a prefix history, so every compared byte is in the
block. A block-only fast path now skips the per-chunk span selection and
`@min(span.len, ...)` bound; the word and 32-byte vector comparison sequence,
the window check and the match result are unchanged. Dictionary and history
inputs keep the original virtual-span path.

## Measurement

- Host Intel i7-10700K, Linux 6.8, Zig 0.16.0 ReleaseFast, `skylake+pku+sgx`,
  single thread.
- `run-zstd-encode-bench`, level 3, one-shot, twelve 128 KiB Silesia prefixes,
  `--iterations 50 --rounds 3`, interleaved with libzstd 1.6.0.
- A/B: revert the patch, rebuild, measure `before`; re-apply, rebuild, measure
  `after`.

| case | before MiB/s | after MiB/s | speed ratio | bytes |
| --- | ---: | ---: | ---: | ---: |
| dickens | 13.37 | 14.58 | 1.0904 | 51,971 |
| mozilla | 42.66 | 45.14 | 1.0581 | 20,112 |
| mr | 16.86 | 18.17 | 1.0778 | 32,663 |
| nci | 47.55 | 49.40 | 1.0390 | 11,033 |
| ooffice | 16.69 | 18.08 | 1.0836 | 68,503 |
| osdb | 24.75 | 26.31 | 1.0629 | 51,095 |
| reymont | 16.05 | 17.27 | 1.0756 | 39,168 |
| samba | 21.84 | 23.09 | 1.0576 | 48,697 |
| sao | 14.32 | 15.29 | 1.0677 | 99,490 |
| webster | 17.59 | 18.58 | 1.0565 | 43,073 |
| xml | 58.17 | 60.71 | 1.0436 | 10,748 |
| x-ray | 14.15 | 15.11 | 1.0680 | 93,086 |

Geometric-mean speed **1.065x**; every output is byte-identical. The weakest
row is nci at +3.9%, above the 0.98x control floor. Level 1 keeps its
59,878-byte wire and its speed is within noise (the compact parser does not use
this path); level 9 keeps its 50,404-byte wire.

## Verification

`zig build test-zstd` is the focused gate; golden level wires and the
dictionary/history virtual-span contracts must stay byte-exact. The fast path
only triggers when `source.dictionary.len == 0 and source.history.len == 0`, so
dictionary, prefix and large-history encoders continue to exercise the
original code.
