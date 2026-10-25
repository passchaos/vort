# Winner cost bound allocation verification

Old main at `27dcca45` and the candidate each ran the identical Vort-only public `encodeFrameWithLevelAlloc` level-3 probe once for the same 65,536-byte XML input. Both executables linked one `vort_zstd` module and their own source tree's X2 object. Builds used CPUs 13–15; sequential executions used CPU 8.

| Metric | Old main | Candidate |
|---|---:|---:|
| Output bytes | 5,078 | 5,078 |
| Peak requested heap bytes | 2,561,185 | 2,561,185 |
| Successful allocations | 115 | 115 |
| Remap requests / successes | 51 / 51 | 51 / 51 |
| Resize requests | 0 | 0 |
| Live bytes after return | 5,078 | 5,078 |
| Live bytes after caller free | 0 | 0 |
| Increased / released bytes after cleanup | 4,462,540 / 4,462,540 | 4,462,540 / 4,462,540 |

All 282 allocation/free events, including the optional tiny-payload forced OOM request, are identical. Both outputs match SHA-256 `795448b31e4039831d40f1ee39d322865f8d32ef9f673d99d73aca17d4827c92`. The tiny forced first allocation failure returns `OutOfMemory` with zero live bytes in both executables.

Requested heap includes all byte requests through the public caller allocator wrapper, with returned output charged until explicit caller free. The backing allocator is Zig `page_allocator`. Embedded caller input, tracker/codec stack state, executable mappings, allocator bookkeeping and OS page rounding are excluded. RSS and wall-clock data were not collected. This is an allocator correctness and regression check, not a performance benchmark or a C-reference memory comparison.

Source hashes before/after compilation and execution remain stable. Full commands, source/executable/object hashes, event ledgers, and final results are stored alongside this report. No repository sources or Git state were edited by this task.
