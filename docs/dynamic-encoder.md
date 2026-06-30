# Dynamic Huffman encoder status

Vort includes a dynamic Huffman encoder for raw, zlib, and gzip wrappers. It can emit LZ77 match tokens and is verified by Python zlib through `zig build run-python-zlib-diff`.

The current dynamic encoder is still intentionally simple: it uses conservative frequency completion and direct code-length emission instead of optimized code-length RLE or block-cost selection.

Remaining work for production dynamic encoding:

- build production-quality optimal or package-merge code lengths from literal/length and distance
  frequencies;
- RLE encode dynamic code lengths using symbols 16/17/18;
- choose HLIT/HDIST/HCLEN trimming safely;
- compare dynamic vs fixed vs stored block cost before selecting a mode;
- add Python zlib, gzip CLI, zlib-ng, and zlib-rs differential vectors with
  match-heavy payloads.
