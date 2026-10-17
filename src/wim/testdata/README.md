# WIM fixtures

`xpress-small.wim.b64`, `lzx-small.wim.b64`, `lzms-small.esd.b64`, and
`pipable-xpress.wim.b64` were generated with wimlib commit
`cd5e231c348c255ae5088873b5a66ee0eb96fa07`. The standard XPRESS/LZX fixtures
come from a tree containing `nested/file.txt` with the bytes
`hello WIM XPRESS payload\n`.

The LZMS ESD fixture instead contains `nested/lzms.txt`, whose bytes are pinned
in `src/lzms/testdata/lzms-small.txt`. Its SHA-256 is
`21375a8b6443c81d4e169c677b5322e517e843f6fa2599c6d06d4026553cf09c`.

The fixtures cover a compressed image-metadata resource, an uncompressed file
resource, the 50-byte lookup-table format, UTF-16LE XML metadata, SHA-1 lookup,
security-prefix and dentry parsing, nested path lookup/extraction, and both
XPRESS-Huffman and WIM LZX resource decoding. The ESD fixture adds LZMS image
metadata, an alternate solid chunk table, and a solid LZMS file blob. They are
stored as base64 to keep repository transport text-only. The pipable fixture
contains `nested/payload.txt` with the pinned LZMS test text and covers matching
leading/trailing headers, blob headers, per-chunk headers, and the tail-position
chunk table.

`encrypted-esd-small.esd.b64` is a deterministic synthetic encrypted ESD whose
single 32-byte range uses AES-256-CBC with a zero IV. Its XML session key is
RSA-OAEP-SHA1 wrapped with the generated test-only CryptoAPI PRIVATEKEYBLOB in
`encrypted-esd-test-private.blob.b64`. The decrypted payload SHA-1 is
`0613af950acadbb268fb9b7d1b58f3ec5ca57101`; its integrity table intentionally
covers the encrypted bytes so decryption must rebuild it. These keys protect no
real content and exist only for interoperability regression tests.
