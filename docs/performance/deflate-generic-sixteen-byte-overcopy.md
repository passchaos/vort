# Deflate generic-loop sixteen-byte overcopy

## Hypothesis

The 64 KiB raw Deflate level-9 profile puts 94.5% of samples in
`decodeSemanticDynamicBlockIntoBufferedReader`, the generic semantic loop used
for blocks that do not qualify for the non-overlap inline specialization. Its
short non-overlapping matches go through `shortcopy.copy`'s width dispatch.
The full-output inline loop already benefits from a single 16-byte move for
`length <= 16` and `distance >= 16`; the generic loop can use the same move
whenever the destination has a complete 16-byte window.

## Experiment

The generic non-overlap branch now takes one unaligned 16-byte load/store when
`length <= 16`, `distance >= 16` and `out_pos + 16 <= output.len`; all other
matches keep `shortcopy.copy`. The explicit window check is required: the
generic loop batches literal entries before a match, so `out_pos` can already
have advanced past the loop-entry headroom check. A first version without that
check passed the screen but failed the harness guard contract on
`ooffice.64k.l6`; the guarded form is the adopted one.

## Result

Two four-sweep screens over the 48 raw Deflate 64 KiB/1 MiB rows compare the
committed binary (`decode-brwide5`, SHA-256
`b4f2489f2352b15635eaa7cf0d3994b2caf55f3cf08a1522164146968c639ff6`) with the
adopted candidate (`decode-defgen16b`, SHA-256
`6c4aba004d128aa2c4db38fe80ff7fe2266e8f82d49b8f82305df686effd978d`).

| Run | L6 64 KiB | L6 1 MiB | L9 64 KiB | L9 1 MiB |
| --- | ---: | ---: | ---: | ---: |
| 1 | 0.9646 | 0.9614 | 0.9475 | 0.9606 |
| 2 | 0.9632 | 0.9621 | 0.9475 | 0.9595 |

Lower is faster. A 24-row two-sweep full-file screen gives `0.9523` for level 6
and `0.9524` for level 9. The standalone Deflate suite passes 581/581 tests.

## Conclusion

The guarded overcopy is adopted for the generic semantic loop. It removes the
short-copy width dispatch for the dominant short non-overlap class in blocks
that do not use the inline specialization.

Raw comparison, records and binaries stay local under
`/tmp/vort-br-lookup-20261101/` (`oneshot-defgen16b-comparison.json`,
`oneshot-defgen16b-1.json`, `oneshot-defgen16b-full-comparison.json`,
`decode-defgen16b`, `decode-brwide5`).
