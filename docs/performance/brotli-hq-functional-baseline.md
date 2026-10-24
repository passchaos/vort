# Brotli HQ functionality baseline

Date: 2026-10-24. Recorded HQ codec revision: `46b21593`; portable public-route
fixes: `49e1e924` and `45a8997a`.

The optional HQ API now provides native quality-10 and quality-11 command
parsing for standard Brotli windows. The
[HQ command-parser contract](../formats/brotli-hq-command-parser.md) defines
controls, exact encodings, ownership and publication. This document records the
completed functional, reference, CLI and build gates. Subsequent platform
fixes are recorded separately from the original frozen native evidence.

## Recorded evidence

| Gate | Recorded result | Evidence scope |
| --- | ---: | --- |
| HQ Debug | 102/102 | 93 named tests and nine anonymous import roots |
| HQ ReleaseFast | 102/102 | The same ordered test-name list as Debug |
| Full Brotli, ReleaseFast | 1107/1107 | Existing Brotli and new HQ tests together |
| Versioned references | 134 logical cases; 354 probe invocations | 74 feature cases, 49 frozen legacy rows, two memory measure/exact cases and nine expected-error cases |
| Reference interoperability | 146 successful reference results; two system RAW skips | Versioned Brotli 1.2.0 and system Brotli 1.0.9 helpers |
| CLI | 146 round-trips; 60 profile-wire checks; 50 rejected-output checks; 4 same-path checks; 10 legacy mapping checks | Debug public probe; six parser tests; nine build steps; all 1517 source files unchanged |
| Complete `zig build check` | 145/145 steps | Native library, CLI, probes and existing wasm static-library compilation; source snapshot unchanged |
| Post-platform `zig build check` | 147/147 steps | Adds the real public WebAssembly consumer to the complete build surface; source snapshot unchanged |
| Post-platform native / x86-32 HQ | 102/102 each, ReleaseFast | Complete original-tree gates after portable arithmetic and decoder/allocator dispatch fixes |
| Public WebAssembly consumer | 7/7 build steps; two 4097-byte round-trips | Real q10/q11 public encode and general exact decode; Node v26.10.0; no module imports or libc |

The staging evidence is held in
`/tmp/vort-br-hq-final-20261024-dtre4swk`. Its `hq-*-result.json`,
`br-release-fast-result.json`, `coverage/summary.json` and
`reference/{formal-command,formal-summary,reference-abi-manifest,report}.json`
record gate commands, binary/source hashes and reference identities.
Permanent reports include [reference results](data/brotli-hq-functional-x86-20261024.json),
[reference artifact binding](data/brotli-hq-reference-binding-x86-20261024.json),
[actual TestFn coverage](data/brotli-hq-contracts-x86-20261024.json),
[CLI provenance](data/brotli-hq-cli-x86-20261024.json),
[CLI results](data/brotli-hq-cli-gate-x86-20261024.json), and
[WebAssembly execution](data/brotli-hq-wasm-x86-20261024.json).
The temporary staging directory retains raw logs, binaries and complete input
archives; it is not the permanent release-evidence location.

The named-test coverage was extracted read-only from the actual compiled ELF
`TestFn` name slices and function pointers. The extraction verified compilation
cache output digests, the run-manifest input digests and source-input content.
Debug and ReleaseFast both contain exactly 93 named tests plus nine anonymous
roots. The broad gate source snapshots contain 1521 files and are unchanged
before/after execution. The extraction itself rebuilt and executed no tests.

The recorded gate used `--summary all` without `--verbose`, so the exact child
`zig test` argument vector was not logged. The build command is recorded, and
the ELF and execution-input binding provide the binary provenance. This gap
must remain visible in the archived evidence.

## Implemented behavior

`hq = null` retains the prior quality policy and complete wire behavior. A
non-null `hq` is valid for qualities 10 and 11 and propagates through one-shot,
reusable, chunks, bounded-output and incremental APIs. The existing container
window stays authoritative: standard window bits 10 through 24, with normal
history limited to `2^window_bits - 16`. The HQ default meta-block target is
256 KiB and the accepted ceiling is 16 MiB. Outer stream and incremental block
targets are resolved into the actual parser settings and profile.

The ordinary-history tree retains a stream checkpoint, rebinds borrowed source
views, stitches short/main tails and uses deep forks for candidate parses.
Its epoch and absolute positions use `u64`. Stored fallback still advances the
plaintext history/index while preserving the entering distance cache and model.
The generic stream layer gathers caller fragments into the configured
meta-block; the internal 4096-position parser horizon does not publish a block.

The parser prices the complete 704-command alphabet and every semantic short
distance selector. The plan carries the selected command symbol, distance code,
physical prefix/extra bits and fixed distance parameters into the actual
writer. Equal physical distances retain their distinct selector/cache choices.
Implicit distance zero and explicit semantic code zero both leave the recent
distance cache unchanged. Static references also leave it unchanged.

Static dictionary commands preserve the original word length and separately
advance by transformed output length. RAW/compound and serialized providers
retain complete candidate tuples rather than collapsing different addresses,
raw lengths or transforms with equal output. Independent native tests cover
their address, context, budget and transaction behavior.

Quality 10 defaults to one native parse. Quality 11 defaults to two native
parses, using the first candidate's actual Huffman tables and command/literal
statistics to refine the next model. Each pass starts from the same entering
source, history, context bytes and recent-distance checkpoint. The format bridge
compares serialized candidates including their headers and payload. A one-shot
q11 call also preserves the complete corresponding q10 stream and eligible
legacy winner. Every compressed meta-block of an eligible legacy candidate must
honor the fixed HQ distance shape and block ceiling.

