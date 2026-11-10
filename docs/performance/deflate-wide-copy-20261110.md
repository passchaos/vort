# Deflate inline wide non-overlap copies

## Context

After the 2026-11-09 matrix (0.9131 ref/Vort), a fresh profile of
`nci.64k` L6 put 37.3% of decode time in
`deflate.semantic.linear_entry.aligned` and another 7.5% in
`compiler_rt.memcpy.memcpyFast`. Annotating the payload showed the
runtime-length `memcpy` for non-overlapping matches longer than the
sixteen-byte overcopy tier: generic length dispatch plus call/return and
register spills around every such match.

## Change

`src/deflate/decoder/shortcopy.zig` gains `copyWide`: for a
non-overlapping match with `distance >= 16` it emits fixed sixteen-byte
unaligned vector moves in a bounded loop (at most 258 bytes) followed by
one overlapping tail store. The semantic linear loop enters the path
only when `distance >= 16` and the loop's 258-byte output headroom
guarantees every speculative byte is inside the output buffer, so no
runtime-length `memcpy` or bounds branching remains.

## Result

48-row three-round paired A/B (Silesia 64 KiB/1 MiB, zlib L6/L9 raw
frames, taskset CPU 15, per-row medians of best-of-five):

| Group | new/old time geomean |
| --- | ---: |
| L6 64 KiB | 0.9749 (-2.51%) |
| L6 1 MiB | 0.9947 (-0.53%) |
| L9 64 KiB | 0.9712 (-2.88%) |
| L9 1 MiB | 0.9945 (-0.55%) |
| all 48 rows | **0.9838 (-1.62%)** |

Bootstrap 95% interval over rows: `[-2.82%, -0.68%]`. Strongest rows:
`xml.64k` L6 -14.41%, `xml.64k` L9 -14.12%, `nci.64k` L9 -13.96%,
`nci.64k` L6 -10.19%; worst control `mr.64k` L9 +0.64%, every row above
the 0.98x floor. `zig test src/deflate.zig`: 670/670.

Raw rows: [deflate-widecopy.csv](data/deflate-wide-copy-20261110/deflate-widecopy.csv).
