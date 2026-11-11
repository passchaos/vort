# Raw Deflate caller-output overlap admission, 2026-11-11

Commit `f74ca1fefd26b35936af94a719ae6bdd9c2c7494` rejects overlapping
caller output for contiguous Raw Deflate decoding with `InvalidBlockPlan`
before decoder writes. Its base is
`6618b0c5833bf48dcc1a3cb99b9cec238f9e67b1`. The reproduced failure included
silent corruption across stored blocks even with runtime safety enabled:
the first block's output replaced a later block's compressed payload.

The complete output slice must be disjoint from the complete compressed
input and preset dictionary. This protects unused output capacity, trailing
input beyond the first member, and the original prefix skipped during sync
recovery. Input and dictionary remain read borrows and may overlap each
other. Half-open endpoint adjacency and empty slices remain valid borrows.
The guard compares range starts by subtraction without adding lengths to
addresses. Empty-input and missing-sync-marker errors retain their existing
behavior; the rejection contract concerns output overlap before writes.

| Public surface | Coverage in this repair |
| --- | --- |
| `decodeRawAuto` / root `decodeRawDeflate` | Complete contiguous input/output borrow admission |
| `decodeRawAutoWithDictionary` / root `decodeRawDeflateWithDictionary` | Output disjoint from input and dictionary; shared read storage allowed |
| `decodeRawFixed` | Contiguous fixed-block output admission |
| `decodeRawStored` / root `decodeRawStoredDeflate` | Contiguous stored-block output admission, including future block payloads |
| `decodeRawDeflateAfterSync` | Original complete input protected after sync discovery |
| Allocating/append, chunks/scratch, zlib/gzip, incremental | Separate ownership surfaces; this round makes no additional claim about them |

The borrow contract is documented in
[`docs/formats/deflate-decode-borrows.md`](../formats/deflate-decode-borrows.md).

| Reproduced case | Before ReleaseSafe | Before ReleaseFast | After both modes |
| --- | --- | --- | --- |
| Dictionary match, expected `Xabcdefghijklmnop` | `@memcpy arguments alias` panic, exit 134 | Incorrect `Xaacdeeghhikllnop`, exit 0 | `InvalidBlockPlan`; entire backing unchanged |
| Stored overlap, expected `abcd` | `@memcpy arguments alias` panic, exit 134 | Incorrect `dbcd`, exit 0 | `InvalidBlockPlan`; entire backing unchanged |
| Future stored payload through auto API, expected `abcdef` | Incorrect `abcabc`, exit 0 | Incorrect `abcabc`, exit 0 | `InvalidBlockPlan`; entire backing unchanged |
| Future stored payload through stored API, expected `abcdef` | Incorrect `abcabc`, exit 0 | Incorrect `abcabc`, exit 0 | `InvalidBlockPlan`; entire backing unchanged |

All eight repaired standalone probe runs exited 0 and preserved the backing
bytes. The focused contract contains **81 core rejection scenarios** plus
successful controls: overlap directions, containment, unused output tail,
full-input tail, dictionaries, future payloads, sync prefix, endpoint adjacency,
empty output, shared read borrows, precise consumption, and strict trailing-data
behavior. Rejected calls leave the same input/dictionary available for
independent retry. The package root adds four public facade rejection checks
and a successful independent decode.

The completed focused ReleaseSafe, Debug, and native x86_64 gates each passed
6/6 aggregate tests. Root validation passed 11/11 build steps and 94/94 tests;
the full Deflate module passed 695/695 tests. The actual wasm32 WASI run
started under Node v26.10.0 and returned exit 0, with a receipt bound to the
archived module. These executions finished before evidence packaging.

The final rebuilt probe then exercised all **72 frozen Silesia Raw Deflate
wires**: 12 files, 64 KiB / 1 MiB / full sizes, producer levels 6/9. All rows
passed full-output, output-count, 64-byte guard, input immutability, and exposed
exact-consumption validation against libdeflate 1.26. Each row used one decode
per side, two balanced pairs, and no warmup, yielding 144 paired batches.
The recorded durations demonstrate functional compatibility and benchmark
executability. This smoke does not support throughput, confidence-interval,
parity, or optimization conclusions.

The [evidence package](deflate-raw-output-alias-20261111/README.md) preserves
exact before/after logs, native gate logs, five small independently inflated
fixtures, the WASI module and receipt, all 72 smoke rows and stderr files,
the original runner, five committed source files, and the exact final probe.
Its independent validator checks the byte and source bindings, re-inflates
the five small fixtures with Python zlib, and verifies the recorded smoke
contracts without rerunning codec probes or benchmarks.
