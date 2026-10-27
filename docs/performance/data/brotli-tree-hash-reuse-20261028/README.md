# Hash reuse and matched q8 evidence

Baseline compression source: `3dd41759`. `source-and-build.json` records the
candidate source files, executable identities, explicit reference libraries,
CPU, native targets and build flags. The two versions use the same benchmark
tool source and q8/generic/actual-lgwin16 policy.

- `matched-raw.json.xz`: 18 complete reports (two versions, three process
  sweeps, three prefix lengths), each with all twelve cases and five alternating
  Vort/reference rounds of three ordinary calls. CSV text and complete raw
  JSON retain all clocks, checksums, sizes, hashes, parameters and provenance.
- `matched-summary.json`, `matched-rows.csv`: per-case median of the fifteen
  ordinary samples per version. Final time ratio 0.9906246, reference time
  ratio 40.1957, size ratio 0.9955604. All 36 cases are parameter matched.
- `matched-inputs.json`, `matched-gates.json.xz`: frozen input identities and
  successful shared sample-gate validation for all eighteen reports.
- `baseline-stage.json.xz`, `candidate-stage.json.xz`: three q8 stage rounds
  each for Mozilla, Dickens and MR. Every context non-time field and wire
  agrees; these diagnostic timings do not replace ordinary encode samples.
- `q8-exploratory.json.xz`: an earlier 18-prefix exploratory q8-only comparison,
  seven reversed blocks and five calls per sample, time ratio 0.9875664.
- `q8-cycles-report.txt`, `q8-cycle-executable.json`: pure q8 cycle attribution
  for Mozilla, including executable/input identities. This reports CPU samples,
  not a measured causal saving from a specific code line.
- Reference build/configuration and current parameter-test logs are compressed;
  `reference-CMakeCache.txt.xz` preserves Release `-O3 -DNDEBUG -march=native`.

The source overlays are the two changed `src/br/encoder/literal_*` files in
the hash-reuse commit. Other compression source dependencies come from the
baseline commit. The parameter-enabled benchmark source is included in the
separate reference-parameter change. Source paths and input locations in raw
commands are the original observation paths, not portable installation names.

To reproduce from the repository root with the Silesia files present under
`/home/passchaos/Work/corpora/silesia-20261025/files`:

```sh
br_measure_dir=$(mktemp -d /tmp/vort-br-hash.XXXXXX)
mkdir -p "$br_measure_dir/baseline" "$br_measure_dir/corpus"
git archive 3dd41759 src | tar -x -C "$br_measure_dir/baseline"
cp docs/performance/data/brotli-tree-hash-reuse-20261028/q8-only.zig "$br_measure_dir/"
cmake -S /home/passchaos/Work/brotli -B "$br_measure_dir/reference-build" \
  -DCMAKE_BUILD_TYPE=Release -DBROTLI_DISABLE_TESTS=ON -DBROTLI_BUILD_TOOLS=OFF \
  '-DCMAKE_C_FLAGS_RELEASE=-O3 -DNDEBUG -march=native'
cmake --build "$br_measure_dir/reference-build" -j6
zig build-obj src/br/encoder/record_optimal_object.zig -O ReleaseFast \
  -femit-bin="$br_measure_dir/record.o"
for br_variant in baseline candidate; do
  br_source=src/br.zig
  if [ "$br_variant" = baseline ]; then br_source="$br_measure_dir/baseline/src/br.zig"; fi
  zig build-exe "$br_measure_dir/record.o" -lc -O ReleaseFast \
    --dep vort_br --dep benchmark_provenance -Mroot=tools/br/planned_encode_bench.zig \
    -O ReleaseFast -Mvort_br="$br_source" \
    -O ReleaseFast -Mbenchmark_provenance=tools/benchmark_provenance.zig \
    -femit-bin="$br_measure_dir/bench-matched-$br_variant"
done
python3 docs/performance/data/brotli-tree-hash-reuse-20261028/matched_measure.py \
  "$br_measure_dir"
```

The local reference checkout must match the recorded 1.2.0 source epoch; the
runner asserts its API version. Rebuilding in a new directory changes debug
paths and executable hashes, which must be recorded as a new observation.
The native-only exploratory runner additionally needs the 18 named frozen
prefix files and `q8-baseline`/`q8-candidate` compiled from `q8-only.zig`.

These point measurements do not establish statistical significance, general
maximum memory use, or industry-best performance. The input, time and size
results remain explicit even where the competitor result is better.
