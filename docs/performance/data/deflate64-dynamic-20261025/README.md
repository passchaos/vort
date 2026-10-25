# Deflate64 dynamic functional evidence

The codec/tool source snapshot is `02b6498aa2e24fdf7e09eb1f194bc680aeac7b7f`.
`new-source-manifest.json` binds 1890 source/tool files. The fixed/stored
reference is `d69caf3d0de0afbcf773fea0524ad20060db8a32`, independently bound by
`old-source-manifest.json`. Documentation and subsequent handoff records do
not refresh historical source or timing epochs.

`native-final/` and `x86-final/` each contain 80 production raw/ZIP artifacts,
their input/wire/progress manifest, reference ZIP wrappers and full independent
Info-ZIP results. Each campaign verifies 112 member plaintexts, 154 commands
and 35 dynamic blocks. Reference wrappers and repeated members are additional
evidence, not additional corpus inputs. `cross-target-final.json` checks full
manifest/results equality and binds each executable and report.

The reference is system Info-ZIP UnZip 6.00 with `USE_DEFLATE64`; its identity,
version output and full commands are retained in the differential reports.
The Python parser has a hand-packed RFC dynamic golden and strict malformed
tree checks. The initial parser-order failure and ZIP fixed-block assumption
are retained in their original failed logs, followed by corrected final runs.

`validation.json` distinguishes codec, RLE, focused ZIP, full ZIP, build and
CLI scopes. The earlier Debug full suite used an earlier oracle: 1998 passes
and one ReleaseFast-only large-dictionary fixture skipped. The final
ReleaseFast full suite passes all 2000 tests. It is not the same test snapshot
or execution mode as that earlier Debug result.

`resource-comparison.json` independently validates both requested-allocation
reports and input/options/bound identity. Only the distant one-shot output
changes, from 69098 to 65633 bytes. Its requested peak falls by the identical
3465 bytes; non-output heap payload remains 393216 bytes. The six other
one-shot rows and complete 4 MiB stream record are unchanged. These are codec
requested live heap bytes including returned output, not RSS, stack, caller
input/collector memory or whole-process peaks. No timings were requested.

Reproduce with Zig 0.16.0 from the source checkout:

```sh
zig test src/deflate/dynamic/code_length_rle.zig -OReleaseFast
zig test src/deflate64.zig
zig test src/deflate64.zig -OReleaseFast
zig test src/deflate64.zig -target x86-linux-gnu -OReleaseFast
zig build test-zip-deflate64-stream --summary all
zig build test-zip-codecs -Doptimize=ReleaseFast --summary all
zig build check --summary all
zig build run --summary all -- --help
zig build run-deflate64-stream-diff -- --directory /tmp/vort-dynamic-native
zig build run-deflate64-stream-diff -Dtarget=x86-linux-gnu -- --directory /tmp/vort-dynamic-x86
zig build run-deflate64-index-probe
```

Resource measurements use ReleaseFast, single-thread encoding on an
i7-10700K, with exact CPU/target/executable details in the reports. Compilation
and ordinary validation are separate from performance evidence; this campaign
does not establish encoder speed or industry leadership.
