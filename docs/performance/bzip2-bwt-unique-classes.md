# Bzip2 BWT unique-prefix termination

Date: 2026-10-29. Zig 0.16.0, Linux x86-64, Intel Core i7-10700K.

The encoder now stops cyclic suffix-array doubling when every current prefix
has a unique class. The distinct prefix comparison already determines each
complete cyclic rotation, so further passes cannot change the sorted order.
Periodic inputs retain equal rotations and execute the old full sequence,
including its deterministic tie order and original pointer.

The shared forward transform lives in `src/bzip2/bwt.zig`; the encoder keeps
its existing `BwtBlock` and `bwtTransformAlloc` aliases. Both one-shot and
incremental encoders use this core. Allocation sizes and failure order are
unchanged: four `u32` arrays, a `usize` count array and the transformed output.
This improves work on distinct data while retaining the old worst-case bound
and requested heap peak. It does not change the encoded representation.

## Exact-output validation

Four new BWT test groups compare transformed bytes and the original pointer
against a frozen full-doubling implementation from baseline commit
`a79a10f615c27001376b253bfe3734efbc484f80`. The frozen function differs only in
API names from the original encoder function. A separate naive cyclic rotation
sort checks small inputs; an independent last-to-first occurrence-rank inverse
recovers every tested input. The naive sort permits a different order within
identical periodic rotations, while the frozen oracle verifies the exact old
tie order and pointer.

Coverage includes 3279 exhaustive inputs over a three-byte alphabet, 96 random
small inputs, non-power-of-two lengths through 16381, exact periods, a long
common prefix with one marker, all 256 initial classes already unique, and a
900000-byte block. Empty and 900001-byte inputs reject before allocation.
Three input distributions exercise each of the six denied allocation points
and allocator failure enumeration, covering initial uniqueness and periodic
full doubling.

## Allocation-inclusive measurement

The campaign measures native awake-clock intervals around allocation,
transform or complete level-9 encoding, sampled output consumption and free.
File I/O, SHA256 and exact-output preflight are outside these intervals.
Preflight retains two raw BWT outputs and, for encoding, one encoded output;
these warm the process and contribute symmetric live-memory background.
The measurements do not represent cold-start latency, RSS or a throughput
comparison with another compression library.

For BWT, the same current executable contains the production kernel and frozen
full-doubling kernel. For complete encoding, the campaign rebuilds the old
encoder and its source closure directly from the baseline Git commit, using
the same measurement tool and compiler options. The current executable is
also built by the campaign, with an observed build exit code and source
hashes. Each is single-threaded and pinned to CPU 0. Default native target
features, exact command lines, executable/input/source hashes and all raw
samples are in the JSON evidence. Compiler work finishes before timing starts;
ordinary background load is recorded, without claiming a fully isolated host.

Two repeats alternate baseline/current order. Each call retains five samples
of three iterations; nine inputs and two scopes produce 72 calls and 360 raw
sample rows. Complete compressed bytes are identical across old/current
versions and repeats, and all 36 encoding-call outputs are independently
decoded with Python `_bz2` and its linked libbz2. The actual extension/library
paths, hashes and `BZ2_bzlibVersion` are recorded. The CSV field
`raw_bwt_original_pointer` describes BWT directly over input, before RLE1; it
does not claim to parse the pointer from an encoded block.

| Input | Bytes | BWT speedup | Complete encode speedup | Encoded bytes |
| --- | ---: | ---: | ---: | ---: |
| unique256 | 256 | 15.242x | 1.611x | 419 |
| random16k | 16384 | 5.883x | 2.394x | 18604 |
| random64k | 65536 | 5.102x | 2.594x | 74020 |
| random900k | 900000 | 11.859x | 7.344x | 1014869 |
| source | 13007 | 1.939x | 1.783x | 5694 |
| json64k | 65536 | 2.289x | 2.165x | 3066 |
| periodic64k | 65536 | 0.967x | 0.976x | 54 |
| periodic900k | 900000 | 0.958x | 0.968x | 58 |
| nearly_periodic64k | 65536 | 0.934x | 0.968x | 62 |

