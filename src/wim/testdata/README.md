# WIM fixtures

`xpress-small.wim.b64`, `lzx-small.wim.b64`, and `lzms-small.esd.b64` were
generated with wimlib commit
`cd5e231c348c255ae5088873b5a66ee0eb96fa07` from a tree containing
`nested/file.txt` with the bytes `hello WIM XPRESS payload\n`.

The LZMS ESD fixture instead contains `nested/lzms.txt`, whose bytes are pinned
in `src/lzms/testdata/lzms-small.txt`. Its SHA-256 is
`21375a8b6443c81d4e169c677b5322e517e843f6fa2599c6d06d4026553cf09c`.

The fixtures cover a compressed image-metadata resource, an uncompressed file
resource, the 50-byte lookup-table format, UTF-16LE XML metadata, SHA-1 lookup,
security-prefix and dentry parsing, nested path lookup/extraction, and both
XPRESS-Huffman and WIM LZX resource decoding. The ESD fixture adds LZMS image
metadata, an alternate solid chunk table, and a solid LZMS file blob. They are
stored as base64 to keep repository transport text-only.
