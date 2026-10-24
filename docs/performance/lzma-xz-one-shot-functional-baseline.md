# Bounded LZMA and XZ one-shot decoding

Date: 2026-10-24. Zig 0.16.0, Linux x86-64, Intel Core i7-10700K.
Source and tools revision: `96c1bb2a`. This records functionality, compatibility
and requested-allocation behavior. It does not claim throughput or RSS
leadership.

## Caller-buffer validation and replay

LZMA-Alone, MicroLZMA and ZIP-LZMA caller-buffer helpers no longer allocate
complete plaintext before copying it into the destination. Their shared
workspace drains a validation/count pass through fixed 273-byte symbol scratch,
then resets the retained probability tables and circular dictionary for replay.
Probability storage grows from the actual lc/lp shape and retains its high-water
capacity. The stdlib model borrows that storage rather than owning it.

XZ caller-buffer single/concatenated decoding, decoded-size queries and strict
inspection also avoid complete plaintext storage. A dedicated workspace
validates every block, inverse filter, block check, Index/Footer record, stream
padding and member boundary, retaining numeric block plans. Five LZMA2
probability shapes, dictionary capacity and inverse-filter storage are reused
across blocks. Count and replay use the same fixed execution schedule.

All required validation and allocation finish before caller output is written.
Too-small output, malformed data, late checks, budget rejection and backing OOM
leave destination bytes unchanged. Legacy input/output overlap remains supported:
the required compressed input is copied before output starts. LZMA known-size
helpers protect only their actually consumed coded prefix, preserving their
existing ignored-tail behavior.

`LzmaDecodeWorkspace` and `XzDecodeWorkspace` expose independent output,
dictionary and work limits, requested live/peak metrics, zero-allocation
initialization, retained reset and validated reconfiguration. LZMA-Alone
`DecodeOptions.max_working_memory` also applies to allocating decode, including
its returned output and replacement peaks. The slice remains owned by the
caller and is freed through the original allocator.

XZ additionally exposes `prepare`, overlap-aware `prepareInto` and repeated
`replayInto`. Borrowed prepared input must remain unchanged until the next
preparation, reset or deinit. Borrowed-input overlap is rejected before replay
writes; convenience Into methods handle overlap during preparation.

Known-size Alone and non-EOS ZIP retain their coded-tail semantics. Unknown-size
Alone and EOS ZIP retain end-marker/full-input validation; raw EOS ZIP's size
argument remains an output ceiling, with exact entry size enforced by the
archive layer. MicroLZMA retains strict range/input completion and its explicit
partial-prefix option. XZ retains all eight BCJ filters, Delta combinations,
all supported checks and the old single/concatenated error ordering. One-shot
decoding does not inherit the incremental facade's separate default block or
Index caps.

## Verification

| Gate | Result |
| --- | ---: |
| Complete LZMA family, ReleaseFast | 74/74 |
| Complete XZ/LZMA2 family, ReleaseFast | 89/89 |
| One-shot contract aggregate, Debug and ReleaseFast | 29/29 each |
| 7z/PBZX/WIA-RVZ consumers, ReleaseFast | 76/76 |
| ZIP/TAR/CPIO stream consumers, ReleaseFast | 70/70 |
| Final build check, including wasm32-wasi | 136/136 steps |
| Debug CLI help, formatting and diff checks | pass |

The independent LZMA campaign covers 91 streams and 316 runs: Alone 36,
MicroLZMA 19 and ZIP payload 36. It includes genuine liblzma 5.8.4 LZMA1EXT
known-size/no-EOS output, Python EOS streams, dedicated MicroLZMA reference
encoding and system xz 5.2.5 verification. Its 278 historical-oracle calls,
177 OOM failures, 266 warmed zero-allocation calls and 12 lifecycle checks pass.
An allocator observer confirms that caller bytes remain unchanged at every
allocation attempt. An 8192-byte ignored tail requires only a 114-byte alias
copy in its known-size fixture.

The independent XZ campaign covers 44 reference streams and 75 cases, including
system liblzma/xz 5.2.5 and 7-Zip 26.02 modern-filter references. All checks,
eight BCJ filters, Delta chains, multiple blocks, concatenation, stream padding,
8 MiB RLE and expected errors pass. Sixty-one valid cases exercise prepared
replay and warmed reuse with allocation disabled. Ten exact/below cold-budget
checks and 66 injected OOM failures preserve caller bytes; 66 Into/size pairs
make 132 matching calls against the historical oracle.

The oracle is compiled from revision `4d0a93f0` using the shared
[`legacy_probe.zig`](../../tools/one_shot/legacy_probe.zig). It compares output,
count and error semantics, rather than treating the modified allocating path
as the only reference.

| Representative sample | Requested work evidence |
| --- | --- |
| LZMA Alone/Micro/ZIP, 92160-byte plaintext | Maximum single allocation 12288 bytes; peak 17251 bytes |
| LZMA 2 MiB plaintext, 4 KiB dictionary | Count and Into succeed within a 64 KiB work budget |
| XZ 8 MiB plaintext | Peak 78544 bytes, within a 256 KiB work budget |
| Empty XZ streams, single and concatenated | Zero working heap |

These are corpus observations. Work counters exclude caller input/output,
fixed state, stack, allocator bookkeeping and allocator-internal remap
transients. Dictionary history can still retain up to the accepted window;
removing decoded-output staging does not promise a fixed universal memory
footprint.

The [LZMA JSON](data/lzma-one-shot-x86-20261024.json) binds 26 current source
hashes; the [XZ JSON](data/xz-one-shot-x86-20261024.json) binds 56. Their integration
records also verify drivers, probes and historical-oracle hashes against the
recorded source/tools revision. Exact versions, commands and corpus provenance
are retained in those reports.

```sh
zig build test-lzma test-xz -Doptimize=ReleaseFast
zig build test-lzma-xz-one-shot-contracts
zig build test-lzma-xz-one-shot-contracts -Doptimize=ReleaseFast
zig build test-xz-consumers test-stream-contract-consumers -Doptimize=ReleaseFast
zig build run-lzma-one-shot-diff -Doptimize=ReleaseSafe -- --report /tmp/lzma-one-shot.json
zig build run-xz-one-shot-diff -Doptimize=ReleaseFast -- --report /tmp/xz-one-shot.json
zig build check --summary all
```

Use the reports' `--baseline-probe` commands to reproduce the optional
historical comparisons. Format API and lifetime details are in
[LZMA](../formats/lzma.md) and [XZ](../formats/xz.md).

The next functionality priority is Zstd negative fast levels and explicit
strategy controls, followed by remaining encoder preset/training capabilities.
Broader current-source speed/ratio/memory comparisons remain necessary before
an industry-best claim.
