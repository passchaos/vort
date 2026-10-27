# Fused suffix search, 2026-10-27/28

Baseline: `718558333bd1bab3202c461f56d8d02762def614`. Intel i7-10700K,
Zig 0.16.0, ReleaseFast, native x86_64 `skylake+pku+sgx`, one thread,
CPU 2. Concurrent validation processes exclude CPU 2 and sibling 10.

`search/raw.json.xz` retains five version-interleaved blocks, nine ordinary
search timings per case/block, the independent profiled call, full selected
proposals and executable/input/command provenance. Its 36 rows span all twelve
Silesia files at 4096/16384/65536 bytes. `search/rows.csv` and `summary.json`
use the median of the five per-block minima. Final ratio: 0.9451147; the
intermediate fused implementation before the module split is 0.9391603.

`encode/raw.json.xz` retains two reversed-order sweeps of the existing public
q8/generic one-shot benchmark, each with five Vort/libbrotli interleaved
samples. Every sample has one encoding iteration; all 36 input/wire hashes,
sizes and settings agree across versions and sweeps. Median-of-ten ordinary
Vort time yields 0.9908249. Native and reference decoding verify the wire
outside timing. Explicit reference encoder/decoder/common 1.0.9 files and
hashes are retained. Vort lgwin16 versus reference lgwin22 prevents a
matched-window competitor ranking. Results are point measurements without a
statistical significance or industry-best claim.

`measured-sources.tar.xz` overlays the changed source closure on the baseline
checkout; `intermediate/` contains the two intermediate fused modules. Other
source dependencies and the existing public encoding benchmark come from the
baseline commit. The measured shim briefly exposed an unused `Command` alias
in the internal search module. Final source removes this alias. `identity.json`
records both source hashes and an ELF comparison: **every allocated code/data
section of both measured executables equals its rebuilt final equivalent**.
Only nonloaded metadata differs; the measured executable hashes remain in the
raw provenance. Later Wasm wrapper changes have a separate source epoch.

Run from the repository root with the twelve extracted Silesia files available
at the recorded path, or change `--corpus` to their location:

```sh
br_measure_dir=$(mktemp -d /tmp/vort-br-fused.XXXXXX)
mkdir -p "$br_measure_dir/head" "$br_measure_dir/candidate"
git archive 71855833 src | tar -x -C "$br_measure_dir/head"
git archive 71855833 src | tar -x -C "$br_measure_dir/candidate"
tar -xf docs/performance/data/brotli-fused-suffix-20261027/measured-sources.tar.xz -C "$br_measure_dir/candidate"
cp src/br_context_bench.zig "$br_measure_dir/head/src/"
for br_variant in head candidate; do
  zig build-exe -O ReleaseFast --dep context_bench --dep benchmark_provenance \
    -Mroot=tools/br/literal_context_search_bench.zig \
    -O ReleaseFast -Mcontext_bench="$br_measure_dir/$br_variant/src/br_context_bench.zig" \
    -O ReleaseFast -Mbenchmark_provenance=tools/benchmark_provenance.zig \
    -femit-bin="$br_measure_dir/$br_variant/search"
done
python3 docs/performance/data/brotli-fused-suffix-20261027/measure.py \
  --executable "head=$br_measure_dir/head/search" \
  --executable "candidate=$br_measure_dir/candidate/search" \
  --corpus /home/passchaos/Work/corpora/silesia-20261025/files \
  --output "$br_measure_dir/search-result"

zig build-obj src/br/encoder/record_optimal_object.zig -O ReleaseFast \
  -femit-bin="$br_measure_dir/record.o"
for br_variant in head candidate; do
  zig build-exe "$br_measure_dir/record.o" -lc -O ReleaseFast \
    --dep vort_br --dep benchmark_provenance \
    -Mroot=tools/br/planned_encode_bench.zig \
    -O ReleaseFast -Mvort_br="$br_measure_dir/$br_variant/src/br.zig" \
    -O ReleaseFast -Mbenchmark_provenance=tools/benchmark_provenance.zig \
    -femit-bin="$br_measure_dir/$br_variant/encode"
done
python3 docs/performance/data/brotli-fused-suffix-20261027/measure_encode.py \
  --baseline "$br_measure_dir/head/encode" \
  --candidate "$br_measure_dir/candidate/encode" \
  --corpus /home/passchaos/Work/corpora/silesia-20261025/files \
  --library-directory /usr/lib/x86_64-linux-gnu \
  --output "$br_measure_dir/encode-result"
```

The installed component entrypoint is also available for future measurements:

```sh
zig build -j2 run-br-literal-context-search-bench -- \
  --path /home/passchaos/Work/corpora/silesia-20261025/files/dickens \
  --limit 65536 --rounds 9
```

Focused final Debug validation passes 79/79. The retained final validation logs
record the broader checks and the separate public Wasm Debug stack regression.
