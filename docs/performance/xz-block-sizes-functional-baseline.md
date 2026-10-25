# XZ declared Block Header sizes functional baseline

Date: 2026-10-26. The public size option, direct block input alias fix and CLI
flag are implemented. Functional/reference, real MT worker, Wasm and final
build/help gates below have completed. No throughput or encoder RSS result is
assigned.

The [public contract](../formats/xz-block-sizes.md) adds
`include_block_sizes: bool = false` to XZ one-shot and incremental options,
independently of parallel encoding. True declares both exact size VLIs in each
nonempty Block Header. False preserves framing and the prior non-aliasing
allocation/append order. The earlier [parallel baseline](xz-parallel-functional-baseline.md)
retains its frozen source, probe and reference epochs.

## Implementation and resource scope

The sized writer completes LZMA2 payload, including its zero end marker, before
declaring its length. Header/Padding/Check bytes are excluded from Compressed
Size; Uncompressed Size is original plaintext length. Shared header construction
writes canonical VLIs/filter descriptors/Header CRC. The block writer
recalculates alignment and Index unpadded records for stream termination. Checks
continue to cover original plaintext.

Alloc/Append/Into, stored/lazy and bounded parallel routes share the block writer.
Incremental full, flushed and final partial blocks forward the flag; reset
retains it and next-stream options can change it. Incremental encoding remains
serial. Wire comparisons use identical settings and block/flush boundaries.
The direct writer copies input overlapping the output allocation before header/
payload growth or Check computation in both modes, without adding a copy to
default non-aliasing writes.

| Resource control | Actual scope |
| --- | --- |
| Supplied allocator | Owns temporary complete payload, filter scratch and alias input copies in all routes |
| Explicit `ParallelOptions.max_working_memory` | Whole-operation requested heap, including the new storage and existing output/Index/codec allocations |
| Serial one-shot | No separate whole-operation heap-cap option; allocations use the supplied allocator |
| Incremental `max_pending_output_len` | Logical bytes awaiting publication, not all temporary or retained heap |
| `MatchOptions.max_working_memory` | Inner matcher/parser storage budget, not complete block payload storage |

Complete one-shot output staging and Index growth remain real storage. No
constant-memory, zero-allocation or RSS conclusion follows. Allocation/quota
failure and caller publication are checked within each API's existing contract;
incremental bytes returned by earlier calls cannot be rolled back.

## Completed gates

After documentation commit `c85fc634`, `git pull --rebase origin main` reports
the branch up to date. The [post-rebase record](data/xz-block-sizes-20261026/post-rebase.json)
and [raw logs](data/xz-block-sizes-20261026/post-rebase.tar.xz) retain a fresh
Debug run of 22 core, 112 root/consumer and 10 CLI executions: 144/144 passed,
with 205/205 combined build steps, actual Wasm fallback and CLI help. Global
checks use cached compilation; unfiltered root tests are not executed.
All 2011 final source hashes still match. The evidence manifest now covers 19
artifacts, including these two records, without relabeling earlier campaigns.

| Gate | Completed result | Scope |
| --- | --- | --- |
| Native Debug, native ReleaseFast and actual x86 Linux GNU ReleaseFast | Each 134/134 executions | 22 core (12 named plus 10 imports) and 112 root/consumer executions |
| Default-option earlier Debug XZ family | 161/161 | Earlier closed-option scope |
| Complete final native Debug XZ and consumer suites | 276/276 | 173 XZ plus 103 consumer executions |
| Combined Debug family/check/help | 202/202 build steps | Started before CLI flag integration; not final flag help evidence |
| Native and x86 external/reference matrices | Each 129/129 | 116 target encode cases, including five expected rejects, plus 13 original liblzma MT-encoder streams decoded by Vort |
| Cross-target status/wire comparison | 129 matching statuses, 124 matching artifacts | Artifact count includes 13 upstream inputs; not 124 target encodes |
| Default saved-wire preservation | 72/72 new wires equal saved bytes | 72 new original-reference full-content/exact-consumption checks; zero old runs or compiles |
| Actual Wasm runtime | 3/3 build/run steps | Two sized multi-block successes, two quota refusals and a 32-byte default-false control |
| CLI unit contracts | 10/10 executions | Nine named tests, including two new, plus one import |
| Actual public CLI-module campaign | 32/32 | 20 successful cases and 12 rejections preserving existing output |
| Final CLI/check/help Debug command | 201/201 build steps | Includes the final flag help and the 10 CLI unit executions |
| Separate final Debug check | 195/195 cached build steps | Compiles all new hooks/global root tests; does not execute the unfiltered root suite |

The 112 root/consumer total includes one named contract with five scenes and
imports, not 112 independent new codec cases. Global root tests are compiled by
`check`, not run. This increment does not claim a full-root ReleaseFast compile
or execution; ReleaseFast evidence is the bounded codec/root-consumer filters
on native/x86. Logged compiler/test MaxRSS and CLI help runtime are not encoder
resource or throughput measurements.

