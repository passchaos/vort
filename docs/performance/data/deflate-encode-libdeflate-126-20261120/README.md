# Deflate level-6 encode against libdeflate 1.26, 2026-11-20

## Purpose

The earlier deflate encode baseline used the system libdeflate 1.10, while
the decode evidence uses the locally built 1.26. The encode bench now accepts
`-Ddeflate-reference-dir` (library directory, added to the link path and
RUNPATH) and `-Ddeflate-reference-include` (matching `libdeflate.h` so
`LIBDEFLATE_VERSION_STRING` reports the loaded version). This package records
the current source (chain-64 default + chain-node early load) against
libdeflate 1.26.

## Measurement

- Host Intel i7-10700K, Linux 6.8, Zig 0.16.0 ReleaseFast, `skylake+pku+sgx`,
  single thread.
- `run-deflate-encode-bench`, level 6, raw Deflate, twelve 128 KiB Silesia
  prefixes, `--iterations 3 --rounds 5`, rotating encoder order.
- Reference: libdeflate 1.26 (`~/Work/libdeflate/build-vort`), zlib 1.2.11.
- Command shape:
  `zig build run-deflate-encode-bench -Ddeflate-reference-dir=<build-vort> -Ddeflate-reference-include=<libdeflate> -- --input <file> --level 6 --iterations 3 --rounds 5`

| case | vort MiB/s | libdeflate 1.26 MiB/s | ratio | vort bytes | libdeflate bytes | size delta |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| dickens | 23.13 | 82.43 | 0.281 | 50,996 | 50,679 | +0.6% |
| mozilla | 85.18 | 185.05 | 0.460 | 23,159 | 22,873 | +1.3% |
| mr | 23.01 | 92.48 | 0.249 | 33,563 | 32,101 | +4.6% |
| nci | 95.51 | 221.56 | 0.431 | 11,174 | 11,047 | +1.1% |
| ooffice | 29.45 | 89.38 | 0.329 | 68,263 | 68,034 | +0.3% |
| osdb | 47.80 | 119.24 | 0.401 | 51,770 | 51,265 | +1.0% |
| reymont | 25.68 | 92.21 | 0.278 | 37,453 | 37,163 | +0.8% |
| samba | 38.31 | 110.92 | 0.345 | 49,546 | 46,159 | +7.3% |
| sao | 26.23 | 82.51 | 0.318 | 99,460 | 99,568 | -0.1% |
| webster | 34.19 | 104.52 | 0.327 | 42,288 | 41,835 | +1.1% |
| xml | 123.99 | 249.45 | 0.497 | 10,233 | 10,411 | -1.7% |
| x-ray | 32.67 | 98.39 | 0.332 | 94,246 | 94,453 | -0.2% |

Geometric-mean speed ratio **0.3467x** against libdeflate 1.26, versus
**0.3756x** against the system 1.10; 1.26 is about 8% faster overall. Vort is
smaller on sao, xml and x-ray, and larger on the other nine rows (worst samba
+7.3%, mr +4.6%).

## Scope limits

One host, one-shot raw Deflate, 128 KiB prefixes, min-of-five interleaved
rounds. The bench links the requested library and loads it through RUNPATH;
the version string comes from the matching header, not from a runtime query
(libdeflate exposes the version only as a compile-time macro).
