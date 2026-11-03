# Table-driven literal context lookup, 2026-11-03

Hot encoder loops used `literal_context.value`, whose UTF-8 and signed modes
branch on character ranges. `literal_context.valueClustered` already provides
the table-driven equivalent used by the incremental payload loop; its tables
are precomputed from the same `utf8LastByte`, `utf8SecondLastByte` and
`signedBucket` functions.

The HQ parser literal pricing, prepared literal emission, prepared adaptive
distance emission, context-split scoring, joint context split, literal block
split and command-plan paths now use `valueClustered`. The change preserves
the exact context values and leaves test oracles and analysis-only call sites
unchanged.

## Measurement

The same six-file Silesia q8 screen as the
[full-file comparison](full-file-q8-20261103.md) runs before and after the
change: quality 8, generic mode, actual window 16, inputs truncated to 8 MiB,
one encode per file. Every wire length is identical; the table lists the
paired encode-time ratio.

| Case | Wire bytes | Before ns | After ns | Time ratio |
| --- | ---: | ---: | ---: | ---: |
| dickens | 3,028,223 | 1,860,060,000 | 1,759,100,000 | 0.9457 |
| ooffice | 2,918,595 | 1,009,880,000 | 938,140,000 | 0.9290 |
| osdb | 2,741,829 | 838,940,000 | 771,390,000 | 0.9195 |
| sao | 5,002,015 | 1,433,680,000 | 1,322,460,000 | 0.9224 |
| xml | 639,005 | 318,740,000 | 293,890,000 | 0.9220 |
| x-ray | 5,327,621 | 1,926,840,000 | 1,826,410,000 | 0.9479 |

Geometric paired time ratio: **0.9310**, about **7.4% faster** q8 planned
encoding. All six files improve, and compressed sizes are unchanged. The
context-filtered tests pass 163/163 and the q8 filter 35/35 in Debug; the
complete ReleaseFast Brotli suite passes 1,533 tests with one existing
platform skip out of 1,534 and exit zero.

This is a single-encode screen on the q8 planned path, not a full-file,
memory/RSS or multi-platform ranking. [Raw rows](context-lookup-20261103.csv)
retain the paired timings and wire equality.
