# Exact sparse and grouped Brotli joint assignment

Joint literal-context discovery now packs each immutable context's nonzero
frequencies into a bounded local list, then evaluates four adjacent trees with
u64 lanes. Each frequency is loaded once per group. The existing heap price
buffer is reused as a compact `[symbol][requested_tree]u16` matrix: only its
active prefix is written and read, with no new heap allocation.

Price preparation continues to use the exact `Histogram.symbolCostsQ8()`
result. Joint discovery uses unsmoothed histogram prices and an unseen-symbol
penalty; the q8 context splitter's different smoothed model is not substituted.
All prices are frozen for a complete assignment round. Ascending group/lane
order and strict `<` retain the earliest tree on ties, and the scalar tail
handles one to three remaining trees. Frequencies and prices widen before
multiplication; `256 * max(u32) * max(u16) < 2^56` bounds every sum.

The production kernel is in `src/br/encoder/joint_context/assignment.zig`.
The coordinator retains requested tree counts, both seed orders, iteration and
early-stop rules, aggregation, compaction and complete-wire arbitration.
Allocator calls, lifetimes, heap price capacity and scratch admission are
unchanged. The sparse list is bounded at 256 symbols; the transposed price
matrix stays in the existing heap allocation, including the 256-tree limit.
The q8 splitter's independent fixed 64-tree workspace is unchanged.

## Ordinary public API measurements

The baseline is the preceding exact joint-kernel increment, reconstructed from
`fdcc266ede4d36b460fd0d9db3e385146638ac9c` plus its Zstd, zero-window LZ77 and
joint-kernel overlays. The candidate adds sparse grouped assignment. Both use
Zig 0.16.0 LLVM ReleaseFast, Linux x86-64/Skylake, an Intel i7-10700K, one codec
thread pinned to CPU 2, generic mode and the public quality API's default
16-bit window. Four serial alternating AB/BA sweeps give four observations per
side for each of 24 configurations. Each process does an untimed startup
encode/decode and one timed encode, then verifies its full wire and frees it
outside the timed interval.

| Scope | Candidate / baseline time | Time reduction |
| --- | ---: | ---: |
| q10, six files, 32 KiB | `0.745173` | `25.48%` |
| q10, six files, 64 KiB | `0.799231` | `20.08%` |
| q11, six files, 32 KiB | `0.748530` | `25.15%` |
| q11, six files, 64 KiB | `0.796740` | `20.33%` |
| Combined, 24 configurations | `0.771994` | `22.80%` |

All 192 ordinary full-wire signatures agree. Twenty-three configurations win
all four pairs. NCI q10 32 KiB is retained as a point regression at `1.002999`
with 1/4 paired wins; its q11 counterpart is `0.992748` with 4/4 wins. Mozilla
q10 32 KiB is the strongest point at `0.638864`. This epoch is a controlled
comparison against the preceding increment; ratios from previous epochs are
not multiplied into a cumulative performance claim.

A separate large-input campaign uses immutable 256 KiB source, documentation
and structured-data prefixes from the baseline tree. Three alternating AB/BA
sweeps cover six quality/input configurations and 36 processes.

| Scope | Candidate / baseline time |
| --- | ---: |
| q10, three 256 KiB inputs | `0.886185` |
| q11, three 256 KiB inputs | `0.890783` |
| Combined | `0.888481` |

Source and documentation improve in all three pairs for both qualities.
Structured data retains point ratios `1.007588/1.002156` and paired wins
`2/3` and `1/3`. All 36 full-wire signatures agree. These real-file samples
establish the measured scope; they do not establish statistical significance
or all-platform performance.

An earlier four-way exploratory campaign is retained separately: q10 32 KiB
geomeans are `0.768728` for sparse scalar assignment, `0.749328` for fixed-stride
grouping and `0.749584` for compact grouping. It covers six files, three sweeps
and 72 serial processes. The close grouped results do not establish a speed
difference between layouts. Compact grouping is retained because it keeps
small requested tree counts in a smaller active price prefix.

## Matched reference gap

