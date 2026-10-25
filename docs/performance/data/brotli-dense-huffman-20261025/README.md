# Brotli dense Huffman evidence, 2026-10-25

Baseline runtime is f642d0d8. The candidate adds a 256-symbol natural Huffman
attempt with exact ranked arrays and the original max15 package-merge fallback,
and safely rejects excessive depths in existing small kernels.

- `baseline14/`: current f642 ordinary q8 baseline, full source/executable/input/
  requested competitor-file hashes, five raw rounds/input and compiler monitor.
- `dense-debug/`, `dense-x86/`: initial QA assumed all random weights succeed.
- `dense-debug-fixed/`, `dense-x86-fixed/`: random acceptance corrected, but a
  redundant dense-only >31 depth expectation still failed. All inner kernel
  and Prefix integration checks already passed.
- `dense-debug-final/`, `dense-releasefast/`, `dense-x86-final/`: final21/21
  exact tests. The fixed34-Fibonacci natural-depth33 test remains; dense
  distributions only require their independently computed >15 rejection.
- `micro-build/`: functional smoke incorrectly disallowed a real mixed fallback.
  `micro-build-fixed/` accepts and reports mixed1/32 while retaining ties0/32
  and deliberate-fallback32/32. No input or cap was altered to avoid fallback.
  Its producer/test-source epoch is recorded in full snapshots; later QA-only
  fixes retain the same runtime kernels/tool. `microbench/` is the compiler-free
  accepted20000-iteration/five-round measurement, bound to that executable.
- `old-depth-probe.*`: attempted direct old-module reproduction fails import
  boundaries due its test imports. `old_small_huffman_core.zig` is the exact
  ordinary function prefix, with test definitions excluded; its extraction and
  full old source hashes are in `old-depth-core-probe.json`. Actual Debug
  execution of sorted34Fibonacci triggers the old u5 overflow.
- `br-family/`, `complete-check/`, `legacy-profile-gates/`, `cli-help/`:
  frozen final-runtime validation, including1423pass/one skip and174checks.
- `public14/`, `profile14/`, `paired14/`: accepted ordinary, actual context and
  three alternating old/candidate process-pair evidence with source/identity
  stability and no compiler observation. `analysis.json` checks all14 unique
  inputs, five rounds, unchanged wires/settings and70 ordered candidate
  decisions/work counts. New dispatch counts identify actual construction.
- `elf-review.*`/`focusedasm/`: limited pinned public route/index/fallback/stack
  evidence. Static review and finite mathematical models do not substitute
  for compiled complete-array tests or broad codec/competitor comparisons.
- `post-rebase/`: final handoff checks, separate from timing evidence.

Micro ratios are complete PrefixAlphabet calls, including gather/scatter and
same result checksum. Deep profile stages are nested/nonadditive and include
clocks. Requested competitor file identity is not loader dependency closure.
Local stack reservations/red-zone accesses are not full call-chain memory/RSS.
No all-quality, platform, streaming, competitor-memory or industry-best claim.
No binary, object or corpus contents are checked in.