Speedup is the baseline median divided by the current median across all ten
samples per input/scope/variant; values below 1 mean slower. The full-work
periodic/near-periodic rows have 3.3%-6.6% lower raw-BWT throughput and
2.4%-3.2% lower complete-encoding throughput in this run. Their elapsed-time
increases are 3.4%-7.0% and 2.4%-3.3%, respectively. The added stop check and resulting
code generation are not isolated causes by this campaign. The original
algorithm and full-work bound remain the reference for these rows.

[Final raw evidence](data/bzip2-bwt-unique-classes-20261029/final.json) includes
all observed samples and passes the source/binary/input/target/affinity audit.
[Preliminary evidence](data/bzip2-bwt-unique-classes-20261029/preliminary.json)
is a separate completed 72-call screen using the earlier metadata fields.
Its declared current-build command was supplied externally and its generic
`original_pointer` column also refers to raw-input BWT; the final campaign
fixes those recording ambiguities and uses the actual linked libbz2 identity.
[An interrupted final setup](data/bzip2-bwt-unique-classes-20261029/interrupted.json)
records exit 130 during baseline compilation before any timing call, while
integrating the final review fixes. An earlier maximum-file read hit
`StreamTooLong`; the tool now reserves one byte to observe EOF and enforces
the 900000-byte bound separately. Those failed/incomplete epochs support no
performance conclusion.

The unique-byte microcase skips every doubling pass. Distinct random/source/
JSON rows benefit; exact periods and the almost-periodic sample can require
the full sequence and provide little benefit. Reported values are corpus
observations, and a slowdown on an unchanged-work row is retained rather than
hidden. The equal-length Huffman-group baseline remains a substantial ratio
limitation. Adaptive group/length planning and comparable real-file
ratio/throughput/memory measurements remain next Bzip2 work, alongside the
other nine formats in the long-term objective.

## Reproduction and checks

```sh
python3 tools/bzip2/bwt_campaign.py \
  --current zig-out/bin/vort-bzip2-bwt-bench \
  --baseline-commit a79a10f615c27001376b253bfe3734efbc484f80 \
  --cpu 0 --iterations 3 --samples 5 --repeats 2 \
  --report /tmp/bzip2-bwt.json
zig build -j2 test-bzip2
zig build -j2 test-bzip2 -Doptimize=ReleaseFast
zig build -j2 test-bzip2-stream-consumers run-bzip2-diff \
  run-bzip2-stream-contract-diff -Doptimize=ReleaseFast
zig build -j2 test check check-wasm
```

The complete Bzip2 suite passes 58 tests in Debug and ReleaseFast. The new
four-group BWT oracle tests pass in both modes; an actual default-Debug bench
call reports Debug provenance. ReleaseFast Bzip2/archive-consumer validation
passes 153 tests (58 codec and 95 consumer), bidirectional Python bz2
interoperability passes seven corpus cases plus legacy randomization and
concatenation, and the independent stream-contract campaign passes 92 cases.
The monolithic ReleaseFast CLI compilation takes about 40 minutes / 7 GiB
MaxRSS in the build report, outside benchmark timing. The actual differential
execution takes about 252 ms.

`git pull --rebase origin main` leaves the branch current without conflicts.
Post-rebase Bzip2 58 and the 92-case stream-contract campaign pass again;
Wasm compilation and CLI help also return exit 0. A separate complete
`zig build -j2 check` returns exit 0 with 211/211 steps. Format, Python syntax,
source-reference and Git whitespace checks pass.

The combined `zig build -j2 test check check-wasm` later returns exit 1.
Its original root-test executable reports 5030 passed / two skipped, including
the two small support suites, after about 59 minutes. Three later queued
compilation steps read the next Huffman prototype while it still exposed an
internal shape error outside existing consumer error sets. That error mapping
is corrected in the following feature, but this command spans source epochs
and is not assigned a clean whole-gate pass. The original separate 211-step
check remains an independent completed epoch. [Validation records](data/bzip2-bwt-unique-classes-20261029/validation.json)
retain the terminal combined log, counts and source-epoch distinction.

Complete-stream byte equality in this document belongs to commits
`b2f6e2b7` / `80ea656b`; reproduce the screen from that source epoch.
The subsequent adaptive Huffman feature changes encoded bits while preserving
the forward BWT result. Future long gates use a frozen checkout to avoid late
compilations reading ongoing edits.