Core validation covers sized/default framing and payloads; Header sizes/CRC,
padding/Index/Footer; VLI boundaries and malformed declarations; destination
forms, stored/lazy, filters/checks/parsers/presets; matching serial/parallel and
incremental boundaries; partial flush/finish/reset/next-stream; downstream
consumers; alias relocation, short output, allocation failure and parallel
quota cleanup. CLI checks cover shorthand/exact booleans, preset order,
duplicate/malformed flags and explicit rejection on LZMA/raw LZMA2/MicroLZMA,
even when false.

## Actual reference worker activity

Each platform's matrix also performs 37 normal and one low-threading-memory MT
decode with the original library, and separately 37 plus one with the counter
library. These calls are additional checks within the campaign and are not
added to the 129 codec-case total. Both libraries verify complete plaintext,
body extents, caller guards and exact stream input consumption.

The worker-path input is 262177 bytes, split into nine blocks with a 32768-byte
block/chunk size and a 4096-byte dictionary. It requests three decoder threads,
64 MiB threading memory and 256 MiB stop memory. The original library succeeds;
the separately loaded counter library records these paths on both targets:

The Vort probes are built and executed separately for native x86-64 and
32-bit x86 Linux GNU. Both sets of compressed streams use the same 64-bit host
reference libraries and C adapter. This is not a 32-bit liblzma reference build;
its public stream/MT/LZMA-options struct sizes are 136/128/112 bytes.

| Decoder control | Completed worker jobs / distinct completed identities | Peak active decode calls | Direct blocks and reason |
| --- | --- | --- | --- |
| Sized nine-block stream | 9 / 3 | 3 | 0 |
| Same input, sizes disabled | 0 / 0 | 0 | 9 completed, 9 missing-size reasons |
| Sized nine-block stream, threading memory 1 byte | 0 / 0 | 0 | 9 completed, 9 memory-limit reasons |
| Sized single-block control | 1 / 1 | 1 | 0 |
| Empty control | 0 / 0 | 0 | No blocks |

The sized multiblock case also records 17 worker decode calls, three threads
entered/exited, no failed/abandoned jobs and no live jobs/calls/threads after
`lzma_end`. Invariant and identity-overflow counters are zero. Completed worker
identity and natural call overlap are evidence beyond configured thread count;
no artificial delay, barrier or timing threshold forces them. These observations
do not guarantee three active workers for other inputs/settings/platforms.
Both header sizes are necessary for the reference's threaded block path; Index
sizes are insufficient, and thread/memory/filter/I/O constraints still apply.

## Default wire, Wasm and source identities

The default gate compares 72 newly encoded native wires to previously saved
bytes, with 72 new liblzma 5.8.4 full-content/exact-consumption decodes. It runs
and compiles the old helper zero times. All 88 blocks lack optional size flags;
210 LZMA2 packets and a maximum 1872-byte input bound this old-public-API matrix.
The saved executable is the previous parallel gate's actual `12cab3c7...`
artifact, not a new build of `a7226f32`. The new helper is `5d3852d9...`.
Its 109-file source closure is stable across compilation/runtime; old source/
ELF/wire identities are archived separately, without an unrecorded `.h` binding.

The Wasm artifact runs in Node v26.10.0 without imports/WASI host, with a 4 MiB
FixedBufferAllocator, `std.Io.failing` and unsupported-target serial fallback.
Stored 8192-byte input produces eight blocks and 8480 wire bytes; fast-compressed
2048-byte input produces two blocks and 220 wire bytes. Both check Into/input
aliases, scalar Header CRC/canonical u64 VLI/packet lengths/original CRC-64,
serial-sized wire and public decode. Zero heap quota and a 1023-byte in-flight
cap below a 1024-byte block reject while preserving caller bytes/allocator
position. Heap peaks 19360 and 807224 are parallel-option requested-allocation
counters; live heap returns to zero and worker startup remains zero. The
default-false control encodes 32 bytes of input with zero size flags. The saved
runtime artifact is bound to its recorded executable and consumer/gate hashes.
Later test-only imports in the XZ facade do not turn it into a final-source rerun
or an all-source before/after equality claim.

Both differential reports retain `xz-block-sizes-epoch2-20261026` and a stable
118-file closure hash
`53d35bc3aff21a03b3bfcaa22dec8f399d7c14b10f2f82a4de1e08f580cdacbb`.
Native probe SHA-256 is
`4c82f4a6d7c2ad3696839b2ee858d8026840326da4ce749ad604b0485f4931e6`;
x86 probe SHA-256 is
`9482429dbdb88a4e2d37859fe31923c53cb11c3abe05e4414549b150e34fffc3`.
Final feature commit is `63a7dfa254f3567f906b35e73657c6cae4a1db56`. Its broader
2011-file source manifest SHA-256 is
`e1fc5c9ffb6f726a3cbfd7f8879fb2aec2ec3f5b870114d5bd498de24ea92569`.
The final snapshot does not refresh the earlier probe or Wasm runtime identities.

