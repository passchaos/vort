# Stream-count verification evidence

This archive records functional progress toward wide Brotli/Zstd incremental
streams. Each stage retains its own source, compiler-input and artifact
identity. Earlier successful binaries are not labelled as executions of later
source revisions.

`index.json` lists each original file's path, byte count and SHA-256, plus the
SHA-256 of its deterministic tar.gz bundle. Text reports, commands, logs,
protocol outcomes, source hashes and input indices are retained. Full source
ZIPs, checkout copies, compiler binaries, large wire output and multi-GiB source
files are not duplicated in Git; their identity and local paths remain in the
original reports. The tools are committed as repository source.

| Group | Scope |
| --- | --- |
| formal-counts / aggregate-binding | Three 142-entry native/x86 runs, actual ELF names, cached inputs and linked objects |
| brotli-producer / brotli-qa / brotli-baseline | Producer checks, 18 independent QA names, archived old wire and legitimate prefix models |
| zstd-qa / zstd-baseline | 17 independent QA names, six archived wire rows and the separate checksum row |
| xxh64-reference | Independent C XXH fixed-point stripe and full-width length vectors |
| legacy-diagnostics | Nullable local-to-wide type adaptation and 37-type x86 compile consumer |
| cli-smoke / cli-source | Bounded file adapter, parser tests, small reference/old-wire/cap/same-path checks |
| tool-smoke | Locked small-scale real-generator/reference checks before the long campaign |
| wasm | Initial consumer/tool compilation failures and final four actual public operations |
| cli-large-file | Unique sparse source, original cap/reference-limit stages, corrected explicit-window success and actual x86 artifact binding |
| large-streams | Real reusable-buffer sources/drains, independent C receipts, failed skippable continuation and subsequent stages |
| families | Complete native/x86 families, compiler/runtime failures and their necessary final stages |
| global / post-rebase | Global build and complete CLI checks, then rebase verification |

Some groups are added as their terminal evidence becomes available. Source
models and small preflight tests are explicitly distinguished from physically
processed multi-GiB streams. Functional durations and requested allocations are
not competitor throughput, ratio or process-memory rankings. Current limits
and the incomplete industry-best objective are described in the
[functional baseline](../../stream-counts-functional-baseline.md).
