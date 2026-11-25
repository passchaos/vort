# Deflate hash3/hash4 parser screen, 2026-11-20

## Decision

Neither hash3/hash4 variant replaces the default lazy parser. Both were
reverted: the full variant is speed-neutral overall with double-digit
regressions on structured inputs, and the skip-interior variant reaches
1.0416x but breaches the 0.98x control floor and the x-ray ratio budget.

## Motivation

The level-6 profile puts about 30% of Vort encode time on the `prev[...]`
chain load, and libdeflate's HC matchfinder instead keeps a chainless 3-byte
table plus a 4-byte hash chain. Both variants below replace the lazy parser's
single 3-byte chain with a chainless 3-byte slot (`head3`) plus a 4-byte hash
chain (`head4`), so the chain contains only true 4-byte candidates.

## Variant A: full insertion, 15/16 tables

Twelve 128 KiB level-6 prefixes, `--iterations 50 --rounds 3`, old/new
binaries alternating per file:

- Geometric-mean speed **1.0034x**, size **-0.61%** (570,101 vs 572,151
  bytes; libdeflate 1.10 total 565,588).
- Wins: dickens 1.226x/-0.65%, webster 1.101x/-0.39%, reymont 1.074x/-1.18%,
  ooffice 1.060x/-0.11%.
- Losses: xml 0.864x, nci 0.933x, mr 0.934x, mozilla 0.944x, sao 0.962x,
  x-ray 0.983x.

A four-file width screen (dickens/xml/nci/mozilla) measured 13/15 tables at
1.347/0.877/0.990/0.971 and 13/16 at 1.316/0.901/0.969/0.938, so smaller
tables do not remove the structured-input regression.

## Variant B: skip hash3 insertion inside matches, 13/15 tables

Skipping the `head3` update for positions consumed inside an accepted match
recovers the structured-input speed:

- Geometric-mean speed **1.0416x**, size **+0.12%** (575,356 bytes).
- Rows: dickens 1.259x/-0.21%, webster 1.135x/+0.20%, ooffice 1.076x/+0.84%,
  x-ray 1.073x/+3.25%; mr 0.958x, sao 0.957x, xml 0.964x.
- Fails the 0.98x control floor on mr/sao and the x-ray ratio budget, so it
  cannot replace the default.

## Interpretation

The 4-byte chain is a large win where 3-byte hash chains are deep (text) and
a loss where insertion and the extra table load dominate (structured or
high-entropy inputs). A future attempt would need a content-adaptive parser
choice or a chain-node tag that preserves the existing budget accounting; a
plain parser swap is not adoptable.

## Measurement

- Host Intel i7-10700K, Linux 6.8, Zig 0.16.0 ReleaseFast, `skylake+pku+sgx`,
  single thread.
- `run-deflate-encode-bench`, level 6, one-shot, twelve 128 KiB Silesia
  prefixes, zlib 1.2.11 and libdeflate 1.10 references. Old and new binaries
  ran sequentially per file in one session.

## Raw data

`full-15-16-before.csv` / `full-15-16-after.csv` and
`skip-13-15-before.csv` / `skip-13-15-after.csv` (schema of
`run-deflate-encode-bench`).