A separate serial native campaign compares the final ordinary API with local
Brotli 1.2.0, commit `558fc647cdaf391228d614ca85f711e02e4e583b`, at q10/q11,
generic mode and actual wire lgwin16. All six Silesia 64 KiB prefixes have four
observations per side, giving 96 records. The native C reference wrapper uses
`BrotliEncoderCompress`; its timed interval includes output allocation and
encoding, while comparison/free are outside. Both runners have a startup
encode/decode. The reference library build uses GCC `-O3 -DNDEBUG -march=native`;
the wrapper also uses `-O3 -DNDEBUG -march=native`.

| Quality | Vort / reference time | Vort / reference compressed size |
| --- | ---: | ---: |
| q10 | `4.844650` | `1.097600` |
| q11 | `2.425075` | `1.121350` |

The native wrapper reports loaded Brotli objects through `dl_iterate_phdr`.
Each process binds the resolved encoder, decoder and common library paths to
their SHA256 identities and asserts both API versions. Reference wires decode
to exact plaintext with destination guards; their first window bit proves
lgwin16. The Vort wires match the formal 64 KiB campaign. The different native
caller allocation strategies are part of these public one-shot measurements;
this is not an allocator-free kernel comparison. The remaining time and size
gaps keep the industry-best objective open.

## Correctness and resource gates

Independent integer contracts cover 2,560 support/extreme/tree-count/stride
comparisons, every tree count 1–256, 64 cross-group/tail tie and tail-winner
cases, and 26 exact preparations against the original histogram model.
Inactive cells, buffer guards and immutable input/price state are checked.
Sparse and both grouped layouts pass Debug and ReleaseFast independently.
The retained library's joint suites pass 37/37 in Debug and ReleaseFast.
Retained grouped contracts also execute on 32-bit x86 and actual wasm32-wasi,
including both generic and SIMD128 targets.

An independent complete-plan oracle preserves all returned fields for 40
cases and 80 candidate comparisons, including tree caps 2/8/64/128/256,
iteration limits, reused temporal types, errors/null results, ownership and
scratch thresholds. The final implementation also passes that oracle in
actual Wasm. All 24 public 32/64 KiB configurations preserve complete output,
requested peak, exact-peak cap success and zero final live budget. The explicit
libbrotli 1.2.0 decoder validates 60 baseline/final exports over all 30 ordinary
and large configurations, bound to 228 timed wire signatures.

The final `zig build -j2 test-br-total-memory check check-wasm --summary all`
gate exits 0 at 215/215 steps and 68/68 total-memory tests; the CLI help smoke
also exits 0. Terminal results are recorded in the evidence package. Full
repository runtime tests are not implied by compile checks.
The frozen inputs, source overlays, four raw campaigns, wire exports, exact
commands and independent reducer are in
[`data/brotli-joint-grouped-20261030/`](data/brotli-joint-grouped-20261030/).

A separate post-gate ordinary q11 Mozilla 64 KiB profile records 3,564 user-cycle
samples and the same 14,185-byte golden wire. Self-symbol points are
`compiler_rt.memset=18.73%`, joint discovery `18.38%`, aggregation `6.52%`,
modeled optimal parsing `5.85%` and fixed optimal parsing `4.53%`. This diagnostic
is excluded from the A/B campaigns. Inline resolution failed in the system
addr2line helper, so the retained report disables inline and call-graph
resolution; memset is not attributed to particular callers. The next speed
screen should distinguish histogram clearing from other buffer initialization
before changing their layouts or lifetimes.

The next ratio candidate is concrete: the ordinary optimal/refinement path
clamps its search window to 32 KiB, while the default 16-bit Brotli window
permits distance 65,520 and the lazy path already uses the full window.
`entropy_feedback.build` also rejects the wider model. A full-window Brotli
distance-price proposal can retain the original fixed seed and complete-wire
candidate while testing far-match witnesses and all public budget boundaries.
The measured X-ray size gap is `17.69%/16.45%` at q10/q11; no distance attribution
has been measured, so the window limit does not explain that entire gap.

A second candidate is native command/distance pricing beyond the ordinary
command-state refinement's current 8 KiB input limit. Current-pipeline profiling
should also locate remaining price preparation and tree/map costs. The full
deflate/zstd/brotli goal remains active.
