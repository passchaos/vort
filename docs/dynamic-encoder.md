## Dynamic Huffman encoder status

Vort includes a production dynamic Huffman encoder for raw, zlib, and gzip
wrappers. It emits LZ77 match tokens, uses tree-based Huffman code length
generation, and handles arbitrary distance code sets without conservative
fallback guards.

The encoder:
- uses tree-based Huffman length generation with Kraft-cost repair for
  all three alphabets (literals, distances, code-lengths);
- preserves the unbounded Huffman tree depths before applying zlib-style
  length-limit redistribution, avoiding the older shortcut that clipped deep
  leaves during tree traversal and then repaired the flattened code space;
- handles arbitrary distance code sets without limiting active symbols or
  max symbol index;
- uses minimal frequency completion (2 symbols) instead of power-of-two
  padding to reduce header overhead;
- supports RFC1951 code-length RLE with symbols 16/17/18;
- provides raw/zlib/gzip split-best encoders that plan each bounded block
  independently and choose stored/fixed/dynamic emission per block;
- uses bit-cost models for stored, fixed, and dynamic candidates, avoiding
  candidate materialization just to compare block modes;
- provides adaptive split encoding with level-specific split windows and
  search steps, falling back to one-shot best block when smaller;
- routes the best compression level through the production hash-chain optimal
  parser, with full raw/zlib/gzip adaptive split coverage across default,
  filtered, Huffman-only, and RLE strategies;
- generates correct output verified by Python zlib, system gzip, and
  zlib-ng/zlib-rs differential harnesses.

Remaining encoder work for future milestones:

- implement package-merge length-limited Huffman for optimal code lengths
  under the 15-bit constraint (current tree + zlib-style overflow
  redistribution is correct and deterministic but not globally optimal);
  `run-huffman-length-report-dashboard` records fixed and generated small
  brute-force oracle cases that future implementations must satisfy before
  replacing the production length builder, and now includes a package-merge
  candidate side-by-side with the current production builder;
- dynamic-Huffman-aware optimal parser refinement (iterative LZ77
  re-optimization using dynamic bit costs beyond the production fixed-cost
  optimal parser);
- split-point search tuning against standard corpora.
