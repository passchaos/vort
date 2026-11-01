# Deflate copy policy against libdeflate's word loop

## Reference

libdeflate's `decompress_template.h` fastloop copies every match with
`offset >= 8` using five ordered unaligned 8-byte moves (40 bytes), then a
five-move loop until the match end. The scheme relies on ordered loads/stores:
each later load reads history or bytes written earlier in the same copy, so
overlapping matches work without a separate periodic path. libdeflate decodes
at most three literals per iteration (one primary plus two speculative), while
Vort packs two literals per table entry and speculates four entries.

## Experiment

The generic Deflate semantic loop adopted libdeflate's copy shape for
`distance >= 8` whenever `out_pos + length + 40 <= output.len`, keeping the
existing 16-byte move for `length <= 16` and `distance >= 16` because that
class was already measured as the hottest short-match shape. Distances below
eight retain `shortcopy.copy` or `copyMatchAt`.

## Result

The 48-row screen compares the committed `decode-defgen16b` (SHA-256
`6c4aba004d128aa2c4db38fe80ff7fe2266e8f82d49b8f82305df686effd978d`) with the
candidate `decode-defword40b` (SHA-256
`a239a5c779b5d19e841f6d28a7393e95346e548d9490ba7ded8e361ff38c5745`):

| L6 64 KiB | L6 1 MiB | L9 64 KiB | L9 1 MiB |
| ---: | ---: | ---: | ---: |
| 1.0008 | 0.9997 | 0.9930 | 1.0000 |

Lower is faster. The level-9 64 KiB row improves about 0.7%, but the other
three rows are neutral. The standalone Deflate suite passes 581/581 tests,
including the overlap cases.

## Conclusion

The candidate was reverted. Vort's existing 16-byte overcopy plus
`shortcopy`/`memcpy` selection is already at parity with libdeflate's word
copy on the measured corpus. The remaining Deflate gap is not in the copy
kernel; the profile still points at the literal-entry spill and table loads.
libdeflate's literal speculation depth is also below Vort's, so copying that
policy would not help.

Raw comparison, records and binaries stay local under
`/tmp/vort-br-lookup-20261101/` (`oneshot-defword40b-comparison.json`,
`decode-defword40b`, `decode-defgen16b`).
