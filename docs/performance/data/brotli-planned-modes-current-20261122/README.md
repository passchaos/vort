# Brotli planned planner modes versus libbrotli q9/q11, 2026-11-22

## Method

- Host Intel i7-10700K, Linux 6.8, Zig 0.16.0 ReleaseFast, single thread;
  system libbrotli **1.0.9** as the reference.
- `run-br-planned-encode-bench`, 64 KiB Silesia prefixes, three iterations at
  reference q9 and one at q11.
- Mode semantics: `vort` is the reusable legacy fast path because no planned
  quality is set; `lazy` is `.level = .balanced`; `ratio` is `.level = .ratio`.
  The `--quality` flag selects the **libbrotli reference** quality, not a Vort
  preset. The q9 row is the meaningful equal-quality comparison; the q11 row
  compares a fixed Vort ratio planner against a much stronger reference.

## Result (q9 reference)

| mode | speed vs reference | size vs reference |
| --- | ---: | ---: |
| legacy fast | 4.3613x | 1.1276x |
| balanced | 3.2847x | 1.0660x |
| ratio | **0.3331x** | **0.9995x** |

The ratio planner matches libbrotli q9 size at one third of its throughput.
Weak rows: `nci` 0.0880x speed / 1.0532x size, `xml` 0.1496x / 1.0224x,
`mr` 0.1555x / 1.0367x, `reymont` 0.3157x / 0.9690x. Structured text is where
the ratio search spends the most time for the least size benefit.

## Result (q11 reference)

The same fixed ratio planner is 3.3185x faster than libbrotli q11 but 1.1281x
larger; this is not a quality-equivalent row and is retained only to show the
tradeoff. Weak rows by speed are `mr` 1.9512x, `nci` 2.3034x, `mozilla`
2.4790x and `reymont` 2.5490x, all still faster than the q11 reference.

## Raw data

`q9-<case>.csv` and `q11-<case>.csv` for the twelve Silesia 64 KiB prefixes
(schema of `run-br-planned-encode-bench`).
