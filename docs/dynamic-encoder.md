# Dynamic Huffman encoder status

Vort includes a dynamic Huffman encoder for raw, zlib, and gzip wrappers. It can emit LZ77 match tokens and is verified by Python zlib through `zig build run-python-zlib-diff`.

The current dynamic encoder uses conservative frequency completion and RFC1951 code-length RLE symbols 16/17/18. It still lacks production block-cost selection and production-grade length-limited Huffman optimization.

Remaining work for production dynamic encoding:

- build production-quality optimal or package-merge code lengths from literal/length and distance
  frequencies;
- choose HLIT/HDIST/HCLEN trimming safely;
- compare dynamic vs fixed vs stored block cost before selecting a mode;
- add Python zlib, gzip CLI, zlib-ng, and zlib-rs differential vectors with
  match-heavy payloads.
