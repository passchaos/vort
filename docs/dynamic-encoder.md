## Dynamic Huffman encoder status

Vort includes a production dynamic Huffman encoder for raw, zlib, and gzip
wrappers. It emits LZ77 match tokens, uses tree-based Huffman code length
generation, and handles arbitrary distance code sets without conservative
fallback guards.

The encoder:
- uses package-merge length-limited Huffman generation for all three alphabets
  (literals, distances, code-lengths), keeping generated code lengths within
  DEFLATE's 15-bit limit while matching brute-force oracle costs on the
  small cases tracked by `run-huffman-length-report-dashboard`;
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

## Runtime level and strategy changes

`DeflateParams` exposes zlib-compatible numeric levels `0...9` and strategies
`.default`, `.filtered`, `.huffman_only`, `.rle`, and `.fixed`. Level 0 is a
true stored-only mode regardless of strategy. `.fixed` retains stored fallback
but excludes dynamic-Huffman blocks; the other nonzero combinations retain the
Best encoder's stored/fixed/dynamic arbitration under their selected parser
policy.

The root exports `DeflateParams` and `DeflateParamsError`; algorithm-family and
resolved planner details remain internal. Unlike the C API, the normalized Zig
surface has no `-1`/default-compression sentinel: callers select an explicit
level `0...9`, with `6` as the struct default.

`RawDeflateIncrementalBestEncoder`, `ZlibIncrementalBestEncoder`, and
`GzipIncrementalBestEncoder` expose `requestParams()`. The level families are
stored (`0`), fast (`1...3`), and slow (`4...9`). A request within the active
family and strategy applies immediately without ending the current block, so
accepted but still buffered bytes use the new planner. A family or strategy
change queues an implicit non-final DEFLATE block boundary: callers drain with
empty input until `need_input`, and the boundary adds neither a sync marker nor
byte alignment. Supplying input while this asynchronous boundary is pending is
an error.

An initial request made before any input applies immediately and emits no empty
block. Levels `10...15` return `InvalidCompressionLevel` without changing
active or queued state.

Duplicate requests are idempotent, the latest queued request wins, and a
request for the active pair cancels a queued change. Snapshots expose active
and requested parameters, pending-boundary state, applied-change count,
stored-only state, and combined flushing state. `reset()` retains the active
pair but cancels queued work and resets the count; `resetWithOptions()` opts
back into direct low-level compression options. Fixed-only incremental encoders
advertise `supports_runtime_params = false` and return `UnsupportedOperation`
from `requestParams()` because their block policy cannot implement the full
runtime domain. Wrapper runtime state is authoritative in `snapshot()`; outer
options remain initialization/reset configuration and do not change early while
a request is queued.

For wrapped encoders, ordinary `reset()` and gzip header-only `nextMember()` /
`nextMemberExactSize()` reuse the active pair and cancel a queued request. APIs
that explicitly accept new raw options (`nextStream`, `nextMemberWithOptions`,
and their exact-size variants) replace runtime-param state with those options.
Parameter changes affect the DEFLATE payload planner; they do not rewrite an
already emitted zlib FLEVEL or gzip XFL/header field.

Parameter boundaries retain rolling history, matcher state, and a preset
dictionary. Zlib Adler-32 and gzip CRC-32/ISIZE continue across changes.
`fullFlush()` remains the only parameter/flush composition that clears history
and disables the current preset dictionary; partial/sync/block boundaries and
ordinary parameter changes do not. `partialFlush()` publishes accepted data
then writes the ten-bit non-final empty fixed block defined by zlib
`Z_PARTIAL_FLUSH`. Unlike sync/full flush it does not byte-align, but unlike
`blockFlush()` it emits enough bits for the decoder to finish the preceding
block immediately. Flush strength upgrades in block < partial < sync < full
order.

### Validation

`run-deflate-params-interop` passes against the selected libz; the local run
reports runtime zlib 1.2.11. It covers raw, zlib, and gzip in both directions:
three Vort `requestParams()` streams are inflated by libz, and three libz
`deflateParams()` streams are decoded by Vort. The common schedule covers
`6 -> 1 -> 0 -> 6`, every strategy, same-family `1 <-> 3` and `4 <-> 9`, 84
total requests, and 24 same-family requests. Vort observes 45 applied changes
and 30 queued implicit boundaries. Both implementations drain through
three-byte output. The libz side deliberately applies zero-output pressure,
observes three `Z_BUF_ERROR` results, and retries the same requested parameters
to successful completion. Cross-implementation wire equality is not required;
decoded bytes and wrapper checksums are.

The same gate covers six bidirectional `Z_PARTIAL_FLUSH` cases across raw,
zlib, and gzip using three-byte output: three Vort streams inflate through
libz, and three libz streams decode through Vort. Fixed fixture tests separately
pin the exact ten-bit marker wire.

Focused runtime-parameter tests pass 19/19, and the direct Deflate suite passes
473/473. The full repository test graph passes 2615/2615, and `zig build check`
passes all 113 steps including the new probe. The probe is also wired into
`ci-smoke`; the aggregate smoke graph currently has unrelated existing
failures, so this increment does not claim a fully green `ci-smoke` run.

Remaining encoder work for future milestones:

- dynamic-Huffman-aware optimal parser refinement (iterative LZ77
  re-optimization using dynamic bit costs beyond the production fixed-cost
  optimal parser);
- split-point search tuning against standard corpora.
