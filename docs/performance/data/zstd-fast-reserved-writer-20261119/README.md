# Zstd level-1 fast sequence writer reservation, 2026-11-19

## Change

The fast large-sequence emitter called `ReverseBitstreamWriter.addBits` four
times per sequence. Every call flushed full bytes and rechecked output capacity
through `ensureUnusedCapacity`, and the 128 KiB level-1 profile attributed
5.4% of encode cycles to `addBits` plus 1.6% to the array-list capacity check.
The emitter now reserves 16 bytes per sequence plus one spare word (the
worst-case per-sequence fields stay below 90 bits, plus three initial states
and the stop bit) and writes through `addBitsReserved`, which flushes only when
the next field cannot fit in the 64-bit accumulator. The three initial states
and the stop byte still use the checked writer after a full-byte flush. A
differential unit test pins both writers to identical bytes, including a
full-word field and the switch back to the checked path.

## Measurement

- Host: Intel i7-10700K, 16 logical CPUs, Linux 6.8, single thread.
- Build: Zig 0.16.0 ReleaseFast, `x86_64-linux-gnu`, `skylake+pku+sgx`.
- Corpus: twelve 128 KiB Silesia prefixes.
- API: `zig build run-zstd-encode-bench`, level 1, one-shot, interleaved
  Vort-first/reference-first rounds (`--iterations 1 --rounds 5`).
- Reference: libzstd 1.6.0 (`~/Work/zstd`).

| case | before bytes | after bytes | before MiB/s | after MiB/s | speed ratio |
| --- | ---: | ---: | ---: | ---: | ---: |
| dickens | 59,878 | 59,878 | 74.28 | 79.21 | 1.0664 |
| mozilla | 24,399 | 24,399 | 151.68 | 160.90 | 1.0608 |
| mr | 36,827 | 36,827 | 69.22 | 74.75 | 1.0799 |
| nci | 11,491 | 11,491 | 196.75 | 210.23 | 1.0685 |
| ooffice | 76,442 | 76,442 | 85.93 | 88.09 | 1.0252 |
| osdb | 61,098 | 61,098 | 113.52 | 118.27 | 1.0418 |
| reymont | 43,617 | 43,617 | 70.15 | 75.12 | 1.0708 |
| samba | 54,011 | 54,011 | 93.72 | 102.47 | 1.0933 |
| sao | 114,461 | 114,461 | 96.99 | 103.71 | 1.0693 |
| webster | 48,838 | 48,838 | 84.45 | 92.72 | 1.0980 |
| xml | 12,323 | 12,323 | 224.95 | 248.86 | 1.1063 |
| x-ray | 107,218 | 107,218 | 121.14 | 124.73 | 1.0297 |

Geometric-mean speed ratio **1.0672x**; all twelve output sizes are
byte-identical to the previous source. The weakest row is +2.5%, above the
0.98x control floor.

## Screen not adopted

A deferred predefined-table viability walk priced the alternative from the
code stream and ran the DP only when selection actually chose it. Literal and
match codes include predefined states with mixed transition widths (LL 1,
LL 17, ML 2), so only the offset kind could be deferred; writer-only measured
1.0760x geometric mean versus 1.0752x with the deferral, i.e. no gain. The
deferral was removed and only the writer change is kept.

## Correctness

The reserved writer can hold a complete 64-bit accumulator. The first version
switched back to the checked writer without flushing full bytes, which
corrupted the xml frame (libzstd rejected it as invalid); the fixed path flushes
before the initial-state writes. `test-zstd` covers the golden wires plus the
new writer differential test.
