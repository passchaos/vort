# Portable PNG/DEFLATE match comparisons, 2026-11-02

On Zig 0.16 AArch64 built with `-mcpu=baseline-neon`, scalarizing the
32-lane byte-equality vector and bitcasting its boolean lanes to u32 lost
mismatch bits. The shared match-length scalar comparison test returned 40
for a match that ended at byte 16. Encoders consequently emitted matches
containing unequal bytes; the full-table and ring parsers could agree on the
same incorrect tokens.

The same boolean-mask form appeared in incremental cross-history matching
and the uniform-byte admission check. All three now share the target
capability predicate in `lz77/match/length.zig`. NEON AArch64 and SSE2 x86
retain the old vector path; other targets use existing exact little-endian
word comparisons followed by byte tails. Big-endian targets use word
comparisons so mask bit order cannot select the wrong first byte. No parser
state, buffer capacity or allocation is added.

The nearby match-length regression isolates the 16-versus-40 failure. The
existing exhaustive boundary test compares every mismatch, maximum length,
unaligned offset and short-distance overlap against byte-wise semantics.
The incrementally owned matcher and uniform-byte tests are now explicitly
imported at the Deflate root, so those gates actually discover them.

Verification:

- No-NEON shared match tests pass 2/2; related lazy/hash/replay/allocation
  tests pass 17/17. Native LZ77 also passes 17/17.
- No-NEON Deflate semantic/ring/window/matcher tests pass 43/43, resolving
  both previously observed baseline failures. Native and no-NEON incremental
  gates each pass 12/12, including history, dictionary and uniform-byte tests.
- imx no-NEON PNG row/Adam7 owner tests pass 87/87, including the three
  previously exposed Adam7 encoder failures.
- Thirty fixed/level-1..9 streams decode exactly through system zlib and
  native/no-NEON encoded bytes match. Independent mathematical PNG inputs
  cover all fifteen legal color/depth combinations, both ordinary/Adam7
  layouts and levels 1/6/8/9: all 120 PNG buffers match native encoding and
  every pixel matches image-png and libpng. PNG CRC/zlib Adler checks pass.
- A ReleaseFast native exported match probe has byte-identical 336-byte
  `.text` before/after, SHA-256
  `cfda6a663d729d7a94c013957dbed3987e37dcbb7c2ab109e15b67c9222ebf0e`.
  This establishes unchanged instructions for that native kernel, not a
  format-wide throughput claim. x86_64 and AArch64 big-endian compile the
  changed comparison paths; their runtime behavior was not tested here.

Full proof, generators and independent-decoder identities live in imx's
`docs/evidence/png-portable-match/`. Run artifacts are under
`/nav_env/Temp/imx-png-portable-match-20261102/`. The broad codec performance
and conformance goals remain open.
