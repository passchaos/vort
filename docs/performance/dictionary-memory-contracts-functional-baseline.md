# Dictionary recovery and streaming allocation contracts

Date: 2026-10-24. Zig 0.16.0, Linux x86-64, Intel Core i7-10700K.
This extends the [native resource baseline](stream-contracts-functional-baseline.md)
and [XZ progressive baseline](xz-progressive-functional-baseline.md). It records
functional behavior and requested-allocation accounting, not throughput or RSS
leadership.

## Native dictionary recovery

Zstd/LZ4 incremental decoders parse a complete validated frame header before
reporting a nonzero unresolved dictionary ID. `requiredDictionaryId()` exposes
that request; waiting `step` and `finish` return `NeedDictionary` with zero new
progress. The already-accepted header and previous members' counters, output
pledge and work budget are retained.

`provideDictionary` rejects a different declared ID with `DictionaryMismatch`.
`provideDictionarySet` without the requested entry returns `NeedDictionary`.
Both preserve the request. Zstd checks full standard dictionary metadata before
installing an override; inconsistent metadata is `InvalidDictionaryMetadata`.
ID zero does not invent a request. LZ4's IDs are application numbers and do not
authenticate dictionary bytes.

Provided bytes are borrowed only for the current frame, through completion,
terminal failure, reset or deinit. The override takes priority over a configured
set miss but never replaces the original configured dictionary/catalog. A
temporary catalog can be released after selection while its selected dictionary
bytes remain alive. Fatal errors clear provided-content views and remain sticky.

Advance caller input/output by `snapshot().last_step_progress` after the first
request, provide the matching dictionary, then continue with unconsumed input.
The decoder reuses its retained header. A subsequent member independently
resolves its ID. Diagnostics distinguish dictionary retry from payload errors.

LZ4 prevalidated linked blocks now seed dictionary history before switching to
small-output cursors. Their virtual-prefix preflight handles unlimited output
limits without overflowing or changing the real cumulative allowance.

## LZMA-Alone

`max_working_memory` bounds the persistent probability, dictionary and compressed
allocations. Symbol staging is fixed at 273 bytes. Initialization allocates
nothing, reset retains capacity, and successful reconfiguration releases old
owned storage through the original budget. The existing void reset-with-options
signature records invalid settings without discarding valid owned state;
`Options.validate()` allows an immediate check.

Small ZIP end-marker lookahead uses a read-only symbol preflight: fixed model
and range state plus only the current 768-entry literal row are copied to
stack storage. LC/LP row selection and matched-literal history remain exact.
Incomplete input never mutates the live model. Positive symbols require caller
output space; EOS may commit without output after restoring original properties
and the owned literal-probability slice. Known-size completion retains its
established coded-tail behavior.

Error snapshots report accepted input and actual published output. Probability
or dictionary changes before failure cannot be replayed: fatal errors are sticky
until reset. Current/peak requested heap bytes and failed-call offsets are
public. Active values retain single ownership without storing callbacks to a
former stack-local budget.

## Brotli

Owned and caller-history incremental decoders have consistent failed-call
progress, fatal sticky behavior and cumulative output limits. The owned facade's
`max_working_memory` accounts for history, header storage and replacement buffers
while old and new allocations are simultaneously live. Caller-supplied history
and header scratch remain caller-owned and do not become hidden allocations.

`max_output_len` and output pledges retain frame scope; `max_total_output_len`
limits the logical operation across `nextFrame`. Frame transitions preserve
totals and peaks and can only tighten operation limits. A new limit below
published output or live capacity is rejected before changing state. Reset
starts a new operation, and explicit reconfiguration validates before releasing
storage.

Physical caller-header exhaustion retains its existing
`UnsupportedBrotliFeature` error and carries a `grow_compressed_header` hint;
larger scratch can resume accepted bytes without replay. Other unsupported or
corrupt payload errors remain fatal. Header batches are clipped to available
capacity and parsed before requesting growth, so a retry cannot backtrack
payload accepted in a previous call.

## Evidence and reproduction

The final source contract aggregate passes 53 tests in both Debug and
ReleaseFast. ZIP/TAR/CPIO consumer integration passes 70 ReleaseFast tests.
Complete codec runs pass 839 native Zstd/LZ4 tests, 62 LZMA tests and 980 Brotli
tests; the final native borrowed-view and Brotli header-boundary refinements
are also covered by the final contract aggregate and independent probes.
The final build check passes all 131 steps, including wasm32-wasi, and the
Debug CLI help smoke succeeds.

Native reference coverage passes 271 cases over 38 libzstd/liblz4 frames:
279 dictionary requests, 279 wrong-ID rejections, 279 set misses, eight exact
budget checks, 16 allocation failures and 12 fatal sticky cases. Reference
versions are libzstd 1.4.8 and liblz4 1.9.3. Explicit-ID raw-content Zstd cases
document their header conversion and independently validated reference
dictionary, rather than claiming the upstream raw encoder emits those IDs.

LZMA reference cases include Python/xz EOS streams and proper known-size/no-EOS
streams written through the public writer and independently decoded by
liblzma/xz. Header-rewritten EOS samples are labeled separately and are not
claimed as successful liblzma known-size encodings. Brotli uses libbrotli 1.2.0,
including metadata, compound dictionaries and Large Window frames.

| Independent validation | Streams | Runs | Allocation failure checks |
| --- | ---: | ---: | ---: |
| Native dictionary recovery, ReleaseFast | 38 | 271 | 16 |
| LZMA-Alone, ReleaseSafe | 31 | 162 | 20 |
| Brotli owned/caller history, ReleaseSafe | 26 | 268 | 8 |

Brotli header replacement is measured through a public workflow: exhaust a
16385-byte header cap, reset retaining capacity, decode a small reference frame,
then call `nextFrame` with a 32768-byte cap and decode the larger header. Old
and new header allocations are simultaneously live, giving a requested peak of
49154 bytes. That exact budget succeeds; one byte less fails with correct
published progress. Eight additional caller-header endpoint cases preserve a
32-byte suffix without spurious growth or cross-call input rollback.

The native JSON stores 69 source hashes; LZMA and Brotli reports store 21 and
85 source hashes respectively. Source, driver and probe hashes match the
validated files. Exact corpus provenance, versions, commands and failures are
retained in [the native dictionary JSON](data/native-dictionary-resume-x86-20261024.json),
[LZMA JSON](data/lzma-memory-contracts-x86-20261024.json) and
[Brotli JSON](data/brotli-memory-contracts-x86-20261024.json). These measurements
describe the recorded corpora and are not general memory upper bounds.

```sh
zig build test-codec-stream-contracts
zig build test-codec-stream-contracts test-stream-contract-consumers -Doptimize=ReleaseFast
zig build run-native-dictionary-resume-diff -Doptimize=ReleaseFast -- --report /tmp/native-dictionary.json
zig build run-lzma-contract-diff -Doptimize=ReleaseSafe -- --report /tmp/lzma-contracts.json
zig build run-br-stream-contract-diff -Doptimize=ReleaseSafe -- --report /tmp/br-contracts.json
zig build check --summary all
```

Requested-byte budgets exclude fixed state, stack preflight, caller buffers,
allocator metadata and allocator-internal remap transients. Broader real-file
allocation/RSS, speed/ratio comparisons and Bzip2/Snappy resource-contract
parity remain future work before an industry-best claim.
