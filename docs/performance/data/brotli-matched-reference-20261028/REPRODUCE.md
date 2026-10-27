# Reproduce the parameter contracts

Run from the Vort repository root. Use an empty temporary directory; this
restores the recorded compression source and overlays the preserved tools.

```sh
matched_repro=/tmp/vort-br-matched-repro-20261028
mkdir -p "$matched_repro"
git archive 3dd417597de62232050f15041c6ce48b87dd9065 src tools corpus/native-library-bench-small.txt | tar -x -C "$matched_repro"
cp -a docs/performance/data/brotli-matched-reference-20261028/sources/tools "$matched_repro/"
cd "$matched_repro"
taskset -c 0,1,3-9,11-15 zig build-obj -OReleaseFast src/br/encoder/record_optimal_object.zig -femit-bin=record.o
taskset -c 0,1,3-9,11-15 zig test -lc -OReleaseFast record.o \
  --test-filter 'Brotli encode' --test-filter 'Brotli reference benchmark' --test-filter 'libbrotli explicit' \
  --dep vort_br --dep benchmark_provenance -Mroot=tools/br/planned_encode_bench.zig \
  -OReleaseFast -Mvort_br=src/br.zig -OReleaseFast -Mbenchmark_provenance=tools/benchmark_provenance.zig
taskset -c 0,1,3-9,11-15 zig build-exe -lc -OReleaseFast record.o \
  --dep vort_br --dep benchmark_provenance -Mroot=tools/br/planned_encode_bench.zig \
  -OReleaseFast -Mvort_br=src/br.zig -OReleaseFast -Mbenchmark_provenance=tools/benchmark_provenance.zig \
  -femit-bin=bench
taskset -c 0,1,3-9,11-15 python3 tools/br/planned_encode_reference_gate_test.py
taskset -c 0,1,3-9,11-15 python3 tools/br/planned_encode_path_gate_test.py
taskset -c 0,1,3-9,11-15 python3 tools/codec_bench/sample_gate_smoke.py
```

Each configuration uses `--iterations 1 --case json --samples-json NAME.json
--csv NAME.csv`, followed by its flags:

| Name | Flags |
| --- | --- |
| default | No parameter overrides |
| matched | `--quality 8 --planned-quality=8 --reference-lgwin=16 --reference-mode generic` |
| adjusted | `--quality 0 --planned-quality=0 --reference-lgwin 16` |
| modes | `--quality 8 --planned-quality=8 --planned-mode text --reference-lgwin=16 --reference-mode=font` |

For example:

```sh
taskset -c 0,1,3-9,11-15 ./bench --iterations 1 --case json \
  --quality 8 --planned-quality=8 --reference-lgwin=16 --reference-mode generic \
  --samples-json matched.json --csv matched.csv
```

`commands.json` contains every exact original command, including input and
manifest paths, the four JSON-only/JSON+CSV gate pairs, and both path gates.
The frozen inputs and manifest are in `samples/`; update `frozen_path` when
copying the input to another directory. JSON-only validation omits `--csv`:

```sh
taskset -c 0,1,3-9,11-15 python3 tools/codec_bench/sample_gate.py \
  --samples-json matched.json --manifest MANIFEST.json --csv matched.csv --executable ./bench
```

The current and historical path fixtures contain identical row values; the
historical fixture omits the five appended reference/window/matching columns.
Use `--require-ratio-no-worse-than-reference` when exercising the small
fixture's auxiliary size requirement. General evidence validation leaves that
option unset.

The follow-up preserves the complete modern 12-row 64 KiB batch plus extracted
Dickens CSV/JSON. `path_gate_followup.json` contains its exact replay commands.
For the full batch, omit `--input`, which checks one row against one input.
For the Dickens row, first decompress `samples/dickens-modern-input.bin.xz`
to a temporary file; pass that file with `--input` and `--limit 65536`. Update
the modern manifest's `frozen_path` to that file when running its JSON gate.
Default path validation must exit 0; adding the explicit auxiliary size
requirement must exit 1. Both small-fixture schemas must still exit 0 with it.

`exit_evidence.json` retains explicit completion codes. Inspect compressed
logs with `xz -dc logs/NAME.log.xz`. Package hashes can be checked by running
`sha256sum -c SHA256SUMS` from this directory. Rebuilding may use a different
reference library or produce a different executable hash; its new samples
must record those identities.