Incremental q11 retains a q10 candidate from the same entering meta-block
state. Whole-stream size ordering is established by the complete one-shot
comparison; local comparisons do not establish that ordering for independent
streams with different earlier choices or block boundaries.

Publication reserves output capacity before changing a shared partial byte.
Final-block output and its final marker are committed together. Prefix growth,
input/dictionary alias snapshots, model-allocation failures and partial output
drains preserve the accepted/delivered progress required for retry. Published
counters follow only the winning wire; attempted-work counters retain real
rejected or failed work. The public effective quality is restored after an
internal q10 safeguard fails during a q11 operation.

## Reference and corpus scope

The functional runner recorded an Intel(R) Core(TM) i7-10700K CPU @ 3.80GHz and
Zig 0.16.0. The reference C wrappers were built with
`cc (Ubuntu 11.4.0-1ubuntu1~22.04.2) 11.4.0`, using `O2 PIC shared C wrapper`
settings. Runs occurred under concurrent CPU load. Existing reference-library
build flags and runtime source revisions were not independently reconstructed.
Validation durations and process peaks are not throughput or memory rankings.

The modern helper binds versioned encoder, decoder and common libraries under
`/tmp/vort-brotli-shared-build`, with runtime encoder/decoder version
`0x1002000` (1.2.0). Its headers come from local revision
`558fc647cdaf391228d614ca85f711e02e4e583b` and matching `common/version.h`.
The system helper binds `/usr/lib/x86_64-linux-gnu` libraries whose runtime
encoder/decoder version is `0x1000009` (1.0.9); the system headers expose no
package-version macro. The ABI manifest records hashes for helpers, headers
and all three library files in each reference layer.

The 146 successful results are recorded as bidirectional reference checks.
The two skipped results are specifically `raw-prefix` and
`compound-cross-chunk` against system Brotli 1.0.9, which lacks the prepared
encoder / attach-decoder shared-dictionary API. The modern 1.2.0 helper supplies
that RAW API. Both public reference helpers report serialized-dictionary
attachment unavailable; native serialized-provider tests do not establish
external serialized interoperability. No dictionary bytes or headers were
removed to turn an unsupported attachment into a success.

The reference matrix covers all 15 standard window widths and 21 actual
distance shapes, including every `ndirect_high` at `npostfix = 3` and the
520-symbol maximum. Independent mapping tests cover all 64 legal shapes.
One-shot, chunks and incremental wide-history witnesses each emitted distance
66512. RAW-prefix and compound-cross-chunk witnesses each published a real
dictionary command; the transformed-word row published three static commands.
The 49 legacy rows are separately bound to the frozen baseline manifest.

The memory witness measured an HQ-managed requested peak of 9973172 bytes,
accepted that exact cap and rejected 9973171 bytes. Expected-error rows preserve
their output. These figures describe that fixture and the managed allocation
scope; they are not total encoder allocation or process RSS.

## Remaining boundaries

The 4096-position horizon and finite native beam have a retained model-quality
gap. An independent 4098-byte witness has a legal 32792-bit parse, while the
current choice costs 32793 bits; both improve on its 32797-bit literal-only
path. The one-bit difference is a model-cost regression witness. Globally
optimal model cost, reference-style global segmentation and complete HQ
algorithm parity remain work to validate and improve.

`max_working_memory` and `peak_working_memory` cover the HQ-managed requested
heap: budget handle, dictionary indices, models, matchers/live forks, parser
workspaces, plans, candidate artifacts and explicitly charged alias snapshots.
Generic plaintext/pending buffers, retained plaintext history, complete-frame
output and the retained complete q10 comparison wire use the backing allocator
outside this cap. Stream I/O storage follows the configured block and window
bounds. The subsequent [total-memory milestone](brotli-total-memory-functional-baseline.md)
adds a separate quota covering these outer allocations and HQ workspaces.
Lower-peak complete-stream comparison remains unfinished.

The subsequent [Large Window milestone](brotli-large-window-functional-baseline.md)
adds explicit extended-format HQ encoding. Broader current-reference ratio and
encode/decode-throughput measurements, total-allocation/RSS evidence and global
HQ parity remain outside this completed standard-window slice. This milestone
keeps the long-term industry-best objective active.

## Recorded reproduction commands

Commands below are the recorded build/runner invocations; `zig` denotes the
recorded `/home/passchaos/Temp/zig-x86_64-linux-0.16.0/zig` executable.

```sh
zig build -fno-incremental test-br-hq -Doptimize=Debug --summary all
zig build -fno-incremental test-br-hq -Doptimize=ReleaseFast --summary all
zig build -fno-incremental test-br -Doptimize=ReleaseFast --summary all
zig build -fno-incremental test-br-hq -Dtarget=x86-linux-musl -Doptimize=ReleaseFast --summary all
zig build -fno-incremental test-br-public-wasm -Doptimize=ReleaseFast --summary all
zig build -fno-incremental test-br-hq-cli -Doptimize=Debug --summary all
zig build -fno-incremental check -Doptimize=Debug -j4 --summary all
zig build -fno-incremental run-br-hq-diff -Doptimize=ReleaseFast -- --reference /tmp/vort-br-hq-reference-modern.so --system-reference /tmp/vort-br-hq-reference-system.so --output-dir /tmp/vort-br-hq-final-20261024-dtre4swk/reference
```

The reference output directory was prepared with the frozen legacy baseline
assets and versioned ABI helpers. Recreating an empty directory requires those
assets and helper provenance; an empty-directory run is a different evidence
setup. The CLI manifest records
`zig build -fno-incremental test-br-hq-cli -Doptimize=Debug --summary all` as
running. Its final result and the complete build-check command/result will be
added by the final evidence owner after completion.
