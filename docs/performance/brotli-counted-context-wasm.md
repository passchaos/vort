# Counted-context Wasm correctness

The frozen public q8/generic consumer validates exact candidate counting and
deferred literal-context emission in **wasm32-wasi**, with ReleaseFast encoding
and the existing **8 MiB stack**. The baseline is the compressed module retained
by the [prepared-command regression](brotli-prepared-command-wasm.md).

Both modules produce the same complete **14,362-byte** Brotli stream from the
same **65,536-byte** deterministic mixed input. The current module performs
**4 exact evaluations** and **2 emissions linked to evaluations**. Ordinary and
profiled public encoding agree byte for byte; Zig decoding and Node's native
Brotli decoder recover the complete input.

| Witness | Baseline | Counted candidate |
| --- | ---: | ---: |
| Decoded commands | 1,299 | 1,299 |
| Active command entries | 88 | 88 |
| Complex command trees | 1 | 1 |
| Recent copies | 152 | 152 |
| Preferred groups with reusable candidates and real wires | 2 | 2 |
| Exact evaluation attempts | Not exported | 4 |
| Emissions linked to evaluations | Not exported | 2 |

The fixture crosses the production recent-distance gate and the 128-command
cache boundary. Each module also validates a command/distance key offset above
`2^32`. Evaluations carry exact lengths; emitted candidates register actual
output storage and retain the evaluation reference.

The identity anchors are:

| Artifact | SHA-256 |
| --- | --- |
| Current Wasm | `75954c9cd7cfbe66d20b8fdc1f23e3da5ae4cb31b257d5cad7be9991fff5262b` |
| Decompressed baseline Wasm | `fb3ea213835c177711dcd14293c765cb7872a76297cac45286be44c7c701d3bf` |
| Compressed baseline | `eef827c8d1f329796311d1a67cac30ffce17f7115a1cef179ce2ccfe2521904d` |
| Full input | `af1a093e1380b98ce3fd749e06b2618b02d80c9b1234fe0018e0a3bc95eb1c25` |
| Both full wires | `b6eb2991d9848de02c4079a698b23328d122550b2af0dc119326219da6f96762` |
| Frozen `src/br.zig` | `8a2af34def5929a00e2a3df9889affc085383511b37e3409c615d6a75a20432f` |

The final `test-br-prepared-command-wasm` invocation was observed to exit **0**;
its compressed log records all five build/run steps succeeding. The archive
agent subsequently replayed the frozen module and compressed baseline **once**,
with an explicit **exit code 0**. Newly generated input and both full wires
matched the preserved bytes. The source restoration script also exited **0**
and verified all **21 changed/untracked source overlays**.

Complete native producer reports use schema
`vort.brotli.q8-candidate-profile.v2`. The independent profile gate validated
**three inputs × three rounds**, including evaluation accounting, successful
candidate references, emission lengths and links, and returned real-wire
references. The archive replay repeated this structural validation using the
preserved inputs with relocated paths. Wasm exposes the witness counters above;
the complete event-topology reports are from the native producer. The reader
retains support for valid v1 full-wire reports.

The [correctness package](data/brotli-counted-context-wasm-20261028/) contains
the frozen module, compressed baseline, complete input/wires, compressed logs,
v2 reports and their inputs, per-file source manifests, and replay scripts.
Source reconstruction uses Git base
`289110eb515edf7af24a5a72d88c80bfc164b9d8` plus the 21 overlays. A small archive
preserves 18 unchanged reference files, including `src/root.zig`, the Wasm
module root and build definitions. Other unchanged dependencies come from the
pinned Git base; the full source tree is not duplicated in this package.

Run `python3 replay.py --output EMPTY_DIR` from the package to verify its hashes,
replay the frozen Wasm comparison, and validate the saved v2 traces. The package
[README](data/brotli-counted-context-wasm-20261028/README.md) documents source
restoration and narrow optional rebuild commands. `SHA256SUMS` protects the
stored artifacts, and `observed-exits.json` distinguishes the main gate
observation from the archive agent's verification.

This evidence establishes correctness for the frozen fixture and recorded
profile cases. It makes no throughput or memory claim. Timing fields retained
in raw reports and logs are preserved provenance; performance and memory
evidence are maintained separately.
