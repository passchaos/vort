# Dynamic Huffman encoder status

Vort includes a dynamic Huffman encoder for raw, zlib, and gzip wrappers. It can emit LZ77 match tokens and is verified by Python zlib through `zig build run-python-zlib-diff`.

The current dynamic encoder uses conservative frequency completion, a
frequency-weighted tree length builders for both literal/distance and
code-length alphabets, and RFC1951 code-length RLE symbols 16/17/18. It also has raw/zlib/gzip split-best encoders that plan each bounded
block independently and choose stored, fixed, or dynamic emission per block.
Stored/fixed/dynamic choices use bit-cost models for stored, fixed-Huffman, and
dynamic-Huffman candidates, avoiding candidate materialization just to compare
block modes. Adaptive split encoding now searches candidate block lengths using
that cost model instead of relying only on byte-uniqueness heuristics, with
level-specific split windows and search steps, then falls back to the one-shot
best block whenever that is smaller. For complex distance-code sets that are not
yet proven safe, the dynamic encoder conservatively falls back to fixed-Huffman
token emission so public outputs remain zlib-compatible. The split-best and
adaptive-split compatibility wrappers are covered by the Python zlib and system
gzip differential smoke harnesses, including match-heavy raw split-best, zlib dynamic/split-best, and gzip
adaptive payloads.

Remaining work for production dynamic encoding:

- replace the current weighted tree length builder with production-quality
  package-merge length-limited Huffman lengths;
- choose HLIT/HDIST/HCLEN trimming safely;
- expand split-point search beyond bounded candidates and tune the current
  level-specific policies against standard corpora;
- extend zlib-ng and zlib-rs direct CLI/library differential vectors with more
  match-heavy dynamic payloads.
