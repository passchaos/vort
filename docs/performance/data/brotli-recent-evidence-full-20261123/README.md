# Brotli recent evidence: full public-operation gates

Status: complete functional verification of the original instrumented
prototype and counter-free follow-up; both performance screens are rejected.
No encoder change has been adopted.

Base main revision: `b929184e4f815773f9fde0d2c40224a0a5dcf938`.
The prototype source is based on `b1656a4e`; all shared source files match main
except the archived HQ parser change. `manifest.json` binds both benchmark
executables, the full-API probe executables, source hashes and host policy.

## Complete wire and resource results

- Twelve Silesia prefixes at 8 KiB and 64 KiB, q10/q11, produce **48 identical
  complete wires** before/after. libbrotli 1.2.0 independently decodes Vort
  output, and Vort decodes reference output. Requested quality, generic mode
  and actual 16-bit windows match.
- The explicit periodic q10 64 KiB / q11 32 KiB command-state ceilings also
  preserve complete wire hashes and cross-library round trips. These two rows
  are separate from the default 8 KiB command-state setting.
- The public Alloc/Into, singleton-chunk Append, and split-chunk Alloc/Into/
  Append probe compares **144 API entries**. Each tests ordinary, profiled,
  exact-cap and cap-minus-one calls. All before/after wires, decoded hashes,
  logical results, requested-heap profiles, allocator-taking independent
  backing peaks and failure-preservation flags match, with zero differences.
- RAW compound dictionaries include split backing and an empty attachment.
  Into's internal backing allocator cannot be observed by the external tracker;
  its backing fields are null. Its profile, quota and output guards are tested.
  This specific Append API excludes old destination capacity and charges the
  new replacement allocation. Cross-facade wire identity is recorded as an
  observation; some chunk boundaries and RAW singleton Append change the wire.
  Same-API identity under profile/cap settings is enforced.
- Actual ReleaseSafe x86 ELF32 and Wasm32 WASI executions each pass all 25
  prototype tests, 65,400 match-query and 699 exact parser/command comparisons.
  The generic WASI receipt records the actual artifact, runtime and exit zero.

`full-wire-api-samples.tar.xz` contains complete wire matrices, API JSON,
original paired CSV/JSON samples and commands. `portability-artifacts.tar.xz`
retains runners, actual test artifacts, hashes, logs and receipts.
`full-api-comparison.json` and `portability-results.json` are readable receipts.
Probe source and reproduction instructions are kept beside this document.

## Original instrumented performance screen

Host: Intel i7-10700K, Zig 0.16.0 ReleaseFast, native x86-64 GNU,
`skylake+pku+sgx`, CPU 2 / physical core 2 (SMT sibling 10), one codec thread,
`intel_pstate` with the observed `powersave` governor. The source/build/protocol
is identical before/after apart from the cache. This is a local interleaved
screen with recorded power policy, not an industry ranking or RSS comparison.

Each row has three alternating baseline/variant process pairs. Each process
uses three ordinary allocating quality-preset iterations and five alternating
Vort/reference rounds. Primary Vort timings include allocation/free and
per-round Vort warmup is outside timing. Auxiliary balanced/ratio passes are
outside the primary timer. The reference is the explicit local libbrotli
1.2.0 encoder/decoder/common trio, quality-matched, generic mode and window 16.

| Scope | Rows | Geometric mean | 95% paired-block bootstrap interval |
| --- | ---: | ---: | ---: |
| 8 KiB target, q10/q11, twelve files | 24 | 1.000122x | [0.997539, 1.002392] |
| 64 KiB controls, q10/q11, four files | 8 | 0.998219x | [0.996338, 0.999928] |
| All rows | 32 | 0.999646x | not used for target claim |

One target row, q11 `reymont`, is 0.978517x. The target does not reach 1.03x,
its confidence interval includes parity, and the 0.98x row floor fails.
The instrumented variant is rejected. Intervals resample the three process-pair
blocks separately by quality for this fixed corpus; 10,000 draws use seed
20261123. This short pilot is not a broad population or fixed-host ratchet.
`instrumented-pilot-summary.json` preserves ratios and gate outcomes.

Generated code retains evidence-counter writes. The
[assembly audit](generated-code-audit.md) records the exact symbols, code
sections and individual function stack reservations. None of these is a
whole-operation stack-peak measurement.

## Counter-free follow-up

The follow-up changes only diagnostic collection through an explicit comptime
switch. It keeps hashing, byte facts, transition order, model prices and logical
budget accounting. Debug/ReleaseSafe each pass the original 65,400 query streams
in scalar/statistics-enabled/statistics-disabled paths and 699 exact parser
pairs. Both actual 32-bit x86 and Wasm executions pass 25 tests, including the
statistics-disabled owner. Native automatic entry storage is 512/1024/2048
bytes; generated own frames and code sections are smaller than the instrumented
variant, as the assembly audit shows.

All 50 complete public wires and the 144 full API/resource entries remain
identical to the frozen baseline. The before/after requested heap profiles and
independent backing observations also match. The actual stack peak remains
unmeasured.

The same pinned 32-row, three-pair, three-iteration protocol yields:

| Scope | Geometric mean | 95% paired-block bootstrap interval |
| --- | ---: | ---: |
| 8 KiB target | 1.001005x | [0.997663, 1.003218] |
| 64 KiB controls | 0.998921x | [0.997093, 1.000569] |
| All rows | 1.000483x | not used for target claim |

Every row is above 0.98x, but target improvement remains below 3% and its
confidence interval includes parity. The counter-free candidate is also
rejected. Removing verified diagnostic work did not establish a material
complete-encoder improvement. `runtime-pilot-summary.json` records the gates;
`runtime-wire-api-samples.tar.xz` keeps exact outputs, public API results and raw
paired samples. `runtime-source-portability-proof.tar.xz` preserves the changed
source, exact patch, proof tests/logs and actual 32-bit artifacts/receipts.

These results are negative evidence for this bounded recent-cache design under
the measured settings. The next structural investment should follow a complete
optimized quality-path profile rather than assume Debug match-loop dominance
predicts production end-to-end benefit. Full quality profiling includes warmed
calls and benchmark auxiliaries, so primary-call attribution must be explicit.

The [primary q10 profile](q10-next-structural-boundary.md) attributes the
optimized full call and identifies ordinary nonrecent context-group common
planning/winner-only emission as the next sharing boundary. Its exact input,
raw perf capture, symbol export and attribution script are preserved; these
diagnostics do not establish a new performance claim.
