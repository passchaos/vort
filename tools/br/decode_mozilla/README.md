# Multi-block Brotli header diagnostics

This diagnostic reads existing producer wires and validates them with the
public `br.decodeStreamInto` API. It profiles all compressed meta-block headers
through the existing aggregate header APIs; it does not recompress input.

```sh
zig build -j2 build-br-header-profile test-br-header-profile \
  -Dtarget=x86_64-linux-gnu -Dcpu=skylake+pku+sgx
zig-out/bin/vort-br-header-profile \
  --input frame.br --plain original.bin --iterations 2 --output headers.json
```

`zig build run-br-header-profile -- --help` exposes the same command. The
executable and codec module use ReleaseFast; option tests use ReleaseSafe.
Inputs are limited to 256 MiB each and iterations to 1–1,000,000. The output
path is checked against the inputs and executable, including symlink/hardlink
identity, before reads and again before publication.

The public validation decode uses aligned buffers with 64-byte guards, checks
the complete output against the supplied plain bytes, and verifies unchanged
wire bytes. Both header APIs separately discover header offsets with a full
decode into allocated output before timing. Those diagnostic allocations do
not describe the production Into decoder's heap use.

The JSON keeps aggregate counters and clocks with their API and scope. Divide
counters by `iterations` for per-stream totals. The nested code-length and
canonical-build clocks overlap their outer tree-stage clocks. Do not add both
sets or interpret instrumented stage sums as whole-codec decoding time.
`benchmarkCompressedHeaders` measures repeated isolated header reconstruction;
its cold label describes fresh parser state rather than flushed CPU caches.

This tool does not identify the public payload route or measure codec heap.
Use the unchanged whole-operation comparator and separately attributed call
graphs for those questions. The [Mozilla evidence](../../../docs/performance/br/decode-mozilla-profile-20261112.md)
records the first three-row pilot and its limits.

`payload_counts.zig` complements the header clocks with the complete public
whole-stream command, distance and copy summary. It reads no clock:

```sh
zig build -j2 build-br-payload-counts test-br-payload-counts \
  -Dtarget=x86_64-linux-gnu -Dcpu=skylake+pku+sgx
zig-out/bin/vort-br-payload-counts \
  --input frame.br --plain original.bin --output counts.json
```

Its report preserves every summary field, verifies the full public decode and
guards, and exports the SHA-256 of the running Linux executable. An external
runner binds source and build provenance; the tool does not guess a runtime
source digest. Input/output alias checks and the 256 MiB file bounds match the
header tool. Allocating summary history and retry work is diagnostic memory,
and whole-stream counts do not identify each meta-block's actual executor.
Copy histograms include a final decoded command whose copy may be unused;
applied distance-path counters have their own denominator.
