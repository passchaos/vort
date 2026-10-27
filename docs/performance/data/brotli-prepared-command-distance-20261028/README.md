# Prepared command/distance ordinary evidence

`matched-raw.json.xz` retains eighteen complete reports, including CSV text:
two versions, three sweeps and three prefix lengths. Each report contains
twelve cases and five alternating rounds of three calls. `matched-summary.json`
and `matched-rows.csv` report per-case medians and geometric means. The initial
all-input strategy has separately named raw/summary artifacts.

`verify.py` recomputes the ratios and checks every input/wire/settings identity
within and across both experiments. It also compares the two diagnostic q8
profiles after removing clock fields and provenance. Run it from this directory
with `python3 verify.py`. `SHA256SUMS` checks archive integrity.

`source-and-build.json` records exact source/tool/executable/library hashes,
compiler and reference settings. The successful baseline/current complete
compression source archives are in the sibling
`brotli-prepared-command-wasm-20261028/sources` package. Their br.zig and
prepared-module hashes match this final ordinary-call epoch. The baseline
archive includes an unused diagnostic Key module; its encoder does not import
that module. `initial-br.zig.xz` is the only earlier source change: the initial
strategy lacks the 8 KiB producer gate. Both strategies share the same module
and benchmark source. `benchmark-sources.tar.xz` freezes the six benchmark
files needed to rebuild the ordinary runner.

The diagnostic candidate profile was measured with the initial strategy and
an unpinned 14-CPU affinity; baseline diagnostics were pinned to CPU 2. All
three inputs are 64 KiB and cross the final producer gate. These diagnostic
clocks are not used for performance claims. Public profile contracts cover
bounded state and wire linkage separately. `quality_stage_profile.zig` freezes
the diagnostic runner; its imports use the archived benchmark files.

To reproduce the final experiment, create an empty temporary directory and
restore the baseline and candidate source archives into separate subdirectories.
Restore `benchmark-sources.tar.xz` into its root, then build:

```sh
zig build-obj candidate/src/br/encoder/record_optimal_object.zig \
  -O ReleaseFast -femit-bin=record.o
zig build-exe record.o -lc -O ReleaseFast \
  --dep vort_br --dep benchmark_provenance -Mroot=tools/br/planned_encode_bench.zig \
  -O ReleaseFast -Mvort_br=baseline/src/br.zig \
  -O ReleaseFast -Mbenchmark_provenance=tools/benchmark_provenance.zig \
  -femit-bin=bench-matched-baseline
zig build-exe record.o -lc -O ReleaseFast \
  --dep vort_br --dep benchmark_provenance -Mroot=tools/br/planned_encode_bench.zig \
  -O ReleaseFast -Mvort_br=candidate/src/br.zig \
  -O ReleaseFast -Mbenchmark_provenance=tools/benchmark_provenance.zig \
  -femit-bin=bench-gated
cmake -S /home/passchaos/Work/brotli -B reference-build \
  -DCMAKE_BUILD_TYPE=Release -DBROTLI_DISABLE_TESTS=ON -DBROTLI_BUILD_TOOLS=OFF \
  '-DCMAKE_C_FLAGS_RELEASE=-O3 -DNDEBUG -march=native'
cmake --build reference-build -j6
```

The reference checkout must match the recorded clean commit. The original
`matched_measure.py` expects the twelve Silesia files at their recorded paths
and accepts this temporary root as its one argument. It pins ordinary runs to
CPU 2 and asserts API version and actual windows. The initial runner is also
retained with its original executable naming. New builds have new executable
identities; save the rerun reports as a new epoch.

Reference file hashes identify requested canonical files; the tool explicitly
does not verify actual loaded objects or transitive dependencies. Requested
Vort peaks in raw CSV are observations for these inputs, not a general memory
limit. Point timings do not prove significance or competitor leadership.

`post-rebase-validation.json` and the corresponding compressed logs record
Debug/ReleaseFast preparation tests, the public q8 profile contract and the
combined compile/Wasm/help checks, all with terminal exit 0. Tested source
hashes match the final implementation. The tested commit precedes the amend
that adds these documentation/evidence files.
