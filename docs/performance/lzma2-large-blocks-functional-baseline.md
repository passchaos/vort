# Large LZMA dictionaries and LZMA2 chunks

Date: 2026-10-24. Source and tools revision: `d4623d8a`.

Custom LZMA encoder dictionaries now cover 4 KiB...1.5 GiB, matching liblzma's
encoding range. Raw LZMA2 and XZ expose `chunk_size` from one byte through
2 MiB. Compressed packets use all 21 plaintext-length bits, while completed
range payloads and individual stored packets remain bounded to 64 KiB.
These are functionality, interoperability and resource-contract claims; this
milestone does not establish competing compression performance leadership.

## Contracts

The [encoder contract](../formats/lzma-encode-controls.md) records defaults,
ownership and the optional raw incremental pending limit. The twenty preset
dictionary values and 64 KiB default chunk size remain unchanged. Large groups
serialize as one compressed packet when its complete size beats the complete
stored alternative, otherwise as up to 32 stored packets. Only
`CompressedPayloadLimitExceeded` permits that fallback; allocation and matcher
budget failures propagate. Range capacity includes its cache and flush tail.

Packet groups commit model/history state only after successful output checks.
Raw incremental snapshots distinguish accepted, encoded and delivered bytes;
failed groups retain accepted input for retry. Null `max_pending_output_len`
derives a bound from the input group, and the original 64 KiB configuration
still evaluates to 65552. Explicit limits remain unchanged.

The bounded short-repeat regression uses a real retained LZMA model. A four-byte
cap rejects a one-byte rep0 without committing model/range/output/statistics;
a five-byte cap succeeds and flushes exactly five bytes. Work profiles retain
actual attempted coding. Scalar and pointer/size arithmetic are checked before
output mutation, and overlapping stored input is retained through growth.

## Validation

The final Debug and ReleaseFast large-block gates each pass 67/67 executions:
30 LZMA and 37 XZ/LZMA2, including 53 named tests and 14 import roots.
[Contract evidence](data/lzma2-large-blocks-contracts-x86-20261024.json) records
the actual test names and 87 stable before/after source/build hashes.
The complete XZ family separately passes 143/143. The other family
and consumer gates pass LZMA 162, XZ consumers 85 and stream-contract consumers
79. The former property test expecting the current maximum to map to 28 was
corrected: explicit 64 MiB still maps to 28, 1 GiB to 36 and 1.5 GiB to 37.
This changes test data only; codec production bytes remain identical.

All 140 complete build-check steps pass, as do the wasm32-wasi library check
and compile-only ARM64 large-chunk and big-endian PowerPC dictionary/cap tests.
The complete Debug CLI help exposes the new settings.

[The reference campaign](data/lzma2-large-blocks-functional-x86-20261024.json)
uses liblzma 5.8.4 with matching headers/runtime and records 26 chunk/control
rows, six dictionary-property rows and fifty frozen legacy wire comparisons.
Raw and XZ one-shot/incremental outputs match, and real 2 MiB compressed and
32-packet stored groups round-trip in both directions. A following compressed
packet correctly carries the necessary model/properties reset.

[The CLI evidence](data/lzma2-large-blocks-cli-x86-20261024.json) passes 101
round-trips, 112 rejected-output preservation cases, five flag-order checks and
twenty profile byte comparisons. It separately verifies two 2 MiB XZ results,
two completed payload limits, a large-chunk profile comparison, and maximum
dictionary encoding followed by Vort bounded full decode. The 1429-file
before/after snapshots match, and all 979 actual compiled inputs match their
recorded content. A later property-test-only delta is disclosed and its codec
production prefix is proven byte-identical to the saved compiler snapshot.

The maximum-dictionary 64-byte CLI sample peaks at 1,574,668 requested encoder
bytes within a 4 MiB budget and 12,352 decoder bytes within a 64 KiB budget.
These are owned allocation ledgers, not process RSS.

## Actual distance and reference scope

[The explicit ReleaseFast distance evidence](data/lzma-large-distance-core-x86-20261024.json)
uses a real dictionary and match distance of 67,108,865 bytes, length 64. HC3,
BT4, legacy wide and the advanced planner find the same distance; the token
encodes into a ten-byte LZMA payload with rep0=67,108,864. HC3 matcher arrays
request 1,074,790,432 bytes and BT4 requests 1,612,185,648, plus 67,108,865
dictionary bytes. The evidence records exact source hashes, successful output
and the later label-only change used to keep this expensive test out of routine
gates. The subsequent small prefix-tail fix is recorded separately; the heavy
body is unchanged.

Maximum dictionary metadata and full reference decoding are separate evidence.
Liblzma recognizes the original 1.5 GiB Alone header and returns MEMLIMIT under
the specified small budget. It estimates 1,610,678,752 bytes for decoding;
known plaintext size does not eliminate that reference allocation. This is
header acceptance, not a complete large-window reference decode. Actual chunk
interop uses moderate dictionaries; Vort's own full bounded small-input decode
is independently exercised. No report substitutes a changed small dictionary
header for an original-container full decode claim.

## Reproduction and remaining work

```sh
zig build test-lzma2-large-blocks -j2 --summary all
zig build test-lzma2-large-blocks -Doptimize=ReleaseFast -j2 --summary all
zig build test-lzma-large-distance -Doptimize=ReleaseFast
zig build test-lzma test-xz test-xz-consumers test-stream-contract-consumers -Doptimize=ReleaseFast -j4 --summary all
zig build test-lzma-xz-cli-controls -j2 --summary all
zig build check -j4 --summary all
python3 tools/lzma/large_blocks_diff.py --reference /tmp/vort-large-blocks-reference.so --probe /tmp/vort-large-blocks-final-probe --legacy-prepared /tmp/vort-lzma-controls-prepared2 --output-dir /tmp/large-blocks-validation
zig build run-lzma2-large-blocks-diff -Doptimize=ReleaseFast -- --reference /tmp/vort-large-blocks-reference.so --legacy-prepared /tmp/vort-lzma-controls-prepared2 --output-dir /tmp/large-blocks-validation
```

The explicit distance gate needs substantial memory and runs independently.
Reference full maximum-dictionary decoding requires an explicit sufficient
`--large-dictionary-budget`; default reference checks remain bounded.
Performance parity still requires current-reference corpus measurements and
further HQ modeling. XZ blocks remain independent, with a 1 MiB default outer
block; use an outer block of at least 2 MiB to emit a full-size chunk.
