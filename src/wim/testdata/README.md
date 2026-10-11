# WIM fixtures

`xpress-small.wim.b64` and `lzx-small.wim.b64` were generated with wimlib commit
`cd5e231c348c255ae5088873b5a66ee0eb96fa07` from a tree containing
`nested/file.txt` with the bytes `hello WIM XPRESS payload\n`.

The fixtures cover a compressed image-metadata resource, an uncompressed file
resource, the 50-byte lookup-table format, UTF-16LE XML metadata, SHA-1 lookup,
security-prefix and dentry parsing, nested path lookup/extraction, and both
XPRESS-Huffman and WIM LZX resource decoding. They are stored as base64 to keep
repository transport text-only.
