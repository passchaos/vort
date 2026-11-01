# Brotli prefix length tail zeroing

## Hypothesis

The one-shot 64 KiB Brotli profile attributes 1.41% of total time to a `memset`
inside `readMinimalCompressedHeaderInto`. The complex prefix parser initializes
`lengths: [max_alphabet_size]u4 = @splat(0)` before its RLE loop, even though
the loop writes every position up to `index`; only the unwritten tail can still
need zeros when the Huffman space is exhausted early.

## Experiment

Both the ordinary and profiled complex parsers now leave `lengths` undefined
and zero only `lengths[index..alphabet_size]` after the final pending-repeat
flush. `initSparseTrustedInto` reads only the active symbols, so the tail beyond
`alphabet_size` stays untouched.

## Result

Two independent four-sweep screens over the 48 Brotli 64 KiB/1 MiB rows compare
the committed binary (`decode-final`, SHA-256
`87ae6891096d2d35fbabb2afdb325a48ec650816a6e20400d29721727594c984`) with the
candidate (`decode-lentail`, SHA-256
`489066b59dd85f756ae86e426399f8f1bb28171899006655b35bbf6e45909e6e`).

| Run | q6 64 KiB | q6 1 MiB | q11 64 KiB | q11 1 MiB |
| --- | ---: | ---: | ---: | ---: |
| 1 | 0.9942 | 1.0016 | 0.9962 | 1.0031 |
| 2 | 0.9961 | 1.0011 | 0.9954 | 1.0010 |

Lower is faster. The 64 KiB rows improve about 0.4–0.6%, but 1 MiB is neutral to
slightly slower. A 24-row two-sweep full-file screen gives `1.0005` for q6 and
`1.0037` for q11. The median ratio is `0.9979` across the 64 KiB/1 MiB rows and
`1.0022` across the full rows. The largest regressions are
`dickens.1m.q6 1.023`, `xml.full.q6 1.037` and `dickens.1m.q11 1.020`; the
largest gains are `xml.64k.q6 0.981` and `xml.64k.q11 0.986`.

## Conclusion

The change was reverted. The 64 KiB gain does not survive the full-file rows,
and the overall effect is a wash dominated by code layout rather than the
removed clear. The header cost is not worth another structural attempt without
a stronger attribution.

Raw comparison, records and binaries stay local under
`/tmp/vort-br-lookup-20261101/` (`oneshot-lentail-comparison.json`,
`oneshot-lentail-1.json`, `oneshot-lentail-full-comparison.json`,
`decode-lentail`, `decode-final`).
