# Brotli Large Window history evidence

The baseline is `e047456b4c5d38640e18cace58a36c366e10b5ea`. The first feature
snapshot is `18a7fc6df2ada175152f4d921a795f7f90bc0e82`; the final snapshot is
`2f421462ce9399dfa9d4febcc39028dba2ce95c2`. Their manifests bind 1901
source/tool files independently. The final change retains the original ratio
four-byte/min16 proposals before trying the added three-byte/min3 proposals.
It does not change standard-format selection or reduce search budgets.

`native-retained.tar.xz` and `x86-retained.tar.xz` preserve all 2105 original
campaign files per target. Each `*-files.json` records original paths, sizes,
SHA-256 and the archive hash. Reports are also available as plain JSON.
Archive compression is evidence packaging, not performance measurement.

```sh
tar -xJf native-retained.tar.xz
tar -xJf x86-retained.tar.xz
```

Each final campaign passes 450 cases: 423 streaming cases and 27 one-shot
cases. Reported far cases are 297 streaming plus 27 one-shot; 27 window-boundary
cases are counted separately by the report. All use actual emitted wire,
deterministic source-position bounds and independent libbrotli full plaintext.
The report does not claim an exact count of every far token. Three hundred
new-frame outputs per target are independently decoded and checked against
fresh-encoder output. Capacity and heap dimensions differ across targets;
`cross-target-retained.json` compares semantic bytes, progress, logical history
and token evidence while retaining those target-specific resource records.

The primary reference is the existing local libbrotli 1.2.0 experimental build.
Requested paths, actual symbol owners, versions and file hashes are recorded.
The 64-bit Python reference process verifies both native and x86 Vort probes.
No compression timing is performed by these gates.

Initial 450-case campaigns each had nine legacy-fast 64KiB first-block failures:
the facade called a tiny parser limited to 32KiB. The complete hash planner now
handles that admitted block with the same options and token ownership. Initial
reports and logs retain their own source epoch. The exact pre-fix root source
was reconstructed and checked against its original hash. Older large reports
and source bodies are stored losslessly as `.xz`, with their uncompressed hashes
in `compressed-history-files.json`; use `xz -dk PATH.xz` to inspect them.

The first size comparison also found q8 chunks two bytes larger than baseline.
The final ratio-candidate correction changes that sample from 70053 to 70050
bytes, versus baseline 70051. q2 incremental changes from 70270 to 70039 bytes,
while retaining more history increases requested heap. Both the earlier
negative result and the corrected result remain in `size-examples/` with source,
executable and input identities. Neither establishes broad ratio, memory or
throughput leadership.

`legacy-parity/retained-refresh/` binds the final executables to 216 exact
standard/q0/q1 wire comparisons and 120 reset-wire comparisons against saved
old outputs. Only the final new streams run during that refresh, giving 336
independent full-content checks. Earlier old/new runs and intermediate refreshes
retain their own report hashes. Do not combine those counts into one benchmark
or relabel an old executable with the final source revision.

Reproduce with Zig 0.16.0:

```sh
zig build test-br-large-history --summary all
zig build test-br-large-history -Doptimize=ReleaseFast --summary all
zig build test-br-large-history -Dtarget=x86-linux-gnu -Doptimize=ReleaseFast --summary all
zig build test-br -Doptimize=ReleaseFast --summary all
zig build check --summary all
zig build run --summary all -- --help
zig build run-br-large-history-diff -- --directory /tmp/vort-history-native \
  --reference-encoder /tmp/vort-br-general-experimental-build/libbrotlienc.so.1.2.0 \
  --reference-decoder /tmp/vort-br-general-experimental-build/libbrotlidec.so.1.2.0 \
  --reference-common /tmp/vort-br-general-experimental-build/libbrotlicommon.so.1.2.0
```

The x86 differential adds `-Dtarget=x86-linux-gnu` to the same build step.
`validation.json` distinguishes focused tests, complete family checks and
platform-specific skips. A logical history window is a distance bound; actual
geometric buffer capacity and adaptive snapshots are charged separately by the
requested-heap authority. Their measurements exclude RSS and whole-process stack.

The final test-only revision is `2adbe60b64767220acc037317ff5bda48d8d0276`.
`new-source-manifest.json` binds 1902 files; `codec-source-manifest.json`
preserves the 1901-file production snapshot at `2f421462`. The only new delta
is the adaptive correctness fixture and its test hook, recorded in
`source-epochs/adaptive-test-delta.json`. All three final focused configurations
again pass 27 executions, now including real 70000-byte retained history,
65536-byte adaptive input, exact/below requested-heap limits and three targeted
history/snapshot growth refusals. Accepted input remains visible while prior
committed history, pending bytes and semantic state survive failure; retry
produces the same complete wire. These test results do not refresh the earlier
external executable or full-family source epoch.
