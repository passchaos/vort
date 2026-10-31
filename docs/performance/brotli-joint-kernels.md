# Exact Brotli joint-context kernels

Joint literal-context clustering now reads immutable histograms through pointers
and uses an ordinary u64 sum for its 256-term assignment score. The maximum
possible score is `256 * max(u32) * max(u16)`, below `2^56`; the previous
saturation checks could never fire. Pointer captures also avoid copying complete
histograms while inspecting populations and compacting trees.

Tree aggregation has a separate validated-population path. Context histograms
form a disjoint partition of the validated literal input, and each is added
once to one tree. When the total literal population fits u32, every merged
counter fits u32 and every tree total fits u64. That path adds arrays directly.
Larger populations retain the original checked histogram merge.

The kernels are in `src/br/encoder/joint_context/`; the coordinator retains
all requested counts, ordered/interleaved seeds, frozen per-round costs,
assignment order, early-stop rules, compaction and complete-wire scoring.
No allocation, scratch admission, model price, candidate budget or ownership
policy changes.

## Ordinary public API evidence

Two independent Zig 0.16.0 LLVM ReleaseFast executables ran four serial AB/BA
sweeps on CPU 2, Intel i7-10700K, Linux x86-64/Skylake. Six exact Silesia prefixes
(Dickens, MR, NCI, Mozilla, OOffice and X-ray) cover 32/64 KiB and q10/q11,
giving 24 configurations and four ordinary observations per side. The runner
uses the public allocating quality API with generic/default-window options,
checks every timed result's complete wire against its startup encode, and
decodes once outside the loop. Encode alone is timed; wire comparison and free
are outside each measured interval.

| Scope | Candidate / baseline time | Time reduction |
| --- | ---: | ---: |
| q10, 32 KiB geomean | `0.745898` | `25.41%` |
| q10, 64 KiB geomean | `0.783620` | `21.64%` |
| q11, 32 KiB geomean | `0.746071` | `25.39%` |
| q11, 64 KiB geomean | `0.772182` | `22.78%` |
| Combined | `0.761766` | `23.82%` |

All complete wires are unchanged. Twenty-two rows improve in all four pairs.
NCI 32 KiB is retained as a regression: q10 is `1.032144`, q11 `1.009577`,
and both lose all four pairs. The largest improvement is Mozilla 32 KiB q10
at `0.668298`. These observations establish a gain for this native workload;
they do not prove statistical significance, all-platform gains or industry
leadership.

A separate three-way quick screen distinguishes immutable pointer/plain-score
work from validated aggregation. At OOffice/Mozilla/MR 32 KiB, plain-score time
ratios are `0.712093/0.696137/0.778850`; aggregation further changes time by
`0.969282/0.968134/0.976554`. That earlier epoch is preserved separately from
the formal result.

## Correctness and resources

Independent baseline modules compare 40 complete discovery plans, 80 candidate
comparisons, tree caps 2/8/64/128/256, two iteration limits, reused temporal
types, all returned plan fields, errors/null paths and exact scratch boundaries.
The final split kernels preserve those results; the same plan oracle also runs
in actual wasm32-wasi. Integer contracts compare scalar saturating scores with
extreme/sparse u32/u16 inputs and checked partition merging, including the exact
u32 population boundary and the larger-population fallback.

Current joint-related Debug and ReleaseFast suites pass 33/33 each. Kernel and
histogram contracts pass 10/10 in native Debug/ReleaseFast and 32-bit x86 Debug.
An independent public comparison over all 24 configurations preserves complete
wires, requested peak and exact-peak limit success, with zero final live budget.
The explicit libbrotli 1.2.0 oracle decodes all 48 baseline/candidate exports,
matches exact plaintext and checks guarded output destinations. All 192 ordinary
golden wire signatures are verified against those exports.

The final `zig build -j2 test-br-total-memory check check-wasm --summary all`
gate exits 0: 215/215 build steps succeed and 67/67 total-memory tests pass.
The CLI help smoke also exits 0. Original immutable inputs, raw timings,
separated source overlays, commands, executable identities and an independent
corruption-tested reducer are retained in
[`data/brotli-joint-kernels-20261030/`](data/brotli-joint-kernels-20261030/).

Next work should reuse exact grouped assignment in this joint planner without
changing its different entropy model, then reduce remaining tree/map scoring.
The full deflate/zstd/brotli goal remains active.
