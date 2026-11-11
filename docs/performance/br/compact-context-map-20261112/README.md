# Compact context-map three-way screen

This package preserves the rejected compact-map candidate on three frozen Mozilla
wires. Each row runs all six permutations of `main / previous / compact`, for
54 valid child events in total. No measurement, codec or already-passed test is
rerun while packaging or verifying this evidence.

| Fixture | Main median / compact median | Previous median / compact median |
|---|---:|---:|
| Full q11 | 0.98981748715836x | 0.9977163950729292x |
| 1 MiB q11 | 0.9998991100630439x | 1.005779525638996x |
| Full q6 | 0.9752812702549858x | 1.0136873179649009x |

Each value is `exp(mean(log(ratio)))` over six three-process groups. Each process
median comes from two timed Vort batches; warmup batches and reference durations
are excluded from these ratios. Thus a value above 1 means compact is faster than
that comparator under identical inputs/iterations. The candidate was not adopted.

`screen.tar.gz` preserves all three original manifests, 54 event files and raw
stdout/stderr streams, the combined events and three exact summaries.
`compact-source-probe.tar.gz` preserves eight frozen source files and the compact
executable as mode 0755. `runner-builds.tar.gz` preserves the runner, screen log,
main/candidate build logs and the recorded ReleaseSafe 23/23 result.

`initial-noexec.tar.gz` preserves the first aborted attempt: one completed main
event followed by `taskset` PermissionDenied for the previous executable. It has
no final events file. Neither its partial main result nor its failed previous
attempt enters any valid-screen ratio. The runner stopped before saving a failed
event JSON, so no standalone captured failure returncode is invented.

Main source is the clean recorded `093d5b9c2793e31a5c23c0913af66ef0c22a5ac5` Git
content, registry 2062 and digest `990b8a2ce68ad441bcaae424307f267a22707c08698012521ca37087f5929bb6`.
The new candidate records base `21952b95` plus eight untracked frozen overlay files,
registry 2066 and digest `7020223de26ec2dd3a7469978f8f0d8cdd0ca283e00ee943f7cfa864125eb12a`.
Previous source uses immutable21952 files plus the earlier eight-file V2 overlay,
registry 2066 and digest `f7a525c03ec357f3a3f8b20e2fc7fe91a07a033a9b27df55995d3565da4ffeef`.
No live previous candidate source is used; it has since been modified.

`reuse.json` binds the exact archives in the
[earlier distributions package](../decode-mozilla-distributions-20261112/README.md).
Immutable base, previous/main source bytes, unchanged main/previous binaries and
reference SO/fixture hash metadata are reused instead of duplicating the full
31 MB package. The executable alias `bin/previous-compare` has mode 0755 and bytes
identical to the earlier `semantic-cold-compare` SHA
`f5074d03b6dbb214c773b0842184e89ea8fcd5cc90e60477ac6b1ff448e6dca9`.

The full-operation public APIs retain matched cold lifecycle: Vort
`brDecodeStreamInto` versus libbrotli 1.2.0 one-shot decode with per-call state and
internal heap. Full rows use one decode per batch; 1 MiB uses 20. Each report has
two warmup and two timed batches, ReleaseFast/Zig 0.16.0/x86_64-linux-gnu,
`skylake+pku+sgx`, CPU 15, and one codec/benchmark thread. The development-host
snapshots observed no compilers; they do not prove exclusive timed-batch isolation.
Complete output, guards, unchanged input and explicit successful child exit codes
are recorded. Exact compressed-byte consumption, production heap, a full 72-row
acceptance matrix and industry leadership are not claimed.

All archive members retain exact original bytes. Sorted GNU tar/gzip9 normalize
only container metadata: uid/gid/mtime 0, empty owner names, empty gzip filename,
timestamp0 and file modes 0644/0755. `archive-bindings.json`, `reuse.json` and
`SHA256SUMS` bind payloads and reused dependencies.

From the repository root, run the independent offline validator:

```sh
python3 docs/performance/br/compact-context-map-20261112/verify.py \
  --original-bytes --git-repo . --external-fixtures
```

It checks exact raw-event equality, all six orders, medians/ratios, executable
identities, source reconstruction, the excluded non-executable failure and the
Safe receipt. `validation-receipt.json` records the completed archival audit.
