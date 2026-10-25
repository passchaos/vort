# Single-sequence pricing allocation verification

The old production tree at `5928518f` and candidate each ran the same Vort-only `encodeFrameWithLevelAlloc` level-3 XML probe once, followed by one tiny first-allocation OOM check. Each executable imported exactly one `vort_zstd` module and linked its own source tree's X2 object. Compilation used CPUs 13–15; sequential heap-only executions used CPU 8.

| Metric | Old production | Candidate |
|---|---:|---:|
| XML input bytes | 65,536 | 65,536 |
| Output bytes | 5,078 | 5,078 |
| Peak requested heap bytes | 2,561,185 | 2,561,185 |
| Successful allocations | 115 | 115 |
| Remap requests / successes | 51 / 51 | 51 / 51 |
| Resize requests | 0 | 0 |
| Live requested heap after return | 5,078 | 5,078 |
| Live requested heap after caller free | 0 | 0 |
| Increased / released bytes after cleanup | 4,462,540 / 4,462,540 | 4,462,540 / 4,462,540 |

All 282 allocation and release events are identical. Outputs match SHA-256 `795448b31e4039831d40f1ee39d322865f8d32ef9f673d99d73aca17d4827c92`. Both tiny forced first allocations return `OutOfMemory` with zero live bytes.

This measures caller allocator requests, including returned output until its explicit caller free. The backing allocator is Zig `page_allocator`; embedded input, codec/tracker stack locals, executable mappings, allocator bookkeeping and OS page rounding are excluded. No per-request limit or total budget is imposed on the XML control. No RSS or wall-clock metric was collected, no C encoder ran, and no speed or competitor-memory conclusion is made.

Source hashes before/after compilation and execution remain stable. The independent probe and fixture hashes are unchanged from preparation. Build/execute commands, source identities, executable/object hashes and all event ledgers are stored in this directory. Each XML executable ran once; the 14-sample timing baseline was not repeated here. No repository sources or Git state were edited by this task.

Source binding uses full `src/**/*.zig` snapshots, not the root hash alone. Old worktree is `/home/passchaos/project-z/vort`, HEAD `5928518f0c6dc4cea028dba3c6692a7128b74275`, with weighted bound SHA-256 `e45b292daca0a33a5840f21543cf0ae93396db65072ab9aa4562def89ab4a890` and frequency reduction SHA-256 `34ee2d73fb003ae301e9642a9cd61ef366aaccefa856baff2cae56166347eb2b`. `source-bindings.json` lists relevant transitive modules and the complete manifest identities.
