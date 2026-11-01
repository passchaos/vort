# Brotli standard-header packed literal cache

The large-window header gained a four-slot cache of expanded packed literal
trees earlier. The standard `MinimalCompressedHeader` used by the one-shot
decoder still kept a single active tree, so frames with many literal block types
rebuilt the Huffman table on every switch.

## Change

The standard header now uses the same eight-slot round-robin cache keyed by
tree index. The indices clear after every compressed-header parse and the
prepared flags clear with the rest of the header. The cache adds about 12 KiB to
the standard header. Command and distance packed trees keep their single active
slot because they are expanded far less often.

## Measurement

### One-shot prefix screen

A paired 384-process four-sweep screen against the previous current-source build
gives `0.9954/1.0036/0.9974/0.9968` for q6/q11 at 64 KiB/1 MiB: the prefixes are
neutral because they switch literal block types rarely.

### One-shot full files

A 24-row, two-sweep full-file screen gives an overall `0.9827`. The largest
gains are samba q6 `0.879`, ooffice q11 `0.913`, x-ray q11 `0.933` and samba
q11 `0.953`. The largest regressions are dickens q11 `1.021`, sao q6 `1.014`,
webster q11 `1.013` and nci q11 `1.011`. The win is concentrated in frames with
many literal block-type switches.

### Eight-slot follow-up

A one-shot samba.full q6 profile after the four-slot cache still attributed
7.3% to `PackedPrefixCode(256).expand`. Doubling the cache to eight slots
(round-robin cursor widened to `u3`) reduced samba.full q6 from 53.77 to
48.77 ms. A 24-row two-sweep full-file screen gives `0.9886` overall versus the
four-slot build (samba q6 `0.912`, x-ray q11 `0.948`; worst dickens q11 `1.028`),
and the 64 KiB/1 MiB prefixes are neutral
(`0.9971/1.0017/0.9947/0.9913`). The cache adds another about 6 KiB per header
type.

## Validation

The complete ReleaseFast Brotli suite passes 1504/1505 with one 32-bit-specific
skip and zero failures. The standard packed-literal cache test now checks the
round-robin cache indices instead of the removed single active index.

## Next work

The standard header still rebuilds command and distance packed trees on every
switch. Extending the cache there is only worth it if their expansion profiles
grow. Raw Deflate and the Zstd sequence decode remain the largest three-codec
gaps.
