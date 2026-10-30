# Numeric DEFLATE level 8 uses bounded forward lazy parsing

Numeric zlib level 8 now follows the same high-level parsing family as local
zlib-rs 0.6.8: a forward one-position lazy parser with a 32 KiB history,
1024-entry chain budget, good-match threshold 32, maximum lazy length 128 and
nice length 258. Named `CompressionLevel.best` and numeric level 9 retain
Vort's global optimal parser and complete default/filtered arbitration.

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

| Metric | Current optimal | Forward lazy | image-png/zlib-rs |
| --- | ---: | ---: | ---: |
| Aggregate throughput | 3.684 MiB/s | 24.807 MiB/s | 33.939 MiB/s |
| Complete PNG bytes | 35,318,177 | 36,217,269 | 37,442,939 |
| Largest requested heap peak | 91,228,195 | 76,903,445 | not measured by the Zig allocator |

Forward lazy improves all 30 rows. Its geometric speedup is `7.514707x`, its
aggregate speedup is `6.733136x`, and its minimum is `2.530084x`. Against the
Rust peer it reaches `0.851037x` geometrically and `0.730929x` in aggregate,
with 11 of 30 rows faster.

The speed/ratio tradeoff remains explicit: total output grows `2.545692%`
against Vort's global optimal baseline, but remains `3.273434%` smaller than
the Rust total. Twenty-seven rows grow, three shrink, and individual size
ratios span `0.989585x...1.259671x`. Numeric levels do not promise byte
stability or monotonic size.

All 90 complete baseline/candidate/Rust PNGs were decoded by both image-png and
libpng. All 180 observations reproduce the original dimensions, layout and
pixels. All candidate allocations are released. Allocation counts and total
requested bytes fall on every row; requested-heap peak falls geometrically to
`0.560460x`. One 32px Adaptive row increases by 2,250 bytes (`1.012928x`),
while the maximum peak across the matrix drops by about 14.3 MiB.

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
`/nav_env/Temp/imx-png-level8-forward-20261030/`. The committed imx evidence
retains the full per-row JSON, executable/source identities and reproduction
commands. Level 8 still trails zlib-rs on 19 of 30 rows, particularly photos
and Lohengrin, so broader throughput leadership remains open.
