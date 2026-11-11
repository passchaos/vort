# Frozen Mozilla distributions and semantic screens

This package preserves three whole-stream counter runs, three actual per-meta-block
dispatcher diagnostics, and the bounded semantic command/distance experiments on
the same Mozilla producer wires. It uses immutable base revision
`21952b95e99a6979dd640447f0beebcb16b29f49` plus explicitly frozen source overlays.
The experimental semantic kernels were rejected. Their source and binaries are
retained independently of the later diagnostic/shared-dispatch increment.

All original report, stdout/stderr, receipt, runner and source bytes are retained
without newline normalization. Archives use sorted GNU tar members, zero
uid/gid/mtime, empty owner names, modes 0644/0755, and gzip level 9 with an empty
filename and timestamp 0. `archive-bindings.json` binds every member's SHA-256,
length and original origin. No codec, test, compiler or measurement is rerun by
the packer or offline validator.

| Archive | Contents |
|---|---|
| `baseline-source.tar.gz` | 2059 source files obtained directly from immutable base Git blobs; includes the 2044-file counter baseline and 15 additional build modules registered by the screen runner |
| `counts.tar.gz` | External pre-build source freeze, three full public summaries, exact commands/returncodes/raw streams, before/after source/tool/probe identities, the frozen counter tool and distribution overview |
| `meta-blocks.tar.gz` | Three real shared-dispatch route reports with independent logical replay, host/execution receipts, 2047-file source freeze, four frozen source overlay files and exact probe source |
| `semantic-screen.tar.gz` / `semantic-source.tar.gz` | Original three-row semantic screen: 24 child events, all raw streams, manifests, four ratios per row, and seven frozen overlay files |
| `cold-fallback-v2-screen.tar.gz` / `cold-fallback-v2-source.tar.gz` | Separate V2 screen and eight frozen overlay files; its three cold fallback wrappers are noinline |
| `shared-dispatch-screen.tar.gz` / `shared-dispatch-source.tar.gz` | Separate three-row functional control screen and its complete 2062-file source registry reconstructed from matching immutable `6539890e` Git blobs |
| `brotli-smoke.tar.gz` | 72 frozen-wire correctness/executability rows, raw streams, explicit exit codes and source/probe stability receipt |
| `probe-binaries.tar.gz` | Actual counter/test/diagnostic executables, the immutable baseline compare binary and each separately frozen candidate compare binary |
| `runners-builds.tar.gz` | Original runner, screen log, three completed build/gate logs and the original empty preliminary meta build log |
| `correctness-supplement.tar.gz` | Semantic helper Debug/ReleaseSafe proofs, later actual-kernel oracle proofs, and explicitly bound later audit/build supplements |

The source registries have distinct scopes. Counters register 2044 baseline
files and bind their separate tool externally. Per-meta diagnostics register
2047 files: the baseline with `src/br.zig` replaced and three new modules. The
original semantic screen registers 2059 baseline files and 2065 candidate files;
V2 registers 2066 candidate files because it also includes the later oracle test
source. Seven/eight overlay files alone are not complete source snapshots; the
baseline archive plus the corresponding overlay reconstructs each recorded
registry. The same Git revision does not imply identical working trees or
executables. Every screen uses its own frozen overlay and binary, never live
main or the subsequently changed candidate install path.

Shared-dispatch and smoke manifests retain their recorded revision
`53c49311067af60a84fb3bc3e38bb6c93053b4fb`, but the authoritative 2062-entry source
digest is `990b8a2ce68ad441bcaae424307f267a22707c08698012521ca37087f5929bb6`.
All registered bytes match immutable
`6539890e984e76a2ce208e60c3125600e7970b46` Git blobs. The archive uses those verified
content blobs and does not describe the source as the clean `53c49311` commit.

The counter executable exports the actual SHA-256 of Linux `/proc/self/exe`.
Its runtime source SHA is deliberately null. Source identity comes from
`counts-source-freeze.json`, the exact per-module build argv and unchanged
before/after source/tool/probe receipts. The three counter invocations were each
performed once; complete public output, output length, 64-byte guards and
unchanged input were validated before JSON publication.

Counter summaries describe logical whole-stream quantities. Their allocating
history discovery may reserve or retry with a full declared window bounded by
the known output limit. This is diagnostic replay, not production Into heap or
peak-memory evidence. The per-meta diagnostic owns output/record storage, two
header objects, a history object and the full bounded replay window. Its stage
clocks include instrumentation and cache effects; output growth, header copy,
counter replay and validation are outside those clocks. They are not competitor
or acceptance timings. `small_generic` explicitly includes its own header
reconstruction.

The per-meta route tag records the actual shared prepared-dispatch executor.
Inner helper specialization is not inferred from that tag. The original full
q11 diagnostic has seven final `wide10_generic_literal` blocks with NPOSTFIX 3;
their literal bytes use signed context. These frozen diagnostic sources and
reports are distinct from both experimental semantic timing epochs. Whole-stream
maxima cannot substitute for actual per-meta route attribution.

All 20 compressed record stats agree with the corresponding public summaries:
20 additive fields, including both arrays, are summed elementwise; eight public
maximum fields use the per-record maximum. `max_wire_distance` has no public
whole-summary counterpart and remains separate from `max_lz77_distance`.
Per-record decoded ranges are contiguous, and literal/LZ77/dictionary byte totals
cover the complete plain output.

