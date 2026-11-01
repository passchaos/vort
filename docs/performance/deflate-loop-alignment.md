# Deflate semantic loop: 64-byte entry alignment

## Hypothesis

Layout changes have measured effects in this loop: the branch-hint experiment
moved the 48-row screen by about 1%, and the earlier live-range work changed
which values spill. The generic semantic loop entry
(`decodeSemanticDynamicBlockIntoBufferedReader`) had no alignment attribute,
while the Zstd dense sequence loop is already `align(64)`. Aligning the
Deflate hot loop to a 64-byte boundary keeps its first instructions in a single
fetch window and avoids a straddling first cache line.

## Experiment

```zig
noinline fn decodeSemanticDynamicBlockIntoBufferedReader(
    noalias reader: *bitstream.BufferedBitReader,
    ...
) align(64) Error!usize {
```

The symbol address moves to `0x10f8b00`, which is 64-byte aligned.

## Result

Two independent four-sweep 48-row screens compare the committed decoder
(`decode-litend`) with the aligned build (`decode-aln64`). Lower is faster.

| Run | L6 64 KiB | L6 1 MiB | L9 64 KiB | L9 1 MiB |
| --- | ---: | ---: | ---: | ---: |
| 1 | 0.9978 | 0.9992 | 0.9969 | 0.9951 |
| 2 | 0.9982 | 0.9964 | 0.9986 | 0.9957 |

Both runs improve every group; the geometric mean is about 0.997. The
standalone Deflate suite passes 581/581 and `zig build -j2 check` exits zero.

## Conclusion

The alignment is a free, uniform improvement. It is small in absolute terms
because the loop body is several kilobytes and only the entry is aligned, but
it is reproducible and costs nothing.

Raw comparison files, records and binaries stay local under
`/tmp/vort-decode-priority-20261031/` (`aln64-comparison.json`,
`aln64b-comparison.json`, `decode-aln64`, `decode-litend`).
