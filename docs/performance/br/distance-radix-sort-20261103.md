# Radix sort for distance parameter frequencies, 2026-11-03

The q8 distance chooser collects one semantic-distance frequency per explicit
copy, then sorts and deduplicates them before scoring all 64 parameter shapes.
The perf profile attributed about 1.83% of the process to the comparison sort
inside `chooseDistanceParameterAlternativeAlloc`.

`sortDistanceFrequencies` now uses an LSD radix sort with 8-bit digits for
inputs of at least 128 entries; smaller inputs keep the comparison sort. The
result is the same ascending order used by the dedup pass, so parameter
selection and wire bytes are unchanged. The radix path allocates one temporary
`DistanceFrequency` buffer of `semantic_count` entries (16 bytes each) and
frees it immediately.

## Measurement

The six-file Silesia q8 screen uses the same settings as the
[full-file comparison](full-file-q8-20261103.md). Every wire length is
identical.

| Case | Wire bytes | Before ns | Radix ns | Time ratio |
| --- | ---: | ---: | ---: | ---: |
| dickens | 3,028,223 | 1,759,100,000 | 1,758,200,000 | 0.9995 |
| ooffice | 2,918,595 | 938,140,000 | 936,220,000 | 0.9979 |
| osdb | 2,741,829 | 771,390,000 | 771,220,000 | 0.9998 |
| sao | 5,002,015 | 1,322,460,000 | 1,318,400,000 | 0.9969 |
| xml | 639,005 | 293,890,000 | 292,430,000 | 0.9950 |
| x-ray | 5,327,621 | 1,826,410,000 | 1,817,310,000 | 0.9950 |

Geometric paired time ratio: **0.9974**, about **0.26% faster** q8 planned
encoding. All six files improve and sizes are unchanged. The gain is modest;
the temporary buffer raises peak requested heap for large command streams,
which this screen does not measure as RSS.

The distance filter passes 185/185 tests, parameter pair 24/24 and q8 35/35.
The complete ReleaseFast Brotli suite passes 1,533 tests with one existing
platform skip out of 1,534 and exit zero.

[Raw rows](distance-radix-20261103.csv) retain the paired timings and wire
equality.