| Fixture | Commands | Applied distance copies | Final ignored-copy shapes |
|---|---:|---:|---:|
| Full q11 | 3,770,834 | 3,770,833 | 1 |
| 1 MiB q11 | 20,296 | 20,295 | 1 |
| Full q6 | 3,455,508 | 3,455,500 | 8 |

Command counts and the copy-length histogram include a terminal command whose
insert reaches the end before its copy is applied. Command/histogram percentages
use all decoded commands as the denominator. Distance percentages use the sum of
applied implicit, short, direct and regular copies; this also equals the sum of
LZ77/static/shared dictionary copy counts. The histogram ranges are
`1, 2–3, 4–7, 8–15, 16–31, 32–63, 64–127, 128–255, >=256`.

| Fixture | Zero-insert commands | Implicit + short copies | Direct copies | Regular copies |
|---|---:|---:|---:|---:|
| Full q11 | 28.30% | 54.24% | 0.93% | 44.82% |
| 1 MiB q11 | 54.49% | 51.42% | 1.55% | 47.03% |
| Full q6 | 26.68% | 44.97% | 0% | 55.03% |

The two semantic screens each retain three rows, four interleaved B/C process
pairs per row and 24 child reports. Every report has two warmup batches and two
timed batches, with full input using one decode per batch and 1 MiB using 20.
For each process pair, speed is the baseline Vort median divided by the candidate
Vort median; the row value is the geometric mean of four ratios. Warmups and
reference durations are excluded from this B/C ratio. Under identical input and
iterations this is candidate throughput divided by baseline throughput.

| Fixture | Original semantic speed | V2 noinline fallback speed | Shared-dispatch control |
|---|---:|---:|---:|
| Full q11 | 0.9904879980x | 0.9887127357x | 1.0116585967x |
| 1 MiB q11 control | 0.9929737832x | 1.0005488194x | 1.0000307623x |
| Full q6 | 0.9604926771x | 0.9596898068x | 1.0031456560x |

Both variants failed the declared improvement target and were not adopted.
V2's “cold” name describes fallback wrappers, not a different API lifecycle.
Its static code/frame reduction does not establish reduced dynamic cost. The
whole candidate includes its semantic planes/setup and cannot be attributed to
one helper or to pure dispatcher extraction.
The separately adopted shared dispatcher has a functional control screen;
these local ratios are not a speedup or statistical-parity claim.

Timing uses matched cold public APIs: Vort `brDecodeStreamInto` and reference
`BrotliDecoderDecompress`, whose state/internal heap is recreated per call.
Recorded conditions are ReleaseFast, Zig 0.16.0, x86_64-linux-gnu,
`skylake+pku+sgx`, i7-10700K, CPU 15 affinity and a single codec/benchmark thread.
The development host uses intel_pstate/powersave with turbo enabled. Before/after
snapshots observed no compilers; process ticks do not prove timed-batch isolation.
Full-output/guard/input-unchanged checks are retained, while exact compressed-byte
consumption and heap/RSS acceptance are not claimed. These are bounded local
screens, not a complete 72-row acceptance matrix or an industry-leadership result.

Reference libbrotli 1.2.0 SO bytes and fixture metadata/hashes are reused from the
[modern decode package](../../modern-decode-refresh-20261111/README.md) through
`reference-reuse.json`; payloads and SO files are not duplicated. Default offline
verification checks the reused package hashes and selected identities. Optional
flags also hash the still-retained original fixture payloads and compare baseline
sources with pinned Git blobs.

Correctness supplements are separate later epochs. Semantic-helper raw
Debug/ReleaseSafe receipts show 26/26 tests per mode. The actual-kernel oracle
shows 23/23 per mode, with combined original stdout/stderr logs; it ran after the
original timing. V2's later Safe gate is not retroactively assigned the original
Debug proof. Available correctness-source copies are selected only by their
recorded exact SHA. Test-root identities and timing identities remain distinct.

The later public WASI gate records 7/7 steps. An actual wasm32-wasi run of the
new diagnostic contracts records 23/23 tests, exit 0 and the SHA of the retained
WASM binary. The frozen Brotli smoke covers 72 wires with two calls per
implementation, no warmup, complete outputs/guards/input-unchanged checks and
explicit exit 0. Its manifest retains the generic iterations map
`65536:100, 1048576:20, full:1`; each row's argv/probe overrides iterations to 1.
Those effective row parameters govern this correctness smoke. Its timing fields
are not used for ranking or acceptance.

`codegen-audit.json` is a main-reconstructed supplement from an earlier read-only
audit and V2 ELF inspection, not a copy of independently retained original
disassembler stdout. The offline validator uses frozen binaries and `objdump`
to independently check ELF sizes, explicit stack adjustments and the three
recorded natural-loop instruction/call/branch/MOV-stack site counts. Static
counts include cold branches and cannot establish dynamic frequency, spill cost
or cycles. Route-weight integers and decoded/command shares are independently
recomputed from the 20 actual diagnostic records; they are not time weights.

From the repository root, run the offline validator without any codec execution:

```sh
python3 docs/performance/br/decode-mozilla-distributions-20261112/verify.py
```

For the optional retained-origin/Git/fixture audit:

```sh
python3 docs/performance/br/decode-mozilla-distributions-20261112/verify.py \
  --original-bytes --git-repo . --external-fixtures
```

`validation-receipt.json` records the final independent offline verification.
`SHA256SUMS` binds the package's final standalone files and archives.
