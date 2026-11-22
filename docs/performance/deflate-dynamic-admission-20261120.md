# Dynamic Deflate tree admission, 2026-11-20

Classified differential fuzzing found two malformed distance trees accepted by
Vort but rejected by three independent reference implementations. A raw
128-byte text case changed HLIT and produced a seven-bit distance singleton;
Vort decoded 127 bytes. A 20,505-byte gzip case changed distance widths from
`{1, 1}` to incomplete `{1, 3}`; Vort decoded the original plaintext despite
the invalid header. Runtime zlib 1.2.11, zlib-ng 1.3.2 and the loaded
libdeflate artifact rejected both mutations. Original controls decoded
completely in all three.

The [wire contract](../formats/deflate-dynamic-huffman.md) now shares a small
Deflate-owned admission module across ordinary parsing, compact incremental
tables and Deflate64's independent parser. It validates complete code-length
trees, complete or legal one-bit singleton data trees, and unused empty
distance trees. Generic Huffman construction remains unchanged. One-shot
shape refusals use `InvalidHuffmanCode`; incremental shape refusals retain
`InvalidDynamicBlockHeader` and existing progress/sticky diagnostics.

## Validation

The same isolated candidate passes native/x86/WASI runner tests, 12/12 per
target, plus 74/74 existing Deflate dynamic tests and 7/7 Deflate64 dynamic
tests. Independent zlib controls accept five legal trees and reject ten
illegal trees. Dedicated cases cover allocating/direct/chunked/append/header
inspection, whole versus one-byte input, semantic workspaces, dictionaries,
wrapped streams, protected output/history and error accounting.

Mainline `check-deflate-dynamic-admission check-library-tests` passes 17/17
build steps and 24/24 native/x86 runner tests, with actual WASI execution and
complete current library test compilation. The full ReleaseFast deep campaign
passes 7/7 build steps: 14,684 valid round-trip/exact-size checks, 408,571 cuts
and 498,324 mutations. Original-wire and mutation-sequence digests remain
identical to the pre-fix run. Exactly eight raw and two gzip invalid-tree
acceptances become rejections; all other legacy counters remain unchanged.
The two formats have no remaining Vort-only mutation acceptance in this seed.
This statement retains the campaign's reference-capacity and consumption
scope rather than asserting global malformed-stream parity.

An independent seed `0x20261121` also passes all 7/7 build steps: 14,680 valid
streams, 13,824 actual external-reference checks, 409,213 truncation cuts and
497,970 mutations. Raw/zlib/gzip have zero Vort-only mutation acceptance in
that campaign, and all mutually accepted external outputs agree. Remaining
acceptance observations retain their reference-capacity/consumption scope.

Several old synthetic fixtures carried invalid codebooks or misplaced repeat
overrun witnesses. Their repairs make codebooks complete or explicitly test
header rejection, while preserving the generic kernel-hole oracles, original
archived bytes, committed-prefix behavior and guards. The raw directory's
`fixture-repairs-README.md` records each former shape, correction and retained
purpose. All five affected filtered fixture gates pass.

[Raw evidence](data/deflate-dynamic-admission-20261120/) preserves actual before
and after samples, independent tree analysis, candidate source archive,
portability receipt, current-source hashes and the full differential report.
The preceding whole-library result passed 406/406 steps and 5,825 tests with
two skipped; it binds the source before this admission increment. The later
complete admission/reporting snapshot passed 408/408 build steps and 5,827
tests with two skipped, including 5,734 root-library passes. All recorded
source hashes matched at terminal exit zero. Its
[terminal receipt](data/deflate-dynamic-admission-20261120/full-final-gate-receipt.json)
binds the source before the subsequent Puffin increment.
The q11 performance screen stopped without a complete acceptance epoch and
its production patch remains unadopted. The independent Android OTA Puffin
parser is outside this ordinary Deflate/Deflate64 candidate's scope; its
[structural follow-up](puffin-dynamic-bounds-20261121.md) has separate evidence.