The original loaded liblzma 5.8.4 SHA-256 is
`03a333e8fd35e4c771c04ce93ab08dc0b8bbfa7615900179c53e1dd92a4d9ec0`, used
separately for ordinary decoding and upstream MT encoding/decoding. The 527-file
original reference tree digest is
`009cb7a779e309321560934707313c64ed2e3c607be13a6cde28c662a70be580`; the
528-file counter tree digest is
`6aae8aa4983d5e43763f7ce2ca99c1bc50a3bb0274d5c9e540cf08a2b218ea98`.
Counter library SHA-256 is
`5484343e9b9e0674f5ccf7f6ecfcbf24ba8bb4f37879dedfb5df83fb3050d85c`, and
C ABI adapter SHA-256 is
`b256261a2a670285150d94654dfe23cd24d494fc4b7558d932bf9a8ea315ef1b`.
The adapter is not linked to liblzma; explicit loading and library-owner proofs
bind each returned status to the selected library. The counter build records
79 actual object files and 352 dependency inputs. Its generated instrumentation
manifest SHA-256 is
`0c113f0939f190e2cd7e09c7f4d062dcb26a84cd4e7327ad04d517510a35723e`; patch
script SHA-256 is
`8ecd82d656ad58d5239469250f3da8c1f6af37f36a7386e52cd78c45dd3f373c`.
Full source indices, patch/header, compiler/configure/build/adapter commands and
actual-object input manifests keep those scopes reproducible.

The [repository evidence bundle](data/xz-block-sizes-20261026/) preserves the
actual artifacts and independent scopes:

| Evidence | Archive or manifest |
| --- | --- |
| Native differential, generated inputs/wires and per-call results | [native.tar.xz](data/xz-block-sizes-20261026/native.tar.xz) |
| Actual x86 differential and artifacts | [x86.tar.xz](data/xz-block-sizes-20261026/x86.tar.xz) |
| Saved/default parity, old/new ELF/source bindings and full content checks | [legacy-parity.tar.xz](data/xz-block-sizes-20261026/legacy-parity.tar.xz) |
| Actual public CLI-module executable/cases/output guards | [cli.tar.xz](data/xz-block-sizes-20261026/cli.tar.xz) |
| Original/counter liblzma, full source/build inputs, patch/adapter and licenses | [reference.tar.xz](data/xz-block-sizes-20261026/reference.tar.xz) |
| Frozen reference build/provenance records for review | [reference-build.json](data/xz-block-sizes-20261026/reference-build.json), [reference-provenance.json](data/xz-block-sizes-20261026/reference-provenance.json) |
| Frozen native/x86 probe executables | [probes.tar.xz](data/xz-block-sizes-20261026/probes.tar.xz) |
| Actual Wasm executable, consumer/gate snapshots and report | [wasm.tar.xz](data/xz-block-sizes-20261026/wasm.tar.xz), [wasm-report.json](data/xz-block-sizes-20261026/wasm-report.json) |
| Terminal and earlier logs | [logs.tar.xz](data/xz-block-sizes-20261026/logs.tar.xz) |
| CPU/host/compiler/runtime environment | [environment.json](data/xz-block-sizes-20261026/environment.json) |
| Cross-target status/artifact comparisons | [cross-target.json](data/xz-block-sizes-20261026/cross-target.json) |
| Final 2011-file source snapshot and zero-mismatch feature verification | [final-source-manifest.json](data/xz-block-sizes-20261026/final-source-manifest.json), [source-verification.json](data/xz-block-sizes-20261026/source-verification.json) |
| Completed validation counts and log/report hashes | [validation-summary.json](data/xz-block-sizes-20261026/validation-summary.json) |
| Archive content hash verification | [archive-verification.json](data/xz-block-sizes-20261026/archive-verification.json) |
| Seventeen archived artifact hashes, excluding this manifest itself | [evidence-manifest.json](data/xz-block-sizes-20261026/evidence-manifest.json) |

Raw evidence remains under `/tmp/vort-xz-block-sizes-20261026`. The functional
host is Intel Core i7-10700K/Linux, Zig 0.16.0, Python 3.10.12 and Node v26.10.0;
per-artifact target/build/library identities remain those recorded above.
Archive verification records 772 files each for native/x86, 98 CLI files,
383 manifest-listed legacy files (384 including its manifest), 16 raw log files,
all 527 original and 528 patched reference source files, 79 actual objects, three
probe executables and the saved Wasm executable. The evidence manifest records
17 artifact hashes and excludes itself. Separate build/provenance JSON copies
are the frozen records, not refreshed report identities.

This increment's formal validation has no failed compile/runtime campaign or
runtime codec repair. Zero-compressed-size header defense, exact C adapter
status handling and complete provenance checks were revised before execution.
Logs named initial retain their actual successful scope; later aggregate checks
do not rewrite those source/probe epochs. The earlier parallel baseline's failed
build history remains separate. Subsequent rebase/reverification records also
need their own scope.

This is bounded functional/compatibility and observed reference-activity
evidence, not full liblzma MT feature parity, all-platform guarantees or industry
performance leadership. The next functional slice is bounded parallel
incremental encoding; broader ratio/throughput/memory comparisons need their
own reproducible benchmark scope.
