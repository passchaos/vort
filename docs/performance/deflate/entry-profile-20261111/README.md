# Deflate weakest-row entry profile, 2026-11-11

Status: exploratory profile; no production optimization or A/B result.

The modern reference matrix's weakest cold Deflate row is the first 64 KiB
of Silesia `reymont` encoded by Python zlib at level 6. A follow-up profile
retains the exact frozen wire and executable and attributes the complete
paired operation to its kernels and setup. This profile predates the raw
output-alias fix; that functional correction takes priority.

## Source, lifecycle and sampling

The executable is the frozen probe from
`docs/performance/modern-decode-current-20261111/probe.tar.gz`, SHA-256
`eddd7b5deaef84f1dc7fc50cc736cb64e0083b6e02e6a40ae8298c8ccc5bb8ba`.
The checked-out source was `6618b0c5833bf48dcc1a3cb99b9cec238f9e67b1`;
its production codecs were unchanged from the matrix's `4bca528b` base.
The raw JSON retains probe/fixture hashes, explicit reference path and mapped
libraries, CPU/target features, APIs and complete balanced pairs.

Environment: i7-10700K, CPU 15, Zig 0.16.0 ReleaseFast,
`skylake+pku+sgx`, libdeflate 1.26, perf 6.8.12. Each side makes 30,000
cold-context calls per batch, with two warmup and two measured paired batches
in balanced AB/BA order. Caller buffers are reused; reference context
allocation/release occurs inside each call. Hardware/process caches are primed.

`perf record -F 199 -g` recorded the entire process, including both decoders,
validation and startup. The event is `cycles:P`; there were 2,668 samples and
no lost samples. Kernel symbols were restricted, and the archived reports
retain the warnings. No separate immutable power-state snapshot was captured.
Profiling overhead and this single workload preclude a throughput acceptance
claim or a fixed-host merge gate.

## Observations and bounded next step

The archived `perf report` event-weighted overhead is **62.53%** for the Vort
executable and **57.76%** for `deflate.semantic.linear_entry.aligned` alone.
Thus that kernel contributes about **92.4% of executable-attributed weight**,
including validation/startup in the executable denominator. This is not an
instruction count or a fraction of only timed codec work.

The outer raw block parser/entry function contributes 1.53% of total event
weight; literal-table construction 0.95%, and semantic distance-table
construction 0.41%. Inlined generic distance preparation is part of its
caller and is not isolated by this sample.

Source inspection found duplicate distance preparation: the caller builds
`DynamicDistanceDecoder.fast8` before a successful semantic path builds its
own distance table. Delaying the generic table until a fallback is a real
structural option, but this profile does not measure the removable share.
No variant was implemented or rejected. Prioritize the dominant semantic
kernel when repairing this weakest-row cliff; preserve the duplicate-setup
idea for a measured whole-operation screen rather than predicting a gain.

A future setup experiment must preserve current Huffman acceptance/error
order: missing EOB and literal-tree validation precede distance validation;
oversubscribed distance trees fail before payload; literal-only empty distance
trees remain valid; singleton nonzero widths 1 through 15 use canonical zero;
under-subscribed distance trees are not rejected eagerly. A failed semantic
literal initialization must preserve its generic fallback. No setup shortcut
may change malformed-input errors or raw prefix consumption.

## Preserved evidence and reproduction

`profile.tar.gz` retains exact perf data, the full raw paired JSON, source
binding, concise symbol/DSO reports and their stderr. `bindings.json` hashes
every member; `SHA256SUMS` covers package files. No minimum sample was selected.
The warmup/measured timings were collected under perf and are not substituted
for the modern matrix's ordinary benchmark results.

The original invocation, after restoring the frozen executable and fixtures:

```sh
perf record -F 199 -g \
  -o /tmp/vort-deflate-distance-setup-20261111/base.perf.data -- \
  taskset -c 15 /tmp/vort-deflate-distance-setup-20261111/base-probe \
  --codec deflate \
  --input /tmp/vort-current-decode-matrix-20261111/fixtures/reymont.65536.plain \
  --encoded-input /tmp/vort-current-decode-matrix-20261111/fixtures/reymont.65536.deflate.6.wire \
  --iterations 30000 --rounds 2 --warmup 2 --lifecycle cold \
  --reference /tmp/vort-reference-libdeflate-20261111.SkIxha/build/libdeflate.so.0 \
  --reference-version 1.26 \
  --output /tmp/vort-deflate-distance-setup-20261111/base-profile.json
```

Use `perf report --stdio --no-children --call-graph none --sort dso,symbol`
or `--sort dso` on the extracted data. Refer to the modern matrix package for
exact fixture generation, reference builds and executable restoration.
