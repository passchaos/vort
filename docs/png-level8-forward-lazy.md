# Numeric DEFLATE level 8 uses bounded forward lazy parsing

Numeric zlib level 8 follows the same high-level parsing family as local
zlib-rs 0.6.8: a forward one-position lazy parser with a 32 KiB history,
good-match threshold 32, maximum lazy length 128 and nice length 258. A complete
corpus sweep bounds the active chain budget to four candidates. Named
`CompressionLevel.best` and numeric level 9 retain Vort's global optimal parser
and complete default/filtered arbitration.

The level-8 matcher uses the standard four-byte multiplicative hash with the
reference shift of 16. Inputs larger than 64 KiB retain only the live
power-of-two predecessor history. A good current match quarters only the
next-position probe budget; matches at least 128 bytes skip that probe. The
ordinary lazy modes keep their existing scan/hash policies and output.

One-shot, reusable and dictionary paths share the same tuning helper. The
incremental matcher applies the same probe floor and budget without changing
its persistent-history or reset ownership. Incremental output may differ from
one-shot output, as before.

## Complete PNG evidence

The ordinary imx PNG consumer was measured on fifteen original image-png
rasters with Adaptive and Up filtering, for 30 complete level-8 rows. Three
alternating process-CPU rounds were pinned to CPU 10. Every peer calibrated its
own iteration count, and output construction, encoding, ownership transfer and
free stayed inside the timed region.

| Metric | Previous 1024-chain forward | Four-chain forward | image-png/zlib-rs |
| --- | ---: | ---: | ---: |
| Aggregate throughput | 24.829 MiB/s | 97.744 MiB/s | 33.967 MiB/s |
| Complete PNG bytes | 36,217,269 | 37,272,867 | 37,442,939 |
| Largest requested heap peak | 76,903,445 | 77,247,343 | not measured by the Zig allocator |

The bounded chain improves all 30 rows over the previous forward parser. Its
geometric speedup is `3.098020x`, its aggregate speedup is `3.936697x`, and its
minimum is `1.062143x`. Against Rust it reaches `2.636772x` geometrically and
`2.877578x` in aggregate, with 28 of 30 rows faster.

The speed/ratio tradeoff remains explicit: total output grows `2.914626%`
against the 1024-chain forward baseline, but remains `0.454216%` smaller than
the Rust total. A sweep of chain budgets 1024, 512, 256, 128, 64, 32, 16, 8,
4 and 2 keeps total output below Rust through four; two grows to 37,654,088
bytes, `0.563922%` above Rust. Four is therefore the fastest measured point
that preserves the corpus-wide size lead. Numeric levels do not promise byte
stability or monotonic size.

All 90 complete baseline/candidate/Rust PNGs were decoded by both image-png and
libpng. All 180 observations reproduce the original dimensions, layout and
pixels. All candidate allocations are released. Larger encoded outputs make
requested heap rise `1.035425x` geometrically, with a `1.222858x` worst row;
the matrix maximum changes only from 76,903,445 to 77,247,343 bytes and stays
inside the 1 GiB runtime limit.

## Tuned tiny one-shot path

Tuned one-shot inputs through 32 KiB now use the existing 4096-bucket tiny
planner instead of allocating and clearing the 32768-bucket full table. Its
hash heads and predecessors use signed 16-bit positions: three- and four-byte
anchors can insert at most positions 32765 and 32764, preserving every value
plus the `-1` sentinel. An independent maximum-size `isize` planner matches
every token and statistic. The tiny and full implementations remain separately
outlined so the full-input match loop keeps its code shape.

On the 16px Adaptive/Up rows, complete encoding improves `1.802455x` and
`1.673778x` over the four-chain baseline, and reaches `1.518259x` and
`1.136720x` against Rust. Across all 30 rows, the incremental change is
`1.060719x` geometrically and `1.005833x` in aggregate, with a `0.991498x`
minimum. Candidate/Rust becomes `2.795128x` geometrically and `2.880994x` in
aggregate with 30/30 wins.

Complete output grows by only 22 bytes, from 37,272,867 to 37,272,889, and
remains below Rust's 37,442,939. Requested-heap peak falls on every row or stays
exact, reaching `0.726663x` geometrically. The 16px peak drops from 142,512 to
7,280 bytes and the 32px peak from 176,288 to 28,704 bytes; the matrix maximum
stays 77,247,343 bytes.

## Verification

- all 149 ReleaseFast LZ77 tests;
- 141 selected ReleaseFast DEFLATE best/optimal/dictionary/numeric and
  incremental tests;
- all tuned scalar/indexed/prefix tokens, full-table/ring tokens, dictionary
  replay, reusable ownership and allocation-failure points;
- imx bounded PNG encoding in Debug and ReleaseFast plus seven checkpoint
  policy tests;
- 32-bit x86 and big-endian PowerPC64 ReleaseSafe test compilation;
- the complete 30-row CPU, size, requested-memory and dual-decoder matrix under
  a 1 GiB address-space cap.

Frozen binaries and complete PNGs remain under
`/nav_env/Temp/imx-png-level8-tiny-split-20261031/`. The committed imx evidence
retains the full per-row JSON, executable/source identities and reproduction
commands. This matrix now has 30/30 speed wins over Rust and a smaller aggregate
output, but broader formats, corpora and APIs remain open.
