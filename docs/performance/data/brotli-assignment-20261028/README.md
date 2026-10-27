# Grouped integer assignment evidence

Baseline compression dependencies are commit
`c507a5c1d10dabfb4cbe9f933b9b486677c8cd04`. The candidate overlays only
`src/br/encoder/literal_context_split.zig` and its new `assignment_costs.zig`.
The fixed 64-by-256 u16 cost workspace is transposed, and each sparse
frequency contributes to four adjacent trees with widened u64 integer
arithmetic. The original scalar preparation/assignment remains in the
exhaustive reference search. No allocator or candidate policy changes.

`matched-raw.json.xz` preserves eighteen reports: two versions, three reversed
process sweeps and three prefix lengths. Each report includes all twelve
Silesia files, five interleaved Vort/reference rounds of three calls, complete
CSV text, exact commands, input/wire identities, settings, reference identity
limitations and executable/CPU provenance. `matched-summary.json` and
`matched-rows.csv` use a per-case median of fifteen samples per version, then
a geometric mean. `exploratory-*` preserves the earlier one-sweep experiment
and is excluded from the final measurement.

`baseline-stage.json.xz` and `candidate-stage.json.xz` retain three public q8
profile rounds for Mozilla, Dickens and MR 64 KiB prefixes. `stage-equality.json`
records complete non-time-field equality, including all context counters,
proposal configurations, selection events and returned-wire linkage.
Diagnostic clocks have different affinities and are excluded from timing
claims. `verify.py` recomputes ordinary ratios and validates both sample epochs,
cross-epoch identities, diagnostic equality and `SHA256SUMS`.

`source-and-build.json` records source overlays, tools, native executable
hashes and current canonical reference-library hashes. `source-overlays.tar.xz`
and `benchmark-sources.tar.xz` freeze the implementation and the six native
runner files; the profile runner is saved separately. Other dependencies come
from the baseline commit. The sibling `brotli-assignment-wasm-20261028` package
holds scalar/SIMD128 Wasm correctness evidence.

To reproduce, create an empty temporary root with `baseline` and `candidate`
subdirectories. Restore `git archive c507a5c1 src` into both, extract the source
overlays into `candidate`, and the benchmark archive into the root. Build:

```sh
zig build-obj candidate/src/br/encoder/record_optimal_object.zig \
  -O ReleaseFast -femit-bin=record.o
zig build-exe record.o -lc -O ReleaseFast \
  --dep vort_br --dep benchmark_provenance -Mroot=tools/br/planned_encode_bench.zig \
  -O ReleaseFast -Mvort_br=baseline/src/br.zig \
  -O ReleaseFast -Mbenchmark_provenance=tools/benchmark_provenance.zig \
  -femit-bin=bench-baseline
zig build-exe record.o -lc -O ReleaseFast \
  --dep vort_br --dep benchmark_provenance -Mroot=tools/br/planned_encode_bench.zig \
  -O ReleaseFast -Mvort_br=candidate/src/br.zig \
  -O ReleaseFast -Mbenchmark_provenance=tools/benchmark_provenance.zig \
  -femit-bin=bench-candidate
cmake -S /home/passchaos/Work/brotli -B reference-build \
  -DCMAKE_BUILD_TYPE=Release -DBROTLI_DISABLE_TESTS=ON -DBROTLI_BUILD_TOOLS=OFF \
  '-DCMAKE_C_FLAGS_RELEASE=-O3 -DNDEBUG -march=native'
cmake --build reference-build -j6
```

The clean reference checkout must be recorded Brotli 1.2.0 commit 558fc647.
With the twelve Silesia files present at their recorded paths, run
`python3 matched_measure.py TEMP_ROOT 3`. The original runner pins CPU 2 and
asserts the API version and matched q8/generic/actual-lgwin16 settings. Both
versions use Zig 0.16.0 ReleaseFast native `skylake+pku+sgx`, one thread on an
Intel i7-10700K. Timed work includes allocation/free. Vort has one untimed
warmup before its primary round; the reference has no explicit warmup.
Rebuilds have different executable identities and should be saved as a new
epoch. Canonical reference files are hashed; actual loaded objects and
transitive dependencies are explicitly unverified by this tool epoch.

These are point measurements, not proof of statistical significance, general
maximum stack use or industry-best performance. The ordinary runner cross
decodes both implementations outside timing. No decoder safety, wire ratio,
strict tie rule, context-cache state or allocation failure policy was changed.

`post-rebase-validation.json` and compressed logs retain final 82/82
Debug/ReleaseFast context tests, 25/25 profile/resource tests and the 219/219
combined compile/Wasm/help checks, all with explicit exit 0. The tested commit
precedes the documentation/evidence amend; implementation hashes are unchanged.
