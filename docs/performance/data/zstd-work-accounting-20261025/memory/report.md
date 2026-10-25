# Work accounting allocation verification

Old production at `e4bfdd63` and the candidate each executed the identical public Vort `encodeFrameWithLevelAlloc` level-3 XML probe once, followed by one tiny forced first-allocation OOM check. Each executable linked one `vort_zstd` module and its own X2 object. Compilation used CPUs 13–15; sequential allocator verification used CPU 8.

Both outputs are 5,078 bytes with SHA-256 `795448b31e4039831d40f1ee39d322865f8d32ef9f673d99d73aca17d4827c92`. All 282 allocation/free events are identical. Requested heap peak is 2,561,185 bytes in both versions, with 115 successful allocations, 51 successful remaps and no resizes. Only the 5,078-byte caller output remains live at return; caller free leaves zero live bytes. Increased and released bytes both total 4,462,540. Both tiny forced allocation failures return `OutOfMemory` with zero live bytes.

The candidate HEAD advanced from `e4bfdd63` to `a8defd42` during its successful compilation. The extra HEAD-equality audit assertion reported that transition; all compilation commands exited zero and every source byte hash remained unchanged. That audit is preserved in `new-build.json` and `head-transition.json`. The already-built executable was admitted against the complete unchanged source snapshot, and was not rebuilt. Its single resource execution ran with HEAD `a8defd42`, unchanged before/after.

Complete src snapshots bind both compilations and executions. `source-bindings.json` also lists weighted, reduction, Huffman, literal caches and single-sequence module hashes; root hash alone is not treated as complete code identity.

Requested heap includes requests through the caller allocator and returned output until explicit free. The backing allocator is Zig `page_allocator`; caller input, fixed tracker/codec stack, executable mappings, allocator bookkeeping and OS page rounding are excluded. No RSS or wall-clock metric was collected, no C encoder ran, and these results make no performance claim. This task changed only its own `/tmp` artifacts and did not mutate source or Git state.

Separate parent-coordinated, source-matched `sizeof` evidence in `../state-analysis.json` reports tracked/untracked cache objects of 6,032/5,568 bytes on native and 5,980/5,516 bytes on x86, a 464-byte object-state reduction. These compiled object sizes are outside requested heap and do not establish total stack high-water or RSS reduction. The independent heap probe tracker itself is 16,528 bytes of fixed local state per value. No additional probe was compiled or run to obtain this report.
