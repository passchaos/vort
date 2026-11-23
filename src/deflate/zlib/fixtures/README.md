# Smaller-CINFO compatibility fixture

`small-cinfo-distance-257.zlib` is a manually assembled RFC 1951 fixed-Huffman
block in an RFC 1950 wrapper. It contains 257 literal bytes (0 through 255,
then 0xa5), followed by a length-257/distance-257 match and EOB. The resulting
514-byte payload has SHA-256
`0ebb80b6df9e23276228cbe55ca86957fc16d372e311bf55ff1ef118c4ed6d50`.

The header is 0x08 0x1d: CM=8, CINFO=0 (256-byte advertised window), no preset
dictionary and valid FCHECK. Its match distance deliberately exceeds that
advertised window by one. Existing Vort one-shot behavior tolerates this
metadata discrepancy like common zlib decoders; it still validates the payload,
Adler-32 and member boundary. The incremental regression exercises this same
contract, including output backpressure and strict checksum/tail handling.

The independent generator uses canonical fixed codes directly and only uses
Python zlib for Adler-32 and reference decompression. It was checked with runtime
zlib 1.2.11 on 2026-11-23. The 282-byte wire SHA-256 is
`a24a3f00d36d06382e512e99b4b11fe8fad62642bb55f27c7d016253f74b630b`.

```sh
python3 src/deflate/zlib/fixtures/generate_small_cinfo.py
```
