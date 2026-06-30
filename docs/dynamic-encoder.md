# Dynamic Huffman encoder status

Vort includes a dynamic Huffman encoder for raw, zlib, and gzip wrappers. It can emit LZ77 match tokens and is verified by Python zlib through `zig build run-python-zlib-diff`.

The current dynamic encoder uses conservative frequency completion and RFC1951
code-length RLE symbols 16/17/18. It also has raw/zlib/gzip split-best encoders
that plan each bounded block independently and choose stored, fixed, or dynamic
emission per block. For complex distance-code sets that are not yet proven safe,
the dynamic encoder conservatively falls back to fixed-Huffman token emission so
public outputs remain zlib-compatible. The split-best and adaptive-split
compatibility wrappers are covered by the Python zlib differential smoke
harness.

Remaining work for production dynamic encoding:

- build production-quality optimal or package-merge code lengths from literal/length and distance
  frequencies;
- choose HLIT/HDIST/HCLEN trimming safely;
- replace byte-size candidate selection with bit-accurate block cost modeling
  that does not need to materialize every candidate;
- add Python zlib, gzip CLI, zlib-ng, and zlib-rs differential vectors with
  match-heavy payloads.
