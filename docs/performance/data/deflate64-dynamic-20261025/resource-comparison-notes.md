# Deflate64 dynamic resource report audit

Both supplied native reports independently passed `tools/deflate64_index_gate.py::validate(report, label)`. The gate's `main()` was not used, because this increment intentionally changes one encoded wire. Input identities, default options (`max_chain=128`, `nice_length=128`), encoded bounds, round-trip assertions, and allocation cleanup passed the same strict checks.

| Case | Old wire B | New wire B | Old requested peak B | New requested peak B |
|---|---:|---:|---:|---:|
| empty | 2 | 2 | 2 | 2 |
| tiny16 | 18 | 18 | 131154 | 131154 |
| pattern12079 | 46 | 46 | 196654 | 196654 |
| random4097 | 4102 | 4102 | 167942 | 167942 |
| random16387 | 16392 | 16392 | 278536 | 278536 |
| repeat65539 | 6 | 6 | 393222 | 393222 |
| distant131072 | 69098 | 65633 | 462314 | 458849 |

Six one-shot case records are unchanged. For `distant131072`, wire size falls from 69,098 to 65,633 bytes and requested peak from 462,314 to 458,849 bytes. Both deltas are exactly 3,465 bytes. The non-output allocation events remain 131,072-byte heads and 262,144-byte previous storage, totaling 393,216 bytes. In both reports peak minus returned output is 393,216 bytes; the current requested amount at return equals wire length. The observed peak reduction is attributable to the smaller output allocation, not a matcher/workspace reduction. The wire hashes intentionally differ and both reports assert round-trip verification.

The complete streaming records are identical: 4 MiB reused-block input, 6,328-byte wire, SHA-256 `8a65c2566ddf379fe22dffbb6e8be754fd2f8d30d65c7cee63145b252db4a8fc`, 1,025 steps, retained/peak requested bytes 462,909, and zero requested bytes/live allocations after deinit. All growth checkpoints, allocation events, cleanup-failure counts and memory conservation fields match exactly.

These numbers measure requested live heap allocations through the probe's codec allocator, including output until caller free. They do not measure RSS, page rounding, allocator metadata, dynamic Huffman planning's stack trees, stack high-water, or whole-process memory. Raw remap physical transients are outside the logical API ledger. New dynamic planning may add stack work not reflected here; no reduction in total memory or stack footprint is claimed.

All new one-shot timing values are null. This read-only audit does not compile, run an encoder, or establish a timing comparison. Old/new CPU-affinity provenance differs and is preserved in the JSON rather than treated as comparable timing evidence.

The old supplied source manifest binds commit `d69caf3d0de0afbcf773fea0524ad20060db8a32`. The final candidate manifest binds commit `02b6498aa2e24fdf7e09eb1f194bc680aeac7b7f` and 1890 source/tool files, SHA-256 `5c39685857351c98b13d969d73fa80a7ea19ecadadfc710ecb5401be289cd2bc`. There is no pending source binding. The parent rebuilt the resource executable after two comment clarifications; this audit independently validated that final report and the preserved pre-comment report. Every one-shot resource row, complete streaming record, and codec option is exactly unchanged. Only executable identity and command provenance differ. Final report SHA-256 is `b995416df1fa1599b321d3fc306d43e63acfda0bcc9ffe47072fca4446a832e2`. This audit did not recreate a source snapshot or perform a build/encoding run.
