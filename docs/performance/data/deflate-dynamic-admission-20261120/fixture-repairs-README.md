# Dynamic admission fixture repairs

All changes are confined to `/tmp/vort-deflate-dynamic-admission.IGIQSs`.
The main repository is untouched. No commits are created. Production admission
changes and other agents' files are outside this repair's ownership.

| File / old fixture | Invalid old shape or misplaced witness | Repair and retained purpose |
| --- | --- | --- |
| `src/fuzz.zig`, repeat18 | Singleton one-bit CODES18 was incomplete and rejected before repeat decoding. | Add unused CODES0 at width one to complete CODES. Two 138-zero runs exceed the 258-length vector; expect `InvalidDynamicBlockHeader` at bit 45. |
| `src/fuzz.zig`, repeat17 | Singleton CODES17 was incomplete. In addition, 86 three-zero runs exactly filled all 258 lengths, so the trailing opcode was never parsed and did not witness an overrun. | Add unused CODES0 at width one; emit 85 three-zero runs (255 lengths), then a four-zero run. Expect repeat bounds rejection at bit 373. |
| `src/fuzz.zig`, missing DIST | Three width-two LL leaves (`a`, EOB256, LL257) were incomplete, hiding the intended empty-distance payload failure. | Add unused literal `b` at width two. Header parsing succeeds at bit 324; literal `a` and LL257 are present, and later use of empty DIST returns `InvalidHuffmanCode`. |
| `src/deflate/semantic/distance_holes_tests.zig`, existing9 / existing10 | The public positive second-block DIST alphabet `{9,10}` was incomplete. | Keep DIST0 at width nine and DIST1 at width ten; add unused DIST2..9 at widths 1..8 plus DIST10 at width ten. Canonical encoder codes become 255 / 511. Validate the complete tree, exact header and payload, public success, guards, and both single/two-block cases. |
| `src/deflate/semantic/distance_holes_tests.zig`, missing10 | The old two-block stale-slot public wire attempted payload hole rejection using an incomplete second header. | Preserve its bytes and bit length (2436 bits / 305 bytes), but explicitly prove header rejection after 1114 header bits and before payload consumption. Preserve the valid first block's 128-byte prefix; no invalid-block output is written. The single-block case writes no output. Retain the `{9,10}` generic table and canonical hole-shape oracle. |
| `src/deflate/semantic/public_linear_contracts.zig`, missing primary prefix | DIST0 / DIST29 at width two were incomplete. A body with 256 initial literals and a missing prefix cannot establish a public semantic-loop rejection under strict admission. | Keep that body and generic primary-hole witness. Decode the known direct CL lengths independently, then explicitly check strict public parsing rejects at header bit 1226. Single-block output stays untouched. Add a first stored block containing `stored`; that committed prefix survives rejection and all later output bytes remain untouched. Existing legal OSDB hot-loop witnesses remain intact. |
| `src/deflate/semantic/distance_holes_modes.zig`, archived mode wires | The embedded wires' second `{9,10}` DIST alphabet is intentionally incomplete. Calling strict `parseDynamicLengths` to prepare a kernel oracle incorrectly treated invalid public wire as admitted. | Preserve all embedded bytes and hashes. Read only the header with the generic header reader, compare its direct CL symbols to known LL / DIST arrays, and build generic Huffman tables directly. Separately assert strict parsing rejects at the same header-end position. Retain ordinary, non-overlap, window, sink, rolling/wrap execution, prefix preservation, guard, and token-progress checks. |

Validation uses only filtered `zig test` commands from the isolated directory.
Every command sets `TMPDIR=/tmp`, `ZIG_GLOBAL_CACHE_DIR` to
`/tmp/vort-deflate-dynamic-admission.IGIQSs/fixture-global-cache`, and a distinct
`ZIG_LOCAL_CACHE_DIR` below the same isolated directory. No full library/root
build is started.

Filters:

- `zig test src/deflate.zig --test-filter 'Deflate long distance secondary hole contracts'`
- `zig test src/deflate.zig --test-filter 'Deflate public generic semantic linear contracts'`
- `zig test src/deflate.zig --test-filter 'Deflate long distance secondary execution modes'`
- `zig test src/fuzz.zig --test-filter 'deflate malformed smoke fixtures reach repeat overruns and empty distance use'`
- `zig test src/fuzz.zig --test-filter 'deflate smoke corpus covers valid and malformed raw streams'`

First validation pass: public linear (8 tests), kernel modes (9 tests), fuzz
exact fixtures (8 tests), and Deflate smoke (11 tests) passed. The public hole
suite exposed an overstrong new assertion requiring untouched unused output
after the first dynamic block. That block's semantic loop may legitimately
write speculatively inside capacity, as the original contract already states.
The check preserves its committed 128-byte prefix and external guards; the
no-history invalid-header case still requires entirely untouched output.
The stored-prefix case separately proves untouched output after `stored`.

Final validation result: all five filtered commands passed (public holes 8,
public linear 8, kernel modes 9, fuzz exact fixtures 8, Deflate smoke 11).
The public-hole suite was rerun after adding an independent exact header-shape
witness, and passed. `zig fmt --check` passed for all four modified Zig files.
Zig version: 0.16.0. Validation completed on 2026-11-20 at 21:45 China time.
