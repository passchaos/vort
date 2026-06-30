# Dynamic Huffman encoder status

Vort currently includes a minimal literal-only dynamic Huffman encoder for raw,
zlib, and gzip wrappers. Its output is verified by Python zlib through
`zig build run-python-zlib-diff`.

The encoder deliberately does **not** yet emit LZ77 match tokens in dynamic
blocks. A first token-capable attempt showed how easy it is to generate invalid
code-length alphabets; the current implementation stays conservative and routes
match-capable compression through fixed-Huffman blocks until production-quality
canonical length generation and dynamic header/RLE optimization are implemented.

Remaining work for full dynamic encoding:

- build optimal or package-merge code lengths from literal/length and distance
  frequencies;
- RLE encode dynamic code lengths using symbols 16/17/18;
- choose HLIT/HDIST/HCLEN trimming safely;
- compare dynamic vs fixed vs stored block cost before selecting a mode;
- add Python zlib, gzip CLI, zlib-ng, and zlib-rs differential vectors with
  match-heavy payloads.
