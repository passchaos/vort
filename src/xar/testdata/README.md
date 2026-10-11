# XAR fixtures

`apple-xar-bzip2.xar.b64` is the Base64 representation of `archive8` embedded
in libarchive's `test_read_format_xar.c`. The upstream test records the exact
archive as produced by Apple's `xar --compression bzip2 -cf archive8.xar f1`;
`f1` contains `hellohellohello\n`.

The fixture is 525 bytes and comes from libarchive commit
`f65c564402eb200373b3638dfcd2904206150dec` in the local compatibility
checkout used for this implementation.
