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

## Rejected tuned tiny one-shot paths

Several <=32 KiB variants reduced the 16px fixed cost, including a 4096-bucket
stack planner, signed-16-bit positions, separately outlined tiny/full bodies,
and a single-body heap planner with a 4096-entry head. Token/reference and OOM
tests passed, and the 16px rows improved by roughly `1.6x...1.8x`.

None survived the large-image control. Direct and partially outlined variants
regressed several large rows by about `0.5%...1.7%`; the source-identical build
after public-error-set repair made the 128px rows `0.976412x` / `0.982147x`.
The final single-body small-head pilot still put Exoplanet near `0.994x` and
Lohengrin/Adaptive at a `0.988720x` paired median. These are code-generation
costs, not correctness failures. All tiny product changes are withdrawn and the
four-chain full-head implementation remains official.

## Verification

- all 148 ReleaseFast LZ77 tests;
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
`/nav_env/Temp/imx-png-level8-chain4-20261031/`. The committed imx evidence
retains the full per-row JSON, executable/source identities and reproduction
commands. Two 16px rows still trail Rust, so uniform per-case leadership and
broader formats, corpora and APIs remain open.
