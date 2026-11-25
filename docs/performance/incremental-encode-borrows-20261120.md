# Incremental encoder memory admission, 2026-11-20

This functional increment closes a cross-codec data-corruption path. An
incremental call may publish a frame header or pending output before reading
new input. If the caller supplies overlapping input and output, that earlier
write can replace plaintext before the encoder accepts it.

The shared Deflate encoder admission covers raw stored/fixed/best plus zlib
and gzip fixed/best wrappers. Brotli checks the shared stored/planned/static-
dictionary owner. Zstd checks the single-frame encoder and the persistent
parallel facade, owner and queue. Checks run before mutable stream transitions,
allocator binding, profile publication, or prefix error recording. A refused
call returns `InvalidBlockPlan` and can be retried with independent buffers.

Stable parallel objects are checked before acquiring the queue mutex. A native
held-mutex regression proves that receiver, control, queue, mutex and descriptor
conflicts return immediately; dynamic Job capacity descriptors remain checked
under the queue lock. Brotli's retained dictionary descriptor traversal also
checks the 15-RAW-prefix limit, including a serialized RAW attachment, before
walking the descriptors.

Public behavior and the executable portability commands are documented in the
[borrow contract](../formats/incremental-encode-borrows.md).

## Observed failures before the change

The focused regressions were added before production admission:

| Codec | Observed result with overlapping input/output |
| --- | --- |
| Gzip fixed encoder | Accepted 49 input bytes and wrote a 10-byte header, returned `need_input` instead of rejecting the overlap. |
| Brotli stored/planned/static-dictionary | Each accepted 6 input bytes and wrote a 3-byte metadata prefix, returned `need_input` instead of rejecting the overlap. |
| Zstd single-frame encoder | Accepted 32 input bytes and wrote a 6-byte frame header, returned `need_input` instead of rejecting the overlap. |

These are active encoders with valid settings. The regression input and output
share physical bytes; the format-prefix write precedes plaintext buffering.
The default one-bit Brotli window prefix is retained until its byte is complete,
so the Brotli fixture supplies metadata to make a prefix actually publishable.

The [raw evidence directory](data/incremental-encode-borrows-20261120/) retains
the failing logs and final verification artifacts. This work makes no ratio,
throughput or industry-leadership claim. Existing independent-buffer wire
selection remains the validation oracle.

## Compatibility and portability

`zig build -j2 check-incremental-encode-borrows --summary all` passed all 38
steps. Native and Linux x86 each ran the Deflate/Deflate64/Brotli/Zstd filtered
suites with 12/6/46/26 passing runner tests. Actual WASI ran the same four suites and
recorded a successful `wasi-receipt.json`; parallel Zstd uses its synchronous
fallback on that target. The runner totals include anonymous imported tests;
the functional matrices execute multiple public encoder cases within those
tests.

The ReleaseFast Zstd interoperability matrix passed **171/171** cases against
the pinned libzstd **1.6.0** library and header. It covered every explicit
strategy, standard/magicless frames, dictionaries, checksums, caller progress,
memory limits, flush/continuation, and actual worker overlap (peak 2). The
three declared long-input sizes retained stable capacities. Reference decoding
verified exact consumption, complete plaintext and caller guards; matched
worker1/failing-Io controls preserved each frame's wire.

The ReleaseFast Brotli multiblock differential passed against libbrotli
**1.0.9** with 98 main cases, 7,056 generated fixtures and their progressive
replays, 121 incremental static-dictionary transform cases, and the existing
metadata, window, chunked and schedule controls. This run included no real-file
corpus, and establishes functional interoperability only.

## Large-sequence fixture correction

The first complete Zstd campaign passed 169 cases and failed two historical
sequence-coverage assertions. Both frames decoded correctly and emitted
`[0, 1, 1116]` physical sequence counts, below the required 1,248 maximum.
Isolated probes built from HEAD `22e5ca2495dc140103ffc9ef41de389fd593ba07`,
and then HEAD plus the untouched turn-start LZ77 experiment, emitted the exact
same bytes. This established fixture drift independently of the admission
change. The original wire hashes are retained in `zstd-initial-summary.json`
and the full failed report is preserved in `zstd-interop-initial.json.gz`.

The incremental campaign now uses a dedicated dense short-match fixture. It
keeps the original seed, match traversal, 24 KiB input, and 8 KiB block/job
settings, uses one delimiter byte after each four-byte anchor, and prevents
that anchor extending through the delimiter. Six diagnostic variants produced
1,303–1,337 sequences; the retained original seed and traversal produced 1,330.
The **`>=1248`** assertion remains unchanged. Both original and dense fixtures
have byte-identical pre-change/current standard and magicless wires; the
final complete 171-case matrix is green.

`zstd-turn-start-baseline.json` and `zstd-baseline-build.json` retain the replay
and compiler commands, archive identity, unchanged Huffman object identity,
reference decoding and exact wire comparisons. `zstd-interop-final.tar.xz`
preserves the complete final campaign, including fixtures, commands, replies,
source snapshots, report and artifact manifest.

## Final library verification and source state

The first full build found an inline-state generic incompatibility in the
Deflate64 consumer of the shared stored core. Its state has a byte-aligned
`bit_index` and no heap-backed `bytes` list. Storage admission now protects
that state through the receiver, and the shared `clone` conditionally copies
heap-backed bit state while retaining inline state directly. Four focused
Deflate64 regressions validate overlap refusal, retained-capacity protection,
independent cloned continuation, exact wire/decoded contents and reset. They
run in all three architecture variants alongside the primary codecs.

The final frozen source passed `zig build -j2 check check-wasm --summary all`:
394/394 build steps and 86/86 native/x86 auxiliary runner tests passed. The
complete `zig build -j2 test --summary all` execution for this frozen snapshot
also passed: 11/11 steps, 5,710 runner tests passed and two skipped. The test
binary ran for 56 minutes in Debug. `source-before-lifecycle.json` binds this
snapshot; later metadata-finalization and profile/prefix transition changes
have their own evidence under `incremental-encoder-lifecycle-20261120`.
The overall three-codec goal remains active.

For the source-WASI runner, Zig 0.16 displays captured test stderr and Node's
experimental warning under `run node w`, followed by `failed command`. The
first full build's final tree explicitly marks that node successful; its actual
failure was the Deflate64 inline-state compile error above. Independent PIPE,
file-output and strace rechecks exited zero and wrote complete JSON. Use the
final node status and process exit code to assess this gate.
