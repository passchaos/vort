# Counted context evidence

Base dependencies are commit 289110eb. `source-overlays.tar.xz` contains the
changed/new source and tool files; `source-and-build.json` records their hashes
and native executable/reference identities. `benchmark-sources.tar.xz` freezes
the six ordinary runner files. Other dependencies come from the Git base.

`matched-raw.json.xz` retains eighteen reports and complete CSV text, with all
commands, clocks, input/wire identities, settings and provenance. The final
36-case summaries/rows use medians from fifteen samples per version. The
exploratory six reports are separately named and excluded from final timing.
`verify.py` recomputes timing ratios, checks wire/settings identity, validates
context/ordered selection equality and archive hashes.

Restore `git archive 289110eb src` into separate baseline/candidate directories,
then overlay candidate sources and restore benchmark tools into a temporary
root. Compile the record object ReleaseFast, and compile the same
`tools/br/planned_encode_bench.zig` with `--dep vort_br --dep benchmark_provenance`,
`-Mvort_br=baseline/src/br.zig` or `candidate/src/br.zig`, and
`-Mbenchmark_provenance=tools/benchmark_provenance.zig`, linking `record.o -lc`.
Name binaries `bench-baseline` and `bench-candidate`. Build the clean Brotli
1.2.0 commit 558fc647 under `reference-build` with
`-DCMAKE_BUILD_TYPE=Release -DBROTLI_DISABLE_TESTS=ON -DBROTLI_BUILD_TOOLS=OFF`
and `-DCMAKE_C_FLAGS_RELEASE=-O3 -DNDEBUG -march=native`.
Run `python3 matched_measure.py TEMP_ROOT 3` with the twelve Silesia files at
the recorded paths. New builds have new executable identities: record a new
epoch. Canonical requested library files are hashed; actual loaded objects and
transitive dependencies remain explicitly unverified.

`final-stage.json.xz` and `baseline-stage.json.xz` record three q8 rounds for
Mozilla/Dickens/MR. IDs and wire-attempt counts change; `stage-equality.json`
records identical wire hashes, context non-time fields and ordered strict
selection results. Diagnostic clocks are excluded from performance claims.

`memory/` preserves complete independent requested-byte ledgers, four inputs,
generation metadata, compile/run/compare commands and explicit exit codes.
`compare.py` originally accepts the evidence root as its argument. Restore the
two compressed memory JSONs before running it in a new directory. Native probe
source is in the overlays under `tools/br/candidate_memory_*`; its command
arguments are recorded in `baseline-compile.json` and `candidate-compile.json`.
Build each against its matching codec source and run the preserved four inputs
with `--json OUTPUT`. The native fixture deliberately forces moving growth and
tests ordinary/profile, actual peak, peak-minus-one and all ownership cleanup.
Peaks are unchanged on these cases; requests fall for three Silesia inputs.
Caller-owned profile storage and fixed stack are outside these heap metrics.

`SHA256SUMS` protects all package files. Point timings do not establish
significance, general memory bounds, other-platform speed or industry-best
performance. The sibling Wasm package preserves exact full-wire replay.

`post-rebase-validation.json` and the matching compressed logs record final
21/21 count/emission, 20/20 policy, 25/25 public profile, 219/219 combined
compile/Wasm/help and nineteen Python gate tests, all exit 0. Tested source
hashes match the formal measurement; the tested commit precedes the amend
that adds these documentation/evidence files.
