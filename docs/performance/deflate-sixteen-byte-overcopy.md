# Deflate sixteen-byte overcopy

## Hypothesis

A call-graph profile of `dickens.1m.rawdeflate.9` on the committed one-shot
decoder attributes 84.55% to the non-overlap semantic loop and 17.05% to
`compiler_rt.memcpy.memcpyFast`, including about 2.3% at the call instruction
itself plus the surrounding register spills. The full-output specialization
enters its loop only while at least 262 output bytes remain, so a 16-byte
load/store can replace the runtime-length memcpy for short matches without any
extra bounds check.

## Experiment

For non-overlapping matches with `length <= 16` and `distance >= 16`, copy one
unaligned 16-byte vector instead of calling memcpy. The extra bytes land beyond
the current `out_pos` inside the guaranteed headroom and are overwritten by
later tokens before they can be read as history; `distance >= 16` keeps the
source load entirely inside decoded history.

## Result

The 384-process four-sweep screen over the 48 raw Deflate 64 KiB/1 MiB rows
compares the committed binary (`decode-final`, SHA-256
`87ae6891096d2d35fbabb2afdb325a48ec650816a6e20400d29721727594c984`) with the
candidate (`decode-def16`, SHA-256
`7e75154de3db0a5fe81aa103c7b409ee13e4ac50594fafa8b7beb64032e11a44`).

| Scope | Level 6 | Level 9 |
| --- | ---: | ---: |
| 64 KiB | 0.9902 | 0.9944 |
| 1 MiB | 0.9896 | 0.9923 |
| full | 0.9953 | 0.9897 |

Lower is faster. The full rows use a separate 24-row two-sweep screen. The
largest gains are `dickens.64k.l6 0.948`, `webster.64k.l9 0.959`,
`dickens.1m.l9 0.962` and `dickens.1m.l6 0.962`; the worst row is
`dickens.64k.l9 1.007`. Every group improves, and the full-file level-9 group
improves about 1%.

Two wider variants were rejected. Adding a 32-byte branch for
`length <= 32 and distance >= 32` moved the 64 KiB/1 MiB screen to
`1.0063/0.9998/1.0086/1.0013`; adding an 8-byte branch before the 16-byte path
moved it to `1.0083/1.0119/1.0049/1.0150`. The standalone Deflate suite passes
581/581 tests.

## Conclusion

The 16-byte overcopy is adopted. It removes the memcpy call for the dominant
short non-overlap match class while leaving longer matches on the existing
ERMS path.

Raw comparison, records and binaries stay local under
`/tmp/vort-br-lookup-20261101/` (`oneshot-def16-comparison.json`,
`oneshot-def16-full-comparison.json`, `decode-def16`, `decode-final`).
