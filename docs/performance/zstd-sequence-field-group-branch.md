# Zstd sequence field-group branch consolidation

## Hypothesis

The split-Huffman sequence loop decoded every sequence's three extra fields
with a separate `if (fields_are_grouped)` expression, then repeated the same
condition for the three FSE transitions. That is six identical branches per
sequence and keeps the optional `field_group` live across every extraction. The
profile attributes about 95% of Zstd level-3 decode time to the two split
sequence loops.

## Experiment

`sequence_field_group.Group.init` is still called once per sequence. The three
extra fields and the three transitions now live in a single
`if (field_group) |*group| { ... } else { ... }` pair, so each sequence takes
one grouped/ungrouped decision. `expectEnd` runs after the branch when the
sequence is last, and the match/literal lengths are formed afterwards from the
extracted extras. `Group.init` consumes the whole group from the source reader,
so the grouped path keeps the same progress accounting.

## Result

Two independent four-sweep screens over the 48 Zstd 64 KiB/1 MiB rows compare
the committed binary (`decode-def16b`, SHA-256
`7e75154de3db0a5fe81aa103c7b409ee13e4ac50594fafa8b7beb64032e11a44`) with the
candidate (`decode-seqgroup`, SHA-256
`472271e39928954092b288e4e70509d2f7f4bf93ae11a34e59aace4408db0150`).

| Run | L3 64 KiB | L3 1 MiB | L19 64 KiB | L19 1 MiB |
| --- | ---: | ---: | ---: | ---: |
| 1 | 0.9824 | 0.9892 | 0.9844 | 0.9900 |
| 2 | 0.9872 | 0.9903 | 0.9822 | 0.9933 |

Lower is faster. A 24-row two-sweep full-file screen gives `0.9904` for level 3
and `0.9930` for level 19. The largest gains are `mr.64k.l19 0.943`,
`dickens.64k.l3 0.952`, `mr.64k.l3 0.962` and `samba.64k.l3 0.962`; the largest
regressions are `nci.64k.l19 1.044` and `nci.1m.l19 1.015`. The focused
`zig build test-zstd -Doptimize=ReleaseFast` suite exits 0.

## Conclusion

The consolidation is adopted. It removes five repeated conditions per sequence
and shortens the optional group's live range while preserving the grouped
fast path.

## Extended paths

Applying the same consolidation to the medium-split, single-Huffman and raw
sequence loops was neutral and reverted. Two four-sweep screens give
`1.0000/0.9991/0.9964/0.9991` and `0.9996/1.0002/0.9960/0.9977` for level 3/19
at 64 KiB/1 MiB. Besides the lack of a measurable gain, the single-Huffman loop
reads `state.reader` directly, so moving its transition reads ahead of
`resolveSequenceOffset` would advance reader progress on an error path.

Raw comparison, records and binaries stay local under
`/tmp/vort-br-lookup-20261101/` (`oneshot-seqgroup-comparison.json`,
`oneshot-seqgroup-1.json`, `oneshot-seqgroup-full-comparison.json`,
`oneshot-seqgroup-all-comparison.json`, `decode-seqgroup`, `decode-def16b`).
