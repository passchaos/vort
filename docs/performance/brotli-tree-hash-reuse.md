# Brotli tree-cache hash reuse

Date: 2026-10-28. Baseline: `3dd41759`, including the fused suffix bounds and
independent large-window writer frames. Industry-best functionality and
performance remain incomplete.

The q8 context search hashes all 256 tree frequencies before a memo lookup.
On a miss it builds an exact Huffman score, then used to hash the same immutable
frequency vector again before publishing. Lookup and publication now share one
hash. The existing set selection, complete-vector comparison, replacement,
owner-mode reporting and publication after successful scoring stay identical.
No cache storage or heap allocation is added.

Two direct tests cover 1,024 collision-heavy lookup/publication requests with
complete legacy/reused cache-state equality, and supplied hash collisions that
must still reject a different vector. The focused Debug filter passes 81/81.
Complete q8 stage reports for Mozilla, Dickens and MR preserve all context
non-timing fields, including cache hits/misses, replacements' classifications,
scorer calls and selected proposals; output hashes also agree.
An actual wasm32-wasi ReleaseFast consumer repeats 1,024 conflict-heavy
requests and compares the complete cache state after hash reuse. Node runs
the frozen module with no host imports and returns zero.

## Ordinary encoding evidence

An exploratory ordinary q8-only harness runs 18 prefixes (six Silesia files,
4/16/64 KiB), seven alternating process blocks and five encode calls per
sample. The per-case median time geometric ratio is 0.98757. This harness
times the public allocating call and validates output outside its timer.

The final existing public encoding benchmark compares all twelve Silesia files
at 4/16/64 KiB, for 36 cases. Three reversed-order version sweeps each contain
five alternating Vort/reference rounds of three calls, reduced to per-case
median ordinary time. Every Vort/reference input, wire and settings identity
matches across versions and sweeps; each row reports actual windows 16/16 and
matching q8/generic parameters.

| Quantity | Geometric ratio |
| --- | ---: |
| Candidate / baseline ordinary encoding time | 0.990625 |
| Candidate / Brotli 1.2.0 reference encoding time | 40.1957 |
| Candidate / reference encoded size | 0.995560 |

The final point measurement improves Vort time by about 0.94%. It does not
establish statistical significance or an improvement on every row. Matching
parameters reveal a much larger remaining throughput gap: Vort takes about
40 times the reference time in this corpus aggregate, with similar sizes.
The reference is the clean local Brotli 1.2.0 checkout `558fc64`, built with
GCC Release `-O3 -DNDEBUG -march=native`; Vort uses Zig 0.16.0 ReleaseFast,
native x86_64 `skylake+pku+sgx`. CPU is an i7-10700K, one codec thread pinned
to CPU 2. Compiler work excludes that CPU and sibling 10. Explicit reference
files, their API versions and hashes are recorded; loader dependency closure
is not independently certified.

The pure q8 cycle profile identifies context clustering/tree scoring and
optimal parsing; stage reports also show repeated full wire trials as a major
cost. Reduce repeated writer preparation and emission while preserving exact
byte-length arbitration and the full candidate policy next.

[Raw rounds, per-case results, source/build identities and runners](data/brotli-tree-hash-reuse-20261028/)
retain this source epoch separately from the earlier suffix and Wasm fixes.

Final native/Wasm compile validation passes 210/210 steps. After remote rebase,
the focused library and actual reference-parameter tests pass 93/93 (81/12),
18 Python metadata/path tests pass, and the original file fixture retains its
explicit auxiliary ratio requirement. The frozen Wasm protocol consumer again
passes 1,024 requests with a matching cache-source hash. Actual CLI help also
completes; explicit exits and complete logs are retained with the evidence.
