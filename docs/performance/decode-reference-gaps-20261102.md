# Decode reference gaps, 2026-11-02

This epoch refreshes the decode comparison after the incremental Deflate
symbol-path work. One-shot code is unchanged since the 2026-11-01 epoch; the
new rows are the streaming Deflate comparison against classic zlib and a
per-source one-shot table against the pinned references.

## Protocol

All runs are pinned to logical CPU2, built with Zig 0.16.0 ReleaseFast,
`-target x86_64-linux-gnu -mcpu=skylake+pku+sgx` (our code) or
`gcc -O3 -march=skylake` (reference C harnesses). Inputs are the twelve
Silesia sources at 1 MiB, raw Deflate level 9 and Zstd level 3. Each process
times 300-400 warmed decode calls; file loading, output verification and
guards stay outside the interval. References:

- libdeflate 1.26 (git `92e6a0db9fa848d742f9eb286c92afc60f2c3dda`), pinned
  shared build under `/tmp/vort-decode-priority-20261031/reference/libdeflate-build`;
- libzstd 1.6.0, pinned `libzstd.so.1.6.0` under the same reference directory;
- zlib 1.2.11 (system), raw `inflate` with a 32 KiB window.

## One-shot Deflate vs libdeflate 1.26

| Source | libdeflate ns | vort ns | vort / libdeflate |
| --- | ---: | ---: | ---: |
| dickens | 862,125 | 1,252,359 | 1.453 |
| mozilla | 1,101,782 | 1,422,299 | 1.291 |
| mr | 736,245 | 1,088,597 | 1.479 |
| nci | 301,176 | 392,681 | 1.304 |
| ooffice | 1,467,405 | 2,121,694 | 1.446 |
| osdb | 720,053 | 1,059,822 | 1.472 |
| reymont | 672,098 | 1,030,587 | 1.533 |
| samba | 689,259 | 997,495 | 1.447 |
| sao | 1,489,125 | 2,049,247 | 1.376 |
| x-ray | 1,528,287 | 2,180,959 | 1.427 |
| xml | 381,000 | 570,462 | 1.497 |

The one-shot gap is 1.29-1.53x (mean about 1.44x). It is smallest on mozilla
and nci and largest on reymont, xml and mr. The profile of the one-shot loop
is dominated by the 16-byte short-match overcopy (about 10% of instructions),
the 56-bit reservoir refill (about 18%), and the four-entry literal
speculation. These are already the libdeflate-style techniques, so the
remaining gap is in constant factors and table layout rather than a missing
algorithm.

## One-shot Zstd vs libzstd 1.6.0

| Source | libzstd ns | vort ns | vort / libzstd |
| --- | ---: | ---: | ---: |
| dickens | 853,130 | 1,186,964 | 1.391 |
| mozilla | 249,824 | 519,330 | 2.079 |
| mr | 732,725 | 1,097,280 | 1.498 |
| nci | 420,040 | 545,609 | 1.299 |
| ooffice | 932,097 | 1,348,276 | 1.446 |
| osdb | 585,199 | 876,763 | 1.498 |
| reymont | 754,469 | 1,036,861 | 1.374 |
| samba | 548,451 | 836,599 | 1.525 |
| sao | 960,882 | 1,574,409 | 1.639 |
| x-ray | 1,000,341 | 1,519,355 | 1.519 |
| xml | 461,312 | 662,885 | 1.437 |

The Zstd gap is 1.30-2.08x (mean about 1.50x). Mozilla is the outlier at
2.08x. Its profile is dominated by the FSE sequence loop (about 45%), the
per-block sequence-mode parse and FSE table build (about 11-19%), and a large
`memset` (about 8-14%) that comes from RLE literal/block fills. libzstd
executes 1.77x fewer instructions on this row, so the gap is both algorithmic
constants and per-block setup.

## Streaming Deflate vs classic zlib 1.2.11

| Source | zlib ns | vort incremental ns | vort / zlib |
| --- | ---: | ---: | ---: |
| dickens | 3,108,319 | 2,789,259 | 0.897 |
| mozilla | 2,066,962 | 2,389,905 | 1.156 |
| mr | 2,439,679 | 2,628,262 | 1.077 |
| nci | 1,048,576 | 883,027 | 0.842 |
| ooffice | 4,358,884 | 4,161,276 | 0.955 |
| osdb | 2,566,336 | 2,133,365 | 0.831 |
| reymont | 2,561,791 | 2,281,793 | 0.891 |
| samba | 2,034,156 | 1,987,068 | 0.977 |
| sao | 3,499,061 | 3,747,132 | 1.071 |
| x-ray | 4,441,307 | 4,750,621 | 1.070 |
| xml | 1,369,451 | 1,178,895 | 0.861 |

The incremental decoder is faster than classic zlib on seven of eleven
sources, about even on samba, and still 1.07-1.16x slower on mozilla, mr, sao
and x-ray. Against the one-shot decoder it is 2.15x slower at 64 KiB and
2.24x at 1 MiB on Dickens. zlib-ng, not classic zlib, is the streaming
industry bar; this table only establishes that the classic baseline is now
matched or beaten on most text-like sources.

## Next steps

1. Streaming Deflate: the windowed semantic path is the remaining 2.2x lever
   against one-shot; it needs a shared semantic decoder and a caller scratch
   of at least two 32 KiB windows.
2. Zstd: mozilla's 2.08x gap points at per-block FSE table construction and
   RLE fills; a faster table builder and avoiding redundant clears are the
   first candidates.
3. One-shot Deflate: the remaining 1.44x needs constant-factor work in the
   reservoir refill and 16-byte overcopy rather than new algorithms.
4. Brotli: 1 MiB is already within 1.12-1.14x; the 64 KiB fixed setup cost is
   the main remaining Brotli item.
