# Brotli one-shot command and distance lookup

After the literal fallback increment, a one-shot profile still attributed
`readCommandSymbol` and `readMinimalDistance` to the canonical scalar scan. The
standard fallback loops resolved command symbols through `tree.decode` and
distance symbols through the same scan whenever the tail-lookup preparation was
unavailable.

## Change

The standard command reader now uses `decodePrepared` and returns a mutable tree
pointer; the two distance fallback readers and their tail-lookup `else` branches
also use `decodePrepared`. The standard header parser already clears prepared
flags after each parse, so undefined headers cannot publish stale readiness.
Long codes keep the canonical fallback after the same zero-padded peek.

## Measurement

A paired 384-process four-sweep screen against the literal-fallback build gives:

| Producer quality / scope | Command+distance lookup / previous |
| --- | ---: |
| q6 / 64 KiB | 0.8942 |
| q6 / 1 MiB | 0.9976 |
| q11 / 64 KiB | 0.9140 |
| q11 / 1 MiB | 1.0047 |

All 48 rows reduce to `0.9514`; the four sweeps independently give
`0.9561/0.9506/0.9497/0.9515`. The best row is MR 64 KiB q6 at `0.670`; the
worst is OSDB 64 KiB q6 at `1.018`. The 1 MiB point estimates are neutral, so
the gain is specific to small frames that use the fallback loops.

Cumulatively with the literal fallback, the 48-row one-shot set is about 10%
faster than before the two fallback increments, and the 64 KiB groups are about
19% faster.

The follow-up 1,296-process industry epoch gives Brotli current/reference:

| Producer / scope | Before command+distance | After |
| --- | ---: | ---: |
| q6 / 64 KiB | 1.7448 | 1.5342 |
| q6 / 1 MiB | 1.1535 | 1.1595 |
| q6 / full | 1.4445 | 1.2693 |
| q11 / 64 KiB | 1.5542 | 1.3822 |
| q11 / 1 MiB | 1.1272 | 1.1546 |
| q11 / full | 1.3900 | 1.2665 |

Brotli now has the smallest remaining gap among the three codecs at 1 MiB and
full; raw Deflate is the largest at about 1.67–1.83x.

## Validation

The complete ReleaseFast Brotli suite passes 1504/1505 with one 32-bit-specific
skip and zero failures.

## Next work

Raw Deflate's semantic dynamic block loop remains the largest three-codec gap,
followed by the Zstd sequence decode. Brotli's remaining 64 KiB gap is about
1.38–1.53x; per-call setup and the external literal loop are the next candidates.
