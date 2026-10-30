# Numeric DEFLATE level 9 uses bounded forward lazy parsing

Numeric zlib level 9 now uses the same forward one-position lazy architecture
as numeric level 8, with a four-candidate main chain, 32 KiB history,
good-match threshold 32, maximum lazy length 258 and nice length 258. Named
`CompressionLevel.best` remains the global optimal parser with complete
default/filtered arbitration, preserving an explicit compression-priority API.

The local architecture and speed/size reference is image-png backed by
flate2/zlib-rs 0.6.8. Vort does not claim Rust wire identity. Incremental level
9 uses the same tuned search bounds while retaining persistent history,
dictionary handling and reset determinism.

## Chain boundary

The complete 30-row corpus emits 36,213,317 bytes with a 1024-candidate forward
chain, 37,272,736 bytes with four candidates and 37,654,031 bytes with two.
Pinned image-png/zlib-rs emits 37,444,262 bytes. Four is the fastest measured
point that keeps the corpus total smaller than Rust (`0.995419x`); two crosses
the boundary (`1.005602x`). The old global-optimal numeric level 9 emits
35,320,334 bytes, so this is an explicit speed/ratio tradeoff rather than a
compression-size improvement.

## Complete PNG evidence

Fifteen original image-png rasters, Adaptive and Up filtering, contribute 30
complete level-9 rows. Baseline, candidate and Rust produce 90 PNGs. image-png
and libpng independently decode every file; all 180 observations reproduce the
original dimensions, layout and pixels. All candidate allocations are released.

| Metric | Previous numeric-9 optimal | Four-chain forward | image-png/zlib-rs |
| --- | ---: | ---: | ---: |
| Aggregate throughput | 3.606 MiB/s | 97.218 MiB/s | 21.188 MiB/s |
| Complete PNG bytes | 35,320,334 | 37,272,736 | 37,444,262 |
| Largest requested heap peak | 91,161,494 | 77,247,343 | outside Zig allocator |

Three alternating CPU-10 rounds improve every native row: `23.689024x`
geometric, `26.957716x` aggregate and `2.675008x` minimum. Candidate/Rust is
`3.892176x` geometrically and `4.588261x` in aggregate, with 28/30 wins. The
two remaining Rust deficits are the 16px Adaptive and Up controls.

Requested heap falls to `0.580439x` geometrically. One 32px Adaptive row grows
`1.012928x` in requested peak, while the matrix maximum drops by about
13.9 MiB. Allocation count and total requested bytes fall on every row.

## Verification

- all 148 ReleaseFast LZ77 tests;
- 141 selected ReleaseFast DEFLATE best/optimal/dictionary/numeric and
  incremental tests;
- tuned incremental levels 8/9 cover dictionary history, short tails, block
  sizes 1/3/17/128/259/1024 and reset identity;
- imx bounded PNG encoding passes 87/87 in Debug and ReleaseFast;
- seven checkpoint policy tests;
- 32-bit x86 and big-endian PowerPC64 ReleaseSafe numeric-level compilation;
- 30 complete rows and 180 independent decodes within a 1 GiB runtime cap.

Frozen binaries and complete outputs remain under
`/nav_env/Temp/imx-png-level9-forward4-20261031/`. The matching imx evidence
retains every CPU sample, size/resource record, source identity and reproduction
command. This establishes corpus aggregate/geometric speed and total-size
leadership, not uniform per-case or format-wide leadership.
